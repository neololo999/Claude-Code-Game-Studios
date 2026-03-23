## TerrainRenderer — draws the level grid using sprites or colored rectangles.
##
## In Sprint 7+: loads PNG textures from assets/sprites/terrain/ if present.
## Falls back to ColorRect rendering (Sprint 6 behaviour) if textures are absent.
## This allows art assets to be dropped in without modifying game-logic code.
##
## Texture paths (conventional):
##   res://assets/sprites/terrain/solid.png
##   res://assets/sprites/terrain/dirt_slow.png
##   res://assets/sprites/terrain/dirt_fast.png
##   res://assets/sprites/terrain/ladder.png
##   res://assets/sprites/terrain/rope.png
##   res://assets/sprites/terrain/hole_open.png   (dug open state)
##
## Colour palette (fallback — used when texture is null):
##   EMPTY      → transparent (skip draw)
##   SOLID      → #888888 (mid-grey)
##   DIRT_SLOW  → #8B5E3C (brown)
##   DIRT_FAST  → #C8A97A (tan)
##   LADDER     → #FFD700 (gold)
##   ROPE       → #FF8C00 (dark orange)
##   (dug open) → #222222 (near-black)
##
## Implements: production/sprints/sprint-07.md#SPRITE-01
class_name TerrainRenderer
extends Node2D

# Texture asset paths — one per TileType (index matches TileType int value).
const TEXTURE_PATHS: Array[String] = [
	"",                                              # EMPTY (0) — no texture
	"res://assets/sprites/terrain/solid.png",        # SOLID (1)
	"res://assets/sprites/terrain/dirt_slow.png",    # DIRT_SLOW (2)
	"res://assets/sprites/terrain/dirt_fast.png",    # DIRT_FAST (3)
	"res://assets/sprites/terrain/ladder.png",       # LADDER (4)
	"res://assets/sprites/terrain/rope.png",         # ROPE (5)
]
const HOLE_OPEN_TEXTURE_PATH: String = "res://assets/sprites/terrain/hole_open.png"

# Colours indexed by TileType int value (fallback when texture absent).
const TILE_COLOURS: Array[Color] = [
	Color(0, 0, 0, 0),           # EMPTY (0) — transparent, skip
	Color("#888888"),             # SOLID (1)
	Color("#8B5E3C"),             # DIRT_SLOW (2)
	Color("#C8A97A"),             # DIRT_FAST (3)
	Color("#FFD700"),             # LADDER (4)
	Color("#FF8C00"),             # ROPE (5)
]
const OPEN_HOLE_COLOUR: Color = Color("#222222")

# Loaded textures — null if asset not present.
var _textures: Array[Texture2D] = []
var _hole_open_texture: Texture2D = null

var _grid: GridSystem = null
var _terrain: TerrainSystem = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Connect to grid + terrain and draw the initial frame.
## Must be called after TerrainSystem.initialize().
func setup(grid: GridSystem, terrain: TerrainSystem) -> void:
	_grid    = grid
	_terrain = terrain
	_load_textures()
	if not terrain.dig_state_changed.is_connected(_on_dig_state_changed):
		terrain.dig_state_changed.connect(_on_dig_state_changed)
	queue_redraw()


## Force a full redraw of all cells — use after level load.
func refresh() -> void:
	queue_redraw()


# ---------------------------------------------------------------------------
# Texture loading
# ---------------------------------------------------------------------------

func _load_textures() -> void:
	_textures.clear()
	for i in range(TEXTURE_PATHS.size()):
		var path: String = TEXTURE_PATHS[i]
		if path.is_empty() or not ResourceLoader.exists(path):
			_textures.append(null)
		else:
			_textures.append(ResourceLoader.load(path) as Texture2D)
	if ResourceLoader.exists(HOLE_OPEN_TEXTURE_PATH):
		_hole_open_texture = ResourceLoader.load(HOLE_OPEN_TEXTURE_PATH) as Texture2D
	else:
		_hole_open_texture = null


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _grid == null or _terrain == null:
		return
	var cell: int = GridSystem.CELL_SIZE
	for row in range(_grid.rows):
		for col in range(_grid.cols):
			_draw_cell(col, row, cell)


func _draw_cell(col: int, row: int, cell: int) -> void:
	var rect := Rect2(col * cell, row * cell, cell, cell)
	var tile: TerrainSystem.TileType = _terrain.get_tile_type(col, row)

	# Check for open/closing dig hole.
	if tile == TerrainSystem.TileType.DIRT_SLOW or tile == TerrainSystem.TileType.DIRT_FAST:
		var dig_state: TerrainSystem.DigState = _terrain.get_dig_state(col, row)
		if dig_state == TerrainSystem.DigState.OPEN or dig_state == TerrainSystem.DigState.CLOSING:
			if _hole_open_texture != null:
				draw_texture_rect(_hole_open_texture, rect, false)
			else:
				draw_rect(rect, OPEN_HOLE_COLOUR)
			return

	var tile_index: int = int(tile)
	if tile_index <= 0 or tile_index >= TILE_COLOURS.size():
		return  # EMPTY or out-of-range — nothing to draw

	# Sprite path: use texture if loaded, otherwise colour fallback.
	if tile_index < _textures.size() and _textures[tile_index] != null:
		draw_texture_rect(_textures[tile_index], rect, false)
	else:
		var colour: Color = TILE_COLOURS[tile_index]
		if colour.a > 0.0:
			draw_rect(rect, colour)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Single-cell incremental update on dig state change — no full redraw.
func _on_dig_state_changed(
		col: int, row: int,
		_old: TerrainSystem.DigState,
		_new: TerrainSystem.DigState) -> void:
	_draw_cell(col, row, GridSystem.CELL_SIZE)
	queue_redraw()
