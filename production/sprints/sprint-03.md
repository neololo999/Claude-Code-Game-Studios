# Sprint 3 — 2026-04-20 to 2026-05-03

> **Status**: Planning
> **Created**: 2026-04-20
> **Owner**: Producer
> **Sprint Number**: 3 of ~5 (MVP)

---

## Sprint Goal

Implement the Enemy AI system — the last major gameplay system before Level System
integration. After this sprint, a guard can patrol a row, avoid open holes, detect the
player, chase greedily, fall under gravity, and cycle through TRAPPED → DEAD → respawn.
This is the highest-risk sprint on the critical path; PATROL + CHASE are Must Have.
TRAPPED/DEAD is Should Have and brings the enemy to full MVP behaviour.

---

## Capacity

| Metric | Value |
|--------|-------|
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |

> Buffer is reserved for unexpected cross-system friction (GridGravity signal timing,
> TerrainSystem cell-state edge cases) and is pre-allocated to AI-05 + DIG-02 as
> stretch goals. Do not schedule into it intentionally.

---

## Sprint 2 Retrospective Summary

| Item | Result |
|------|--------|
| DIG-01 — DigSystem | ✅ Done (commit 3746774) |
| PICK-01 — PickupSystem | ✅ Done (commit b07cab8) |
| INT-01 — Integration smoke-test / LevelBootstrap | ✅ Done (commit 9891a2c) |
| DIG-02 — DigConfig Resource (stretch) | ❌ Not completed — buffer consumed by INT-01 edge cases; carried over to Sprint 3 stretch |

**Velocity**: 4.5/5.0 effective days delivered (90%). All Must Have and Should Have complete.
No regression risks identified. Sprint 2 contracts (DigSystem, PickupSystem, LevelBootstrap)
are stable API for Sprint 3 to build on.

---

## Carryover from Sprint 2

| Task | Reason not completed | New Estimate | Priority in Sprint 3 |
|------|---------------------|--------------|----------------------|
| DIG-02 — DigConfig Resource | Buffer consumed by INT-01 scene-wiring friction; DIG-02 is non-blocking for Enemy AI | 0.5d | Stretch |

---

## Dependency Graph (Sprint 3)

```
[Sprint 2 — All Must Have ✅]
  DigSystem · PickupSystem · LevelBootstrap · level_test.tscn
                         │
          ┌──────────────┤
          ▼              │
    [AI-01:              │
     EnemyConfig]        │
          │              │
          ▼              │
    [AI-02: PATROL +     │
     Gravity (2d)]       │
          │              │
          ▼              │
    [AI-03: CHASE +      │
     Detection (1.5d)]   │
          │              │
          ▼              │
    [AI-04: TRAPPED +    │  ◄── Should Have
     DEAD + Respawn (1d)]│
          │              │
          └──────────────┘
                ▼  (stretch, if buffer intact)
          [AI-05: INT-02 — enemy in level_test.tscn]
          [DIG-02: DigConfig carryover]
```

> AI-01 → AI-02 → AI-03 → AI-04 form a **strict sequential chain**.
> AI-05 and DIG-02 are independent of each other and can run in parallel on buffer day.

---

## Tasks

### Must Have — Critical Path (4 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| AI-01 | **EnemyConfig Resource** — `class_name EnemyConfig extends Resource` with four `@export` float parameters: `DETECTION_RANGE: float = 8.0`, `ENEMY_MOVE_SPEED: float = 5.0`, `TRAP_ESCAPE_TIME: float = 8.0`, `RESPAWN_DELAY: float = 2.0`; save as `resources/configs/enemy_config.tres`; `EnemyController` exposes `@export var config: EnemyConfig` | `godot-gdscript-specialist` | 0.5 | Sprint 2 systems stable | ① `enemy_config.tres` committed to `resources/configs/` and opens in Godot editor without errors ② All four float params are visible and editable in the Inspector ③ Changing a value in the `.tres`, saving, and reloading scene reflects the new value in EnemyController at runtime ④ No hardcoded equivalents of these constants remain in `enemy_controller.gd` |
| AI-02 | **EnemyController — PATROL + Gravity** — `class_name EnemyController extends Node2D`; state machine scaffold (enum `State { PATROL, CHASE, FALLING, TRAPPED, DEAD }`); `setup(grid: GridSystem, terrain: TerrainSystem, gravity: GridGravity, player: PlayerMovement)` dependency injection; `spawn(spawn_cell: Vector2i, rescate_cell: Vector2i)` positions enemy and stores rescate; `reset()` returns to spawn position in PATROL state; PATROL loop: move one cell horizontally per move tick; U-turn on: wall hit, grid edge reached, next cell is SOLID, next cell is OPEN (hole — do NOT jump in); subscribe to `GridGravity.entity_should_fall(id)` → transition to FALLING, fall cell-by-cell; subscribe to `GridGravity.entity_landed(id, cell)` → evaluate next state; emit `enemy_moved(id, from, to)`, `enemy_fell(id)` signals; unit tests in `tests/unit/test_enemy_controller.gd` | `godot-gdscript-specialist` | 2.0 | AI-01 | ① Enemy patrols horizontally without stopping on a flat SOLID-floored row (AC-01) ② Enemy U-turns when it reaches a wall, grid edge, or a SOLID cell ahead (AC-02a) ③ Enemy U-turns when the cell ahead has an OPEN floor hole (AC-02b — does NOT walk into hole) ④ `GridGravity.entity_should_fall` received → enemy transitions to FALLING, position updates cell-by-cell until supported (AC-06) ⑤ `reset()` called → enemy returns to `spawn_cell`, state = PATROL, move direction reset (AC-11) ⑥ `enemy_moved(id, from, to)` emitted on every valid PATROL step ⑦ `enemy_fell(id)` emitted on FALLING entry ⑧ Unit tests for all 4 ACs (01, 02, 06, 11) pass in `tests/unit/test_enemy_controller.gd` |
| AI-03 | **CHASE state + player detection** — line-of-sight check: same row OR same column, no SOLID cell between enemy and player, distance ≤ DETECTION_RANGE → transition PATROL → CHASE; greedy next_cell: from valid traversable neighbours (EMPTY, LADDER, ROPE — not SOLID, not OPEN), select cell that minimises Manhattan distance to player; horizontal tie-breaking (prefer horizontal move over vertical); LADDER cells used for vertical movement; subscribe to `PlayerMovement.player_moved(from, to)` to track player position; CHASE → PATROL when player exits detection range or LOS breaks; emit `enemy_reached_player(enemy_id: int, cell: Vector2i)` when enemy and player occupy same cell; emit `enemy_moved(id, from, to)` on each CHASE step | `godot-gdscript-specialist` | 1.5 | AI-02 | ① Player enters same row/col within DETECTION_RANGE with clear LOS → enemy transitions PATROL → CHASE within one update tick (AC-03) ② Greedy step reduces Manhattan distance each move; valid LADDER cells used for vertical (AC-04 + AC-10) ③ Player exits DETECTION_RANGE or LOS blocked → enemy transitions CHASE → PATROL (AC-05) ④ Enemy and player occupy same cell → `enemy_reached_player(id, cell)` emitted (AC-09) ⑤ `PlayerMovement.player_moved` received each frame → enemy re-evaluates target position (AC-12) ⑥ Greedy deadlock fallback: if no valid neighbour reduces distance, enemy stays in place and re-evaluates next tick (documented known limitation) ⑦ Unit tests for all 6 ACs (03, 04, 05, 09, 10, 12) pass |

**Must Have subtotal: 4.0 days**

---

### Should Have (1 day — brings enemy to full MVP behaviour)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| AI-04 | **TRAPPED + DEAD + respawn cycle** — after `entity_landed(id, cell)`: query `TerrainSystem.get_tile_state(cell.x, cell.y)` → if `DigState.OPEN` → transition to TRAPPED; start `TRAP_ESCAPE_TIME` countdown via `_process` delta accumulation (not `SceneTreeTimer`, so it survives scene pauses); on timer expiry → transition to DEAD; start `RESPAWN_DELAY` timer; on expiry → `spawn(rescate_cell, rescate_cell)` and transition to PATROL; edge case EC-03: if hole closes (tile returns to INTACT) while enemy is TRAPPED before escape timer fires → transition DEAD immediately on next `_process` tick; emit `enemy_trapped(id, cell)`, `enemy_escaped(id)` (if EC-03 triggers), `enemy_died(id)` signals at each transition; `notify_digging` call from DigSystem is **not required** — enemy reads terrain state directly | `godot-gdscript-specialist` | 1.0 | AI-02, AI-03 | ① Enemy falls into an OPEN cell → transitions to TRAPPED; `enemy_trapped(id, cell)` emitted (AC-07) ② TRAP_ESCAPE_TIME elapses while cell stays OPEN → transitions to DEAD → respawn at rescate_cell in PATROL (AC-08) ③ EC-03: hole closes while TRAPPED (cell state = INTACT) → immediate DEAD transition, `enemy_escaped(id)` suppressed, `enemy_died(id)` emitted ④ After RESPAWN_DELAY, enemy re-enters PATROL from rescate_cell — full patrol behaviour resumes ⑤ Unit tests for ACs 07, 08, and EC-03 pass in `tests/unit/test_enemy_controller.gd` |

**Should Have subtotal: 1.0 day — total effective capacity used: 5.0 days**

---

### Stretch Goals — Buffer Day (requires AI-01 through AI-04 complete within 5 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| AI-05 | **INT-02: Enemy in level_test.tscn** — Add one `EnemyController` node to `scenes/levels/level_test.tscn`; extend `LevelBootstrap` to call `enemy.setup(grid, terrain, gravity, player_movement)` and `enemy.spawn(Vector2i(8,6), Vector2i(1,1))`; connect `enemy_reached_player` to a console print handler (`[ENEMY] Reached player at {cell}`); verify end-to-end: enemy patrols, detects player, chases, falls into dig holes, traps, respawns — with no crashes or `push_error` | `godot-gdscript-specialist` | 0.5 | AI-01, AI-02, AI-03, AI-04, INT-01 | ① Scene opens with no console errors ② Enemy patrols visibly in editor play mode ③ Enemy transitions to CHASE when player moves into detection range ④ Enemy falling into a dug hole prints `[ENEMY] Trapped` to console ⑤ Enemy respawns at rescate_cell after RESPAWN_DELAY ⑥ `[ENEMY] Reached player at {cell}` prints when enemy catches player |
| DIG-02 | **DigConfig Resource (Sprint 2 carryover)** — `class_name DigConfig extends Resource`; `@export var dig_duration: float = 0.5`; `@export var dig_cooldown: float = 0.5`; save as `resources/configs/dig_config.tres`; update `DigSystem` to reference `@export var config: DigConfig` — no hardcoded timing constants remain in DigSystem | `godot-gdscript-specialist` | 0.5 | DIG-01 (Sprint 2) | ① `dig_config.tres` committed to `resources/configs/` and opens in Godot editor ② Changing `dig_duration` in the `.tres` and reloading the scene reflects the new cooldown in DigSystem ③ `@export var config: DigConfig` present in DigSystem; no inline float constants for dig timing remain |

**Stretch subtotal: 1.0 day (= buffer)**

---

## Critical Path

```
AI-01 (0.5d) → AI-02 (2d) → AI-03 (1.5d) → AI-04 (1d) → Sprint 3 Done
                  ↑
           ⚠️ BOTTLENECK
```

> ⚠️ **AI-02 is the sprint bottleneck** at 2 days and gates everything downstream.
> PATROL + Gravity is the foundation — if AI-02 is not complete by end of Day 3,
> escalate immediately: drop AI-04 scope before touching AI-03 (CHASE is higher
> player-facing value than TRAPPED cycle for Sprint 3).
>
> **Day 3 checkpoint**: AI-02 must be ≥ 80% done. PATROL loop functional + at least
> one GridGravity integration path verified. If behind, de-scope AI-04 to protect
> the AI-03 (CHASE) delivery.

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| S3-R01 | **EnemyController complexity** — 5 states, greedy pathfinding, trap cycle; L effort may underrun in CHASE implementation, leaving AI-04 incomplete | High | High | `godot-gdscript-specialist` | Split AI-02 (patrol+gravity) and AI-03 (chase) into separate tasks so partial delivery is possible. Track Day 3 checkpoint: if AI-02 < 80%, defer AI-04 to Sprint 4 and protect AI-03. Sprint ships PATROL + CHASE as minimum. |
| S3-R02 | **Greedy deadlock** — Greedy Manhattan move may get stuck if all traversable neighbours are blocked (e.g., enclosed corridors), causing enemy to freeze | Medium | Medium | `godot-gdscript-specialist` | Fallback: if no valid neighbour reduces Manhattan distance, enemy stays in place and re-evaluates next tick. Document as known limitation in `enemy_controller.gd` inline comment. Playtesting will determine if a fallback wander is needed post-MVP. |
| S3-R03 | **TRAPPED detection via cell state** — `TerrainSystem.get_tile_state()` must correctly return `DigState.OPEN` for a freshly dug cell; any timing gap between `entity_landed` and state update causes TRAPPED to be skipped | Low | Medium | `godot-gdscript-specialist` | Read terrain state in `entity_landed` handler after a single `await get_tree().process_frame` to ensure TerrainSystem has processed the dig event. Confirm `DigState` enum values are stable in TerrainSystem before AI-04 starts. |
| S3-R04 | **OQ-02 rescate position** — GDD requires a "fixed position defined by the level designer"; Level System does not exist yet | Medium | Low | Producer | Hardcode rescate as the `rescate_cell` parameter passed to `spawn()` for MVP. Level System (Sprint 4) will inject it via `EnemyController.spawn(spawn_cell, rescate_cell)` — the API is already designed to accept it. No rework needed. |

---

## Definition of Done for Sprint 3

All Must Have tasks require ALL acceptance criteria passing before the sprint is
closed. Partial completion of a task does not count toward velocity.

### Must Have (non-negotiable)
- [ ] `EnemyConfig.tres` loads in Godot editor without errors; all 4 params editable
- [ ] `EnemyController` PATROL + Gravity: ACs 01, 02, 06, 11 pass
- [ ] `EnemyController` CHASE + Detection: ACs 03, 04, 05, 09, 10, 12 pass
- [ ] Unit tests pass in `tests/unit/test_enemy_controller.gd` (no failures, no `push_error`)

### Should Have
- [ ] `EnemyController` TRAPPED + DEAD + respawn: ACs 07, 08, EC-03 pass *(if AI-04 complete)*
- [ ] Full enemy lifecycle exercised in unit tests without crashes

### Quality Gates
- [ ] No `push_error` or unhandled exceptions during any test run
- [ ] All public API functions (`setup`, `spawn`, `reset`, signals) have GDScript `## doc comments`
- [ ] Code follows project conventions: `snake_case` variables, `PascalCase` classes, `UPPER_SNAKE` constants
- [ ] `DigConfig.tres` committed under `resources/configs/` *(if DIG-02 stretch complete)*
- [ ] `LevelBootstrap.gd` updated with enemy wiring step *(if AI-05 stretch complete)*

---

## Sprint Schedule (indicative)

| Day | Date | Focus |
|-----|------|-------|
| Day 1 | Mon 2026-04-20 | AI-01 complete (0.5d) → AI-02 start: state machine scaffold + PATROL horizontal loop |
| Day 2 | Tue 2026-04-21 | AI-02 continued: U-turn logic (wall / edge / OPEN hole) |
| Day 3 | Thu 2026-04-23 | AI-02 complete: GridGravity integration (entity_should_fall + entity_landed) + unit tests *(Day 3 checkpoint: AI-02 ≥ 80%)* |
| Day 4 | Mon 2026-04-27 | AI-03: LOS detection, PATROL ↔ CHASE transitions, player_moved tracking |
| Day 5 | Tue 2026-04-28 | AI-03 complete: greedy step + enemy_reached_player + unit tests → AI-04 start (TRAPPED entry) |
| Day 6 | Thu 2026-04-30 | Buffer: AI-04 complete (DEAD + respawn) + AI-05 / DIG-02 stretch if time permits |

> Sprint review: **Sun 2026-05-03** — demo patrol → chase → trap cycle, retrospective.

---

## Open Questions Carried Into Sprint

| GDD | OQ ID | Question | Resolution Deadline |
|-----|-------|----------|---------------------|
| Grid Gravity GDD | OQ-02 | Player + guard simultaneous fall on the same column — cohabitation or collision? | Resolve during AI-02: document decision in `enemy_controller.gd` inline comment; raise ADR if a breaking GridGravity change is needed |
| Enemy AI GDD | OQ-03 | If the greedy chase path requires the enemy to descend via LADDER but the LADDER is not adjacent — does the enemy wait at the LADDER tile or attempt horizontal movement first? | Resolve during AI-03: horizontal tie-breaking rule covers most cases; document edge case and accepted behaviour |
| Enemy AI GDD | OQ-04 | EC-03 — when a hole closes while the enemy is TRAPPED, should `enemy_escaped(id)` be suppressed entirely or emitted before `enemy_died(id)` for audio/VFX hookup? | Resolve during AI-04: current spec suppresses it; confirm with Creative Director if audio feedback is needed at MVP |

---

## File Paths

```
src/gameplay/enemy/enemy_config.gd          # EnemyConfig Resource class
src/gameplay/enemy/enemy_controller.gd      # EnemyController Node2D
resources/configs/enemy_config.tres         # Runtime config resource
resources/configs/dig_config.tres           # DIG-02 stretch carryover
tests/unit/test_enemy_controller.gd         # Unit tests for all 12 ACs
scenes/levels/level_test.tscn               # Extended in AI-05 stretch
```

---

## Handoff Notes for Sprint 4 (Level System)

When Sprint 3 closes, the following contracts must be stable (no breaking changes
without an ADR) for Sprint 4 to build on:

- `EnemyController.setup(grid, terrain, gravity, player_movement)` — Level System calls this during level init
- `EnemyController.spawn(spawn_cell: Vector2i, rescate_cell: Vector2i)` — Level System injects spawn positions from `LevelData` resource
- `EnemyController.reset()` — Level System calls this on every level restart
- `EnemyController.enemy_reached_player(enemy_id: int, cell: Vector2i)` — Level System subscribes to trigger player death + restart
- `EnemyConfig` resource — Level System may override per-level enemy config (e.g., faster guards on later levels)

**Sprint 4 focus**: Level System (init, win/lose conditions, level sequence, restart) + Levels 1–5.
The Level System will be the first consumer of `EnemyController.spawn()` with real per-level
spawn data replacing the hardcoded `Vector2i(8,6)` used in Sprint 3 integration testing.

---

## Milestone Reference

See [`production/milestones/mvp.md`](../milestones/mvp.md) for full MVP scope and
target date (2026-05-31).

---

*Document owner: Producer | Last updated: 2026-04-20*
