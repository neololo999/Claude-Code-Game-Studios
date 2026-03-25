# GDD: Main Menu System

> **Status**: Approved
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-25
> **Milestone**: Alpha (Sprint 10)
> **Implements**: `src/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`
> **Dependencies**: ProgressionSystem, LevelSystem

---

## Overview

The Main Menu is the entry point of the Alpha build. It replaces the direct
`level_01.tscn` launch that the Vertical Slice used. It shows available worlds
with lock/unlock state, lets the player start World 1 (and any subsequently
unlocked worlds), and serves as the hub to which the game returns after "Quit
to Menu" or game completion.

**Design philosophy**: The menu is a world map, not a list. Each world is a
card that communicates instantly whether it is playable and how many stars have
been earned. Navigation is entirely keyboard/gamepad compatible — no mouse
required for any action.

---

## Player Fantasy

The player opens the game and immediately sees the world they've been working
through. Their star progress is visible at a glance. They pick a world and are
in gameplay within two button presses. On returning from death, the menu
restores the context they left — the same world is focused.

---

## Detailed Rules

### Scene Structure

`scenes/ui/main_menu.tscn` is the application's `run/main_scene`.

Node tree (built entirely in code by `main_menu.gd._ready()`):
```
MainMenu (Control — full rect)
  Background (ColorRect — dark background)
  VBoxContainer (centred)
    TitleLabel ("Dig & Dash")
    SubtitleLabel ("Select World")
    WorldCardsContainer (HBoxContainer)
      WorldCard × N (Panel — one per world, built dynamically)
        VBoxContainer
          WorldNameLabel
          StarsLabel ("X / Y ⭐")
          StartButton ("Start" / locked icon "🔒")
```

The `WorldCard` count is driven by `ProgressionSystem.get_all_worlds()`. Sprint
10 builds 3 cards (worlds 01–03); if worlds are added, new cards appear
automatically.

### UI States

| State | Trigger | Displayed Content |
|-------|---------|------------------|
| WorldSelect | Default on scene ready | All world cards; unlocked = active Start button; locked = greyed 🔒 label |
| LevelSelect | Not implemented Sprint 10 (stub `print`) | Deferred to Full Vision — Sprint 10 shows world select only |
| Settings | Not implemented Sprint 10 (stub `print`) | Deferred to Full Vision |

Sprint 10 scope: WorldSelect only. The "Settings" option may be a disabled
button in the footer. Pressing Start on an unlocked world immediately calls
`ProgressionSystem.start_level()` and changes the scene — no level select step.

### Navigation Flow

```
[application launch]
        │
        ▼
  scenes/ui/main_menu.tscn
        │
  Player focuses a World Card
  Presses Enter / ui_accept
        │
        ▼
  ProgressionSystem.start_level(world_id, first_level_id)
  get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")
        │
  LevelSystem._ready() reads ProgressionSystem.get_current_level_id()
  Loads the correct level
        │
  [...gameplay through all levels of the world...]
        │
  ┌─────────────────────────┐
  │ LevelSystem.return_to_menu signal emitted  │
  │ (on GameOverScreen "Quit to Menu"          │
  │  or game_completed with no next level)     │
  └─────────────────────────┘
        │
  get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
```

### Return-to-Menu Contract

`LevelSystem` gains a new signal in Sprint 10:
```gdscript
signal return_to_menu
```

Emitted in two situations:
1. `_on_transition_quit_to_menu()` — player chose "Quit to Menu" on GameOverScreen
2. `game_completed` is reached AND there is no next level (optional; deferred to design review)

`MainMenuLoader` (helper or direct scene signal) listens to `return_to_menu`
and calls `get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")`.

In Sprint 10 implementation, LevelSystem is not modified to directly know about
main_menu.tscn. Instead, `main_menu.gd._on_return_to_menu()` is connected when
the level scene is loaded. To do this without coupling:
- After `change_scene_to_file("level_01.tscn")`, the level scene emits
  `return_to_menu` — any node in the same scene tree can catch it via the
  SceneTree or via `/root/LevelSystem`.
- Simplest implementation: LevelSystem emits `return_to_menu`; in
  `_on_tree_entered()` or `_ready()` of main_menu, we connect to
  `get_tree().node_added` to detect LevelSystem and connect its signal.
  OR: LevelSystem calls `get_tree().change_scene_to_file()` directly when
  `return_to_menu_requested` is received from TransitionSystem.

**Sprint 10 decision**: LevelSystem handles the scene change directly
(simplest). `_on_transition_quit_to_menu()` calls
`get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")` instead of
just printing. `game_completed` similarly triggers scene change. This avoids
a complex signal backpropagation chain for the Alpha milestone.

### World Card Content

Each WorldCard is built from `ProgressionSystem.get_world_state(world_id)`:

| Field | Source | Display Rule |
|-------|--------|-------------|
| World name | `WorldData.world_name` | Always shown |
| Star count | `world_state.total_stars / world_state.max_stars` | e.g. "23 / 30 ⭐" |
| Start button | `world_state.unlocked` | Enabled + "Start" text if unlocked; disabled + "🔒 Locked" if not |

Locked world cards are visible but greyed out (`modulate.a = 0.5`). The
focused element cycles only through unlocked cards (locked cards are not
focusable). Tab / arrow keys navigate between unlocked cards.

---

## Formulas

### Card Star Display

```
total_stars = world_state.total_stars
max_stars   = world_state.max_stars   # len(level_ids) × 3

display = "%d / %d ⭐" % [total_stars, max_stars]
```

Example: 3 levels all 3★ → "9 / 9 ⭐". New game → "0 / 30 ⭐".

### Focus Restore

On returning from gameplay, the card for `ProgressionSystem.current_world_id`
is focused automatically:

```
focused_card_index = max(0, index_of(current_world_id, all_worlds))
```

If `current_world_id` is empty, default focus is card index 0.

---

## Edge Cases

| ID | Scenario | Behaviour |
|----|----------|-----------|
| EC-M01 | ProgressionSystem autoload not registered | `main_menu.gd` falls back to showing one hardcoded "World 1 – Start" card that launches level_001. Print warning. |
| EC-M02 | All worlds are locked (impossible by design — world_01 never locked) | WorldSelect shows at least one active card. |
| EC-M03 | Player presses Start on a locked card | Locked cards have `disabled = true`; input is ignored. |
| EC-M04 | return_to_menu called while already on main menu scene | `change_scene_to_file()` reloads main_menu.tscn — fresh state, progression preserved in autoload. |
| EC-M05 | `change_scene_to_file` fails (missing scene file) | Godot prints an error; game idles. No crash. |

---

## Dependencies

| Direction | System | Nature |
|-----------|--------|--------|
| Depends on | ProgressionSystem | `get_all_worlds()`, `get_world_state()`, `start_level()`, `get_current_level_id()` |
| Depends on | SceneTree | `change_scene_to_file()` for scene navigation |
| Depended on by | LevelSystem | Emits `return_to_menu` / calls `change_scene_to_file()` to return here |

---

## Tuning Knobs

| Knob | Location | Default | Safe Range | Effect |
|------|----------|---------|------------|--------|
| Card width | `_build_world_card()` | 180px | 140–240px | Width of each world card |
| Card spacing | `WorldCardsContainer.add_theme_constant_override` | 20px | 8–40px | Gap between world cards |
| Title font size | `TitleLabel.add_theme_font_size_override` | 32 | 24–48 | Game title display size |
| Locked modulate | `_build_world_card()` | `alpha = 0.45` | 0.3–0.6 | Visibility of locked cards |

---

## Acceptance Criteria

| ID | Criterion | Testable? |
|----|-----------|-----------|
| AC-M01 | Launching the game shows the main menu (not level_01 directly) | Yes — set main scene to main_menu.tscn; verify menu appears on launch |
| AC-M02 | Main menu shows 3 world cards; World 1 card is active, Worlds 2–3 are locked | Yes — new game → verify card states |
| AC-M03 | Pressing Start on World 1 card launches level_001 | Yes — select World 1, press Enter/Accept; level_001 loads and starts |
| AC-M04 | After completing World 1 (all 10 levels), returning to menu shows World 2 unlocked | Yes — complete World 1 in session; return to menu; World 2 card is active |
| AC-M05 | World star counts shown on cards reflect session progress | Yes — complete several levels; return to menu; verify star totals |
| AC-M06 | "Quit to Menu" from GameOverScreen returns to main menu | Yes — die in a level; choose Quit to Menu; main menu loads |
| AC-M07 | Keyboard/gamepad navigation works between world cards | Yes — use arrow keys / gamepad; focus cycles through unlocked cards only |
| AC-M08 | No push_error when ProgressionSystem autoload is absent | Yes — remove autoload registration; main menu should show fallback |
