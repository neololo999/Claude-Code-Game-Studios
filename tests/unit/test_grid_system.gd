## Manual unit tests for GridSystem.
##
## Run by adding this script as a child node in any test scene, or via
## Godot's built-in runner.  Each test prints "[PASS] AC-N: …" or
## "[FAIL] AC-N: … — expected X got Y".
##
## Covers all 10 Acceptance Criteria from design/gdd/grid-system.md.
extends Node


func _ready() -> void:
	_run_all_tests()


func _run_all_tests() -> void:
	print("=== GridSystem Tests ===")
	_test_ac1_grid_to_world()
	_test_ac2_world_to_grid()
	_test_ac3_origin()
	_test_ac4_invalid_negative()
	_test_ac5_valid_origin()
	_test_ac6_invalid_out_of_bounds()
	_test_ac7_neighbors_corner()
	_test_ac8_neighbors_center()
	_test_ac9_cell_changed_signal()
	_test_ac10_uninitialized_guard()
	print("=== Done ===")


# ---------------------------------------------------------------------------
# AC-1  grid_to_world(2, 3) with CELL_SIZE=32 → Vector2(80, 112)
# ---------------------------------------------------------------------------

func _test_ac1_grid_to_world() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: Vector2 = grid.grid_to_world(2, 3)
	var expected: Vector2 = Vector2(80.0, 112.0)
	if result == expected:
		print("[PASS] AC-1: grid_to_world(2, 3) → Vector2(80, 112)")
	else:
		print("[FAIL] AC-1: grid_to_world(2, 3) — expected %s got %s" % [expected, result])
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-2  world_to_grid(Vector2(85, 115)) → Vector2i(2, 3)
# ---------------------------------------------------------------------------

func _test_ac2_world_to_grid() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: Vector2i = grid.world_to_grid(Vector2(85.0, 115.0))
	var expected: Vector2i = Vector2i(2, 3)
	if result == expected:
		print("[PASS] AC-2: world_to_grid(Vector2(85, 115)) → Vector2i(2, 3)")
	else:
		print("[FAIL] AC-2: world_to_grid(Vector2(85, 115)) — expected %s got %s" % [expected, result])
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-3  grid_to_world(0, 0) → Vector2(16, 16)   (CELL_SIZE/2 offset)
# ---------------------------------------------------------------------------

func _test_ac3_origin() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: Vector2 = grid.grid_to_world(0, 0)
	var expected: Vector2 = Vector2(16.0, 16.0)
	if result == expected:
		print("[PASS] AC-3: grid_to_world(0, 0) → Vector2(16, 16)")
	else:
		print("[FAIL] AC-3: grid_to_world(0, 0) — expected %s got %s" % [expected, result])
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-4  is_valid(-1, 0) → false
# ---------------------------------------------------------------------------

func _test_ac4_invalid_negative() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: bool = grid.is_valid(-1, 0)
	if not result:
		print("[PASS] AC-4: is_valid(-1, 0) → false")
	else:
		print("[FAIL] AC-4: is_valid(-1, 0) — expected false got true")
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-5  is_valid(0, 0) → true  (after initialize)
# ---------------------------------------------------------------------------

func _test_ac5_valid_origin() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: bool = grid.is_valid(0, 0)
	if result:
		print("[PASS] AC-5: is_valid(0, 0) → true")
	else:
		print("[FAIL] AC-5: is_valid(0, 0) — expected true got false")
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-6  is_valid(cols, 0) → false
# ---------------------------------------------------------------------------

func _test_ac6_invalid_out_of_bounds() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: bool = grid.is_valid(grid.cols, 0)
	if not result:
		print("[PASS] AC-6: is_valid(cols, 0) → false")
	else:
		print("[FAIL] AC-6: is_valid(cols, 0) — expected false got true")
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-7  get_neighbors(0, 0) → exactly 2 entries  (top-left corner)
# ---------------------------------------------------------------------------

func _test_ac7_neighbors_corner() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: Array[Vector2i] = grid.get_neighbors(0, 0)
	if result.size() == 2:
		print("[PASS] AC-7: get_neighbors(0, 0) → 2 entries")
	else:
		print("[FAIL] AC-7: get_neighbors(0, 0) — expected 2 entries got %d" % result.size())
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-8  get_neighbors(1, 1) → exactly 4 entries  (interior cell)
# ---------------------------------------------------------------------------

func _test_ac8_neighbors_center() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	var result: Array[Vector2i] = grid.get_neighbors(1, 1)
	if result.size() == 4:
		print("[PASS] AC-8: get_neighbors(1, 1) → 4 entries")
	else:
		print("[FAIL] AC-8: get_neighbors(1, 1) — expected 4 entries got %d" % result.size())
	_free_grid(grid)


# ---------------------------------------------------------------------------
# AC-9  set_cell(2, 3, 1) emits cell_changed(2, 3, 0, 1)
# ---------------------------------------------------------------------------

func _test_ac9_cell_changed_signal() -> void:
	var grid: GridSystem = _make_grid(5, 5)
	add_child(grid)  # Must be in tree for deferred calls (not needed here, but good practice).

	var captured_col: int = -999
	var captured_row: int = -999
	var captured_old: int = -999
	var captured_new: int = -999
	var was_emitted: bool = false

	grid.cell_changed.connect(
		func(c: int, r: int, old_id: int, new_id: int) -> void:
			captured_col = c
			captured_row = r
			captured_old = old_id
			captured_new = new_id
			was_emitted = true
	)

	grid.set_cell(2, 3, 1)

	var ok: bool = (
		was_emitted
		and captured_col == 2
		and captured_row == 3
		and captured_old == 0
		and captured_new == 1
	)
	if ok:
		print("[PASS] AC-9: set_cell(2, 3, 1) emits cell_changed(2, 3, 0, 1)")
	else:
		print(
			"[FAIL] AC-9: cell_changed — expected (2,3,0,1) emitted=true"
			+ " | got (%d,%d,%d,%d) emitted=%s"
			% [captured_col, captured_row, captured_old, captured_new, was_emitted]
		)

	grid.queue_free()


# ---------------------------------------------------------------------------
# AC-10  get_cell before initialize() → returns -1, no crash
# ---------------------------------------------------------------------------

func _test_ac10_uninitialized_guard() -> void:
	var grid: GridSystem = GridSystem.new()
	# Deliberately NOT calling initialize().
	var result: int = grid.get_cell(0, 0)
	if result == -1:
		print("[PASS] AC-10: get_cell() before initialize returns -1, no crash")
	else:
		print("[FAIL] AC-10: get_cell() before initialize — expected -1, got %d" % result)
	grid.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Create a GridSystem, initialize it to p_cols × p_rows, and return it.
## The node is NOT added to the scene tree unless the test needs signals.
func _make_grid(p_cols: int, p_rows: int) -> GridSystem:
	var grid: GridSystem = GridSystem.new()
	grid.initialize(p_cols, p_rows)
	return grid


## Free a GridSystem that was not added to the scene tree.
func _free_grid(grid: GridSystem) -> void:
	grid.free()
