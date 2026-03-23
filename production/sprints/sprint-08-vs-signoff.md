# VS Integration Sign-Off — Sprint 8

> **Status**: 🔲 In Progress
> **Created**: 2026-03-23
> **Sprint**: Sprint 8
> **Reviewer**: Programmer + Producer

This document tracks verification of every success criterion in
`production/milestones/vertical-slice.md`. All 21 criteria must be assessed
before the `v0.2.0-vs` tag is applied.

---

## How to Use This Document

Play all 10 levels with **all VS systems active** in the Godot editor:
`CameraController`, `TerrainRenderer`, `EntityRenderer`, `VfxSystem`,
`AudioSystem`, `HUDController`, `StarsSystem`.

For each criterion below, mark ✅ or ❌ with a brief note. If ❌, add an issue
reference and fix before re-testing. Do not tag until all ✅.

---

## Visual Criteria (8)

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| V1 | All terrain types render as distinct pixel-art tiles (not colored rectangles) | ⬜ | |
| V2 | Player character has a sprite (idle + moving; no full animation rig required) | ⬜ | |
| V3 | Guard enemies have a sprite (idle + patrol; distinct from player) | ⬜ | |
| V4 | Camera follows the player and clamps to level bounds | ⬜ | |
| V5 | Dig holes show an open-state visual distinct from SOLID terrain | ⬜ | |
| V6 | Exit cell shows a distinct visual when locked vs. open | ⬜ | |
| V7 | Screen-shake on player death (< 0.3s, subtle) | ⬜ | |
| V8 | Pickup collection shows a brief flash or pop effect | ⬜ | |

---

## Audio Criteria (6)

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| A1 | Dig sound effect plays on `DigSystem.dig_started` | ⬜ | |
| A2 | Pickup collection sound plays on `PickupSystem.pickup_collected` | ⬜ | |
| A3 | Player death sound plays on `LevelSystem.player_died` | ⬜ | |
| A4 | Level complete sound plays on `LevelSystem.level_victory` | ⬜ | |
| A5 | Background music loop plays during gameplay (any placeholder track) | ⬜ | |
| A6 | All audio is at correct relative mix levels (no ear-splitting SFX) | ⬜ | |

---

## HUD Criteria (3)

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| H1 | Treasure counter visible during play: `X / Y collected` format | ⬜ | |
| H2 | Dig cooldown indicator reflects dig cooldown state | ⬜ | Single bar (DigSystem has one shared cooldown — see HUD-02 note) |
| H3 | Exit-open indicator shows when exit is unlocked | ⬜ | |

---

## Stability Criteria (4)

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| S1 | All 10 levels complete without crashes or visual glitches | ⬜ | |
| S2 | Audio does not stutter or double-play on rapid events | ⬜ | |
| S3 | Camera never shows out-of-bounds (black bars) during normal play | ⬜ | |
| S4 | HUD always reflects the correct game state (no stale values after restart) | ⬜ | |

---

## Stars Criteria (added Sprint 8 — not in VS milestone doc)

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| ST1 | `StarsDisplay` appears after each level_victory | ⬜ | |
| ST2 | Star count reflects elapsed time vs. par correctly (1/2/3 stars) | ⬜ | |
| ST3 | Display auto-dismisses after ~2s with no crash | ⬜ | |

---

## Per-Level Playthrough Log

Play each level end-to-end. Note any issues observed.

| Level | Completed | Issues |
|-------|-----------|--------|
| level_001 | ⬜ | |
| level_002 | ⬜ | |
| level_003 | ⬜ | |
| level_004 | ⬜ | |
| level_005 | ⬜ | |
| level_006 | ⬜ | |
| level_007 | ⬜ | |
| level_008 | ⬜ | |
| level_009 | ⬜ | |
| level_010 | ⬜ | |

---

## Par Time Calibration (VS-INT-01 Day 3)

Update `StarsConfig.PAR_TIMES` with 1.2× clean-solve times after playing each level.

| Level | Raw Solve Time | Par Time (×1.2, round to 5s) | Updated in stars_config.gd |
|-------|----------------|-------------------------------|---------------------------|
| level_001 | — | — | ⬜ |
| level_002 | — | — | ⬜ |
| level_003 | — | — | ⬜ |
| level_004 | — | — | ⬜ |
| level_005 | — | — | ⬜ |
| level_006 | — | — | ⬜ |
| level_007 | — | — | ⬜ |
| level_008 | — | — | ⬜ |
| level_009 | — | — | ⬜ |
| level_010 | — | — | ⬜ |

---

## Open Issues

*List any ❌ criteria here with a fix plan.*

| ID | Criterion | Description | Fix Plan | Resolved |
|----|-----------|-------------|----------|---------|
| — | — | — | — | — |

---

## Sign-Off

| Role | Sign-Off | Date |
|------|----------|------|
| Programmer | ⬜ | — |
| Producer | ⬜ | — |

**Gate decision**: ⬜ PENDING — all stability criteria must be ✅ before tagging.

---

> **Triage rule (S8-R03)**: If > 3 open ❌ criteria remain by end of Day 4,
> fix stability criteria (S1–S4) first. Cosmetic ❌ items may be documented
> as known issues and deferred to Alpha without blocking the VS tag.

---

## HUD-02 Design Note

The VS criterion H2 specifies "left + right dig cooldown state". The current
`DigSystem` implements a single shared cooldown — there is no independent
left/right cooldown in the GDD (`dig-system.md`). The HUD renders one cooldown
bar which accurately reflects the single `DigSystem` state. This is a VS
milestone doc discrepancy, not a bug. The single-bar design is intentional and
correct per the `dig-system.md` specification.

---

*Document owner: Programmer + Producer | Created: 2026-03-23*
