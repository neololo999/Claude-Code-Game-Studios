## VfxSystem — screen-shake on death + pickup flash effects.
##
## Screen-shake: offsets CameraController.offset by randomised vector
## for 0.25s with amplitude 4px. Resets offset to zero after.
##
## Pickup flash: spawns a white ColorRect at the pickup cell world position,
## tweens alpha 0.6 → 0.0 over 0.15s, then queue_free()s it.
##
## Uses _process-based timer for shake (consistent with project conventions —
## no SceneTreeTimer). Uses Tween for flash (one-shot, self-cleaning).
##
## Implements: design/gdd/visual-feedback.md
class_name VfxSystem
extends Node2D

const SHAKE_DURATION:  float = 0.25
const SHAKE_AMPLITUDE: float = 4.0
const FLASH_DURATION:  float = 0.15
const FLASH_ALPHA:     float = 0.6
const MAX_FLASHES:     int   = 8

var _camera: CameraController = null
var _grid:   GridSystem       = null

var _shake_timer:   float = 0.0
var _active_flashes: int  = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _shake_timer <= 0.0:
		return
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_shake_timer = 0.0
		if _camera != null:
			_camera.offset = Vector2.ZERO
	else:
		if _camera != null:
			_camera.offset = Vector2(
				randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE),
				randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE)
			)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire signals. Call in LevelSystem._initialize_level().
func setup(
		camera: CameraController,
		pickups: PickupSystem,
		level_sys: LevelSystem,
		grid: GridSystem) -> void:
	_camera = camera
	_grid   = grid

	if level_sys != null and not level_sys.player_died.is_connected(_on_player_died):
		level_sys.player_died.connect(_on_player_died)
	if pickups != null and not pickups.pickup_collected.is_connected(_on_pickup_collected):
		pickups.pickup_collected.connect(_on_pickup_collected)


## Cancel shake + free all flash rects. Called on level restart.
func reset() -> void:
	_shake_timer = 0.0
	if _camera != null:
		_camera.offset = Vector2.ZERO
	# Free any lingering flash rects.
	for child in get_children():
		child.queue_free()
	_active_flashes = 0


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	_shake_timer = SHAKE_DURATION


func _on_pickup_collected(col: int, row: int, _remaining: int) -> void:
	if _grid == null or _active_flashes >= MAX_FLASHES:
		return
	_spawn_flash(col, row)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spawn_flash(col: int, row: int) -> void:
	var world_pos: Vector2 = _grid.grid_to_world(col, row)
	var half: float = GridSystem.CELL_SIZE / 2.0

	var rect := ColorRect.new()
	rect.size = Vector2(GridSystem.CELL_SIZE, GridSystem.CELL_SIZE)
	rect.position = world_pos - Vector2(half, half)
	rect.color = Color(1.0, 1.0, 1.0, FLASH_ALPHA)
	add_child(rect)
	_active_flashes += 1

	var tween: Tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, FLASH_DURATION)
	tween.tween_callback(func() -> void:
		rect.queue_free()
		_active_flashes -= 1
	)
