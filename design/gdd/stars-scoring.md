# GDD: Stars / Scoring System

> **Status**: Approved
> **Created**: 2026-03-23
> **Last Updated**: 2026-03-23
> **Milestone**: Vertical Slice (Sprint 8)
> **Implements**: `src/systems/stars/stars_system.gd`, `src/systems/stars/stars_config.gd`
> **Dependencies**: LevelSystem

---

## Overview

The Stars / Scoring system rewards players for completing levels quickly. After
each level victory, a `StarsDisplay` overlay shows 1–3 stars and the elapsed
time before the game advances. Stars are stored in memory for the session; no
persistence is required for the Vertical Slice.

**Design philosophy**: Stars reward mastery without punishing casual play. A
1-star completion is always valid — the player finishes the level. Stars are
shown post-victory, never during play, so they do not add cognitive load to the
core loop.

---

## Timer Model

- Timer **starts** when `LevelSystem.level_started(level_index)` is emitted.
- Timer **stops** when `LevelSystem.level_victory` is emitted.
- Implementation uses `Time.get_ticks_msec()` for millisecond precision.
- Timer resets to 0 on `LevelSystem.level_restarted` (death restarts the clock
  when the level re-enters RUNNING — `level_started` is not re-emitted on
  restart, so `StarsSystem` listens to `level_restarted` to reset the clock).
- Timer is not visible to the player during gameplay. Only the elapsed value
  shown post-victory in `StarsDisplay`.

---

## Star Threshold Spec

| Stars | Condition |
|-------|-----------|
| ⭐⭐⭐ | `elapsed ≤ par_time` |
| ⭐⭐  | `elapsed ≤ par_time × 1.5` |
| ⭐   | `elapsed > par_time × 1.5` (any completion) |

- `par_time` is looked up from `StarsConfig.PAR_TIMES` by `level_id` (String key).
- If a level_id is not in `PAR_TIMES`, par_time defaults to 60.0 seconds.
- Stars are computed at the moment `level_victory` is emitted. The result is
  immutable for that run; no post-hoc adjustment.

### Par Time Calibration

Par times in `StarsConfig` are **placeholder values (60 s/level)** at VS ship.
The correct par time for each level is 1.2× the designer's clean-solve time,
measured during the VS integration pass (VS-INT-01).

> **Calibration procedure (VS-INT-01, Day 3)**: Play each level as a competent
> solver (no deliberate slowdown). Record the raw completion time. Multiply by
> 1.2. Set `PAR_TIMES["level_00N"] = result`. Round to nearest 5 seconds.

---

## Par Time Source

Par times live in `src/systems/stars/stars_config.gd` as a typed `Dictionary`
constant. This keeps them editable in-script without a custom Resource class.

```gdscript
const PAR_TIMES: Dictionary = {
    "level_001": 60.0,
    "level_002": 60.0,
    ...
}
```

Par times are **not** stored in `LevelData` for VS. Storing them in `LevelData`
is deferred to Alpha, when the level editor tooling makes per-level authoring
practical.

---

## StarsSystem Node Placement

`StarsSystem` is a `Node` child of the Level scene, alongside `AudioSystem` and
`VfxSystem`. It is wired at level load time via `LevelSystem._initialize_level()`:

```
Level01 (LevelSystem)
  ├── ...
  ├── AudioSystem
  ├── VfxSystem
  └── StarsSystem   ← new in Sprint 8
        └── StarsDisplay (CanvasLayer — instantiated at runtime by StarsSystem)
```

`LevelSystem` holds an `@export var stars: StarsSystem` (null-safe). Wiring
follows the same guarded pattern as `AudioSystem` and `VfxSystem`.

---

## Signal Connections

| Signal | Source | StarsSystem response |
|--------|--------|---------------------|
| `level_started(level_index)` | `LevelSystem` | Record `_start_ms = Time.get_ticks_msec()`, store current `level_id` |
| `level_restarted` | `LevelSystem` | Reset `_start_ms = Time.get_ticks_msec()` (restart clock) |
| `level_victory` | `LevelSystem` | Stop timer, compute stars, call `_show_display()` |

---

## Persistence Model (Vertical Slice)

In-memory only. `StarsSystem` holds:

```gdscript
var _session_stars: Dictionary = {}  # level_id (String) → stars (int 1–3)
```

On each `level_victory`: if the new result is **better** than the stored value
(or no value exists), the dictionary is updated. This means replaying a level
can improve your star rating in the same session.

Save-to-disk is deferred to the Full Vision milestone (Save System).

---

## StarsDisplay UI Spec

`StarsDisplay` is a `CanvasLayer` (layer = 20, above HUD at layer 10) that is
**instantiated at runtime** by `StarsSystem` on `level_victory`. It is not a
persistent scene node — it is created, displayed, then freed.

### Layout

```
┌──────────────────────────────────────────┐
│                                          │
│          ⭐  ⭐  ⭐   (or fewer)          │
│         "Completed in 42.3s"             │
│                                          │
└──────────────────────────────────────────┘
```

- Centered on viewport.
- Star row: 3 `Label` nodes showing `⭐` (filled) or `☆` (empty).
- Time row: one `Label` showing `"Completed in %.1fs" % elapsed`.
- Background: semi-transparent `ColorRect` (Color(0, 0, 0, 0.6)), full-viewport.

### Timing

1. Display appears immediately on `level_victory`.
2. Stays visible for **2.0 seconds**.
3. After 2.0s: emits `display_complete` signal, then calls `queue_free()`.
4. `LevelSystem` does **not** await `display_complete` for VS — the existing
   `VICTORY_HOLD_TIME = 1.5s` timer in LevelSystem handles the advance delay.
   `StarsDisplay` shows for 2.0s and disappears just after the level transitions.

> **Note**: The 0.5s gap (display lives 2.0s, level advances after 1.5s) means
> the display auto-clears shortly after level load. This is acceptable for VS.
> Alpha will add a proper "tap to continue" interaction.

---

## Public API

### `StarsSystem`

```gdscript
## Wire signals. Call once in LevelSystem._initialize_level().
func setup(level_sys: LevelSystem) -> void

## Returns the best star count recorded for level_id this session.
## Returns 0 if the level has not been completed.
func get_stars(level_id: String) -> int

## Returns the elapsed time of the most recently completed level (seconds).
## Returns 0.0 if no level has been completed yet.
func get_time_elapsed() -> float
```

### Signals

```gdscript
## Emitted when StarsDisplay completes and is freed.
signal display_complete(level_id: String, stars: int)
```

---

## Null-Safety Contracts

- If `LevelSystem` is null in `setup()`: log a warning and return. No crash.
- If `level_id` is not in `PAR_TIMES`: use 60.0s default, no error.
- `StarsDisplay` uses `queue_free()` after its tween, guarded by `is_inside_tree()`.
- All `Time.get_ticks_msec()` calls are pure API with no failure mode.

---

*Document owner: Game Designer | Created: 2026-03-23 | Last updated: 2026-03-23*
