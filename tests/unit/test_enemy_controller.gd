## Unit tests for EnemyController — AI-01 + AI-02.
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Test grid layouts (5 × 5):
##
##   _TEST_DATA (standard — DIRT_SLOW at (2,2), solid floor at row 4):
##     Col:  0    1    2    3    4
##     Row 0: [ E,   E,   E,   E,   E ]   E = EMPTY     (0)
##     Row 1: [ E,   E,   E,   E,   E ]   S = SOLID     (1)
##     Row 2: [ E,   E,   D,   E,   E ]   D = DIRT_SLOW (2)
##     Row 3: [ E,   E,   E,   E,   E ]   ← patrol row
##     Row 4: [ S,   S,   S,   S,   S ]   ← solid floor
##
##   _HOLE_DATA (EC-01 ledge test — gap at (3,3)):
##     Row 0: [ E,   E,   E,   E,   E ]
##     Row 1: [ E,   E,   E,   E,   E ]
##     Row 2: [ E,   E,   E,   E,   E ]   ← enemy at (2,2)
##     Row 3: [ S,   S,   S,   E,   S ]   ← void at (3,3)
##     Row 4: [ S,   S,   S,   S,   S ]
##
## Timer constants use move_speed = 20.0 (0.05 s/cell).
## _STEP = 0.15 s ≈ 3× the move interval for reliable completion.
##
## Covers: AC-01, AC-02, AC-02b, AC-06, AC-07, AC-08a, AC-08b, AC-11
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const _TEST_COLS: int = 5
const _TEST_ROWS: int = 5

## Grid step speed for tests — 1/20 = 0.05 s/cell.
const _MOVE_SPEED: float = 20.0

## Wait duration: 3× the move interval for reliable completion.
const _STEP: float = 0.15

## Fast dig duration for tests so OPEN state is reachable without long awaits.
const _DIG_DURATION: float = 0.05

## Entity ID reserved for the test enemy.
const _ENEMY_ID: int = 10

## Standard grid — DIRT_SLOW at (2,2), solid floor at row 4.
const _TEST_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0 — all EMPTY
	0, 0, 0, 0, 0,  # row 1 — all EMPTY
	0, 0, 2, 0, 0,  # row 2 — DIRT_SLOW at (2,2)
	0, 0, 0, 0, 0,  # row 3 — all EMPTY (patrol row)
	1, 1, 1, 1, 1,  # row 4 — SOLID floor
]

## Hole grid — gap in floor at (3,3) for EC-01 ledge avoidance test.
const _HOLE_DATA: Array[int] = [
	0, 0, 0, 0, 0,  # row 0
	0, 0, 0, 0, 0,  # row 1
	0, 0, 0, 0, 0,  # row 2 — enemy at (2,2)
	1, 1, 1, 0, 1,  # row 3 — gap at (3,3)
	1, 1, 1, 1, 1,  # row 4
]


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	await _run_all_tests()


func _run_all_tests() -> void:
	print("=== EnemyController Tests ===")
	await _test_ac01_patrol_moves_horizontally()
	await _test_ac02_patrol_turns_at_wall()
	await _test_ac02b_patrol_turns_at_open_hole()
	_test_ac06_entity_should_fall_enters_falling()
	_test_ac07_entity_landed_open_cell_trapped()
	await _test_ac08a_trapped_timer_expires_dead()
	await _test_ac08b_dead_timer_expires_patrol()
	_test_ac11_reset_returns_to_spawn()
	print("=== Done ===")


# ---------------------------------------------------------------------------
# Helper — world factory
# ---------------------------------------------------------------------------

## Build a fresh isolated world for each test.
## Returns a Dictionary with keys:
##   "grid"    GridSystem
##   "terrain" TerrainSystem
##   "gravity" GridGravity
##   "player"  PlayerMovement  (pure signal source — no setup()/spawn() called)
##   "enemy"   EnemyController (added to scene tree so _process fires)
##   "config"  EnemyConfig
func _make_world(tile_data: Array[int] = _TEST_DATA) -> Dictionary:
	var grid := GridSystem.new()
	var terrain := TerrainSystem.new()
	var gravity := GridGravity.new()

	# Fast TerrainConfig so dig tests reach OPEN state quickly.
	var tc := TerrainConfig.new()
	tc.dig_duration = _DIG_DURATION
	tc.dig_close_slow = 30.0
	tc.dig_close_fast = 15.0
	tc.closing_duration = 5.0

	terrain.setup(grid, tc)
	terrain.initialize(tile_data, _TEST_COLS, _TEST_ROWS)
	gravity.setup(grid, terrain)

	# PlayerMovement is used solely as a signal source: enemy.setup() only
	# calls player_moved.connect().  No setup()/spawn() required.
	var player := PlayerMovement.new()
	player.entity_id = 0
	add_child(player)  # keeps it alive and ensures queue_free works

	var cfg := EnemyConfig.new()
	cfg.move_speed = _MOVE_SPEED
	cfg.detection_range = 8
	cfg.trap_escape_time = 8.0
	cfg.respawn_delay = 2.0

	var enemy := EnemyController.new()
	enemy.config = cfg
	add_child(enemy)  # _process fires while in scene tree
	enemy.setup(grid, terrain, gravity, player, null, _ENEMY_ID)

	return {
		"grid": grid,
		"terrain": terrain,
		"gravity": gravity,
		"player": player,
		"enemy": enemy,
		"config": cfg,
	}


## Release all nodes created by _make_world().
## Player and enemy are in the scene tree → queue_free (deferred).
## Grid, terrain, gravity were never added to the tree → free immediately.
func _teardown_world(world: Dictionary) -> void:
	(world["enemy"] as EnemyController).queue_free()
	(world["player"] as PlayerMovement).queue_free()
	(world["gravity"] as GridGravity).free()
	(world["terrain"] as TerrainSystem).free()
	(world["grid"] as GridSystem).free()


# ---------------------------------------------------------------------------
# AC-01 — Enemy in PATROL moves horizontally each tick
# ---------------------------------------------------------------------------

## Spawn at (2,3): EMPTY, solid floor at row 4 → grounded, patrol_dir = 1.
## Expected: enemy_moved(enemy_id, (2,3), (3,3)) fires after one move interval.
func _test_ac01_patrol_moves_horizontally() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	enemy.spawn(Vector2i(2, 3), Vector2i(2, 0))

	var moved_from := Vector2i(-1, -1)
	var moved_to   := Vector2i(-1, -1)
	var signal_fired := false

	enemy.enemy_moved.connect(
		func(_id: int, f: Vector2i, t: Vector2i) -> void:
			if not signal_fired:
				signal_fired = true
				moved_from = f
				moved_to   = t
	)

	await get_tree().create_timer(_STEP).timeout

	var ok: bool = (
		signal_fired
		and moved_from == Vector2i(2, 3)
		and moved_to == Vector2i(3, 3)
	)
	if ok:
		print("[PASS] AC-01: enemy in PATROL moves right — enemy_moved(10, (2,3), (3,3))")
	else:
		print(
			"[FAIL] AC-01: patrol move — fired=%s from=%s to=%s"
			% [signal_fired, moved_from, moved_to]
			+ " (expected fired=true, from=(2,3), to=(3,3))"
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-02 — Enemy in PATROL facing non-traversable cell reverses patrol_dir
# ---------------------------------------------------------------------------

## Spawn at (4,3): EMPTY, grounded.  patrol_dir = 1 (right).
## Next cell (5,3) is out of bounds → is_valid returns false → U-turn.
## First valid enemy_moved must be leftward: from=(4,3), to=(3,3).
func _test_ac02_patrol_turns_at_wall() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	enemy.spawn(Vector2i(4, 3), Vector2i(2, 0))

	var first_from := Vector2i(-1, -1)
	var first_to   := Vector2i(-1, -1)
	var moved := false

	enemy.enemy_moved.connect(
		func(_id: int, f: Vector2i, t: Vector2i) -> void:
			if not moved:
				moved = true
				first_from = f
				first_to   = t
	)

	await get_tree().create_timer(_STEP).timeout

	# First successful move must be leftward (proof that a U-turn occurred).
	var ok: bool = (
		moved
		and first_from == Vector2i(4, 3)
		and first_to   == Vector2i(3, 3)
	)
	if ok:
		print("[PASS] AC-02: enemy at right edge turns around — first move is leftward (4,3)→(3,3)")
	else:
		print(
			"[FAIL] AC-02: expected U-turn then leftward first move"
			+ " — moved=%s from=%s to=%s"
			% [moved, first_from, first_to]
			+ " (expected first move from=(4,3), to=(3,3))"
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-02b — Enemy in PATROL facing open void below reverses patrol_dir (EC-01)
# ---------------------------------------------------------------------------

## Hole grid: row 3 has a gap at (3,3) — no solid below (3,2).
## Spawn at (2,2): is_grounded(2,2) = true (solid at (2,3)).  patrol_dir = 1.
## is_grounded(3,2) = false (gap at (3,3)) → enemy must refuse to step right.
## First valid move is leftward: from=(2,2), to=(1,2).
func _test_ac02b_patrol_turns_at_open_hole() -> void:
	var world := _make_world(_HOLE_DATA)
	var enemy: EnemyController = world["enemy"]
	enemy.spawn(Vector2i(2, 2), Vector2i(2, 0))

	var first_from := Vector2i(-1, -1)
	var first_to   := Vector2i(-1, -1)
	var moved := false

	enemy.enemy_moved.connect(
		func(_id: int, f: Vector2i, t: Vector2i) -> void:
			if not moved:
				moved = true
				first_from = f
				first_to   = t
	)

	await get_tree().create_timer(_STEP).timeout

	# First successful move is leftward — confirms EC-01 void detection.
	var ok: bool = (
		moved
		and first_from == Vector2i(2, 2)
		and first_to   == Vector2i(1, 2)
	)
	if ok:
		print("[PASS] AC-02b: enemy avoids void at (3,3) — EC-01 turns around, first move leftward (2,2)→(1,2)")
	else:
		print(
			"[FAIL] AC-02b: EC-01 ledge check — moved=%s from=%s to=%s"
			% [moved, first_from, first_to]
			+ " (expected first move from=(2,2), to=(1,2))"
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-06 — entity_should_fall signal → state becomes FALLING
# ---------------------------------------------------------------------------

## Spawn at (2,3) (grounded).  Emit entity_should_fall(enemy_id) directly.
## (2,3) is EMPTY / not OPEN → not TRAPPED path → state = FALLING.
## Synchronous: no _process tick required.
func _test_ac06_entity_should_fall_enters_falling() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	var gravity: GridGravity = world["gravity"]
	enemy.spawn(Vector2i(2, 3), Vector2i(2, 0))

	# Emit signal directly (bypasses GridGravity's cell_changed chain but
	# tests the signal handler in isolation, which is the unit-test goal).
	gravity.entity_should_fall.emit(enemy.enemy_id)

	var entered_falling: bool = enemy._state == EnemyController.State.FALLING

	if entered_falling:
		print("[PASS] AC-06: entity_should_fall emitted → state = FALLING")
	else:
		print(
			"[FAIL] AC-06: entity_should_fall — expected FALLING got %s"
			% EnemyController.State.keys()[enemy._state]
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-07 — entity_landed on OPEN cell → state becomes TRAPPED, timer set
# ---------------------------------------------------------------------------

## Dig cell (2,2) (DIRT_SLOW in standard grid) and advance to OPEN state via
## a manual terrain._process() call.  Then place enemy at (2,2), emit
## entity_landed, and verify state = TRAPPED with trap_timer armed.
func _test_ac07_entity_landed_open_cell_trapped() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	var gravity: GridGravity = world["gravity"]
	var terrain: TerrainSystem = world["terrain"]

	# Spawn enemy at (3,3) so the dig at (2,2) does not interact with it.
	enemy.spawn(Vector2i(3, 3), Vector2i(2, 0))

	# Dig (2,2) and advance through DIGGING → OPEN in one manual tick.
	# dig_duration = 0.05 s; calling _process(0.1) expires the timer.
	terrain.dig_request(2, 2)
	terrain._process(0.1)  # DIGGING → OPEN

	var is_open: bool = terrain.get_dig_state(2, 2) == TerrainSystem.DigState.OPEN
	if not is_open:
		print("[FAIL] AC-07: setup failed — cell (2,2) is not OPEN after manual _process tick")
		_teardown_world(world)
		return

	# Simulate the enemy having fallen into the hole: place it at (2,2)
	# and set state to FALLING as it would be before landing.
	enemy.current_cell = Vector2i(2, 2)
	enemy._state = EnemyController.State.FALLING

	# Emit entity_landed directly to unit-test the handler in isolation.
	gravity.entity_landed.emit(enemy.enemy_id)

	var trapped: bool = enemy._state == EnemyController.State.TRAPPED
	var timer_set: bool = enemy._trap_timer == (world["config"] as EnemyConfig).trap_escape_time

	var ok: bool = trapped and timer_set
	if ok:
		print("[PASS] AC-07: entity_landed on OPEN cell → state = TRAPPED, trap_timer armed")
	else:
		print(
			"[FAIL] AC-07: expected TRAPPED + timer=%.1f — got state=%s timer=%.1f"
			% [
				(world["config"] as EnemyConfig).trap_escape_time,
				EnemyController.State.keys()[enemy._state],
				enemy._trap_timer,
			]
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-08a — TRAPPED timer expires → state becomes DEAD
# ---------------------------------------------------------------------------

## Spawn and place enemy in TRAPPED state with a very short _trap_timer.
## After _STEP, _process should have fired and transitioned to DEAD.
func _test_ac08a_trapped_timer_expires_dead() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	enemy.spawn(Vector2i(2, 3), Vector2i(2, 0))

	# Bypass normal trap entry and fast-forward the timer.
	enemy._state = EnemyController.State.TRAPPED
	enemy._trap_timer = 0.05  # expires well within _STEP

	await get_tree().create_timer(_STEP).timeout

	var is_dead: bool = enemy._state == EnemyController.State.DEAD

	if is_dead:
		print("[PASS] AC-08a: TRAPPED timer expires → state = DEAD")
	else:
		print(
			"[FAIL] AC-08a: expected DEAD after trap_timer expired — got %s"
			% EnemyController.State.keys()[enemy._state]
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-08b — DEAD timer expires → state returns to PATROL at rescate cell
# ---------------------------------------------------------------------------

## Place enemy in DEAD state with a very short _respawn_timer.
## After _STEP, enemy should be at rescate_cell and in PATROL.
func _test_ac08b_dead_timer_expires_patrol() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	var rescate: Vector2i = Vector2i(2, 0)
	enemy.spawn(Vector2i(2, 3), rescate)

	# Bypass normal death entry and fast-forward the respawn timer.
	enemy._state = EnemyController.State.DEAD
	enemy._respawn_timer = 0.05  # expires well within _STEP

	await get_tree().create_timer(_STEP).timeout

	var at_rescate: bool = enemy.current_cell == rescate
	var is_patrol: bool  = enemy._state == EnemyController.State.PATROL

	var ok: bool = at_rescate and is_patrol
	if ok:
		print("[PASS] AC-08b: DEAD timer expires → state = PATROL at rescate_cell %s" % rescate)
	else:
		print(
			"[FAIL] AC-08b: expected PATROL at %s — got state=%s cell=%s"
			% [rescate, EnemyController.State.keys()[enemy._state], enemy.current_cell]
		)
	_teardown_world(world)


# ---------------------------------------------------------------------------
# AC-11 — reset() returns enemy to spawn cell and PATROL state
# ---------------------------------------------------------------------------

## Spawn at (1,3).  Manually move enemy to (3,3) and set state FALLING.
## After reset(), current_cell must equal spawn_cell and state must be PATROL.
## Synchronous: reset() is fully synchronous.
func _test_ac11_reset_returns_to_spawn() -> void:
	var world := _make_world()
	var enemy: EnemyController = world["enemy"]
	var spawn: Vector2i = Vector2i(1, 3)
	var rescate: Vector2i = Vector2i(2, 0)
	enemy.spawn(spawn, rescate)

	# Simulate enemy having wandered and entered FALLING state.
	enemy.current_cell = Vector2i(3, 3)
	enemy._state = EnemyController.State.FALLING

	enemy.reset()

	var back_at_spawn: bool = enemy.current_cell == spawn
	var is_patrol: bool     = enemy._state == EnemyController.State.PATROL

	var ok: bool = back_at_spawn and is_patrol
	if ok:
		print("[PASS] AC-11: reset() → current_cell = %s, state = PATROL" % spawn)
	else:
		print(
			"[FAIL] AC-11: expected cell=%s PATROL — got cell=%s state=%s"
			% [spawn, enemy.current_cell, EnemyController.State.keys()[enemy._state]]
		)
	_teardown_world(world)
