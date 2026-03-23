# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does signal-driven cell-coincidence detection correctly handle
#            all pickup collection and exit-unlock states?
# Date: 2026-03-22
#
# Run with: godot --headless --script prototypes/pickup-system/pickup_test.gd
extends SceneTree

# ---------------------------------------------------------------------------
# Test harness — minimal, no deps
# ---------------------------------------------------------------------------

var _pass: int = 0
var _fail: int = 0

func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ✓  %s" % label)
		_pass += 1
	else:
		print("  ✗  FAIL: %s" % label)
		_fail += 1


func _make_sys() -> PickupSystem:
	var sys := PickupSystem.new()
	get_root().add_child(sys)
	return sys


# Signal capture helper
class Cap:
	var fired: bool = false
	var col: int = -1
	var row: int = -1

	func on_pickup_collected(c: int, r: int) -> void:
		fired = true
		col = c
		row = r

	func on_signal() -> void:
		fired = true


# ---------------------------------------------------------------------------
# AC-01 — Basic collection
# ---------------------------------------------------------------------------

func test_ac01_basic_collection() -> void:
	print("\n[AC-01] Basic collection")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 2)]
	sys.init(pickups, Vector2i(5, 5))

	var cap := Cap.new()
	sys.pickup_collected.connect(cap.on_pickup_collected)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))

	_check("pickup_collected fired", cap.fired)
	_check("pickup_collected col == 1", cap.col == 1)
	_check("pickup_collected row == 1", cap.row == 1)
	_check("pickups_remaining == 1", sys.pickups_remaining == 1)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-02 — Exit unlocks on last pickup
# ---------------------------------------------------------------------------

func test_ac02_exit_unlock() -> void:
	print("\n[AC-02] Exit unlock on last pickup")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1)]
	sys.init(pickups, Vector2i(5, 5))

	var all_cap := Cap.new()
	var unlock_cap := Cap.new()
	sys.all_pickups_collected.connect(all_cap.on_signal)
	sys.exit_unlocked.connect(unlock_cap.on_signal)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))

	_check("all_pickups_collected fired", all_cap.fired)
	_check("exit_unlocked fired", unlock_cap.fired)
	_check("pickups_remaining == 0", sys.pickups_remaining == 0)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-03 — Locked exit is silently ignored
# ---------------------------------------------------------------------------

func test_ac03_locked_exit_ignored() -> void:
	print("\n[AC-03] Locked exit silently ignored")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(2, 2)]
	sys.init(pickups, Vector2i(5, 5))

	var exit_cap := Cap.new()
	sys.player_reached_exit.connect(exit_cap.on_signal)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(5, 5))  # exit cell, but locked

	_check("player_reached_exit NOT fired", not exit_cap.fired)
	_check("pickups_remaining still 1", sys.pickups_remaining == 1)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-04 — Victory via open exit
# ---------------------------------------------------------------------------

func test_ac04_victory_via_exit() -> void:
	print("\n[AC-04] Victory via open exit")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1)]
	sys.init(pickups, Vector2i(5, 5))

	var exit_cap := Cap.new()
	sys.player_reached_exit.connect(exit_cap.on_signal)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))  # collect
	sys.on_player_moved(Vector2i(1, 1), Vector2i(5, 5))  # enter exit

	_check("player_reached_exit fired", exit_cap.fired)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-05 — Full reset
# ---------------------------------------------------------------------------

func test_ac05_full_reset() -> void:
	print("\n[AC-05] Full reset")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
	sys.init(pickups, Vector2i(5, 5))

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))  # collect one
	sys.reset()

	_check("pickups_remaining restored to 2", sys.pickups_remaining == 2)
	_check("pickups_total unchanged at 2", sys.pickups_total == 2)

	# Locked exit again after reset
	var exit_cap := Cap.new()
	sys.player_reached_exit.connect(exit_cap.on_signal)
	sys.on_player_moved(Vector2i(0, 0), Vector2i(5, 5))
	_check("exit still locked after reset", not exit_cap.fired)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-06 — Zero-treasure level
# ---------------------------------------------------------------------------

func test_ac06_zero_treasures() -> void:
	print("\n[AC-06] Zero-treasure level")
	var sys := _make_sys()
	var all_cap := Cap.new()
	var unlock_cap := Cap.new()
	var exit_cap := Cap.new()
	sys.all_pickups_collected.connect(all_cap.on_signal)
	sys.exit_unlocked.connect(unlock_cap.on_signal)
	sys.player_reached_exit.connect(exit_cap.on_signal)

	var pickups: Array[Vector2i] = []
	sys.init(pickups, Vector2i(5, 5))

	_check("all_pickups_collected fired at init", all_cap.fired)
	_check("exit_unlocked fired at init", unlock_cap.fired)
	_check("pickups_remaining == 0", sys.pickups_remaining == 0)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(5, 5))
	_check("player_reached_exit fires immediately", exit_cap.fired)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-07 — Player dies on treasure cell (no player_moved → no collection)
# ---------------------------------------------------------------------------

func test_ac07_death_no_collection() -> void:
	print("\n[AC-07] Death on treasure cell — no collection without player_moved")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(3, 3)]
	sys.init(pickups, Vector2i(5, 5))

	var collected_cap := Cap.new()
	sys.pickup_collected.connect(collected_cap.on_pickup_collected)

	# Simulate death: player_moved is never emitted, level resets
	sys.reset()

	_check("pickup_collected NOT fired", not collected_cap.fired)
	_check("pickups_remaining still 1 after reset", sys.pickups_remaining == 1)
	sys.queue_free()


# ---------------------------------------------------------------------------
# AC-08 — HUD sync: pickups_remaining updated before signal fires
# ---------------------------------------------------------------------------

func test_ac08_hud_sync() -> void:
	print("\n[AC-08] HUD sync — remaining decremented before signal")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
	sys.init(pickups, Vector2i(5, 5))

	var remaining_on_signal: int = -1
	var capture_remaining := func(_c: int, _r: int) -> void:
		remaining_on_signal = sys.pickups_remaining
	sys.pickup_collected.connect(capture_remaining)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))
	_check("pickups_remaining == 1 when signal fires", remaining_on_signal == 1)
	sys.queue_free()


# ---------------------------------------------------------------------------
# EC-04 — No double-collection of same cell
# ---------------------------------------------------------------------------

func test_ec04_no_double_collection() -> void:
	print("\n[EC-04] No double-collection of same cell")
	var sys := _make_sys()
	var pickups: Array[Vector2i] = [Vector2i(1, 1)]
	sys.init(pickups, Vector2i(5, 5))

	var fire_count: int = 0
	var count_fires := func(_c: int, _r: int) -> void:
		fire_count += 1
	sys.pickup_collected.connect(count_fires)

	sys.on_player_moved(Vector2i(0, 0), Vector2i(1, 1))
	sys.on_player_moved(Vector2i(1, 1), Vector2i(2, 2))
	sys.on_player_moved(Vector2i(2, 2), Vector2i(1, 1))  # revisit — already collected

	_check("pickup_collected fired exactly once", fire_count == 1)
	sys.queue_free()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _init() -> void:
	print("=== Pickup System Prototype Tests ===")
	test_ac01_basic_collection()
	test_ac02_exit_unlock()
	test_ac03_locked_exit_ignored()
	test_ac04_victory_via_exit()
	test_ac05_full_reset()
	test_ac06_zero_treasures()
	test_ac07_death_no_collection()
	test_ac08_hud_sync()
	test_ec04_no_double_collection()

	print("\n=== Results: %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
