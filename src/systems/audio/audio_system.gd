## AudioSystem — reacts to game events with SFX + background music loop.
##
## All playback is null-safe: missing AudioStream resources are silently skipped.
## The game runs identically whether or not audio files are present.
##
## Node structure (child of Level01 in level_01.tscn):
##   AudioSystem (this node)
##     ├── SfxPlayer   (AudioStreamPlayer)
##     ├── SfxPlayerB  (AudioStreamPlayer — second voice for overlapping SFX)
##     └── MusicPlayer (AudioStreamPlayer — looping background music)
##
## SFX assignments (all @export, assigned in scene or inspector):
##   sfx_dig, sfx_pickup, sfx_exit_open, sfx_death, sfx_victory, sfx_win
##
## Implements: design/gdd/audio-system.md
class_name AudioSystem
extends Node

@export var config: AudioConfig

## SFX streams — assign in inspector. Null = silently skipped.
@export var sfx_dig:       AudioStream = null
@export var sfx_pickup:    AudioStream = null
@export var sfx_exit_open: AudioStream = null
@export var sfx_death:     AudioStream = null
@export var sfx_victory:   AudioStream = null
@export var sfx_win:       AudioStream = null

## Music stream — assign in inspector. Null = no music.
@export var sfx_music: AudioStream = null

@onready var _sfx_a:    AudioStreamPlayer = $SfxPlayer
@onready var _sfx_b:    AudioStreamPlayer = $SfxPlayerB
@onready var _music:    AudioStreamPlayer = $MusicPlayer

var _sfx_toggle: bool = false  # alternate between A and B for two-voice SFX

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	var vol: float = config.sfx_volume_db if config else 0.0
	var mvol: float = config.music_volume_db if config else -6.0
	_sfx_a.volume_db   = vol
	_sfx_b.volume_db   = vol
	_music.volume_db   = mvol
	_music.autoplay    = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire signals. Call once in LevelSystem._initialize_level().
func setup(dig: DigSystem, pickups: PickupSystem, level_sys: LevelSystem) -> void:
	if dig != null and not dig.dig_started.is_connected(_on_dig_started):
		dig.dig_started.connect(_on_dig_started)
	if pickups != null:
		if not pickups.pickup_collected.is_connected(_on_pickup_collected):
			pickups.pickup_collected.connect(_on_pickup_collected)
		if not pickups.all_pickups_collected.is_connected(_on_all_pickups_collected):
			pickups.all_pickups_collected.connect(_on_all_pickups_collected)
	if level_sys != null:
		if not level_sys.player_died.is_connected(_on_player_died):
			level_sys.player_died.connect(_on_player_died)
		if not level_sys.level_victory.is_connected(_on_level_victory):
			level_sys.level_victory.connect(_on_level_victory)
		if not level_sys.game_completed.is_connected(_on_game_completed):
			level_sys.game_completed.connect(_on_game_completed)

	play_music()


## Start music loop (AUDIO-02). No-op if stream is null or already playing.
func play_music() -> void:
	if sfx_music == null or _music.playing:
		return
	_music.stream = sfx_music
	_music.play()


## Stop music. Called e.g. on game_completed to hand off to win jingle.
func stop_music() -> void:
	_music.stop()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	# Alternate between two players for lightweight two-voice overlap.
	var player: AudioStreamPlayer = _sfx_b if _sfx_toggle else _sfx_a
	_sfx_toggle = not _sfx_toggle
	player.stream = stream
	player.play()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_dig_started(_col: int, _row: int) -> void:
	_play_sfx(sfx_dig)


func _on_pickup_collected(_col: int, _row: int, _remaining: int) -> void:
	_play_sfx(sfx_pickup)


func _on_all_pickups_collected() -> void:
	_play_sfx(sfx_exit_open)


func _on_player_died() -> void:
	_play_sfx(sfx_death)


func _on_level_victory() -> void:
	_play_sfx(sfx_victory)


func _on_game_completed() -> void:
	stop_music()
	_play_sfx(sfx_win)
