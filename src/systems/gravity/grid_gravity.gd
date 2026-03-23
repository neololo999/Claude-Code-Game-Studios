## GridGravity — Discrete grid-based gravity system for Dig & Dash.
##
## Tracks registered entities, detects when their support cell changes via
## GridSystem.cell_changed, and emits entity_should_fall / entity_landed so
## consumers (PlayerMovement, EnemyAI) can execute the actual movement.
##
## is_grounded() is stateless — safe to call without registering an entity.
## cell_occupied() is injected into TerrainSystem.cell_occupied_check to
## prevent holes from closing while an entity occupies the cell (resolves OQ-01).
##
## Lifecycle: create → setup() → register_entity() → update_entity_position()
##            → unregister_entity() / reset()
##
## Implements: design/gdd/grid-gravity.md#GRAV-01
class_name GridGravity
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a registered entity loses its ground support.
## Consumers (PlayerMovement, EnemyAI) execute the actual fall movement.
signal entity_should_fall(entity_id: int)

## Emitted when a falling entity reaches a grounded cell.
## Only emitted after a prior entity_should_fall — not on every grounded move.
signal entity_landed(entity_id: int)

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _grid: GridSystem
var _terrain: TerrainSystem
var _config: GravityConfig

## cell → Array of entity_ids on that cell.
var _entities: Dictionary = {}  # Vector2i → Array[int]

## entity_id → Vector2i (reverse lookup for fast position queries).
var _positions: Dictionary = {}  # int → Vector2i

## entity_ids currently immune to falling (actively digging).
var _digging_entities: Dictionary = {}  # int → bool

## entity_ids that received entity_should_fall but have not yet landed.
## Cleared in update_entity_position() when the entity reaches a grounded cell.
var _falling_entities: Dictionary = {}  # int → bool

## True once setup() has been called successfully.
var _is_loaded: bool = false

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Inject dependencies. Call before any other method.
##
## Connects to p_grid.cell_changed and injects cell_occupied into
## p_terrain.cell_occupied_check (resolves OQ-01 from terrain GDD).
## If p_config is null a default GravityConfig is created automatically.
func setup(p_grid: GridSystem, p_terrain: TerrainSystem, p_config: GravityConfig = null) -> void:
	_grid = p_grid
	_terrain = p_terrain
	_config = p_config if p_config != null else GravityConfig.new()
	_is_loaded = true
	_grid.cell_changed.connect(_on_cell_changed)
	_terrain.cell_occupied_check = cell_occupied


## Register entity at initial position.
##
## Must be called before is_grounded queries for signals to work.
## Stateless is_grounded() works without registration.
## Re-registering an already-registered entity moves it to the new position.
func register_entity(entity_id: int, col: int, row: int) -> void:
	# Remove from previous cell if already tracked.
	if _positions.has(entity_id):
		_remove_from_cell(entity_id, _positions[entity_id])
	var cell := Vector2i(col, row)
	_positions[entity_id] = cell
	if not _entities.has(cell):
		_entities[cell] = []
	if not (entity_id in _entities[cell]):
		_entities[cell].append(entity_id)


## Unregister entity (on death, level unload, etc).
##
## Safe to call for an entity that was never registered — no-op.
func unregister_entity(entity_id: int) -> void:
	if _positions.has(entity_id):
		_remove_from_cell(entity_id, _positions[entity_id])
		_positions.erase(entity_id)
	_digging_entities.erase(entity_id)
	_falling_entities.erase(entity_id)


## Update entity's tracked position. Call after every movement step.
##
## Moves the entity from its previous cell to (col, row).
## If the entity was falling and the new position is grounded, emits entity_landed.
func update_entity_position(entity_id: int, col: int, row: int) -> void:
	register_entity(entity_id, col, row)
	# Detect landing: entity was falling and has reached a supported cell.
	if _falling_entities.get(entity_id, false) and is_grounded(col, row):
		_falling_entities.erase(entity_id)
		entity_landed.emit(entity_id)


## Returns true if the entity at (col, row) is supported.
##
## Stateless — safe to call without registering.
## is_grounded = is_solid(col, row+1) OR is_climbable(col, row)
## Special case: row+1 >= rows → treated as solid (invisible floor, EC-01).
func is_grounded(col: int, row: int) -> bool:
	if not _is_loaded:
		return true  # safe default before setup()
	# Bottom of grid = implicit floor (EC-01).
	if row + 1 >= _grid.rows:
		return true
	# On LADDER or ROPE → always grounded (EC-03).
	if _terrain.is_climbable(col, row):
		return true
	# Cell below is solid.
	return _terrain.is_solid(col, row + 1)


## Returns true if at least one entity is registered at (col, row).
##
## Injected into TerrainSystem.cell_occupied_check to block hole closing (OQ-01).
## Safe to call before setup() — returns false when registry is empty.
func cell_occupied(col: int, row: int) -> bool:
	return _entities.has(Vector2i(col, row))


## Set dig immunity for an entity. While immune, entity_should_fall is suppressed.
##
## Called by Dig System: notify_digging(entity_id, true) on dig start,
## notify_digging(entity_id, false) on dig end (EC-04).
func notify_digging(entity_id: int, is_digging: bool) -> void:
	if is_digging:
		_digging_entities[entity_id] = true
	else:
		_digging_entities.erase(entity_id)


## Clear all registered entities. Called by Level System on restart/unload.
##
## Does not disconnect from GridSystem.cell_changed — the system remains
## ready to accept new registrations for the next level (EC-07).
func reset() -> void:
	_entities.clear()
	_positions.clear()
	_digging_entities.clear()
	_falling_entities.clear()

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Remove entity_id from the cell array. Erases the cell key when empty.
func _remove_from_cell(entity_id: int, cell: Vector2i) -> void:
	if _entities.has(cell):
		_entities[cell].erase(entity_id)
		if _entities[cell].is_empty():
			_entities.erase(cell)

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

## React to a terrain cell change. If the changed cell was directly below a
## registered entity, re-evaluate that entity's grounded status and emit
## entity_should_fall if it is no longer supported.
func _on_cell_changed(col: int, row: int, _old_id: int, _new_id: int) -> void:
	# Only cells directly below registered entities matter (EC-06).
	var above_cell: Vector2i = Vector2i(col, row - 1)
	if not _entities.has(above_cell):
		return
	# Duplicate to iterate safely — entity_should_fall consumers may mutate
	# the registry (e.g. unregister_entity) during signal handling.
	var entity_ids: Array = _entities[above_cell].duplicate()
	for entity_id: int in entity_ids:
		# Skip digging-immune entities (EC-04).
		if _digging_entities.get(entity_id, false):
			continue
		# Re-evaluate grounded status with the updated cell data.
		if not is_grounded(col, row - 1):
			_falling_entities[entity_id] = true
			entity_should_fall.emit(entity_id)
