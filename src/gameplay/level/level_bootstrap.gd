## LevelBootstrap — Wires all 6 Sprint 1-2 systems for the INT-01 smoke test.
##
## Initialization order (enforced by _ready):
##   1. TerrainSystem.setup(grid, terrain_config)
##      — TerrainSystem.initialize() will call grid.initialize() internally;
##        no standalone grid.initialize() required.
##   2. GridGravity.setup(grid, terrain, gravity_config)
##      — Connects grid.cell_changed and injects cell_occupied into terrain.
##   3. InputSystem.config = input_config_res
##      — InputSystem has no setup(); config is a plain @export property.
##   4. PlayerMovement.setup(grid, terrain, gravity, input, input_config, fall_speed)
##      — Internally connects input.move_requested and gravity signals.
##        Do NOT reconnect move_requested externally.
##   5. DigSystem.setup(terrain, gravity, player, terrain_config, player_id)
##   6. PickupSystem.setup(grid, player)
##      — Internally connects player.player_moved.
##   7. Connect input.dig_requested → dig._on_dig_requested
##   8. Connect player/dig/pickup signals → local feedback callbacks
##   9. _initialize_level() — builds flat terrain array, calls terrain.initialize(),
##        spawns player (which registers with gravity), initialises pickups.
##
## Implements: production/sprints/sprint-02.md#INT-01
class_name LevelBootstrap
extends Node

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

# ---------------------------------------------------------------------------
# Exports — config resources (optional; fall back to defaults when null)
# ---------------------------------------------------------------------------

@export var terrain_config_res: TerrainConfig
@export var gravity_config_res: GravityConfig
@export var input_config_res: InputConfig

# ---------------------------------------------------------------------------
# Exports — level parameters
# ---------------------------------------------------------------------------

@export var grid_rows: int = 8
@export var grid_cols: int = 10
@export var player_start: Vector2i = Vector2i(1, 1)
@export var pickup_positions: Array[Vector2i] = [
	Vector2i(3, 1), Vector2i(6, 1), Vector2i(8, 3)
]
@export var exit_position: Vector2i = Vector2i(9, 1)

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# -----------------------------------------------------------------------
	# Resolve configs — create defaults so setup() never receives null.
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
	# Step 1 — TerrainSystem
	# setup() takes (GridSystem, TerrainConfig); config is NOT a public property.
	# -----------------------------------------------------------------------
	terrain.setup(grid, t_config)

	# -----------------------------------------------------------------------
	# Step 2 — GridGravity
	# setup(grid, terrain, config) — grid first, terrain second.
	# Internally connects grid.cell_changed and injects cell_occupied check.
	# -----------------------------------------------------------------------
	gravity.setup(grid, terrain, g_config)

	# -----------------------------------------------------------------------
	# Step 3 — InputSystem config
	# InputSystem has no setup() method; @export var config is the only hook.
	# InputSystem._ready() already ran (children before parents), so we
	# override here if an explicit resource was supplied.
	# -----------------------------------------------------------------------
	if input_config_res != null:
		input.config = input_config_res

	# -----------------------------------------------------------------------
	# Step 4 — PlayerMovement
	# setup() takes (grid, terrain, gravity, input, input_config, fall_speed).
	# It internally connects input.move_requested — do NOT reconnect externally.
	# Pass g_config.fall_speed so gravity feel matches the GravityConfig resource.
	# -----------------------------------------------------------------------
	player.setup(grid, terrain, gravity, input, input.config, g_config.fall_speed)

	# -----------------------------------------------------------------------
	# Step 5 — DigSystem
	# setup(terrain, gravity, player, terrain_config, player_id)
	# Shares the same t_config instance as TerrainSystem for consistent timing.
	# -----------------------------------------------------------------------
	dig.setup(terrain, gravity, player, t_config, player.entity_id)

	# -----------------------------------------------------------------------
	# Step 6 — PickupSystem
	# setup(grid, player) — internally connects player.player_moved.
	# -----------------------------------------------------------------------
	pickups.setup(grid, player)

	# -----------------------------------------------------------------------
	# Step 7 — Dig input connection
	# InputSystem.dig_requested is a one-shot per key-down; DigSystem exposes
	# _on_dig_requested(direction: Vector2i) as its handler.
	# -----------------------------------------------------------------------
	input.dig_requested.connect(dig._on_dig_requested)

	# -----------------------------------------------------------------------
	# Step 8 — Console feedback signals
	# -----------------------------------------------------------------------
	player.player_moved.connect(_on_player_moved)
	dig.dig_started.connect(_on_dig_started)
	pickups.pickup_collected.connect(_on_pickup_collected)
	pickups.all_pickups_collected.connect(_on_all_collected)
	pickups.player_reached_exit.connect(_on_player_won)

	# -----------------------------------------------------------------------
	# Step 9 — Build terrain, spawn player, register pickups
	# -----------------------------------------------------------------------
	_initialize_level()

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Build and load the level layout, then spawn the player and register pickups.
##
## Grid layout (10 cols × 8 rows; row 0 = top, row 7 = bottom):
##   Row 7 : SOLID floor across all columns
##   Row 6 : alternating DIRT_SLOW (even cols) / EMPTY (odd cols) — diggable platforms
##   Row 5 : EMPTY except SOLID platform at cols 7–9
##   Row 4 : SOLID platform at cols 0–3
##   Row 3–6: LADDER at col 4 (vertical climb shaft)
##   Row 2 : ROPE at cols 5–8 (horizontal traverse)
##   Rows 0–1: EMPTY (player spawn area)
func _initialize_level() -> void:
	# Build a flat row-major Array[int]. Index = row * grid_cols + col.
	var cell_data: Array[int] = []
	cell_data.resize(grid_cols * grid_rows)
	cell_data.fill(TerrainSystem.TileType.EMPTY)

	# Row 7 — solid floor
	for c: int in range(grid_cols):
		cell_data[7 * grid_cols + c] = TerrainSystem.TileType.SOLID

	# Row 6 — alternating DIRT_SLOW / EMPTY platforms
	for c: int in range(grid_cols):
		if c % 2 == 0:
			cell_data[6 * grid_cols + c] = TerrainSystem.TileType.DIRT_SLOW

	# Row 5 — SOLID platform cols 7–9
	for c: int in range(7, grid_cols):
		cell_data[5 * grid_cols + c] = TerrainSystem.TileType.SOLID

	# Row 4 — SOLID platform cols 0–3
	for c: int in range(4):
		cell_data[4 * grid_cols + c] = TerrainSystem.TileType.SOLID

	# Rows 3–6 — LADDER at col 4 (vertical climb shaft)
	for r: int in range(3, 7):
		cell_data[r * grid_cols + 4] = TerrainSystem.TileType.LADDER

	# Row 2 — ROPE at cols 5–8
	for c: int in range(5, 9):
		cell_data[2 * grid_cols + c] = TerrainSystem.TileType.ROPE

	# Rows 0–1 remain EMPTY (player spawn area — no writes needed).

	# Initialize TerrainSystem with the flat cell data.
	# TerrainSystem.initialize() also calls GridSystem.initialize() internally.
	terrain.initialize(cell_data, grid_cols, grid_rows)

	# Spawn player — PlayerMovement.spawn() places the node, registers with
	# GridGravity, and transitions to IDLE state. No separate register_entity call needed.
	player.spawn(player_start)

	# Register pickups and exit cell with PickupSystem.
	pickups.initialize(pickup_positions, exit_position)

	print("[INT] Level initialized: %d×%d grid, %d pickups, exit at %s" % [
		grid_cols, grid_rows, pickup_positions.size(), exit_position
	])

# ---------------------------------------------------------------------------
# Signal callbacks — console feedback
# ---------------------------------------------------------------------------

func _on_player_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	print("[INT] Player moved %s → %s" % [from_cell, to_cell])


## dig_started(col: int, row: int) — matches DigSystem signal signature.
func _on_dig_started(col: int, row: int) -> void:
	print("[INT] Dig started at (%d, %d)" % [col, row])


## pickup_collected(col: int, row: int, remaining: int) — matches PickupSystem signal.
func _on_pickup_collected(col: int, row: int, remaining: int) -> void:
	print("[INT] Pickup at (%d, %d) collected! %d remaining" % [col, row, remaining])


func _on_all_collected() -> void:
	print("[INT] All pickups collected! Exit is now open!")


func _on_player_won() -> void:
	print("[INT] Player reached exit — LEVEL COMPLETE!")
