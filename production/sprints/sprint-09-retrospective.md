# Retrospective: Sprint 9 — Alpha Foundation
Period: 2026-03-23 – 2026-03-25
Generated: 2026-03-25

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (Must Have) | 5 | 5 | 0 |
| Tasks (Should Have) | 1 | 1 | 0 |
| Tasks (Nice to Have) | 1 | 0 | -1 |
| Completion Rate (Must+Should) | — | 100% | — |
| Effort Days (planned) | 5.0d | ~2–3d wall-clock | — |
| Bugs / Fix Commits | — | 9 | — |
| Feat Commits | — | 3 | — |
| Unplanned Tasks Added | — | 2 | — |
| Total Commits | — | 16 | — |

> ALPHA-00 was pre-done on 2026-03-23 ahead of the official sprint start,
> saving 0.5d of effective capacity.

---

## Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| Sprint 7 | 5.0d | 5.0d | 100% |
| Sprint 8 | 5.0d | 3.5d | 70% |
| Sprint 9 (current) | 5.0d | 5.0d | 100% |

**Trend**: Recovering — bounced back from Sprint 8's incomplete manual steps.
Sprint 8's 70% was a one-time dip caused by non-automatable tasks (audio
sourcing, manual integration playthrough) rather than code velocity issues.
Automatable/code tasks have maintained 100% across sprints.

---

## What Went Well

- **100% Must Have + Should Have delivery.** All 6 planned tasks shipped:
  ALPHA-00, GDD-TRANSITIONS, GDD-PROGRESSION, TRANSITION-01, PROGRESSION-01,
  GDD-MENU. No planned scope was deferred.

- **Sprint 10 unblocked ahead of schedule.** Commit `c605073` delivered
  TransitionSystem, ProgressionSystem, _and_ the MainMenu (MAIN-00) — a Sprint 10
  task — in a single session. Sprint 10 starts with approximately 2.5d of planned
  work already done.

- **Zero technical debt introduced.** No TODO, FIXME, or HACK comments appear
  anywhere in the codebase. Clean code hygiene maintained through an aggressive
  sprint.

- **ADR-001 decided and implemented same sprint.** The level authoring pipeline
  decision (TileMapLayer-first) was identified, documented as ADR-001, and
  implemented within the sprint window — avoiding a future sprint disruption when
  60-level content production would have hit the LevelBuilder ceiling.

- **Sprint 8 carryover did not block Sprint 9.** The three manual Sprint 8
  carryovers (audio sourcing, integration playthrough, v0.2.0-vs tag) ran in
  parallel and did not delay any Sprint 9 code tasks.

---

## What Went Poorly

- **ADR-001 implementation generated 8 stabilisation fix commits.** The
  TileMapLayer-first pipeline was decided and implemented mid-sprint, but
  integrating it with the existing TileSet/PackedByteArray/TerrainMap stack
  required 6 consecutive fix commits (`11b275d` through `d58e4a4`) before
  stabilising. This represents ~1–1.5 unplanned days of rework.

- **GDScript type errors shipped in the main delivery commit.** Commit `c605073`
  (the primary Sprint 9+10 delivery) was immediately followed by `eaac493`
  ("fix: resolve GDScript type errors in level_system, main_menu, test_dig_system")
  and `d1106b6` ("Fix GDScript parse errors in StarsSystem/StarsConfig"). Hot-fixes
  on a major delivery commit suggest insufficient local parse-testing before commit.

- **WORLD2-SKETCH (Nice to Have) not completed.** The 3 sketch World 2 levels
  were not started. This was correctly deprioritised under time pressure but means
  World 2 content design has zero validated levels entering Sprint 10.

- **Sprint header date inconsistency in sprint-09.md.** The document header reads
  `2026-07-13 to 2026-07-26` while the Capacity table shows the correct
  `2026-03-25 → 2026-04-07`. This is a documentation error that could cause
  confusion in historical tracking.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| TileSet null-safety in ADR-001 pipeline | ~1.5d (6 fix commits) | Iterative null checks and hybrid fallback in LevelSceneParser + TileMapLayer | Prototype new pipeline in isolation branch before merging; add a minimal Godot headless smoke test that loads `level_001.tscn` |
| GDScript type errors in main delivery commit | ~0.5d (2 fix commits) | Hot-fix commit same session | Run `godot --headless --check-only` locally on all modified `.gd` files before committing |
| Sprint 8 manual carryover (audio, tag) | Ongoing | Runs parallel; non-blocking | Budget manual tasks as separate calendar slots outside sprint velocity tracking |

---

## Estimation Accuracy

| Task | Estimated | Actual (approx) | Variance | Likely Cause |
|------|-----------|-----------------|----------|--------------|
| TRANSITION-01 | 1.5d | ~1.0d | -0.5d | State machine slots were well-defined; null-safe pattern was already established |
| PROGRESSION-01 | 1.5d | ~1.0d | -0.5d | Data model was spec'd in GDD before implementation; no database/file I/O in scope |
| ADR-001 pipeline (unplanned) | — | ~2.0d | +2.0d | Not estimated; emerged from mid-sprint architectural decision |
| MAIN-00 MainMenu (unplanned Sprint 10) | — | ~1.0d | +1.0d | Not in Sprint 9 scope; done opportunistically |

**Overall estimation accuracy**: ~100% for planned tasks (all within original
estimates or under). The sprint looks fast on the clock because the planned tasks
were well-scoped and two unplanned items (ADR-001, MAIN-00) ran concurrently with
bufferred capacity.

The consistent -0.5d variance on 1.5d programmer tasks suggests these task
estimates are 50% padded. Consider reducing similar 1.5d implementation estimates
to 1.0d in future sprints when a GDD is authored first.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| WORLD2-SKETCH | Sprint 9 (Nice to Have) | 1 | Deprioritised; buffer consumed by ADR-001 rework | Promote to Should Have in Sprint 10; 3 levels minimum for World 2 validation |
| AUDIO-ASSETS (manual sourcing) | Sprint 8 | 2 | Requires manual CC0 file hunting outside code tools | Assign a fixed-time block (1hr) outside sprint; close or descope if not done by Sprint 10 |
| v0.2.0-vs tag | Sprint 8 | 2 | Blocked on manual integration playthrough | Complete integration playthrough at Sprint 10 start; tag then |

---

## Technical Debt Status

- Current TODO count: **0** (previous: unknown — first retrospective)
- Current FIXME count: **0**
- Current HACK count: **0**
- Trend: **Clean** — no debt markers in `src/` or `scenes/`

The high fix-to-feat commit ratio (9:3) this sprint is not technical debt
accumulation — it reflects stabilisation of an unplanned architectural change
(ADR-001). The end state is clean.

---

## Previous Action Items Follow-Up

*No previous retrospective — this is Sprint 9, the first retrospective on record.*

---

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Run `godot --headless --check-only` (or equivalent parse check) on all modified `.gd` files before every commit | Programmer | High | Sprint 10 Day 1 |
| 2 | Complete Sprint 8 manual carryovers: source audio CC0 files, run integration playthrough, tag `v0.2.0-vs` | Producer | High | Sprint 10 Day 1 |
| 3 | Add WORLD2-SKETCH (3 sketch levels 011–013) as Should Have in Sprint 10 to validate World 2 design direction | Level Designer | Medium | Sprint 10 |
| 4 | Fix sprint-09.md header date (`2026-07-13 to 2026-07-26` → `2026-03-25 to 2026-04-07`) | Producer | Low | Next commit |
| 5 | Add a minimal CI/smoke step: `godot --headless --quit` against `main_menu.tscn` to catch scene-load regressions | DevOps / Programmer | Medium | Sprint 10 |

---

## Process Improvements

- **Parse-test before push.** GDScript type errors that reach `main` require a
  hot-fix commit, polluting the history and raising apparent fix-rate. Adding a
  pre-commit hook or a one-liner (`godot --headless --check-only res://`) would
  eliminate this class of follow-up commit entirely.

- **Scope unplanned ADR work explicitly.** ADR-001 was decided and implemented
  within Sprint 9 without adjusting the sprint scope or noting the trade-off
  against WORLD2-SKETCH. For future mid-sprint architectural decisions, log a
  quick scope-change note in the sprint doc so the trade-off is visible to
  reviewers.

---

## Summary

Sprint 9 was a strong delivery sprint — 100% of planned Must Have and Should Have
tasks shipped, and Sprint 10's most complex task (MainMenu) was partially completed
as a bonus. The main friction point was the ADR-001 TileMapLayer pipeline
implementation triggering 8 stabilisation fixes; this was unplanned scope that
consumed the buffer. Going into Sprint 10, the single most important improvement
is adding a local GDScript parse check before committing to prevent hot-fix
commit chains on major delivery commits.
