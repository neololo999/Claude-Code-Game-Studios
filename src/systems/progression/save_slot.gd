## SaveSlot — in-memory session state for Dig & Dash progression.
##
## Holds which worlds are unlocked, star counts per level, and the current
## world/level cursor. In Alpha this is RAM-only. Full Vision wraps this
## class with FileAccess serialisation without changing its fields or
## ProgressionSystem's API.
##
## Implements: design/gdd/progression.md
class_name SaveSlot
extends RefCounted

# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## world_ids the player may enter.
var unlocked_worlds: Array[String] = []

## level_id → int (1–3). Absent key means level not yet completed.
var level_stars: Dictionary = {}

## World the player is currently in (set by ProgressionSystem.start_level).
var current_world_id: String = ""

## Level the player is currently in (read by LevelSystem in Sprint 10).
var current_level_id: String = ""
