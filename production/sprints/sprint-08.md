# Sprint 8 — 2026-06-29 to 2026-07-12

> **Status**: Planned
> **Created**: 2026-03-23
> **Owner**: Producer
> **Sprint Number**: 8 of 8 (Vertical Slice — final sprint)

---

## Sprint Goal

Close the Vertical Slice milestone: deliver Stars/Scoring, wire real CC0 audio
assets into the AudioSystem, complete a full integration pass verifying every VS
success criterion across all 10 levels, and tag `v0.2.0-vs`.

After this sprint, the game is demonstrable to external playtesters without
explanation — the test for the Vertical Slice milestone.

---

## Capacity

| Metric | Value |
|--------|-------|
| Sprint dates | 2026-06-29 → 2026-07-12 |
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |
| Tasks loaded — Must Have | 4.5d |
| Tasks loaded — Should Have | 0.5d |
| **Total loaded** | **5.0d** (100% of effective capacity) |

> Buffer is implicit in the VS-INT-01 estimate (see S8-R03). If Stars/Scoring
> ships ahead of schedule, the saved time folds into HUD-02 or SPRITE-ART.

---

## Sprint 7 Retrospective Summary

> Sprint 7 was Planned at time of writing. The table below will be filled in
> retrospectively once Sprint 7 closes. Expected outcome based on prior velocity:

| ID | Task | Owner | Estimate | Expected Result |
|----|------|-------|----------|----------------|
| GDD-AUDIO | Author `design/gdd/audio-system.md` | Game Designer | 0.5d | ⬜ TBD |
| GDD-VFX | Author `design/gdd/visual-feedback.md` | Game Designer | 0.5d | ⬜ TBD |
| SPRITE-01 ★CP | Terrain sprite pipeline + TerrainRenderer update | Programmer | 1.0d | ⬜ TBD |
| AUDIO-01 ★CP | Implement AudioSystem + AudioConfig | Programmer | 1.0d | ⬜ TBD |
| AUDIO-02 | Music loop support in AudioSystem | Programmer | 0.5d | ⬜ TBD |
| SPRITE-02 | Entity sprite pipeline + EntityRenderer update | Programmer | 0.5d | ⬜ TBD |
| VFX-01 | Screen-shake + pickup flash (VfxSystem) | Programmer | 1.0d | ⬜ TBD |

*Retrospective to be completed before Sprint 8 Day 1. Any Sprint 7 carryover
becomes the top priority of Sprint 8 and may displace HUD-02.*

---

## Carryover from Sprint 7

*To be filled in at Sprint 7 close. Assumed none (consistent with Sprints 1–6
velocity pattern). If carryover exists, it is inserted as Must Have above
STARS-01 and displaces HUD-02 from Should Have.*

---

## Dependency Graph (Sprint 8)

```
[Sprint 7 — Expected: All Must Have + All Should Have]
 AudioSystem · VfxSystem · SPRITE pipeline
 TerrainRenderer (Sprite2D) · EntityRenderer (Sprite2D)
 HUDController · CameraController · GDD-AUDIO · GDD-VFX
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
  [GDD-STARS:       [AUDIO-ASSETS:      [VS-INT-01 ★CP ★HIGHEST RISK
   Stars/Scoring     Source CC0 SFX      Full integration pass
   GDD (0.5d)]       + music (0.5d)]     (2.0d) — starts Day 3]
       │                                       ▲
       ▼                                       │
  [STARS-01: ★CP                               │
   Implement Stars/                        All Must Have
   Scoring (1.0d)]──────────────────────── above complete
                                               │
                                               ▼
                                       [VS-RELEASE (0.5d)
                                        gate check + tag]
       [HUD-02 ← Should Have
        polish pass (0.5d)]
```

**★CP = Critical Path**

Sequential constraints:
- **Path A**: `GDD-STARS` (0.5d) → `STARS-01` (1.0d) → feeds `VS-INT-01`
- **Path B**: `AUDIO-ASSETS` (0.5d) → feeds `VS-INT-01`
- **Path C**: `VS-INT-01` (2.0d) → `VS-RELEASE` (0.5d) = **the milestone gate**

**Recommended sequencing for solo developer (5 days):**

| Day | Focus |
|-----|-------|
| Day 1 | `GDD-STARS` (0.5d) + `AUDIO-ASSETS` (0.5d) |
| Day 2 | `STARS-01` (1.0d) — full day, Stars/Scoring implementation |
| Day 3–4 | `VS-INT-01` (2.0d) — integration pass, all 10 levels |
| Day 5 | `HUD-02` (0.5d, Should Have) + `VS-RELEASE` (0.5d) |

---

## Tasks

### Must Have (4.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **GDD-STARS** | Author `design/gdd/stars-scoring.md`. Must cover: timer model (start on `LevelSystem.level_started`, stop on `LevelSystem.level_victory`), star threshold spec (3 stars ≤ par time, 2 stars ≤ par × 1.5, 1 star = any completion), par time source (constant in `LevelData` resource or separate `StarsConfig`), `StarsSystem` node placement and signal connections, persistence model (in-memory for VS; save system deferred to Full Vision), `StarsDisplay` UI spec (shown post-victory before level advance, `CanvasLayer` above HUD), and public API (`get_stars(level_id: int) -> int`, `get_time_elapsed() -> float`). | Game Designer | 0.5d | — | `design/gdd/stars-scoring.md` committed before STARS-01 starts. Covers all 7 spec areas above. Reviewed by implementer same day. |
| **STARS-01** ★CP | Implement `src/systems/stars/stars_system.gd` and `src/systems/stars/stars_config.gd`. `StarsSystem` extends `Node`. Connects to `LevelSystem.level_started` (start timer) and `LevelSystem.level_victory` (stop timer + compute stars). `stars_config.gd` exposes `PAR_TIMES: Dictionary` (level_id → par seconds) with placeholder values (60s per level). `StarsDisplay` (`CanvasLayer`) instantiated by `StarsSystem` on victory: shows 1–3 star icons and elapsed time for 2 seconds then emits `display_complete` which `LevelSystem` can await before advancing. Stars result is stored in-memory only (`_session_stars: Dictionary`). Null-safe: if `LevelSystem` signals are not found, log warning and no-op — no crash. | Programmer | 1.0d | GDD-STARS | `StarsSystem` computes correct star count for a level completed in par time, 1.4× par, and 2× par. `StarsDisplay` appears for ~2s post-victory. System has zero crashes on full 10-level playthrough. No `push_error` introduced. |
| **AUDIO-ASSETS** | Source 5 royalty-free CC0 sound effects (dig, pickup, death, victory, game-complete) and 1 looping background music track. Acceptable sources: freesound.org (CC0 filter), OpenGameArt.org (CC0), or Godot's built-in `AudioStreamGenerator` for procedural SFX. Convert/export to `.ogg` (preferred) or `.wav`. Place in `assets/audio/sfx/` and `assets/audio/music/`. Update `audio_config.gd` `SFX_KEYS` paths and `MUSIC_TRACK_PATH` to point to the new files. Verify `AudioSystem` plays all 5 SFX and loops music in a test run. Document the licence/source for each asset in `assets/audio/CREDITS.md`. | Audio Director / Producer | 0.5d | AUDIO-01 (Sprint 7) | All 5 SFX play on their respective events in a test playthrough. Music loops continuously during gameplay. `assets/audio/CREDITS.md` lists source and licence for each file. No `push_error` or audio engine warnings. |
| **VS-INT-01** ★CP ★HIGHEST RISK | Full Vertical Slice integration pass. Systematically verify **every** success criterion in `production/milestones/vertical-slice.md` (Visual × 8, Audio × 6, HUD × 3, Stability × 4 = 21 criteria). Play all 10 levels end-to-end at least once with all systems active (Camera, TerrainRenderer, EntityRenderer, VfxSystem, AudioSystem, HUDController, StarsSystem). For each criterion: mark ✅ Done or ❌ Failed with a note. Fix any ❌ before proceeding — regressions discovered here take priority over Nice to Have scope. Document all findings in a sign-off checklist committed to `production/sprints/sprint-08-vs-signoff.md`. | Programmer + Producer | 2.0d | All Sprint 7 + STARS-01 + AUDIO-ASSETS | All 21 VS success criteria marked ✅ in `sprint-08-vs-signoff.md`. Zero crashes across a complete 10-level playthrough. No open ❌ items at sprint close. |
| **VS-RELEASE** | (a) Run the VS gate check (`/gate-check vertical-slice`). (b) Address any FAIL-level blockers surfaced. (c) Tag `v0.2.0-vs` on `main`. (d) Update `production/milestones/vertical-slice.md` Status to `✅ CLOSED`, add Closed Date and Tag fields. (e) Update `production/milestones/vertical-slice.md` success criteria checkboxes to reflect actual state. | Producer | 0.5d | VS-INT-01 | `v0.2.0-vs` tag exists on `main`. `vertical-slice.md` Status = `✅ CLOSED` with Closed Date. Gate check verdict is PASS or PASS-WITH-CONCERNS (no unresolved FAIL blockers). |

### Should Have (0.5d)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|---------------------|
| **HUD-02** | HUD visual polish pass on `HUDController`. Review all 3 VS HUD criteria: (1) treasure counter format exactly `X / Y collected`, (2) dig cooldown bars accurately reflect left and right cooldown independently, (3) exit indicator label updates correctly on `LevelSystem.exit_opened`. Apply any readability fixes at 640×360 native resolution (font size, contrast, positioning). Verify HUD state resets correctly after level restart (no stale values). | Programmer | 0.5d | HUD-01 (Sprint 6) | All 3 VS HUD criteria verified ✅. HUD shows correct values immediately after level restart (within 1 frame). No layout overflow or clipping at 640×360. |

### Nice to Have

| ID | Task | Owner | Est. Days | Notes |
|----|------|-------|-----------|-------|
| **SPRITE-ART** | Replace the solid-color 32×32 placeholder PNGs (from SPRITE-01, Sprint 7) with simple but distinct pixel-art tiles. Minimum bar: each TileType is visually distinguishable through shape/texture, not just color (for colorblind accessibility). Player and enemy sprites should be silhouette-distinct. No animation required. Existing `Texture2D` load path in `TerrainRenderer`/`EntityRenderer` is drop-in; no GDScript changes needed. | Technical Artist | 1.0d | Requires buffer day or VS-INT-01 finishing early. If not complete this sprint, VS ships with colored-PNG sprites and SPRITE-ART becomes Sprint 9 / Alpha priority. |

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| **S8-R01** | Sprint 7 carryover (particularly `VFX-01` or `AUDIO-01`) lands in Sprint 8, consuming capacity and displacing `HUD-02` or compressing `VS-INT-01`. | Medium | High | Producer | On Sprint 8 Day 1, audit Sprint 7 delivery before any new work. All Sprint 7 Must Have items must be complete before `VS-INT-01` starts. If Sprint 7 left AUDIO-01 incomplete, `AUDIO-ASSETS` is deferred and `VS-INT-01` adjusts its audio criteria scope accordingly. |
| **S8-R02** | Stars par time values (60s/level) are placeholders that feel wrong during the integration pass — too easy or too punishing — requiring a tuning session that wasn't budgeted. | Medium | Medium | Game Designer | Par times must be playtest-tuned in `VS-INT-01` (Days 3–4) when the developer plays all 10 levels anyway. Allocate 30 min within `VS-INT-01` to adjust `PAR_TIMES` constants in `stars_config.gd`. No new task needed. |
| **S8-R03** | `VS-INT-01` uncovers a cascade of regressions (e.g., `VfxSystem` screen-shake conflicts with `CameraController` on certain levels, or `AudioSystem` double-plays on rapid death/restart cycles) that require more than 2.0d to resolve. | Medium | High | Programmer | The 1.0d buffer day is implicitly reserved for `VS-INT-01` overrun. If by end of Day 4 more than 3 open ❌ criteria remain, invoke triage: (1) fix stability criteria first (crashes, black bars, stale HUD), (2) defer cosmetic ❌ items to an Alpha polish sprint, (3) tag `v0.2.0-vs` with known cosmetic issues documented in `sprint-08-vs-signoff.md`. |
| **S8-R04** | CC0 audio sourcing takes longer than 0.5d — finding assets that fit the game's tone requires extensive searching. | Low | Medium | Producer | Use OpenGameArt.org "Blippy Chippy" or similar explicitly CC0 chiptune SFX packs. A tone mismatch is acceptable for VS (VS-R02 mitigation: "architecture matters more than assets"). Any asset that doesn't crash the AudioSystem meets the VS bar. |
| **S8-R05** | SPRITE-ART scope creep — once any pixel art exists, there is pressure to add walk-cycle animation, tileset variants, or parallax backgrounds. | Low | High | Producer | SPRITE-ART is Nice to Have and subject to strict scope: 6 terrain tiles + 2 entity sprites, static (no animation). Any addition beyond this requires a new GDD entry + sprint negotiation. |

---

## Dependencies on External Factors

- **Sprint 7 full delivery** (AudioSystem, VfxSystem, SPRITE pipeline) is assumed. If Sprint 7 did not deliver its Should Have items, VS-INT-01 scope adjusts to mark those success criteria as ❌ and VS may close as "art-lite" per VS-R01 contingency.
- **CC0 asset availability**: AUDIO-ASSETS requires internet access to source files (freesound.org, OpenGameArt.org). These must be downloaded before network access is removed.
- **Godot 4.6.1 editor availability**: SPRITE-ART (Nice to Have) requires the Godot editor to validate sprite import and rendering.

---

## Acceptance Criteria (Sprint Exit Gate)

The sprint is **Done** when ALL Must Have criteria below are true:

### GDD-STARS
- [ ] `design/gdd/stars-scoring.md` exists and is committed
- [ ] Covers: timer model, 3-tier star thresholds, par time source, `StarsSystem` placement, signal connections, in-memory persistence, `StarsDisplay` UI spec, public API

### STARS-01
- [ ] `src/systems/stars/stars_system.gd` exists extending `Node`
- [ ] `src/systems/stars/stars_config.gd` exists with `PAR_TIMES` dictionary
- [ ] Star computation returns correct 1–3 value for par, 1.4×, and 2× par test cases
- [ ] `StarsDisplay` appears for ~2s after `LevelSystem.level_victory`
- [ ] System functional with zero crashes on full 10-level playthrough
- [ ] No new `push_error` calls

### AUDIO-ASSETS
- [ ] 5 SFX files present in `assets/audio/sfx/` (dig, pickup, death, victory, complete)
- [ ] 1 looping music file present in `assets/audio/music/`
- [ ] `audio_config.gd` paths updated and resolving
- [ ] All SFX audible on their respective game events in a test playthrough
- [ ] `assets/audio/CREDITS.md` documents source and licence for every file

### VS-INT-01
- [ ] `production/sprints/sprint-08-vs-signoff.md` committed with all 21 VS criteria assessed
- [ ] All stability criteria are ✅ (no crashes, no black bars, no stale HUD)
- [ ] Zero crashes across a full 10-level playthrough
- [ ] All audio criteria ✅ (SFX play, music loops, no stutter)

### VS-RELEASE
- [ ] `v0.2.0-vs` tag exists on `main`
- [ ] `production/milestones/vertical-slice.md` Status = `✅ CLOSED` with Closed Date
- [ ] Gate check result is PASS or PASS-WITH-CONCERNS (no unresolved FAIL blockers)

### Should Have (target, not blocking)
- [ ] HUD treasure counter shows `X / Y collected` format exactly
- [ ] Dig cooldown bars reflect left and right cooldown independently
- [ ] Exit indicator updates correctly; HUD resets cleanly after restart

---

## Definition of Done (Sprint Level)

A task is **Done** when:
1. All acceptance criteria for that task are met
2. No new `push_error` calls introduced anywhere in the project
3. The change is committed to `main` with a descriptive message referencing the task ID
4. Any GDD or milestone doc affected is updated in the same commit
5. The task owner has self-tested in the Godot editor (run all 10 levels, verify no regressions)

---

## Notes

- **This is the final Vertical Slice sprint.** The VS milestone closes here with
  the `v0.2.0-vs` tag. Do not pull Alpha scope (main menu, transition screens,
  world progression) into this sprint under any circumstances.

- **VS-INT-01 is the gate for everything.** Stars, audio assets, and HUD polish
  only matter if they pass the integration test. If VS-INT-01 reveals that VFX or
  audio from Sprint 7 are broken, fix those regressions *within* VS-INT-01's
  2.0d budget before moving to VS-RELEASE.

- **The VS milestone can close with colored-PNG sprites** (SPRITE-ART is Nice
  to Have). The VS success criterion "not colored rectangles" refers to the
  Sprint 7 `ColorRect` architecture, replaced by PNG-backed `Sprite2D` nodes.
  Solid-color 32×32 PNGs technically satisfy this. SPRITE-ART is aesthetics,
  not a gate blocker.

- **Stars par times must be tuned during playtesting**, not picked from a
  spreadsheet. The 60s/level default in `StarsConfig` is a placeholder; the
  correct value is 1.2× the designer's clean solve time. Budget 30 min in
  VS-INT-01 Day 1 to play each level and set real par times.

- **After VS-RELEASE, the next milestone is Alpha**: main menu, world
  progression (multiple worlds), win/lose transition screens. Sprint 9 should
  plan for: `design/gdd/progression.md`, `design/gdd/main-menu.md`, and
  implementing `ProgressionSystem`.

- **Godot version**: 4.6.1 / GDScript. Stars system introduces no new engine
  APIs beyond `Time.get_ticks_msec()`. All other systems are stable from
  Sprints 6–7.

- **Sprint 8 success metric:** "We'll know this sprint was right if an external
  playtester picks up the game and says something equivalent to 'satisfying'
  about the dig loop — without us explaining anything."

---

*Document owner: Producer | Created: 2026-03-23 | Last updated: 2026-03-23*
