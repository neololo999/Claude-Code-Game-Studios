## LevelTileMapBuilder — Auto-populates a TileMapLayer from LevelBuilder data.
##
## Attach this to a TileMapLayer node. In _ready(), it reads the level data
## and fills the tilemap so you can see it visually and edit it manually.
##
## Tile IDs match TerrainSystem:
##   0 = EMPTY
##   1 = SOLID
##   2 = DIRT_SLOW
##   3 = DIRT_FAST
##   4 = LADDER
##   5 = ROPE
class_name LevelTileMapBuilder
extends TileMapLayer

@export var level_id: String = "level_002"

func _ready() -> void:
	var data: LevelData = LevelBuilder.build(level_id)
	if data == null:
		push_error("LevelTileMapBuilder: could not build level '%s'" % level_id)
		return

	# Populate the tilemap from terrain data
	var idx: int = 0
	for row: int in range(data.grid_rows):
		for col: int in range(data.grid_cols):
			var terrain_id: int = data.terrain_map[idx]
			# Only place tiles for non-empty cells
			if terrain_id > 0:
				set_cell(Vector2i(col, row), 0, Vector2i(terrain_id - 1, 0))
			idx += 1
