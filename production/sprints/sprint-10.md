# Sprint 10 — 2026-04-09 to 2026-04-22

> **Status**: Planned
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-25
> **Owner**: Producer
> **Sprint Number**: 10 (Alpha — Sprint 2 of 3)

---

## Sprint Goal

Wire ProgressionSystem into the game loop and ship the Alpha main menu.
After this sprint the game launches into a world-select menu, the player
picks a world, levels load via ProgressionSystem, and "Quit to Menu" returns
to the menu with session progress preserved.

---

## Capacity

| Metric | Value |
|--------|-------|
| Sprint dates | 2026-04-09 → 2026-04-22 |
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Tasks loaded — Must Have | 4.5d |
| Tasks loaded — Should Have | 0.5d |
| **Total loaded** | **5.0d** (100% of effective capacity) |

---

## Sprint 9 Retrospective Summary

> Filled in at Sprint 9 close.

| ID | Task | Owner | Estimate | Result |
|----|------|-------|----------|--------|
| ALPHA-00 | `production/milestones/alpha.md` | Producer | 0.5d | ✅ Done (Sprint 9 pre-start) |
| GDD-TRANSITIONS | `design/gdd/transition-screens.md` | Game Designer | 0.5d | ✅ Done |
| GDD-PROGRESSION | `design/gdd/progression.md` | Game Designer | 0.5d | ✅ Done |
| TRANSITION-01 | TransitionSystem + screen classes | Programmer | 1.5d | ✅ Done |
| PROGRESSION-01 | ProgressionSystem + WorldData + SaveSlot | Programmer | 1.5d | ✅ Done |
| GDD-MENU | `design/gdd/main-menu.md` | Game Designer | 0.5d | ✅ Done |

---

## Dependency Graph (Sprint 10)

```
[Sprint 9 — TransitionSystem · ProgressionSystem · GDD-MENU]
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
  [MAIN-01: ★CP      [MAIN-02:          [MAIN-03:
   ProgressionSystem  "Quit to Menu"     Level completion
   autoload +         wires to           → ProgressionSystem
   LevelSystem reads  change_scene       .on_level_completed
   current_level_id   (0.5d)]            (0.5d)]
   (0.5d)]
       │
       ▼
  [MAIN-00: ★CP
   MainMenu scene +
   WorldSelect UI
   (2.5d)]
       │
       ▼
  [MAIN-04:
   project.godot →
   main_menu.tscn as
   main scene (0.5d)]
```

**★CP = Critical Path**

---

## Tasks

### Must Have (4.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **MAIN-01** ★CP | Register `ProgressionSystem` as an autoload in `project.godot` (name: "ProgressionSystem"). Update `LevelSystem._ready()` to call `get_node_or_null("/root/ProgressionSystem")` and use `get_current_level_id()` instead of `starting_level_id` when it returns a non-empty string. Null-safe: falls back to `starting_level_id` when autoload absent. | Programmer | 0.5d | PROGRESSION-01 ✅ | LevelSystem_ready() loads the level from ProgressionSystem.get_current_level_id() after start_level() has been called. Backwards-compatible: level_01.tscn launched directly still works. |
| **MAIN-00** ★CP | Implement `scenes/ui/main_menu.tscn` + `src/ui/main_menu.gd`. Scene is a Control node; script builds all UI in `_ready()`. Shows world cards from `ProgressionSystem.get_all_worlds()` with name, star count, and Start button. Unlocked worlds: active Start button. Locked worlds: greyed card, disabled button. Pressing Start on an unlocked world calls `ProgressionSystem.start_level(world_id, first_level_id)` then `get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")`. Keyboard/arrow-key navigation between cards. | Programmer | 2.5d | MAIN-01 | Menu shows 3 world cards on new game (1 active, 2 locked). Start on World 1 launches level_001. Arrow keys navigate cards. Session stars shown correctly. |
| **MAIN-02** | Replace the `print("[LevelSystem] Quit to menu")` stub in `_on_transition_quit_to_menu()` with `get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")`. Also emit `return_to_menu` signal (new signal) before the scene change so external listeners can hook in. Same for `game_completed`: emit `return_to_menu` then change scene to main menu. | Programmer | 0.5d | MAIN-00 | GameOverScreen "Quit to Menu" → main_menu.tscn loads. game_completed → main_menu.tscn loads. No crash. |
| **MAIN-03** | Wire level completion to ProgressionSystem: in `LevelSystem._initialize_level()`, connect `stars.display_complete` to a new handler `_on_stars_display_complete(level_id, stars)` that calls `ProgressionSystem.on_level_completed(level_id, stars)` (null-safe via get_node_or_null). Also handles WorldCompleteScreen: after `on_level_completed`, if ProgressionSystem emits `world_completed`, call `transition.show_world_complete(...)` (null-safe). | Programmer | 0.5d | MAIN-01, TRANSITION-01 | After completing a level, ProgressionSystem.get_world_state shows updated stars. Completing World 1 unlocks World 2 (verified in menu). |
| **MAIN-04** | Change `run/main_scene` in `project.godot` from `res://scenes/levels/level_01.tscn` to `res://scenes/ui/main_menu.tscn`. | Programmer | 0.5d | MAIN-00 | `godot --headless --quit` exits via main menu. F5 in editor opens main menu. |

### Should Have (0.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **WORLD2-SKETCH** | Add 3 sketch-quality levels (`_level_011`, `_level_012`, `_level_013`) in `LevelBuilder` for World 2 as GDScript-generated data. Minimal design: introduce multi-guard scenarios. No pixel-art — ColorRect tiles sufficient. | Level Designer | 0.5d | — | Levels 011–013 load without crash. Each introduces at least 2 guards. |

---

## Carryover from Sprint 9

*To be filled at Sprint 9 close.*

---

## Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| **S10-R01** | `ProgressionSystem` autoload registration is order-sensitive — if it _ready() fires before LevelSystem, current_level_id may be empty | Low | Medium | ProgressionSystem._ready() sets current_level_id="" by default; LevelSystem falls back to starting_level_id. Order independence guaranteed. |
| **S10-R02** | `change_scene_to_file` in LevelSystem introduces coupling to main_menu.tscn path | Medium | Low | Path is a single string constant; acceptable for Alpha. Full Vision: emit signal, let autoload handle routing. |
| **S10-R03** | MAIN-00 scope: WorldSelect UI at 2.5d is the largest Sprint 10 task | High | Medium | Scope strictly to code-generated UI (no .tscn authoring in editor). No animations. If > 2.5d, cut WORLD2-SKETCH. |

---

## Acceptance Criteria (Sprint Exit Gate)

### MAIN-01
- [ ] `ProgressionSystem` listed as autoload in project.godot
- [ ] LevelSystem._ready() uses ProgressionSystem.get_current_level_id() when non-empty
- [ ] Level_01.tscn still works when launched directly (backward-compatible)

### MAIN-00
- [ ] `scenes/ui/main_menu.tscn` exists
- [ ] `src/ui/main_menu.gd` exists
- [ ] Main menu shows 3 world cards
- [ ] Start on World 1 launches level_001 via ProgressionSystem.start_level()
- [ ] Arrow keys navigate between cards
- [ ] Session star counts update on return to menu

### MAIN-02
- [ ] "Quit to Menu" from GameOverScreen loads main_menu.tscn
- [ ] `game_completed` loads main_menu.tscn
- [ ] `return_to_menu` signal exists on LevelSystem

### MAIN-03
- [ ] Stars persist in ProgressionSystem after level completion
- [ ] Completing World 1 (levels 001–010) unlocks World 2

### MAIN-04
- [ ] Launching the game starts at the main menu

---

## Definition of Done (Sprint Level)

1. All Must Have acceptance criteria met.
2. No new `push_error` calls.
3. All 10 levels playable from main menu without crash.
4. Return to menu from both GameOverScreen and level completion works.
5. Code committed to `main` with task IDs in commit messages.
