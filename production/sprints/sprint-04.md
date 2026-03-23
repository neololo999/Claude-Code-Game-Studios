# Sprint 4 — 2026-05-04 to 2026-05-17

> **Status**: Planning
> **Created**: 2026-05-04
> **Owner**: Producer
> **Sprint Number**: 4 of ~5 (MVP)

---

## Sprint Goal

Implement the Level System — the final orchestrating system of the MVP core loop —
and author the first five playable levels as `LevelData` Resources.

After this sprint, a player can launch `level_01.tscn`, die and restart instantly,
collect all pickups, reach the exit, and advance to the next level — across Levels
1–5 — with full guard AI active throughout.

This sprint transforms the collection of isolated systems (Grid, Terrain, Gravity,
Player, Enemy, Pickup, Dig) into a **single playable product slice**. LVL-02 is the
critical-path bottleneck; all five .tres files in LVL-03 depend on the `LevelData`
schema being locked by end of Day 1 (LVL-01).

---

## Capacity

| Metric | Value |
|--------|-------|
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |

> Buffer is pre-allocated to LVL-04 (scene wiring) and LVL-05 (unit tests) as
> stretch/should-have goals. Do not schedule into it intentionally.

---

## Sprint 3 Retrospective Summary

| Item | Result |
|------|--------|
| AI-01 — EnemyConfig Resource | ✅ Done |
| AI-02 — EnemyController PATROL + Gravity | ✅ Done |
| AI-03 — CHASE state + player detection | ✅ Done |
| AI-04 — TRAPPED + DEAD + respawn cycle | ✅ Done |
| AI-05 — INT-02: Enemy in level_test.tscn (stretch) | ✅ Done |
| DIG-02 — DigConfig Resource (carryover stretch) | ✅ Done |

**Velocity**: 6.0/5.0 effective days delivered (120%). All Must Have, Should Have,
and all stretch goals complete — first 100% stretch-inclusive sprint. Enemy AI is
fully integrated into `level_test.tscn` via `LevelBootstrap`. Sprint 3 contracts
(`EnemyController.setup()`, `spawn()`, `reset()`, `enemy_reached_player`) are stable
API for Sprint 4 to consume.

> **Note**: Sprint 3 completing all stretch goals means Sprint 4 inherits zero
> carryover and can focus entirely on Level System + level authoring.

---

## Carryover from Sprint 3

*None.* All Sprint 3 tasks (including stretch) completed within sprint.

---

## Dependency Graph (Sprint 4)

```
[Sprint 3 — All systems ✅]
  GridSystem · TerrainSystem · GridGravity · PlayerMovement
  DigSystem · PickupSystem · EnemyController · LevelBootstrap
                         │
           ┌─────────────┤
           ▼             │
     [LVL-01:            │
      LevelData          │
      Resource (0.5d)]   │
           │             │
     ┌─────┴──────┐      │
     ▼            ▼      │
[LVL-02:     [LVL-03:    │
 LevelSystem  5 × .tres  │
 Node (2d)]   files (2d)]│
     │             │     │
     └──────┬──────┘     │
            ▼            │
     [LVL-04:            │  ◄── Should Have
      level_01.tscn      │
      wiring (0.5d)]     │
            │            │
            └────────────┘
                  ▼  (stretch, if buffer intact)
     [LVL-05: Unit tests for LevelSystem (ACs 01–10)]
```

> **LVL-01 is the sprint's critical gate**: both LVL-02 and LVL-03 depend on the
> `LevelData` schema being locked before they can proceed. LVL-01 must be 100% done
> by end of Day 1 morning. LVL-02 and LVL-03 can proceed in parallel once schema
> is locked (solo dev: sequential, but estimates are independent).

---

## Tasks

### Must Have — Critical Path (4.5 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| LVL-01 | **`LevelData` Resource** — `class_name LevelData extends Resource`; `@export var grid_width: int`; `@export var grid_height: int`; **`@export var terrain_map: PackedInt32Array`** (flat row-major, index = `row * grid_width + col` — `Array[Array]` is NOT supported in Godot 4 typed exports; same flat pattern as GridSystem); `@export var player_spawn: Vector2i`; `@export var enemy_spawns: Array[Vector2i]`; `@export var enemy_rescate_positions: Array[Vector2i]`; `@export var pickup_cells: Array[Vector2i]`; `@export var exit_cell: Vector2i`; `@export var level_name: String`; `@export var level_index: int`; save script at `src/gameplay/level/level_data.gd` | `godot-gdscript-specialist` | 0.5 | Sprint 3 systems stable | ① Script saved at `src/gameplay/level/level_data.gd`, class_name `LevelData extends Resource` ② All 10 `@export` fields are visible and editable in the Godot Inspector when a `.tres` is opened ③ `terrain_map` is `PackedInt32Array` (not `Array[Array]`); index formula `row * grid_width + col` is documented in an inline `##` comment ④ Creating a blank `LevelData.new()` and assigning all fields produces no Godot warnings or type errors ⑤ `enemy_spawns` and `enemy_rescate_positions` are parallel arrays (same index = same guard); comment documents this constraint |
| LVL-02 | **`LevelSystem` Node** — `class_name LevelSystem extends Node`; state machine `enum State { IDLE, LOADING, RUNNING, DYING, RESTARTING, VICTORY, TRANSITIONING }`; `const DEATH_FREEZE_TIME: float = 0.5`; `const VICTORY_HOLD_TIME: float = 1.5`; `@export` references for all 7 sub-systems (grid, terrain, gravity, player, enemy, pickups, input); `load_level(level_id: String) → void` — loads `.tres` from `res://resources/levels/{level_id}.tres`, runs init sequence: Grid→Terrain→Gravity→Player→Enemy→Pickup→Input (in that order, AC-10); `restart() → void` — disables input, resets all systems in reverse, re-inits with cached LevelData, re-enables input; emits `player_died` signal before entering DYING state; DYING: accumulates delta for DEATH_FREEZE_TIME then auto-restarts (no player input needed); VICTORY: accumulates delta for VICTORY_HOLD_TIME then calls `load_level(current_level + 1)` or goes IDLE on last level; EC-07: key R in RUNNING triggers `restart()`; **Input gating via `input.set_process_unhandled_input(false)` + `input.set_process(false)`** (InputSystem has no `enable()/disable()` — see S4-R03); `var death_count: int` incremented on each death, reset on `load_level()`; expose `current_level_index: int`, `level_name: String`, `level_state: State` as read-only properties; signals: `player_died`, `level_victory`, `level_started(level_index: int)` | `godot-gdscript-specialist` | 2.0 | LVL-01 | ① `load_level("level_001")` → all 7 sub-systems init in correct order (Grid→Terrain→Gravity→Player→Enemy→Pickup→Input), state = RUNNING (AC-01, AC-10) ② `enemy_reached_player` received → `player_died` emitted, state = DYING within same frame (AC-02) ③ DEATH_FREEZE_TIME (0.5 s) elapses → `restart()` called automatically, all sub-systems reset + re-init, player at spawn, enemies at spawns, all pickups restored, state = RUNNING (AC-03) ④ `player_reached_exit` received → state = VICTORY, `level_victory` emitted (AC-04) ⑤ VICTORY_HOLD_TIME (1.5 s) elapses → `load_level(current + 1)` called (AC-05) ⑥ Last level completed → state = IDLE, `print("[LEVEL] Game complete!")` (AC-06) ⑦ `enemy_reached_player` and `player_reached_exit` arrive same frame → DYING triggered, VICTORY suppressed; `player_reached_exit` ignored while state ≠ RUNNING (AC-07, EC-02) ⑧ Key R in RUNNING → `restart()` triggered, identical behaviour to death restart without death_count increment (AC-08) ⑨ `death_count` increments on each death (AC-02 path), resets to 0 on `load_level()` call (AC-09) ⑩ Input disabled (`set_process_unhandled_input(false)` + `set_process(false)`) during DYING/RESTARTING/LOADING/TRANSITIONING; re-enabled when state enters RUNNING (S4-R03 mitigation) |
| LVL-03 | **5 × `LevelData` .tres files** — `resources/levels/level_001.tres` through `level_005.tres`; each file must open in Godot editor without errors; `level_index` must match file number (1-based); all terrain maps encoded as flat `PackedInt32Array` using `TileType` enum int values from `TerrainSystem`; enemy, pickup, exit, and spawn positions must be valid (within grid bounds); designer must play-complete each level before committing. **Level specs:** ① `level_001` — 10×8, 1 guard (patrol only), 3 pickups, no DIRT_FAST, tutorial-simple: SOLID floor row 7, small DIRT_SLOW platforms, single LADDER shaft, guard starts far side from player. ② `level_002` — 10×8, 1 guard, 4 pickups, introduces DIRT_FAST alongside DIRT_SLOW (player must distinguish timings). ③ `level_003` — 12×8, 2 guards (different patrol ranges), 4 pickups, LADDER traversal required to collect all pickups; guards start on separate platforms. ④ `level_004` — 12×8, 2 guards, 5 pickups, ROPE traversal required; one pickup reachable only via ROPE; guard patrols below ROPE. ⑤ `level_005` — 14×8, 2 guards, 5 pickups, multi-platform puzzle: two SOLID platforms at different heights, LADDER + ROPE both required, one guard on each platform | `godot-gdscript-specialist` | 2.0 | LVL-01 | ① All 5 `.tres` files committed to `resources/levels/` and open in Godot editor without errors ② `level_index` matches file number (level_001.tres → level_index = 1, etc.) ③ Each `terrain_map` is a `PackedInt32Array` of size `grid_width × grid_height`; all indices are valid `TileType` enum values ④ All spawn positions (player, enemies, rescate) and pickup/exit positions are within grid bounds ⑤ Each level is designer-completable: player can collect all pickups and reach exit without softlock ⑥ Level 1 uses only SOLID + DIRT_SLOW terrain types (no DIRT_FAST, no ROPE) ⑦ Level 2 contains at least one DIRT_FAST cell reachable by the player ⑧ Level 3 contains at least one LADDER cell required to reach a pickup ⑨ Level 4 contains at least one ROPE cell required to reach a pickup ⑩ Level 5 requires both LADDER and ROPE to complete |

**Must Have subtotal: 4.5 days**

---

### Should Have (0.5 day — first fully playable MVP scene)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| LVL-04 | **Wire `LevelSystem` into `scenes/levels/level_01.tscn`** — Replace `LevelBootstrap` as the scene root coordinator; add `LevelSystem` node to scene; wire all 7 `@export` node references in the Inspector; call `level_system.load_level("level_001")` from `_ready()`; connect `level_system.player_died` → `print("[LEVEL] Player died — death #%d" % death_count)`; connect `level_system.level_victory` → `print("[LEVEL] Victory!")` and `level_system.level_started` → `print("[LEVEL] Level %d started" % level_index)`; **LevelBootstrap remains in the scene tree as a deactivated reference** (do not delete — it is the existing smoke-test harness; set `LevelBootstrap.process_mode = PROCESS_MODE_DISABLED`) | `godot-gdscript-specialist` | 0.5 | LVL-01, LVL-02, LVL-03 | ① `scenes/levels/level_01.tscn` opens in Godot editor without errors ② Scene plays (F5 or Run Scene) with no `push_error` in console ③ `[LEVEL] Level 1 started` prints on scene launch ④ Player dies (guard reaches player) → `[LEVEL] Player died — death #1` prints, level restarts within 0.5 s ⑤ All 3 pickups collected + exit reached → `[LEVEL] Victory!` prints; scene transitions to level_002 load (or prints level 2 started) ⑥ `LevelBootstrap` node remains in scene with `process_mode = PROCESS_MODE_DISABLED` (not deleted) ⑦ No duplicate signal connections from LevelBootstrap (process_mode disabled prevents double-firing) |

**Should Have subtotal: 0.5 day — total effective capacity used: 5.0 days**

---

### Stretch Goals — Buffer Day (requires LVL-01 through LVL-04 complete within 5 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| LVL-05 | **Unit tests for `LevelSystem` (ACs 01–10)** — `tests/unit/test_level_system.gd`; mock sub-system nodes (minimal stub classes that expose required API); test each of the 10 AC scenarios in isolation: load_level init order, DYING trigger + freeze timer, restart sub-system reset, VICTORY trigger, level advance, game-complete (last level), death-priority-over-victory same frame, manual restart (R key), death_count tracking, init sequence order enforcement | `godot-gdscript-specialist` | 0.5 | LVL-01, LVL-02 | ① Test file at `tests/unit/test_level_system.gd` runs with no failures ② Tests for ACs 01–10 are individually identifiable (named test functions matching AC ID) ③ Each test is isolated — no shared mutable state between test cases ④ All tests pass without `push_error` or unhandled exceptions ⑤ Test file uses stub/mock sub-systems (not real scene nodes) so tests run headless |

**Stretch subtotal: 0.5 day (= buffer)**

---

## Critical Path

```
LVL-01 (0.5d) ──┬──► LVL-02 (2d) ──► LVL-04 (0.5d)
                 │         ↑
                 │    ⚠️ BOTTLENECK
                 └──► LVL-03 (2d)
```

> ⚠️ **LVL-01 is the sprint gate** — it takes only 0.5 days but its output (the
> `LevelData` schema) unblocks both LVL-02 and LVL-03. It must be 100% done and
> committed before Day 1 ends. Any schema ambiguity discovered here (e.g., how
> `terrain_map` encodes multi-layer terrain) must be resolved before LVL-03 starts
> authoring `.tres` files.
>
> ⚠️ **LVL-02 is the sprint bottleneck** at 2 days and gates LVL-04. The state
> machine scaffold (IDLE/LOADING/RUNNING) must be functional by end of Day 2 so
> that LVL-03 `.tres` files can be smoke-tested against it.
>
> **Day 3 checkpoint**: LVL-02 must be ≥ 80% done. load_level() + RUNNING state
> functional. DYING/RESTARTING cycle in progress. If behind, drop LVL-05 entirely
> and consider simplifying LVL-04 to a console-only wiring (no scene file) to
> protect LVL-03 delivery.
>
> **LVL-03 priority**: 5 playable levels are the most player-visible Sprint 4
> deliverable. If time compresses, simplify level layouts (fewer platforms, smaller
> grids) before reducing the level count below 5.

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| S4-R01 | **`Array[Array]` not supported in Godot 4 typed `@export`** — The Level System GDD specifies `terrain_map: Array[Array]` but Godot 4 does not support nested typed arrays as `@export` fields. Using it would cause Inspector errors and `.tres` serialization failures. | High | High | `godot-gdscript-specialist` | **Resolved by design**: LVL-01 spec mandates `PackedInt32Array` flat row-major layout (index = `row * grid_width + col`). This is identical to the pattern used in `GridSystem` and `LevelBootstrap._initialize_level()`. No runtime performance penalty; designer authors rows conceptually. Document formula in `level_data.gd` inline comment. |
| S4-R02 | **5 levels in 2 days is tight** — Authoring 5 well-formed `.tres` files with correct flat terrain maps, valid spawns, and designer-verified completability is tedious, especially for 12×8 and 14×8 grids. A single miscalculated index silently places a tile in the wrong row. | Medium | High | `godot-gdscript-specialist` | Keep levels 1–5 simple: 1–2 guards, basic platform layouts, no exotic terrain combos beyond what each level's spec requires. Author a helper script or GDScript snippet that prints a visual ASCII grid from a `PackedInt32Array` to visually verify maps before saving `.tres`. If Day 4 falls behind, reduce level 5 to 12×8 (not 14×8) — the spec allows simplification. |
| S4-R03 | **`InputSystem` has no `enable()/disable()` method** — The Level System GDD specifies `InputSystem.enable()` / `InputSystem.disable()` in the init and restart lifecycle. The implemented `InputSystem` (Sprint 0) has no such methods; only the comment `set_process_unhandled_input(false)` is mentioned. Calling non-existent methods will crash at runtime. | High | High | `godot-gdscript-specialist` | **Resolved by design**: LVL-02 spec mandates using `input.set_process_unhandled_input(false)` + `input.set_process(false)` (disable) and the reverse (enable) directly on the InputSystem node reference. No changes to InputSystem.gd required. Document this deviation from the GDD in a `## NOTE` comment in `level_system.gd`. Do NOT add `enable()/disable()` to InputSystem without an ADR — that is a Sprint 5+ concern. |
| S4-R04 | **DYING/RESTARTING sub-system reset order** — Calling `reset()` on systems in the wrong order during restart may leave stale state (e.g., PickupSystem reset before EnemyController reset could cause a signal to fire on a reset pickup). | Low | Medium | `godot-gdscript-specialist` | GDD specifies reverse-init order for reset: Input → Enemy → Pickup → Player → Gravity → Terrain → Grid. Enforce this order in code with step comments matching sprint-03.md's style. If a reset order bug is found, the fix is a one-line reorder — not a design change. |

---

## Definition of Done for Sprint 4

All Must Have tasks require ALL acceptance criteria passing before the sprint is
closed. Partial completion of a task does not count toward velocity.

### Must Have (non-negotiable)
- [ ] `LevelData` Resource: all 10 `@export` fields present; `terrain_map` is `PackedInt32Array`; no Inspector warnings
- [ ] `LevelSystem` state machine: all 7 states reachable; `load_level()` and `restart()` functional; ACs 01–10 met
- [ ] `player_died`, `level_victory`, `level_started` signals emitted at correct transitions
- [ ] Input correctly disabled during DYING/RESTARTING/LOADING/TRANSITIONING; re-enabled on RUNNING
- [ ] 5 × `LevelData` .tres files committed to `resources/levels/`; each opens in Godot editor without errors
- [ ] Each level is designer-completable (all pickups reachable, exit reachable, no softlock)
- [ ] No `push_error` or unhandled exceptions during `load_level()`, `restart()`, or normal gameplay

### Should Have
- [ ] `scenes/levels/level_01.tscn` plays end-to-end (spawn → play → die → restart → win → level 2 loads) *(if LVL-04 complete)*
- [ ] `LevelBootstrap` node disabled (not deleted) in the updated scene

### Quality Gates
- [ ] All public API (`load_level`, `restart`, `player_died`, `level_victory`, `level_started`, all read-only properties) have GDScript `## doc comments`
- [ ] Code follows project conventions: `snake_case` variables, `PascalCase` classes, `UPPER_SNAKE` constants
- [ ] `LevelData` schema deviation from GDD (`PackedInt32Array` vs `Array[Array]`) documented with `## NOTE` inline comment and in Sprint 4 handoff notes
- [ ] Unit tests pass for LevelSystem ACs 01–10 in `tests/unit/test_level_system.gd` *(if LVL-05 stretch complete)*

---

## Sprint Schedule (indicative)

| Day | Date | Focus |
|-----|------|-------|
| Day 1 | Mon 2026-05-04 | LVL-01 complete by noon (0.5d) — schema locked, `.gd` committed → LVL-02 start: state enum scaffold + IDLE/LOADING/RUNNING + `load_level()` init sequence (half day) |
| Day 2 | Tue 2026-05-05 | LVL-02 continued: DYING state + `DEATH_FREEZE_TIME` accumulation + `restart()` sub-system reset in reverse order + `player_died` signal |
| Day 3 | Thu 2026-05-07 | LVL-02 complete: VICTORY + `VICTORY_HOLD_TIME` + TRANSITIONING + level sequence + EC-07 (R key restart) + death_count + all signals *(Day 3 checkpoint: LVL-02 ≥ 80%)* |
| Day 4 | Mon 2026-05-11 | LVL-03: levels 001–003 authored + ASCII-grid verified + smoke-tested against LevelSystem |
| Day 5 | Tue 2026-05-12 | LVL-03 complete: levels 004–005 authored + all 5 levels designer-play-verified |
| Day 6 | Thu 2026-05-14 | Buffer: LVL-04 (scene wiring, 0.5d) + LVL-05 (unit tests, 0.5d stretch) if time permits |

> Sprint review: **Sun 2026-05-17** — demo: launch level_01.tscn → play → die →
> restart → collect all pickups → exit → level 2 loads. Retrospective follows.

---

## Open Questions

| GDD | OQ ID | Question | Resolution Deadline |
|-----|-------|----------|---------------------|
| Level System GDD | OQ-01 | **Level sequence format** — Scan `res://resources/levels/` alphabetically, or use an explicit `level_sequence.tres`? *Recommendation: alphabetical scan for MVP (zero extra authoring); explicit sequence file for post-MVP.* | Resolve Day 1 before LVL-02 starts — affects `load_level()` implementation |
| Level System GDD | OQ-02 | **Restart input** — Key R for manual restart: should it be handled by `InputSystem` (new action `restart_level`) or directly in `LevelSystem._unhandled_input()`? *Recommendation: `LevelSystem._unhandled_input()` — avoids InputMap changes and keeps restart logic co-located with state machine.* | Resolve during LVL-02 (Day 2–3) |

---

## File Paths

```
src/gameplay/level/level_data.gd            # LVL-01: LevelData Resource class
src/gameplay/level/level_system.gd          # LVL-02: LevelSystem Node (state machine)
resources/levels/level_001.tres             # LVL-03: Level 1 — 10×8, 1 guard, 3 pickups
resources/levels/level_002.tres             # LVL-03: Level 2 — 10×8, 1 guard, 4 pickups, DIRT_FAST
resources/levels/level_003.tres             # LVL-03: Level 3 — 12×8, 2 guards, 4 pickups, LADDER
resources/levels/level_004.tres             # LVL-03: Level 4 — 12×8, 2 guards, 5 pickups, ROPE
resources/levels/level_005.tres             # LVL-03: Level 5 — 14×8, 2 guards, 5 pickups, puzzle
scenes/levels/level_01.tscn                 # LVL-04: Full scene wiring (LevelSystem replaces LevelBootstrap)
tests/unit/test_level_system.gd             # LVL-05: Unit tests, ACs 01–10 (stretch)
```

---

## Level Layout Reference (for LVL-03)

| Level | Grid | Guards | Pickups | New Mechanic | Notes |
|-------|------|--------|---------|--------------|-------|
| 001 | 10×8 | 1 | 3 | — | Tutorial-simple; SOLID + DIRT_SLOW only; guard starts far side |
| 002 | 10×8 | 1 | 4 | DIRT_FAST | Player must distinguish DIG_CLOSE_SLOW vs DIG_CLOSE_FAST timings |
| 003 | 12×8 | 2 | 4 | LADDER | At least one pickup only reachable via vertical LADDER climb |
| 004 | 12×8 | 2 | 5 | ROPE | At least one pickup only reachable via horizontal ROPE traverse |
| 005 | 14×8 | 2 | 5 | LADDER + ROPE | Multi-platform puzzle; one guard per platform; both mechanics required |

> Levels 1–5 should be completable by a first-time player within 3 attempts each
> (per MVP validation criteria). Prefer simple, readable layouts over clever traps.
> Pillar check: **Montée en complexité maîtrisée** — each level introduces exactly
> one new combination or constraint above the previous.

---

## Handoff Notes for Sprint 5 (Levels 6–10 + Integration Pass)

When Sprint 4 closes, the following contracts must be stable (no breaking changes
without an ADR) for Sprint 5 to build on:

- `LevelData` schema — all 10 `@export` fields; `terrain_map` as `PackedInt32Array`
- `LevelSystem.load_level(level_id: String)` — Sprint 5 will call this for levels 6–10
- `LevelSystem.restart()` — Sprint 5 integration testing calls this exhaustively
- `LevelSystem.player_died`, `level_victory`, `level_started` signals — stable signal API
- `resources/levels/level_001.tres` through `level_005.tres` — Sprint 5 will author 006–010 in the same format

**Sprint 5 focus**: Levels 6–10 + full integration pass (all 10 levels end-to-end playthrough)
+ bug fixes + MVP sign-off playtest. Sprint 5 is the final MVP sprint — zero scope additions.

---

## Milestone Reference

See [`production/milestones/mvp.md`](../milestones/mvp.md) for full MVP scope and
target date (2026-05-31).

---

*Document owner: Producer | Last updated: 2026-05-04*
