# GDD: Visual Feedback System

> **Status**: Approved
> **Created**: 2026-06-15
> **Last Updated**: 2026-06-15
> **Milestone**: Vertical Slice (Sprint 7)
> **Implements**: `src/systems/vfx/vfx_system.gd`
> **Dependencies**: CameraController, LevelSystem, PickupSystem

---

## Overview

The Visual Feedback system adds two lightweight effects that make the game feel
responsive: a brief camera shake on player death, and a flash on pickup
collection. Both effects are short (< 0.3s), subtle, and never obscure gameplay
information.

**Design constraint**: Visual feedback must never interfere with readability.
Screen-shake amplitude is capped at 4px. Flash opacity never exceeds 0.6.

---

## Effect 1: Screen-Shake on Death

**Trigger**: `LevelSystem.player_died` signal.

**Behaviour**:
- Duration: 0.25s
- Amplitude: 4.0px (horizontal + vertical, randomised per frame)
- Implementation: offset `CameraController.offset` by a random `Vector2`
  within `(-amplitude, +amplitude)` each frame during shake duration.
- Uses `_process(delta)` with an elapsed timer — no `SceneTreeTimer`.
- After shake completes: reset `camera.offset` to `Vector2.ZERO`.

**API note**: `Camera2D.offset` is the correct property. It applies after limit
clamping in Godot 4.x, so shake never causes the camera to show out-of-bounds
content (the limit clamping happens at the position level, not offset level —
minor edge-of-level artefact acceptable for MVP).

---

## Effect 2: Pickup Flash

**Trigger**: `PickupSystem.pickup_collected(col, row, remaining)`.

**Behaviour**:
- A white `ColorRect` (one cell-sized, 32×32px) is positioned at the
  collected cell's world position.
- Fades from opacity 0.6 → 0.0 over 0.15s using a `Tween`.
- After fade completes: `queue_free()` the ColorRect.
- Maximum 8 simultaneous flash rects (unlikely to hit in normal play, but
  prevents memory growth in edge cases).

**Implementation note**: VfxSystem adds flash rects as children of itself
(which extends `Node2D` in world space, not CanvasLayer). The rects are
positioned using `GridSystem.grid_to_world(col, row)`.

---

## Node Architecture

```
Level01 (LevelSystem)
  └── VfxSystem (Node2D)
        └── [Flash rects created/freed dynamically]
```

`VfxSystem` extends `Node2D` so it has a world-space position for the flash
rects. Camera shake is applied directly to the `CameraController.offset`
property.

---

## Public API — `VfxSystem`

### `setup(camera: CameraController, pickups: PickupSystem, level_sys: LevelSystem, grid: GridSystem) -> void`

Connects signals and stores references.

### `reset() -> void`

Cancels any active shake timer, resets `camera.offset = Vector2.ZERO`, frees
all active flash rects. Called by LevelSystem on restart.

---

## Acceptance Criteria

| ID | Criterion |
|----|-----------|
| VFX-AC-01 | Screen-shake triggers on `player_died`; lasts ≤ 0.25s; amplitude ≤ 4px |
| VFX-AC-02 | After shake: `camera.offset` is exactly `Vector2.ZERO` |
| VFX-AC-03 | Pickup flash appears at correct grid position; fades in 0.15s |
| VFX-AC-04 | Flash rects are freed after fade; no memory accumulation |
| VFX-AC-05 | `reset()` clears shake and all active flashes on restart |
| VFX-AC-06 | No `push_error` with zero signal connections (null camera is handled) |

---

*Document owner: Technical Artist | Created: 2026-06-15 | Last updated: 2026-06-15*
