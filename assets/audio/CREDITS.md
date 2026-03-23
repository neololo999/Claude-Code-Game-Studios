# Audio Asset Credits — Dig & Dash

All audio assets used in this project must be CC0 (public domain) or have an
equivalent licence that permits free use, modification, and redistribution
without attribution requirements.

---

## Sound Effects (`assets/audio/sfx/`)

| File | Event | Source | URL | Licence |
|------|-------|--------|-----|---------|
| `dig.ogg` | Player digs a hole | — | — | — |
| `pickup.ogg` | Treasure collected | — | — | — |
| `exit_open.ogg` | All treasures collected / exit unlocks | — | — | — |
| `death.ogg` | Player death | — | — | — |
| `victory.ogg` | Level complete | — | — | — |
| `win.ogg` | All 10 levels complete | — | — | — |

## Music (`assets/audio/music/`)

| File | Description | Source | URL | Licence |
|------|-------------|--------|-----|---------|
| `loop.ogg` | Background gameplay loop | — | — | — |

---

## Recommended CC0 Sources

- **OpenGameArt.org** — https://opengameart.org/ (filter by CC0)
  - Search: "chiptune", "8-bit", "puzzle", "retro SFX pack"
  - Notable packs: "Blippy Chippy" sounds, "512 Sound Effects" by Juhani Junkala
- **Freesound.org** — https://freesound.org/ (filter: CC0)
  - Search: "dig", "coin", "blip", "retro game over", "fanfare"
- **itch.io** — https://itch.io/game-assets/free (sort by CC0)

## Asset Requirements

| Requirement | Value |
|-------------|-------|
| Format | `.ogg` preferred (smaller than `.wav`, natively supported by Godot) |
| SFX duration | < 2 seconds each |
| Music loop | Seamless loop, 30–120 seconds before repeat |
| Sample rate | 44100 Hz or 22050 Hz |
| Channels | Mono for SFX, Stereo for music |

## Godot Wiring

After adding files:
1. Open Godot editor — files will auto-import as `AudioStreamOggVorbis` resources.
2. Open `scenes/level_01.tscn` → select `AudioSystem` node.
3. In Inspector, assign each SFX stream to the corresponding `@export` var:
   - `sfx_dig` → `assets/audio/sfx/dig.ogg`
   - `sfx_pickup` → `assets/audio/sfx/pickup.ogg`
   - `sfx_exit_open` → `assets/audio/sfx/exit_open.ogg`
   - `sfx_death` → `assets/audio/sfx/death.ogg`
   - `sfx_victory` → `assets/audio/sfx/victory.ogg`
   - `sfx_win` → `assets/audio/sfx/win.ogg`
   - `sfx_music` → `assets/audio/music/loop.ogg`
4. Save the scene.

The `AudioSystem` is null-safe: if any stream is not assigned, the event is
silently skipped. The game runs correctly without any audio files.

---

*Last updated: 2026-03-23*
