## PlayerMovement — Grid-based player entity controller for Dig & Dash.
##
## Implements: design/gdd/player-movement.md
## Sprint:     production/sprints/sprint-01.md#MOVE-01
##
## Receives movement intentions from InputSystem, validates them against
## TerrainSystem and GridSystem, executes cell-by-cell movement, and handles
## gravity-driven falling via GridGravity signals.
##
## The player can never be in an invalid grid position: every transition is
## validated before execution, and every snap writes the authoritative cell
## and world position atomically.
##
## Lifecycle:
##   1. Add PlayerMovement as a child of your Level node.
##   2. Set entity_id before calling setup().
##   3. Call setup() to inject all system dependencies.
##   4. Call spawn() to place the player and enter IDLE.
##   5. Call reset() on level restart (alias for spawn()).
##   6. Call die() to enter DEAD state (stub — consumed by Level System in MVP).
class_name PlayerMovement
extends Node2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after every successful move (horizontal, vertical, or fall step).
signal player_moved(from_cell: Vector2i, to_cell: Vector2i)

## Emitted when the player dies (consumed by Level System — stub only in MVP).
signal player_died()

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

## 4-state machine controlling which inputs and transitions are accepted.
## See design/gdd/player-movement.md §States and Transitions for the full
## transition table.
enum State {
	IDLE,    ## Grounded or on structure, waiting for input.
	MOVING,  ## Transitioning to target cell.
	FALLING, ## Falling cell-by-cell, ignoring horizontal input.
	DEAD,    ## No movement accepted until reset().
}

# ---------------------------------------------------------------------------
# Public properties
# ---------------------------------------------------------------------------

## Current grid cell. Updated atomically after every successful snap.
var current_cell: Vector2i = Vector2i.ZERO

## Entity ID used with GridGravity registry.
## Must be set (via @export or code) before calling setup().
@export var entity_id: int = 0

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _state: State = State.IDLE

var _grid: GridSystem
var _terrain: TerrainSystem
var _gravity: GridGravity
var _input: InputSystem
var _input_config: InputConfig

## Seconds per fall cell. Injected via setup(). Default: 0.1 s (GDD tuning table).
var _fall_speed: float = 0.1

## Target cell for the current MOVING transition.
var _target_cell: Vector2i = Vector2i.ZERO

## Seconds remaining on the current move transition.
var _move_timer: float = 0.0

## Seconds remaining until the next fall step.
var _fall_timer: float = 0.0

## 1-slot input buffer (last-wins). Consumed on any transition to IDLE.
## See design/gdd/player-movement.md §EC-01.
var _buffered_input: Vector2i = Vector2i.ZERO
var _has_buffered_input: bool = false

## True once setup() has been called successfully. Guards all signal handlers.
var _is_setup: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Disable _process until spawn() activates the player.
	set_process(false)


## Tick the movement and fall timers. Frame-rate independent (delta everywhere).
## Two separate `if` blocks (not elif) allow MOVING→FALLING within one frame
## when _complete_move() calls _start_fall() and the fall timer already expired.
func _process(delta: float) -> void:
	if _state == State.MOVING:
		_move_timer -= delta
		if _move_timer <= 0.0:
			_complete_move()

	if _state == State.FALLING:
		_fall_timer -= delta
		if _fall_timer <= 0.0:
			_fall_timer += _fall_speed  # += absorbs timer overshoot (keeps rhythm stable)
			_execute_fall_step()

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Wire all system dependencies and connect signals.
## Must be called once before spawn(). Re-calling is not supported.
##
## p_fall_speed: seconds per fall cell (default 0.1 s — see GDD tuning table).
func setup(
	p_grid: GridSystem,
	p_terrain: TerrainSystem,
	p_gravity: GridGravity,
	p_input: InputSystem,
	p_input_config: InputConfig,
	p_fall_speed: float = 0.1,
) -> void:
	_grid = p_grid
	_terrain = p_terrain
	_gravity = p_gravity
	_input = p_input
	_input_config = p_input_config
	_fall_speed = p_fall_speed
	_input.move_requested.connect(_on_move_requested)
	_gravity.entity_should_fall.connect(_on_entity_should_fall)
	_gravity.entity_landed.connect(_on_entity_landed)
	_is_setup = true


## Place the player at spawn_cell, register with GridGravity, and enter IDLE.
## Cancels any active transition timer. Safe to call from any state (including
## DEAD and FALLING) — implements EC-08 of player-movement.md.
func spawn(spawn_cell: Vector2i) -> void:
	if not _is_setup:
		push_error("PlayerMovement.spawn: call setup() before spawn().")
		return
	_move_timer = 0.0
	_fall_timer = 0.0
	_buffered_input = Vector2i.ZERO
	_has_buffered_input = false
	_state = State.IDLE
	current_cell = spawn_cell
	position = _grid.grid_to_world(current_cell.x, current_cell.y)
	# Unregister first to flush any stale _falling_entities state in GridGravity
	# (important when reset() is called mid-fall).
	_gravity.unregister_entity(entity_id)
	_gravity.register_entity(entity_id, current_cell.x, current_cell.y)
	set_process(true)


## Alias for spawn — called by Level System on level restart.
func reset(spawn_cell: Vector2i) -> void:
	spawn(spawn_cell)


## Transition to DEAD state. Unregisters from GridGravity and emits player_died.
## No movement is accepted until reset() is called.
func die() -> void:
	_state = State.DEAD
	set_process(false)
	_gravity.unregister_entity(entity_id)
	player_died.emit()

# ---------------------------------------------------------------------------
# Signal handlers (private)
# ---------------------------------------------------------------------------

## Connected to InputSystem.move_requested in setup().
##
## State routing (see design/gdd/player-movement.md §Règle 5 and §Règle 6):
##   DEAD    — discard entirely.
##   MOVING  — buffer last-wins (1-slot, EC-01).
##   FALLING — discard (EC-06: no lateral drift during fall).
##   IDLE    — validate and execute immediately.
func _on_move_requested(direction: Vector2i) -> void:
	if not _is_setup:
		return
	match _state:
		State.DEAD:
			pass  # discard entirely
		State.MOVING:
			# 1-slot buffer, last-wins: overwrite any previous buffered input.
			_buffered_input = direction
			_has_buffered_input = true
		State.FALLING:
			pass  # EC-06: all input discarded during fall — no buffer
		State.IDLE:
			_validate_and_move(direction)


## Connected to GridGravity.entity_should_fall in setup().
## Only reacts to our entity_id. IDLE or MOVING → enter FALLING.
## MOVING is interrupted: the in-progress transition is abandoned so the
## player falls from current_cell (not the mid-flight _target_cell).
func _on_entity_should_fall(id: int) -> void:
	if not _is_setup or id != entity_id:
		return
	if _state == State.IDLE or _state == State.MOVING:
		_start_fall()


## Connected to GridGravity.entity_landed in setup().
## Fired by GridGravity (Scenario A) when a registered-as-falling entity
## reaches a grounded cell via update_entity_position.
## Not fired for Scenario B falls (self-triggered by _complete_move) —
## those are handled by the is_grounded re-check in _execute_fall_step.
func _on_entity_landed(id: int) -> void:
	if not _is_setup or id != entity_id:
		return
	_state = State.IDLE
	_consume_buffered_input()

# ---------------------------------------------------------------------------
# Private methods — Movement
# ---------------------------------------------------------------------------

## Validate direction against terrain and gravity rules, then start a move.
## Only called when state is IDLE (from _on_move_requested or _consume_buffered_input).
##
## Horizontal (direction.y == 0):
##   can_move = is_valid(col±1, row)
##              AND is_traversable(col±1, row)
##              AND (is_grounded(col, row) OR is_climbable(col, row))
##
## Climb up (direction.y == -1):
##   can_climb = is_climbable(col, row) AND is_traversable(col, row-1)
##
## Climb down (direction.y == 1):
##   can_climb = is_climbable(col, row)
##               AND (is_traversable(col, row+1) OR is_climbable(col, row+1))
func _validate_and_move(direction: Vector2i) -> void:
	var col: int = current_cell.x
	var row: int = current_cell.y

	if direction.y == 0:
		# Horizontal movement — requires ground or structure support.
		var can_move: bool = (
			_grid.is_valid(col + direction.x, row)
			and _terrain.is_traversable(col + direction.x, row)
			and (_gravity.is_grounded(col, row) or _terrain.is_climbable(col, row))
		)
		if can_move:
			_start_move(Vector2i(col + direction.x, row))

	elif direction.y == -1:
		# Vertical up — only on LADDER or ROPE.
		var can_climb: bool = (
			_terrain.is_climbable(col, row)
			and _terrain.is_traversable(col, row - 1)
		)
		if can_climb:
			_start_move(Vector2i(col, row - 1))

	elif direction.y == 1:
		# Vertical down — only on LADDER or ROPE.
		var can_climb: bool = (
			_terrain.is_climbable(col, row)
			and (_terrain.is_traversable(col, row + 1) or _terrain.is_climbable(col, row + 1))
		)
		if can_climb:
			_start_move(Vector2i(col, row + 1))


## Begin a timed transition toward target_cell. Sets state to MOVING.
## Uses InputConfig.move_interval so tuning MOVE_SPEED in InputConfig
## automatically keeps Input System and PlayerMovement in sync.
func _start_move(target_cell: Vector2i) -> void:
	_state = State.MOVING
	_target_cell = target_cell
	_move_timer = _input_config.move_interval


## Called when _move_timer expires. Snaps position to _target_cell and
## re-evaluates gravity: starts a fall if no longer grounded, otherwise
## transitions to IDLE and consumes any buffered input.
func _complete_move() -> void:
	var from: Vector2i = current_cell
	current_cell = _target_cell
	position = _grid.grid_to_world(current_cell.x, current_cell.y)
	_gravity.update_entity_position(entity_id, current_cell.x, current_cell.y)
	player_moved.emit(from, current_cell)
	# Re-evaluate support after landing.
	if not _gravity.is_grounded(current_cell.x, current_cell.y):
		_start_fall()
	else:
		_state = State.IDLE
		_consume_buffered_input()


## Begin a cell-by-cell fall. Arms the fall timer.
func _start_fall() -> void:
	_state = State.FALLING
	_fall_timer = _fall_speed


## Advance one fall step downward. Called by _process when _fall_timer expires.
##
## Two landing paths:
##   Scenario A (GridGravity-tracked fall): update_entity_position triggers
##     entity_landed → _on_entity_landed sets state to IDLE before we reach
##     the re-check. The `if _state == State.FALLING` guard prevents a
##     double-transition.
##   Scenario B (self-triggered fall from _complete_move): entity is NOT in
##     GridGravity._falling_entities, so entity_landed never fires. The
##     is_grounded re-check at the end of this function is the sole landing
##     detector for Scenario B.
func _execute_fall_step() -> void:
	# Safety guard: already grounded (e.g., entity_landed already fired above).
	if _gravity.is_grounded(current_cell.x, current_cell.y):
		_state = State.IDLE
		_consume_buffered_input()
		return

	var target: Vector2i = Vector2i(current_cell.x, current_cell.y + 1)

	# Guard: below grid bounds. Should not occur — GridGravity's is_grounded
	# returns true at the bottom row (EC-01 implicit floor).
	if not _grid.is_valid(target.x, target.y):
		_state = State.IDLE
		_consume_buffered_input()
		return

	var from: Vector2i = current_cell
	current_cell = target
	position = _grid.grid_to_world(current_cell.x, current_cell.y)
	_gravity.update_entity_position(entity_id, current_cell.x, current_cell.y)
	player_moved.emit(from, current_cell)

	# Re-check grounded after landing (primary detector for Scenario B falls).
	# Guard: entity_landed (Scenario A) may have already set state to IDLE,
	# possibly starting a buffered move (MOVING). Do not override that.
	if _state == State.FALLING and _gravity.is_grounded(current_cell.x, current_cell.y):
		_state = State.IDLE
		_consume_buffered_input()


## Consume and re-validate the 1-slot input buffer. Idempotent — safe to call
## when the buffer is empty. Re-validates at consumption time (EC-01: the
## terrain or gravity state may have changed since the input was buffered).
func _consume_buffered_input() -> void:
	if not _has_buffered_input:
		return
	var dir: Vector2i = _buffered_input
	_buffered_input = Vector2i.ZERO
	_has_buffered_input = false
	_validate_and_move(dir)
