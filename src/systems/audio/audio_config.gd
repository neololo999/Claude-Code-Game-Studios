## AudioConfig — tuning constants for AudioSystem.
##
## Implements: design/gdd/audio-system.md
class_name AudioConfig
extends Resource

## Volume in dB for all SFX players. 0.0 = unity gain.
@export var sfx_volume_db: float = 0.0

## Volume in dB for music player. Slightly quieter than SFX by default.
@export var music_volume_db: float = -6.0
