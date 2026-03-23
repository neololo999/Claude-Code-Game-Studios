# Sprint 6 — 2026-06-01 to 2026-06-14

> **Status**: Planned
> **Created**: 2026-05-31
> **Owner**: Producer
> **Sprint Number**: 6 of 8 (Vertical Slice)

---

## Sprint Goal

Lay the foundation of the Vertical Slice milestone: author the VS milestone doc,
write Camera and HUD GDDs, implement the `CameraController` (Camera2D with
player-tracking and level-bounds clamping), and replace all debug `draw_rect`
calls with a proper `TerrainRenderer` layer.

After this sprint, the game still has no audio and no animated sprites — but
every cell of every level is drawn by a dedicated rendering system (not debug
primitives), the camera follows the player and respects level bounds, and the
design contracts for Camera and HUD are locked for Sprint 7 implementation.

**This is a foundation sprint, not a polish sprint.** The single highest-risk
task is `RENDER-01`: integrating a new rendering layer into a codebase that
currently uses scattered `draw_rect` calls. All other tasks depend on
`RENDER-01` completing cleanly.

---

## Capacity

| Metric | Value |
|--------|-------|
| Sprint dates | 2026-06-01 → 2026-06-14 |
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |
| Tasks loaded — Must Have | 4.0d |
| Tasks loaded — Should Have | 1.0d |
| **Total loaded** | **5.0d** (100% of effective capacity) |

> Buffer is reserved for `RENDER-01` overrun (see S6-R01). If `RENDER-01`
> ships within estimate, the saved time folds into `HUD-01`. If `RENDER-01`
> overruns by > 0.5d, `HUD-01` drops to Sprint 7 without negotiation.

---

## Sprint 5 Retrospective Summary

| ID | Task | Owner | Estimate | Result |
|----|------|-------|----------|--------|
| LVL-06 | Author Levels 6–10 in `LevelBuilder` | Game Designer | 2.0d | ✅ Done |
| INT-03 | Full-playthrough integration pass (Levels 1–10) | Programmer | 1.0d | ✅ Done |
| MVP-01 | `_get_next_level_id()` verification + "YOU WIN" screen | Programmer | 0.5d | ✅ Done |
| MVP-02 | `project.godot` 640×360 + default scene verify | Programmer | 0.5d | ✅ Done |
| LVL-05 *(carryover)* | `LevelSystem` unit tests | Programmer | 0.5d | ✅ Done |
| MVP-03 | Final commit + MVP milestone closed + `v0.1.0-mvp` tag | Producer | 0.5d | ✅ Done |
| **Velocity** | | | **5.0 / 5.0d** | **100% Must Have · 100% Should Have** |

**What went well:** INT-03 completed within estimate despite 10-level scope —
state-leak concerns from S5-R01 did not materialise. Should Have column shipped
in full, raising confidence for Sprint 6 capacity model.

**What to watch:** RENDER-01 in Sprint 6 is a larger refactor than any single
task in Sprints 1–5. The absence of a rendering abstraction was by design for
MVP; removing it now requires auditing every scene that currently calls
`draw_rect` or uses debug colours. Budget the full 1.5d estimate; do not
compress it.

---

## Carryover from Sprint 5

None.

---

## Dependency Graph (Sprint 6)

```
[Sprint 5 — ✅ All Must Have + All Should Have]
  v0.1.0-mvp · 9 systems · 10 levels · zero visuals · static viewport
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
      [VS-00:             [GDD-CAM:           [GDD-HUD:
       VS milestone doc    Camera GDD          HUD GDD
       (0.5d)]             (0.5d)]             (0.5d)]
                               │                   │
                               ▼                   ▼
                           [CAM-01: ★CP        [HUD-01:  ← Should Have
                            CameraController    HUD impl
                            (1.0d)]             (0.5d)]

  [Sprint 5 — all 9 systems live]
          │
          ▼
      [RENDER-01: ★CP ★HIGHEST RISK
       TerrainRenderer — replaces all draw_rect terrain calls
       (1.5d)]
          │
          ▼
      [RENDER-02:  ← Should Have
       EntityRenderer — player + guard sprites
       (0.5d)]
```

**★CP = Critical Path**

Critical paths (sequential constraints):
- **Path A**: `GDD-CAM` (0.5d) → `CAM-01` (1.0d) = **1.5d chain**
- **Path B**: `RENDER-01` (1.5d) → `RENDER-02` (0.5d) = **2.0d chain** ← longest

`RENDER-01` is the single longest task and the gate for `RENDER-02`. Delay
here ripples into the Should Have column only — `CAM-01` and the three GDD
tasks are independent and can proceed in any order.

**Recommended sequencing for solo developer (5 days):**

| Day | Focus |
|-----|-------|
| Day 1 | `VS-00` (0.5d) + `GDD-CAM` (0.5d) |
| Day 2 | `GDD-HUD` (0.5d) + `CAM-01` start (0.5d) |
| Day 3 | `CAM-01` finish (0.5d) + `RENDER-01` start (0.5d) |
| Day 4 | `RENDER-01` continue (1.0d) |
| Day 5 | `RENDER-02` (0.5d) + `HUD-01` (0.5d) ← both Should Have |

---

## Tasks

### Must Have (4.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **VS-00** | Create `production/milestones/vertical-slice.md`. Must include: milestone definition ("un monde complet poli avec feedback visuel/audio"), success criteria checklist, scope boundaries (in/out), 3-sprint plan (Sprint 6–8 with per-sprint deliverables), and a risk register seeded with at least 3 VS-level risks. This document is the contract that governs Sprints 6–8 scope negotiations. | Producer | 0.5d | — | ⬜ Not started |
| **GDD-CAM** | Author `design/gdd/camera-system.md`. Must cover: Godot `Camera2D` setup and node placement, player-tracking logic (smooth follow via `position_smoothing`), level bounds clamping (camera cannot scroll past grid edges), conditional scroll behaviour (no scroll for levels ≤ 640×360 viewport; smooth scroll activated only for levels exceeding viewport in either axis), and `setup(player: Node2D, level_data: LevelData)` public API contract. | Game Designer | 0.5d | — | ⬜ Not started |
| **GDD-HUD** | Author `design/gdd/hud-system.md`. Must cover: treasure counter display (`X / Y collected`), dig cooldown indicator (separate left/right indicators mirroring `DigSystem` state), exit-open state indicator (hidden until exit is open), implementation requirement as a `CanvasLayer` (not parented to the game world — must be viewport-space), and integration contracts with `PickupSystem`, `DigSystem`, and `LevelSystem` signals. | Game Designer | 0.5d | — | ⬜ Not started |
| **CAM-01** ★CP | Implement `src/systems/camera/camera_controller.gd` and `src/systems/camera/camera_config.gd`. `CameraController` must extend `Camera2D`. Public API: `setup(player: Node2D, level_data: LevelData) -> void`. Internally: enable `position_smoothing`, compute level bounds from `level_data` grid dimensions × cell size, set `limit_left/right/top/bottom` to clamp to grid edges. For levels whose grid fits within 640×360, limits must prevent any scroll (camera centred on level). For larger levels, limits allow scroll within grid bounds. `camera_config.gd` exposes: `SMOOTH_SPEED: float = 5.0`. No camera shake in this sprint — that is Visual Feedback (Sprint 7). | Programmer | 1.0d | GDD-CAM | ⬜ Not started |
| **RENDER-01** ★CP ★HIGHEST RISK | Implement `src/systems/rendering/terrain_renderer.gd`. This replaces all existing debug `draw_rect` terrain rendering. `TerrainRenderer` must: (a) extend `Node2D`, (b) expose `setup(grid: GridSystem, terrain: TerrainSystem) -> void`, (c) expose `refresh() -> void` that redraws all cells, (d) connect to `TerrainSystem`'s `cell_changed(coords: Vector2i, tile_type: TileType)` signal for incremental updates on dig events (no full redraw on every dig). Each `TileType` must render as a distinct colour: `EMPTY` = transparent/black, `SOLID` = grey `#888888`, `DIRT_SLOW` = brown `#8B5E3C`, `DIRT_FAST` = tan `#C8A97A`, `LADDER` = yellow `#FFD700`, `ROPE` = orange `#FF8C00`. Use `ColorRect` nodes or `draw_rect` in `_draw()` — pixel-art sprites are Sprint 7. **Remove or disable all existing `draw_rect` terrain calls** from other scenes/scripts after `RENDER-01` is wired into `level_01.tscn`. | Programmer | 1.5d | — | ⬜ Not started |

### Should Have (1.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **RENDER-02** | Implement `src/systems/rendering/entity_renderer.gd`. Extends `Node2D`. Public API: `setup(player: Node2D, enemies: Array[Node2D]) -> void`. In `_process(delta)`: reposition a `ColorRect` or `Sprite2D` for the player (colour `#00AAFF` — blue) and one per enemy (colour `#FF2222` — red). Rects should be one cell-sized (e.g. 16×16 px or whatever cell size `GridSystem` defines). **Remove or disable all existing `draw_rect` entity calls** from other scenes/scripts after wiring into `level_01.tscn`. | Programmer | 0.5d | RENDER-01 | ⬜ Not started |
| **HUD-01** | Implement a minimal HUD as a `CanvasLayer` (layer index 10) in `level_01.tscn`. Nodes: (a) `Label` treasure counter wired to `PickupSystem.treasure_collected` and `PickupSystem.treasure_total` signals — format `"💎 %d / %d"`; (b) two `TextureRect` or `ColorRect` dig cooldown bars (left dig, right dig) wired to `DigSystem`'s cooldown progress (0.0–1.0); (c) an exit-open `Label` (`"EXIT OPEN"`) shown/hidden via `LevelSystem.exit_opened` signal. No visual polish — placeholder geometry and system fonts acceptable. This task follows `GDD-HUD` design decisions exactly. | Programmer | 0.5d | GDD-HUD | ⬜ Not started |

### Nice to Have

*None — sprint is at full effective capacity (5.0d loaded). Any additional scope
would consume the buffer reserved for `RENDER-01` overrun.*

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| **S6-R01** | `RENDER-01` underestimates the scope of removing existing `draw_rect` calls. If terrain rendering is interleaved across multiple scenes/autoloads rather than centralised, the audit and removal work may push the task past 1.5d. | Medium | High | Programmer | Before starting `RENDER-01`, spend 30 min auditing every `.gd` and `.tscn` file for `draw_rect`/`queue_redraw` calls. If more than 5 files are affected, escalate to Producer immediately — `RENDER-02` and `HUD-01` drop to Sprint 7, and the full 5d is given to the Must Have column. |
| **S6-R02** | `CAM-01` bounds-clamping behaves incorrectly for levels whose dimensions match the viewport exactly (640×360), potentially showing a 1-pixel scroll jitter or misaligned limit. Edge cases in Godot `Camera2D` limit values. | Low | Medium | Programmer | Add a regression test: load each of the 10 existing levels and verify zero camera drift on `_ready`. Include this in `CAM-01` acceptance criteria. Reserve the known 1.0d estimate rather than compressing. |
| **S6-R03** | GDD quality for Camera or HUD requires a revision cycle before `CAM-01` / `HUD-01` can implement. If the GDD author and implementer surface a design ambiguity mid-sprint (e.g. "how does the cooldown bar map to two independent dig timers?"), implementation stalls. | Low | Medium | Game Designer | GDDs must be written on Day 1–2 before any implementation. Implementer reviews each GDD before closing it — any open question is resolved same day. GDD-CAM and GDD-HUD are small systems (S size); ambiguity should surface and resolve within hours, not days. |
| **S6-R04** | `VS-00` milestone doc balloons into a full design exercise (world design, sprite art direction, audio direction) rather than a scoping document. Time spent > 0.5d. | Low | Low | Producer | `VS-00` scope is fixed: definition, success criteria, scope boundary, 3-sprint plan, risk register. No asset direction in this document — that belongs in individual GDDs. Hard stop at 0.5d; any excess detail is deferred to the relevant GDD. |

---

## Acceptance Criteria (Sprint Exit Gate)

The sprint is **Done** when ALL Must Have criteria below are true:

### VS-00
- [ ] `production/milestones/vertical-slice.md` exists
- [ ] Document contains: milestone definition, success criteria checklist (≥ 8 items), scope boundaries (in/out table), 3-sprint plan (Sprint 6–8 table), risk register (≥ 3 risks)
- [ ] Status field in the document reads `Planned`

### GDD-CAM
- [ ] `design/gdd/camera-system.md` exists
- [ ] Covers: `Camera2D` node setup, `position_smoothing` configuration, player-tracking approach, level-bounds clamping via `limit_*` properties
- [ ] Explicitly specifies no-scroll behaviour for levels ≤ 640×360 and scroll activation for larger levels
- [ ] Defines `setup(player, level_data)` public API signature and contract

### GDD-HUD
- [ ] `design/gdd/hud-system.md` exists
- [ ] Covers: treasure counter (X/Y format), left + right dig cooldown indicators, exit-open state indicator
- [ ] Specifies implementation as `CanvasLayer` (not in game-world space)
- [ ] Lists integration signals from `PickupSystem`, `DigSystem`, `LevelSystem`

### CAM-01
- [ ] `src/systems/camera/camera_controller.gd` exists and extends `Camera2D`
- [ ] `src/systems/camera/camera_config.gd` exists with `SMOOTH_SPEED` constant
- [ ] `setup(player, level_data)` correctly wires player tracking and sets `limit_*` to grid bounds
- [ ] All 10 existing levels load without camera drift or scroll for levels ≤ 640×360
- [ ] Committed to `main` with no new `push_error` calls

### RENDER-01
- [ ] `src/systems/rendering/terrain_renderer.gd` exists extending `Node2D`
- [ ] `setup(grid, terrain)` and `refresh()` methods implemented
- [ ] Connected to `TerrainSystem.cell_changed` signal — single-cell update, no full redraw on dig
- [ ] All 6 `TileType` values render as distinct, documented colours
- [ ] All pre-existing `draw_rect` terrain calls removed or disabled from other files
- [ ] All 10 levels render correctly after `setup()` call in `level_01.tscn`
- [ ] Committed to `main` with no new `push_error` calls

### Should Have (target, not blocking)
- [ ] `src/systems/rendering/entity_renderer.gd` exists; player renders blue, enemies red, positions track in `_process`
- [ ] HUD `CanvasLayer` in `level_01.tscn`; treasure counter and dig indicators update live during play

---

## Definition of Done (Sprint Level)

A task is **Done** when:
1. All acceptance criteria for that task are met
2. No new `push_error` calls introduced anywhere in the project
3. The change is committed to `main` with a descriptive message referencing the task ID
4. Any GDD or milestone doc affected is updated in the same commit
5. The task owner has self-tested in the Godot editor (run all 10 levels, verify no visual regressions)

---

## Notes

- **Vertical Slice = 3 sprints (6–8).** Sprint 6 = foundation (rendering + camera
  + GDDs). Sprint 7 = pixel-art sprites + audio + visual feedback. Sprint 8 =
  HUD polish + stars/scoring + full VS integration pass. Audio and Visual
  Feedback are explicitly **out of scope for Sprint 6** — do not pull them in
  even if capacity appears free.

- **`RENDER-01` is the most structurally significant task since Sprint 1.**
  Replacing debug rendering with a proper rendering layer touches the widest
  surface area of any task this sprint. Treat it as a mini-refactor: audit
  first, implement second, verify all 10 levels third. The 1.5d estimate assumes
  a clean audit; if the audit reveals deeply entangled `draw_rect` calls, the
  buffer day is RENDER-01's, not the Should Have column's.

- **`HUD-01` and `RENDER-02` are both Should Have.** If `RENDER-01` or `CAM-01`
  overrun into the buffer day, drop `HUD-01` first (0.5d), then `RENDER-02`
  (0.5d) — in that order. Neither blocks Sprint 7's scope. Document the
  carryover in this file before closing the sprint.

- **GDDs must precede implementation.** `GDD-CAM` must be committed before
  `CAM-01` starts coding. `GDD-HUD` must be committed before `HUD-01` starts.
  This is non-negotiable — GDDs exist to prevent implementation ambiguity, not
  to document it retroactively.

- **No sprite art in Sprint 6.** `RENDER-01` and `RENDER-02` use solid
  `ColorRect` fills — the same visual fidelity as MVP, but now routed through
  the correct rendering abstraction. Pixel-art asset creation is a Sprint 7
  concern, after the rendering layer exists and is stable.

- **Godot version**: 4.6.1 / GDScript. All implementations must target this
  exact version. `Camera2D.position_smoothing_enabled` and `Camera2D.limit_*`
  properties are the correct API surface for CAM-01.

- **Sprint 6 success metric:** "We'll know this sprint was right if Sprint 7 can
  add pixel-art sprites by swapping textures in `TerrainRenderer` and
  `EntityRenderer` without touching any game-logic code."

---

*Document owner: Producer | Created: 2026-05-31 | Last updated: 2026-05-31*
