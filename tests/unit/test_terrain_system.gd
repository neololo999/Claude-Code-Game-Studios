## Unit tests for TerrainSystem — TERR-01 (property layer) + TERR-02 (dig state machine).
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Test grid layout (4 × 4):
##   Row 0: [ E,  E,  E, E ]   E  = EMPTY     (0)
##   Row 1: [ E,  S,  E, E ]   S  = SOLID     (1)
##   Row 2: [ E, DS, DF, E ]   DS = DIRT_SLOW (2)   DF = DIRT_FAST (3)
##   Row 3: [ E,  L,  R, E ]   L  = LADDER    (4)    R = ROPE      (5)
##
## Covers: AC-01 through AC-13 (AC-06 is a manual editor test, noted inline).
extends Node


# ---------------------------------------------------------------------------
# Test constants
# ---------------------------------------------------------------------------

const _TEST_COLS: int = 4
const _TEST_ROWS: int = 4

## Flat row-major tile data matching the layout above.
const _TEST_DATA: Array[int] = [
	0, 0, 0, 0,  # row 0 — all EMPTY
	0, 1, 0, 0,  # row 1 — SOLID at (1,1)
	0, 2, 3, 0,  # row 2 — DIRT_SLOW at (1,2), DIRT_FAST at (2,2)
	0, 4, 5, 0,  # row 3 — LADDER at (1,3), ROPE at (2,3)
]

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	await _run_all_tests()


func _run_all_tests() -> void:
	print("=== TerrainSystem Tests ===")

	# Synchronous property tests
	_test_ac01_traversable()
	_test_ac02_solid()
	_test_ac03_climbable()
	_test_ac04_destructible()
	_test_ac05_unknown_tile_id()
	print("[NOTE] AC-06: TerrainConfig.tres save/load — manual editor test, skipped in script.")
	_test_ac07_out_of_bounds()
	_test_ac11_dig_solid_rejected()
	_test_ac12_dig_open_rejected()

	# Asynchronous dig-cycle tests (use short timer values; await each)
	await _test_ac08_dig_intact_to_open()
	await _test_ac09_cell_returns_to_intact()
	await _test_ac10_dirt_fast_closes_before_slow()
	await _test_ac13_reset_with_active_timers()

	print("=== Done ===")

# ---------------------------------------------------------------------------
# AC-01 — is_traversable
# ---------------------------------------------------------------------------

func _test_ac01_traversable() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var ok: bool = (
		terrain.is_traversable(0, 0) == true   # EMPTY
		and terrain.is_traversable(1, 3) == true   # LADDER
		and terrain.is_traversable(2, 3) == true   # ROPE
		and terrain.is_traversable(1, 1) == false  # SOLID
		and terrain.is_traversable(1, 2) == false  # DIRT_SLOW (INTACT)
		and terrain.is_traversable(2, 2) == false  # DIRT_FAST (INTACT)
	)
	if ok:
		print("[PASS] AC-01: is_traversable — EMPTY/LADDER/ROPE true; SOLID/DIRT_SLOW/DIRT_FAST (intact) false")
	else:
		print(
			"[FAIL] AC-01: is_traversable — got EMPTY=%s LADDER=%s ROPE=%s SOLID=%s DS=%s DF=%s"
			% [
				terrain.is_traversable(0, 0),
				terrain.is_traversable(1, 3),
				terrain.is_traversable(2, 3),
				terrain.is_traversable(1, 1),
				terrain.is_traversable(1, 2),
				terrain.is_traversable(2, 2),
			]
		)

	terrain.free()


# ---------------------------------------------------------------------------
# AC-02 — is_solid
# ---------------------------------------------------------------------------

func _test_ac02_solid() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var ok: bool = (
		terrain.is_solid(1, 1) == true   # SOLID
		and terrain.is_solid(1, 2) == true   # DIRT_SLOW (INTACT)
		and terrain.is_solid(2, 2) == true   # DIRT_FAST (INTACT)
		and terrain.is_solid(1, 3) == true   # LADDER
		and terrain.is_solid(0, 0) == false  # EMPTY
		and terrain.is_solid(2, 3) == false  # ROPE
	)
	if ok:
		print("[PASS] AC-02: is_solid — SOLID/DIRT_SLOW/DIRT_FAST(intact)/LADDER true; EMPTY/ROPE false")
	else:
		print(
			"[FAIL] AC-02: is_solid — got SOLID=%s DS=%s DF=%s LADDER=%s EMPTY=%s ROPE=%s"
			% [
				terrain.is_solid(1, 1),
				terrain.is_solid(1, 2),
				terrain.is_solid(2, 2),
				terrain.is_solid(1, 3),
				terrain.is_solid(0, 0),
				terrain.is_solid(2, 3),
			]
		)

	terrain.free()


# ---------------------------------------------------------------------------
# AC-03 — is_climbable
# ---------------------------------------------------------------------------

func _test_ac03_climbable() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var ok: bool = (
		terrain.is_climbable(1, 3) == true   # LADDER
		and terrain.is_climbable(2, 3) == true   # ROPE
		and terrain.is_climbable(0, 0) == false  # EMPTY
		and terrain.is_climbable(1, 1) == false  # SOLID
		and terrain.is_climbable(1, 2) == false  # DIRT_SLOW
		and terrain.is_climbable(2, 2) == false  # DIRT_FAST
	)
	if ok:
		print("[PASS] AC-03: is_climbable — LADDER/ROPE true; EMPTY/SOLID/DIRT true=false")
	else:
		print(
			"[FAIL] AC-03: is_climbable — got LADDER=%s ROPE=%s EMPTY=%s SOLID=%s DS=%s DF=%s"
			% [
				terrain.is_climbable(1, 3),
				terrain.is_climbable(2, 3),
				terrain.is_climbable(0, 0),
				terrain.is_climbable(1, 1),
				terrain.is_climbable(1, 2),
				terrain.is_climbable(2, 2),
			]
		)

	terrain.free()


# ---------------------------------------------------------------------------
# AC-04 — is_destructible
# ---------------------------------------------------------------------------

func _test_ac04_destructible() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var ok: bool = (
		terrain.is_destructible(1, 2) == true   # DIRT_SLOW
		and terrain.is_destructible(2, 2) == true   # DIRT_FAST
		and terrain.is_destructible(0, 0) == false  # EMPTY
		and terrain.is_destructible(1, 1) == false  # SOLID
		and terrain.is_destructible(1, 3) == false  # LADDER
		and terrain.is_destructible(2, 3) == false  # ROPE
	)
	if ok:
		print("[PASS] AC-04: is_destructible — DIRT_SLOW/DIRT_FAST true; others false")
	else:
		print(
			"[FAIL] AC-04: is_destructible — got DS=%s DF=%s EMPTY=%s SOLID=%s LADDER=%s ROPE=%s"
			% [
				terrain.is_destructible(1, 2),
				terrain.is_destructible(2, 2),
				terrain.is_destructible(0, 0),
				terrain.is_destructible(1, 1),
				terrain.is_destructible(1, 3),
				terrain.is_destructible(2, 3),
			]
		)

	terrain.free()


# ---------------------------------------------------------------------------
# AC-05 — Unknown tile ID substituted with EMPTY; warning logged; no crash
# ---------------------------------------------------------------------------

func _test_ac05_unknown_tile_id() -> void:
	# ID 99 is not a valid TileType — should become EMPTY at (0,0).
	var bad_data: Array[int] = [
		99, 0, 0, 0,
		0,  1, 0, 0,
		0,  2, 3, 0,
		0,  4, 5, 0,
	]
	var terrain: TerrainSystem = _make_terrain(bad_data, _TEST_COLS, _TEST_ROWS)

	# Cell (0,0) should have been substituted to EMPTY.
	var tile: TerrainSystem.TileType = terrain.get_tile_type(0, 0)
	if tile == TerrainSystem.TileType.EMPTY:
		print("[PASS] AC-05: unknown tile ID 99 → substituted with EMPTY, no crash")
	else:
		print("[FAIL] AC-05: unknown tile ID 99 — expected EMPTY (%d) got %d" % [TerrainSystem.TileType.EMPTY, tile])

	terrain.free()


# ---------------------------------------------------------------------------
# AC-07 — Out-of-bounds query returns SOLID (safe default OQ-03)
# ---------------------------------------------------------------------------

func _test_ac07_out_of_bounds() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var tile_neg: TerrainSystem.TileType = terrain.get_tile_type(-1, 0)
	var tile_far: TerrainSystem.TileType = terrain.get_tile_type(100, 100)
	var solid_neg: bool = terrain.is_solid(-1, 0)
	var solid_far: bool = terrain.is_solid(100, 100)
	var trav_neg: bool = terrain.is_traversable(-1, 0)
	var trav_far: bool = terrain.is_traversable(100, 100)

	var ok: bool = (
		tile_neg == TerrainSystem.TileType.SOLID
		and tile_far == TerrainSystem.TileType.SOLID
		and solid_neg == true
		and solid_far == true
		and trav_neg == false
		and trav_far == false
	)
	if ok:
		print("[PASS] AC-07: out-of-bounds → get_tile_type=SOLID, is_solid=true, is_traversable=false")
	else:
		print(
			"[FAIL] AC-07: out-of-bounds — tile(-1,0)=%d tile(100,100)=%d solid(-1,0)=%s solid(100,100)=%s"
			% [tile_neg, tile_far, solid_neg, solid_far]
		)

	terrain.free()


# ---------------------------------------------------------------------------
# AC-08 — dig_request on DIRT_SLOW: INTACT → DIGGING → OPEN (async)
# ---------------------------------------------------------------------------

func _test_ac08_dig_intact_to_open() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	# State before dig.
	var state_before: TerrainSystem.DigState = terrain.get_dig_state(1, 2)

	terrain.dig_request(1, 2)
	var state_after_request: TerrainSystem.DigState = terrain.get_dig_state(1, 2)

	# Wait for dig_duration (0.05 s) + a small margin.
	await get_tree().create_timer(0.05 + 0.05).timeout

	var state_after_dig: TerrainSystem.DigState = terrain.get_dig_state(1, 2)
	var traversable_after_dig: bool = terrain.is_traversable(1, 2)
	var solid_after_dig: bool = terrain.is_solid(1, 2)

	var ok: bool = (
		state_before == TerrainSystem.DigState.INTACT
		and state_after_request == TerrainSystem.DigState.DIGGING
		and state_after_dig == TerrainSystem.DigState.OPEN
		and traversable_after_dig == true
		and solid_after_dig == false
	)
	if ok:
		print("[PASS] AC-08: dig_request DIRT_SLOW: INTACT→DIGGING→OPEN; traversable=true, solid=false when OPEN")
	else:
		print(
			"[FAIL] AC-08: before=%d after_req=%d after_dig=%d traversable=%s solid=%s"
			% [state_before, state_after_request, state_after_dig, traversable_after_dig, solid_after_dig]
		)

	terrain.queue_free()


# ---------------------------------------------------------------------------
# AC-09 — DIRT_SLOW cell returns to INTACT after DIG_CLOSE_SLOW + CLOSING_DURATION (async)
# ---------------------------------------------------------------------------

func _test_ac09_cell_returns_to_intact() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	terrain.dig_request(1, 2)

	# Wait for full cycle: dig + close_slow + closing + margin.
	# dig_duration=0.05, dig_close_slow=0.10, closing_duration=0.05 → total=0.20 s
	await get_tree().create_timer(0.05 + 0.10 + 0.05 + 0.1).timeout

	var state: TerrainSystem.DigState = terrain.get_dig_state(1, 2)
	var tile: TerrainSystem.TileType = terrain.get_tile_type(1, 2)
	var is_solid_again: bool = terrain.is_solid(1, 2)

	var ok: bool = (
		state == TerrainSystem.DigState.INTACT
		and tile == TerrainSystem.TileType.DIRT_SLOW
		and is_solid_again == true
	)
	if ok:
		print("[PASS] AC-09: DIRT_SLOW returns to INTACT; tile=DIRT_SLOW restored, is_solid=true")
	else:
		print(
			"[FAIL] AC-09: state=%d (expected %d INTACT), tile=%d (expected %d DIRT_SLOW), is_solid=%s"
			% [
				state, TerrainSystem.DigState.INTACT,
				tile, TerrainSystem.TileType.DIRT_SLOW,
				is_solid_again,
			]
		)

	terrain.queue_free()


# ---------------------------------------------------------------------------
# AC-10 — DIRT_FAST closes before DIRT_SLOW when both dug simultaneously (async)
# ---------------------------------------------------------------------------

func _test_ac10_dirt_fast_closes_before_slow() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	# Dig both cells at the same time.
	terrain.dig_request(1, 2)  # DIRT_SLOW: open for 0.10 s
	terrain.dig_request(2, 2)  # DIRT_FAST: open for 0.05 s

	# Wait long enough for DIRT_FAST to finish its full cycle but NOT DIRT_SLOW.
	# dig=0.05, fast_open=0.05, closing=0.05 → DIRT_FAST INTACT at ~0.15 s
	# DIRT_SLOW still in OPEN (open for 0.10 s, won't close until ~0.20 s total)
	# Sample at 0.20 s: DIRT_FAST should be INTACT, DIRT_SLOW may be CLOSING or INTACT.
	# Use 0.175 s to catch DIRT_FAST done but DIRT_SLOW still OPEN.
	await get_tree().create_timer(0.05 + 0.05 + 0.05 + 0.025).timeout

	var state_slow: TerrainSystem.DigState = terrain.get_dig_state(1, 2)
	var state_fast: TerrainSystem.DigState = terrain.get_dig_state(2, 2)

	# DIRT_FAST must be INTACT (fully restored).
	# DIRT_SLOW must NOT be INTACT yet (still OPEN or CLOSING at this sample point).
	var fast_done: bool = (state_fast == TerrainSystem.DigState.INTACT)
	var slow_still_open: bool = (
		state_slow == TerrainSystem.DigState.OPEN
		or state_slow == TerrainSystem.DigState.CLOSING
	)

	var ok: bool = fast_done and slow_still_open
	if ok:
		print("[PASS] AC-10: DIRT_FAST closes before DIRT_SLOW (fast=INTACT, slow=OPEN/CLOSING at sample point)")
	else:
		print(
			"[FAIL] AC-10: state_fast=%d (expected INTACT=%d), state_slow=%d (expected OPEN=%d or CLOSING=%d)"
			% [
				state_fast, TerrainSystem.DigState.INTACT,
				state_slow, TerrainSystem.DigState.OPEN, TerrainSystem.DigState.CLOSING,
			]
		)

	terrain.queue_free()


# ---------------------------------------------------------------------------
# AC-11 — dig_request on SOLID → silently rejected, cell stays INTACT
# ---------------------------------------------------------------------------

func _test_ac11_dig_solid_rejected() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	var signal_fired: bool = false
	terrain.dig_state_changed.connect(
		func(_c: int, _r: int, _old: TerrainSystem.DigState, _new: TerrainSystem.DigState) -> void:
			signal_fired = true
	)

	terrain.dig_request(1, 1)  # SOLID — not destructible
	var state: TerrainSystem.DigState = terrain.get_dig_state(1, 1)

	var ok: bool = state == TerrainSystem.DigState.INTACT and not signal_fired
	if ok:
		print("[PASS] AC-11: dig_request on SOLID → rejected, state=INTACT, no signal")
	else:
		print("[FAIL] AC-11: state=%d signal_fired=%s" % [state, signal_fired])

	terrain.free()


# ---------------------------------------------------------------------------
# AC-12 — dig_request on already-OPEN cell → silently rejected
# ---------------------------------------------------------------------------

func _test_ac12_dig_open_rejected() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	# Manually force the cell into OPEN state by directly accessing internal
	# dicts — we need to bypass the timer to test the rejection logic only.
	# We use dig_request to go INTACT→DIGGING first, then poke the dict.
	terrain.dig_request(1, 2)
	# Advance to OPEN by manipulating the internal timer to zero and calling
	# _process with a large delta.
	terrain._dig_timers[Vector2i(1, 2)] = 0.0
	terrain._process(0.0)  # triggers DIGGING → OPEN immediately

	var state_before_second_dig: TerrainSystem.DigState = terrain.get_dig_state(1, 2)

	# Count signals after this point.
	var extra_signals: int = 0
	terrain.dig_state_changed.connect(
		func(_c: int, _r: int, _old: TerrainSystem.DigState, _new: TerrainSystem.DigState) -> void:
			extra_signals += 1
	)

	terrain.dig_request(1, 2)  # should be rejected — already OPEN

	var state_after: TerrainSystem.DigState = terrain.get_dig_state(1, 2)
	var ok: bool = (
		state_before_second_dig == TerrainSystem.DigState.OPEN
		and state_after == TerrainSystem.DigState.OPEN
		and extra_signals == 0
	)
	if ok:
		print("[PASS] AC-12: dig_request on OPEN cell → silently rejected, state stays OPEN")
	else:
		print(
			"[FAIL] AC-12: state_before=%d state_after=%d extra_signals=%d"
			% [state_before_second_dig, state_after, extra_signals]
		)

	terrain.queue_free()


# ---------------------------------------------------------------------------
# AC-13 — reset() with active timers → all cells INTACT, no signals after (async)
# ---------------------------------------------------------------------------

func _test_ac13_reset_with_active_timers() -> void:
	var terrain: TerrainSystem = _make_terrain(_TEST_DATA, _TEST_COLS, _TEST_ROWS)

	# Dig DIRT_SLOW and wait until OPEN.
	terrain.dig_request(1, 2)
	await get_tree().create_timer(0.05 + 0.05).timeout

	var state_pre_reset: TerrainSystem.DigState = terrain.get_dig_state(1, 2)

	# Call reset() while cell is OPEN.
	terrain.reset()

	# Count any signals emitted after reset.
	var post_reset_signals: int = 0
	terrain.dig_state_changed.connect(
		func(_c: int, _r: int, _old: TerrainSystem.DigState, _new: TerrainSystem.DigState) -> void:
			post_reset_signals += 1
	)

	var state_after_reset: TerrainSystem.DigState = terrain.get_dig_state(1, 2)
	var tile_after_reset: TerrainSystem.TileType = terrain.get_tile_type(1, 2)
	var solid_after_reset: bool = terrain.is_solid(1, 2)

	# Wait long enough that old timers WOULD have fired (if not cancelled).
	await get_tree().create_timer(0.30).timeout

	var ok: bool = (
		state_pre_reset == TerrainSystem.DigState.OPEN
		and state_after_reset == TerrainSystem.DigState.INTACT
		and tile_after_reset == TerrainSystem.TileType.DIRT_SLOW
		and solid_after_reset == true
		and post_reset_signals == 0
	)
	if ok:
		print("[PASS] AC-13: reset() cancels timers; cell=INTACT, tile=DIRT_SLOW restored, no signals after reset")
	else:
		print(
			"[FAIL] AC-13: pre_reset=%d post=%d tile=%d solid=%s post_signals=%d"
			% [
				state_pre_reset, state_after_reset,
				tile_after_reset, solid_after_reset,
				post_reset_signals,
			]
		)

	terrain.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Create a fully wired TerrainSystem with fast timer values for testing.
## The GridSystem is added as a child of TerrainSystem so it is freed together.
## The TerrainSystem is added to this test node's scene tree so _process runs.
func _make_terrain(data: Array[int], p_cols: int, p_rows: int) -> TerrainSystem:
	var grid: GridSystem = GridSystem.new()

	var config: TerrainConfig = TerrainConfig.new()
	config.dig_duration     = 0.05  # short: fast test execution
	config.dig_close_slow   = 0.10
	config.dig_close_fast   = 0.05
	config.closing_duration = 0.05

	var terrain: TerrainSystem = TerrainSystem.new()
	add_child(terrain)
	terrain.add_child(grid)  # grid freed with terrain
	terrain.setup(grid, config)
	terrain.initialize(data, p_cols, p_rows)
	return terrain
