# GDD: Transition Screens System

> **Status**: Approved
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-25
> **Milestone**: Alpha (Sprint 9)
> **Implements**: `src/systems/transition/transition_system.gd`
> **Dependencies**: LevelSystem, StarsSystem

---

## Overview

The Transition Screens system replaces LevelSystem's hardcoded timers with
interactive overlays that let the player acknowledge level outcomes before
advancing. After completing a level the player sees a **Victory Screen**
(stars + elapsed time + "Continue" prompt). After dying the player sees a
**Game Over Screen** (death count + "Retry" / "Quit to Menu"). After completing
the last level of a world the player sees a **World Complete Screen** (total
stars + "Next World").

**Design philosophy**: Transition screens give the player agency at every
outcome boundary. The player decides when to advance — they are never yanked
forward by a timer. The screens are minimal and fast to read (< 3 seconds of
text scanning), and every action is a single keypress or button click.

---

## Player Fantasy

The player finishes a level and sees their star rating and time. They feel a
moment of pride or determination before pressing a key to continue. If they
die, they see precisely how many times they have died and have a clear choice:
try again or go back to the menu. There are no confirmations, no pauses, no
loading screens between the outcome and the decision.

---

## Detailed Rules

### Screen Types

| Screen | Trigger | Content | Actions |
|--------|---------|---------|---------|
| Victory | `LevelSystem.level_victory` | Stars (1–3), elapsed time, "Continue" hint | Any key / button → advance to next level |
| Game Over | `DYING` timer expires (after `DEATH_FREEZE_TIME`) | Death count, "Retry" / "Quit to Menu" buttons | Retry → restart current level; Quit → return to menu |
| World Complete | ProgressionSystem emits `world_completed` (Sprint 10) | Total world stars / max stars, "Next World" / "Back to Menu" | Next World → advance; Back → menu |

### LevelSystem State Machine Extension

Two new states are added to the `State` enum:

```
TRANSITION_SCREEN  — Replaces VICTORY when TransitionSystem is present.
                     Entered after level_victory is emitted.
                     Exits when TransitionSystem.confirmed is emitted.

GAME_OVER          — Replaces immediate RESTARTING when TransitionSystem is present.
                     Entered after DYING timer expires.
                     Exits on TransitionSystem.retry_requested or
                     TransitionSystem.quit_to_menu_requested.
```

**Complete 9-state machine (after Sprint 9):**

| State | Transition To | On Condition |
|-------|--------------|--------------|
| IDLE | LOADING | `load_level()` called |
| LOADING | RUNNING | Level data resolved |
| RUNNING | DYING | Enemy catches player or `restart()` called |
| RUNNING | VICTORY | All pickups collected + exit reached |
| DYING | GAME_OVER | `DEATH_FREEZE_TIME` elapsed + TransitionSystem present |
| DYING | RESTARTING | `DEATH_FREEZE_TIME` elapsed + TransitionSystem null (fallback) |
| RESTARTING | RUNNING | `_do_restart()` complete |
| VICTORY | TRANSITION_SCREEN | Immediately if TransitionSystem present |
| VICTORY | TRANSITIONING | `VICTORY_HOLD_TIME` elapsed + TransitionSystem null (fallback) |
| TRANSITION_SCREEN | TRANSITIONING | `TransitionSystem.confirmed` received |
| GAME_OVER | RESTARTING | `TransitionSystem.retry_requested` received |
| GAME_OVER | IDLE (stub) | `TransitionSystem.quit_to_menu_requested` received |
| TRANSITIONING | RUNNING | Next level loaded |

### Signal Contracts

`TransitionSystem` emits:
- `confirmed` — player confirmed the Victory Screen (pressed any key / button)
- `retry_requested` — player chose Retry on the Game Over Screen
- `quit_to_menu_requested` — player chose Quit to Menu on the Game Over Screen
- `world_complete_confirmed` — player confirmed the World Complete Screen

`LevelSystem` responds:
- `confirmed` → `_do_next_level()`
- `retry_requested` → `_do_restart()`
- `quit_to_menu_requested` → print stub (Sprint 10: emit `return_to_menu` signal)
- `world_complete_confirmed` → `_do_next_level()` or emit `return_to_menu` depending on context

### CanvasLayer Placement

| Screen | Layer | Above |
|--------|-------|-------|
| HUDController | 10 | — |
| StarsDisplay | 20 | HUD |
| VictoryScreen | 30 | StarsDisplay |
| GameOverScreen | 30 | StarsDisplay |
| WorldCompleteScreen | 30 | StarsDisplay |

VictoryScreen at layer 30 sits above StarsDisplay at layer 20. Both displays
coexist: StarsDisplay auto-dismisses after `StarsConfig.DISPLAY_DURATION`
seconds; VictoryScreen waits for explicit player input. The player can press
"Continue" before or after StarsDisplay dismisses — both handle their own
lifecycle independently.

### Null-Safe Fallback

`LevelSystem.@export var transition: TransitionSystem` is nullable. When
`transition` is null:
- VICTORY → existing `VICTORY_HOLD_TIME` timer → TRANSITIONING (unchanged)
- DYING → existing `DEATH_FREEZE_TIME` → RESTARTING (unchanged)

All TransitionSystem API calls are guarded by `if transition != null`.
The game is fully playable without TransitionSystem wired.

### Input Handling

Victory Screen "any key" handler:
- Intercepts `_unhandled_input` inside VictoryScreen (CanvasLayer)
- Calls `get_viewport().set_input_as_handled()` to prevent propagation
- Prevents `_unhandled_input` in LevelSystem from receiving the same event
  (LevelSystem already guards restart with `if level_state != State.RUNNING`)

Game Over Screen:
- Uses Control buttons — standard Godot focus/click/gamepad navigation
- "Retry" button: emits `retry_requested` via MarginContainer
- "Quit to Menu" button: emits `quit_to_menu_requested`
- Escape key also triggers `retry_requested` (mirrors ui_cancel convention)

---

## Formulas

### Star Display (Victory Screen)

```
stars = StarsSystem.get_stars(level_id)
elapsed = StarsSystem.get_time_elapsed()

star_string = filled_star × stars + empty_star × (3 - stars)
time_string = "%.1fs" % elapsed
```

Variables:
- `stars`: int, range [1, 3]
- `elapsed`: float, seconds, range [0.0, ∞)

Example: stars=2, elapsed=47.3s → "⭐⭐☆  Completed in 47.3s"

### World Stars (World Complete Screen)

```
world_total_stars = sum(ProgressionSystem.get_stars(level_id) for level_id in world.level_ids)
world_max_stars = len(world.level_ids) × 3
```

Example: 10 levels, 23 total → "23 / 30 ⭐"

---

## Edge Cases

| ID | Scenario | Behaviour |
|----|----------|-----------|
| EC-T01 | Player presses key multiple times on Victory Screen | First keypress emits `confirmed` and frees the screen; subsequent keypresses have no target. `is_instance_valid()` guard in `_unhandled_input`. |
| EC-T02 | Player presses R or ui_cancel during TRANSITION_SCREEN | LevelSystem._unhandled_input checks `level_state != State.RUNNING` → no-op. Already handled. |
| EC-T03 | TransitionSystem present but StarsSystem null | VictoryScreen shows stars=0, elapsed=0.0. `stars` export var is null-safe. |
| EC-T04 | `confirmed` emitted during GAME_OVER state | LevelSystem._on_transition_confirmed() checks `level_state != State.TRANSITION_SCREEN` → no-op. |
| EC-T05 | Level has no next level (last level of last world) | `_do_next_level()` calls `_get_next_level_id()` → returns "" → `game_completed` emitted. VictoryScreen is freed before `game_completed`. |
| EC-T06 | World Complete Screen is not yet triggered (Sprint 9) | `show_world_complete()` exists in TransitionSystem API but is not called until Sprint 10 wires ProgressionSystem.world_completed signal. |

---

## Dependencies

| Direction | System | Nature |
|-----------|--------|--------|
| Depends on | LevelSystem | Receives call from `_on_player_reached_exit` and `_process(DYING)` |
| Depends on | StarsSystem | `get_stars()` and `get_time_elapsed()` called at victory |
| Depended on by | LevelSystem | Signals `confirmed`, `retry_requested`, `quit_to_menu_requested` drive state transitions |
| Depended on by | ProgressionSystem (Sprint 10) | `show_world_complete()` called when `world_completed` signal received |

---

## Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| `CANVAS_LAYER` | `TransitionConfig` | 30 | 25–50 | Must stay above StarsDisplay (20) and HUD (10) |
| `BG_COLOR` | `TransitionConfig` | `Color(0, 0, 0, 0.75)` | alpha 0.5–0.9 | Background overlay opacity |
| `HINT_BLINK_INTERVAL` | `TransitionConfig` | 0.6 | 0.3–1.2 | "Press any key" hint blink speed. Lower = faster blink = more urgency |

---

## Acceptance Criteria

| ID | Criterion | Testable? |
|----|-----------|-----------|
| AC-T01 | VictoryScreen appears after every `level_victory` | Yes — complete any level; overlay must be visible with stars and time |
| AC-T02 | Stars and time on VictoryScreen match StarsSystem values | Yes — compare VictoryScreen display to StarsSystem.get_stars() / get_time_elapsed() |
| AC-T03 | Any keypress on VictoryScreen advances to next level | Yes — press multiple keys; level must advance exactly once |
| AC-T04 | GameOverScreen appears after death freeze | Yes — let an enemy touch the player; wait DEATH_FREEZE_TIME; overlay must appear |
| AC-T05 | Death count on GameOverScreen matches LevelSystem.death_count | Yes — die N times; verify count displayed equals N |
| AC-T06 | Retry on GameOverScreen restarts the current level | Yes — choose Retry; player spawns at start, enemies reset |
| AC-T07 | "Quit to Menu" on GameOverScreen prints stub message, no crash | Yes — choose Quit to Menu; check Output panel for "[LevelSystem] Quit to menu" |
| AC-T08 | Without TransitionSystem wired, game behaves as Sprint 8 | Yes — remove TransitionSystem from scene; confirm VICTORY_HOLD_TIME + auto-advance |
| AC-T09 | No new push_error calls in any of the 10 levels | Yes — play all levels with Debugger open |
