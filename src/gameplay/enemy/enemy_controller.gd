## EnemyController — AI-driven 5-state entity for Dig & Dash.
##
## Implements a discrete-grid enemy with PATROL, CHASE (stub), FALLING,
## TRAPPED, and DEAD states.  Gravity integration is handled via GridGravity
## signals; timers are all _process-based for full reset() control.
##
## Lifecycle:
##   1. Add EnemyController as a child of your Level node.
##   2. Assign config (@export) or let setup() inject one.
##   3. Call setup() to inject system dependencies.
##   4. Call spawn() to place the enemy and enter PATROL.
##   5. Call reset() on level restart.
##
## Implementation notes vs. design spec (AI-02):
##   • entity_should_fall / entity_landed signals carry only entity_id (not
##     col/row as originally drafted).  Current cell is used for position.
##   • State.FALLING calls _process_falling() rather than being a no-op:
##     entity_landed() can only fire from GridGravity.update_entity_position(),
##     so the enemy must actively step downward during a fall.
##   • EC-01 (ledge detection) uses _gravity.is_grounded(next_col, next_row),
##     which already encapsulates the climbable exception and implicit floor.
##
## Implements: design/gdd/ai-system.md#AI-02
class_name EnemyController
extends Node2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Seconds per fall cell — mirrors PlayerMovement default (GDD tuning table).
const _FALL_SPEED: float = 0.1

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## AI state machine.
## CHASE is a stub in AI-02; full implementation deferred to AI-03.
enum State { PATROL, CHASE, FALLING, TRAPPED, DEAD }

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after every successful patrol or fall movement.
signal enemy_moved(enemy_id: int, from_cell: Vector2i, to_cell: Vector2i)

## Emitted when the enemy enters FALLING or TRAPPED state (lost footing).
signal enemy_fell(enemy_id: int)

## Emitted when the enemy lands in an OPEN (dug) cell and becomes TRAPPED.
signal enemy_trapped(enemy_id: int, cell: Vector2i)

## Emitted when the enemy respawns at the rescue position after DEAD state.
signal enemy_escaped(enemy_id: int)

## Emitted when the TRAPPED timer expires and the enemy transitions to DEAD.
signal enemy_died(enemy_id: int)

## Emitted when the enemy reaches the player's cell (CHASE — AI-03).
signal enemy_reached_player(enemy_id: int, cell: Vector2i)

# ---------------------------------------------------------------------------
# @export variables
# ---------------------------------------------------------------------------

## Enemy configuration resource.  Assign in the inspector or inject via setup().
@export var config: EnemyConfig

# ---------------------------------------------------------------------------
# Public variables
# ---------------------------------------------------------------------------

## Unique integer ID — assigned by Level System.  Read by GridGravity.
var enemy_id: int = 0

## Current grid cell.  Updated atomically after every successful move.
var current_cell: Vector2i = Vector2i.ZERO

# ---------------------------------------------------------------------------
# Private variables — system references
# ---------------------------------------------------------------------------

var _grid: GridSystem
var _terrain: TerrainSystem
var _gravity: GridGravity
var _player_movement: PlayerMovement

# ---------------------------------------------------------------------------
# Private variables — state
# ---------------------------------------------------------------------------

var _state: State = State.PATROL

## Horizontal patrol direction: +1 = right, -1 = left.
var _patrol_dir: int = 1

var _spawn_cell: Vector2i = Vector2i.ZERO

## Top-of-level rescue position used for respawn after DEAD state.
var _rescate_cell: Vector2i = Vector2i.ZERO

## Last known player cell — populated by _on_player_moved for AI-03 CHASE.
var _player_cell: Vector2i = Vector2i.ZERO

var _trap_timer: float = 0.0
var _respawn_timer: float = 0.0

## Countdown to next patrol step (seconds).  Reloaded to 1.0 / move_speed.
var _move_timer: float = 0.0

## Countdown to next fall step (seconds).  Reloaded to _FALL_SPEED.
var _fall_timer: float = 0.0

## True once setup() has completed successfully.
var _is_setup: bool = false

## Gravity-immunity flag — kept for parity with PlayerMovement; not actively
## used by the enemy in AI-02 (enemies do not dig).
var _is_digging: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Disable _process until spawn() activates the enemy.
	set_process(false)


func _process(delta: float) -> void:
	if not _is_setup:
		return
	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_patrol(delta)   # stub — AI-03 replaces with CHASE logic
		State.FALLING:
			_process_falling(delta)
		State.TRAPPED:
			_process_trapped(delta)
		State.DEAD:
			_process_dead(delta)

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Inject system dependencies.  Must be called once before spawn().
##
## p_config: if non-null, overrides the @export config field.
## p_id:     sets enemy_id used in GridGravity and all signal payloads.
func setup(
	p_grid: GridSystem,
	p_terrain: TerrainSystem,
	p_gravity: GridGravity,
	p_player: PlayerMovement,
	p_config: EnemyConfig = null,
	p_id: int = 0,
) -> void:
	_grid = p_grid
	_terrain = p_terrain
	_gravity = p_gravity
	_player_movement = p_player
	if p_config != null:
		config = p_config
	enemy_id = p_id
	_gravity.entity_should_fall.connect(_on_entity_should_fall)
	_gravity.entity_landed.connect(_on_entity_landed)
	_player_movement.player_moved.connect(_on_player_moved)
	_is_setup = true


## Place the enemy at spawn_cell, register with GridGravity, and enter PATROL.
##
## spawn_cell:   starting grid position.
## rescate_cell: grid cell used for respawn after DEAD expires (top of level).
func spawn(spawn_cell: Vector2i, rescate_cell: Vector2i) -> void:
	_spawn_cell = spawn_cell
	_rescate_cell = rescate_cell
	current_cell = spawn_cell
	position = _grid.grid_to_world(spawn_cell.x, spawn_cell.y)
	_gravity.register_entity(enemy_id, spawn_cell.x, spawn_cell.y)
	_state = State.PATROL
	_patrol_dir = 1
	_move_timer = 1.0 / config.move_speed
	set_process(true)


## Reset the enemy to its spawn position, cancelling all active timers.
##
## Unregisters from GridGravity first to flush any stale _falling_entities
## state (important when reset() is called mid-fall).
func reset() -> void:
	_gravity.unregister_entity(enemy_id)
	_trap_timer = 0.0
	_respawn_timer = 0.0
	spawn(_spawn_cell, _rescate_cell)

# ---------------------------------------------------------------------------
# Private methods — State processors
# ---------------------------------------------------------------------------

## Advance one patrol step.  Called every frame while in PATROL (or CHASE stub).
##
## EC-01 (ledge avoidance): the enemy refuses to step onto a cell that is not
## supported from below, unless that cell is a LADDER or ROPE.  This check is
## delegated to _gravity.is_grounded(next_col, next_row), which already
## encapsulates the climbable exception and the implicit bottom-row floor.
func _process_patrol(delta: float) -> void:
	_move_timer -= delta
	if _move_timer > 0.0:
		return
	_move_timer = 1.0 / config.move_speed

	var next_col: int = current_cell.x + _patrol_dir
	var next_row: int = current_cell.y

	# Validate: in-bounds, traversable by an entity, and supported from below.
	var can_enter: bool = (
		_grid.is_valid(next_col, next_row)
		and _terrain.is_traversable(next_col, next_row)
		and _gravity.is_grounded(next_col, next_row)
	)

	if can_enter:
		var old_cell: Vector2i = current_cell
		current_cell = Vector2i(next_col, next_row)
		position = _grid.grid_to_world(current_cell.x, current_cell.y)
		_gravity.update_entity_position(enemy_id, current_cell.x, current_cell.y)
		enemy_moved.emit(enemy_id, old_cell, current_cell)
	else:
		_patrol_dir = -_patrol_dir


## Advance one fall step downward.  Called every frame while in FALLING.
##
## Two landing paths (mirrors PlayerMovement._execute_fall_step):
##   Scenario A (GridGravity-tracked): update_entity_position triggers
##     entity_landed → _on_entity_landed handles state transition.
##   Scenario B (self-triggered, entity not in _falling_entities): the
##     is_grounded re-check at the end of this function is the sole
##     landing detector.
func _process_falling(delta: float) -> void:
	_fall_timer -= delta
	if _fall_timer > 0.0:
		return
	_fall_timer += _FALL_SPEED

	# Safety: already grounded (e.g. entity_landed fired and set state to
	# PATROL before this tick completed).
	if _gravity.is_grounded(current_cell.x, current_cell.y):
		_state = State.PATROL
		return

	var next: Vector2i = Vector2i(current_cell.x, current_cell.y + 1)

	# Guard: below grid bounds (is_grounded bottom-row check should have
	# caught this, but protect against edge cases).
	if not _grid.is_valid(next.x, next.y):
		_state = State.PATROL
		return

	var old_cell: Vector2i = current_cell
	current_cell = next
	position = _grid.grid_to_world(current_cell.x, current_cell.y)
	# Scenario A: if entity was in _falling_entities, entity_landed fires here
	# when grounded → _on_entity_landed sets state (may transition to TRAPPED).
	_gravity.update_entity_position(enemy_id, current_cell.x, current_cell.y)
	enemy_moved.emit(enemy_id, old_cell, current_cell)

	# Scenario B: entity_landed won't fire — detect landing manually.
	if _state == State.FALLING and _gravity.is_grounded(current_cell.x, current_cell.y):
		_state = State.PATROL


## Countdown the trap timer.  When it expires the enemy transitions to DEAD.
func _process_trapped(delta: float) -> void:
	_trap_timer -= delta
	if _trap_timer <= 0.0:
		_trigger_respawn()


## Countdown the respawn timer.  When it expires the enemy teleports to the
## rescue cell and re-enters PATROL.
func _process_dead(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		current_cell = _rescate_cell
		position = _grid.grid_to_world(_rescate_cell.x, _rescate_cell.y)
		# Re-register at the new position so GridGravity tracks the entity.
		_gravity.register_entity(enemy_id, _rescate_cell.x, _rescate_cell.y)
		_state = State.PATROL
		_patrol_dir = 1
		_move_timer = 1.0 / config.move_speed
		enemy_escaped.emit(enemy_id)

# ---------------------------------------------------------------------------
# Private methods — Helpers
# ---------------------------------------------------------------------------

## Transition from TRAPPED to DEAD: emit the died signal and arm the respawn
## timer.  Called by _process_trapped when the trap timer expires.
func _trigger_respawn() -> void:
	enemy_died.emit(enemy_id)
	_state = State.DEAD
	_respawn_timer = config.respawn_delay

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

## Connected to GridGravity.entity_should_fall in setup().
##
## If the current cell is an OPEN (dug) hole the enemy is immediately TRAPPED.
## Otherwise the enemy enters FALLING and _process_falling drives the descent.
## enemy_fell is emitted in both cases.
##
## Note: signal carries only entity_id — position is read from current_cell.
func _on_entity_should_fall(entity_id: int) -> void:
	if entity_id != enemy_id:
		return
	# TRAPPED and DEAD states are already resolved — no re-entry.
	if _state == State.TRAPPED or _state == State.DEAD:
		return
	var dig_state: TerrainSystem.DigState = _terrain.get_dig_state(
		current_cell.x, current_cell.y
	)
	if dig_state == TerrainSystem.DigState.OPEN:
		_state = State.TRAPPED
		_trap_timer = config.trap_escape_time
		enemy_trapped.emit(enemy_id, current_cell)
	else:
		_state = State.FALLING
		_fall_timer = _FALL_SPEED
	enemy_fell.emit(enemy_id)


## Connected to GridGravity.entity_landed in setup().
##
## Checks whether the landing cell is an OPEN (dug) hole.  If so the enemy
## becomes TRAPPED; otherwise it resumes PATROL.
## AI-03 will add a CHASE re-evaluation here instead of plain PATROL.
##
## Note: signal carries only entity_id — position is read from current_cell,
## which has already been updated by _process_falling steps.
func _on_entity_landed(entity_id: int) -> void:
	if entity_id != enemy_id:
		return
	var dig_state: TerrainSystem.DigState = _terrain.get_dig_state(
		current_cell.x, current_cell.y
	)
	if dig_state == TerrainSystem.DigState.OPEN:
		_state = State.TRAPPED
		_trap_timer = config.trap_escape_time
		enemy_trapped.emit(enemy_id, current_cell)
	else:
		_state = State.PATROL


## Connected to PlayerMovement.player_moved in setup().
##
## Stores the latest player cell so AI-03 CHASE logic can reference it.
func _on_player_moved(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	_player_cell = to_cell
