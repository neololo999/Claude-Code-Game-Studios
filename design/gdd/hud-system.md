# GDD: HUD System

> **Status**: Approved
> **Created**: 2026-06-01
> **Last Updated**: 2026-06-01
> **Milestone**: Vertical Slice (Sprint 6–7)
> **Implements**: `src/systems/hud/hud_controller.gd`
> **Dependencies**: PickupSystem, DigSystem, LevelSystem

---

## Overview

The HUD (Heads-Up Display) shows the player the state of the three most
time-sensitive variables during play: how many treasures remain, whether their
dig ability is on cooldown, and whether the exit is open.

The HUD is implemented as a **`CanvasLayer`** node in `level_01.tscn` so it
renders in viewport space, not world space. Camera movement does not affect
HUD position.

**Design philosophy**: The HUD must be readable in one glance. All three
indicators are visible at all times during gameplay. No modal screens, no
tooltips, no tutorial popups — just three persistent status readouts.

---

## HUD Elements

### 1. Treasure Counter

**Purpose**: Tells the player how many treasures they still need to collect
to unlock the exit.

**Format**: `💎 X / Y` where X = collected, Y = total.

**Behaviour**:
- Initialised to `0 / Y` at level start.
- Updates on every `PickupSystem.pickup_collected` signal.
- Shows `Y / Y` (all collected) and visually confirms exit unlock state.
- Resets on `LevelSystem.level_restarted`.

**Position**: Top-left corner, 8px margin from viewport edge.

---

### 2. Dig Cooldown Indicators

**Purpose**: Tells the player when their dig ability is ready on each side.

**Layout**: Two indicators, labelled "← DIG" and "DIG →", positioned bottom-left
and bottom-right of the viewport respectively (or side by side at bottom-center).

**Behaviour**:
- When `DigSystem` is in READY state: indicator shows full (green `ColorRect`
  or filled bar). Label "READY".
- When `DigSystem` is DIGGING (cooldown active): indicator depletes as a
  progress bar from full → empty over the cooldown duration.
- Resets to full on `LevelSystem.level_restarted`.

**Implementation note**: `DigSystem` does not emit continuous progress signals.
The HUD controller must poll `DigSystem._cooldown_timer / config.dig_cooldown`
in `_process` to compute fill percentage (0.0–1.0).

> **Design decision — single DigSystem, two indicators**: The current `DigSystem`
> has a single cooldown shared between left and right dig. Both indicators reflect
> the same cooldown timer. When a future sprint splits left/right dig into
> independent cooldowns, the HUD is already structured to support two independent
> values.

---

### 3. Exit Indicator

**Purpose**: Tells the player the exit is open and they should head to it.

**Format**: A label or icon reading `"EXIT OPEN →"` (or equivalent).

**Behaviour**:
- Hidden at level start.
- Shown on `LevelSystem.exit_opened` signal (or `PickupSystem.exit_unlocked`).
- Hidden again on `LevelSystem.level_restarted` (reset state).

**Position**: Top-right or center-top of viewport.

---

## Node Structure

```
HUDLayer (CanvasLayer, layer = 10)
  └── TreasureLabel    (Label)
  └── DigBar           (HBoxContainer or Control)
        └── DigBarFill (ColorRect — scaled width by fill ratio)
  └── ExitLabel        (Label — visible = false until exit unlocked)
```

All nodes use the default Godot font. No custom fonts in Sprint 6 — visual
polish is Sprint 7.

`CanvasLayer` layer index is **10**, ensuring HUD renders on top of all game
world content.

---

## Public API — `HUDController`

`src/systems/hud/hud_controller.gd` (extends `CanvasLayer` or `Control`).

### `setup(pickups: PickupSystem, dig: DigSystem, level_system: LevelSystem) -> void`

Connects signals and stores references. Must be called once in
`LevelSystem._initialize_level()`.

### `initialize(total_pickups: int) -> void`

Sets `Y` in the treasure counter and resets all indicators to their
"level start" state. Called each time a new level loads (including on restart).

### `_process(delta) -> void`

Polls `DigSystem` cooldown progress and updates the dig bar fill ratio.

---

## Integration Signals

| Signal | Source | HUD Response |
|--------|--------|-------------|
| `pickup_collected(col, row, remaining)` | `PickupSystem` | Update treasure counter label |
| `exit_unlocked()` | `PickupSystem` | Show exit indicator |
| `level_restarted` | `LevelSystem` | Reset all indicators to level-start state |
| `level_started(index)` | `LevelSystem` | Re-initialize treasure counter for new level |

---

## Acceptance Criteria

| ID | Criterion |
|----|-----------|
| HUD-AC-01 | HUD is a `CanvasLayer` at layer index 10 in `level_01.tscn` |
| HUD-AC-02 | Treasure counter shows `0 / Y` at level start, increments on each pickup |
| HUD-AC-03 | Dig bar depletes during cooldown and refills on completion |
| HUD-AC-04 | Exit indicator is hidden at level start; shown on `exit_unlocked` |
| HUD-AC-05 | All indicators reset correctly on level restart |
| HUD-AC-06 | HUD position is unaffected by camera movement |
| HUD-AC-07 | No `push_error` during any level load, play, or restart |

---

## Out of Scope (this GDD)

- Custom fonts or styled UI (Sprint 7 visual polish)
- Level timer or speedrun display
- Score display (Stars/Scoring is a separate system)
- Animated transitions on indicator state changes (Sprint 7)

---

*Document owner: Game Designer | Created: 2026-06-01 | Last updated: 2026-06-01*
