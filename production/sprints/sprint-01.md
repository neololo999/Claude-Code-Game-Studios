# Sprint 1 — 2026-03-23 to 2026-04-05

> **Status**: Planning
> **Created**: 2026-03-23
> **Owner**: Producer
> **Sprint Number**: 1 of ~5 (MVP)

---

## Sprint Goal

Establish the runnable Godot project and implement the complete Foundation Layer
(Grid System, Terrain System, Grid Gravity) so that every subsequent system has
a stable, tested substrate to build on — and optionally get the player moving on
the grid as a stretch goal.

---

## Capacity

| Metric | Value |
|--------|-------|
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |

> Buffer exists for unplanned debugging, Godot 4.6.1 quirks, and task estimation
> error. Do not schedule into it intentionally.

---

## Dependency Graph (Sprint 1)

```
[PROJ-01: Godot Project]
        │
        ▼
[GRID-01: GridSystem]
        │
        ▼
[TERR-01: Terrain — Property Layer]
        │
        ├────────────────────┐
        ▼                    ▼
[TERR-02: Terrain —    [GRAV-01: GridGravity]
  Dig State Machine]         │
                             ▼
                       [MOVE-01: PlayerMovement
                         Horizontal ← STRETCH]
                             │
                             ▼
                       [MOVE-02: PlayerMovement
                         Vertical ← NICE TO HAVE]
```

---

## Tasks

### Must Have — Critical Path (5 days)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| PROJ-01 | **Godot project scaffolding** — Create `project.godot`, configure display (640×360 or 1280×720), set `CELL_SIZE=32` in ProjectSettings, establish canonical folder structure (`src/systems/`, `src/gameplay/`, `src/data/`, `scenes/`, `resources/`, `tests/`), move existing `input_system.gd` + `input_config.gd` to `src/systems/input/`, create `main.tscn` with empty Node root | `godot-specialist` | 0.5 | — | ① `project.godot` opens without errors in Godot 4.6.1 ② Default scene runs (black screen, no errors in console) ③ `InputSystem` node added to `main.tscn` loads without errors ④ Folder structure matches canonical layout in project README |
| GRID-01 | **GridSystem implementation** — `class_name GridSystem`, `CELL_SIZE=32` const, `cols`/`rows` properties, `initialize(cols, rows)` / `unload()` lifecycle, `get_cell(col,row)→int` / `set_cell(col,row,id)`, `grid_to_world(col,row)→Vector2`, `world_to_grid(pos)→Vector2i`, `is_valid(col,row)→bool`, `get_neighbors(col,row)→Array[Vector2i]`, `cell_changed(col,row,old_id,new_id)` signal, UNINITIALIZED guard on all accessors | `godot-gdscript-specialist` | 1.0 | PROJ-01 | ① `grid_to_world(2, 3)` with `CELL_SIZE=32` returns `Vector2(80, 112)` ② `world_to_grid(Vector2(85, 115))` returns `Vector2i(2, 3)` ③ `grid_to_world(0, 0)` returns `Vector2(16, 16)` ④ `is_valid(-1, 0)` → `false`; `is_valid(0,0)` → `true`; `is_valid(cols,0)` → `false` ⑤ `get_neighbors(0, 0)` returns exactly 2 entries; `get_neighbors(1,1)` returns exactly 4 ⑥ `set_cell(2,3,1)` emits `cell_changed(2,3,0,1)` ⑦ `get_cell` before `initialize()` returns `-1` without crash ⑧ Grid overlay invisible in gameplay scene |
| TERR-01 | **TerrainSystem — property layer** — `TerrainType` enum (`EMPTY=0, SOLID=1, DIRT_SLOW=2, DIRT_FAST=3, LADDER=4, ROPE=5`), `TerrainConfig` Resource (all tuning knobs: `DIG_DURATION=0.5`, `DIG_CLOSE_SLOW=8.0`, `DIG_CLOSE_FAST=4.0`, `CLOSING_DURATION=1.0`), `initialize(level_data)` populates grid from 2D int array, `is_traversable(col,row)→bool`, `is_solid(col,row)→bool`, `is_climbable(col,row)→bool`, `is_destructible(col,row)→bool`, `get_tile_type(col,row)→TerrainType`, unknown-ID fallback to EMPTY with warning | `godot-gdscript-specialist` | 1.0 | GRID-01 | ① `is_traversable` → `true` for EMPTY, LADDER, ROPE; `false` for SOLID, DIRT_SLOW, DIRT_FAST (intact) ② `is_solid` → `true` for SOLID, DIRT_SLOW, DIRT_FAST, LADDER; `false` for EMPTY, ROPE ③ `is_climbable` → `true` **only** for LADDER and ROPE ④ `is_destructible` → `true` only for DIRT_SLOW and DIRT_FAST ⑤ `initialize()` with ID `99` substitutes EMPTY and prints a warning; no crash ⑥ `TerrainConfig.tres` saves/loads in Godot editor without errors ⑦ Out-of-bounds query returns SOLID (safe default per GDD OQ-03) |
| TERR-02 | **TerrainSystem — dig state machine** — `DigState` enum (`INTACT, DIGGING, OPEN, CLOSING`), per-cell state dictionary, `dig_request(col,row)` validates destructibility + current state, drives `INTACT→DIGGING→OPEN→CLOSING→INTACT` via `SceneTreeTimer`, `get_dig_state(col,row)→DigState`, `get_dig_timer_remaining(col,row)→float`, `dig_state_changed(col,row,old_state,new_state)` signal, `cell_occupied` callback hook (resolved in GRAV-01), `reset()` cancels all active timers + resets all cells to INTACT | `godot-gdscript-specialist` | 1.5 | TERR-01 | ① `dig_request` on DIRT_SLOW → cell transitions INTACT→DIGGING after 0.5 s, DIGGING→OPEN after `DIG_DURATION` ② Cell returns to INTACT after `DIG_CLOSE_SLOW` + `CLOSING_DURATION` seconds ③ DIRT_FAST closes before DIRT_SLOW when both dug simultaneously ④ `dig_request` on SOLID → rejected, cell stays INTACT ⑤ `dig_request` on already-OPEN cell → silently rejected ⑥ `reset()` called with 3 active dig timers → all timers cancelled, all cells back to INTACT, no residual signals ⑦ `dig_state_changed` signal fires on every state transition with correct `(col, row, old, new)` params ⑧ `is_traversable` returns `true` for a cell in OPEN state |
| GRAV-01 | **GridGravity implementation** — `register_entity(id,col,row)`, `unregister_entity(id)`, `update_entity_position(id,col,row)`, `is_grounded(col,row)→bool` (checks `is_solid(col,row+1)` OR `is_climbable(col,row)`; row=rows-1 treated as grounded), entity registry dict `cell→[ids]`, subscribe to `GridSystem.cell_changed` → emit `entity_should_fall(entity_id)` when support disappears, `cell_occupied(col,row)→bool` (resolves Terrain GDD OQ-01), `entity_should_fall(entity_id)` signal, `entity_landed(entity_id)` signal, `reset()` clears registry, connects to TERR-02's `cell_occupied` hook | `godot-gdscript-specialist` | 1.0 | TERR-01, TERR-02 | ① Entity with SOLID at `row+1` → `is_grounded` = `true` ② Entity with EMPTY at `row+1`, not on LADDER/ROPE → `is_grounded` = `false` AND `entity_should_fall` emitted ③ Entity on LADDER (is_climbable=true) → `is_grounded` = `true` regardless of cell below ④ `cell_changed` on cell directly below registered entity → `entity_should_fall` emitted in same frame ⑤ `cell_occupied(col,row)` → `true` iff entity registered on that cell ⑥ `reset()` → `cell_occupied` returns `false` everywhere ⑦ Entity at `row = rows-1` → `is_grounded` = `true`, no `entity_should_fall` emitted ⑧ TERR-02 CLOSING→INTACT blocked when `cell_occupied` returns `true` on that cell |

**Must Have subtotal: 5.0 days**

---

### Should Have — Stretch Goal (requires buffer intact: +1 day)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| MOVE-01 | **PlayerMovement — core states + horizontal movement** — `PlayerMovement` node, states `IDLE/MOVING/FALLING/DEAD`, `current_cell:Vector2i`, `register_entity` with GridGravity on spawn, `can_move_horizontal(col,row,dx)` validation (is_valid + is_traversable + is_grounded OR is_climbable), execute move on `move_requested` from InputSystem, snap to `grid_to_world`, update GridGravity position, emit `player_moved(from,to)`, listen to `entity_should_fall` → transition to FALLING state (tick loop at `FALL_SPEED`), listen to `entity_landed` → back to IDLE | `gameplay-programmer` | 1.5 | GRAV-01 | ① Player starts on grid cell, snapped to `grid_to_world(spawn)` ② `move_requested(left)` on traversable + grounded cell → player moves left, `player_moved` signal emitted ③ `move_requested` toward SOLID cell → player stays, no signal ④ `move_requested(left/right)` when not grounded and not on LADDER/ROPE → blocked ⑤ `entity_should_fall` → player enters FALLING, moves down at `FALL_SPEED` per cell ⑥ `entity_landed` → player snaps to cell, enters IDLE ⑦ `move_requested(horizontal)` during FALLING → ignored |

**Should Have subtotal: 1.5 days** *(requires buffer not used on Must Have)*

---

### Nice to Have — Only if Should Have is complete and time remains

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| MOVE-02 | **PlayerMovement — vertical movement + input buffer + reset** — `can_climb_up` / `can_climb_down` validation, execute vertical moves on LADDER/ROPE, 1-slot input buffer (last-input-wins) consumed post-snap, `reset(spawn_pos)` → state IDLE + snap + re-register in GridGravity | `gameplay-programmer` | 1.0 | MOVE-01 | ① `move_requested(up)` on LADDER → player moves up one cell ② `move_requested(down)` on LADDER → player moves down one cell ③ `move_requested(up)` when not on LADDER/ROPE → ignored ④ `move_requested` during MOVING transition → buffered; executed after snap if still valid; discarded if invalid ⑤ `reset(spawn)` during FALLING → state forced to IDLE, player snapped to spawn |

**Nice to Have subtotal: 1.0 day**

---

## Critical Path

```
PROJ-01 (0.5d) → GRID-01 (1d) → TERR-01 (1d) → TERR-02 (1.5d) → GRAV-01 (1d)
                                                                         ↓
                                                                    MOVE-01 (stretch)
```

> ⚠️ **GRAV-01 is the sprint bottleneck.** It depends on TERR-02, which has the
> largest estimate (1.5d). Any slip in TERR-02 directly pushes GRAV-01 and the
> stretch goal. Flag TERR-02 progress on Day 3.

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| R-01 | **`cell_changed` signal reentrance** — A dig timer callback fires during another `cell_changed` emission, causing recursive signal dispatch in Godot 4 | Medium | High | `godot-gdscript-specialist` | Use `call_deferred` or `emit_signal.call_deferred` in all timer callbacks. Document the constraint in TERR-02 code comments. Test explicitly with two simultaneous dig operations. |
| R-02 | **TERR-02 underestimated** — The state machine + timer management proves more complex than 1.5 days (SceneTreeTimer vs custom ticker debate, blocking logic) | Medium | Medium | Producer | Check TERR-02 progress at end of Day 3. If < 50% done, drop GRAV-01 timer-blocking feature to unblock GRAV-01 and cut MOVE-01 from scope. |
| R-03 | **GridGravity ↔ TerrainSystem circular dependency at runtime** — `cell_occupied` requires GridGravity to be initialised before TerrainSystem can block a close timer, but TerrainSystem is initialised first | Low | Medium | `godot-gdscript-specialist` | Wire `cell_occupied` as a `Callable` injected into TerrainSystem at scene setup (dependency injection pattern). Document setup order in `main.tscn`. |
| R-04 | **Godot 4.6.1 project setup friction** — Moving existing `input_system.gd` breaks relative `class_name` or res:// paths assumed by the file | Low | Low | `godot-specialist` | Validate `class_name InputSystem` is globally accessible post-move. Run project with InputSystem node in scene before declaring PROJ-01 done. |
| R-05 | **Player Movement scope creep** — MOVE-01 reviewer requests adding vertical movement before AC sign-off, expanding scope mid-sprint | Low | Medium | Producer | Strictly enforce MOVE-01 ↔ MOVE-02 split. Vertical movement is MOVE-02 (Nice to Have). Any AC not in the table above requires a formal scope change. |

---

## Definition of Done for Sprint 1

All Must Have tasks require ALL acceptance criteria passing before the sprint is
closed. Partial completion of a task does not count.

### Foundation Layer (non-negotiable)
- [ ] `project.godot` opens and runs in Godot 4.6.1 with no console errors
- [ ] `InputSystem` is functional in `main.tscn` (existing implementation verified working)
- [ ] `GridSystem`: all 8 ACs pass (unit tests or manual console verification)
- [ ] `TerrainSystem` property layer: all 7 ACs pass; `TerrainConfig.tres` is committed
- [ ] `TerrainSystem` dig state machine: all 8 ACs pass; timing confirmed with `print` logs
- [ ] `GridGravity`: all 8 ACs pass; `cell_occupied` correctly blocks terrain closing

### Stretch Goal (conditional)
- [ ] *(If MOVE-01 completed)* Player visible on grid, moves left/right, falls under gravity
- [ ] *(If MOVE-02 completed)* Player climbs LADDER, input buffer works, reset works

### Quality Gates
- [ ] No `push_error` or unhandled exceptions in any implemented system during smoke test
- [ ] All public API functions have GDScript `## doc comments`
- [ ] `TerrainConfig` Resource committed as `.tres` file (not hardcoded constants)
- [ ] `GravityConfig` Resource stubbed (even if not used until MOVE-01)
- [ ] Code follows project naming conventions: `snake_case` variables, `PascalCase` classes

---

## Sprint Schedule (indicative)

| Day | Date | Focus |
|-----|------|-------|
| Day 1 | Mon 2026-03-23 | PROJ-01 (0.5d) → GRID-01 start |
| Day 2 | Tue 2026-03-24 | GRID-01 complete → TERR-01 start |
| Day 3 | Thu 2026-03-26 | TERR-01 complete → TERR-02 start |
| Day 4 | Mon 2026-03-30 | TERR-02 complete *(risk checkpoint)* |
| Day 5 | Tue 2026-03-31 | GRAV-01 → Done / stretch MOVE-01 start |
| Day 6 | Thu 2026-04-02 | Buffer / MOVE-01 stretch / QA sweep |

> Sprint review: **Sun 2026-04-05** — demo Foundation Layer, retrospective.

---

## Open Questions Carried Into Sprint

These questions from the GDDs must be answered during implementation (not design):

| GDD | OQ ID | Question | Resolution Deadline |
|-----|-------|----------|---------------------|
| Terrain GDD | OQ-01 | Who owns `cell_occupied`? Resolved: GridGravity (via `Callable` injection) | Before TERR-02 starts |
| Grid Gravity GDD | OQ-01 | Dig immunity signal path: Dig System calls `notify_digging` — but Dig System is Sprint 2. Stub the interface now. | During GRAV-01 |
| Grid Gravity GDD | OQ-02 | Player + guard simultaneous fall on same column — cohabitation or collision? | Defer to Sprint 3 (Enemy AI) |
| Grid System GDD | Open Q3 | Single grid per level confirmed (no multi-layer). Document as ADR. | During GRID-01 |

---

## Handoff Notes for Sprint 2

When Sprint 1 closes, the following contracts must be stable (no breaking changes
without an ADR) for Sprint 2 to build on:

- `GridSystem.grid_to_world`, `world_to_grid`, `is_valid`, `get_neighbors`, `cell_changed`
- `TerrainSystem.is_traversable`, `is_solid`, `is_climbable`, `is_destructible`, `get_tile_type`, `dig_request`
- `GridGravity.is_grounded`, `register_entity`, `entity_should_fall`, `entity_landed`, `cell_occupied`
- `InputSystem.move_requested`, `dig_requested` *(already stable)*

Sprint 2 will focus on: **Player Movement (complete if not done in S1) → Dig System**.

---

## Milestone Reference

See [`production/milestones/mvp.md`](../milestones/mvp.md) for full MVP scope and
target date.

---

*Document owner: Producer | Last updated: 2026-03-23*
