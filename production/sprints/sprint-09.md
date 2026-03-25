# Sprint 9 — 2026-07-13 to 2026-07-26

> **Status**: Active
> **Created**: 2026-03-23
> **Last updated**: 2026-03-25
> **Owner**: Producer
> **Sprint Number**: 9 (Alpha — Sprint 1 of 3)

---

## Sprint Goal

Lay the Alpha foundation: create the Alpha milestone document, design the
Transition Screens and Progression systems (GDDs), implement win/lose transition
overlays that replace `LevelSystem`'s hardcoded `VICTORY_HOLD_TIME`, and build
the `ProgressionSystem` skeleton that will drive the main menu in Sprint 10.

After this sprint, the game shows a victory screen after each level (with stars
and a "Continue" prompt) and a game-over screen after death (with "Retry" /
"Quit to Menu"). The `ProgressionSystem` tracks world/level state in memory,
ready for the main menu to consume in Sprint 10.

---

## Capacity

| Metric | Value |
|--------|-------|
| Sprint dates | 2026-03-25 → 2026-04-07 |
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |
| Tasks loaded — Must Have | 4.0d (ALPHA-00 ✅ pre-done, saves 0.5d) |
| Tasks loaded — Should Have | 0.5d |
| **Total loaded** | **4.5d** (90% of effective capacity) |
| Available buffer | 0.5d freed for WORLD2-SKETCH (Nice to Have) or unexpected rework |

---

## Sprint 8 Retrospective Summary

> Sprint 8 was partially executed at planning time. The code deliverables
> (StarsSystem, HUD-02 fix, VS sign-off doc) were committed. Manual steps
> (audio asset sourcing, integration pass, v0.2.0-vs tag) remain.

| ID | Task | Owner | Estimate | Result |
|----|------|-------|----------|--------|
| ALPHA-00 | Create `production/milestones/alpha.md` | Producer | 0.5d | ✅ Done (this sprint, Day 1) |
| GDD-STARS | Author `design/gdd/stars-scoring.md` | Game Designer | 0.5d | ✅ Done |
| STARS-01 ★CP | StarsSystem + StarsConfig + StarsDisplay | Programmer | 1.0d | ✅ Done |
| AUDIO-ASSETS | Source CC0 audio + CREDITS.md | Producer | 0.5d | ⚠️ Structure only — audio files need manual sourcing |
| HUD-02 | Treasure counter format fix | Programmer | 0.5d | ✅ Done |
| VS-INT-01 | Integration pass sign-off doc | Programmer | 2.0d | ⚠️ Document created — manual playthrough pending |
| VS-RELEASE | `v0.2.0-vs` tag | Producer | 0.5d | ⚠️ Pending manual VS-INT-01 completion |

**Velocity**: 3.5 / 5.0d code work complete. 1.5d manual steps (audio
sourcing, integration playthrough, tag) carry forward as pre-conditions
for VS milestone close — they do not block Sprint 9 implementation.

> **Action required before VS close**: Complete `sprint-08-vs-signoff.md`,
> source audio files, assign in inspector, tag `v0.2.0-vs`.

---

## Post-Plan Codebase Changes (2026-03-25)

> A significant refactor was committed **after** the Sprint 9 plan was authored
> (commit `14805c0`). Key changes relevant to this sprint:

| Change | File | Impact on Sprint 9 |
|--------|------|-------------------|
| `starting_level_id` export var added; `load_level(id)` promoted to full public API | `level_system.gd` | **Positive for PROGRESSION-01**: ProgressionSystem can call `load_level()` directly in Sprint 10 without API changes. |
| LevelSystem `_ready()` now auto-starts via `starting_level_id` instead of hardcoded `level_001` | `level_system.gd` | **Positive for Sprint 10**: MainMenu can set `starting_level_id` or call `load_level()` directly. |
| `level_system.gd` was touched (non-state-machine changes) | `level_system.gd` | **S9-R01 note**: State machine enum (lines 43–50) is unchanged. New file version is the correct base for TRANSITION-01. Implementer must re-read before touching state machine. |
| Diagonal digging added | `dig_system.gd` | No Sprint 9 impact. |
| Climbing logic refined | `player_movement.gd` | No Sprint 9 impact. |
| New `level_02.tscn` TileMap-based scene | `scenes/levels/level_02.tscn` | **Positive for WORLD2-SKETCH** (Nice to Have): a real level_02 scene exists; World 2 sketch levels can build on this pattern. |
| New tools: `LevelTileMapBuilder`, `TerrainVisualizer` | `src/tools/` | Level design tooling now available for WORLD2-SKETCH. |

> **Action**: Implementer must `git pull` and review `level_system.gd` at
> `14805c0` before starting TRANSITION-01. The state machine enum is intact;
> the null-safe fallback design is still valid.

---



None blocking Sprint 9 implementation. VS-RELEASE (manual) runs in parallel.

---

## Dependency Graph (Sprint 9)

```
[Sprint 8 — StarsSystem · AudioSystem · VfxSystem · HUDController]
[Vertical Slice — LevelSystem 7-state machine · PickupSystem signals]
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
  [GDD-TRANSITIONS:  [GDD-PROGRESSION:  [ALPHA-00: ★ Day 1
   Transition screens  Progression /      production/milestones/
   GDD (0.5d)]         Worlds GDD (0.5d)] alpha.md (0.5d)]
       │                   │
       ▼                   ▼
  [TRANSITION-01:     [PROGRESSION-01: ★CP
   Win/lose screens    ProgressionSystem
   (1.5d)]             skeleton (1.5d)]
       │
       └──────────────────┐
                          ▼
                     [GDD-MENU ← Should Have
                      Main Menu GDD (0.5d)
                      — design only, impl Sprint 10]
```

**★CP = Critical Path**

Sequential constraints:
- **Path A**: `GDD-TRANSITIONS` (0.5d) → `TRANSITION-01` (1.5d) = **2.0d chain**
- **Path B**: `GDD-PROGRESSION` (0.5d) → `PROGRESSION-01` (1.5d) = **2.0d chain**
- Paths A and B are **independent** — can be done sequentially on Days 1–4.

**Recommended sequencing for solo developer (5 days) — revised post-ALPHA-00:**

| Day | Focus |
|-----|-------|
| Day 1 | `GDD-TRANSITIONS` (0.5d) + `GDD-PROGRESSION` (0.5d) + `TRANSITION-01` start (0.5d) |
| Day 2 | `TRANSITION-01` (continue 1.0d) |
| Day 3 | `TRANSITION-01` finish (0.5d) + `PROGRESSION-01` start (0.5d) |
| Day 4 | `PROGRESSION-01` (1.0d) |
| Day 5 | `PROGRESSION-01` finish (0.5d) + `GDD-MENU` (0.5d) + WORLD2-SKETCH if buffer remains |

---

## Tasks

### Must Have (4.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **ALPHA-00** ✅ | Create `production/milestones/alpha.md`. Must cover: milestone definition, success criteria (Navigation × 4, Transitions × 6, Progression × 4, Content × 4, Stability × 4), scope boundaries, 3-sprint plan (9–11), 4 Alpha systems with effort estimates, risk register (4 risks), validation criteria, and pointer to Full Vision. | Producer | 0.5d | — | ✅ **Done** (commit `d69539a`, 2026-03-23). `production/milestones/alpha.md` committed ahead of sprint start. |
| **GDD-TRANSITIONS** | Author `design/gdd/transition-screens.md`. | Game Designer | 0.5d | — | ✅ **Done** |
| **GDD-PROGRESSION** | Author `design/gdd/progression.md`. | Game Designer | 0.5d | — | ✅ **Done** |
| **TRANSITION-01** ★CP | Implement `src/systems/transition/transition_system.gd` and the three screen classes. Add `TRANSITION_SCREEN` and `GAME_OVER` states to `LevelSystem.State`. | Programmer | 1.5d | GDD-TRANSITIONS | ✅ **Done** | **Victory flow**: on `level_victory`, instead of starting the `VICTORY_HOLD_TIME` timer, enter `TRANSITION_SCREEN` and instantiate `VictoryScreen` (CanvasLayer 30): shows stars from `StarsSystem.get_stars()` and elapsed time from `StarsSystem.get_time_elapsed()`. Player presses any key → `TransitionSystem.confirmed` → LevelSystem calls `_do_next_level()`. **Game-over flow**: on `player_died`, after `DEATH_FREEZE_TIME`, enter `GAME_OVER` and instantiate `GameOverScreen`: shows death count, "Retry" (→ `_do_restart()`), "Quit to Menu" (→ stub: `print("[LevelSystem] Quit to menu")`). Both screens are `CanvasLayer` nodes instantiated at runtime and freed on confirmation. Null-safe: if `TransitionSystem` is not present, LevelSystem falls back to existing `VICTORY_HOLD_TIME` timer. `LevelSystem.@export var transition: TransitionSystem` (nullable). | Programmer | 1.5d | GDD-TRANSITIONS | Victory screen appears after `level_victory` showing correct star count and time. Any keypress advances to next level. Game-over screen appears after death freeze showing death count. Retry restarts level. Quit to menu prints stub message. Both screens null-safe (game works without TransitionSystem). No new `push_error`. |
| **PROGRESSION-01** ★CP | Implement `src/systems/progression/progression_system.gd`, `world_data.gd`, `save_slot.gd`. | Programmer | 1.5d | GDD-PROGRESSION | ✅ **Done** | `WorldData` resource: `world_id: String`, `world_name: String`, `level_ids: Array[String]`. `SaveSlot` class: `unlocked_worlds: Array[String]`, `level_stars: Dictionary`, `current_world_id: String`, `current_level_id: String` — no file I/O, in-memory only. `ProgressionSystem` (Node, candidate for autoload): initialises with an Array of `WorldData` representing the 3 Alpha worlds; World 1 unlocked by default. Implements `start_level()`, `on_level_completed(level_id, stars)` (updates SaveSlot + checks world completion), `is_world_unlocked(world_id)`, `get_world_state(world_id)`. Emits `world_completed(world_id: String)` and `world_unlocked(world_id: String)`. Does NOT yet drive LevelSystem — that connection is Sprint 10 (MainMenu). | Programmer | 1.5d | GDD-PROGRESSION | `ProgressionSystem` initialises with 3 worlds. `on_level_completed("level_010", 3)` correctly unlocks World 2. `is_world_unlocked("world_02")` returns true after World 1 is completed. SaveSlot data model matches GDD spec. No crashes. No `push_error`. |

### Should Have (0.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **GDD-MENU** | Author `design/gdd/main-menu.md`. | Game Designer | 0.5d | PROGRESSION-01 | ✅ **Done** |

### Nice to Have

| ID | Task | Owner | Est. Days | Notes |
|----|------|-------|-----------|-------|
| **WORLD2-SKETCH** | Design 3–5 sketch-quality levels for World 2 in `LevelBuilder` as `_level_011()` through `_level_015()`. Focus on introducing one new challenge (e.g. multi-guard coordination, ROPE-heavy traversal, or tight dig-timing puzzles). No pixel-art assets required — ColorRect/placeholder sprites sufficient. | Level Designer | 1.0d | Requires buffer day. These levels validate World 2's design direction before Sprint 10 authors all 10 World 2 levels. |

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| **S9-R01** | `TRANSITION-01` requires modifying `LevelSystem`'s 7-state machine, which was last touched in commit `14805c0` (2026-03-25). Adding `TRANSITION_SCREEN` and `GAME_OVER` states risks breaking existing `DYING → RESTARTING` and `VICTORY → TRANSITIONING` flows. | High | High | Programmer | Read `level_system.gd` at `HEAD` before touching the state machine — it was modified post-planning. The state machine enum (lines 43–50) is unchanged as of `14805c0`; the new `starting_level_id` and `load_level()` refactor does not affect state transitions. Add the new states as additional branches in `_process()` — do not restructure existing branches. The null-safe fallback (VICTORY_HOLD_TIME when TransitionSystem is null) means existing behaviour is preserved for any scene that doesn't wire TransitionSystem. Regression test: all 10 levels with TransitionSystem = null before wiring it in. |
| **S9-R02** | `PROGRESSION-01` is designed for autoload but the existing LevelSystem is not — connecting them in Sprint 10 may require a scene restructure. | Medium | Medium | Technical Director | Defer the autoload decision to the GDD-PROGRESSION authoring step. If autoload creates coupling problems, ProgressionSystem can remain a scene-level node owned by a new `GameRoot` scene introduced in Sprint 10. Document the choice in the GDD. |
| **S9-R03** | GDD quality for Transitions or Progression requires a revision cycle that delays TRANSITION-01 or PROGRESSION-01 past Day 2. | Low | Medium | Game Designer | Both GDDs authored on Day 1. Implementer reviews and flags any open questions by end of Day 1. Producer resolves same day. Implementer never waits more than one session. |
| **S9-R04** | Input handling on transition screens conflicts with `LevelSystem._unhandled_input` (Key R / ui_cancel triggers restart during RUNNING). Pressing any key on the victory screen might also trigger the R-key restart. | Medium | Medium | Programmer | Transition screens must be in `TRANSITION_SCREEN` or `GAME_OVER` state — `_unhandled_input` already guards restart with `if level_state != State.RUNNING`. Add the new states as additional no-op branches. Victory screen "any key" handler must call `event.handled = true` (or use `get_viewport().set_input_as_handled()`). |

---

## Acceptance Criteria (Sprint Exit Gate)

The sprint is **Done** when ALL Must Have criteria below are true:

### ALPHA-00
- [x] `production/milestones/alpha.md` exists and is committed ✅ (commit `d69539a`)
- [x] Covers all 5 success criterion groups, sprint plan, systems table, risk register ✅

### GDD-TRANSITIONS
- [x] `design/gdd/transition-screens.md` exists and is committed
- [x] Covers all 3 screen types, LevelSystem state extension, signal contracts, layouts, CanvasLayer placement, null-safe fallback

### GDD-PROGRESSION
- [x] `design/gdd/progression.md` exists and is committed
- [x] Covers WorldData model, SaveSlot class, ProgressionSystem placement, public API, Full Vision stub contract

### TRANSITION-01
- [x] `src/systems/transition/transition_system.gd` exists
- [x] `LevelSystem.State` enum includes `TRANSITION_SCREEN` and `GAME_OVER`
- [x] Victory screen shows star count + elapsed time after `level_victory`
- [x] Any keypress on victory screen advances to next level
- [x] Game-over screen shows death count with Retry / Quit to Menu options
- [x] Retry correctly restarts the current level
- [x] Both screens absent = game behaves exactly as Sprint 8 (null-safe)
- [x] No new `push_error` calls

### PROGRESSION-01
- [x] `src/systems/progression/progression_system.gd` exists
- [x] `src/systems/progression/world_data.gd` exists
- [x] `src/systems/progression/save_slot.gd` exists
- [x] World 1 unlocked by default; World 2 unlocked after `on_level_completed("level_010", any)`
- [x] `is_world_unlocked()` returns correct values
- [x] `world_completed` and `world_unlocked` signals emit correctly
- [x] No `push_error` calls

### Should Have (target, not blocking)
- [x] `design/gdd/main-menu.md` exists with scene structure, 3 UI states, and return-to-menu contract

---

## Definition of Done (Sprint Level)

A task is **Done** when:
1. All acceptance criteria for that task are met
2. No new `push_error` calls introduced anywhere in the project
3. The change is committed to `main` with a descriptive message referencing the task ID
4. Any GDD or milestone doc affected is updated in the same commit
5. The task owner has self-tested: all 10 existing levels play through the new transition flow without regressions

---

## Notes

- **LevelSystem state machine surgery is the highest risk this sprint.**
  Read `level_system.gd` completely before touching it. The 7-state machine
  has been stable for 5 sprints. The new states (`TRANSITION_SCREEN`,
  `GAME_OVER`) slot in as new branches — they do not replace existing ones.
  The null-safe fallback means no regression is possible when TransitionSystem
  is not wired.

- **ProgressionSystem does not drive LevelSystem yet.** `PROGRESSION-01`
  builds the data model and logic only. The wiring (`MainMenu calls
  ProgressionSystem.start_level() → LevelSystem.load_level()`) is Sprint 10.
  This avoids a circular dependency between ProgressionSystem (autoload
  candidate) and LevelSystem (scene node).

- **`SaveSlot` is the Full Vision contract.** Design it carefully in
  `GDD-PROGRESSION`. The Full Vision save system only needs to
  serialize/deserialize `SaveSlot` via `FileAccess` — no other changes
  to ProgressionSystem's API should be required.

- **Return-to-menu is a stub.** `GameOverScreen`'s "Quit to Menu" button
  prints a message and idles. The real scene transition (`get_tree()
  .change_scene_to_file("res://scenes/main_menu.tscn")`) requires the
  MainMenu scene to exist, which is Sprint 10.

- **Sprint 9 success metric:** "We'll know this sprint was right if Sprint 10
  can wire the MainMenu to `ProgressionSystem.start_level()` and drop in a
  `WorldSelect` UI without touching `LevelSystem` or `TransitionSystem`."

- **Godot version**: 4.6.1 / GDScript. New APIs this sprint: none.
  `CanvasLayer`, `InputEvent.is_action_pressed`, and `SceneTreeTimer` are
  all used in prior sprints. `get_tree().change_scene_to_file()` is Godot
  4.x stable API used in Sprint 10.

- **Level authoring pipeline — décision prise (2026-03-25).** Suite au
  constat que `LevelBuilder` (code GDScript) limite la créativité pour 60
  niveaux, l'ADR-001 a été acceptée : migration vers TileMapLayer-first.
  Sprint 10 devra inclure `LEVELS-PIPELINE-01` (voir
  `docs/adr/ADR-001-level-authoring-tilemap-migration.md`).
  Cette décision ne bloque pas Sprint 9 — `LevelBuilder` reste la source
  de vérité pour les niveaux 001–010 pendant toute cette sprint.

---

*Document owner: Producer | Created: 2026-03-23 | Last updated: 2026-03-25*
