## TransitionSystem — manages victory and game-over transition screens.
##
## Owned by LevelSystem as a nullable @export var. When wired, it replaces
## the hardcoded VICTORY_HOLD_TIME and RESTARTING-immediately behaviours with
## interactive overlays that the player acknowledges before advancing.
##
## Null-safe contract: if LevelSystem.transition is null the game behaves
## exactly as in the Vertical Slice (timer-based auto-advance).
##
## Implements: design/gdd/transition-screens.md
class_name TransitionSystem
extends Node

# ---------------------------------------------------------------------------
# Signals — LevelSystem connects to these to drive state transitions
# ---------------------------------------------------------------------------

## Player confirmed the VictoryScreen ("Press any key"). → _do_next_level()
signal confirmed

## Player chose Retry on the GameOverScreen. → _do_restart()
signal retry_requested

## Player chose Quit to Menu on the GameOverScreen. → change scene (Sprint 10)
signal quit_to_menu_requested

## Player confirmed the WorldCompleteScreen "Next World". → _do_next_level()
signal world_complete_confirmed

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _active_screen: CanvasLayer = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Show the VictoryScreen overlay.
## stars: 1–3 (from StarsSystem.get_stars()); 0 if StarsSystem is absent.
## elapsed: completion time in seconds (from StarsSystem.get_time_elapsed()).
func show_victory(stars: int, elapsed: float) -> void:
	_clear_active_screen()
	var screen: VictoryScreen = VictoryScreen.new()
	add_child(screen)
	screen.initialize(stars, elapsed)
	screen.confirmed.connect(_on_victory_confirmed)
	_active_screen = screen


## Show the GameOverScreen overlay.
## death_count: LevelSystem.death_count at the time of game-over.
func show_game_over(death_count: int) -> void:
	_clear_active_screen()
	var screen: GameOverScreen = GameOverScreen.new()
	add_child(screen)
	screen.initialize(death_count)
	screen.retry_requested.connect(_on_retry_requested)
	screen.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	_active_screen = screen


## Show the WorldCompleteScreen overlay.
## Called in Sprint 10 when ProgressionSystem.world_completed is received.
## has_next_world: false if this is the last world (no "Next World" button).
func show_world_complete(
		world_name: String,
		total_stars: int,
		max_stars: int,
		has_next_world: bool) -> void:
	_clear_active_screen()
	var screen: WorldCompleteScreen = WorldCompleteScreen.new()
	add_child(screen)
	screen.initialize(world_name, total_stars, max_stars, has_next_world)
	screen.world_complete_confirmed.connect(_on_world_complete_confirmed)
	screen.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	_active_screen = screen


## Free the active screen without emitting any signal.
## Called by LevelSystem on level restart (defensive).
func dismiss() -> void:
	_clear_active_screen()

# ---------------------------------------------------------------------------
# Private callbacks
# ---------------------------------------------------------------------------

func _on_victory_confirmed() -> void:
	_clear_active_screen()
	confirmed.emit()


func _on_retry_requested() -> void:
	_clear_active_screen()
	retry_requested.emit()


func _on_quit_to_menu_requested() -> void:
	_clear_active_screen()
	quit_to_menu_requested.emit()


func _on_world_complete_confirmed() -> void:
	_clear_active_screen()
	world_complete_confirmed.emit()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _clear_active_screen() -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = null
