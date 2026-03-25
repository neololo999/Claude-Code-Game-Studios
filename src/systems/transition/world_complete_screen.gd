## WorldCompleteScreen — CanvasLayer overlay shown after completing a world.
##
## Shows the world name, total stars earned, and options to continue to the
## next world or return to the main menu.
## Triggered by ProgressionSystem.world_completed signal (Sprint 10 wiring).
##
## Instantiated at runtime by TransitionSystem.show_world_complete(). Not a
## persistent scene — do not add to the scene tree manually.
##
## Layout:
##   WorldCompleteScreen (CanvasLayer, layer=30)
##     └── Control (full rect)
##           ├── Background (ColorRect)
##           └── VBoxContainer (centred)
##                 ├── TitleLabel   "World Complete!"
##                 ├── WorldLabel   world_name
##                 ├── StarsLabel   "X / Y ⭐"
##                 └── ButtonRow (HBoxContainer)
##                       ├── NextWorldButton  "Next World" (may be hidden if no next)
##                       └── MenuButton       "Back to Menu"
##
## Implements: design/gdd/transition-screens.md
class_name WorldCompleteScreen
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Player chose to continue to the next world.
signal world_complete_confirmed

## Player chose to return to the main menu.
signal quit_to_menu_requested

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _handled: bool = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build and show the world-complete overlay.
## world_name: display name of the completed world.
## total_stars: sum of stars across all levels in the world.
## max_stars: len(level_ids) × 3.
## has_next_world: whether there is a subsequent world to unlock/continue to.
func initialize(
		world_name: String,
		total_stars: int,
		max_stars: int,
		has_next_world: bool) -> void:
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
	title.text = "World Complete!"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var world_label: Label = Label.new()
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_label.text = world_name
	vbox.add_child(world_label)

	var stars_label: Label = Label.new()
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.text = "%d / %d ⭐" % [total_stars, max_stars]
	stars_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(stars_label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 24)
	vbox.add_child(button_row)

	if has_next_world:
		var next_btn: Button = Button.new()
		next_btn.text = "Next World"
		next_btn.pressed.connect(_on_next_pressed)
		button_row.add_child(next_btn)
		next_btn.grab_focus()

	var menu_btn: Button = Button.new()
	menu_btn.text = "Back to Menu"
	menu_btn.pressed.connect(_on_menu_pressed)
	button_row.add_child(menu_btn)

	if not has_next_world:
		menu_btn.grab_focus()

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_next_pressed() -> void:
	if _handled:
		return
	_handled = true
	world_complete_confirmed.emit()


func _on_menu_pressed() -> void:
	if _handled:
		return
	_handled = true
	quit_to_menu_requested.emit()
