# Sprint 5 — 2026-05-18 to 2026-05-31

> **Status**: In Progress
> **Created**: 2026-05-18
> **Owner**: Producer
> **Sprint Number**: 5 of 5 (MVP — FINAL SPRINT)

---

## Sprint Goal

Complete the game. Author Levels 6–10, run a full-playthrough integration pass,
wire the "YOU WIN" final screen, and sign off on the MVP milestone.

After this sprint, a player can launch `level_01.tscn` and play all 10 levels
end-to-end — no crashes, no `push_error` noise, no missing wiring — and see a
"YOU WIN" placeholder screen on completing Level 10.

**This is a sign-off sprint, not a feature sprint.** Every task either closes an
open gap or validates that what was built in Sprints 1–4 actually works together.
INT-03 is the highest-risk task and has priority over everything in the Should Have
column.

---

## Capacity

| Metric | Value |
|--------|-------|
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |

> Buffer is reserved for INT-03 overrun (see S5-R01). If INT-03 completes within
> estimate, the saved day folds into LVL-05 and MVP-03.

---

## Sprint 4 Retrospective Summary

| Item | Result |
|------|--------|
| LVL-01 — `LevelData` Resource schema | ✅ Done |
| LVL-02 — `LevelSystem` (init, win, lose, restart, advance) | ✅ Done |
| LVL-03 — Levels 1–5 authored via `LevelBuilder` | ✅ Done |
| LVL-04 — `level_01.tscn` wired, set as default scene | ✅ Done |
| LVL-05 — `LevelSystem` unit tests (stretch) | ❌ Not done — carryover to Sprint 5 |

**Velocity**: 4.0/4.0 Must Have days delivered (100%). All Must Have tasks
complete. Stretch goal (LVL-05) not reached — within normal operating parameters
given sprint capacity model.

Sprint 4 contracts (`LevelData`, `LevelSystem`, `LevelBuilder`, `LEVEL_IDS`,
`level_01.tscn` as default scene) are stable and ready for Sprint 5 to build on.

---

## Carryover from Sprint 4

| ID | Task | Original Sprint | Estimate | Priority |
|----|------|----------------|----------|----------|
| LVL-05 | `LevelSystem` unit tests | Sprint 4 (stretch) | 0.5d | Should Have |

---

## Dependency Graph (Sprint 5)

```
[Sprint 4 — All Must Have ✅]
  LevelData · LevelSystem · LevelBuilder (levels 1–5) · level_01.tscn (default)
                         │
          ┌──────────────┤
          ▼              │
    [LVL-06:             │
     Levels 6–10 in      │
     LevelBuilder (2d)]  │
          │              │
          ▼              ▼
    [INT-03: Full-playthrough integration pass (1d)]
          │
    ┌─────┴──────┐
    ▼            ▼
[MVP-01:      [MVP-02:
 _get_next_    project.godot
 level_id() +  640×360 verify
 YOU WIN (0.5d)] (0.5d)]
                         │
                         ▼
                   [LVL-05: Unit tests (0.5d)]
                         │
                         ▼
                   [MVP-03: Final commit + milestone close (0.5d)]
```

**Critical path**: LVL-06 → INT-03 → MVP-01 → MVP-03

---

## Tasks

### Must Have (4.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **LVL-06** | Author Levels 6–10 in `LevelBuilder` (`_build_level_006` through `_build_level_010`). Update `LEVEL_IDS` array to include all 10 IDs. Each level must introduce one new mechanic combination or constraint per design pillar 4. Levels must be completable — rough is acceptable, elegant is not required. | Game Designer | 2.0d | LVL-03 ✅ | ⬜ Not started |
| **INT-03** | Integration pass: run a complete playthrough of Levels 1–10 in the Godot editor. Log every `push_error`, softlock, wiring bug, and state-leak found. Fix all issues found. Exit criterion: zero `push_error` calls during normal gameplay across all 10 levels. | Programmer | 1.0d | LVL-06 | ⬜ Not started |
| **MVP-01** | (a) Verify `LevelSystem._get_next_level_id()` uses `LevelBuilder.LEVEL_IDS` when no `.tres` files are present (stub exists — confirm it works end-to-end). (b) Implement "YOU WIN" final screen logic: when `_get_next_level_id()` returns `null` after Level 10, emit a signal or transition to a placeholder "YOU WIN" `CanvasLayer`. | Programmer | 0.5d | INT-03 | ⬜ Not started |
| **MVP-02** | Verify `project.godot`: confirm `level_01.tscn` is the default scene, confirm window size is 640×360, confirm `display/window/stretch/mode` is correct for pixel-art grid. Fix any discrepancies found. | Programmer | 0.5d | LVL-04 ✅ | ⬜ Not started |

### Should Have (1.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **LVL-05** | `LevelSystem` unit tests (carryover from Sprint 4). Cover: `init()` with valid `LevelData`, `on_level_complete()` advancing to next level, `on_player_died()` triggering restart, `_get_next_level_id()` returning `null` on Level 10. | Programmer | 0.5d | LVL-02 ✅ | ⬜ Not started |
| **MVP-03** | Final commit: update `production/milestones/mvp.md` success criteria checkboxes to reflect delivered state. Mark milestone Status as **Complete**. Tag the commit `v0.1.0-mvp`. Write a one-paragraph retrospective note at the bottom of `mvp.md`. | Producer | 0.5d | INT-03, MVP-01, MVP-02 | ⬜ Not started |

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| **S5-R01** | INT-03 wiring bugs exceed 1-day estimate and expand to 2+ days. Cross-system state leaks (dig timers not resetting, pickup state persisting across restart) are the most likely source. | Medium | High | Programmer | Pre-allocate the 1-day buffer to INT-03 overrun. If INT-03 still overruns into Day 3, drop LVL-05 entirely — unit tests are Should Have, a clean playthrough is Must Have. |
| **S5-R02** | Level 10 puzzle design quality is too rough to meet pillar 4 ("Montée en complexité maîtrisée"). | Medium | Low | Game Designer | Accept rough — completable > elegant for MVP. Document a polish note in `mvp.md` post-sign-off. Level polish is a Vertical Slice concern. |
| **S5-R03** | `LevelSystem._get_next_level_id()` stub from Sprint 4 has a latent bug that surfaces only when `LEVEL_IDS` has 10 entries (off-by-one on final level). | Low | Medium | Programmer | MVP-01 explicitly verifies this case. Add it to the INT-03 checklist as a mandatory test case before closing that task. |

---

## Acceptance Criteria (Sprint Exit Gate)

The sprint is **Done** when ALL of the following are true:

- [ ] `LevelBuilder` contains `_build_level_001` through `_build_level_010` and `LEVEL_IDS` lists all 10 IDs
- [ ] All 10 levels are completable (designer has completed each manually)
- [ ] Full playthrough of Levels 1–10 in Godot produces **zero** `push_error` calls
- [ ] Completing Level 10 shows a "YOU WIN" placeholder screen (any implementation)
- [ ] `project.godot` default scene is `level_01.tscn`, window is 640×360
- [ ] `mvp.md` milestone status is updated to reflect Sprint 4 completion
- [ ] Git tag `v0.1.0-mvp` is pushed

### Should Have (target, not blocking)
- [ ] `LevelSystem` unit tests pass in `tests/`
- [ ] MVP-03 final commit + milestone marked Complete

---

## Definition of Done (Sprint Level)

A task is **Done** when:
1. The implementation matches its acceptance criteria above
2. No new `push_error` calls are introduced
3. The change is committed to `main` with a descriptive message
4. Any affected documentation is updated in the same commit

---

## Notes

- **This is the final MVP sprint.** After sign-off, the next milestone is Vertical
  Slice (Sprint 6+), which adds sprites, animations, sound, HUD, and camera.
- INT-03 is intentionally scheduled *after* LVL-06 so all 10 levels are present
  during the integration pass. Running it earlier would require a second pass.
- MVP-01 and MVP-02 are parallelisable with LVL-05 once INT-03 is green.
- LVL-05 (unit tests) is Should Have, not Must Have. If INT-03 runs long,
  drop LVL-05 without negotiation — it can be backfilled in Sprint 6 Sprint 0.
- The "YOU WIN" screen required by MVP-01 is explicitly a **placeholder** per
  the MVP scope boundaries. No transitions, no scoring, no animation required.

---

*Document owner: Producer | Created: 2026-05-18 | Last updated: 2026-05-18*
