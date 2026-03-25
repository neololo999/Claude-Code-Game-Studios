## TerrainVisualizer — Displays terrain from LevelBuilder as ColorRects for editor preview.
##
## Attach to a Node2D in the level scene.
## At runtime, it reads level data and creates ColorRects for each terrain tile,
## allowing visual editing and understanding of the level layout.
class_name TerrainVisualizer
extends Node2D

@export var level_id: String = "level_002"

# Color mapping for terrain types
var terrain_colors: Dictionary = {
	0: Color.TRANSPARENT,  # EMPTY
	1: Color.DARK_GRAY,    # SOLID
	2: Color.BROWN,        # DIRT_SLOW
	3: Color.DARK_RED,     # DIRT_FAST
	4: Color.GOLD,         # LADDER
	5: Color.DARK_CYAN,    # ROPE
}

func _ready() -> void:
	var data: LevelData = LevelBuilder.build(level_id)
	if data == null:
		push_error("TerrainVisualizer: could not build level '%s'" % level_id)
		return

	# Create ColorRect for each terrain tile
	var idx: int = 0
	for row: int in range(data.grid_rows):
		for col: int in range(data.grid_cols):
			var terrain_id: int = data.terrain_map[idx]
			if terrain_id > 0:
				var rect = ColorRect.new()
				rect.size = Vector2(32, 32)
				rect.position = Vector2(col * 32, row * 32)
				rect.color = terrain_colors.get(terrain_id, Color.WHITE)
				add_child(rect)
			idx += 1
