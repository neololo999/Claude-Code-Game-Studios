# GDD: Camera System

> **Status**: Approved
> **Created**: 2026-06-01
> **Last Updated**: 2026-06-01
> **Milestone**: Vertical Slice (Sprint 6)
> **Implements**: `src/systems/camera/camera_controller.gd`
> **Dependencies**: GridSystem, LevelData

---

## Overview

The Camera system follows the player across the grid world using Godot's
`Camera2D` node. For levels that fit within the 640×360 viewport, no scrolling
occurs — the camera is centered on the level. For larger levels, the camera
tracks the player and is clamped to the grid bounds so the player never sees
out-of-bounds black space.

**Design constraint**: The camera must never reveal what is outside the level
grid. The player should always feel "inside" a space, not floating in void.

---

## Node Architecture

```
Level01 (LevelSystem)
  └── CameraController (extends Camera2D)   ← new in Sprint 6
  └── GridSystem
  └── TerrainSystem
  └── ...
```

`CameraController` extends `Camera2D` directly. It is added as a child of the
Level node (same scene as all other systems). It requires a single `setup()`
call after the level is loaded.

---

## Public API

### `setup(player: Node2D, level_data: LevelData) -> void`

Wires the camera to follow the given player node and computes level bounds from
`level_data`.

- Must be called after `LevelSystem._initialize_level()` completes.
- Must be called once per level load (limits are recalculated from `level_data`
  grid dimensions each time — different levels may have different grid sizes).
- Safe to call again on level restart (idempotent).

### `reset() -> void`

Snaps the camera to the player's current position immediately (no smooth
interpolation). Called at the start of each level and on restart to prevent
the camera from sliding in from a previous level's position.

---

## Player Tracking

The camera uses Godot's built-in `position_smoothing_enabled = true` with
`position_smoothing_speed` set from `CameraConfig.SMOOTH_SPEED`.

The camera's `position` is **not** set manually in `_process`. Instead,
`CameraController` sets its own node as `current = true` and lets Godot's
`Camera2D` track the player via `global_position = player.global_position` in
`_process`.

> **Rationale**: Manual `lerp` tracking introduces frame-rate dependence.
> Godot's built-in smoothing is frame-rate independent and handles edge cases
> (e.g. camera at limit boundary) correctly.

---

## Level Bounds Clamping

Bounds are computed from `level_data.grid_cols`, `level_data.grid_rows`, and
`GridSystem.CELL_SIZE`:

```
level_width  = level_data.grid_cols * GridSystem.CELL_SIZE   # pixels
level_height = level_data.grid_rows * GridSystem.CELL_SIZE   # pixels
```

The four `Camera2D` limit properties are set as follows:

```
limit_left   = 0
limit_top    = 0
limit_right  = level_width
limit_bottom = level_height
```

These limits prevent the camera from scrolling past grid edges in any direction.
Godot enforces these limits natively — no additional clamping code is required.

---

## Conditional Scroll Behaviour

### Small levels (≤ 640×360)

When `level_width ≤ 640` **and** `level_height ≤ 360`, the level fits inside the
viewport without scrolling. In this case:

1. Disable `position_smoothing_enabled` (no need to track — camera is fixed).
2. Set `Camera2D` offset to center the level in the viewport:
   ```
   offset = Vector2(level_width / 2.0, level_height / 2.0)
   ```
3. Set all four limits tight to the level bounds (same as above).

This ensures the camera is locked and centred regardless of where the player
moves within the level.

### Large levels (> 640 wide OR > 360 tall)

When the level exceeds the viewport in either axis:

1. Enable `position_smoothing_enabled = true`.
2. Set offset to `Vector2.ZERO` (camera tracks player world position directly).
3. Set limits to level bounds (as above) — Godot clamps automatically.

The camera will track the player and stop scrolling at the grid boundary.

---

## CameraConfig Resource

`src/systems/camera/camera_config.gd` — a plain `Resource` subclass with one
exported constant:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `smooth_speed` | `float` | `5.0` | `Camera2D.position_smoothing_speed` — higher = snappier tracking |

A corresponding `.tres` file is created at
`resources/configs/camera_config.tres`.

---

## Integration with LevelSystem

`LevelSystem` holds an `@export var camera: CameraController` NodePath.
In `_initialize_level()`, after all systems are set up, call:

```gdscript
camera.setup(player, data)
```

On restart (via `_do_restart()`), call `camera.reset()` to snap position
immediately rather than smoothing from the previous position.

---

## Acceptance Criteria

| ID | Criterion |
|----|-----------|
| CAM-AC-01 | `CameraController` extends `Camera2D` and is a child of the Level node |
| CAM-AC-02 | `setup(player, level_data)` sets correct `limit_*` for all 10 levels |
| CAM-AC-03 | Small levels (≤ 640×360): camera is centered, no scroll |
| CAM-AC-04 | Large levels: camera tracks player, stops at grid edges |
| CAM-AC-05 | `reset()` snaps camera to player position with no interpolation lag |
| CAM-AC-06 | No `push_error` during any level load or restart |

---

## Open Questions

*None — all design decisions are closed for Sprint 6 implementation.*

---

*Document owner: Game Designer | Created: 2026-06-01 | Last updated: 2026-06-01*
