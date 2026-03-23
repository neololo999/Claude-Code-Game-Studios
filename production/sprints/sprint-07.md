# Sprint 7 — 2026-06-15 to 2026-06-28

> **Status**: Planned
> **Created**: 2026-06-14
> **Owner**: Producer
> **Sprint Number**: 7 of 8 (Vertical Slice)

---

## Sprint Goal

Replace colored rectangles with real pixel-art sprites, wire the audio system to
game events, and deliver a first pass of visual feedback — all building directly
on the rendering abstraction established in Sprint 6.

After this sprint, the game shows distinct pixel-art tiles for terrain and entity
sprites for the player and guards, plays sound effects on dig / pickup / death /
victory, loops background music during gameplay, and gives the player a tactile
screen-shake on death and a pickup flash on collection. The game is no longer
visually silent.

**This is the polish layer sprint.** Every task this sprint is a consumer of
Sprint 6's rendering and camera contracts — no new architectural game-logic is
introduced. The single highest-risk task is `SPRITE-01`: it owns the asset
pipeline (placeholder PNG generation + `Texture2D` loading with `ColorRect`
fallback) and is the gate for `SPRITE-02`. All other tracks — GDDs, audio, VFX —
are independent and can proceed in parallel with sprite work.

---

## Capacity

| Metric | Value |
|--------|-------|
| Sprint dates | 2026-06-15 → 2026-06-28 |
| Working days in sprint | 6 (3 days/week × 2 weeks) |
| Buffer (20%) | 1 day |
| **Effective capacity** | **5 days** |
| Stretch capacity (if buffer unused) | +1 day |
| Tasks loaded — Must Have | 3.0d |
| Tasks loaded — Should Have | 2.0d |
| **Total loaded** | **5.0d** (100% of effective capacity) |

> Buffer is reserved for `SPRITE-01` overrun (see S7-R01). If `SPRITE-01`
> ships within estimate, the saved time folds into `VFX-01`. If `SPRITE-01`
> overruns by > 0.5d, `VFX-01` drops to Sprint 8 without negotiation.

---

## Sprint 6 Retrospective Summary

| ID | Task | Owner | Estimate | Result |
|----|------|-------|----------|--------|
| VS-00 | Create `production/milestones/vertical-slice.md` | Producer | 0.5d | ✅ Done |
| GDD-CAM | Author `design/gdd/camera-system.md` | Game Designer | 0.5d | ✅ Done |
| GDD-HUD | Author `design/gdd/hud-system.md` | Game Designer | 0.5d | ✅ Done |
| CAM-01 ★CP | Implement `CameraController` (Camera2D, player tracking, level bounds) | Programmer | 1.0d | ✅ Done |
| RENDER-01 ★CP | Implement `TerrainRenderer` (6 TileType colours, incremental dig update) | Programmer | 1.5d | ✅ Done |
| RENDER-02 *(Should Have)* | Implement `EntityRenderer` (player=blue, enemies=red, `_process` tracking) | Programmer | 0.5d | ✅ Done |
| HUD-01 *(Should Have)* | Implement `HUDController` (CanvasLayer 10, treasure counter, dig cooldown bar, exit label) | Programmer | 0.5d | ✅ Done |
| **Velocity** | | | **5.0 / 5.0d** | **100% Must Have · 100% Should Have** |

**What went well:** `RENDER-01` — the highest-risk task of the sprint — shipped
within its 1.5d estimate. The up-front `draw_rect` audit recommended in the
sprint plan paid off: no entangled calls were found that forced scope reductions.
Both Should Have tasks (`RENDER-02`, `HUD-01`) shipped on Day 5 as planned,
giving Sprint 7 a clean, stable rendering foundation to build on.

**What to watch:** `SPRITE-01` in Sprint 7 introduces an asset pipeline concern
that has no precedent in Sprints 1–6 — the team has never generated binary `.png`
files programmatically or loaded `Texture2D` resources at runtime. Budget the
full 1.0d estimate; validate the Python placeholder-generation script *before*
touching `TerrainRenderer`. If the asset pipeline takes longer than expected, the
`ColorRect` fallback path in `TerrainRenderer` means the game remains playable
at zero additional risk.

---

## Carryover from Sprint 6

None.

---

## Dependency Graph (Sprint 7)

```
[Sprint 6 — ✅ All Must Have + All Should Have]
  CameraController · TerrainRenderer · EntityRenderer · HUDController
  camera-system.md · hud-system.md · vertical-slice.md
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
      [GDD-AUDIO:         [GDD-VFX:          [SPRITE-01: ★CP ★HIGHEST RISK
       Audio system GDD    Visual Feedback     Terrain sprite loading +
       (0.5d)]             GDD (0.5d)]         PNG placeholder pipeline
                               │               (1.0d)]
                               │                   │
                               ▼                   ▼
                           [VFX-01:           [SPRITE-02:  ← Should Have
                            Screen-shake +     Entity sprite loading
                            pickup flash       in EntityRenderer
                            (1.0d)]            (0.5d)]
      [GDD-AUDIO]
          │
          ▼
      [AUDIO-01: ★CP
       AudioSystem SFX events
       (1.0d)]
          │
          ▼
      [AUDIO-02:  ← Should Have
       Music loop
       (0.5d)]
```

**★CP = Critical Path**

Critical paths (sequential constraints):
- **Path A**: `GDD-AUDIO` (0.5d) → `AUDIO-01` (1.0d) → `AUDIO-02` (0.5d) = **2.0d chain** ← longest
- **Path B**: `GDD-VFX` (0.5d) → `VFX-01` (1.0d) = **1.5d chain**
- **Path C**: `SPRITE-01` (1.0d) → `SPRITE-02` (0.5d) = **1.5d chain**

`AUDIO-02` is the Should Have item most likely to be squeezed by an `AUDIO-01`
overrun. `SPRITE-02` and `VFX-01` are independent of the audio track and can
proceed concurrently on the same day.

**Recommended sequencing for solo developer (5 days):**

| Day | Focus |
|-----|-------|
| Day 1 | `GDD-AUDIO` (0.5d) + `GDD-VFX` (0.5d) |
| Day 2 | `SPRITE-01` (1.0d) — full day, asset pipeline + TerrainRenderer update |
| Day 3 | `AUDIO-01` (1.0d) — full day, AudioSystem + signal wiring |
| Day 4 | `SPRITE-02` (0.5d) + `AUDIO-02` (0.5d) ← both Should Have |
| Day 5 | `VFX-01` (1.0d) ← Should Have |

---

## Tasks

### Must Have (3.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **GDD-AUDIO** | Author `design/gdd/audio-system.md`. Must cover: `AudioSystem` node role and scene placement (autoload vs. child of level), `AudioStreamPlayer` one-shot event model (one player per sound category or pooled), signal connections (`DigSystem.dig_started`, `PickupSystem.pickup_collected`, `LevelSystem.player_died`, `LevelSystem.level_victory`, `LevelSystem.game_completed`), music loop architecture (separate `AudioStreamPlayer`, `stream_paused` on game pause), `audio_config.gd` constants (`music_volume_db`, `sfx_volume_db`), null-safe stream handling (system must not crash if audio files are absent), and public API (`play_sfx(event: String) -> void`, `set_music_volume(db: float) -> void`, `set_sfx_volume(db: float) -> void`). | Game Designer | 0.5d | — | ⬜ Not started |
| **GDD-VFX** | Author `design/gdd/visual-feedback.md`. Must cover: screen-shake specification (duration < 0.3s, amplitude 4px, `CameraController` offset approach using `Tween` or `_process` counter, no camera position override that conflicts with level bounds), pickup flash specification (target: cell `Rect2` at pickup world position, `ColorRect` with `modulate.a` tweened 0→1 in 0.05s then 1→0 in 0.10s, `queue_free` on completion), `VfxSystem` node placement (CanvasLayer or Node2D child of level — justify the choice), signal connections (`LevelSystem.player_died` → shake, `PickupSystem.pickup_collected(coords)` → flash at world pos), and `CameraController` reference acquisition strategy. | Game Designer | 0.5d | — | ⬜ Not started |
| **SPRITE-01** ★CP ★HIGHEST RISK | (a) **Asset pipeline**: Write a Python script (`tools/generate_placeholders.py`) that programmatically generates 6 terrain PNGs (32×32 px, one per `TileType`) using the same colours as `TerrainRenderer` (`SOLID=#888888`, `DIRT_SLOW=#8B5E3C`, `DIRT_FAST=#C8A97A`, `LADDER=#FFD700`, `ROPE=#FF8C00`, `DIRT_OPEN=#000000`). Output to `assets/sprites/terrain/`. Run script once; commit the generated `.png` files. (b) **TerrainRenderer update**: Extend `TerrainRenderer` to attempt `load("res://assets/sprites/terrain/<tile_name>.png")` for each `TileType`. If the `Texture2D` loads successfully, render a `Sprite2D`; if `null`, fall back to existing `ColorRect` — **no behaviour change if assets are absent**. All 6 tile names must be documented in `audio_config.gd` — wait, in a constant map within `terrain_renderer.gd`. Existing `ColorRect` fallback path must remain tested and functional. | Programmer | 1.0d | — | ⬜ Not started |
| **AUDIO-01** ★CP | Implement `src/systems/audio/audio_system.gd` and `src/systems/audio/audio_config.gd`. `AudioSystem` extends `Node`. On `_ready`: create one `AudioStreamPlayer` child per SFX slot (`dig`, `pickup`, `death`, `victory`, `complete`) and one dedicated `music_player`. Connect to `DigSystem.dig_started`, `PickupSystem.pickup_collected`, `LevelSystem.player_died`, `LevelSystem.level_victory`, `LevelSystem.game_completed` — each triggers `play_sfx()` with the matching key. `audio_config.gd` exposes: `MUSIC_VOLUME_DB: float = -10.0`, `SFX_VOLUME_DB: float = 0.0`, `SFX_KEYS: Dictionary` mapping event names to `.ogg`/`.wav` resource paths. `play_sfx()` must be null-safe: if the stream resource at the configured path does not exist, log a warning and return — no `push_error`, no crash. The system must function with **zero audio files present** in the project. | Programmer | 1.0d | GDD-AUDIO | ⬜ Not started |

### Should Have (2.0d)

| ID | Task | Owner | Estimate | Dependencies | Status |
|----|------|-------|----------|--------------|--------|
| **AUDIO-02** | Extend `AudioSystem` with music loop support. `music_player` (`AudioStreamPlayer`) loads the stream from `audio_config.MUSIC_TRACK_PATH`. If stream is non-null: set `stream_paused = false`, `volume_db = audio_config.MUSIC_VOLUME_DB`, `autoplay = true` on the node, and `looping = true` on the `AudioStreamOggVorbis` or `AudioStreamMP3` resource. If stream is null: skip silently. Expose `set_music_volume(db: float) -> void` and `set_sfx_volume(db: float) -> void` that update all live players. Add `audio_config.MUSIC_TRACK_PATH: String = "res://assets/audio/music/loop.ogg"` with the understanding that the file may not exist at ship time — null-safe as per AUDIO-01 contract. | Programmer | 0.5d | AUDIO-01 | ⬜ Not started |
| **SPRITE-02** | Extend `EntityRenderer` with sprite support. (a) **Asset pipeline**: add two placeholder PNGs to the Python script from `SPRITE-01` (or a second pass): `assets/sprites/entities/player.png` (32×32, blue `#00AAFF`, solid fill) and `assets/sprites/entities/enemy.png` (32×32, red `#FF2222`, solid fill). (b) **EntityRenderer update**: attempt `load("res://assets/sprites/entities/player.png")` and `load("res://assets/sprites/entities/enemy.png")` in `setup()`. If `Texture2D` loads, swap `ColorRect` for `Sprite2D` with that texture; if `null`, retain existing `ColorRect`. Position tracking in `_process` must work identically for both code paths. | Programmer | 0.5d | SPRITE-01 | ⬜ Not started |
| **VFX-01** | Implement `src/systems/vfx/vfx_system.gd`. `VfxSystem` extends `Node`. On `_ready`: locate `CameraController` via `get_tree().get_first_node_in_group("camera")` or direct node path — document the chosen strategy. **Screen-shake**: connect to `LevelSystem.player_died`; on signal, start a `Tween` that offsets `CameraController.offset` (not `position`) with a random 4px amplitude pattern over 0.25s, resetting to `Vector2.ZERO` on completion. Shake must not interfere with level-bounds clamping set by `CAM-01`. **Pickup flash**: connect to `PickupSystem.pickup_collected(coords: Vector2i)`; on signal, instantiate a `ColorRect` at the world-space position of `coords` (cell size 32×32), set `color = Color.WHITE`, parent to the level's `Node2D` root, and run a `Tween`: alpha 0→1 over 0.05s then 1→0 over 0.10s, then `queue_free`. Both effects must be null-safe: if `CameraController` reference is not found, log a warning and skip shake — no crash. | Programmer | 1.0d | GDD-VFX | ⬜ Not started |

### Nice to Have

*None — sprint is at full effective capacity (5.0d loaded). Any additional scope
would consume the buffer reserved for `SPRITE-01` overrun and the asset pipeline
risk.*

---

## Risks

| ID | Risk | Probability | Impact | Owner | Mitigation |
|----|------|-------------|--------|-------|------------|
| **S7-R01** | `SPRITE-01` asset pipeline (Python PNG generation + Godot `Texture2D` import) takes longer than 1.0d. Godot's import system may require `.import` sidecar files to exist before resources can be `load()`-ed at runtime, which may require a Godot editor headless import pass that cannot be automated without a running editor instance. | High | Medium | Programmer | Before starting `SPRITE-01` implementation, spend 30 min verifying whether `ResourceLoader.load()` works on PNG files that were never opened in the Godot editor (i.e. no `.import` sidecar). If sidecars are required and cannot be generated headlessly, fall back to: ship Sprint 7 with the `ColorRect` renderer from Sprint 6 as the visual layer, and document the asset pipeline gap for Sprint 8's VS integration pass. The `ColorRect` fallback in `TerrainRenderer` is not a regression — it is the designed safety net. |
| **S7-R02** | `AUDIO-01` signal connections fail silently because the `AudioSystem` node is added to the scene tree *after* the systems it listens to have already emitted their `_ready` signals. Connection timing in Godot's scene tree depends on node order. | Medium | Medium | Programmer | `AudioSystem` must connect to signals in its own `_ready` using `get_tree().get_first_node_in_group()` or direct `NodePath` references — not via `@onready` vars that resolve before siblings are ready. Add a fallback: if a target node is not found in `_ready`, defer connection to `call_deferred("_connect_signals")`. Document the chosen strategy in the GDD-AUDIO. |
| **S7-R03** | `VFX-01` screen-shake conflicts with `CameraController`'s `limit_*` bounds: offsetting `Camera2D.offset` may push the rendered viewport outside the level grid, showing black bars on death. | Low | Medium | Programmer | Use `Camera2D.offset` (viewport-space displacement, applied after limit clamping in Godot 4) rather than modifying `position` or `global_position`. Verify with a test level whose camera is already clamped to a tight bound — confirm no black-bar bleed at maximum 4px shake amplitude. |
| **S7-R04** | GDD quality for Audio or Visual Feedback requires a revision cycle that delays `AUDIO-01` or `VFX-01` past Day 2. Both GDDs are authored on Day 1 but have no prior GDD in this project to model from (camera and HUD GDDs covered Godot nodes; audio covers signals + streams, which is a new domain). | Low | Medium | Game Designer | GDDs must be committed and reviewed by the implementer before end of Day 1. Any open question (e.g. "AudioStreamPlayer pooling vs. per-event players") is escalated to Producer same day and resolved with a documented decision — the implementer never waits more than one working session for a GDD clarification. |
| **S7-R05** | Scope creep: once placeholder sprites exist, pressure builds to upgrade them to "real" pixel art in the same sprint. Similarly, once audio wiring exists, there is temptation to add audio files beyond the architecture task. | Medium | Low | Producer | Sprint 7 success metric is architectural, not aesthetic: "Sprint 8 can swap in final art and real audio files without touching any GDScript code." Any new `.png` refinement or audio file addition beyond the Python-generated placeholders requires Producer approval and is explicitly a Sprint 8 concern. |

---

## Acceptance Criteria (Sprint Exit Gate)

The sprint is **Done** when ALL Must Have criteria below are true:

### GDD-AUDIO
- [ ] `design/gdd/audio-system.md` exists and is committed
- [ ] Covers: `AudioSystem` node placement, one-shot `AudioStreamPlayer` model, all 5 signal connections, music loop architecture, `audio_config.gd` constants
- [ ] Defines null-safe handling when audio stream resources are absent
- [ ] Specifies `play_sfx()`, `set_music_volume()`, `set_sfx_volume()` public API signatures

### GDD-VFX
- [ ] `design/gdd/visual-feedback.md` exists and is committed
- [ ] Covers: screen-shake spec (duration < 0.3s, amplitude 4px, `Camera2D.offset` approach), pickup flash spec (0.05s fade-in, 0.10s fade-out, `ColorRect` + `Tween`)
- [ ] Specifies `VfxSystem` node placement and `CameraController` acquisition strategy
- [ ] Lists signal connections (`LevelSystem.player_died`, `PickupSystem.pickup_collected`)

### SPRITE-01
- [ ] `tools/generate_placeholders.py` exists and is runnable with Python 3
- [ ] Running the script produces 6 PNG files in `assets/sprites/terrain/` (one per TileType, 32×32, correct fill colour)
- [ ] Generated PNG files are committed to the repository
- [ ] `TerrainRenderer` attempts `Texture2D` load for each TileType; uses `Sprite2D` if non-null
- [ ] `TerrainRenderer` falls back to `ColorRect` if texture load returns null — existing visual behaviour unchanged
- [ ] All 10 levels render correctly via `TerrainRenderer` with or without `.png` files present
- [ ] Committed to `main` with no new `push_error` calls

### AUDIO-01
- [ ] `src/systems/audio/audio_system.gd` exists extending `Node`
- [ ] `src/systems/audio/audio_config.gd` exists with `MUSIC_VOLUME_DB`, `SFX_VOLUME_DB`, `SFX_KEYS` constants
- [ ] `AudioSystem` connects to all 5 signals: `dig_started`, `pickup_collected`, `player_died`, `level_victory`, `game_completed`
- [ ] `play_sfx()` does not crash or emit `push_error` when the configured audio resource path does not exist
- [ ] System is functional (no crashes) with **zero audio files** in the project
- [ ] Committed to `main` with no new `push_error` calls

### Should Have (target, not blocking)
- [ ] `AudioSystem` plays background music loop when `audio_config.MUSIC_TRACK_PATH` resolves to a non-null stream
- [ ] `EntityRenderer` loads player/enemy PNGs from `assets/sprites/entities/` if available; falls back to `ColorRect`
- [ ] `VfxSystem` triggers < 0.3s screen-shake on `LevelSystem.player_died` with no camera black-bar bleed
- [ ] `VfxSystem` triggers pickup flash `ColorRect` tween at correct world position on `PickupSystem.pickup_collected`

---

## Definition of Done (Sprint Level)

A task is **Done** when:
1. All acceptance criteria for that task are met
2. No new `push_error` calls introduced anywhere in the project
3. The change is committed to `main` with a descriptive message referencing the task ID
4. Any GDD or milestone doc affected is updated in the same commit
5. The task owner has self-tested in the Godot editor (run all 10 levels, verify no visual or audio regressions)

---

## Notes

- **Vertical Slice = 3 sprints (6–8).** Sprint 6 = rendering foundation +
  camera + GDDs (complete). Sprint 7 = sprites + audio + VFX (this sprint).
  Sprint 8 = HUD polish + stars/scoring + full VS integration pass + `v0.2.0-vs`
  tag. Do not pull Sprint 8 scope (stars, HUD polish, integration pass) into
  Sprint 7 even if capacity appears free.

- **`SPRITE-01` is the riskiest new work this sprint.** It is the first task in
  the project's history that involves binary asset generation and Godot's resource
  importer. The Python placeholder script is the correct mitigation: generate the
  files, verify they load, *then* wire `TerrainRenderer`. Attempting to do both in
  one step risks discovering the import issue mid-integration. Audit the import
  pipeline first (30 min); implement second; verify all 10 levels third.

- **The `ColorRect` fallback is not a regression.** `TerrainRenderer` and
  `EntityRenderer` shipping with `ColorRect` as the active path is indistinguishable
  from Sprint 6. The Sprint 7 value in `SPRITE-01` and `SPRITE-02` is the
  *architecture* — the ability to swap in real sprites by dropping files into
  `assets/` without touching GDScript. If `.png` assets don't load due to import
  sidecar issues, the fallback is the delivery, not a failure.

- **GDDs must precede implementation.** `GDD-AUDIO` must be committed before
  `AUDIO-01` starts coding. `GDD-VFX` must be committed before `VFX-01` starts.
  Both GDDs are on Day 1 — the implementer reviews same day. Non-negotiable.

- **`AUDIO-01` must be null-safe end-to-end.** No audio file will exist in the
  repository at sprint close (licensing and production are Sprint 8 concerns per
  VS-R02). Every `AudioStreamPlayer.play()` call must be guarded by a null-check
  on `stream`. Use `if stream != null: play()` pattern; never assume a `.tres`
  or `.ogg` file exists. This is the primary quality bar for AUDIO-01.

- **`VFX-01` screen-shake uses `Camera2D.offset`, not `position`.** In Godot
  4.x, modifying `Camera2D.offset` displaces the rendered viewport in screen
  space *after* limit clamping is applied, meaning the 4px amplitude shake cannot
  cause the camera to violate the level bounds set by `CAM-01`. This is the
  correct API surface; any other approach risks black-bar bleed on levels with
  tight bounds.

- **Godot version**: 4.6.1 / GDScript. `AudioStreamPlayer`, `Tween`,
  `Camera2D.offset`, `ResourceLoader.load()`, and `Sprite2D` are all stable
  Godot 4.x API. No compatibility flags required.

- **Sprint 7 success metric:** "We'll know this sprint was right if Sprint 8 can
  add final pixel art and real audio files by dropping files into `assets/` —
  without modifying a single line of GDScript in `TerrainRenderer`, `EntityRenderer`,
  or `AudioSystem`."

---

*Document owner: Producer | Created: 2026-06-14 | Last updated: 2026-06-14*
