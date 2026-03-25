## CameraController — Camera2D that follows the player within level bounds.
##
## Extends Camera2D directly. Placed as a child of the Level node.
## Call setup() once per level load; call reset() on restart.
##
## Behaviour:
##   - Small levels (≤ 640×360): camera centered, smoothing disabled, no scroll.
##   - Large levels (> 640 wide OR > 360 tall): smooth tracking, clamped to grid.
##
## Implements: design/gdd/camera-system.md
class_name CameraController
extends Camera2D

const VIEWPORT_W: int = 640
const VIEWPORT_H: int = 360

@export var config: CameraConfig

var _player: Node2D = null
var _level_width: int = 0
var _level_height: int = 0
var _large_level: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	enabled = true
	make_current()


func _process(_delta: float) -> void:
	if _player == null or not _large_level:
		return
	global_position = _player.global_position


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire camera to player and compute bounds from level_data.
## Must be called after LevelSystem._initialize_level() wires the player node.
func setup(player: Node2D, level_data: LevelData) -> void:
	_player = player

	var cell: int = GridSystem.CELL_SIZE
	_level_width  = level_data.grid_cols * cell
	_level_height = level_data.grid_rows * cell

	_large_level = (_level_width > VIEWPORT_W) or (_level_height > VIEWPORT_H)

	# Bounds — always clamp to grid edges.
	limit_left   = 0
	limit_top    = 0
	limit_right  = _level_width
	limit_bottom = _level_height

	if _large_level:
		offset = Vector2.ZERO
		position_smoothing_enabled = true
		position_smoothing_speed   = config.smooth_speed if config else 5.0
	else:
		# Center the level in the viewport; disable smoothing.
		offset = Vector2.ZERO
		position_smoothing_enabled = false
		global_position = Vector2(_level_width / 2.0, _level_height / 2.0)


## Snap camera to player immediately — no interpolation lag on level start/restart.
func reset() -> void:
	if _player == null:
		return
	if _large_level:
		position_smoothing_enabled = false
		global_position = _player.global_position
		# Re-enable smoothing next frame so it doesn't snap on regular play.
		position_smoothing_enabled = config.smooth_speed > 0.0 if config else true
