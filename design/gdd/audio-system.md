# GDD: Audio System

> **Status**: Approved
> **Created**: 2026-06-15
> **Last Updated**: 2026-06-15
> **Milestone**: Vertical Slice (Sprint 7)
> **Implements**: `src/systems/audio/audio_system.gd`
> **Dependencies**: DigSystem, PickupSystem, LevelSystem

---

## Overview

The Audio System responds to game events with sound effects and maintains a
background music loop. It is a single `Node` child of the Level, wired to game
signals at setup time. All audio playback is null-safe: if an `AudioStream`
resource is not assigned, the event is silently skipped — the game runs
identically without any audio files present.

**Design philosophy**: Audio is purely reactive. The Audio System never drives
game logic; it only listens and responds. No gameplay system depends on audio.

---

## Sound Events

| Event | Source Signal | SFX Label | Notes |
|-------|--------------|-----------|-------|
| Player digs | `DigSystem.dig_started` | `sfx_dig` | Plays on every successful dig |
| Treasure collected | `PickupSystem.pickup_collected` | `sfx_pickup` | One-shot per pickup |
| All treasures collected | `PickupSystem.all_pickups_collected` | `sfx_exit_open` | Optional — distinct from single pickup |
| Player death | `LevelSystem.player_died` | `sfx_death` | Interrupts any active SFX on same player |
| Level complete | `LevelSystem.level_victory` | `sfx_victory` | Level transition jingle |
| Game complete | `LevelSystem.game_completed` | `sfx_win` | YOU WIN sound |

---

## Node Architecture

```
Level01 (LevelSystem)
  └── AudioSystem (Node)
        ├── SfxPlayer      (AudioStreamPlayer — polyphony mode: single)
        ├── SfxPlayerB     (AudioStreamPlayer — second voice for overlaps)
        └── MusicPlayer    (AudioStreamPlayer — looping, bus: Music)
```

Two `AudioStreamPlayer` nodes for SFX (`SfxPlayer`, `SfxPlayerB`) allow simple
two-voice overlap (e.g., dig + pickup in the same frame). For MVP purposes,
overlapping is handled by stopping the active player and restarting — no full
polyphony engine required.

---

## Public API — `AudioSystem`

`src/systems/audio/audio_system.gd` (extends `Node`).

### `setup(dig: DigSystem, pickups: PickupSystem, level_sys: LevelSystem) -> void`

Connects signals and stores references. Called once in
`LevelSystem._initialize_level()` (guarded by `is_connected`).

### `play_music() -> void`

Starts the music loop if `MusicPlayer.stream != null` and music is not already
playing.

### `stop_music() -> void`

Stops the music player. Called on game_completed if a win jingle exists.

---

## AudioConfig Resource

`src/systems/audio/audio_config.gd` — exported constants:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `sfx_volume_db` | `float` | `0.0` | Volume for all SFX players |
| `music_volume_db` | `float` | `-6.0` | Music slightly quieter than SFX |

---

## Asset Paths (conventional — not enforced by code)

| SFX Label | Expected path |
|-----------|--------------|
| `sfx_dig` | `res://assets/audio/sfx/dig.wav` |
| `sfx_pickup` | `res://assets/audio/sfx/pickup.wav` |
| `sfx_exit_open` | `res://assets/audio/sfx/exit_open.wav` |
| `sfx_death` | `res://assets/audio/sfx/death.wav` |
| `sfx_victory` | `res://assets/audio/sfx/victory.wav` |
| `sfx_win` | `res://assets/audio/sfx/win.wav` |
| Music | `res://assets/audio/music/theme.ogg` |

All paths are assigned via `@export` on `AudioSystem` — no hardcoded paths.
Sprint 7 ships zero audio files; Sprint 8 drops real assets in.

---

## Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AUDIO-AC-01 | `AudioSystem` node exists as child of Level01 |
| AUDIO-AC-02 | `setup()` connects all 6 SFX signals (null-safe) |
| AUDIO-AC-03 | `play_sfx(stream)` silently skips if stream is null |
| AUDIO-AC-04 | Music loops on `play_music()` if stream assigned |
| AUDIO-AC-05 | No `push_error` during 10-level playthrough with zero audio files |
| AUDIO-AC-06 | `sfx_volume_db` and `music_volume_db` applied to players in `setup()` |

---

*Document owner: Audio Director | Created: 2026-06-15 | Last updated: 2026-06-15*
