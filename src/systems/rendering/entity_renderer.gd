## EntityRenderer — draws player and enemy positions as colored rectangles.
##
## Tracks Node2D positions in _process and repositions colored rects.
## Player = blue (#00AAFF), Enemies = red (#FF2222).
## One cell-sized rect per entity.
##
## Implements: production/sprints/sprint-06.md#RENDER-02
class_name EntityRenderer
extends Node2D

const PLAYER_COLOUR: Color = Color("#00AAFF")
const ENEMY_COLOUR:  Color = Color("#FF2222")

var _player: Node2D = null
var _enemies: Array[Node2D] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire to player and enemy nodes. Call after LevelSystem._initialize_level().
func setup(player: Node2D, enemies: Array[Node2D]) -> void:
	_player  = player
	_enemies = enemies.duplicate()


## Update enemy list — call when enemies are added/removed (e.g. level load).
func set_enemies(enemies: Array[Node2D]) -> void:
	_enemies = enemies.duplicate()


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

	# Player — centred on Node2D world position.
	var p_local: Vector2 = to_local(_player.global_position)
	draw_rect(Rect2(p_local - Vector2(half, half), size), PLAYER_COLOUR)

	# Enemies.
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var e_local: Vector2 = to_local(enemy.global_position)
		draw_rect(Rect2(e_local - Vector2(half, half), size), ENEMY_COLOUR)
