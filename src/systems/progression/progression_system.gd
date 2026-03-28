## ProgressionSystem — tracks world unlock state and per-level stars.
##
## Registered as an autoload singleton ("/root/ProgressionSystem") so it
## persists across scene changes (MainMenu ↔ Level). All call sites access
## it via get_node_or_null("/root/ProgressionSystem") so the game degrades
## gracefully when the autoload is not registered.
##
## Sprint 9: data model only — does not drive LevelSystem yet.
## Sprint 10: wired to MainMenu (start_level) and LevelSystem
##   (_on_level_completed after StarsSystem.display_complete).
## Sprint 11: dual-mode support (Puzzle + Arcade).
##
## Implements: design/gdd/progression.md
## Note: No class_name declared — registering a class_name that matches an
## autoload singleton name causes a parse error in Godot 4. Access the
## singleton via `get_node_or_null("/root/ProgressionSystem")` or directly
## through the autoload global `ProgressionSystem`.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when all levels in a world have been completed (stars ≥ 1).
signal world_completed(world_id: String)

## Emitted when a previously locked world becomes available.
signal world_unlocked(world_id: String)

## Emitted when the active game mode changes.
signal mode_changed(new_mode: String)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Active mode: "puzzle" or "arcade".
var _current_mode: String = "puzzle"

## Ordered list of all puzzle worlds. Index order matters for "complete_previous" unlock.
var _worlds: Array[WorldData] = []

## Single session slot for puzzle mode. Full Vision: load from disk into this field.
var _save_slot: SaveSlot = null

## Ordered list of all arcade worlds.
var _arcade_worlds: Array[WorldData] = []

## Session slot for arcade mode.
var _arcade_save_slot: SaveSlot = null

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_init_worlds()
	_save_slot = SaveSlot.new()
	_save_slot.unlocked_worlds = ["world_01"]
	_save_slot.current_world_id = "world_01"
	_save_slot.current_level_id = ""

	_init_arcade_worlds()
	_arcade_save_slot = SaveSlot.new()
	_arcade_save_slot.unlocked_worlds = ["arcade_world_01"]
	_arcade_save_slot.current_world_id = "arcade_world_01"
	_arcade_save_slot.current_level_id = ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set the active game mode ("puzzle" or "arcade"). Emits mode_changed.
func set_mode(mode: String) -> void:
	_current_mode = mode
	mode_changed.emit(mode)


## Returns the currently active game mode ("puzzle" or "arcade").
func get_current_mode() -> String:
	return _current_mode


## Returns the current world id from the active save slot.
## Replaces direct _save_slot field access from call sites.
func get_current_world_id() -> String:
	return _get_active_save_slot().current_world_id


## Record that the player is about to enter world_id / level_id.
## Called by MainMenu immediately before change_scene_to_file().
func start_level(world_id: String, level_id: String) -> void:
	var slot: SaveSlot = _get_active_save_slot()
	slot.current_world_id = world_id
	slot.current_level_id = level_id


## Record that level_id was completed with the given star count.
## Updates the session best (max rule) and checks world completion.
## Called in Sprint 10 by LevelSystem wiring after StarsSystem.display_complete.
func on_level_completed(level_id: String, stars: int) -> void:
	if stars < 1 or stars > 3:
		push_warning("ProgressionSystem.on_level_completed: invalid stars value %d for %s" % [stars, level_id])
		return

	# Max-rule star update.
	var slot: SaveSlot = _get_active_save_slot()
	var previous: int = slot.level_stars.get(level_id, 0)
	if stars > previous:
		slot.level_stars[level_id] = stars

	# World completion check.
	var world: WorldData = _find_world_for_level(level_id)
	if world == null:
		return

	if _is_world_complete(world):
		world_completed.emit(world.world_id)
		_try_unlock_next_world(world)


## Returns the level_id the player should start on.
## LevelSystem reads this in _ready() (Sprint 10) instead of starting_level_id.
## Returns "" if not yet set — LevelSystem falls back to starting_level_id.
func get_current_level_id() -> String:
	return _get_active_save_slot().current_level_id


## Returns true if world_id is in the unlocked_worlds list of the active slot.
func is_world_unlocked(world_id: String) -> bool:
	return world_id in _get_active_save_slot().unlocked_worlds


## Returns a summary dictionary for a world, used by WorldSelect UI.
## Keys: unlocked (bool), total_stars (int), max_stars (int),
##       level_count (int), level_ids (Array[String]).
func get_world_state(world_id: String) -> Dictionary:
	var world: WorldData = _find_world_by_id(world_id)
	if world == null:
		return {
			"unlocked": false,
			"total_stars": 0,
			"max_stars": 0,
			"level_count": 0,
			"level_ids": [],
		}
	var slot: SaveSlot = _get_active_save_slot()
	var total: int = 0
	for lid: String in world.level_ids:
		total += slot.level_stars.get(lid, 0)
	return {
		"unlocked": is_world_unlocked(world_id),
		"total_stars": total,
		"max_stars": world.level_ids.size() * 3,
		"level_count": world.level_ids.size(),
		"level_ids": world.level_ids,
	}


## Returns the ordered list of all WorldData instances for the active mode.
## Used by MainMenu to build world cards dynamically.
func get_all_worlds() -> Array[WorldData]:
	return _get_active_worlds()

# ---------------------------------------------------------------------------
# Private helpers — active slot/world accessors
# ---------------------------------------------------------------------------

func _get_active_worlds() -> Array[WorldData]:
	if _current_mode == "arcade":
		return _arcade_worlds
	return _worlds


func _get_active_save_slot() -> SaveSlot:
	if _current_mode == "arcade":
		return _arcade_save_slot
	return _save_slot

# ---------------------------------------------------------------------------
# Private helpers — initialisation
# ---------------------------------------------------------------------------

func _init_worlds() -> void:
	var w1_ids: Array[String] = []
	for i: int in range(1, 11):
		w1_ids.append("level_%03d" % i)

	var w2_ids: Array[String] = []
	for i: int in range(11, 21):
		w2_ids.append("level_%03d" % i)

	var w3_ids: Array[String] = []
	for i: int in range(21, 31):
		w3_ids.append("level_%03d" % i)

	_worlds = [
		WorldData.create("world_01", "World 1 – The Mines", w1_ids, ""),
		WorldData.create("world_02", "World 2 – The Depths", w2_ids, "complete_previous"),
		WorldData.create("world_03", "World 3 – The Summit", w3_ids, "complete_previous"),
	]


func _init_arcade_worlds() -> void:
	var a1_ids: Array[String] = ["arcade_001", "arcade_002", "arcade_003"]
	var a2_ids: Array[String] = ["arcade_004", "arcade_005", "arcade_006"]

	_arcade_worlds = [
		WorldData.create("arcade_world_01", "Arcade – Zone 1", a1_ids, ""),
		WorldData.create("arcade_world_02", "Arcade – Zone 2", a2_ids, "complete_previous"),
	]

# ---------------------------------------------------------------------------
# Private helpers — logic
# ---------------------------------------------------------------------------

func _find_world_by_id(world_id: String) -> WorldData:
	for world: WorldData in _get_active_worlds():
		if world.world_id == world_id:
			return world
	return null


func _find_world_for_level(level_id: String) -> WorldData:
	for world: WorldData in _get_active_worlds():
		if level_id in world.level_ids:
			return world
	return null


func _is_world_complete(world: WorldData) -> bool:
	var slot: SaveSlot = _get_active_save_slot()
	for lid: String in world.level_ids:
		if slot.level_stars.get(lid, 0) < 1:
			return false
	return true


func _try_unlock_next_world(completed_world: WorldData) -> void:
	var active_worlds: Array[WorldData] = _get_active_worlds()
	var idx: int = active_worlds.find(completed_world)
	if idx < 0 or idx + 1 >= active_worlds.size():
		return
	var next_world: WorldData = active_worlds[idx + 1]
	var slot: SaveSlot = _get_active_save_slot()
	if next_world.world_id in slot.unlocked_worlds:
		return
	slot.unlocked_worlds.append(next_world.world_id)
	world_unlocked.emit(next_world.world_id)
