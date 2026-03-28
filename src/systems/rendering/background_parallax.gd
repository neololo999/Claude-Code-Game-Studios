class_name BackgroundParallax
extends TextureRect
## Controls parallax offset of the background shader based on player position.
## Attach to a TextureRect with the cyberpunk_background shader material.

## Reference to the player node (injected by bootstrap)
var player: Node2D

## Viewport center for parallax calculation
var viewport_center: Vector2

## Smoothing factor for parallax movement (lower = smoother)
@export var smoothing: float = 5.0

## Current parallax offset (smoothed)
var _current_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	viewport_center = get_viewport_rect().size / 2.0


func _process(delta: float) -> void:
	if not player or not material:
		return
	
	# Calculate offset from viewport center (normalized to -1..1 range)
	var player_pos: Vector2 = player.global_position
	var offset_from_center: Vector2 = player_pos - viewport_center
	
	# Normalize based on viewport size (so edges give ~1.0 offset)
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_offset: Vector2 = offset_from_center / viewport_size
	
	# Smooth the offset for fluid movement
	_current_offset = _current_offset.lerp(target_offset, delta * smoothing)
	
	# Apply to shader
	material.set_shader_parameter("parallax_offset", _current_offset)
