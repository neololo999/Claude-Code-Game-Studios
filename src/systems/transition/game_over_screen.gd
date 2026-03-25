## GameOverScreen — CanvasLayer overlay shown after the death freeze.
##
## Shows the death count and two action buttons: Retry and Quit to Menu.
## Emits retry_requested or quit_to_menu_requested via the parent
## TransitionSystem.
##
## Instantiated at runtime by TransitionSystem.show_game_over(). Not a
## persistent scene — do not add to the scene tree manually.
##
## Layout:
##   GameOverScreen (CanvasLayer, layer=30)
##     └── Control (full rect)
##           ├── Background (ColorRect, semi-transparent)
##           └── VBoxContainer (centred)
##                 ├── TitleLabel   "Game Over"
##                 ├── DeathLabel   "Deaths: N"
##                 └── ButtonRow (HBoxContainer)
##                       ├── RetryButton   "Retry"
##                       └── MenuButton    "Quit to Menu"
##
## Implements: design/gdd/transition-screens.md
class_name GameOverScreen
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Player chose to retry the current level.
signal retry_requested

## Player chose to return to the main menu.
signal quit_to_menu_requested

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _handled: bool = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build and show the game-over overlay.
## death_count: total deaths for the current level session.
func initialize(death_count: int) -> void:
	layer = TransitionConfig.CANVAS_LAYER

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg: ColorRect = ColorRect.new()
	bg.color = TransitionConfig.BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	var title: Label = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Game Over"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var death_label: Label = Label.new()
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.text = "Deaths: %d" % death_count
	vbox.add_child(death_label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 24)
	vbox.add_child(button_row)

	var retry_btn: Button = Button.new()
	retry_btn.text = "Retry"
	retry_btn.pressed.connect(_on_retry_pressed)
	button_row.add_child(retry_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Quit to Menu"
	menu_btn.pressed.connect(_on_menu_pressed)
	button_row.add_child(menu_btn)

	# Auto-focus Retry so keyboard/gamepad works immediately.
	retry_btn.grab_focus()

# ---------------------------------------------------------------------------
# Built-in virtual methods — keyboard shortcut
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _handled:
		return
	# Escape / ui_cancel also triggers Retry (mirrors the existing R-key convention).
	if event.is_action_pressed(&"ui_cancel"):
		_handled = true
		get_viewport().set_input_as_handled()
		retry_requested.emit()

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_retry_pressed() -> void:
	if _handled:
		return
	_handled = true
	retry_requested.emit()


func _on_menu_pressed() -> void:
	if _handled:
		return
	_handled = true
	quit_to_menu_requested.emit()
