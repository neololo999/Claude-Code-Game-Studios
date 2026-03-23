# Milestone: Alpha — Full Progression Structure

> **Status**: Planned
> **Target Date**: 2026-08-23
> **Created**: 2026-03-23
> **Owner**: Producer
> **Tier**: Alpha (per `design/gdd/systems-index.md`)

---

## Milestone Definition

The Alpha is the first version of **Dig & Dash** with a complete progression
structure: a main menu, multiple worlds, win/lose transition screens, and a
save system stub. The core loop from the Vertical Slice is intact and polished;
this milestone wraps it in the navigation and content structure that makes the
game feel like a complete product.

**This is a feature-complete prototype, not a shippable product.** The goal is
a navigable game with at least 3 thematic worlds (30 levels), a main menu that
lets the player choose their world, transition screens that summarise each level
outcome, and enough progression scaffolding that the save system (Full Vision)
can be dropped in without rearchitecting.

After this milestone, the game can be evaluated for scope, pacing, and
content quality against the Full Vision target.

---

## Success Criteria

The Alpha is **done** when ALL of the following are true:

### Navigation
- [ ] A main menu is shown on launch (not a direct level load)
- [ ] The main menu shows available worlds with lock/unlock state
- [ ] The player can start World 1 from the main menu
- [ ] Completing World N unlocks World N+1 (shown in the menu)

### Transition Screens
- [ ] A victory transition screen appears after each level (replaces VICTORY_HOLD_TIME)
- [ ] The victory screen shows: stars earned, elapsed time, "Continue" prompt
- [ ] A game-over / death screen appears after the death freeze (replaces instant restart)
- [ ] The game-over screen shows: death count, "Retry" and "Quit to Menu" options
- [ ] A world-complete screen appears after the last level of a world
- [ ] The world-complete screen shows: total stars earned in the world

### Progression
- [ ] ProgressionSystem tracks current world and level across the session
- [ ] Completing all levels of a world unlocks the next world
- [ ] Stars per level are persisted across the session (in-memory; save to disk is Full Vision)
- [ ] World completion state persists across the session

### Content
- [ ] World 1: 10 levels (carried from VS — levels 001–010)
- [ ] World 2: 10 new levels (levels 011–020) designed and playable
- [ ] World 3: 10 new levels (levels 021–030) designed and playable
- [ ] Each world introduces at least one new mechanic or enemy behaviour variation

### Stability
- [ ] Full 30-level playthrough completes without crashes or softlocks
- [ ] Main menu → world select → level → transition → next level flow has no dead ends
- [ ] Session state (stars, world unlock) is consistent after level restart and world completion
- [ ] No `push_error` calls introduced by Alpha systems

---

## Scope Boundaries

### In Scope (Alpha)
- Main menu (world select)
- Win/lose/world-complete transition screens
- ProgressionSystem (world/level sequencing, unlock logic, in-memory state)
- Worlds 2 and 3 (20 new levels)
- Save system **stub** (data model + interface; no file I/O until Full Vision)

### Out of Scope (deferred to Full Vision)
| Feature | Milestone |
|---------|-----------|
| Save to disk / load from disk | Full Vision |
| Settings (volume, fullscreen, rebinding) | Full Vision |
| Worlds 4–6 (levels 031–060) | Full Vision |
| Full animation rigs (walk cycle, climb cycle) | Full Vision |
| Level editor tooling | Full Vision |
| Accessibility options | Full Vision |

---

## Sprint Plan (3 sprints)

| Sprint | Dates | Deliverable |
|--------|-------|-------------|
| **Sprint 9** | 2026-07-13 → 2026-07-26 | Alpha milestone doc + GDDs (Transitions, Progression, Main Menu) + TransitionScreens + ProgressionSystem skeleton |
| **Sprint 10** | 2026-07-27 → 2026-08-09 | Main Menu implementation + World 2 levels (011–020) |
| **Sprint 11** | 2026-08-10 → 2026-08-23 | World 3 levels (021–030) + Alpha integration pass + `v0.3.0-alpha` tag |

> Capacity: 5 effective days/sprint (6 days − 20% buffer), solo developer at 3
> days/week. 3 sprints × 5 effective days = **15 effective days** for Alpha.

---

## Systems Required (3 new Alpha systems)

| # | System | GDD | Effort | Sprint | Status |
|---|---------|-----|--------|--------|--------|
| 1 | **Transition Screens** | `transition-screens.md` | M (2d) | Sprint 9 | ⬜ Not started |
| 2 | **Progression / Worlds** | `progression.md` | M (2d) | Sprint 9–10 | ⬜ Not started |
| 3 | **Main Menu** | `main-menu.md` | M (2d) | Sprint 10 | ⬜ Not started |
| — | **Worlds 2–3 (20 levels)** | — | M (3d) | Sprint 10–11 | ⬜ Not started |

---

## Risk Register

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| **ALP-R01** | **Level design bottleneck** — 20 new levels of puzzle quality takes longer than 3d estimated. Each level requires concept, layout, playtest, and iteration. | High | High | Build 2–3 levels/day using `LevelBuilder` code generation. Accept "sketch quality" levels for Alpha; polish is Full Vision. Use World 1's design patterns as templates. |
| **ALP-R02** | **ProgressionSystem architecture lock-in** — the save system (Full Vision) must be able to slot into whatever ProgressionSystem builds in Sprint 9. Over-engineering or under-engineering both cause pain. | Medium | High | Design ProgressionSystem with an explicit `SaveSlot` data class from the start. The Full Vision save system only needs to serialize/deserialize that class — no other changes required. |
| **ALP-R03** | **Main menu scope creep** — once a menu exists, there is pressure to add options, settings, credits, animated backgrounds, etc. | Medium | Medium | Main menu for Alpha has exactly 3 states: World Select, (locked) World, (active) World. No settings screen. No credits. No animated backgrounds. Any addition requires Producer approval. |
| **ALP-R04** | **Transition screen flow conflicts with LevelSystem state machine** — inserting a player-input-gated screen between VICTORY and TRANSITIONING requires changes to LevelSystem's 7-state machine. | Medium | Medium | TransitionScreen becomes a new state (`TRANSITION_SCREEN`) inserted after VICTORY. LevelSystem awaits `TransitionScreen.confirmed` signal before calling `_do_next_level()`. |

---

## Validation Criteria (Post-Alpha Gate)

Before declaring Alpha closed:

- [ ] A fresh player can navigate from main menu → World 1 → Level 1 → complete all 10 levels → see World 2 unlock — without instructions
- [ ] The win/lose flow feels intentional (transition screen shows, player presses to continue, level advances)
- [ ] All 30 levels are completable by the developer
- [ ] No dead ends in the menu → game → menu round trip
- [ ] Developer rates World 2 and World 3 difficulty curve as "appropriately harder than World 1"

---

## Next Milestone: Full Vision

After Alpha, the final milestone adds save/load, worlds 4–6, settings,
full animation rigs, and the level editor tooling. Target: 3–4 additional
sprints (Sprints 12–15).

*Document owner: Producer | Created: 2026-03-23 | Last updated: 2026-03-23*
