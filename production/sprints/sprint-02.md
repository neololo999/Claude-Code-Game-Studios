# Sprint 2 — 2026-04-06 to 2026-04-19

> **Status**: Planning
> **Created**: 2026-04-06
> **Owner**: Producer
> **Sprint Number**: 2 of ~5 (MVP)

---

## Sprint Goal

Implement the Dig System and Pickup System to complete the player's full action
set — and verify the partial core loop end-to-end in a wired integration scene.
After this sprint, a player can move, dig holes, and collect treasures, enabling
the first partial loop smoke test before Enemy AI arrives in Sprint 3.

---

## Capacity

| Metric | Value |
|--------|-------|
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +0.5 day |

> Buffer exists for unplanned debugging, signal-timing edge cases, and Godot
> scene-wiring friction. Do not schedule into it intentionally.

---

## Dependency Graph (Sprint 2)

```
[Sprint 1 — All Complete ✅]
  GridSystem · TerrainSystem · GridGravity · PlayerMovement · InputSystem
                         │
          ┌──────────────┼─────────────────┐
          ▼              ▼                 ▼
    [DIG-01:         [PICK-01:       (depends on
     DigSystem]       PickupSystem]   DIG-01+PICK-01)
          │              │                 │
          └──────────────┘                 │
                         ▼                 │
                   [INT-01: Integration    │
                    smoke-test scene] ◄────┘
                         │
                         ▼ (stretch, if buffer intact)
                   [DIG-02: DigConfig
                    Resource]
```

> DIG-01 and PICK-01 are **independent** and can be developed in parallel.
> INT-01 depends on both; it is the sprint integration gate.

---

## Tasks

### Must Have — Critical Path (4.5 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| DIG-01 | **DigSystem implementation** — `class_name DigSystem`, listens to `InputSystem.dig_requested(direction: Vector2i)`, computes target cell (`current_cell ± Vector2i(1,0)`), validates dig conditions (player state IDLE/MOVING/LADDER + `is_grounded` + `is_destructible` + no active cooldown), calls `GridGravity.notify_digging(entity_id, true)` BEFORE `TerrainSystem.dig_request(col, row)`, resets immunity flag with `notify_digging(id, false)` after `DIG_DURATION` (0.5 s) via `SceneTreeTimer`, emits `dig_performed(col: int, row: int)` signal, enforces cooldown so a second `dig_requested` within DIG_DURATION is silently rejected, unit tests in `tests/unit/test_dig_system.gd` | `godot-gdscript-specialist` | 2.5 | Sprint 1 systems stable | ① `dig_requested(left)` while grounded + IDLE → calls `TerrainSystem.dig_request(col-1, row)` on destructible cell ② `dig_requested` while player NOT grounded → rejected ③ `dig_requested` while player in FALLING state → rejected ④ `dig_requested` on non-destructible cell (SOLID) → rejected silently ⑤ Cooldown: second `dig_requested` within DIG_DURATION → rejected ⑥ `GridGravity.notify_digging(id, true)` called BEFORE `dig_request()`; `(id, false)` called after DIG_DURATION ⑦ `dig_performed(col, row)` signal emitted on every valid dig ⑧ Digging from LADDER state allowed (player state = LADDER counts as valid) ⑨ Unit tests for all 8 ACs pass in `tests/unit/test_dig_system.gd` |
| PICK-01 | **PickupSystem implementation** — `class_name PickupSystem`, `setup(p_grid, p_terrain, p_player_movement)` dependency injection, `initialize(treasure_cells: Array[Vector2i])` registers positions into internal dict, subscribes to `PlayerMovement.player_moved(from, to)` — on `to` cell match: removes from active set, emits `pickup_collected(cell, remaining)`, emits `all_treasures_collected()` when remaining = 0, `get_remaining_count() → int`, `reset()` restores full initial set, unit tests in `tests/unit/test_pickup_system.gd` | `godot-gdscript-specialist` | 1.0 | Sprint 1 systems stable (PlayerMovement.player_moved signal) | ① `initialize([Vector2i(1,2), Vector2i(3,4)])` → `get_remaining_count()` = 2 ② Player moves to treasure cell → `pickup_collected` emitted, remaining count decremented by 1 ③ Player moves to non-treasure cell → no signal emitted ④ Collecting last treasure → `all_treasures_collected` emitted immediately after `pickup_collected` in same frame ⑤ `reset()` restores all treasures; `get_remaining_count()` returns initial count ⑥ Unit tests for all 5 ACs pass in `tests/unit/test_pickup_system.gd` |
| INT-01 | **Integration smoke-test scene** — Create `scenes/levels/level_test.tscn` with a 10×8 grid, all 7 systems wired via a `LevelBootstrap` autoload script (setup order: Grid → Terrain → Gravity → Player → Dig → Pickup); terrain layout includes SOLID floor at row 7, DIRT_SLOW tiles, a LADDER column, and 3 treasure pickups; player spawns at (1,1); `LevelBootstrap._ready()` prints wiring confirmation; `PickupSystem` signals connected to console print handlers; scene is the default debug scene for Sprint 2 | `godot-specialist` | 1.0 | DIG-01, PICK-01 | ① Scene opens and runs in Godot 4.6.1 with zero console errors ② Player moves left/right with arrow keys / WASD ③ Player digs with Z/X keys — hole opens, closes on timer; console prints dig event ④ Player collects treasure by walking over it — console prints `[PICKUP] Collected! Remaining: X` ⑤ All 3 treasures collected → console prints `[ALL COLLECTED]` |

**Must Have subtotal: 4.5 days**

---

### Should Have — Stretch Goal (requires buffer intact: +0.5 day)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| DIG-02 | **DigSystem config Resource** — Create `resources/configs/dig_config.tres` (`class_name DigConfig extends Resource`) exposing `DIG_DURATION: float = 0.5` and `DIG_COOLDOWN: float = 0.5` as exported properties; update `DigSystem` to load from `DigConfig` rather than inline constants; ensures DigSystem and TerrainConfig share a single source of truth for dig timing; config must save/load in Godot editor without errors | `godot-gdscript-specialist` | 0.5 | DIG-01 | ① `dig_config.tres` commits to `resources/configs/` and opens in Godot editor ② Changing `DIG_DURATION` in the `.tres` and reloading the scene reflects the new cooldown in DigSystem behaviour ③ DigSystem references `DigConfig` via `@export var config: DigConfig` — no hardcoded timing constants remain in DigSystem |

**Should Have subtotal: 0.5 days** *(requires buffer not used on Must Have)*

---

## Critical Path

```
DIG-01 (2.5d) ─────────────────────────────┐
                                            ▼
                                      INT-01 (1d)  → Sprint 2 Done
                                            ▲
PICK-01 (1d) ───────────────────────────────┘
```

> ⚠️ **DIG-01 is the sprint bottleneck** at 2.5 days. It drives the INT-01
> gate and exercises the most cross-system surface area (Input → Dig → Terrain →
> Gravity). Flag DIG-01 progress at end of Day 2. If not ≥ 60% done, drop DIG-02
> from scope and protect the INT-01 buffer day.

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| S2-R01 | **Dig immunity timing edge case** — `notify_digging(id, true/false)` timing relative to TerrainSystem state transitions may cause player to fall mid-dig if the immunity flag is set after `dig_request()` rather than before | Medium | High | `godot-gdscript-specialist` | DIG-01 AC-06 explicitly mandates that `notify_digging(id, true)` is called BEFORE `TerrainSystem.dig_request()`. Test with a `print` log confirming call order. Add a GDScript `assert` in DigSystem to catch accidental reordering. |
| S2-R02 | **Integration wiring complexity** — INT-01 requires manually wiring 7 systems in a scene; a missing signal connection or wrong target causes silent bugs that are hard to trace | Medium | Medium | `godot-specialist` | Use a dedicated `LevelBootstrap` script that wires all systems in `_ready()` and prints each wiring step to console. Enforce the documented setup order: Grid → Terrain → Gravity → Player → Dig → Pickup. Treat missing console lines as a wiring bug. |
| S2-R03 | **TerrainSystem.dig_request caller order** — DigSystem calls `terrain.dig_request()` but TerrainSystem also depends on `GridSystem.cell_changed`. If GridSystem is not fully wired before the first dig, `cell_changed` may not propagate | Low | Medium | `godot-specialist` | `LevelBootstrap` enforces Grid setup as step 1, before any other system. Document setup order constraint in a `## Setup Order` comment block at the top of `LevelBootstrap`. |
| S2-R04 | **PickupSystem same-frame double signal** — Emitting `pickup_collected` and `all_treasures_collected` in the same `_on_player_moved` call may cause listeners to process a stale `get_remaining_count()` value | Low | Low | `godot-gdscript-specialist` | Emit `pickup_collected` first, then decrement, then check for zero and emit `all_treasures_collected`. Verify order in PICK-01 AC-04 unit test. |

---

## Definition of Done for Sprint 2

All Must Have tasks require ALL acceptance criteria passing before the sprint is
closed. Partial completion of a task does not count.

### Action Layer (non-negotiable)
- [ ] `DigSystem`: all 9 ACs pass; unit tests green in `tests/unit/test_dig_system.gd`
- [ ] `PickupSystem`: all 6 ACs pass; unit tests green in `tests/unit/test_pickup_system.gd`
- [ ] `scenes/levels/level_test.tscn`: all 5 ACs pass; scene runs without errors in Godot 4.6.1

### Integration Gate
- [ ] Player can move, dig, and collect in a single session in `level_test.tscn` with no errors
- [ ] `[ALL COLLECTED]` prints to console after the third treasure is collected
- [ ] No residual dig-state or pickup-state when scene is reloaded (reset paths exercised)

### Quality Gates
- [ ] No `push_error` or unhandled exceptions across all three tasks during INT-01 smoke test
- [ ] All public API functions have GDScript `## doc comments`
- [ ] `DigConfig.tres` committed under `resources/configs/` *(if DIG-02 is completed)*
- [ ] `LevelBootstrap.gd` has a `## Setup Order` doc block listing all 7 system wiring steps
- [ ] Code follows project naming conventions: `snake_case` variables, `PascalCase` classes

---

## Sprint Schedule (indicative)

| Day | Date | Focus |
|-----|------|-------|
| Day 1 | Mon 2026-04-06 | DIG-01 start — signal wiring + validation logic |
| Day 2 | Tue 2026-04-07 | DIG-01 continued — cooldown + immunity + signals |
| Day 3 | Thu 2026-04-09 | DIG-01 complete + unit tests → PICK-01 start *(risk checkpoint)* |
| Day 4 | Mon 2026-04-13 | PICK-01 complete + unit tests → INT-01 start |
| Day 5 | Tue 2026-04-14 | INT-01 complete — scene wired and all 5 ACs verified |
| Day 6 | Thu 2026-04-16 | Buffer / DIG-02 stretch / final QA sweep |

> Sprint review: **Sun 2026-04-19** — demo dig + pickup loop, retrospective.

---

## Open Questions Carried Into Sprint

| GDD | OQ ID | Question | Resolution Deadline |
|-----|-------|----------|---------------------|
| Dig System GDD | OQ-01 | If player digs from a LADDER tile, do they remain on the LADDER after digging? (LADDER state = dig allowed per GDD, but cell below may become traversable mid-climb) | During DIG-01 — test LADDER + dig interaction; document decision as inline comment |
| Grid Gravity GDD | OQ-02 | Player + guard simultaneous fall on the same column — cohabitation or collision? | Deferred to Sprint 3 (Enemy AI); DigSystem has no dependency on resolution |
| Integration | OQ-03 | Does `LevelBootstrap` become a persistent scene-level singleton, or should it be a script on a dedicated `Level` root node? | Resolved during INT-01 — document wiring pattern as ADR if reused in Sprint 3 |

---

## Handoff Notes for Sprint 3

When Sprint 2 closes, the following contracts must be stable (no breaking changes
without an ADR) for Sprint 3 to build on:

- `DigSystem.dig_performed(col, row)` signal — Enemy AI will subscribe to detect newly opened holes
- `DigSystem` cooldown state accessible via `is_on_cooldown() → bool` — Enemy AI needs to read dig availability
- `PickupSystem.all_treasures_collected()` signal — Level System (Sprint 4) consumes this to open the exit
- `PickupSystem.get_remaining_count() → int` — Enemy AI difficulty scaling may read this in Sprint 3+
- `scenes/levels/level_test.tscn` — Sprint 3 will extend this scene by adding an Enemy node; wiring order in `LevelBootstrap` must leave an insertion point for Enemy AI after Player in the setup chain

**Sprint 3 focus**: Enemy AI — core patrol loop (left/right patrol, wall-turn) + fall-into-hole detection
(`entity_should_fall` subscribed by EnemyAI, guard trapped for `DIG_CLOSE_SLOW` duration).
Pickup integration test from Sprint 2 becomes the base scene for Enemy AI integration testing.

---

## Milestone Reference

See [`production/milestones/mvp.md`](../milestones/mvp.md) for full MVP scope and
target date.

---

*Document owner: Producer | Last updated: 2026-04-06*
