## DigSystem — Player dig action handler for Dig & Dash.
##
## Bridges InputSystem.dig_requested → TerrainSystem.dig_request with a
## READY / DIGGING state machine and a cooldown timer equal to
## TerrainConfig.dig_duration.
##
## Ordering guarantee (EC-02):
##   GridGravity.notify_digging(id, true) is called BEFORE TerrainSystem.dig_request
##   so the gravity system grants dig immunity before the hole opens beneath the player.
##
## Lifecycle:
##   1. Add DigSystem as a child of your Level node.
##   2. Call setup() to inject all dependencies.
##   3. Connect InputSystem.dig_requested → _on_dig_requested.
##   4. Call reset() on level restart.
##
## Implements: production/sprints/sprint-02.md#DIG-01
## Design doc: design/gdd/dig-system.md
class_name DigSystem
extends Node

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

## Internal state machine. READY accepts new digs; DIGGING blocks until
## the cooldown timer expires.
enum _DigState { READY, DIGGING }

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Dig timing configuration. Assign in the Inspector or inject via setup().
## Falls back to DigConfig.new() defaults if null.
@export var config: DigConfig

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a valid dig is triggered. Consumed by Visual Feedback + Audio.
signal dig_started(col: int, row: int)

## Emitted when the dig cooldown expires. Mostly for debugging.
signal dig_completed(col: int, row: int)

# ---------------------------------------------------------------------------
# Private variables — state
# ---------------------------------------------------------------------------

var _dig_state: _DigState = _DigState.READY
var _cooldown_timer: float = 0.0

## Grid cell of the most recent dig. Used by dig_completed emission.
var _last_dig_cell: Vector2i = Vector2i.ZERO

# ---------------------------------------------------------------------------
# Private variables — injected dependencies
# ---------------------------------------------------------------------------

var _terrain: TerrainSystem = null
var _gravity: GridGravity = null
var _player: PlayerMovement = null
var _terrain_config: TerrainConfig = null
var _player_id: int = 0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	if config == null:
		config = DigConfig.new()
	# _process is enabled only while DIGGING to save CPU when idle.
	set_process(false)


## Tick the cooldown timer. Transitions to READY and clears dig immunity when
## the timer expires. _process is disabled when state returns to READY.
func _process(delta: float) -> void:
	if _dig_state != _DigState.DIGGING:
		return
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_cooldown_timer = 0.0
		_dig_state = _DigState.READY
		set_process(false)
		_gravity.notify_digging(_player_id, false)
		dig_completed.emit(_last_dig_cell.x, _last_dig_cell.y)

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Inject dependencies. Call before connecting to InputSystem.
##
## p_player_id must match the id used with GridGravity.register_entity so
## dig immunity is applied to the correct entity.
func setup(
	p_terrain: TerrainSystem,
	p_gravity: GridGravity,
	p_player: PlayerMovement,
	p_terrain_config: TerrainConfig,
	p_player_id: int = 0,
) -> void:
	_terrain = p_terrain
	_gravity = p_gravity
	_player = p_player
	_terrain_config = p_terrain_config
	_player_id = p_player_id


## Reset state: cancel any active cooldown and clear dig immunity.
## Called by the Level System on level restart.
func reset() -> void:
	if _dig_state == _DigState.DIGGING:
		_gravity.notify_digging(_player_id, false)
	_dig_state = _DigState.READY
	_cooldown_timer = 0.0
	set_process(false)

## Return dig cooldown progress as 0.0 (ready / no cooldown) to 1.0 (just started).
## Used by HUDController to drive the cooldown indicator bar.
func get_cooldown_ratio() -> float:
	if config == null or config.dig_cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_timer / config.dig_cooldown, 0.0, 1.0)

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

## Connected to InputSystem.dig_requested.
##
## Validation (all must pass):
##   1. DigSystem is in READY state (no active cooldown).
##   2. Player state is IDLE (0) or MOVING (1) — not FALLING or DEAD.
##   3. Player is grounded at their current cell.
##   4. Target cell = (player.x + direction.x, player.y + 1) — one row below (Lode Runner diagonal dig).
##   5. Target cell is destructible (DIRT_SLOW or DIRT_FAST).
##   6. Target cell dig state is INTACT (not already being dug or open).
##
## If all pass: enters DIGGING, calls notify_digging(true) BEFORE dig_request (EC-02),
## then emits dig_started.
func _on_dig_requested(direction: Vector2i) -> void:
	# 1 — cooldown gate
	if _dig_state != _DigState.READY:
		return

	# 2 — player state gate (IDLE=0 or MOVING=1 only)
	var player_state: PlayerMovement.State = _player._state
	if player_state != PlayerMovement.State.IDLE and player_state != PlayerMovement.State.MOVING:
		return

	# 3 — grounded check
	if not _gravity.is_grounded(_player.current_cell.x, _player.current_cell.y):
		return

	# 4 — compute target (diagonal below: Lode Runner style)
	var target: Vector2i = Vector2i(
		_player.current_cell.x + direction.x,
		_player.current_cell.y + 1,
	)

	# 5 — destructibility check
	if not _terrain.is_destructible(target.x, target.y):
		return

	# 6 — dig-state check (must be INTACT)
	if _terrain.get_dig_state(target.x, target.y) != TerrainSystem.DigState.INTACT:
		return

	# --- All validations passed — initiate the dig ---
	_dig_state = _DigState.DIGGING
	_cooldown_timer = config.dig_cooldown
	_last_dig_cell = target

	# EC-02: grant dig immunity BEFORE opening the hole so GridGravity
	# does not emit entity_should_fall when the cell below becomes traversable.
	_gravity.notify_digging(_player_id, true)
	_terrain.dig_request(target.x, target.y)
	set_process(true)
	dig_started.emit(target.x, target.y)
