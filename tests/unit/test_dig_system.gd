## Unit tests for DigSystem — DIG-01.
##
## Implements: production/sprints/sprint-02.md#DIG-01
## Design doc: design/gdd/dig-system.md
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Standard test grid layout (5 × 5):
##
##   Col:   0    1    2    3    4
##   Row 0: [ E,   E,   E,   E,   E ]
##   Row 1: [ E,   E,   E,   E,   E ]
##   Row 2: [ E,   E,   E,   E,   E ]   ← player walk row (spawn here)
##   Row 3: [ S,  DS,  DS,  DS,   S ]   S=SOLID(1)  DS=DIRT_SLOW(2)
##   Row 4: [ S,   S,   S,   S,   S ]   S=SOLID floor
##
## Player default spawn: (2, 2) — walk row; grounded by DIRT_SLOW at (2,3).
## Left dig target:  (1, 3) = DIRT_SLOW INTACT (AC-01, AC-04, AC-05, AC-06, AC-07, AC-09)
## Right dig toward: (3, 3) = DIRT_SLOW INTACT (AC-06 second dig)
## Rejection target: (4, 3) = SOLID, non-destructible (AC-02)
##
## Ladder test grid layout (5 × 5):
##
##   Col:   0    1    2    3    4
##   Row 2: [ E,   E,   L,   E,   E ]   L=LADDER(4) ← player ladder spawn
##   Row 3: [ E,  DS,   L,  DS,   E ]   dig targets one row below
##   Row 4: [ S,   S,   S,   S,   S ]
##
## Player ladder spawn: (2, 2) = LADDER — grounded by LADDER at (2,3) (AC-08).
##
## dig_duration = 0.05 s for fast test execution.
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const _TEST_COLS: int = 5
const _TEST_ROWS: int = 5

## Standard grid: SOLID edges in row 3, DIRT_SLOW at cols 1–3, SOLID floor row 4.
const _TEST_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0 — all EMPTY
	0, 0, 0, 0, 0,  # row 1 — all EMPTY
	0, 0, 0, 0, 0,  # row 2 — all EMPTY
	1, 2, 2, 2, 1,  # row 3 — SOLID(1) at cols 0,4; DIRT_SLOW(2) at cols 1–3
	1, 1, 1, 1, 1,  # row 4 — SOLID floor
]

## Ladder grid: LADDER at (2,2) and (2,3); DIRT_SLOW at (1,3) and (3,3).
const _LADDER_TEST_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0
	0, 0, 0, 0, 0,  # row 1
	0, 0, 4, 0, 0,  # row 2 — LADDER(4) at col 2 (player walk row)
	0, 2, 4, 2, 0,  # row 3 — DIRT_SLOW(2) at cols 1,3; LADDER(4) at col 2
	1, 1, 1, 1, 1,  # row 4 — SOLID floor
]

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	await _run_all_tests()


func _run_all_tests() -> void:
	print("=== DigSystem Tests ===")
	_test_ac01_dig_started_emitted()
	_test_ac02_non_destructible_rejected()
	_test_ac03_falling_rejected()
	_test_ac04_double_dig_second_rejected()
	_test_ac05_notify_digging_before_dig_request()
	await _test_ac06_after_cooldown_new_dig_accepted()
	_test_ac07_dig_started_correct_coordinates()
	_test_ac08_ladder_grounded_dig_allowed()
	await _test_ac09_dig_toward_open_rejected()
	_test_ac10_reset_during_digging()
	print("=== Done ===")

# ---------------------------------------------------------------------------
# AC-01 — dig_requested(left) + grounded + DIRT_SLOW at (1,3) → dig_started emitted
# ---------------------------------------------------------------------------

func _test_ac01_dig_started_emitted() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var terrain: TerrainSystem = world["terrain"] as TerrainSystem
	var input: InputSystem = world["input"] as InputSystem

	player.spawn(Vector2i(2, 2))

	var sig_fired: bool = false
	(world["dig"] as DigSystem).dig_started.connect(
		func(_c: int, _r: int) -> void: sig_fired = true
	)

	input.dig_requested.emit(Vector2i(-1, 0))

	var dig_state: TerrainSystem.DigState = terrain.get_dig_state(1, 3)
	var ok: bool = sig_fired and dig_state == TerrainSystem.DigState.DIGGING
	if ok:
		print("[PASS] AC-01: dig_requested(left) grounded + DIRT_SLOW → dig_started emitted, terrain=DIGGING")
	else:
		print(
			"[FAIL] AC-01: dig_requested(left) — expected dig_started=true terrain=DIGGING, "
			+ "got sig_fired=%s terrain=%d" % [sig_fired, dig_state]
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-02 — dig_requested toward SOLID (non-destructible) → rejected, no signal
# ---------------------------------------------------------------------------

func _test_ac02_non_destructible_rejected() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var input: InputSystem = world["input"] as InputSystem

	# Spawn at (3,2); dig right → target (4,3) = SOLID = not destructible.
	player.spawn(Vector2i(3, 2))

	var sig_fired: bool = false
	(world["dig"] as DigSystem).dig_started.connect(
		func(_c: int, _r: int) -> void: sig_fired = true
	)

	input.dig_requested.emit(Vector2i(1, 0))

	if not sig_fired:
		print("[PASS] AC-02: dig_requested toward SOLID (non-destructible) → rejected, no dig_started")
	else:
		print("[FAIL] AC-02: expected rejection of SOLID dig — got dig_started signal unexpectedly")

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-03 — dig_requested while player FALLING (state=2) → rejected
# ---------------------------------------------------------------------------

func _test_ac03_falling_rejected() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var input: InputSystem = world["input"] as InputSystem

	player.spawn(Vector2i(2, 2))
	# Force FALLING state directly (bypasses normal state transition for test isolation).
	player._state = PlayerMovement.State.FALLING

	var sig_fired: bool = false
	(world["dig"] as DigSystem).dig_started.connect(
		func(_c: int, _r: int) -> void: sig_fired = true
	)

	input.dig_requested.emit(Vector2i(-1, 0))

	if not sig_fired:
		print("[PASS] AC-03: dig_requested while player FALLING → rejected, no dig_started")
	else:
		print("[FAIL] AC-03: expected rejection when FALLING — got dig_started signal unexpectedly")

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-04 — dig_requested twice within cooldown → second rejected
# ---------------------------------------------------------------------------

func _test_ac04_double_dig_second_rejected() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var input: InputSystem = world["input"] as InputSystem

	player.spawn(Vector2i(2, 2))

	var sig_count: int = 0
	(world["dig"] as DigSystem).dig_started.connect(
		func(_c: int, _r: int) -> void: sig_count += 1
	)

	# First dig: should succeed (READY → DIGGING).
	input.dig_requested.emit(Vector2i(-1, 0))
	# Second dig immediately: should be rejected (_dig_state == DIGGING).
	input.dig_requested.emit(Vector2i(-1, 0))

	if sig_count == 1:
		print("[PASS] AC-04: dig_requested twice within cooldown → second rejected (1 signal only)")
	else:
		print(
			"[FAIL] AC-04: expected exactly 1 dig_started signal within cooldown, got %d"
			% sig_count
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-05 — notify_digging(true) called before dig_request (order check)
# ---------------------------------------------------------------------------

func _test_ac05_notify_digging_before_dig_request() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var terrain: TerrainSystem = world["terrain"] as TerrainSystem
	var gravity: GridGravity = world["gravity"] as GridGravity
	var input: InputSystem = world["input"] as InputSystem

	player.spawn(Vector2i(2, 2))

	# When terrain fires dig_state_changed (inside dig_request), check whether
	# GridGravity._digging_entities already contains the player id.
	# If notify_digging(true) was called first (EC-02), this must be true.
	var notify_before_dig: bool = false
	terrain.dig_state_changed.connect(
		func(_c: int, _r: int, _old: TerrainSystem.DigState, _new: TerrainSystem.DigState) -> void:
			notify_before_dig = gravity._digging_entities.has(0)
	)

	input.dig_requested.emit(Vector2i(-1, 0))

	if notify_before_dig:
		print("[PASS] AC-05: notify_digging(true) called before dig_request (EC-02 ordering confirmed)")
	else:
		print(
			"[FAIL] AC-05: notify_digging(true) was NOT in effect when terrain fired dig_state_changed"
			+ " — EC-02 ordering violated"
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-06 — after cooldown expires, dig_requested accepted again (async)
# ---------------------------------------------------------------------------

func _test_ac06_after_cooldown_new_dig_accepted() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var input: InputSystem = world["input"] as InputSystem
	var dig: DigSystem = world["dig"] as DigSystem

	player.spawn(Vector2i(2, 2))

	var sig_count: int = 0
	dig.dig_started.connect(func(_c: int, _r: int) -> void: sig_count += 1)

	# First dig: left → (1,3) = DIRT_SLOW INTACT.
	input.dig_requested.emit(Vector2i(-1, 0))
	# dig_duration = 0.05 s; wait for cooldown to expire with generous margin.
	await get_tree().create_timer(0.05 + 0.05).timeout

	# Second dig: right → (3,3) = DIRT_SLOW INTACT (untouched fresh cell).
	input.dig_requested.emit(Vector2i(1, 0))

	if sig_count == 2:
		print("[PASS] AC-06: after cooldown expires, new dig accepted (2 dig_started signals)")
	else:
		print(
			"[FAIL] AC-06: expected 2 dig_started signals (one per dig), got %d"
			% sig_count
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-07 — dig_started(col, row) signal carries correct coordinates
# ---------------------------------------------------------------------------

func _test_ac07_dig_started_correct_coordinates() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var input: InputSystem = world["input"] as InputSystem

	player.spawn(Vector2i(2, 2))

	var sig_col: int = -1
	var sig_row: int = -1
	(world["dig"] as DigSystem).dig_started.connect(
		func(c: int, r: int) -> void:
			sig_col = c
			sig_row = r
	)

	# Dig left from (2,2): target should be (1, 3) — one row below.
	input.dig_requested.emit(Vector2i(-1, 0))

	if sig_col == 1 and sig_row == 3:
		print("[PASS] AC-07: dig_started carries correct coordinates (col=1, row=3)")
	else:
		print(
			"[FAIL] AC-07: dig_started coordinates — expected (1,3), got (%d,%d)"
			% [sig_col, sig_row]
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-08 — player on LADDER (is_grounded via climbable) + adjacent DIRT → dig allowed
# ---------------------------------------------------------------------------

func _test_ac08_ladder_grounded_dig_allowed() -> void:
	var world := _make_ladder_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var gravity: GridGravity = world["gravity"] as GridGravity
	var input: InputSystem = world["input"] as InputSystem

	# Spawn at (2,2) = LADDER. is_grounded(2,2) = true via LADDER at (2,3).
	player.spawn(Vector2i(2, 2))

	# Sanity-check: confirm is_grounded is true due to LADDER below.
	var grounded_via_ladder: bool = gravity.is_grounded(2, 2)

	var sig_fired: bool = false
	(world["dig"] as DigSystem).dig_started.connect(
		func(_c: int, _r: int) -> void: sig_fired = true
	)

	# Dig right from (2,2) → target (3,3) = DIRT_SLOW INTACT → should be accepted.
	input.dig_requested.emit(Vector2i(1, 0))

	if grounded_via_ladder and sig_fired:
		print("[PASS] AC-08: player on LADDER (is_grounded=true) + adjacent DIRT → dig allowed")
	else:
		print(
			"[FAIL] AC-08: grounded_via_ladder=%s sig_fired=%s — "
			% [grounded_via_ladder, sig_fired]
			+ "expected both true"
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-09 — dig_requested toward already OPEN cell → rejected (async)
# ---------------------------------------------------------------------------

func _test_ac09_dig_toward_open_rejected() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var terrain: TerrainSystem = world["terrain"] as TerrainSystem
	var input: InputSystem = world["input"] as InputSystem
	var dig: DigSystem = world["dig"] as DigSystem

	player.spawn(Vector2i(2, 2))

	# First dig: (1,3) → terrain transitions INTACT → DIGGING.
	input.dig_requested.emit(Vector2i(-1, 0))

	# Manually advance TerrainSystem from DIGGING → OPEN without needing it
	# in the scene tree (mirrors the pattern from test_terrain_system.gd AC-12).
	terrain._dig_timers[Vector2i(1, 3)] = 0.0
	terrain._process(0.0)

	var state_open: TerrainSystem.DigState = terrain.get_dig_state(1, 3)

	# Wait for DigSystem cooldown to expire (DigSystem is in tree → _process runs).
	await get_tree().create_timer(0.05 + 0.05).timeout

	# Now DigSystem is READY but terrain (1,3) is OPEN — second dig must be rejected.
	var second_fired: bool = false
	dig.dig_started.connect(func(_c: int, _r: int) -> void: second_fired = true)

	input.dig_requested.emit(Vector2i(-1, 0))

	var ok: bool = state_open == TerrainSystem.DigState.OPEN and not second_fired
	if ok:
		print("[PASS] AC-09: dig_requested toward OPEN cell → rejected (dig state not INTACT)")
	else:
		print(
			"[FAIL] AC-09: state_open=%d (expected OPEN=%d), second_fired=%s (expected false)"
			% [state_open, TerrainSystem.DigState.OPEN, second_fired]
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-10 — reset() during DIGGING → state READY, notify_digging(false) called
# ---------------------------------------------------------------------------

func _test_ac10_reset_during_digging() -> void:
	var world := _make_world()
	var player: PlayerMovement = world["player"] as PlayerMovement
	var gravity: GridGravity = world["gravity"] as GridGravity
	var input: InputSystem = world["input"] as InputSystem
	var dig: DigSystem = world["dig"] as DigSystem

	player.spawn(Vector2i(2, 2))

	# Start a dig to enter DIGGING state.
	input.dig_requested.emit(Vector2i(-1, 0))

	# Verify we are in DIGGING before reset.
	var was_digging: bool = dig._dig_state == DigSystem._DigState.DIGGING

	# Reset during active cooldown.
	dig.reset()

	var is_ready: bool = dig._dig_state == DigSystem._DigState.READY
	var immunity_cleared: bool = not gravity._digging_entities.has(0)

	var ok: bool = was_digging and is_ready and immunity_cleared
	if ok:
		print(
			"[PASS] AC-10: reset() during DIGGING → state=READY, notify_digging(false) called"
		)
	else:
		print(
			"[FAIL] AC-10: was_digging=%s is_ready=%s immunity_cleared=%s "
			% [was_digging, is_ready, immunity_cleared]
			+ "(expected all true)"
		)

	_teardown_world(world)


# ---------------------------------------------------------------------------
# Helpers — world factory
# ---------------------------------------------------------------------------

## Build a fully wired world from a given grid data array.
##
## DigSystem and PlayerMovement are added to the scene tree (they need
## _process). Other nodes are created outside the tree; free() them directly
## in teardown. TerrainConfig and InputConfig are Resources — released by
## reference counting.
func _make_world_from_data(data: Array[int]) -> Dictionary:
	var grid := GridSystem.new()

	var terrain_config := TerrainConfig.new()
	terrain_config.dig_duration     = 0.05  # fast: tests complete in < 0.5 s
	terrain_config.dig_close_slow   = 8.0
	terrain_config.dig_close_fast   = 4.0
	terrain_config.closing_duration = 1.0

	var terrain := TerrainSystem.new()
	terrain.setup(grid, terrain_config)
	terrain.initialize(data, _TEST_COLS, _TEST_ROWS)

	var gravity := GridGravity.new()
	gravity.setup(grid, terrain)

	var input_cfg := InputConfig.new()
	input_cfg.move_speed = 20.0  # 1/20 = 0.05 s/cell

	var input := InputSystem.new()

	var player := PlayerMovement.new()
	player.entity_id = 0
	add_child(player)  # _ready() → set_process(false); spawn() → set_process(true)
	player.setup(grid, terrain, gravity, input, input_cfg, 0.05)

	var dig := DigSystem.new()
	add_child(dig)  # _ready() → set_process(false); dig → set_process(true)
	dig.setup(terrain, gravity, player, terrain_config, 0)
	input.dig_requested.connect(dig._on_dig_requested)

	return {
		"grid":           grid,
		"terrain":        terrain,
		"gravity":        gravity,
		"input":          input,
		"player":         player,
		"dig":            dig,
		"terrain_config": terrain_config,
	}


## Standard 5 × 5 world for most tests.
func _make_world() -> Dictionary:
	return _make_world_from_data(_TEST_DATA)


## 5 × 5 world with a LADDER at (2,3) for AC-08.
func _make_ladder_world() -> Dictionary:
	return _make_world_from_data(_LADDER_TEST_DATA)


## Release all nodes created by _make_world_from_data().
##
## player / dig are in the scene tree → queue_free (deferred).
## All other nodes were never added to the tree → free immediately.
## When gravity.free() is called, Godot automatically removes its signal
## connection to grid.cell_changed, preventing dangling references.
## Resources (terrain_config, input_cfg) are released by reference counting.
func _teardown_world(world: Dictionary) -> void:
	(world["dig"] as DigSystem).queue_free()
	(world["player"] as PlayerMovement).queue_free()
	(world["gravity"] as GridGravity).free()
	(world["input"] as InputSystem).free()
	(world["terrain"] as TerrainSystem).free()
	(world["grid"] as GridSystem).free()
