# GDD: Progression / Worlds System

> **Status**: Approved
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-25
> **Milestone**: Alpha (Sprint 9 — data model; Sprint 10 — wiring)
> **Implements**: `src/systems/progression/progression_system.gd`
> **Dependencies**: LevelSystem, StarsSystem

---

## Overview

The Progression System tracks which worlds are unlocked, which levels have been
completed, and the player's best star count per level. It is the single source
of truth for session state during Alpha. In Full Vision, a save system wraps
the same data model and persists it to disk — ProgressionSystem's API is
designed so that the save layer can be added without any API changes.

**Design philosophy**: ProgressionSystem is the *data spine* of the Alpha. It
tracks progress but never drives gameplay directly — it exposes read / write
methods that MainMenu and LevelSystem call. It never calls into LevelSystem or
UI code. Coupling flows one way: consumers call ProgressionSystem, not vice
versa.

---

## Player Fantasy

The player completes World 1, sees "World 2 Unlocked!" on the World Complete
Screen, and returns to the main menu to find World 2 is now available. Their
star count from World 1 is remembered throughout the session. Replaying a level
earns more stars if they beat their previous time.

---

## Detailed Rules

### World Data Model

`WorldData` is a `Resource` subclass storing static world configuration:

| Field | Type | Description |
|-------|------|-------------|
| `world_id` | `String` | Canonical identifier: `"world_01"`, `"world_02"`, `"world_03"` |
| `world_name` | `String` | Display name: `"World 1 – The Mines"` |
| `level_ids` | `Array[String]` | Ordered list of level IDs belonging to this world |
| `unlock_condition` | `String` | `""` for always-unlocked worlds; `"complete_previous"` for locked worlds |

WorldData instances are created in code by ProgressionSystem. They are NOT
loaded from .tres files in Alpha (no tooling needed for only 3 instances).
Full Vision may migrate to editor-authored WorldData resources if more worlds
are added.

### Session State Model (SaveSlot)

`SaveSlot` is a `RefCounted` class (not a Resource) that holds runtime session
state. It is the serialization boundary: Full Vision adds FileAccess I/O
around SaveSlot without changing its fields or ProgressionSystem's API.

| Field | Type | Description |
|-------|------|-------------|
| `unlocked_worlds` | `Array[String]` | world_ids the player may enter |
| `level_stars` | `Dictionary` | `level_id → int (1–3)`; absent = not yet completed |
| `current_world_id` | `String` | World the player is currently in |
| `current_level_id` | `String` | Level the player is currently in |

### ProgressionSystem Node Placement

**Decision: autoload singleton.**

Rationale: ProgressionSystem must survive scene changes (MainMenu → Level →
MainMenu). If it were a scene-level node it would be destroyed and re-created
on every `change_scene_to_file()`, losing session state. As an autoload it
persists for the application lifetime and is accessible from any scene without
explicit wiring.

Autoload name: `ProgressionSystem` (accessible as `/root/ProgressionSystem`).
LevelSystem accesses it via `get_node_or_null("/root/ProgressionSystem")` so
the game runs correctly without the autoload registered (backwards-compatible
with level_01.tscn launched directly in the editor).

### World Initialization (Alpha)

ProgressionSystem initialises three worlds on startup:

| World | world_id | level_ids | unlock_condition |
|-------|----------|-----------|-----------------|
| World 1 – The Mines | `world_01` | `level_001` … `level_010` | `""` (always unlocked) |
| World 2 – The Depths | `world_02` | `level_011` … `level_020` | `"complete_previous"` |
| World 3 – The Summit | `world_03` | `level_021` … `level_030` | `"complete_previous"` |

Initial SaveSlot: `unlocked_worlds = ["world_01"]`, all other fields empty.

### World Unlock Logic

When `on_level_completed(level_id, stars)` is called:
1. Update `_save_slot.level_stars[level_id]` if `stars` is higher than existing.
2. Find which world `level_id` belongs to.
3. Check if all levels in that world have a star count > 0 in `level_stars`.
4. If yes: emit `world_completed(world_id)`.
5. Find the next world (index + 1 in `_worlds` array).
6. If next world exists and is not already in `unlocked_worlds`: add it and emit `world_unlocked(next_world_id)`.

### Public API

| Method | Signature | Description |
|--------|-----------|-------------|
| `start_level` | `(world_id: String, level_id: String) -> void` | Update current_world_id and current_level_id in SaveSlot. Called by MainMenu before changing scene. |
| `on_level_completed` | `(level_id: String, stars: int) -> void` | Record stars, check world completion. Called by LevelSystem-side wiring in Sprint 10. |
| `get_current_level_id` | `() -> String` | Returns SaveSlot.current_level_id. LevelSystem reads this in _ready() to know which level to load. |
| `is_world_unlocked` | `(world_id: String) -> bool` | Returns whether world_id is in SaveSlot.unlocked_worlds. |
| `get_world_state` | `(world_id: String) -> Dictionary` | Returns `{unlocked, total_stars, max_stars, level_count, level_ids}`. Used by WorldSelect UI. |
| `get_all_worlds` | `() -> Array[WorldData]` | Returns the ordered list of all WorldData resources. Used by WorldSelect to build world cards. |

### Signals

| Signal | Arguments | Emitted When |
|--------|-----------|--------------|
| `world_completed` | `world_id: String` | All levels in a world have been completed (stars ≥ 1) |
| `world_unlocked` | `world_id: String` | A previously locked world becomes available |

### Full Vision Stub Contract

The Full Vision save system only needs to:
1. After ProgressionSystem._ready(): load a SaveSlot from disk and call `_save_slot = loaded_slot`.
2. After `on_level_completed()`: serialize `_save_slot` to disk.

No other changes to ProgressionSystem's API, signals, or business logic are
required. The save format is the SaveSlot field list above.

---

## Formulas

### World Completion Check

```
world_is_complete(world_id) =
  ALL level_ids in world have level_stars[level_id] >= 1

world_completion_stars(world_id) =
  SUM(level_stars.get(level_id, 0) for level_id in world.level_ids)

world_max_stars(world_id) =
  len(world.level_ids) × 3
```

Example:
- World 1 has 10 levels, player completed 8 with 3★ and 2 with 2★:
  `total = 8×3 + 2×2 = 28 / 30`

### Level Star Update

```
new_stars = max(existing_stars, incoming_stars)
```

Replaying a level never reduces a star count. Range: [0, 3].

---

## Edge Cases

| ID | Scenario | Behaviour |
|----|----------|-----------|
| EC-P01 | `on_level_completed` called for unknown level_id | Stars are stored; world lookup returns null world → no world_completed emitted. No error. |
| EC-P02 | `on_level_completed` called multiple times for same level | New stars stored only if higher than existing (max rule). world_completed not re-emitted once world is already completed. |
| EC-P03 | `is_world_unlocked` called for unknown world_id | Returns false. No error. |
| EC-P04 | `get_world_state` called for unknown world_id | Returns `{unlocked: false, total_stars: 0, max_stars: 0, level_count: 0, level_ids: []}`. |
| EC-P05 | `get_current_level_id` called before `start_level` | Returns `""`. LevelSystem falls back to `starting_level_id` export var. |
| EC-P06 | ProgressionSystem not registered as autoload | All call sites use `get_node_or_null` → null → fall back to existing behaviour. No crash. |
| EC-P07 | Last world (world_03) completed | `world_completed("world_03")` emitted. No next world to unlock. No error. |

---

## Dependencies

| Direction | System | Nature |
|-----------|--------|--------|
| Depends on | none | ProgressionSystem has no runtime deps (receives data via method calls) |
| Depended on by | MainMenu | Calls `start_level()`, reads `get_all_worlds()`, `get_world_state()`, `is_world_unlocked()` |
| Depended on by | LevelSystem (Sprint 10) | Reads `get_current_level_id()` in `_ready()`; calls `on_level_completed()` after display_complete |
| Depended on by | WorldSelect UI | Reads world state for card rendering |

Note: `progression.md` and `transition-screens.md` are independent — neither
depends on the other for Sprint 9. The wiring between them (world_completed →
show_world_complete) happens in Sprint 10.

---

## Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `WORLD_IDS` | `ProgressionSystem._init_worlds()` | `["world_01","world_02","world_03"]` | Add / remove world entries | Controls how many worlds exist |
| Level ID ranges | `ProgressionSystem._init_worlds()` | world_01: 001–010, etc. | Any valid level_id strings | Maps levels to worlds |
| `unlock_condition` | `WorldData.unlock_condition` | `"complete_previous"` for worlds 2–3 | `""` (always open) or `"complete_previous"` | Controls world access gating |

---

## Acceptance Criteria

| ID | Criterion | Testable? |
|----|-----------|-----------|
| AC-P01 | ProgressionSystem initialises with 3 worlds; World 1 is unlocked by default | Yes — call `is_world_unlocked("world_01")` → true; `is_world_unlocked("world_02")` → false |
| AC-P02 | `on_level_completed("level_010", 3)` triggers `world_completed("world_01")` | Yes — complete all of world_01; verify signal emission in the debugger |
| AC-P03 | World 2 is unlocked after World 1 is completed | Yes — complete level_001–010 with ≥1 star each; `is_world_unlocked("world_02")` → true |
| AC-P04 | Level stars are updated correctly (max rule) | Yes — call `on_level_completed("level_001", 1)` then `on_level_completed("level_001", 3)`; `get_world_state("world_01").total_stars` reflects 3 |
| AC-P05 | `get_current_level_id()` returns `""` before `start_level()` | Yes — call before any `start_level()` call |
| AC-P06 | `get_current_level_id()` returns `"level_005"` after `start_level("world_01","level_005")` | Yes |
| AC-P07 | `get_world_state` returns correct level_count and is_unlocked | Yes — verify for all three worlds |
| AC-P08 | No push_error calls | Yes — play through normal flow with Debugger open |
