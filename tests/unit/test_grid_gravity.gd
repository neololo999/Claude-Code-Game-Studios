## Unit tests for GridGravity — GRAV-01.
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Test grid layout (5 × 5):
##   Row 0: [ E,  E,  E, E, E ]   E = EMPTY  (0)
##   Row 1: [ E,  E,  E, E, E ]   S = SOLID  (1)
##   Row 2: [ E,  E,  L, E, E ]   L = LADDER (4)
##   Row 3: [ E,  E,  E, E, E ]
##   Row 4: [ S,  S,  S, S, S ]   — solid floor
##
## Covers: AC-01 through AC-08
extends Node


# ---------------------------------------------------------------------------
# Test constants
# ---------------------------------------------------------------------------

const _TEST_COLS: int = 5
const _TEST_ROWS: int = 5

## Flat row-major tile data matching the layout above.
const _TEST_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0 — all EMPTY
	0, 0, 0, 0, 0,  # row 1 — all EMPTY
	0, 0, 4, 0, 0,  # row 2 — LADDER at (2,2)
	0, 0, 0, 0, 0,  # row 3 — all EMPTY
	1, 1, 1, 1, 1,  # row 4 — SOLID floor
]

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	_run_all_tests()


func _run_all_tests() -> void:
	print("=== GridGravity Tests ===")
	_test_ac01_grounded_solid_below()
	_test_ac02_not_grounded_empty_below()
	_test_ac03_grounded_on_ladder()
	_test_ac04_cell_changed_triggers_fall()
	_test_ac05_cell_occupied()
	_test_ac06_reset_clears_occupied()
	_test_ac07_grounded_at_bottom_row()
	_test_ac08_dig_immunity()
	print("=== Done ===")

# ---------------------------------------------------------------------------
# AC-01 — Entity with SOLID at row+1 → is_grounded = true
# ---------------------------------------------------------------------------

func _test_ac01_grounded_solid_below() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# Entity at (0, 3): row+1 = 4, which is SOLID floor.
	var result: bool = gravity.is_grounded(0, 3)

	if result == true:
		print("[PASS] AC-01: entity with SOLID at row+1 → is_grounded = true")
	else:
		print("[FAIL] AC-01: entity with SOLID at row+1 — expected true got %s" % result)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-02 — Entity with EMPTY at row+1 (not on LADDER/ROPE) → is_grounded = false
# ---------------------------------------------------------------------------

func _test_ac02_not_grounded_empty_below() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# Entity at (0, 0): row+1 = 1, which is EMPTY. Not on LADDER/ROPE.
	var result: bool = gravity.is_grounded(0, 0)

	if result == false:
		print("[PASS] AC-02: entity with EMPTY at row+1 (not on LADDER) → is_grounded = false")
	else:
		print("[FAIL] AC-02: entity with EMPTY at row+1 — expected false got %s" % result)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-03 — Entity on LADDER → is_grounded = true regardless of cell below
# ---------------------------------------------------------------------------

func _test_ac03_grounded_on_ladder() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# Entity at (2, 2): LADDER at this cell. Cell below (2, 3) is EMPTY.
	# is_climbable(2, 2) = true → grounded regardless of below.
	var result: bool = gravity.is_grounded(2, 2)

	if result == true:
		print("[PASS] AC-03: entity on LADDER → is_grounded = true (cell below is EMPTY)")
	else:
		print("[FAIL] AC-03: entity on LADDER — expected true got %s" % result)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-04 — cell_changed on cell directly below entity → entity_should_fall emitted
# ---------------------------------------------------------------------------

func _test_ac04_cell_changed_triggers_fall() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# Register entity 1 at (0, 3) — supported by SOLID at (0, 4).
	gravity.register_entity(1, 0, 3)

	var fired_entity_id: int = -1
	gravity.entity_should_fall.connect(
		func(entity_id: int) -> void:
			fired_entity_id = entity_id
	)

	# Simulate digging the floor cell directly below the entity.
	# grid.set_cell triggers cell_changed → _on_cell_changed → entity_should_fall.
	grid.set_cell(0, 4, 0)  # SOLID (1) → EMPTY (0)

	if fired_entity_id == 1:
		print("[PASS] AC-04: cell_changed on cell below entity → entity_should_fall(1) emitted")
	else:
		print("[FAIL] AC-04: cell_changed below entity — expected entity_should_fall(1) got id=%d" % fired_entity_id)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-05 — cell_occupied(col, row) → true iff entity registered there
# ---------------------------------------------------------------------------

func _test_ac05_cell_occupied() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	gravity.register_entity(2, 1, 1)

	var occupied_at_entity: bool = gravity.cell_occupied(1, 1)
	var occupied_at_empty: bool = gravity.cell_occupied(2, 2)

	var ok: bool = occupied_at_entity == true and occupied_at_empty == false
	if ok:
		print("[PASS] AC-05: cell_occupied → true at registered cell, false at unoccupied cell")
	else:
		print(
			"[FAIL] AC-05: cell_occupied — at (1,1) expected true got %s; at (2,2) expected false got %s"
			% [occupied_at_entity, occupied_at_empty]
		)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-06 — reset() → cell_occupied returns false everywhere
# ---------------------------------------------------------------------------

func _test_ac06_reset_clears_occupied() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	gravity.register_entity(1, 1, 1)
	gravity.register_entity(2, 3, 2)

	# Verify occupied before reset.
	var before_1: bool = gravity.cell_occupied(1, 1)
	var before_2: bool = gravity.cell_occupied(3, 2)

	gravity.reset()

	var after_1: bool = gravity.cell_occupied(1, 1)
	var after_2: bool = gravity.cell_occupied(3, 2)

	var ok: bool = (
		before_1 == true and before_2 == true
		and after_1 == false and after_2 == false
	)
	if ok:
		print("[PASS] AC-06: reset() clears entity registry → cell_occupied returns false everywhere")
	else:
		print(
			"[FAIL] AC-06: reset() — before: (1,1)=%s (3,2)=%s; after: (1,1)=%s (3,2)=%s"
			% [before_1, before_2, after_1, after_2]
		)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-07 — Entity at row = rows - 1 (bottom row) → is_grounded = true
# ---------------------------------------------------------------------------

func _test_ac07_grounded_at_bottom_row() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# Entity at row 4 = rows - 1 = 4. row+1 = 5 >= rows(5) → implicit floor (EC-01).
	var result: bool = gravity.is_grounded(0, 4)

	if result == true:
		print("[PASS] AC-07: entity at row=rows-1 → is_grounded = true (implicit floor EC-01)")
	else:
		print("[FAIL] AC-07: entity at bottom row — expected true got %s" % result)

	gravity.free()
	terrain.free()
	grid.free()


# ---------------------------------------------------------------------------
# AC-08 — notify_digging(true) suppresses entity_should_fall;
#          notify_digging(false) restores normal behaviour
# ---------------------------------------------------------------------------

func _test_ac08_dig_immunity() -> void:
	var grid: GridSystem = GridSystem.new()
	var terrain: TerrainSystem = TerrainSystem.new()
	var gravity: GridGravity = GridGravity.new()
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	gravity.register_entity(3, 0, 3)

	var fall_count: int = 0
	gravity.entity_should_fall.connect(
		func(_entity_id: int) -> void:
			fall_count += 1
	)

	# — Part A: immunity active — signal must NOT fire.
	gravity.notify_digging(3, true)
	grid.set_cell(0, 4, 0)  # remove SOLID floor under entity

	var count_after_immune: int = fall_count  # expected: 0

	# — Part B: restore floor, lift immunity, remove floor again — signal MUST fire.
	grid.set_cell(0, 4, 1)   # restore SOLID
	gravity.notify_digging(3, false)
	grid.set_cell(0, 4, 0)  # remove SOLID again

	var count_after_restored: int = fall_count  # expected: 1

	var ok: bool = count_after_immune == 0 and count_after_restored == 1
	if ok:
		print(
			"[PASS] AC-08: notify_digging(true) suppresses entity_should_fall; "
			+ "notify_digging(false) restores normal behaviour"
		)
	else:
		print(
			"[FAIL] AC-08: after immune dig expected 0 signals got %d; "
			+ "after immunity lifted expected 1 total got %d"
			% [count_after_immune, count_after_restored]
		)

	gravity.free()
	terrain.free()
	grid.free()
