## StarsSystem — times each level and awards 1–3 stars on victory.
##
## Connects to LevelSystem signals to track elapsed time. On level_victory,
## computes stars against StarsConfig.PAR_TIMES, stores the result in-memory,
## and shows a StarsDisplay overlay for StarsConfig.DISPLAY_DURATION seconds.
##
## Node placement: child of Level scene alongside AudioSystem and VfxSystem.
##   Level01 (LevelSystem)
##     └── StarsSystem (this node)
##
## Wire once via setup(level_sys). LevelSystem holds an @export var stars.
## All signal connections are null-safe and guarded by is_connected().
##
## Persistence: in-memory only for Vertical Slice. Save system is Full Vision.
##
## Implements: design/gdd/stars-scoring.md
class_name StarsSystem
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after StarsDisplay auto-dismisses. Carries the level result.
signal display_complete(level_id: String, stars: int)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Best stars per level_id this session. Values are 1, 2, or 3.
var _session_stars: Dictionary = {}

## Millisecond timestamp when the current level started (or restarted).
var _start_ms: int = 0

## Elapsed seconds of the most recently completed level.
var _last_elapsed: float = 0.0

## level_id of the currently running level.
var _current_level_id: String = ""

## Reference to LevelSystem — stored for level_id lookup on level_started.
var _level_sys: LevelSystem = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire signals. Call once in LevelSystem._initialize_level().
## Null-safe: logs a warning if level_sys is null and returns without error.
func setup(level_sys: LevelSystem) -> void:
	if level_sys == null:
		push_warning("StarsSystem.setup: level_sys is null — stars disabled.")
		return
	_level_sys = level_sys

	if not level_sys.level_started.is_connected(_on_level_started):
		level_sys.level_started.connect(_on_level_started)
	if not level_sys.level_restarted.is_connected(_on_level_restarted):
		level_sys.level_restarted.connect(_on_level_restarted)
	if not level_sys.level_victory.is_connected(_on_level_victory):
		level_sys.level_victory.connect(_on_level_victory)


## Returns the best star count for level_id this session (1–3), or 0 if
## the level has never been completed.
func get_stars(level_id: String) -> int:
	return _session_stars.get(level_id, 0)


## Returns the elapsed time (seconds) of the most recently completed level.
## Returns 0.0 if no level has been completed yet this session.
func get_time_elapsed() -> float:
	return _last_elapsed

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_level_started(level_index: int) -> void:
	# Derive level_id from the index via LevelSystem's current data.
	# LevelSystem exposes current_level_index; we reconstruct the id string
	# to avoid requiring a direct reference to LevelData.
	_ = level_index  # suppress unused-param warning
	_current_level_id = _resolve_level_id()
	_start_ms = Time.get_ticks_msec()


func _on_level_restarted() -> void:
	# Death restarts the level — reset the clock.
	_start_ms = Time.get_ticks_msec()


func _on_level_victory() -> void:
	var elapsed: float = (Time.get_ticks_msec() - _start_ms) / 1000.0
	_last_elapsed = elapsed

	var stars: int = _compute_stars(elapsed, _current_level_id)

	# Update session best.
	var previous: int = _session_stars.get(_current_level_id, 0)
	if stars > previous:
		_session_stars[_current_level_id] = stars

	_show_display(_current_level_id, stars, elapsed)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Derive the current level_id string from LevelSystem.current_level_index.
## Falls back to an empty string if LevelSystem is not available.
func _resolve_level_id() -> String:
	if _level_sys == null:
		return ""
	# Reconstruct the canonical id: "level_001" … "level_010".
	return "level_%03d" % _level_sys.current_level_index


## Compute star count for elapsed time against the par for level_id.
func _compute_stars(elapsed: float, level_id: String) -> int:
	var par: float = StarsConfig.PAR_TIMES.get(level_id, StarsConfig.PAR_DEFAULT)
	if elapsed <= par:
		return 3
	elif elapsed <= par * StarsConfig.TWO_STAR_MULTIPLIER:
		return 2
	else:
		return 1


## Instantiate a StarsDisplay CanvasLayer, show it, and free it after
## DISPLAY_DURATION seconds. Emits display_complete when done.
func _show_display(level_id: String, stars: int, elapsed: float) -> void:
	var display: StarsDisplay = StarsDisplay.new()
	display.initialize(stars, elapsed)
	add_child(display)

	# Auto-dismiss after DISPLAY_DURATION via a one-shot timer.
	var timer: SceneTreeTimer = get_tree().create_timer(StarsConfig.DISPLAY_DURATION)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(display):
			display.queue_free()
		display_complete.emit(level_id, stars)
	)
