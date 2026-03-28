## EntityRenderer — draws player and enemy positions using sprites or colored rects.
##
## In Sprint 7+: loads PNG textures from assets/sprites/entities/ if present.
## Falls back to ColorRect rendering if textures absent.
##
## Player texture: res://assets/sprites/entities/player.png  (blue #00AAFF fallback)
## Enemy texture:  res://assets/sprites/entities/enemy.png   (red  #FF2222 fallback)
##
## Implements: production/sprints/sprint-07.md#SPRITE-02
class_name EntityRenderer
extends Node2D

const PLAYER_TEXTURE_PATH: String = "res://assets/sprites/entities/player.png"
const ENEMY_TEXTURE_PATH:  String = "res://assets/sprites/entities/enemy.png"

const PLAYER_COLOUR: Color = Color("#00AAFF")
const ENEMY_COLOUR:  Color = Color("#FF2222")

var _player_texture: Texture2D = null
var _enemy_texture:  Texture2D = null

var _player: Node2D = null
var _enemies: Array[Node2D] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire to player and enemy nodes. Call after LevelSystem._initialize_level().
func setup(player: Node2D, enemies: Array[Node2D]) -> void:
	_player  = player
	_enemies = enemies.duplicate()
	_load_textures()


## Update enemy list — call when enemies are added/removed (e.g. level load).
func set_enemies(enemies: Array[Node2D]) -> void:
	_enemies = enemies.duplicate()


# ---------------------------------------------------------------------------
# Texture loading
# ---------------------------------------------------------------------------

func _load_textures() -> void:
	_player_texture = ResourceLoader.load(PLAYER_TEXTURE_PATH) as Texture2D \
		if ResourceLoader.exists(PLAYER_TEXTURE_PATH) else null
	_enemy_texture  = ResourceLoader.load(ENEMY_TEXTURE_PATH) as Texture2D \
		if ResourceLoader.exists(ENEMY_TEXTURE_PATH) else null


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var half: float = GridSystem.CELL_SIZE / 2.0
	var size := Vector2(GridSystem.CELL_SIZE, GridSystem.CELL_SIZE)

	# Player (only when the Player node has no dedicated visual child).
	if not _player_has_embedded_visual():
		var p_local: Vector2 = to_local(_player.global_position)
		var p_rect  := Rect2(p_local - Vector2(half, half), size)
		if _player_texture != null:
			draw_texture_rect(_player_texture, p_rect, false)
		else:
			draw_rect(p_rect, PLAYER_COLOUR)

	# Enemies.
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var e_local: Vector2 = to_local(enemy.global_position)
		var e_rect  := Rect2(e_local - Vector2(half, half), size)
		if _enemy_texture != null:
			draw_texture_rect(_enemy_texture, e_rect, false)
		else:
			draw_rect(e_rect, ENEMY_COLOUR)


func _player_has_embedded_visual() -> bool:
	if _player == null:
		return false
	for child: Node in _player.get_children():
		if child is AnimatedSprite2D and (child as AnimatedSprite2D).visible:
			return true
		if child is Sprite2D and (child as Sprite2D).visible:
			return true
	return false
