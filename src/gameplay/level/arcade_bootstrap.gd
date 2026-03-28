## ArcadeBootstrap — initialises all game systems for a hand-designed arcade level.
##
## The arcade level scene must contain:
##   - TileMapLayer children named: "Solid", "DirtSlow", "DirtFast", "Ladder", "Rope"
##     (only the layers that exist are read; missing layers are skipped)
##   - A Marker2D named "PlayerSpawn" for the player starting cell
##   - A Marker2D named "Exit" for the exit cell
##   - Marker2D nodes in a group "Pickup" for pickup positions
##   - (optional) Marker2D nodes in a group "EnemySpawn" for enemies
##
## Grid size is auto-detected from TileMap bounds unless overridden.
## Cell size is read from tile_size on the first TileMapLayer found.
##
## Initialization order matches LevelBootstrap exactly.
##
## Implements: design/gdd/arcade-mode.md
class_name ArcadeBootstrap
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Delay before reloading after death (seconds).
const DEATH_RESTART_DELAY: float = 0.4

## Delay before advancing after victory (seconds).
const VICTORY_NEXT_LEVEL_DELAY: float = 1.0

## Arcade scene directory used by numeric next-level discovery.
const ARCADE_LEVELS_DIR: String = "res://scenes/levels/arcade"

# ---------------------------------------------------------------------------
# Exports — node references (assign from scene or inspector)
# ---------------------------------------------------------------------------

@export var grid: GridSystem
@export var terrain: TerrainSystem
@export var gravity: GridGravity
@export var player: PlayerMovement
@export var dig: DigSystem
@export var pickups: PickupSystem
@export var input: InputSystem
@export var enemy: EnemyController
@export var entity_renderer: EntityRenderer

## Background parallax controller (optional)
@export var background_parallax: BackgroundParallax

## Arcade HUD (optional)
@export var hud: ArcadeHUD

# ---------------------------------------------------------------------------
# Exports — config resources (optional; fall back to defaults when null)
# ---------------------------------------------------------------------------

@export var terrain_config_res: TerrainConfig
@export var gravity_config_res: GravityConfig
@export var input_config_res: InputConfig
@export var enemy_config_res: EnemyConfig

# ---------------------------------------------------------------------------
# Exports — TileMap source and grid overrides
# ---------------------------------------------------------------------------

## Parent node containing all TileMapLayer children. Must be assigned in inspector.
@export var tilemap_root: Node

## Override grid column count. If 0, auto-detect from TileMap bounds.
@export var override_grid_cols: int = 0

## Override grid row count. If 0, auto-detect from TileMap bounds.
@export var override_grid_rows: int = 0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _cell_data: Array[int] = []
var _grid_cols: int = 0
var _grid_rows: int = 0
var _origin: Vector2i = Vector2i.ZERO
var _tile_size: Vector2 = Vector2(16.0, 16.0)
var _dirt_layers: Array[TileMapLayer] = []  # Dirt TileMapLayers for dig visual updates
var _dug_tiles: Dictionary = {}  # Stores tile data for restoration: tile_coord -> {layer, source_id, atlas_coords, alt_tile}
var _transition_locked: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# -----------------------------------------------------------------------
	# Auto-discover sibling nodes by conventional name when exports are null.
	# This makes the bootstrap resilient to inspector wiring being lost.
	# -----------------------------------------------------------------------
	var p: Node = get_parent()
	if grid       == null: grid       = p.get_node_or_null("GridSystem")    as GridSystem
	if terrain    == null: terrain    = p.get_node_or_null("TerrainSystem") as TerrainSystem
	if gravity    == null: gravity    = p.get_node_or_null("GridGravity")   as GridGravity
	if player     == null: player     = p.get_node_or_null("PlayerMovement") as PlayerMovement
	if dig        == null: dig        = p.get_node_or_null("DigSystem")      as DigSystem
	if pickups    == null: pickups    = p.get_node_or_null("PickupSystem")   as PickupSystem
	if input      == null: input      = p.get_node_or_null("InputSystem")    as InputSystem
	if entity_renderer == null:
		entity_renderer = p.get_node_or_null("EntityRenderer") as EntityRenderer
	if enemy == null:
		enemy = p.get_node_or_null("EnemyController") as EnemyController
	if background_parallax == null:
		var bg_layer: Node = p.get_node_or_null("BackgroundLayer")
		if bg_layer != null:
			background_parallax = bg_layer.get_node_or_null("Background") as BackgroundParallax
	if hud == null:
		hud = p.get_node_or_null("ArcadeHUD") as ArcadeHUD
	if tilemap_root == null:
		tilemap_root = p.get_node_or_null("TileMapRoot")

	# -----------------------------------------------------------------------
	# Guard — all required nodes must be present.
	# -----------------------------------------------------------------------
	if tilemap_root == null:
		push_error("ArcadeBootstrap._ready: 'TileMapRoot' node not found in parent. Aborting initialisation.")
		return

	# -----------------------------------------------------------------------
	# Step 1 — Resolve configs — create defaults so setup() never receives null.
	# Using a single shared TerrainConfig instance for TerrainSystem and
	# DigSystem so both read identical dig_duration values.
	# -----------------------------------------------------------------------
	var t_config: TerrainConfig = (
		terrain_config_res if terrain_config_res != null else TerrainConfig.new()
	)
	var g_config: GravityConfig = (
		gravity_config_res if gravity_config_res != null else GravityConfig.new()
	)

	# -----------------------------------------------------------------------
	# Step 2 — Read TileMapLayer data into a flat cell array.
	# -----------------------------------------------------------------------
	_read_tilemap()
	if _grid_cols == 0 or _grid_rows == 0:
		push_error("ArcadeBootstrap._ready: TileMap read produced a 0×0 grid. Aborting.")
		return

	# -----------------------------------------------------------------------
	# Step 3 — TerrainSystem
	# setup() takes (GridSystem, TerrainConfig); config is NOT a public property.
	# -----------------------------------------------------------------------
	terrain.setup(grid, t_config)

	# -----------------------------------------------------------------------
	# Step 4 — GridGravity
	# setup(grid, terrain, config) — grid first, terrain second.
	# -----------------------------------------------------------------------
	gravity.setup(grid, terrain, g_config)

	# -----------------------------------------------------------------------
	# Step 5 — InputSystem config
	# InputSystem has no setup() method; @export var config is the only hook.
	# -----------------------------------------------------------------------
	if input_config_res != null:
		input.config = input_config_res

	# -----------------------------------------------------------------------
	# Step 6 — PlayerMovement
	# setup() takes (grid, terrain, gravity, input, input_config, fall_speed).
	# -----------------------------------------------------------------------
	player.setup(grid, terrain, gravity, input, input.config, g_config.fall_speed)

	# -----------------------------------------------------------------------
	# Step 7 — DigSystem
	# setup(terrain, gravity, player, terrain_config, player_id)
	# -----------------------------------------------------------------------
	dig.setup(terrain, gravity, player, t_config, player.entity_id)

	# -----------------------------------------------------------------------
	# Step 8 — PickupSystem
	# setup(grid, player) — internally connects player.player_moved.
	# -----------------------------------------------------------------------
	pickups.setup(grid, player)

	# -----------------------------------------------------------------------
	# Step 8.5 — EntityRenderer (optional)
	# -----------------------------------------------------------------------
	if entity_renderer != null:
		entity_renderer.visible = false
		entity_renderer.set_process(false)

	# -----------------------------------------------------------------------
	# Step 8.6 — BackgroundParallax (optional)
	# -----------------------------------------------------------------------
	if background_parallax != null:
		background_parallax.player = player

	# -----------------------------------------------------------------------
	# Step 8.7 — ArcadeHUD (optional)
	# -----------------------------------------------------------------------
	if hud != null:
		hud.setup(pickups)
		hud.back_requested.connect(_on_back_requested)
		hud.retry_requested.connect(_on_retry_requested)

	# -----------------------------------------------------------------------
	# Step 9 — EnemyController (optional)
	# -----------------------------------------------------------------------
	if enemy != null:
		enemy.setup(grid, terrain, gravity, player, enemy_config_res, 1)

	# -----------------------------------------------------------------------
	# Step 10 — Dig input connection
	# -----------------------------------------------------------------------
	input.dig_requested.connect(dig._on_dig_requested)

	# -----------------------------------------------------------------------
	# Step 11 — Build terrain, spawn player, register pickups and enemy
	# -----------------------------------------------------------------------
	_initialize_from_tilemap()

	# -----------------------------------------------------------------------
	# Step 12 — Console feedback signals
	# -----------------------------------------------------------------------
	player.player_moved.connect(_on_player_moved)
	dig.dig_started.connect(_on_dig_started)
	pickups.pickup_collected.connect(_on_pickup_collected)
	pickups.all_pickups_collected.connect(_on_all_collected)
	pickups.player_reached_exit.connect(_on_player_won)
	
	# Connect terrain dig state changes to update TileMap visuals
	terrain.dig_state_changed.connect(_on_dig_state_changed)

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Reads all named TileMapLayer children of tilemap_root into _cell_data.
## Detects grid size from tile bounds unless overrides are set.
func _read_tilemap() -> void:
	# Layer name → TileType mapping.
	var layer_type_map: Dictionary[String, int] = {
		"Solid":    TerrainSystem.TileType.SOLID,
		"DirtSlow": TerrainSystem.TileType.DIRT_SLOW,
		"DirtFast": TerrainSystem.TileType.DIRT_FAST,
		"Ladder":   TerrainSystem.TileType.LADDER,
		"Rope":     TerrainSystem.TileType.ROPE,
	}

	# Collect TileMapLayer children.
	var layers: Array[TileMapLayer] = []
	for child: Node in tilemap_root.get_children():
		if child is TileMapLayer:
			layers.append(child as TileMapLayer)

	if layers.is_empty():
		push_error("ArcadeBootstrap._read_tilemap: no TileMapLayer children found in tilemap_root.")
		return

	# Detect tile size from the first layer's TileSet.
	var first_layer: TileMapLayer = layers[0]
	if first_layer.tile_set != null:
		_tile_size = Vector2(first_layer.tile_set.tile_size)
	else:
		push_warning("ArcadeBootstrap._read_tilemap: first TileMapLayer has no TileSet assigned; using default tile size 16×16.")

	# Collect all used cells across all layers to determine bounds.
	var all_cells: Array[Vector2i] = []
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			all_cells.append(cell)

	if all_cells.is_empty():
		push_error("ArcadeBootstrap._read_tilemap: no cells found in any TileMapLayer.")
		return

	var min_col: int = all_cells[0].x
	var max_col: int = all_cells[0].x
	var min_row: int = all_cells[0].y
	var max_row: int = all_cells[0].y

	for cell: Vector2i in all_cells:
		min_col = mini(min_col, cell.x)
		max_col = maxi(max_col, cell.x)
		min_row = mini(min_row, cell.y)
		max_row = maxi(max_row, cell.y)

	# Extend bounds to include all entity Node2D positions (Sprite2D or Marker2D).
	# This prevents _origin from being AHEAD of spawn/exit/pickup positions,
	# which would produce negative (invalid) grid cells.
	var _p: Node = get_parent()
	for bound_name: String in ["PlayerSpawn", "Exit"] as Array[String]:
		var m: Node = _p.find_child(bound_name, true, false)
		if m is Node2D:
			var tc: Vector2i = Vector2i(
				int((m as Node2D).position.x / _tile_size.x),
				int((m as Node2D).position.y / _tile_size.y)
			)
			min_col = mini(min_col, tc.x)
			max_col = maxi(max_col, tc.x)
			min_row = mini(min_row, tc.y)
			max_row = maxi(max_row, tc.y)
	for node: Node in get_tree().get_nodes_in_group("Pickup"):
		if node is Node2D:
			var tc: Vector2i = Vector2i(
				int((node as Node2D).position.x / _tile_size.x),
				int((node as Node2D).position.y / _tile_size.y)
			)
			min_col = mini(min_col, tc.x)
			max_col = maxi(max_col, tc.x)
			min_row = mini(min_row, tc.y)
			max_row = maxi(max_row, tc.y)

	_origin = Vector2i(min_col, min_row)
	_grid_cols = override_grid_cols if override_grid_cols > 0 else (max_col - min_col + 1)
	_grid_rows = override_grid_rows if override_grid_rows > 0 else (max_row - min_row + 1)
	push_warning("[ARC] TileMap bounds: origin=%s grid=%d×%d" % [_origin, _grid_cols, _grid_rows])

	# Build flat row-major cell data array filled with EMPTY.
	_cell_data.resize(_grid_cols * _grid_rows)
	_cell_data.fill(TerrainSystem.TileType.EMPTY)

	# Write each named layer's cells into the flat array.
	for layer: TileMapLayer in layers:
		var layer_name: String = String(layer.name)
		if not layer_type_map.has(layer_name):
			continue
		var tile_type: int = layer_type_map[layer_name]
		# Store dirt layers for dig visual updates
		if tile_type == TerrainSystem.TileType.DIRT_SLOW or tile_type == TerrainSystem.TileType.DIRT_FAST:
			_dirt_layers.append(layer)
		for cell: Vector2i in layer.get_used_cells():
			var col: int = cell.x - _origin.x
			var row: int = cell.y - _origin.y
			if col >= 0 and col < _grid_cols and row >= 0 and row < _grid_rows:
				_cell_data[row * _grid_cols + col] = tile_type


## Initialises terrain, spawns the player, and registers all pickups and enemies
## from the scene's Marker2D nodes.
func _initialize_from_tilemap() -> void:
	# Load the flat cell array into TerrainSystem (also initialises GridSystem).
	terrain.initialize(_cell_data, _grid_cols, _grid_rows)

	# Align GridSystem world coordinates with the TileMap origin so that
	# grid_to_world(0, 0) maps to world (_origin * CELL_SIZE), not (0, 0).
	grid.world_offset = Vector2(_origin) * GridSystem.CELL_SIZE

	# Locate the PlayerSpawn node (Sprite2D or Marker2D) and spawn the player.
	var spawn_node: Node = get_parent().find_child("PlayerSpawn", true, false)
	if spawn_node == null or not spawn_node is Node2D:
		push_error("ArcadeBootstrap._initialize_from_tilemap: 'PlayerSpawn' not found in scene.")
		return
	var player_cell: Vector2i = _node2d_to_cell(spawn_node as Node2D, _tile_size)
	player.spawn(player_cell)
	# Hide spawn marker at runtime (player sprite takes over)
	if spawn_node is CanvasItem:
		(spawn_node as CanvasItem).visible = false

	# Collect pickup cells from the "Pickup" group.
	var pickup_cells: Array[Vector2i] = []
	for node: Node in get_tree().get_nodes_in_group("Pickup"):
		if node is Node2D:
			var cell: Vector2i = _node2d_to_cell(node as Node2D, _tile_size)
			pickup_cells.append(cell)
			# Setup pickup sprite to hide on collection
			if node is PickupSprite:
				(node as PickupSprite).setup(pickups, cell)

	# Locate the Exit node (Sprite2D or Marker2D).
	var exit_node: Node = get_parent().find_child("Exit", true, false)
	var exit_cell: Vector2i = Vector2i.ZERO
	if exit_node != null and exit_node is Node2D:
		exit_cell = _node2d_to_cell(exit_node as Node2D, _tile_size)
	else:
		push_warning("ArcadeBootstrap._initialize_from_tilemap: 'Exit' not found; exit defaults to (0, 0).")

	pickups.initialize(pickup_cells, exit_cell)

	# Initialize HUD with total pickups count.
	if hud != null:
		hud.initialize(pickup_cells.size())

	# Spawn enemy from the first node in the "EnemySpawn" group (optional).
	if enemy != null:
		var enemy_nodes: Array[Node] = get_tree().get_nodes_in_group("EnemySpawn")
		if not enemy_nodes.is_empty() and enemy_nodes[0] is Node2D:
			var enemy_node: Node2D = enemy_nodes[0] as Node2D
			var enemy_cell: Vector2i = _node2d_to_cell(enemy_node, _tile_size)
			enemy.spawn(enemy_cell, enemy_cell)
			enemy.enemy_reached_player.connect(_on_enemy_reached_player)
			enemy.enemy_trapped.connect(_on_enemy_trapped)
			enemy.enemy_escaped.connect(_on_enemy_escaped)
			# Hide spawn marker at runtime (enemy sprite takes over)
			if enemy_node is CanvasItem:
				(enemy_node as CanvasItem).visible = false

	push_warning("[ARC] Level initialised: %d×%d grid, %d pickups, exit at %s" % [
		_grid_cols, _grid_rows, pickup_cells.size(), exit_cell
	])


## Converts a Node2D world position to a grid cell relative to _origin.
func _node2d_to_cell(node: Node2D, tile_size: Vector2) -> Vector2i:
	return Vector2i(
		int(node.position.x / tile_size.x),
		int(node.position.y / tile_size.y)
	) - _origin

# ---------------------------------------------------------------------------
# Signal callbacks — console feedback (push_warning for arcade logging)
# ---------------------------------------------------------------------------

func _on_player_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	push_warning("[ARC] Player moved %s → %s" % [from_cell, to_cell])
	if _is_enemy_on_cell(to_cell):
		_trigger_restart()


## dig_started(col: int, row: int) — matches DigSystem signal signature.
func _on_dig_started(col: int, row: int) -> void:
	push_warning("[ARC] Dig started at (%d, %d)" % [col, row])


## pickup_collected(col: int, row: int, remaining: int) — matches PickupSystem signal.
func _on_pickup_collected(col: int, row: int, remaining: int) -> void:
	push_warning("[ARC] Pickup at (%d, %d) collected! %d remaining" % [col, row, remaining])


func _on_all_collected() -> void:
	push_warning("[ARC] All pickups collected! Exit is now open!")


func _on_player_won() -> void:
	push_warning("[ARC] Player reached exit — LEVEL COMPLETE!")
	if _transition_locked:
		return
	# Exit occupied by an enemy still counts as death, not victory.
	if _is_enemy_on_cell(player.current_cell):
		_trigger_restart()
		return
	_transition_locked = true
	var timer: SceneTreeTimer = get_tree().create_timer(VICTORY_NEXT_LEVEL_DELAY)
	timer.timeout.connect(_advance_to_next_arcade_level)


func _on_enemy_reached_player(enemy_id: int, cell: Vector2i) -> void:
	push_warning("[ARC] Enemy %d reached player at %s — PLAYER DIES!" % [enemy_id, cell])
	_trigger_restart()


func _on_enemy_trapped(enemy_id: int, cell: Vector2i) -> void:
	push_warning("[ARC] Enemy %d TRAPPED in hole at %s!" % [enemy_id, cell])


func _on_enemy_escaped(enemy_id: int) -> void:
	push_warning("[ARC] Enemy %d escaped and respawned!" % [enemy_id])


func _on_back_requested() -> void:
	push_warning("[ARC] Back to menu requested")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_retry_requested() -> void:
	push_warning("[ARC] Retry level requested")
	_trigger_restart()


## dig_state_changed(col, row, old_state, new_state) — hides TileMap tiles when dug
func _on_dig_state_changed(col: int, row: int, old_state: TerrainSystem.DigState, new_state: TerrainSystem.DigState) -> void:
	# Convert grid coords back to TileMap coords
	var tile_coord: Vector2i = Vector2i(col + _origin.x, row + _origin.y)
	
	if new_state == TerrainSystem.DigState.OPEN:
		# Tile is dug open — hide it in all dirt layers
		for layer: TileMapLayer in _dirt_layers:
			var source_id: int = layer.get_cell_source_id(tile_coord)
			if source_id != -1:
				# Store tile data for restoration
				var atlas_coords: Vector2i = layer.get_cell_atlas_coords(tile_coord)
				var alt_tile: int = layer.get_cell_alternative_tile(tile_coord)
				_dug_tiles[tile_coord] = {
					"layer": layer,
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alt_tile": alt_tile
				}
				layer.erase_cell(tile_coord)
	elif new_state == TerrainSystem.DigState.INTACT and old_state == TerrainSystem.DigState.CLOSING:
		# Hole closed and restored — restore the tile visually
		if _dug_tiles.has(tile_coord):
			var data: Dictionary = _dug_tiles[tile_coord]
			var layer: TileMapLayer = data["layer"]
			layer.set_cell(tile_coord, data["source_id"], data["atlas_coords"], data["alt_tile"])
			_dug_tiles.erase(tile_coord)


# ---------------------------------------------------------------------------
# Transition helpers
# ---------------------------------------------------------------------------

func _trigger_restart() -> void:
	if _transition_locked:
		return
	_transition_locked = true
	if player != null and is_instance_valid(player):
		player.die()
	var timer: SceneTreeTimer = get_tree().create_timer(DEATH_RESTART_DELAY)
	timer.timeout.connect(func() -> void:
		get_tree().reload_current_scene()
	)


func _advance_to_next_arcade_level() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	var next_scene_path: String = _compute_next_arcade_scene_path(
		current_scene.scene_file_path
	)
	if not next_scene_path.is_empty() and FileAccess.file_exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
		return
	# No next arcade scene available yet: return to menu instead of stalling.
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _is_enemy_on_cell(cell: Vector2i) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.current_cell == cell


func _compute_next_arcade_scene_path(current_path: String) -> String:
	if current_path.is_empty():
		return ""
	var dir_path: String = current_path.get_base_dir()
	if not dir_path.begins_with(ARCADE_LEVELS_DIR):
		return ""

	var basename: String = current_path.get_file().get_basename()
	var prefix: String = ""
	var number_part: String = basename

	var sep: int = basename.rfind("_")
	if sep >= 0:
		var tail: String = basename.substr(sep + 1)
		if tail.is_valid_int():
			prefix = basename.substr(0, sep + 1)
			number_part = tail

	if not number_part.is_valid_int():
		return ""

	var width: int = number_part.length()
	var next_number: int = int(number_part) + 1
	var next_number_text: String = str(next_number)
	while next_number_text.length() < width:
		next_number_text = "0" + next_number_text

	return "%s/%s%s.tscn" % [dir_path, prefix, next_number_text]
