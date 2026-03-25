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
##
## Implements: design/gdd/progression.md
class_name ProgressionSystem
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when all levels in a world have been completed (stars ≥ 1).
signal world_completed(world_id: String)

## Emitted when a previously locked world becomes available.
signal world_unlocked(world_id: String)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Ordered list of all worlds. Index order matters for "complete_previous" unlock.
var _worlds: Array[WorldData] = []

## Single session slot. Full Vision: load from disk into this field.
var _save_slot: SaveSlot = null

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_init_worlds()
	_save_slot = SaveSlot.new()
	_save_slot.unlocked_worlds = ["world_01"]
	_save_slot.current_world_id = "world_01"
	_save_slot.current_level_id = ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Record that the player is about to enter world_id / level_id.
## Called by MainMenu immediately before change_scene_to_file().
func start_level(world_id: String, level_id: String) -> void:
	_save_slot.current_world_id = world_id
	_save_slot.current_level_id = level_id


## Record that level_id was completed with the given star count.
## Updates the session best (max rule) and checks world completion.
## Called in Sprint 10 by LevelSystem wiring after StarsSystem.display_complete.
func on_level_completed(level_id: String, stars: int) -> void:
	if stars < 1 or stars > 3:
		push_warning("ProgressionSystem.on_level_completed: invalid stars value %d for %s" % [stars, level_id])
		return

	# Max-rule star update.
	var previous: int = _save_slot.level_stars.get(level_id, 0)
	if stars > previous:
		_save_slot.level_stars[level_id] = stars

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
	return _save_slot.current_level_id


## Returns true if world_id is in the unlocked_worlds list.
func is_world_unlocked(world_id: String) -> bool:
	return world_id in _save_slot.unlocked_worlds


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
	var total: int = 0
	for lid: String in world.level_ids:
		total += _save_slot.level_stars.get(lid, 0)
	return {
		"unlocked": is_world_unlocked(world_id),
		"total_stars": total,
		"max_stars": world.level_ids.size() * 3,
		"level_count": world.level_ids.size(),
		"level_ids": world.level_ids,
	}


## Returns the ordered list of all WorldData instances.
## Used by MainMenu to build world cards dynamically.
func get_all_worlds() -> Array[WorldData]:
	return _worlds

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

# ---------------------------------------------------------------------------
# Private helpers — logic
# ---------------------------------------------------------------------------

func _find_world_by_id(world_id: String) -> WorldData:
	for world: WorldData in _worlds:
		if world.world_id == world_id:
			return world
	return null


func _find_world_for_level(level_id: String) -> WorldData:
	for world: WorldData in _worlds:
		if level_id in world.level_ids:
			return world
	return null


func _is_world_complete(world: WorldData) -> bool:
	for lid: String in world.level_ids:
		if _save_slot.level_stars.get(lid, 0) < 1:
			return false
	return true


func _try_unlock_next_world(completed_world: WorldData) -> void:
	var idx: int = _worlds.find(completed_world)
	if idx < 0 or idx + 1 >= _worlds.size():
		return
	var next_world: WorldData = _worlds[idx + 1]
	if next_world.world_id in _save_slot.unlocked_worlds:
		return
	_save_slot.unlocked_worlds.append(next_world.world_id)
	world_unlocked.emit(next_world.world_id)
