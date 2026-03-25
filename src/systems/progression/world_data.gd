## WorldData — static configuration for a single world in Dig & Dash.
##
## Stores the world's identity, display name, ordered level list, and unlock
## condition. Instances are created in code by ProgressionSystem._init_worlds();
## no .tres files are needed for the Alpha (only 3 worlds).
##
## Implements: design/gdd/progression.md
class_name WorldData
extends Resource

# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## Canonical identifier: "world_01", "world_02", "world_03".
@export var world_id: String = ""

## Human-readable title shown in UI: "World 1 – The Mines".
@export var world_name: String = ""

## Ordered list of level IDs belonging to this world.
## Example: ["level_001", "level_002", … "level_010"]
@export var level_ids: Array[String] = []

## Unlock condition:
##   ""                  — always unlocked (World 1).
##   "complete_previous" — requires the previous world to be completed.
@export var unlock_condition: String = "complete_previous"

# ---------------------------------------------------------------------------
# Factory helper
# ---------------------------------------------------------------------------

## Create a WorldData instance in code without needing the Godot editor.
static func create(
		p_world_id: String,
		p_world_name: String,
		p_level_ids: Array[String],
		p_unlock_condition: String = "complete_previous") -> WorldData:
	var d: WorldData = WorldData.new()
	d.world_id = p_world_id
	d.world_name = p_world_name
	d.level_ids = p_level_ids
	d.unlock_condition = p_unlock_condition
	return d
