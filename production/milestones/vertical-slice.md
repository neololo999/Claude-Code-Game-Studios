# Milestone: Vertical Slice — Un monde complet poli

> **Status**: Planned
> **Target Date**: 2026-08-23
> **Created**: 2026-06-01
> **Owner**: Producer
> **Tier**: Vertical Slice (per `design/gdd/systems-index.md`)

---

## Milestone Definition

The Vertical Slice is the first version of **Dig & Dash** that is **demonstrable
to external playtesters**. The core loop from MVP is intact and fully functional;
this milestone wraps it in the visual and audio layer that makes the experience
legible and pleasurable to someone who has never played the game.

**This is a demonstration prototype, not a shippable product.** The goal is a
single polished world (all 10 levels) that communicates the game's identity —
grid-tight movement, the tension of a closing dig timer, the satisfying snap of
a guard falling into a hole — through art, sound, and responsive feedback.

After this milestone, the game can be shown to external playtesters without
explanation. Before this milestone, it cannot.

---

## Success Criteria

The Vertical Slice is **done** when ALL of the following are true:

### Visual
- [ ] All terrain types render as distinct pixel-art tiles (not colored rectangles)
- [ ] Player character has a sprite (idle + moving; no full animation rig required)
- [ ] Guard enemies have a sprite (idle + patrol; distinct from player)
- [ ] Camera follows the player and clamps to level bounds
- [ ] Dig holes show an open-state visual distinct from SOLID terrain
- [ ] Exit cell shows a distinct visual when locked vs. open
- [ ] Screen-shake on player death (< 0.3s, subtle)
- [ ] Pickup collection shows a brief flash or pop effect

### Audio
- [ ] Dig sound effect plays on `DigSystem.dig_started`
- [ ] Pickup collection sound plays on `PickupSystem.pickup_collected`
- [ ] Player death sound plays on `LevelSystem.player_died`
- [ ] Level complete sound plays on `LevelSystem.level_victory`
- [ ] Background music loop plays during gameplay (any placeholder track)
- [ ] All audio is at correct relative mix levels (no ear-splitting SFX)

### HUD
- [ ] Treasure counter visible during play: `X / Y collected` format
- [ ] Dig cooldown indicator reflects left + right dig cooldown state
- [ ] Exit-open indicator shows when exit is unlocked

### Stability
- [ ] All 10 levels complete without crashes or visual glitches
- [ ] Audio does not stutter or double-play on rapid events
- [ ] Camera never shows out-of-bounds (black bars) during normal play
- [ ] HUD always reflects the correct game state (no stale values after restart)

---

## Scope Boundaries

### In Scope (Vertical Slice)
- Camera system (player tracking + level bounds clamping)
- HUD (treasure counter + dig cooldown + exit indicator)
- Terrain renderer (pixel-art tiles — all 6 TileTypes)
- Entity renderer (player + guard sprites)
- Visual feedback (screen-shake on death, pickup pop, dig flash)
- Audio system (SFX + music loop)
- Stars / Scoring: **deferred to Sprint 8** (see note below)

### Out of Scope (deferred to Alpha or later)
| Feature | Milestone |
|---------|-----------|
| Main menu | Alpha |
| Win/lose transition screens | Alpha |
| World progression (multiple worlds) | Alpha |
| Full animation rigs (walk cycle, climb cycle) | Alpha |
| Settings (volume, fullscreen) | Full Vision |
| Save system | Full Vision |
| Level editor tooling | Full Vision |
| Stars / scoring system | Sprint 8 (end of VS) |

> **Note on Stars/Scoring**: Stars are in-scope for Vertical Slice per
> `systems-index.md`, but deferred to Sprint 8 to avoid blocking Sprint 6–7
> art/audio work. Stars require a timer and a design decision about scoring
> thresholds — these are design concerns that don't block rendering or audio.

---

## Sprint Plan (3 sprints)

| Sprint | Dates | Deliverable |
|--------|-------|-------------|
| **Sprint 6** | 2026-06-01 → 2026-06-14 | Camera + terrain renderer (ColorRect) + GDDs for Camera/HUD |
| **Sprint 7** | 2026-06-15 → 2026-06-28 | Pixel-art sprites (terrain + entities) + audio system + visual feedback |
| **Sprint 8** | 2026-06-29 → 2026-07-12 | HUD polish + stars/scoring + full VS integration pass + v0.2.0-vs tag |

> Capacity: 5 effective days/sprint (6 days − 20% buffer), solo developer at 3
> days/week. 3 sprints × 5 effective days = **15 effective days** for VS.

---

## Systems Required (5 new VS systems)

| # | System | GDD | Effort | Sprint | Status |
|---|---------|-----|--------|--------|--------|
| 1 | **Camera** | `camera-system.md` | S (1d) | Sprint 6 | ⬜ Not started |
| 2 | **Terrain Renderer** | *(no separate GDD — part of rendering arch)* | M (1.5d) | Sprint 6 | ⬜ Not started |
| 3 | **HUD** | `hud-system.md` | S (1d) | Sprint 6–7 | ⬜ Not started |
| 4 | **Audio** | `audio-system.md` | M (2d) | Sprint 7 | ⬜ Not started |
| 5 | **Visual Feedback** | `visual-feedback.md` | M (2d) | Sprint 7 | ⬜ Not started |
| 6 | **Stars / Scoring** | `stars-scoring.md` | S (1d) | Sprint 8 | ⬜ Not started |

---

## Risk Register

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| **VS-R01** | **Pixel-art asset production bottleneck** — creating 6 terrain tiles + player sprite + guard sprite to acceptable quality takes longer than estimated. No dedicated pixel artist; developer wears both hats. | High | Medium | Cap pixel art effort at 1.5d in Sprint 7. Use 16×16 or 32×32 tiles — smallest viable size. If not complete by Day 4 of Sprint 7, ship the ColorRect renderer from Sprint 6 as final and label VS "art-lite". |
| **VS-R02** | **Audio licensing / production** — finding or creating royalty-free SFX and music that fits the game's tone takes longer than expected. | Medium | Low | Use Godot's built-in AudioStreamGenerator for procedural placeholder SFX. Music: use any CC0 chiptune. The architecture matters more than the assets for this milestone. |
| **VS-R03** | **Camera system edge cases** — levels 006–010 have non-standard grid dimensions. Camera limit clamping may behave unexpectedly for levels exactly at viewport size (640×360). | Low | Medium | CAM-01 acceptance criteria explicitly require testing all 10 levels. No camera drift tolerance. |
| **VS-R04** | **HUD layout breaks at non-standard viewport** — `CanvasLayer` anchoring assumptions (top-left treasure, bottom dig bars) may need adjustment for levels larger than viewport. | Low | Low | Anchor all HUD elements to viewport edges using `AnchorPreset.FULL_RECT` sub-anchors. HUD is viewport-space, not world-space — Camera movement should not affect it. |
| **VS-R05** | **Scope creep from art direction** — once sprites exist, the temptation to add animations, parallax backgrounds, or post-processing effects is high. | Medium | Medium | Enforce the GDD freeze. Any new visual feature requires a GDD entry + Producer approval. Sprint 6 success metric: "sprites can be swapped in Sprint 7 without touching game-logic code." |

---

## Validation Criteria (Post-VS Gate)

Before declaring the Vertical Slice milestone closed, conduct an external playtest:

- [ ] A fresh player (not the developer) can understand the controls without instructions
- [ ] The tester uses the word "satisfying" or equivalent when describing the dig loop
- [ ] No visual glitches observed across a full 10-level playthrough
- [ ] Audio mix does not cause negative comments (too loud, too quiet, annoying)
- [ ] Tester attempts Level 1 at least 3 times voluntarily (engagement signal)

---

## Next Milestone: Alpha

After Vertical Slice, the next milestone adds the full progression structure:
main menu, world selection, multiple worlds (60 levels planned), and a save system.

*Document owner: Producer | Created: 2026-06-01 | Last updated: 2026-06-01*
