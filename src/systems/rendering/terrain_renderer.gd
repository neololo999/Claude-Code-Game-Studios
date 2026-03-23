## TerrainRenderer — draws the level grid as colored rectangles.
##
## Renders each cell as a distinct colour per TileType. Connected to
## TerrainSystem.dig_state_changed for incremental single-cell updates on dig
## events — no full redraw on every tile change.
##
## Colour palette (placeholder — replaced by sprite atlas in Sprint 7):
##   EMPTY      → transparent (skip draw)
##   SOLID      → #888888 (mid-grey)
##   DIRT_SLOW  → #8B5E3C (brown)
##   DIRT_FAST  → #C8A97A (tan)
##   LADDER     → #FFD700 (gold)
##   ROPE       → #FF8C00 (dark orange)
##   (dug open) → #222222 (near-black — indicates an open hole)
##
## Implements: production/sprints/sprint-06.md#RENDER-01
class_name TerrainRenderer
extends Node2D

# Colours indexed by TileType int value.
const TILE_COLOURS: Array[Color] = [
	Color(0, 0, 0, 0),           # EMPTY (0) — transparent, skip
	Color("#888888"),             # SOLID (1)
	Color("#8B5E3C"),             # DIRT_SLOW (2)
	Color("#C8A97A"),             # DIRT_FAST (3)
	Color("#FFD700"),             # LADDER (4)
	Color("#FF8C00"),             # ROPE (5)
]
const OPEN_HOLE_COLOUR: Color = Color("#222222")

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
	if not terrain.dig_state_changed.is_connected(_on_dig_state_changed):
		terrain.dig_state_changed.connect(_on_dig_state_changed)
	queue_redraw()


## Force a full redraw of all cells — use after level load.
func refresh() -> void:
	queue_redraw()


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

	# If this cell is a dug tile, check if the hole is open.
	if tile == TerrainSystem.TileType.DIRT_SLOW or tile == TerrainSystem.TileType.DIRT_FAST:
		var dig_state: TerrainSystem.DigState = _terrain.get_dig_state(col, row)
		if dig_state == TerrainSystem.DigState.OPEN or dig_state == TerrainSystem.DigState.CLOSING:
			draw_rect(rect, OPEN_HOLE_COLOUR)
			return

	var tile_index: int = int(tile)
	if tile_index < 0 or tile_index >= TILE_COLOURS.size():
		return
	var colour: Color = TILE_COLOURS[tile_index]
	if colour.a == 0.0:
		return  # EMPTY — nothing to draw
	draw_rect(rect, colour)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Single-cell incremental update on dig state change — no full redraw.
func _on_dig_state_changed(
		col: int, row: int,
		_old: TerrainSystem.DigState,
		_new: TerrainSystem.DigState) -> void:
	var cell: int = GridSystem.CELL_SIZE
	_draw_cell(col, row, cell)
	# queue_redraw() is needed to make the single-cell update visible.
	# Godot batches redraws; calling it here is cheap (one draw call per frame max).
	queue_redraw()
