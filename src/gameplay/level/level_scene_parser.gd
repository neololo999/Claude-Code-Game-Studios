## LevelSceneParser — Bridge: TileMapLayer scene → LevelData.
##
## Part of the TileMapLayer-first level authoring pipeline (ADR-001).
## The source of truth for a level is a .tscn data scene following this node
## convention:
##
##   LevelNNN (Node — root)
##   ├── TerrainMap (TileMapLayer)            ← terrain grid
##   ├── PlayerSpawn (Node2D)                 ← player start (position in pixels)
##   ├── Exit (Node2D)                        ← exit cell (position in pixels)
##   ├── Enemies (Node)
##   │   ├── Enemy (Node2D)                   ← one per enemy spawn
##   │   └── ...
##   └── Pickups (Node)
##       ├── Pickup (Node2D)                  ← one per treasure
##       └── ...
##
## All Node2D positions must be aligned to TileSet cell_size (pixel-snapped).
## Terrain data is read from the "terrain_type" Custom Data Layer on the TileSet
## (values: 0=EMPTY, 1=SOLID, 2=DIRT_SLOW, 3=DIRT_FAST, 4=LADDER, 5=ROPE).
## If the custom data layer is absent, falls back to atlas column + 1.
##
## Enemy rescate (respawn) position defaults to the spawn position.
## Override per-enemy by setting Node2D metadata keys "rescate_col" and
## "rescate_row" (int) in the inspector.
##
## Implements: docs/adr/ADR-001-level-authoring-tilemap-migration.md
class_name LevelSceneParser
extends RefCounted

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Parse a level data scene root and return a LevelData.
##
## level_id — the canonical ID (e.g. "level_001") injected by the caller.
##   If empty, derived from scene_root.name (lower-cased).
##
## Returns null and pushes an error on failure.
static func parse(scene_root: Node, level_id: String = "") -> LevelData:
	# --- TerrainMap -----------------------------------------------------------
	var tilemap: TileMapLayer = scene_root.get_node_or_null("TerrainMap") as TileMapLayer
	if tilemap == null:
		push_error(
			"LevelSceneParser: no TileMapLayer named 'TerrainMap' in scene '%s'"
			% scene_root.name
		)
		return null

	var tileset: TileSet = tilemap.tile_set
	if tileset == null:
		push_error(
			"LevelSceneParser: TerrainMap in scene '%s' has no TileSet assigned"
			% scene_root.name
		)
		return null

	var used_rect: Rect2i = tilemap.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		push_error(
			"LevelSceneParser: TerrainMap in scene '%s' has no tiles placed"
			% scene_root.name
		)
		return null

	if used_rect.position != Vector2i.ZERO:
		push_warning(
			"LevelSceneParser: TerrainMap in '%s' does not start at (0,0) "
			% scene_root.name
			+ "(origin = %s). Tiles will be offset." % used_rect.position
		)

	var cell_size: Vector2i = tileset.tile_size
	var grid_cols: int = used_rect.end.x
	var grid_rows: int = used_rect.end.y

	# --- terrain_type custom data layer (optional) ---------------------------
	var terrain_type_layer: int = _find_custom_data_layer(tileset, "terrain_type")

	# --- Terrain map ----------------------------------------------------------
	var terrain_map: PackedInt32Array = PackedInt32Array()
	terrain_map.resize(grid_cols * grid_rows)
	terrain_map.fill(0)

	for row: int in range(grid_rows):
		for col: int in range(grid_cols):
			var cell: Vector2i = Vector2i(col, row)
			var tile_data: TileData = tilemap.get_cell_tile_data(cell)
			if tile_data == null:
				continue
			var terrain_id: int
			if terrain_type_layer >= 0:
				terrain_id = tile_data.get_custom_data_by_layer_id(terrain_type_layer)
			else:
				# Fallback: atlas column + 1 = terrain_id (matches LevelTileMapBuilder).
				var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
				terrain_id = atlas_coords.x + 1
			terrain_map[row * grid_cols + col] = terrain_id

	# --- Entity positions -----------------------------------------------------
	var player_spawn: Vector2i = _pos_to_grid(
		scene_root.get_node_or_null("PlayerSpawn") as Node2D,
		cell_size,
		Vector2i(1, 1)
	)
	var exit_cell: Vector2i = _pos_to_grid(
		scene_root.get_node_or_null("Exit") as Node2D,
		cell_size,
		Vector2i(grid_cols - 2, 1)
	)

	var enemy_spawns: Array[Vector2i] = []
	var enemy_rescate_positions: Array[Vector2i] = []
	var enemies_node: Node = scene_root.get_node_or_null("Enemies")
	if enemies_node != null:
		for child: Node in enemies_node.get_children():
			if child is Node2D:
				var spawn: Vector2i = _pos_to_grid(child as Node2D, cell_size, Vector2i.ZERO)
				enemy_spawns.append(spawn)
				# Rescate position: metadata override or same as spawn.
				var rescate: Vector2i = spawn
				if child.has_meta("rescate_col") and child.has_meta("rescate_row"):
					rescate = Vector2i(
						int(child.get_meta("rescate_col")),
						int(child.get_meta("rescate_row"))
					)
				enemy_rescate_positions.append(rescate)

	var pickup_cells: Array[Vector2i] = []
	var pickups_node: Node = scene_root.get_node_or_null("Pickups")
	if pickups_node != null:
		for child: Node in pickups_node.get_children():
			if child is Node2D:
				pickup_cells.append(_pos_to_grid(child as Node2D, cell_size, Vector2i.ZERO))

	# --- Build LevelData ------------------------------------------------------
	var data: LevelData = LevelData.new()
	data.level_id = level_id if not level_id.is_empty() else scene_root.name.to_lower()
	data.level_index = _parse_level_index(level_id if not level_id.is_empty() else scene_root.name)
	data.grid_cols = grid_cols
	data.grid_rows = grid_rows
	data.terrain_map = terrain_map
	data.player_spawn = player_spawn
	data.enemy_spawns = enemy_spawns
	data.enemy_rescate_positions = enemy_rescate_positions
	data.pickup_cells = pickup_cells
	data.exit_cell = exit_cell
	return data

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _find_custom_data_layer(tileset: TileSet, layer_name: String) -> int:
	for i: int in range(tileset.get_custom_data_layers_count()):
		if tileset.get_custom_data_layer_name(i) == layer_name:
			return i
	return -1


static func _pos_to_grid(node: Node2D, cell_size: Vector2i, fallback: Vector2i) -> Vector2i:
	if node == null:
		return fallback
	return Vector2i(
		int(roundf(node.position.x / float(cell_size.x))),
		int(roundf(node.position.y / float(cell_size.y)))
	)


## Extracts the numeric index from strings like "level_001", "Level001", "Level01".
static func _parse_level_index(name: String) -> int:
	var regex := RegEx.new()
	regex.compile("(\\d+)")
	var result: RegExMatch = regex.search(name)
	if result != null:
		return result.get_string().to_int()
	return 1
