## LevelData — Serialisable data container for a single Dig & Dash level.
##
## Stored as a .tres resource under res://resources/levels/.
## LevelSystem loads this resource and drives all subsystem initialisation.
##
## Terrain map layout:
##   Flat row-major PackedInt32Array of length grid_cols * grid_rows.
##   Values are TerrainSystem.TileType int values (0=EMPTY, 1=SOLID, …).
##   Index formula: row * grid_cols + col
##
## Implements: production/sprints/sprint-03.md#LVL-01
class_name LevelData
extends Resource

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

## Unique level identifier, e.g. "level_001". Used for file path resolution.
@export var level_id: String = ""

## 1-based level number displayed in HUD.
@export var level_index: int = 1

## Optional human-readable name shown in HUD.
@export var level_name: String = ""

# ---------------------------------------------------------------------------
# Grid dimensions
# ---------------------------------------------------------------------------

## Number of columns in the grid.
@export var grid_cols: int = 10

## Number of rows in the grid.
@export var grid_rows: int = 8

# ---------------------------------------------------------------------------
# Terrain map
# ---------------------------------------------------------------------------

## Flat row-major terrain map. Length must equal grid_cols * grid_rows.
## Values are TerrainSystem.TileType int values.
## Index formula: row * grid_cols + col
@export var terrain_map: PackedInt32Array = PackedInt32Array()

# ---------------------------------------------------------------------------
# Entity positions
# ---------------------------------------------------------------------------

## Player starting cell.
@export var player_spawn: Vector2i = Vector2i(1, 1)

## Enemy starting cells (one per enemy).
@export var enemy_spawns: Array[Vector2i] = []

## Rescue (rescate) positions for each enemy after death.
## Index must match enemy_spawns. Length must equal enemy_spawns.size().
@export var enemy_rescate_positions: Array[Vector2i] = []

## Treasure pickup cell positions.
@export var pickup_cells: Array[Vector2i] = []

## Exit cell — unlocked when all pickups are collected.
@export var exit_cell: Vector2i = Vector2i(8, 1)
