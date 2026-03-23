## Unit tests for PlayerMovement — MOVE-01.
##
## Implements: production/sprints/sprint-01.md#MOVE-01
## Design doc: design/gdd/player-movement.md
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Test grid layout (5 × 5):
##
##   Col:  0    1    2    3    4
##   Row 0: [ E,   E,   E,   E,   E ]   E = EMPTY  (0)
##   Row 1: [ E,   E,   E,   E,   E ]   S = SOLID  (1)
##   Row 2: [ E,   E,   L,   E,   E ]   L = LADDER (4)
##   Row 3: [ E,   E,   L,   E,   E ]
##   Row 4: [ S,   S,   S,   S,   S ]   — solid floor
##
## Notable cells:
##   (2,2), (2,3) — LADDER column
##   Row 4        — implicit floor (SOLID)
##
## Timer constants use move_speed = 20.0 (0.05 s/cell) and fall_speed = 0.05 s
## so tests complete in < 0.5 s each. _STEP = 0.15 s ≈ 3× the slowest interval.
##
## Covers: AC-01 through AC-10
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const _TEST_COLS: int = 5
const _TEST_ROWS: int = 5
const _MOVE_SPEED: float = 20.0   ## 1 / 20 = 0.05 s per cell
const _FALL_SPEED: float = 0.05   ## seconds per fall cell
## Wait step: 3× slowest interval for reliable completion on any machine.
const _STEP: float = 0.15

## Flat row-major tile data matching the layout above.
const _TEST_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0 — all EMPTY
	0, 0, 0, 0, 0,  # row 1 — all EMPTY
	0, 0, 4, 0, 0,  # row 2 — LADDER at (2,2)
	0, 0, 4, 0, 0,  # row 3 — LADDER at (2,3)
	1, 1, 1, 1, 1,  # row 4 — SOLID floor
]

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	await _run_all_tests()


func _run_all_tests() -> void:
	print("=== PlayerMovement Tests ===")
	await _test_ac01_move_horizontal_grounded()
	_test_ac02_move_blocked_by_wall()
	_test_ac03_move_blocked_not_grounded()
	await _test_ac04_entity_should_fall_enters_falling()
	await _test_ac05_after_fall_state_idle()
	_test_ac06_horizontal_ignored_during_falling()
	await _test_ac07_player_moved_emitted()
	_test_ac08_reset_during_falling()
	await _test_ac09_climb_up_ladder()
	await _test_ac10_input_buffered_during_moving()
	print("=== Done ===")

# ---------------------------------------------------------------------------
# Helper — world factory
# ---------------------------------------------------------------------------

## Build a fresh isolated world for each test.
## Returns a Dictionary with keys:
##   "grid"         GridSystem
##   "terrain"      TerrainSystem
##   "gravity"      GridGravity
##   "input"        InputSystem  (signal source only; not added to scene tree)
##   "input_config" InputConfig  (Resource — freed by reference counting)
##   "player"       PlayerMovement  (added to scene tree so _process fires)
func _make_world() -> Dictionary:
	var grid := GridSystem.new()
	var terrain := TerrainSystem.new()
	var gravity := GridGravity.new()
	var input_cfg := InputConfig.new()
	input_cfg.move_speed = _MOVE_SPEED

	# Wire terrain + gravity (GridSystem is initialised inside terrain.initialize).
	terrain.setup(grid)
	terrain.initialize(_TEST_DATA, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# InputSystem is used as a pure signal source — no scene-tree membership needed.
	var input := InputSystem.new()

	# PlayerMovement needs _process → must be in the scene tree.
	var player := PlayerMovement.new()
	player.entity_id = 1
	add_child(player)           # _ready() runs here → set_process(false)
	player.setup(grid, terrain, gravity, input, input_cfg, _FALL_SPEED)

	return {
		"grid": grid,
		"terrain": terrain,
		"gravity": gravity,
		"input": input,
		"input_config": input_cfg,
		"player": player,
	}


## Release all nodes created by _make_world().
## Player is in the scene tree → queue_free (deferred).
## Other nodes were never added to the tree → free immediately.
## InputConfig is a Resource → released by reference counting.
func _teardown_world(world: Dictionary) -> void:
	(world["player"] as PlayerMovement).queue_free()
	(world["gravity"] as GridGravity).free()
	(world["input"] as InputSystem).free()
	(world["terrain"] as TerrainSystem).free()
	(world["grid"] as GridSystem).free()

# ---------------------------------------------------------------------------
# AC-01 — move_requested(left) on grounded traversable → moves left + signal
# ---------------------------------------------------------------------------

## Spawn at (1,3): EMPTY cell, SOLID floor at row 4 → grounded.
## Target (0,3): EMPTY → traversable, valid.
## Expects: player_moved(from=(1,3), to=(0,3)) emitted after move_interval.
func _test_ac01_move_horizontal_grounded() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 3))

	var from_cell := Vector2i(-1, -1)
	var to_cell   := Vector2i(-1, -1)
	var moved     := false
	(world["player"] as PlayerMovement).player_moved.connect(
		func(f: Vector2i, t: Vector2i) -> void:
			moved = true
			from_cell = f
			to_cell   = t
	)

	(world["input"] as InputSystem).move_requested.emit(Vector2i(-1, 0))
	await get_tree().create_timer(_STEP).timeout

	if moved and from_cell == Vector2i(1, 3) and to_cell == Vector2i(0, 3):
		print("[PASS] AC-01: move_requested(left) grounded → player moves left, player_moved emitted")
	else:
		print(
			"[FAIL] AC-01: move_requested(left) grounded — moved=%s from=%s to=%s"
			% [moved, from_cell, to_cell]
			+ " (expected moved=true, from=(1,3), to=(0,3))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-02 — move_requested(left) toward solid wall / grid edge → player stays
# ---------------------------------------------------------------------------

## Spawn at (0,3): left grid edge — col-1 = -1 fails is_valid check.
## No await needed: validation is synchronous; rejection never starts a timer.
func _test_ac02_move_blocked_by_wall() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(0, 3))

	var moved := false
	(world["player"] as PlayerMovement).player_moved.connect(
		func(_f: Vector2i, _t: Vector2i) -> void: moved = true
	)

	(world["input"] as InputSystem).move_requested.emit(Vector2i(-1, 0))
	# Synchronous check — _process has not fired yet.
	var stayed: bool = (world["player"] as PlayerMovement).current_cell == Vector2i(0, 3)

	if stayed and not moved:
		print("[PASS] AC-02: move_requested(left) toward grid edge → player stays, no player_moved")
	else:
		print(
			"[FAIL] AC-02: move toward wall — moved=%s cell=%s"
			% [moved, (world["player"] as PlayerMovement).current_cell]
			+ " (expected moved=false, cell=(0,3))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-03 — move_requested(left/right) when not grounded, not on LADDER → blocked
# ---------------------------------------------------------------------------

## Spawn at (1,1): EMPTY, cell below (1,2) is EMPTY → NOT grounded.
## Not on LADDER/ROPE → is_climbable = false. Horizontal move must be blocked.
func _test_ac03_move_blocked_not_grounded() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 1))

	var moved := false
	(world["player"] as PlayerMovement).player_moved.connect(
		func(_f: Vector2i, _t: Vector2i) -> void: moved = true
	)

	(world["input"] as InputSystem).move_requested.emit(Vector2i(1, 0))
	var blocked: bool = (world["player"] as PlayerMovement).current_cell == Vector2i(1, 1)

	if blocked and not moved:
		print("[PASS] AC-03: move_requested in mid-air (not grounded, not climbable) → blocked")
	else:
		print(
			"[FAIL] AC-03: mid-air move — moved=%s cell=%s"
			% [moved, (world["player"] as PlayerMovement).current_cell]
			+ " (expected moved=false, cell=(1,1))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-04 — entity_should_fall → player enters FALLING, moves down at fall_speed
# ---------------------------------------------------------------------------

## Spawn at (1,3). Remove SOLID floor at (1,4) via grid.set_cell.
## GridGravity.cell_changed → entity_should_fall fires synchronously → FALLING.
## After _STEP, one fall step to (1,4) should have executed.
func _test_ac04_entity_should_fall_enters_falling() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 3))

	var fell_from := Vector2i(-1, -1)
	var fell_to   := Vector2i(-1, -1)
	(world["player"] as PlayerMovement).player_moved.connect(
		func(f: Vector2i, t: Vector2i) -> void:
			fell_from = f
			fell_to   = t
	)

	# Digging the floor triggers the full signal chain synchronously.
	(world["grid"] as GridSystem).set_cell(1, 4, 0)  # SOLID → EMPTY

	# State must be FALLING immediately (no _process tick needed).
	var entered_falling: bool = (
		(world["player"] as PlayerMovement)._state == PlayerMovement.State.FALLING
	)

	# Wait for one fall step to complete.
	await get_tree().create_timer(_STEP).timeout

	var fell_down: bool = (fell_from == Vector2i(1, 3) and fell_to == Vector2i(1, 4))

	if entered_falling and fell_down:
		print("[PASS] AC-04: entity_should_fall → state FALLING, player moves down one cell")
	else:
		print(
			"[FAIL] AC-04: entered_falling=%s fell_down=%s from=%s to=%s"
			% [entered_falling, fell_down, fell_from, fell_to]
			+ " (expected FALLING immediately, from=(1,3) to=(1,4))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-05 — After fall: player snaps to grounded cell, state = IDLE
# ---------------------------------------------------------------------------

## After the floor is dug, the player falls from (1,3) to (1,4).
## (1,4) is the last row: row+1 >= rows → implicit floor (EC-01) → is_grounded.
## Expects state = IDLE and current_cell = (1,4) after the fall completes.
func _test_ac05_after_fall_state_idle() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 3))

	(world["grid"] as GridSystem).set_cell(1, 4, 0)  # trigger fall

	# Wait enough for: fall_timer (0.05 s) + snap + state transition.
	await get_tree().create_timer(_STEP * 2.0).timeout

	var player: PlayerMovement = world["player"] as PlayerMovement
	var is_idle:   bool = player._state == PlayerMovement.State.IDLE
	var is_landed: bool = player.current_cell == Vector2i(1, 4)

	if is_idle and is_landed:
		print("[PASS] AC-05: after fall — player snaps to (1,4), state = IDLE")
	else:
		print(
			"[FAIL] AC-05: is_idle=%s is_landed=%s cell=%s"
			% [is_idle, is_landed, player.current_cell]
			+ " (expected IDLE + cell=(1,4))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-06 — move_requested(horizontal) during FALLING → ignored
# ---------------------------------------------------------------------------

## After floor is dug, state = FALLING. Send move_requested(left).
## current_cell must be unchanged (no horizontal drift — EC-06).
## Synchronous test: no _process tick fires between floor-dig and input check.
func _test_ac06_horizontal_ignored_during_falling() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 3))

	(world["grid"] as GridSystem).set_cell(1, 4, 0)  # trigger fall

	var in_falling: bool = (
		(world["player"] as PlayerMovement)._state == PlayerMovement.State.FALLING
	)
	var cell_before: Vector2i = (world["player"] as PlayerMovement).current_cell

	(world["input"] as InputSystem).move_requested.emit(Vector2i(-1, 0))

	var cell_unchanged: bool = (world["player"] as PlayerMovement).current_cell == cell_before

	if in_falling and cell_unchanged:
		print("[PASS] AC-06: move_requested(horizontal) during FALLING → ignored, cell unchanged")
	else:
		print(
			"[FAIL] AC-06: in_falling=%s cell_unchanged=%s cell=%s"
			% [in_falling, cell_unchanged, (world["player"] as PlayerMovement).current_cell]
			+ " (expected FALLING + cell=(1,3))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-07 — player_moved signal emitted after every successful move
# ---------------------------------------------------------------------------

## Spawn at (1,3). Make two distinct moves (right to (2,3), then right to (3,3)).
## Expects exactly 2 player_moved signals.
## (2,3) is LADDER — traversable and grounded; (3,3) is EMPTY + grounded.
func _test_ac07_player_moved_emitted() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(1, 3))

	var move_count := 0
	(world["player"] as PlayerMovement).player_moved.connect(
		func(_f: Vector2i, _t: Vector2i) -> void: move_count += 1
	)

	# First move: right → (2,3).
	(world["input"] as InputSystem).move_requested.emit(Vector2i(1, 0))
	await get_tree().create_timer(_STEP).timeout

	# Second move: right → (3,3).
	(world["input"] as InputSystem).move_requested.emit(Vector2i(1, 0))
	await get_tree().create_timer(_STEP).timeout

	if move_count == 2:
		print("[PASS] AC-07: player_moved emitted after every successful move (%d/2 signals)" % move_count)
	else:
		print(
			"[FAIL] AC-07: expected 2 player_moved signals, got %d"
			% move_count
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-08 — reset() during FALLING → state IDLE, player snapped to spawn
# ---------------------------------------------------------------------------

## Spawn at (1,3). Dig floor → FALLING. Call reset before any fall step.
## Expects: state = IDLE, current_cell = spawn_cell immediately after reset.
func _test_ac08_reset_during_falling() -> void:
	var world := _make_world()
	var spawn_cell := Vector2i(1, 3)
	(world["player"] as PlayerMovement).spawn(spawn_cell)

	(world["grid"] as GridSystem).set_cell(1, 4, 0)  # trigger fall

	var was_falling: bool = (
		(world["player"] as PlayerMovement)._state == PlayerMovement.State.FALLING
	)

	(world["player"] as PlayerMovement).reset(spawn_cell)

	var player: PlayerMovement = world["player"] as PlayerMovement
	var is_idle:    bool = player._state == PlayerMovement.State.IDLE
	var is_at_spawn: bool = player.current_cell == spawn_cell

	if was_falling and is_idle and is_at_spawn:
		print("[PASS] AC-08: reset() during FALLING → state IDLE, player snapped to spawn (1,3)")
	else:
		print(
			"[FAIL] AC-08: was_falling=%s is_idle=%s is_at_spawn=%s cell=%s"
			% [was_falling, is_idle, is_at_spawn, player.current_cell]
			+ " (expected was_falling=true, IDLE, cell=(1,3))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-09 — move_requested(up) on LADDER → player moves up
# ---------------------------------------------------------------------------

## Spawn at (2,3): LADDER → is_climbable = true, is_grounded = true.
## Target (2,2): LADDER → is_traversable = true.
## Expects: player_moved(from=(2,3), to=(2,2)) after move_interval.
func _test_ac09_climb_up_ladder() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(2, 3))

	var from_cell := Vector2i(-1, -1)
	var to_cell   := Vector2i(-1, -1)
	(world["player"] as PlayerMovement).player_moved.connect(
		func(f: Vector2i, t: Vector2i) -> void:
			from_cell = f
			to_cell   = t
	)

	(world["input"] as InputSystem).move_requested.emit(Vector2i(0, -1))
	await get_tree().create_timer(_STEP).timeout

	if from_cell == Vector2i(2, 3) and to_cell == Vector2i(2, 2):
		print("[PASS] AC-09: move_requested(up) on LADDER → player moves up to (2,2)")
	else:
		print(
			"[FAIL] AC-09: climb up — from=%s to=%s"
			% [from_cell, to_cell]
			+ " (expected from=(2,3), to=(2,2))"
		)
	_teardown_world(world)

# ---------------------------------------------------------------------------
# AC-10 — move_requested while MOVING → buffered, consumed after snap
# ---------------------------------------------------------------------------

## Spawn at (2,3) LADDER (grounded). Emit right × 2 with no await between them.
## First emit: IDLE → MOVING to (3,3).
## Second emit: MOVING → buffer(right).
## After first snap at (3,3): IDLE → consume buffer → MOVING to (4,3).
## After second snap at (4,3): IDLE.
## Expects: move_count = 2, current_cell = (4,3).
func _test_ac10_input_buffered_during_moving() -> void:
	var world := _make_world()
	(world["player"] as PlayerMovement).spawn(Vector2i(2, 3))

	var move_count := 0
	(world["player"] as PlayerMovement).player_moved.connect(
		func(_f: Vector2i, _t: Vector2i) -> void: move_count += 1
	)

	# Both emits happen synchronously — second sees MOVING state and buffers.
	(world["input"] as InputSystem).move_requested.emit(Vector2i(1, 0))  # IDLE → MOVING
	(world["input"] as InputSystem).move_requested.emit(Vector2i(1, 0))  # MOVING → buffer

	# Wait for two move intervals plus generous margin.
	await get_tree().create_timer(_STEP * 3.0).timeout

	var player: PlayerMovement = world["player"] as PlayerMovement
	var at_expected: bool = player.current_cell == Vector2i(4, 3)
	var two_moves:   bool = move_count == 2

	if at_expected and two_moves:
		print("[PASS] AC-10: buffered move consumed after snap; player at (4,3), 2 player_moved signals")
	else:
		print(
			"[FAIL] AC-10: at_expected=%s two_moves=%s cell=%s move_count=%d"
			% [at_expected, two_moves, player.current_cell, move_count]
			+ " (expected cell=(4,3), 2 signals)"
		)
	_teardown_world(world)
