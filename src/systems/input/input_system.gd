## InputSystem — Passive translator: hardware events → discrete action signals.
## Implements: design/gdd/input-system.md
##
## Model: Hold to Move (B)
##   - Holding a direction emits move_requested at MOVE_INTERVAL.
##   - First emission is immediate on key_down (no initial delay).
##   - Releasing stops movement cleanly at the current cell.
##   - Multiple simultaneous directions: last-input-wins (LIFO stack, see EC-01).
##   - dig_requested is one-shot per key_down (no repeat).
##
## Usage:
##   1. Add InputSystem as a child of your main game scene.
##   2. Connect move_requested → PlayerMovement.on_move_requested
##      Connect dig_requested → DigSystem.on_dig_requested
##   3. Call set_process_unhandled_input(false) to silence during pause/UI (EC-04).
##
## Required InputMap actions (Project Settings → InputMap):
##   move_left, move_right, move_up, move_down, dig_left, dig_right
class_name InputSystem
extends Node

## Emitted once immediately on key_down, then at every MOVE_INTERVAL while held.
signal move_requested(direction: Vector2i)

## Emitted once per key_down. No repeat.
signal dig_requested(direction: Vector2i)

## Swap to a custom InputConfig .tres to change tuning values at runtime or per-level.
@export var config: InputConfig

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

enum _State { IDLE, MOVING }

var _state: _State = _State.IDLE

## LIFO stack of currently-held direction vectors (EC-01: last-input-wins).
## Top of stack (_direction_stack.back()) is the active direction.
var _direction_stack: Array[Vector2i] = []

## Countdown timer (seconds) until next move_requested repeat.
var _move_timer: float = 0.0

# Ordered list used to iterate direction action names.
const _DIRECTION_ACTIONS: Array = [
	&"move_left", &"move_right", &"move_up", &"move_down"
]

# Maps action StringName → unit Vector2i.
const _DIRECTION_VECTORS: Dictionary = {
	&"move_left":  Vector2i(-1,  0),
	&"move_right": Vector2i( 1,  0),
	&"move_up":    Vector2i( 0, -1),
	&"move_down":  Vector2i( 0,  1),
}

# Maps dig action StringName → unit Vector2i (Left/Right only per GDD).
const _DIG_ACTIONS: Dictionary = {
	&"dig_left":  Vector2i(-1, 0),
	&"dig_right": Vector2i( 1, 0),
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# EC-05: initialise in IDLE — no signals before first player input.
	_state = _State.IDLE
	_direction_stack.clear()
	_move_timer = 0.0
	if config == null:
		config = InputConfig.new()


func _process(delta: float) -> void:
	if _state != _State.MOVING or _direction_stack.is_empty():
		return
	_move_timer -= delta
	if _move_timer <= 0.0:
		# Use += to absorb timer overshoot and keep rhythm stable.
		_move_timer += config.move_interval
		move_requested.emit(_direction_stack.back())

# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	_handle_dig(event)
	_handle_direction(event)


func _handle_direction(event: InputEvent) -> void:
	for action: StringName in _DIRECTION_ACTIONS:
		if not event.is_action(action):
			continue
		var dir: Vector2i = _DIRECTION_VECTORS[action]
		if event.is_action_pressed(action, false):
			# Ensure no duplicate entry (e.g. focus regained while held).
			_direction_stack.erase(dir)
			_direction_stack.push_back(dir)
			# Immediate first emission + timer reset (also handles direction change).
			_state = _State.MOVING
			_move_timer = config.move_interval
			move_requested.emit(dir)
			return
		elif event.is_action_released(action):
			_direction_stack.erase(dir)
			if _direction_stack.is_empty():
				_state = _State.IDLE
				_move_timer = 0.0
			# else: stack.back() is the new active direction; timer continues.
			return


func _handle_dig(event: InputEvent) -> void:
	for action: StringName in _DIG_ACTIONS:
		if event.is_action_pressed(action, false):
			dig_requested.emit(_DIG_ACTIONS[action] as Vector2i)
			return
