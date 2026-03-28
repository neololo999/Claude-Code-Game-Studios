## PlayerAnimationController — lightweight bridge from PlayerMovement signals
## to AnimatedSprite2D playback (editor-first workflow).
##
## Attach this script directly to an AnimatedSprite2D child of PlayerMovement.
## The SpriteFrames resource and animations are authored in the Godot editor.
class_name PlayerAnimationController
extends AnimatedSprite2D

@export var player_path: NodePath = NodePath("..")
@export var idle_animation: StringName = &"idle"
@export var move_animation: StringName = &"run"
@export var death_animation: StringName = &"dead"
@export var idle_delay_seconds: float = 0.12

var _player: PlayerMovement = null
var _idle_timer: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerMovement
	if _player != null:
		if not _player.player_moved.is_connected(_on_player_moved):
			_player.player_moved.connect(_on_player_moved)
		if not _player.player_died.is_connected(_on_player_died):
			_player.player_died.connect(_on_player_died)
	_play_if_exists(idle_animation)
	set_process(true)


func _process(delta: float) -> void:
	if _is_dead:
		return
	if _idle_timer <= 0.0:
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_play_if_exists(idle_animation)


func _on_player_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _is_dead:
		return
	var dx: int = to_cell.x - from_cell.x
	if dx != 0:
		flip_h = dx < 0
	_play_if_exists(move_animation)
	_idle_timer = maxf(0.0, idle_delay_seconds)


func _on_player_died() -> void:
	_is_dead = true
	_play_if_exists(death_animation)


func _play_if_exists(anim_name: StringName) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(anim_name):
		play(anim_name)
