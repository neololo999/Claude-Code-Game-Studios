## GridSystem — 2D rectangular grid infrastructure for Dig & Dash.
##
## Stores terrain IDs (int) per cell in a flat Array[int] (row-major).
## Does NOT store entities. Does NOT resize after initialization.
##
## Coordinate convention: (col, row) — (0,0) = top-left, col right, row down.
##
## Lifecycle: UNINITIALIZED → LOADED → UNLOADED
##   All accessors require LOADED state; violations push an error and return a
##   safe default (-1 for int, Vector2.ZERO for Vector2, etc.).
##
## Usage:
##   1. Add GridSystem as a child of your Level node.
##   2. Call initialize(cols, rows, cell_data) after loading level data.
##   3. Use get_cell / set_cell / grid_to_world / world_to_grid as needed.
##   4. Call unload() when the level is torn down.
##
## Implements: design/gdd/grid-system.md
class_name GridSystem
extends Node

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

## Global default cell size in pixels.
## Constant — do NOT vary per level (see design/gdd/grid-system.md §Open Questions).
const CELL_SIZE: int = 32

## Lifecycle states.
enum State {
	UNINITIALIZED, ## Before initialize() is called, or after unload().
	LOADED,        ## Grid is fully populated and usable.
	UNLOADED,      ## Alias for UNINITIALIZED; set by unload().
}

## 4-directional neighbour offsets (up, down, left, right).
const _NEIGHBOR_OFFSETS: Array = [
	Vector2i( 0, -1),  # up
	Vector2i( 0,  1),  # down
	Vector2i(-1,  0),  # left
	Vector2i( 1,  0),  # right
]

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a cell's terrain ID changes via set_cell().
## Also emitted when old_id == new_id (simplicity over optimisation;
## TerrainSystem is responsible for deduplication if needed).
signal cell_changed(col: int, row: int, old_id: int, new_id: int)

# ---------------------------------------------------------------------------
# Public variables
# ---------------------------------------------------------------------------

## Number of columns. Valid (non-zero) only while LOADED.
var cols: int = 0

## Number of rows. Valid (non-zero) only while LOADED.
var rows: int = 0

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _state: State = State.UNINITIALIZED

## Flat, row-major storage: index = row * cols + col.
var _cells: Array[int] = []

## Reentrancy guard: true while cell_changed is being emitted.
## A set_cell() call that arrives during emission is deferred.
var _is_emitting: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_state = State.UNINITIALIZED
	_cells.clear()
	cols = 0
	rows = 0
	_is_emitting = false

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Populate the grid with p_cols × p_rows cells.
##
## cell_data: optional flat Array of terrain IDs (row-major order).
##   - If empty, all cells are initialised to 0.
##   - If shorter than cols × rows, remaining cells are filled with 0.
##   - Extra entries beyond cols × rows are silently ignored.
##
## Transition: UNINITIALIZED/UNLOADED → LOADED.
func initialize(p_cols: int, p_rows: int, cell_data: Array = []) -> void:
	if p_cols <= 0 or p_rows <= 0:
		push_error(
			"GridSystem.initialize: cols and rows must be > 0 (got %d, %d)" \
			% [p_cols, p_rows]
		)
		return
	cols = p_cols
	rows = p_rows
	_cells.resize(cols * rows)
	_cells.fill(0)
	if not cell_data.is_empty():
		var limit: int = mini(cell_data.size(), _cells.size())
		for i: int in range(limit):
			_cells[i] = int(cell_data[i])
	_state = State.LOADED


## Free all grid data and reset to UNINITIALIZED.
##
## Transition: LOADED → UNINITIALIZED.
func unload() -> void:
	_cells.clear()
	cols = 0
	rows = 0
	_is_emitting = false
	_state = State.UNINITIALIZED

# ---------------------------------------------------------------------------
# Public methods — Cell access
# ---------------------------------------------------------------------------

## Return the terrain ID stored at (col, row).
##
## Returns -1 and pushes an error if the grid is not LOADED or the coords
## are out of bounds.
func get_cell(col: int, row: int) -> int:
	if not _guard_loaded("get_cell"):
		return -1
	if not is_valid(col, row):
		push_error(
			"GridSystem.get_cell: coords (%d, %d) out of bounds (grid %d×%d)" \
			% [col, row, cols, rows]
		)
		return -1
	return _cells[row * cols + col]


## Write terrain_id to (col, row) and emit cell_changed.
##
## If called while cell_changed is already being emitted (reentrancy), the
## call is automatically deferred via call_deferred so the current emission
## completes cleanly first.
##
## Note: cell_changed is emitted even when old_id == new_id.
func set_cell(col: int, row: int, terrain_id: int) -> void:
	if not _guard_loaded("set_cell"):
		return
	if not is_valid(col, row):
		push_error(
			"GridSystem.set_cell: coords (%d, %d) out of bounds (grid %d×%d)" \
			% [col, row, cols, rows]
		)
		return
	# Reentrancy guard: defer the call so the current emission finishes first.
	if _is_emitting:
		set_cell.call_deferred(col, row, terrain_id)
		return
	var old_id: int = _cells[row * cols + col]
	_cells[row * cols + col] = terrain_id
	_is_emitting = true
	cell_changed.emit(col, row, old_id, terrain_id)
	_is_emitting = false

# ---------------------------------------------------------------------------
# Public methods — Coordinate conversion
# ---------------------------------------------------------------------------

## Convert grid coordinates to the world-space centre of the cell.
##
## Formula: Vector2(col * CELL_SIZE + CELL_SIZE/2, row * CELL_SIZE + CELL_SIZE/2)
## Example: grid_to_world(2, 3) with CELL_SIZE=32 → Vector2(80, 112)
##
## Returns Vector2.ZERO and pushes an error if the grid is not LOADED.
func grid_to_world(col: int, row: int) -> Vector2:
	if not _guard_loaded("grid_to_world"):
		return Vector2.ZERO
	return Vector2(
		col * CELL_SIZE + CELL_SIZE / 2,
		row * CELL_SIZE + CELL_SIZE / 2
	)


## Convert a world-space position to the grid cell that contains it.
##
## Formula: Vector2i(floor(pos.x / CELL_SIZE), floor(pos.y / CELL_SIZE))
## Example: world_to_grid(Vector2(85, 115)) with CELL_SIZE=32 → Vector2i(2, 3)
##
## The result may lie outside valid bounds — always validate with is_valid().
## Returns Vector2i.ZERO and pushes an error if the grid is not LOADED.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	if not _guard_loaded("world_to_grid"):
		return Vector2i.ZERO
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE))
	)

# ---------------------------------------------------------------------------
# Public methods — Validation
# ---------------------------------------------------------------------------

## Return true if (col, row) lies within the grid bounds.
##
## Formula: (0 <= col < cols) and (0 <= row < rows)
## Safe to call in any lifecycle state — returns false when not LOADED.
func is_valid(col: int, row: int) -> bool:
	if _state != State.LOADED:
		return false
	return col >= 0 and col < cols and row >= 0 and row < rows

# ---------------------------------------------------------------------------
# Public methods — Neighbours
# ---------------------------------------------------------------------------

## Return the valid 4-directional neighbours (up, down, left, right) of (col, row).
##
## Only cells that pass is_valid() are included; corner/edge cells return
## fewer than 4 entries.  Returns an empty array if the grid is not LOADED.
func get_neighbors(col: int, row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _guard_loaded("get_neighbors"):
		return result
	for offset: Variant in _NEIGHBOR_OFFSETS:
		var off: Vector2i = offset as Vector2i
		var nc: int = col + off.x
		var nr: int = row + off.y
		if is_valid(nc, nr):
			result.append(Vector2i(nc, nr))
	return result

# ---------------------------------------------------------------------------
# Public methods — Dimensions
# ---------------------------------------------------------------------------

## Return the total world-space size of the grid in pixels.
##
## Formula: Vector2(cols * CELL_SIZE, rows * CELL_SIZE)
## Returns Vector2.ZERO and pushes an error if the grid is not LOADED.
func get_world_size() -> Vector2:
	if not _guard_loaded("get_world_size"):
		return Vector2.ZERO
	return Vector2(cols * CELL_SIZE, rows * CELL_SIZE)

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Return true if the grid is currently LOADED.
## Push an error naming the caller and return false otherwise.
func _guard_loaded(caller: String) -> bool:
	if _state != State.LOADED:
		push_error(
			"GridSystem.%s: grid is not LOADED (state: %s)" \
			% [caller, State.keys()[_state]]
		)
		return false
	return true
