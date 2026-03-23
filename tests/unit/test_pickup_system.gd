## Unit tests for PickupSystem — PICK-01.
##
## Implements: production/sprints/sprint-02.md#PICK-01
## Design doc: design/gdd/pickup-system.md
##
## Run by adding this script as the root of a test scene, or via Godot's built-in
## runner.  Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## All tests are synchronous — no timers, no await.
##
## Test grid: 5 × 5 GridSystem (all cells terrain-id 0).
## Pickups and exit cell coords are arbitrary within [0..4, 0..4].
##
## Covers: AC-01 through AC-08
##
## NOTE on FakePlayer:
##   FakePlayer extends PlayerMovement (not Node2D as the spec draft suggested)
##   because setup() is typed `p_player: PlayerMovement`. FakePlayer IS a
##   PlayerMovement — it inherits player_moved and current_cell with zero extra
##   wiring (PlayerMovement.setup() is never called, so no system dependencies
##   are needed). The only operation performed on FakePlayer in tests is emitting
##   player_moved to simulate the player entering a cell.
extends Node


# ---------------------------------------------------------------------------
# Inner class: minimal PlayerMovement stand-in
# ---------------------------------------------------------------------------

## Minimal stub that satisfies the PlayerMovement type contract.
## Inherits player_moved signal and current_cell var from PlayerMovement.
## Never calls PlayerMovement.setup(), so no TerrainSystem / GridGravity /
## InputSystem dependencies are required.
class FakePlayer extends PlayerMovement:
	pass


# ---------------------------------------------------------------------------
# Per-test state (re-created by _make_system / _teardown each test)
# ---------------------------------------------------------------------------

var _sys: PickupSystem
var _fake: FakePlayer
var _grid: GridSystem


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	_run_all_tests()


func _run_all_tests() -> void:
	print("=== PickupSystem Tests ===")
	_test_ac01_pickup_collected()
	_test_ac02_all_pickups_collected()
	_test_ac03_locked_exit_no_signal()
	_test_ac04_open_exit_player_reached()
	_test_ac05_reset_restores_state()
	_test_ac06_zero_pickups_exit_unlocked()
	_test_ac07_non_pickup_cell_no_signal()
	_test_ac08_pickups_remaining_and_total()
	print("=== Done ===")


# ---------------------------------------------------------------------------
# AC-01  Player moves to treasure cell → pickup_collected emitted,
#        pickups_remaining decremented
# ---------------------------------------------------------------------------

func _test_ac01_pickup_collected() -> void:
	_make_system([Vector2i(1, 1), Vector2i(2, 2)], Vector2i(4, 4))

	var emitted: bool = false
	var cap_col: int = -1
	var cap_row: int = -1
	var cap_rem: int = -1
	_sys.pickup_collected.connect(
		func(c: int, r: int, rem: int) -> void:
			emitted = true
			cap_col = c
			cap_row = r
			cap_rem = rem
	)

	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(1, 1))

	var ok: bool = emitted and cap_col == 1 and cap_row == 1 and cap_rem == 1 and _sys.pickups_remaining == 1
	if ok:
		print("[PASS] AC-01: player moves to treasure → pickup_collected emitted, pickups_remaining decremented")
	else:
		print(
			"[FAIL] AC-01: expected emitted=true col=1 row=1 rem=1 remaining=1 | got emitted=%s col=%d row=%d rem=%d remaining=%d"
			% [emitted, cap_col, cap_row, cap_rem, _sys.pickups_remaining]
		)

	_teardown()


# ---------------------------------------------------------------------------
# AC-02  Last treasure collected → all_pickups_collected + exit_unlocked emitted
# ---------------------------------------------------------------------------

func _test_ac02_all_pickups_collected() -> void:
	_make_system([Vector2i(1, 1)], Vector2i(4, 4))

	var all_collected: bool = false
	var exit_unlocked_fired: bool = false
	_sys.all_pickups_collected.connect(func() -> void: all_collected = true)
	_sys.exit_unlocked.connect(func() -> void: exit_unlocked_fired = true)

	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(1, 1))

	var ok: bool = all_collected and exit_unlocked_fired and _sys.pickups_remaining == 0
	if ok:
		print("[PASS] AC-02: last treasure collected → all_pickups_collected + exit_unlocked emitted")
	else:
		print(
			"[FAIL] AC-02: expected all_collected=true exit_unlocked=true remaining=0 | got %s %s %d"
			% [all_collected, exit_unlocked_fired, _sys.pickups_remaining]
		)

	_teardown()


# ---------------------------------------------------------------------------
# AC-03  Player enters locked exit → no player_reached_exit signal
# ---------------------------------------------------------------------------

func _test_ac03_locked_exit_no_signal() -> void:
	# Two pickups still uncollected → exit stays LOCKED.
	_make_system([Vector2i(1, 1), Vector2i(2, 2)], Vector2i(4, 4))

	var fired: bool = false
	_sys.player_reached_exit.connect(func() -> void: fired = true)

	# Move directly to exit without collecting any pickup.
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(4, 4))

	if not fired:
		print("[PASS] AC-03: player enters locked exit → no player_reached_exit")
	else:
		print("[FAIL] AC-03: player_reached_exit fired on locked exit — should not happen")

	_teardown()


# ---------------------------------------------------------------------------
# AC-04  Player enters open exit → player_reached_exit emitted
# ---------------------------------------------------------------------------

func _test_ac04_open_exit_player_reached() -> void:
	_make_system([Vector2i(1, 1)], Vector2i(4, 4))

	var fired: bool = false
	_sys.player_reached_exit.connect(func() -> void: fired = true)

	# Collect the only pickup to unlock the exit.
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(1, 1))
	# Now step onto the open exit.
	_fake.player_moved.emit(Vector2i(1, 1), Vector2i(4, 4))

	if fired:
		print("[PASS] AC-04: player enters open exit → player_reached_exit emitted")
	else:
		print("[FAIL] AC-04: player_reached_exit not emitted after stepping onto open exit")

	_teardown()


# ---------------------------------------------------------------------------
# AC-05  reset() → pickups_remaining == pickups_total, exit locked
# ---------------------------------------------------------------------------

func _test_ac05_reset_restores_state() -> void:
	_make_system([Vector2i(1, 1), Vector2i(2, 2)], Vector2i(4, 4))

	# Partially collect: take one of two pickups.
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(1, 1))

	# Reset.
	_sys.reset()

	# Verify exit is locked after reset.
	var exit_fired_after_reset: bool = false
	_sys.player_reached_exit.connect(func() -> void: exit_fired_after_reset = true)
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(4, 4))

	var ok: bool = (
		_sys.pickups_remaining == 2
		and _sys.pickups_total == 2
		and not exit_fired_after_reset
	)
	if ok:
		print("[PASS] AC-05: reset() restores pickups_remaining == pickups_total, exit locked")
	else:
		print(
			"[FAIL] AC-05: expected remaining=2 total=2 exit_locked=true | got remaining=%d total=%d exit_fired=%s"
			% [_sys.pickups_remaining, _sys.pickups_total, exit_fired_after_reset]
		)

	_teardown()


# ---------------------------------------------------------------------------
# AC-06  initialize with 0 pickups → exit_unlocked immediate, exit open
# ---------------------------------------------------------------------------

func _test_ac06_zero_pickups_exit_unlocked() -> void:
	# Must connect signals BEFORE initialize() fires them, so bypass _make_system().
	_grid = GridSystem.new()
	_grid.initialize(5, 5)
	_fake = FakePlayer.new()
	_sys = PickupSystem.new()
	_sys.setup(_grid, _fake)

	var all_collected: bool = false
	var exit_unlocked_fired: bool = false
	_sys.all_pickups_collected.connect(func() -> void: all_collected = true)
	_sys.exit_unlocked.connect(func() -> void: exit_unlocked_fired = true)

	# initialize with an empty pickup list — EC-01.
	_sys.initialize([], Vector2i(4, 4))

	# Confirm exit is now open by stepping onto it.
	var exit_reached: bool = false
	_sys.player_reached_exit.connect(func() -> void: exit_reached = true)
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(4, 4))

	var ok: bool = all_collected and exit_unlocked_fired and _sys.pickups_remaining == 0 and exit_reached
	if ok:
		print("[PASS] AC-06: initialize with 0 pickups → exit_unlocked immediate, exit open")
	else:
		print(
			"[FAIL] AC-06: expected all_collected=true exit_unlocked=true remaining=0 exit_reached=true | got %s %s %d %s"
			% [all_collected, exit_unlocked_fired, _sys.pickups_remaining, exit_reached]
		)

	_teardown()


# ---------------------------------------------------------------------------
# AC-07  Player moves to non-pickup cell → no pickup_collected signal
# ---------------------------------------------------------------------------

func _test_ac07_non_pickup_cell_no_signal() -> void:
	_make_system([Vector2i(1, 1)], Vector2i(4, 4))

	var fired: bool = false
	_sys.pickup_collected.connect(func(_c: int, _r: int, _rem: int) -> void: fired = true)

	# Move to a cell that is neither a pickup nor the exit.
	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(3, 3))

	if not fired:
		print("[PASS] AC-07: player moves to non-pickup cell → no pickup_collected signal")
	else:
		print("[FAIL] AC-07: pickup_collected fired for non-pickup cell — should not happen")

	_teardown()


# ---------------------------------------------------------------------------
# AC-08  pickups_remaining and pickups_total correct throughout
# ---------------------------------------------------------------------------

func _test_ac08_pickups_remaining_and_total() -> void:
	_make_system([Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)], Vector2i(4, 4))

	var ok: bool = true
	var msg: String = ""

	if _sys.pickups_total != 3:
		ok = false
		msg += "initial total expected 3 got %d | " % _sys.pickups_total
	if _sys.pickups_remaining != 3:
		ok = false
		msg += "initial remaining expected 3 got %d | " % _sys.pickups_remaining

	_fake.player_moved.emit(Vector2i(0, 0), Vector2i(1, 1))
	if _sys.pickups_remaining != 2:
		ok = false
		msg += "after 1st pickup expected remaining=2 got %d | " % _sys.pickups_remaining

	_fake.player_moved.emit(Vector2i(1, 1), Vector2i(2, 2))
	if _sys.pickups_remaining != 1:
		ok = false
		msg += "after 2nd pickup expected remaining=1 got %d | " % _sys.pickups_remaining

	_fake.player_moved.emit(Vector2i(2, 2), Vector2i(3, 3))
	if _sys.pickups_remaining != 0:
		ok = false
		msg += "after 3rd pickup expected remaining=0 got %d | " % _sys.pickups_remaining

	# pickups_total must remain constant throughout.
	if _sys.pickups_total != 3:
		ok = false
		msg += "pickups_total mutated — expected 3 got %d | " % _sys.pickups_total

	if ok:
		print("[PASS] AC-08: pickups_remaining and pickups_total correct throughout")
	else:
		print("[FAIL] AC-08: %s" % msg.trim_suffix(" | "))

	_teardown()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Create a 5×5 GridSystem, a FakePlayer, and a PickupSystem wired together.
## Stores references in _grid, _fake, _sys for use during the test.
## Also calls initialize() so AC tests can start emitting player_moved immediately.
func _make_system(pickup_cells: Array[Vector2i], exit_cell: Vector2i) -> void:
	_grid = GridSystem.new()
	_grid.initialize(5, 5)
	_fake = FakePlayer.new()
	_sys = PickupSystem.new()
	_sys.setup(_grid, _fake)
	_sys.initialize(pickup_cells, exit_cell)


## Free all three objects created by _make_system().
## Must be called at the end of every test to avoid leaks between tests.
func _teardown() -> void:
	_sys.free()
	_fake.free()
	_grid.free()
	_sys = null
	_fake = null
	_grid = null
