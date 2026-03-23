# Milestone: MVP — First Playable Prototype

> **Status**: ✅ CLOSED — All 5 sprints complete · Tag: `v0.1.0-mvp`
> **Target Date**: 2026-05-31
> **Closed Date**: 2026-05-31
> **Created**: 2026-03-23
> **Owner**: Producer
> **Tier**: MVP (per `design/gdd/systems-index.md`)

---

## Milestone Definition

The MVP is the first version of **Dig & Dash** in which the complete core game loop
is functional end-to-end: a player can dig holes to trap guards, collect all treasures,
and reach the exit — across 10 hand-crafted levels — with no crashes, no game-breaking
bugs, and no missing systems.

**This is a playable prototype, not a shippable product.** No visual polish, no audio,
no main menu, no save system. The goal is a single executable that proves the core loop
is fun and that every system works together.

---

## Success Criteria

The MVP is **done** when ALL of the following are true:

### Functional
- [x] A player can launch the game and immediately start playing Level 1
- [x] The player can move left, right, climb LADDER, traverse ROPE
- [x] The player falls under discrete gravity when unsupported
- [x] The player can dig left and dig right; holes open and close on timer
- [x] Guards patrol and chase the player using grid-based pathfinding
- [x] Guards fall into open holes and are trapped for the hole's open duration
- [x] Collecting all treasures in a level triggers the exit to open
- [x] Reaching the open exit advances to the next level
- [x] A guard reaching the player triggers death and instant level restart
- [x] Falling into a closed hole triggers death and instant level restart
- [x] All 10 levels complete without crashes or softlocks
- [x] Level progression works: completing Level 10 shows a "YOU WIN" screen (placeholder)

### Stability
- [x] Zero crashes across a full playthrough of all 10 levels
- [x] No GDScript runtime errors (`push_error`) during normal gameplay
- [x] Level restart completes in < 500 ms (no perceptible freeze)
- [x] All dig timers reset correctly on restart (no state leaking between attempts)

### Content
- [x] 10 levels are designed, implemented as `LevelData` Resources, and playable
- [x] Each level is completable (verified by the designer completing it)
- [x] Levels introduce mechanics progressively (Level 1 = tutorial-simple, Level 10 = multi-guard puzzle)

---

## Systems Required (all 9 MVP systems)

| # | System | GDD | Effort | Sprint Target | Status |
|---|---------|-----|--------|--------------|--------|
| 1 | **Grid System** | `grid-system.md` | S (1d) | Sprint 1 | ✅ Done (Sprint 1) |
| 2 | **Terrain System** | `terrain-system.md` | M (2.5d) | Sprint 1 | ✅ Done (Sprint 1) |
| 3 | **Input System** | `input-system.md` | S (done) | Sprint 0 | ✅ Done (Sprint 0) |
| 4 | **Grid Gravity** | `grid-gravity.md` | S (1d) | Sprint 1 | ✅ Done (Sprint 1) |
| 5 | **Player Movement** | `player-movement.md` | M (2.5d) | Sprint 1–2 | ✅ Done (Sprint 1) |
| 6 | **Dig System** | `dig-system.md` | M (2.5d) | Sprint 2 | ✅ Done (Sprint 2) |
| 7 | **Pickup System** | `pickup-system.md` | S (1d) | Sprint 2 | ✅ Done (Sprint 2) |
| 8 | **Enemy AI** | `enemy-ai.md` | L (4d+) | Sprint 3–4 | ✅ Done (Sprint 3) |
| 9 | **Level System** | `level-system.md` | M (2.5d) | Sprint 4 | ✅ Done (Sprint 4) |
| — | **10 Playable Levels** | — | S (1.5d) | Sprint 4–5 | ✅ Done (Sprint 5) |

> Input System is complete and excluded from remaining capacity calculations.

---

## Scope Boundaries

### In Scope (MVP)
- Core loop: dig → trap → collect → exit
- Grid-based movement (player + guards)
- Terrain types: EMPTY, SOLID, DIRT_SLOW, DIRT_FAST, LADDER, ROPE
- Discrete gravity for player and guards
- 2 guard behaviours: patrol + chase
- Pickup system (collect all treasures → exit opens)
- Level System: init, win/lose conditions, restart, level sequence
- 10 hand-crafted levels
- Placeholder visuals: colored rectangles are acceptable
- No sound required

### Out of Scope (deferred to later milestones)
| Feature | Milestone |
|---------|-----------|
| Sprite art, animations | Vertical Slice |
| Visual feedback (particles, screenshake) | Vertical Slice |
| Sound effects and music | Vertical Slice |
| HUD (treasure counter, dig indicator) | Vertical Slice |
| Stars / scoring system | Vertical Slice |
| Camera system (scroll for large levels) | Vertical Slice |
| Main menu | Alpha |
| Win/lose transition screens | Alpha |
| World progression (multiple worlds) | Alpha |
| Save system | Full Vision |
| Settings (volume, fullscreen) | Full Vision |
| Level editor tooling | Full Vision |
| 60-level library | Full Vision |

---

## Sprint Plan (projected)

| Sprint | Dates | Deliverable |
|--------|-------|-------------|
| **Sprint 1** | 2026-03-23 → 2026-04-05 | Godot project + Grid + Terrain + Grid Gravity + Player Movement ✅ **Delivered (all Must Have + stretch)** |
| **Sprint 2** | 2026-04-06 → 2026-04-19 | Dig System + Pickup System + integration smoke-test scene ✅ **Delivered (all Must Have)** |
| **Sprint 3** | 2026-04-20 → 2026-05-03 | Enemy AI (core patrol + fall-into-hole + chase + TRAPPED/DEAD + integration) ✅ **Delivered (all Must Have + all stretch — 120% velocity)** |
| **Sprint 4** | 2026-05-04 → 2026-05-17 | Level System + Levels 1–5 ✅ **Delivered (all Must Have — 100% velocity)** |
| **Sprint 5** | 2026-05-18 → 2026-05-31 | Levels 6–10 + integration pass + bug fixes + MVP sign-off ✅ **Delivered (all Must Have + should have — 100% velocity)** |

> Capacity: 5 effective days/sprint (6 days − 20% buffer), solo developer at 3 days/week.

**Total remaining effort (after Sprint 1 — all systems delivered including Player Movement):**

| System | Effort | Days |
|--------|--------|------|
| Dig System | M | 2.5 |
| Pickup System | S | 1.0 |
| Enemy AI | L | 4.5 |
| Level System | M | 2.5 |
| 10 Levels | S | 1.5 |
| Integration + bug fix buffer | — | 2.5 |
| **Total** | | **~14.5 days** |

> 14.5 days / 5 effective days per sprint ≈ **2.9 sprints** remaining after Sprint 2.
> With 3 remaining sprints (Sprint 3–5), there is a ~0.1-sprint contingency buffer.
> Sprint 1 delivering Player Movement as a stretch goal recovered 2.5 days of schedule,
> allowing Sprint 2 to ship Pickup System alongside Dig System.
> **The schedule remains tight; no slack for scope creep.**

---

## Risk Register (MVP-level)

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| MVP-R01 | **Enemy AI complexity exceeds estimate** — Balance between predictability and intelligence is the hardest design problem in the project. Pathfinding, guard-fall detection, hole-avoidance, and chase logic may take 6+ days instead of 4.5. | High | High | Prototype Enemy AI in Sprint 3 as a standalone scene before integrating. Start with BFS shortest-path, resist adding heuristics until playtesting confirms need. Time-box: if > 4 days elapsed, ship the simpler version and iterate post-MVP. |
| MVP-R02 | **Dig System feel requires extended playtesting** — Timer values (`DIG_CLOSE_SLOW=8s`, `DIG_CLOSE_FAST=4s`) are best guesses. Wrong timing makes the game feel either trivially easy or frustratingly hard. | Medium | High | Build Dig System with `TerrainConfig` tuning knobs hot-reloadable in editor. Schedule a dedicated 1-day "feel tuning" session in Sprint 2 before moving to Pickup/Enemy AI. |
| MVP-R03 | **Level design bottleneck** — 10 levels of puzzle quality takes longer than estimated, especially if Level System tools are not ready. | Medium | Medium | Build levels incrementally (2 per sprint from Sprint 3 onward). Use tile-based JSON/Resource format from day 1 so levels can be authored without a custom editor. Accept rough early levels — polish is post-MVP. |
| MVP-R04 | **System integration surprises** — GridGravity ↔ TerrainSystem blocking, player/guard simultaneous fall, pickup detection on same frame as movement — these cross-system interactions may produce subtle bugs. | Medium | Medium | Dedicate Day 1 of Sprint 5 exclusively to integration testing. Write a minimal smoke-test scene that exercises all systems together from Sprint 2 onward. |
| MVP-R05 | **Scope creep from design improvements** — Once the loop is playable, there will be pressure to add "just one more" mechanic (e.g., a third guard type, teleporters). | Low | High | Enforce the GDD freeze. Any new mechanic requires a new GDD + ADR + scope negotiation with the Creative Director. Nothing ships without a GDD. |

---

## Design Pillars (from `systems-index.md`)

All MVP systems must serve these four pillars. Use them as the tiebreaker for any
implementation decision or scope negotiation:

1. **Puzzle d'abord, action ensuite** — Every system should enable planning before execution. Movement is grid-snapped; gravity is predictable; dig timers are visible.
2. **Tension constante** — The closing dig timer, guard pursuit, and gravity must all create persistent pressure. No system should allow the player to pause and relax indefinitely.
3. **Lisibilité parfaite** — At any moment, the player should be able to read the state of the level exactly. Grid alignment, discrete movement, and clear terrain types enforce this.
4. **Montée en complexité maîtrisée** — Level 1 introduces one concept. Each subsequent level adds exactly one new combination or constraint.

---

## Validation Criteria (Post-MVP Gate)

Before declaring the MVP milestone closed, run this validation playtest:

- [ ] A fresh player (not the developer) can understand the controls in < 60 seconds without instructions
- [ ] Levels 1–3 are completable by a new player within 3 attempts each
- [ ] Level 10 is completable by the developer in < 5 minutes
- [ ] No softlock observed across a complete playthrough
- [ ] Restart after death feels instantaneous (< 500 ms perceived)
- [ ] Developer subjectively rates the dig loop as "fun to execute" at the current timer values

---

## Next Milestone: Vertical Slice

After MVP, the next milestone adds visual and audio polish to a single complete world
(Levels 1–10), making it demonstrable to external playtesters. Target: Alpha in
approximately 3 additional sprints (Sprint 6–8).

Key additions for Vertical Slice:
- Sprite art for all terrain types + player + guards
- Dig/close/pickup animations
- Core sound effects (dig, collect, death, win)
- HUD: treasure counter + dig cooldown indicator
- Camera system for levels larger than viewport
- Stars/scoring system

---

*Document owner: Producer | Last updated: 2026-05-31 | Milestone CLOSED — v0.1.0-mvp*
