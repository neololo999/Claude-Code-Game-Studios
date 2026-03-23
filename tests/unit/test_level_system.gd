## Unit tests for LevelSystem — LVL-05.
##
## Run by adding this script as the root of a test scene.
## Each test prints "[PASS] AC-N: …" or "[FAIL] AC-N: … — expected X got Y".
##
## Design philosophy:
##   LevelSystem is tested WITHOUT wiring real subsystems (TerrainSystem,
##   GridGravity, PlayerMovement, PickupSystem, etc.).  TestableLevelSystem,
##   an inner subclass, overrides the three methods that touch subsystem nodes,
##   letting every test focus purely on state-machine logic and signal emission.
##
##   TestableLevelSystem overrides:
##     _initialize_level()  — no-op; records level_state so AC-01 can observe
##                            the LOADING intermediate state from inside the call.
##     _trigger_death()     — full logic minus player.die() (no node wired).
##     _do_restart()        — full logic minus subsystem reset/re-init calls.
##
##   Nodes are NOT added to the scene tree, so _ready() never fires and its
##   deferred load_level("level_001") never interferes.  _process(delta) is
##   called manually for the two timer-driven tests (AC-05, AC-09).
##
##   resources/levels/ contains only .gitkeep (no .tres files at test time),
##   so _get_next_level_id() falls back to LevelBuilder.LEVEL_IDS — a stable
##   ordered list of "level_001" … "level_010".
##
## AC-08 naming note:
##   The design spec AC-08 references a "level_loaded" signal, but LevelSystem
##   emits "level_started".  This test validates the implemented signal name.
##
## Covers: AC-01 through AC-10
##
## Implements: production/sprints/sprint-05.md#LVL-05
extends Node


# ---------------------------------------------------------------------------
# Inner class: TestableLevelSystem
# ---------------------------------------------------------------------------

## Subclass of LevelSystem with subsystem-touching methods stubbed out so that
## the state machine can be exercised without any child nodes being wired.
class TestableLevelSystem extends LevelSystem:

	## State captured inside _initialize_level().
	## When called from load_level() this equals State.LOADING (AC-01).
	## When called from _do_restart() this equals State.RESTARTING (AC-09).
	var state_during_init: LevelSystem.State = LevelSystem.State.IDLE

	## Override: skip all subsystem calls; record intermediate state for AC-01.
	func _initialize_level(_data: LevelData) -> void:
		state_during_init = level_state  # LOADING when called by load_level()
		_is_initialized = true           # mark initialised so load_level() proceeds

	## Override: full death-transition logic minus player.die() (not wired).
	func _trigger_death() -> void:
		if level_state == State.DYING or level_state == State.RESTARTING:
			return
		level_state = State.DYING
		_state_timer = DEATH_FREEZE_TIME
		death_count += 1
		player_died.emit()
		# player.die() intentionally omitted — PlayerMovement not wired in unit tests.

	## Override: full restart-transition logic minus subsystem reset/re-init calls.
	func _do_restart() -> void:
		level_state = State.RESTARTING
		for e: EnemyController in _enemies:
			e.queue_free()
		_enemies.clear()
		# Skip: pickups.reset(), gravity.reset(), terrain.reset() — not wired.
		_initialize_level(_current_level_data)  # no-op override; sets state_during_init
		level_state = State.RUNNING
		level_restarted.emit()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	_run_all_tests()


func _run_all_tests() -> void:
	print("=== LevelSystem Tests ===")
	_test_ac01_load_level_state_transitions()
	_test_ac02_get_next_level_id_returns_next()
	_test_ac03_get_next_level_id_last_returns_empty()
	_test_ac04_enemy_reached_player_triggers_dying()
	_test_ac05_dying_timer_emits_level_restarted()
	_test_ac06_player_reached_exit_triggers_victory()
	_test_ac07_game_completed_on_last_level()
	_test_ac08_level_started_emitted_during_load_level()
	_test_ac09_restart_triggers_restarting_running_cycle()
	_test_ac10_enemy_death_ignored_in_non_running_state()
	print("=== Done ===")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return a fresh TestableLevelSystem.
## The node is NOT added to the scene tree so _ready() never fires and the
## auto-deferred load_level("level_001") never runs.
func _make_system() -> TestableLevelSystem:
	return TestableLevelSystem.new()


## Return a minimal LevelData populated only with identity fields.
## Sufficient for all tests that need _current_level_data to be non-null.
func _make_level_data(p_level_id: String, p_level_index: int) -> LevelData:
	var data: LevelData = LevelData.new()
	data.level_id = p_level_id
	data.level_index = p_level_index
	return data


# ---------------------------------------------------------------------------
# AC-01 — load_level("level_001") transitions IDLE → LOADING → RUNNING
# ---------------------------------------------------------------------------
#
# Strategy: TestableLevelSystem._initialize_level() captures level_state the
# moment it is called — that window is the only place LOADING is observable
# in a synchronous call (load_level sets LOADING, calls _initialize_level,
# then immediately sets RUNNING).

func _test_ac01_load_level_state_transitions() -> void:
	var sys: TestableLevelSystem = _make_system()

	var state_before: LevelSystem.State = sys.level_state  # IDLE by default

	sys.load_level("level_001")  # synchronous

	var state_during: LevelSystem.State = sys.state_during_init  # captured inside override
	var state_after: LevelSystem.State = sys.level_state

	var ok: bool = (
		state_before == LevelSystem.State.IDLE
		and state_during == LevelSystem.State.LOADING
		and state_after == LevelSystem.State.RUNNING
	)
	if ok:
		print("[PASS] AC-01: load_level transitions IDLE → LOADING → RUNNING")
	else:
		print(
			"[FAIL] AC-01: state_before=%d (exp IDLE=%d)  state_during=%d (exp LOADING=%d)  state_after=%d (exp RUNNING=%d)"
			% [
				state_before, LevelSystem.State.IDLE,
				state_during, LevelSystem.State.LOADING,
				state_after,  LevelSystem.State.RUNNING,
			]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-02 — _get_next_level_id() with current level "level_001" returns "level_002"
# ---------------------------------------------------------------------------
#
# The method reads _current_level_data.level_id (not a parameter).
# resources/levels/ has no .tres files, so it falls back to LevelBuilder.LEVEL_IDS
# which lists level_001 … level_010 in order.

func _test_ac02_get_next_level_id_returns_next() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys._current_level_data = _make_level_data("level_001", 1)

	var result: String = sys._get_next_level_id()

	if result == "level_002":
		print("[PASS] AC-02: _get_next_level_id() for \"level_001\" == \"level_002\"")
	else:
		print(
			"[FAIL] AC-02: _get_next_level_id() for \"level_001\" → \"%s\" (expected \"level_002\")"
			% result
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-03 — _get_next_level_id() with current level "level_010" returns ""
# ---------------------------------------------------------------------------
#
# level_010 is the last entry in LevelBuilder.LEVEL_IDS, so idx + 1 >= size → "".

func _test_ac03_get_next_level_id_last_returns_empty() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys._current_level_data = _make_level_data("level_010", 10)

	var result: String = sys._get_next_level_id()

	if result.is_empty():
		print("[PASS] AC-03: _get_next_level_id() for \"level_010\" == \"\" (no next level)")
	else:
		print(
			"[FAIL] AC-03: _get_next_level_id() for \"level_010\" → \"%s\" (expected \"\")"
			% result
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-04 — RUNNING + _on_enemy_reached_player() → state becomes DYING
# ---------------------------------------------------------------------------

func _test_ac04_enemy_reached_player_triggers_dying() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys.level_state = LevelSystem.State.RUNNING

	sys._on_enemy_reached_player(1, Vector2i(3, 3))

	if sys.level_state == LevelSystem.State.DYING:
		print("[PASS] AC-04: _on_enemy_reached_player in RUNNING → state=DYING")
	else:
		print(
			"[FAIL] AC-04: state=%d (expected DYING=%d)"
			% [sys.level_state, LevelSystem.State.DYING]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-05 — DYING + DEATH_FREEZE_TIME elapsed → level_restarted signal emitted
# ---------------------------------------------------------------------------
#
# _process(delta) is called manually; node is not in the scene tree.
# We prime _state_timer to DEATH_FREEZE_TIME, then advance by DEATH_FREEZE_TIME + ε
# to make the timer expire and fire _do_restart() (overridden in TestableLevelSystem).

func _test_ac05_dying_timer_emits_level_restarted() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys._current_level_data = _make_level_data("level_001", 1)
	sys.level_state = LevelSystem.State.DYING
	sys._state_timer = LevelSystem.DEATH_FREEZE_TIME

	var signal_fired: bool = false
	sys.level_restarted.connect(func() -> void: signal_fired = true)

	# Advance timer past zero — triggers _do_restart() inside _process().
	sys._process(LevelSystem.DEATH_FREEZE_TIME + 0.01)

	var ok: bool = signal_fired and sys.level_state == LevelSystem.State.RUNNING
	if ok:
		print("[PASS] AC-05: DEATH_FREEZE_TIME elapsed → level_restarted emitted, state=RUNNING")
	else:
		print(
			"[FAIL] AC-05: signal_fired=%s  state=%d (expected RUNNING=%d)"
			% [signal_fired, sys.level_state, LevelSystem.State.RUNNING]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-06 — RUNNING + _on_player_reached_exit() → state becomes VICTORY
# ---------------------------------------------------------------------------

func _test_ac06_player_reached_exit_triggers_victory() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys.level_state = LevelSystem.State.RUNNING

	sys._on_player_reached_exit()

	if sys.level_state == LevelSystem.State.VICTORY:
		print("[PASS] AC-06: _on_player_reached_exit in RUNNING → state=VICTORY")
	else:
		print(
			"[FAIL] AC-06: state=%d (expected VICTORY=%d)"
			% [sys.level_state, LevelSystem.State.VICTORY]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-07 — _do_next_level() when no next level exists → game_completed emitted
# ---------------------------------------------------------------------------
#
# With _current_level_data.level_id = "level_010", _get_next_level_id()
# returns "" → _do_next_level() emits game_completed and idles.

func _test_ac07_game_completed_on_last_level() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys._current_level_data = _make_level_data("level_010", 10)

	var signal_fired: bool = false
	sys.game_completed.connect(func() -> void: signal_fired = true)

	sys._do_next_level()

	var ok: bool = signal_fired and sys.level_state == LevelSystem.State.IDLE
	if ok:
		print("[PASS] AC-07: _do_next_level() on last level → game_completed emitted, state=IDLE")
	else:
		print(
			"[FAIL] AC-07: signal_fired=%s  state=%d (expected IDLE=%d)"
			% [signal_fired, sys.level_state, LevelSystem.State.IDLE]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-08 — level_started signal emitted during load_level()
# ---------------------------------------------------------------------------
#
# NOTE: The design spec AC-08 references a "level_loaded" signal; the actual
# implementation emits "level_started" (with level_index: int parameter).
# This test validates the implemented signal name and that level_index is correct.

func _test_ac08_level_started_emitted_during_load_level() -> void:
	var sys: TestableLevelSystem = _make_system()

	var signal_fired: bool = false
	var captured_index: int = -1
	sys.level_started.connect(func(idx: int) -> void:
		signal_fired = true
		captured_index = idx
	)

	sys.load_level("level_001")

	# LevelBuilder.build("level_001") produces a LevelData with level_index = 1.
	var ok: bool = signal_fired and captured_index == 1
	if ok:
		print("[PASS] AC-08: load_level() emits level_started with level_index=1")
	else:
		print(
			"[FAIL] AC-08: signal_fired=%s  captured_index=%d (expected 1)"
			% [signal_fired, captured_index]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-09 — restart() in RUNNING → DYING immediately; after timer → RUNNING + level_restarted
# ---------------------------------------------------------------------------
#
# restart() calls _trigger_death() (override: no player.die()),
# which sets state=DYING and primes the timer.
# Then _process(delta > timer) calls _do_restart() (override: full state cycle),
# emitting level_restarted and setting state=RUNNING.

func _test_ac09_restart_triggers_restarting_running_cycle() -> void:
	var sys: TestableLevelSystem = _make_system()
	sys._current_level_data = _make_level_data("level_001", 1)
	sys.level_state = LevelSystem.State.RUNNING

	var signal_fired: bool = false
	sys.level_restarted.connect(func() -> void: signal_fired = true)

	# 1. restart() → DYING state + timer primed.
	sys.restart()
	var state_after_restart: LevelSystem.State = sys.level_state

	# 2. Advance timer past DEATH_FREEZE_TIME → _do_restart() → RUNNING.
	sys._process(LevelSystem.DEATH_FREEZE_TIME + 0.01)
	var state_after_process: LevelSystem.State = sys.level_state

	var ok: bool = (
		state_after_restart == LevelSystem.State.DYING
		and state_after_process == LevelSystem.State.RUNNING
		and signal_fired
	)
	if ok:
		print("[PASS] AC-09: restart() → DYING; timer elapsed → RUNNING; level_restarted emitted")
	else:
		print(
			"[FAIL] AC-09: state_after_restart=%d (exp DYING=%d)  state_after_process=%d (exp RUNNING=%d)  signal=%s"
			% [
				state_after_restart,  LevelSystem.State.DYING,
				state_after_process,  LevelSystem.State.RUNNING,
				signal_fired,
			]
		)

	sys.free()


# ---------------------------------------------------------------------------
# AC-10 — _on_enemy_reached_player() in any non-RUNNING state is ignored
# ---------------------------------------------------------------------------
#
# All 6 non-RUNNING states are exercised.  Each gets its own system instance
# to guarantee isolation.

func _test_ac10_enemy_death_ignored_in_non_running_state() -> void:
	const NON_RUNNING_STATES: Array[LevelSystem.State] = [
		LevelSystem.State.IDLE,
		LevelSystem.State.LOADING,
		LevelSystem.State.DYING,
		LevelSystem.State.RESTARTING,
		LevelSystem.State.VICTORY,
		LevelSystem.State.TRANSITIONING,
	]

	var all_ok: bool = true
	for state: LevelSystem.State in NON_RUNNING_STATES:
		var sys: TestableLevelSystem = _make_system()
		sys.level_state = state

		sys._on_enemy_reached_player(1, Vector2i(0, 0))

		if sys.level_state != state:
			all_ok = false
			print(
				"[FAIL] AC-10: started in state=%d, after _on_enemy_reached_player got state=%d (expected no change)"
				% [state, sys.level_state]
			)

		sys.free()

	if all_ok:
		print(
			"[PASS] AC-10: _on_enemy_reached_player ignored in all %d non-RUNNING states"
			% NON_RUNNING_STATES.size()
		)
