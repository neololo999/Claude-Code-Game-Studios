## TerrainSystem — Tile property queries and dig state machine for Dig & Dash.
##
## Provides per-cell property queries (traversable, solid, climbable, destructible)
## and drives the full dig cycle (INTACT → DIGGING → OPEN → CLOSING → INTACT)
## using _process-based timers for full pause/reset/inspection control.
##
## Lifecycle: UNINITIALIZED → LOADED
##   All accessors require LOADED state; violations return safe defaults.
##
## Usage:
##   1. Add TerrainSystem as a child of your Level node.
##   2. Call setup(grid, config) to inject dependencies.
##   3. Call initialize(cell_data, cols, rows) with level data.
##   4. Query properties and call dig_request() from the Dig System.
##   5. Call reset() on level restart.
##
## Implements: design/gdd/terrain-system.md#TERR-01, #TERR-02
class_name TerrainSystem
extends Node

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

## Tile type identifiers. Values match the flat cell_data integer array.
enum TileType {
	EMPTY     = 0,
	SOLID     = 1,
	DIRT_SLOW = 2,
	DIRT_FAST = 3,
	LADDER    = 4,
	ROPE      = 5,
}

## Dig state for destructible cells (DIRT_SLOW, DIRT_FAST).
enum DigState {
	INTACT  = 0,
	DIGGING = 1,
	OPEN    = 2,
	CLOSING = 3,
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted on every dig state transition for destructible cells.
signal dig_state_changed(col: int, row: int, old_state: DigState, new_state: DigState)

# ---------------------------------------------------------------------------
# Public variables
# ---------------------------------------------------------------------------

## Cell occupancy hook — injected by GridGravity (resolves OQ-01).
## TerrainSystem calls this Callable(col, row) → bool before CLOSING → INTACT.
## When the callable returns true the close is deferred by 0.1 s (polling).
## Default: Callable() (no check — always close immediately).
var cell_occupied_check: Callable = Callable()

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _grid: GridSystem = null
var _config: TerrainConfig = null
var _is_loaded: bool = false

## Active dig states per destructible cell.
## Key = Vector2i(col, row), Value = DigState (stored as int).
var _dig_states: Dictionary[Vector2i, int] = {}

## Seconds remaining on each active dig timer.
## Key = Vector2i(col, row), Value = float (seconds).
var _dig_timers: Dictionary[Vector2i, float] = {}

## Original TileType for each cell mid-dig, so it can be restored on close.
## Key = Vector2i(col, row), Value = TileType (stored as int).
var _original_types: Dictionary[Vector2i, int] = {}

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_process(false)


## Tick all active dig timers. Advances state when a timer expires.
## _process is disabled when _dig_states is empty (no active digs).
func _process(delta: float) -> void:
	if _dig_states.is_empty():
		set_process(false)
		return
	# Iterate over a snapshot so _advance_state can mutate the dict safely.
	var cells: Array[Vector2i] = _dig_states.keys()
	for cell: Vector2i in cells:
		_dig_timers[cell] -= delta
		if _dig_timers[cell] <= 0.0:
			_advance_state(cell.x, cell.y)

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Inject dependencies. Must be called before initialize().
## If p_config is null a default TerrainConfig is created automatically.
func setup(p_grid: GridSystem, p_config: TerrainConfig = null) -> void:
	_grid = p_grid
	_config = p_config if p_config != null else TerrainConfig.new()
	_validate_config()


## Initialize terrain from a flat int array (row-major). Called by Level System.
## Validates all tile IDs; unknown IDs are substituted with EMPTY + push_warning (EC-03).
## Also initializes the injected GridSystem with the sanitized data.
func initialize(cell_data: Array[int], p_cols: int, p_rows: int) -> void:
	if _grid == null:
		push_error("TerrainSystem.initialize: call setup() before initialize().")
		return
	if p_cols <= 0 or p_rows <= 0:
		push_error(
			"TerrainSystem.initialize: cols and rows must be > 0 (got %d, %d)"
			% [p_cols, p_rows]
		)
		return

	# Validate each tile ID and substitute unknowns with EMPTY (EC-03).
	var valid_ids: Array = TileType.values()
	var sanitized: Array[int] = []
	sanitized.resize(cell_data.size())
	for i: int in range(cell_data.size()):
		var raw_id: int = cell_data[i]
		if raw_id not in valid_ids:
			push_warning(
				"TerrainSystem.initialize: unknown tile ID %d at index %d — substituting EMPTY."
				% [raw_id, i]
			)
			sanitized[i] = TileType.EMPTY
		else:
			sanitized[i] = raw_id

	_grid.initialize(p_cols, p_rows, sanitized)
	_is_loaded = true


## Reset all cells to INTACT and cancel all active timers atomically.
## Restores every dug cell to its original tile type in the GridSystem.
## No dig_state_changed signals are emitted during reset.
## Called by Level System on restart.
func reset() -> void:
	if not _is_loaded:
		return
	for cell: Vector2i in _dig_states.keys():
		var original: int = _original_types.get(cell, TileType.EMPTY)
		_grid.set_cell(cell.x, cell.y, original)
	_dig_states.clear()
	_dig_timers.clear()
	_original_types.clear()
	set_process(false)
	_reload_tile_types()

# ---------------------------------------------------------------------------
# Public methods — Property queries
# ---------------------------------------------------------------------------

## Return true if an entity can move through this cell.
## DIRT_SLOW / DIRT_FAST are traversable only when OPEN or CLOSING.
## Out-of-bounds → false (OQ-03: treated as SOLID wall).
func is_traversable(col: int, row: int) -> bool:
	var tile: TileType = get_tile_type(col, row)
	if tile == TileType.DIRT_SLOW or tile == TileType.DIRT_FAST:
		var state: DigState = get_dig_state(col, row)
		return state == DigState.OPEN or state == DigState.CLOSING
	return (
		tile == TileType.EMPTY
		or tile == TileType.LADDER
		or tile == TileType.ROPE
	)


## Return true if this cell blocks movement (solid to physics).
## DIRT_SLOW / DIRT_FAST are solid only when INTACT or DIGGING.
## Out-of-bounds → true (OQ-03: treated as SOLID wall).
func is_solid(col: int, row: int) -> bool:
	var tile: TileType = get_tile_type(col, row)
	if tile == TileType.DIRT_SLOW or tile == TileType.DIRT_FAST:
		var state: DigState = get_dig_state(col, row)
		return state == DigState.INTACT or state == DigState.DIGGING
	return tile == TileType.SOLID or tile == TileType.LADDER


## Return true if an entity can climb this cell.
## Only LADDER and ROPE are climbable. Out-of-bounds → false.
func is_climbable(col: int, row: int) -> bool:
	var tile: TileType = get_tile_type(col, row)
	return tile == TileType.LADDER or tile == TileType.ROPE


## Return true if the tile can be dug by the player.
## Only DIRT_SLOW and DIRT_FAST are destructible. Out-of-bounds → false.
func is_destructible(col: int, row: int) -> bool:
	var tile: TileType = get_tile_type(col, row)
	return tile == TileType.DIRT_SLOW or tile == TileType.DIRT_FAST


## Return the TileType for (col, row).
## For cells that are currently mid-dig (OPEN / CLOSING), returns the
## original tile type — not EMPTY — so callers always know the dirt flavour.
## Out-of-bounds → TileType.SOLID (OQ-03 safe default).
func get_tile_type(col: int, row: int) -> TileType:
	if not _is_loaded or not _grid.is_valid(col, row):
		return TileType.SOLID
	var cell: Vector2i = Vector2i(col, row)
	if _original_types.has(cell):
		return _original_types[cell] as TileType
	return _grid.get_cell(col, row) as TileType

# ---------------------------------------------------------------------------
# Public methods — Dig state queries
# ---------------------------------------------------------------------------

## Return the DigState for (col, row).
## Returns INTACT for cells that have no active dig state entry.
func get_dig_state(col: int, row: int) -> DigState:
	var cell: Vector2i = Vector2i(col, row)
	if _dig_states.has(cell):
		return _dig_states[cell] as DigState
	return DigState.INTACT


## Return the seconds remaining on the active dig timer for (col, row).
## Returns 0.0 for cells with no active timer.
func get_dig_timer_remaining(col: int, row: int) -> float:
	var cell: Vector2i = Vector2i(col, row)
	if _dig_timers.has(cell):
		return maxf(_dig_timers[cell], 0.0)
	return 0.0

# ---------------------------------------------------------------------------
# Public methods — Dig command
# ---------------------------------------------------------------------------

## Request a dig at (col, row). Called by the Dig System.
## Silently rejected when:
##   - TerrainSystem is not loaded
##   - coords are out of bounds
##   - cell is not destructible (not DIRT_SLOW or DIRT_FAST)
##   - cell is not in INTACT state (already digging, open, or closing)
func dig_request(col: int, row: int) -> void:
	if not _is_loaded:
		return
	if not _grid.is_valid(col, row):
		return
	if not is_destructible(col, row):
		return
	if get_dig_state(col, row) != DigState.INTACT:
		return

	var cell: Vector2i = Vector2i(col, row)
	# Preserve the original tile type so we can restore it when the hole closes.
	_original_types[cell] = _grid.get_cell(col, row)

	# Transition: INTACT → DIGGING
	_dig_states[cell] = DigState.DIGGING
	_dig_timers[cell] = _config.dig_duration
	dig_state_changed.emit(col, row, DigState.INTACT, DigState.DIGGING)
	set_process(true)

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Drive the dig state machine for a single cell.
## Called by _process when a cell's timer expires.
func _advance_state(col: int, row: int) -> void:
	var cell: Vector2i = Vector2i(col, row)
	if not _dig_states.has(cell):
		return

	var current: int = _dig_states[cell]

	match current:
		DigState.DIGGING:
			# DIGGING → OPEN: make the hole real in the GridSystem.
			var close_time: float = (
				_config.dig_close_fast
				if _original_types.get(cell, TileType.EMPTY) == TileType.DIRT_FAST
				else _config.dig_close_slow
			)
			_dig_states[cell] = DigState.OPEN
			_dig_timers[cell] = close_time
			_grid.set_cell(col, row, TileType.EMPTY)
			dig_state_changed.emit(col, row, DigState.DIGGING, DigState.OPEN)

		DigState.OPEN:
			# OPEN → CLOSING: begin closing animation.
			_dig_states[cell] = DigState.CLOSING
			_dig_timers[cell] = _config.closing_duration
			dig_state_changed.emit(col, row, DigState.OPEN, DigState.CLOSING)

		DigState.CLOSING:
			# CLOSING → INTACT: restore the cell unless an entity is inside.
			if cell_occupied_check.is_valid():
				if cell_occupied_check.call(col, row):
					# Cell occupied — re-poll in 0.1 s.
					_dig_timers[cell] = 0.1
					return
			# Restore: erase state first, then set_cell so any cell_changed
			# listener sees a clean terrain state.
			var original: int = _original_types.get(cell, TileType.EMPTY)
			_dig_states.erase(cell)
			_dig_timers.erase(cell)
			_original_types.erase(cell)
			_grid.set_cell(col, row, original)
			dig_state_changed.emit(col, row, DigState.CLOSING, DigState.INTACT)


## Validate TerrainConfig invariant: dig_close_fast < dig_close_slow.
## Logs a warning (not an error) so designers are notified without crashing.
func _validate_config() -> void:
	if _config.dig_close_fast >= _config.dig_close_slow:
		push_warning(
			"TerrainConfig invariant violated: dig_close_fast (%f) >= dig_close_slow (%f). "
			% [_config.dig_close_fast, _config.dig_close_slow]
			+ "Expected: DIG_CLOSE_FAST < DIG_CLOSE_SLOW."
		)


## Source-of-truth note: after reset(), the GridSystem holds the authoritative
## tile data and _original_types has been cleared, so no re-read is required.
## This method is a hook for future extensions (e.g. multi-layer terrain).
func _reload_tile_types() -> void:
	pass  # Grid is the canonical source; _original_types cleared by reset().
