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

# Explicit preloads so the Godot LSP resolves these types without a full
# project rescan. Does not conflict with the class_name declarations in
# the target files — preload() is purely a local alias for the same script.
# Note: ProgressionSystem is NOT preloaded here because it is registered as
# an autoload singleton; a const with the same name would hide the singleton
# and cause a parse error. Its class_name is resolved globally by the engine.
const TransitionSystem := preload("res://src/systems/transition/transition_system.gd")
const WorldData := preload("res://src/systems/progression/world_data.gd")
## Type alias for ProgressionSystem — avoids autoload-name/class-name conflict.
const _ProgSys := preload("res://src/systems/progression/progression_system.gd")
const LevelSceneParser := preload("res://src/gameplay/level/level_scene_parser.gd")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Seconds to freeze the level after the player dies before restarting.
const DEATH_FREEZE_TIME: float = 0.5

## Seconds to hold the victory state before advancing to the next level.
const VICTORY_HOLD_TIME: float = 1.5

## Directory containing .tres level resource files (legacy pipeline).
const LEVELS_DIR: String = "res://resources/levels/"

## Directory containing .tscn level data scenes (ADR-001 TileMapLayer pipeline).
## Priority: .tscn > .tres > LevelBuilder (code).
const LEVELS_SCENES_DIR: String = "res://resources/levels/"

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## 9-state lifecycle machine.
enum State {
	IDLE,               ## Before any level is loaded.
	LOADING,            ## ResourceLoader.load() in progress.
	RUNNING,            ## Level active — accepting input and simulation.
	DYING,              ## Player died; freeze timer counting down.
	RESTARTING,         ## Systems being reset; about to re-enter RUNNING.
	VICTORY,            ## All pickups collected and exit reached; hold timer (fallback) or immediate transition.
	TRANSITIONING,      ## Loading the next level resource.
	TRANSITION_SCREEN,  ## VictoryScreen displayed; waiting for player confirmation.
	GAME_OVER,          ## GameOverScreen displayed; waiting for Retry or Quit to Menu.
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

## Emitted when all levels are beaten and there is no next level.
signal game_completed

## Emitted when the player quits to the menu (Sprint 10: triggers scene change).
signal return_to_menu

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

## Optional rendering + HUD nodes — wired in scene for Vertical Slice.
## All are null-safe; the game runs correctly without them (MVP mode).
@export var terrain_renderer: TerrainRenderer
@export var entity_renderer: EntityRenderer
@export var camera: CameraController
@export var hud: HUDController

## DigSystem — optional but required for dig mechanics and HUD cooldown display.
@export var dig: DigSystem

## Sprint 7: Audio + VFX nodes — null-safe like rendering nodes.
@export var audio: AudioSystem
@export var vfx: VfxSystem

## Sprint 8: Stars/Scoring — null-safe; game runs correctly without it.
@export var stars: StarsSystem

## Sprint 9: Transition screens — null-safe; game uses timer fallback without it.
@export var transition: TransitionSystem

## Starting level ID when the scene is loaded (default: "level_001").
## Override in the inspector for each level scene.
@export var starting_level_id: String = "level_001"

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
	_resolve_dependencies_from_scene()
	# MAIN-01: if ProgressionSystem autoload has a current level set (by MainMenu
	# calling start_level()), use it. Otherwise fall back to starting_level_id
	# so level_01.tscn launched directly in the editor continues to work.
	var prog: _ProgSys = \
		get_node_or_null("/root/ProgressionSystem") as _ProgSys
	var level_to_load: String = starting_level_id
	if prog != null and not prog.get_current_level_id().is_empty():
		level_to_load = prog.get_current_level_id()
	load_level(level_to_load)


## Handle timed state transitions for DYING and VICTORY.
func _process(delta: float) -> void:
	match level_state:
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				if transition != null:
					level_state = State.GAME_OVER
					transition.show_game_over(death_count)
				else:
					_do_restart()
		State.VICTORY:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_do_next_level()
		State.TRANSITION_SCREEN:
			pass  ## Waiting for TransitionSystem.confirmed signal.
		State.GAME_OVER:
			pass  ## Waiting for TransitionSystem.retry_requested or quit_to_menu_requested.

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Load a level by ID, initialise all systems, and enter RUNNING.
##
## Resolution order (ADR-001):
##   1. TileMapLayer data scene : res://resources/levels/{level_id}.tscn
##   2. Serialised resource     : res://resources/levels/{level_id}.tres (legacy)
##   3. Code-generated level    : LevelBuilder.build(level_id)            (legacy)
func load_level(level_id: String) -> void:
	level_state = State.LOADING
	set_process(true)

	var data: LevelData = null

	# 1. TileMapLayer-first pipeline (ADR-001).
	var scene_path: String = LEVELS_SCENES_DIR + level_id + ".tscn"
	if FileAccess.file_exists(scene_path):
		var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		if packed != null:
			var scene_root: Node = packed.instantiate()
			data = LevelSceneParser.parse(scene_root, level_id)
			scene_root.free()
			# Migration phase: if the scene has no TerrainMap yet, fill terrain
			# from LevelBuilder and keep entity positions from the scene.
			if data != null and data.terrain_map.is_empty():
				var legacy: LevelData = LevelBuilder.build(level_id)
				if legacy != null:
					data.terrain_map = legacy.terrain_map
					data.grid_cols = legacy.grid_cols
					data.grid_rows = legacy.grid_rows
					data.level_name = legacy.level_name

	# 2. Fallback: .tres resource file (legacy).
	if data == null:
		var tres_path: String = LEVELS_DIR + level_id + ".tres"
		if FileAccess.file_exists(tres_path):
			data = ResourceLoader.load(tres_path) as LevelData

	# 3. Fallback: generate in code (LevelBuilder — legacy, tests only).
	if data == null:
		data = LevelBuilder.build(level_id)

	if data == null:
		push_error(
			"LevelSystem: could not load or build level '%s' (tried %s)"
			% [level_id, scene_path]
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

## Resolve required system references from child node names when export links
## are missing in the scene resource.
func _resolve_dependencies_from_scene() -> void:
	if grid == null:
		grid = get_node_or_null("GridSystem") as GridSystem
	if terrain == null:
		terrain = get_node_or_null("TerrainSystem") as TerrainSystem
	if gravity == null:
		gravity = get_node_or_null("GridGravity") as GridGravity
	if player == null:
		player = get_node_or_null("PlayerMovement") as PlayerMovement
	if pickups == null:
		pickups = get_node_or_null("PickupSystem") as PickupSystem
	if input_node == null:
		input_node = get_node_or_null("InputSystem") as InputSystem
	if dig == null:
		dig = get_node_or_null("DigSystem") as DigSystem
	# Also resolve optional nodes
	if hud == null:
		hud = get_node_or_null("HUDLayer") as HUDController
	if camera == null:
		camera = get_node_or_null("CameraController") as CameraController
	if terrain_renderer == null:
		terrain_renderer = get_node_or_null("TerrainRenderer") as TerrainRenderer
	if entity_renderer == null:
		entity_renderer = get_node_or_null("EntityRenderer") as EntityRenderer
	if audio == null:
		audio = get_node_or_null("AudioSystem") as AudioSystem
	if vfx == null:
		vfx = get_node_or_null("VfxSystem") as VfxSystem
	if stars == null:
		stars = get_node_or_null("StarsSystem") as StarsSystem
	if transition == null:
		transition = get_node_or_null("TransitionSystem") as TransitionSystem


## Ensure required dependencies exist before setup() calls.
func _has_required_dependencies() -> bool:
	return (
		grid != null
		and terrain != null
		and gravity != null
		and player != null
		and pickups != null
		and input_node != null
	)

## Full level initialisation. Called by load_level() and _do_restart().
##
## First call: performs one-time system setup (terrain.setup, gravity.setup,
##   input config assignment, player.setup, pickups.setup).
## Subsequent calls: skips setup and goes straight to initialize/spawn.
##
## TerrainSystem.initialize() calls GridSystem.initialize() internally —
## grid.initialize() must NOT be called separately (see LevelBootstrap).
func _initialize_level(data: LevelData) -> void:
	if not _has_required_dependencies():
		push_error("LevelSystem: missing required node references (Grid/Terrain/Gravity/Player/Pickups/InputSystem)")
		level_state = State.IDLE
		return

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

		# Step 5b: DigSystem — optional; wires terrain/gravity/player + input signal.
		if dig != null:
			dig.setup(terrain, gravity, player, terrain_config, player.entity_id)
			if not input_node.dig_requested.is_connected(dig._on_dig_requested):
				input_node.dig_requested.connect(dig._on_dig_requested)

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

	# -----------------------------------------------------------------------
	# Step 11: Rendering + HUD — null-safe, skipped if not wired in scene.
	# -----------------------------------------------------------------------
	if terrain_renderer != null:
		terrain_renderer.setup(grid, terrain)
		terrain_renderer.refresh()
	if entity_renderer != null:
		var enemy_nodes: Array[Node2D] = []
		for e: EnemyController in _enemies:
			enemy_nodes.append(e)
		entity_renderer.setup(player, enemy_nodes)
	if camera != null:
		camera.setup(player, data)
	if hud != null:
		if not _is_initialized or hud.get_meta("_hud_setup_done", false) == false:
			hud.setup(pickups, dig, self)
			hud.set_meta("_hud_setup_done", true)
		hud.initialize(data.pickup_cells.size())
	if audio != null and not audio.get_meta("_audio_setup_done", false):
		audio.setup(dig, pickups, self)
		audio.set_meta("_audio_setup_done", true)
	if vfx != null and not vfx.get_meta("_vfx_setup_done", false):
		vfx.setup(camera, pickups, self, grid)
		vfx.set_meta("_vfx_setup_done", true)
	if stars != null and not stars.get_meta("_stars_setup_done", false):
		stars.setup(self)
		stars.set_meta("_stars_setup_done", true)
	if transition != null and not transition.get_meta("_transition_setup_done", false):
		transition.confirmed.connect(_on_transition_confirmed)
		transition.retry_requested.connect(_on_transition_retry)
		transition.quit_to_menu_requested.connect(_on_transition_quit_to_menu)
		transition.set_meta("_transition_setup_done", true)
	# MAIN-03: wire StarsSystem.display_complete → ProgressionSystem.on_level_completed.
	if stars != null and not stars.get_meta("_progression_wired", false):
		stars.display_complete.connect(_on_stars_display_complete)
		stars.set_meta("_progression_wired", true)


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
	if dig != null:
		dig.reset()
	# gravity.reset() clears entity registry so player.spawn() starts clean.
	gravity.reset()
	# terrain.reset() restores any dug holes before terrain.initialize() overwrites.
	terrain.reset()

	# Re-initialise with the same level data.
	_initialize_level(_current_level_data)

	# Snap camera to player after restart — no interpolation lag.
	if camera != null:
		camera.reset()
	if vfx != null:
		vfx.reset()

	level_state = State.RUNNING
	level_restarted.emit()


## Advance to the next level alphabetically in LEVELS_DIR.
## Called when the VICTORY timer expires or TransitionSystem.confirmed fires.
func _do_next_level() -> void:
	level_state = State.TRANSITIONING
	var next_id: String = _get_next_level_id()
	if next_id.is_empty():
		# EC-01: last level — return to menu (MAIN-02).
		return_to_menu.emit()
		game_completed.emit()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
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
	level_victory.emit()
	if transition != null:
		# Gather star data before entering TRANSITION_SCREEN.
		var star_count: int = 0
		var elapsed: float = 0.0
		if stars != null:
			star_count = stars.get_stars(_current_level_data.level_id)
			elapsed = stars.get_time_elapsed()
		level_state = State.TRANSITION_SCREEN
		transition.show_victory(star_count, elapsed)
	else:
		_state_timer = VICTORY_HOLD_TIME

# ---------------------------------------------------------------------------
# Input — manual restart
# ---------------------------------------------------------------------------

## MAIN-03: called after StarsDisplay auto-dismisses.
## Reports stars to ProgressionSystem. WorldComplete check is handled by
## _connect_to_progression() which listens to prog.world_completed signal.
func _on_stars_display_complete(level_id: String, stars_count: int) -> void:
	var prog: _ProgSys = \
		get_node_or_null("/root/ProgressionSystem") as _ProgSys
	if prog == null:
		return
	_connect_to_progression(prog)
	prog.on_level_completed(level_id, stars_count)


## Wire ProgressionSystem signals the first time we have a valid reference.
## Guards with meta so we connect at most once per scene lifetime.
func _connect_to_progression(prog: _ProgSys) -> void:
	if prog.get_meta("_level_wired", false):
		return
	prog.world_completed.connect(_on_progression_world_completed)
	prog.set_meta("_level_wired", true)


## Show WorldCompleteScreen when ProgressionSystem says a world is done.
func _on_progression_world_completed(world_id: String) -> void:
	if transition == null:
		return
	var prog: _ProgSys = \
		get_node_or_null("/root/ProgressionSystem") as _ProgSys
	if prog == null:
		return
	var world_state: Dictionary = prog.get_world_state(world_id)
	var all_worlds: Array[WorldData] = prog.get_all_worlds()
	var current_idx: int = -1
	for i: int in all_worlds.size():
		if all_worlds[i].world_id == world_id:
			current_idx = i
			break
	var has_next: bool = current_idx >= 0 and current_idx + 1 < all_worlds.size()
	var world_name: String = all_worlds[current_idx].world_name if current_idx >= 0 else world_id
	transition.show_world_complete(
		world_name,
		world_state.get("total_stars", 0),
		world_state.get("max_stars", 0),
		has_next)


## Transition signal callbacks — wired in _initialize_level().
func _on_transition_confirmed() -> void:
	if level_state != State.TRANSITION_SCREEN:
		return
	_do_next_level()


func _on_transition_retry() -> void:
	if level_state != State.GAME_OVER:
		return
	_do_restart()


func _on_transition_quit_to_menu() -> void:
	if level_state != State.GAME_OVER:
		return
	# MAIN-02: change to main menu scene and emit return_to_menu for external listeners.
	return_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


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
