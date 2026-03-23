## LevelSystem — 7-state orchestrator for Dig & Dash levels.
##
## Drives the full level lifecycle: loading, running, death/restart,
## victory, and transition to the next level.
##
## Initialization order (GDD Rule 2 — enforced by _initialize_level):
##   1. TerrainSystem.setup()  — first-time only (guarded by _is_initialized)
##   2. GridGravity.setup()    — first-time only
##   3. InputSystem.config     — first-time only
##   4. PlayerMovement.setup() — first-time only
##   5. PickupSystem.setup()   — first-time only
##   6. TerrainSystem.initialize() — every level (also calls grid.initialize() internally)
##   7. PlayerMovement.spawn()     — every level
##   8. EnemyController nodes      — spawned dynamically every level
##   9. PickupSystem.initialize()  — every level
##  10. Signal connections         — guarded by is_connected()
##
## Note: TerrainSystem.initialize() calls GridSystem.initialize() internally.
##       Do NOT call grid.initialize() separately (LevelBootstrap confirms this).
##
## Implements: production/sprints/sprint-03.md#LVL-02
class_name LevelSystem
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Seconds to freeze the level after the player dies before restarting.
const DEATH_FREEZE_TIME: float = 0.5

## Seconds to hold the victory state before advancing to the next level.
const VICTORY_HOLD_TIME: float = 1.5

## Directory containing .tres level resource files.
const LEVELS_DIR: String = "res://resources/levels/"

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## 7-state lifecycle machine.
enum State {
	IDLE,          ## Before any level is loaded.
	LOADING,       ## ResourceLoader.load() in progress.
	RUNNING,       ## Level active — accepting input and simulation.
	DYING,         ## Player died; freeze timer counting down.
	RESTARTING,    ## Systems being reset; about to re-enter RUNNING.
	VICTORY,       ## All pickups collected and exit reached; hold timer counting down.
	TRANSITIONING, ## Loading the next level resource.
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the player dies (before the freeze timer starts).
signal player_died

## Emitted when a level enters RUNNING state for the first time.
signal level_started(level_index: int)

## Emitted when the player reaches the open exit.
signal level_victory

## Emitted after a restart completes and the level re-enters RUNNING.
signal level_restarted

# ---------------------------------------------------------------------------
# @export variables — injected from the scene
# ---------------------------------------------------------------------------

@export var grid: GridSystem
@export var terrain: TerrainSystem
@export var gravity: GridGravity
@export var player: PlayerMovement
@export var pickups: PickupSystem
@export var input_node: InputSystem
@export var terrain_config: TerrainConfig
@export var gravity_config: GravityConfig
@export var input_config: InputConfig
@export var enemy_config: EnemyConfig

# ---------------------------------------------------------------------------
# Public read-only state
# ---------------------------------------------------------------------------

## 1-based index of the currently loaded level.
var current_level_index: int = 0

## Total number of deaths since the current level was loaded.
var death_count: int = 0

## Current lifecycle state.
var level_state: State = State.IDLE

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _current_level_data: LevelData = null
var _enemies: Array[EnemyController] = []
var _state_timer: float = 0.0

## True after the first _initialize_level() call; guards one-time setup().
var _is_initialized: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_process(false)


## Handle timed state transitions for DYING and VICTORY.
func _process(delta: float) -> void:
	match level_state:
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_do_restart()
		State.VICTORY:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_do_next_level()

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Load a level by ID, initialise all systems, and enter RUNNING.
##
## level_id must match a .tres file in res://resources/levels/.
## Example: load_level("level_001") loads "res://resources/levels/level_001.tres".
func load_level(level_id: String) -> void:
	level_state = State.LOADING
	set_process(true)

	var path: String = LEVELS_DIR + level_id + ".tres"
	var data: LevelData = ResourceLoader.load(path) as LevelData
	if data == null:
		# Fallback: generate the level in code. Allows play without .tres files.
		data = LevelBuilder.build(level_id)
	if data == null:
		push_error(
			"LevelSystem: could not load or build level '%s' (tried %s)"
			% [level_id, path]
		)
		level_state = State.IDLE
		return

	_current_level_data = data
	current_level_index = data.level_index
	death_count = 0

	# Clean up previous level's dynamic state without disturbing signal wiring.
	# Safe on first load — _enemies is empty and _is_initialized is false.
	if _is_initialized:
		for e: EnemyController in _enemies:
			e.queue_free()
		_enemies.clear()
		gravity.reset()

	_initialize_level(data)

	level_state = State.RUNNING
	level_started.emit(current_level_index)


## Trigger a manual restart (e.g. bound to Key R / ui_cancel).
## Only valid during RUNNING state; ignored otherwise.
func restart() -> void:
	if level_state != State.RUNNING:
		return
	_trigger_death()

# ---------------------------------------------------------------------------
# Private methods — Initialisation
# ---------------------------------------------------------------------------

## Full level initialisation. Called by load_level() and _do_restart().
##
## First call: performs one-time system setup (terrain.setup, gravity.setup,
##   input config assignment, player.setup, pickups.setup).
## Subsequent calls: skips setup and goes straight to initialize/spawn.
##
## TerrainSystem.initialize() calls GridSystem.initialize() internally —
## grid.initialize() must NOT be called separately (see LevelBootstrap).
func _initialize_level(data: LevelData) -> void:
	# -----------------------------------------------------------------------
	# One-time system setup — guarded to prevent duplicate signal connections.
	# -----------------------------------------------------------------------
	if not _is_initialized:
		# Step 1 & 2: TerrainSystem must be set up before GridGravity so that
		# cell_occupied_check can be injected during gravity.setup().
		terrain.setup(grid, terrain_config)
		gravity.setup(grid, terrain, gravity_config)

		# Step 3: InputSystem has no setup(); assign config directly.
		if input_config != null:
			input_node.config = input_config

		# Step 4: PlayerMovement — connects input.move_requested and gravity
		# signals internally. Pass the resolved fall_speed from GravityConfig.
		var fall_speed: float = gravity_config.fall_speed if gravity_config != null else 0.1
		player.setup(grid, terrain, gravity, input_node, input_node.config, fall_speed)

		# Step 5: PickupSystem — connects player.player_moved internally.
		pickups.setup(grid, player)

		_is_initialized = true

	# -----------------------------------------------------------------------
	# Step 6: TerrainSystem.initialize() — populates cell data and calls
	# grid.initialize() with the same data; also sanitises unknown tile IDs.
	# Convert PackedInt32Array → Array[int] (TerrainSystem.initialize requires
	# a typed Array[int], not a PackedInt32Array).
	# -----------------------------------------------------------------------
	var cell_data: Array[int] = []
	cell_data.assign(data.terrain_map)
	terrain.initialize(cell_data, data.grid_cols, data.grid_rows)

	# -----------------------------------------------------------------------
	# Step 7: Player — spawn() places the node, registers with GridGravity,
	# and transitions to IDLE.
	# -----------------------------------------------------------------------
	player.spawn(data.player_spawn)

	# -----------------------------------------------------------------------
	# Step 8: Enemies — created and spawned dynamically.
	# -----------------------------------------------------------------------
	_spawn_enemies(data)

	# -----------------------------------------------------------------------
	# Step 9: PickupSystem — register pickup positions and exit cell.
	# initialize() clears any previous state before populating.
	# -----------------------------------------------------------------------
	pickups.initialize(data.pickup_cells, data.exit_cell)

	# -----------------------------------------------------------------------
	# Step 10: Connect level-end signals (guarded by is_connected).
	# -----------------------------------------------------------------------
	_connect_level_signals()


## Dynamically create one EnemyController child node per enemy_spawn entry.
## Frees any previously tracked enemies first (safe — _enemies is cleared by
## load_level() and _do_restart() before this is called).
func _spawn_enemies(data: LevelData) -> void:
	for i: int in data.enemy_spawns.size():
		var enemy: EnemyController = EnemyController.new()
		# Pre-assign config so _ready() (called by add_child) sees a valid resource.
		enemy.config = enemy_config if enemy_config != null else EnemyConfig.new()
		add_child(enemy)
		# setup() connects gravity and player signals; must be called after add_child.
		enemy.setup(grid, terrain, gravity, player, enemy.config, i + 1)
		# Rescate position: use provided cell or fall back to top of spawn column.
		var rescate: Vector2i
		if i < data.enemy_rescate_positions.size():
			rescate = data.enemy_rescate_positions[i]
		else:
			rescate = Vector2i(data.enemy_spawns[i].x, 0)
		enemy.spawn(data.enemy_spawns[i], rescate)
		_enemies.append(enemy)


## Wire level-end signals from PickupSystem and all active EnemyControllers.
## Guards with is_connected() so this is safe to call on restart (pickups is
## the same instance across restarts; fresh enemy instances never have a prior
## connection).
func _connect_level_signals() -> void:
	if not pickups.player_reached_exit.is_connected(_on_player_reached_exit):
		pickups.player_reached_exit.connect(_on_player_reached_exit)

	for e: EnemyController in _enemies:
		if not e.enemy_reached_player.is_connected(_on_enemy_reached_player):
			e.enemy_reached_player.connect(_on_enemy_reached_player)

# ---------------------------------------------------------------------------
# Private methods — State transitions
# ---------------------------------------------------------------------------

## Initiate the death sequence: freeze, increment death count, notify player.
## EC-03: re-entrant calls are ignored — only one death triggers at a time.
func _trigger_death() -> void:
	if level_state == State.DYING or level_state == State.RESTARTING:
		return
	level_state = State.DYING
	_state_timer = DEATH_FREEZE_TIME
	death_count += 1
	player_died.emit()
	# Transition PlayerMovement to DEAD: unregisters from GridGravity and
	# suppresses further input. Confirmed: PlayerMovement.die() exists.
	player.die()


## Reset all systems and re-initialise the current level.
## Called when the DYING timer expires.
func _do_restart() -> void:
	level_state = State.RESTARTING

	# Tear down dynamic enemy nodes.
	for e: EnemyController in _enemies:
		e.queue_free()
	_enemies.clear()

	# Reset systems in reverse dependency order.
	# pickups.reset() restores pickup registry (initialize() will reinstate too,
	# but spec requires explicit reset here).
	pickups.reset()
	# gravity.reset() clears entity registry so player.spawn() starts clean.
	gravity.reset()
	# terrain.reset() restores any dug holes before terrain.initialize() overwrites.
	terrain.reset()

	# Re-initialise with the same level data.
	_initialize_level(_current_level_data)

	level_state = State.RUNNING
	level_restarted.emit()


## Advance to the next level alphabetically in LEVELS_DIR.
## Called when the VICTORY timer expires.
func _do_next_level() -> void:
	level_state = State.TRANSITIONING
	var next_id: String = _get_next_level_id()
	if next_id.is_empty():
		# EC-01: last level — show end-game screen (stub).
		level_state = State.IDLE
		print("[LevelSystem] All levels complete! YOU WIN!")
		return
	load_level(next_id)


## Scan LEVELS_DIR alphabetically and return the level_id that follows the
## current one. Falls back to LevelBuilder.LEVEL_IDS when no .tres files are
## present so code-generated levels advance correctly without any .tres files.
## Returns "" if the current level is the last or the dir is inaccessible.
func _get_next_level_id() -> String:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(LEVELS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				files.append(fname.get_basename())
			fname = dir.get_next()
		dir.list_dir_end()
		files.sort()

	# When no .tres files exist, use the builder's ordered level list.
	if files.is_empty():
		files.assign(LevelBuilder.LEVEL_IDS)

	var idx: int = files.find(_current_level_data.level_id)
	if idx < 0 or idx + 1 >= files.size():
		return ""
	return files[idx + 1]

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

## Connected to each EnemyController.enemy_reached_player.
## EC-02 / EC-03: only process during RUNNING to prevent double-death.
func _on_enemy_reached_player(_enemy_id: int, _cell: Vector2i) -> void:
	if level_state != State.RUNNING:
		return
	_trigger_death()


## Connected to PickupSystem.player_reached_exit.
## EC-06: ignore if already dying (level_state != RUNNING).
func _on_player_reached_exit() -> void:
	if level_state != State.RUNNING:
		return
	level_state = State.VICTORY
	_state_timer = VICTORY_HOLD_TIME
	level_victory.emit()

# ---------------------------------------------------------------------------
# Input — manual restart
# ---------------------------------------------------------------------------

## Key R or ui_cancel triggers a manual restart during RUNNING.
func _unhandled_input(event: InputEvent) -> void:
	if level_state != State.RUNNING:
		return
	var is_restart: bool = event.is_action_pressed(&"ui_cancel")
	if not is_restart and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		is_restart = key_event.keycode == KEY_R and key_event.pressed and not key_event.echo
	if is_restart:
		restart()
