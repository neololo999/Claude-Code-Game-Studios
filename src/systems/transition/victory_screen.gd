## VictoryScreen — CanvasLayer overlay shown after level victory.
##
## Displays the star count, elapsed time, and a "Press any key" hint.
## The first keypress or button press emits the `confirmed` signal, which
## LevelSystem connects to `_do_next_level()`.
##
## Instantiated at runtime by TransitionSystem.show_victory(). Not a
## persistent scene — do not add to the scene tree manually.
##
## Layout:
##   VictoryScreen (CanvasLayer, layer=30)
##     └── Control (full rect)
##           ├── Background (ColorRect, semi-transparent)
##           └── VBoxContainer (centred)
##                 ├── TitleLabel   "Level Complete!"
##                 ├── StarsLabel   "⭐⭐☆"
##                 ├── TimeLabel    "Completed in X.Xs"
##                 └── HintLabel    "Press any key to continue" (blinking)
##
## Implements: design/gdd/transition-screens.md
class_name VictoryScreen
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted on the first keypress / button press. LevelSystem calls _do_next_level().
signal confirmed

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const STAR_FILLED: String = "⭐"
const STAR_EMPTY: String  = "☆"

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _confirmed: bool = false
var _hint_label: Label = null
var _blink_timer: float = 0.0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build and show the victory overlay.
## stars: 1–3 (pass 0 if unknown — shows "☆☆☆").
## elapsed: completion time in seconds.
func initialize(stars: int, elapsed: float) -> void:
	layer = TransitionConfig.CANVAS_LAYER
	set_process(true)

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
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	var title: Label = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Level Complete!"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var stars_label: Label = Label.new()
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.text = _build_stars_string(stars)
	stars_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(stars_label)

	var time_label: Label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.text = "Completed in %.1fs" % elapsed
	vbox.add_child(time_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "Press any key to continue"
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	vbox.add_child(_hint_label)

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _confirmed:
		return
	_blink_timer += delta
	if _blink_timer >= TransitionConfig.HINT_BLINK_INTERVAL:
		_blink_timer = 0.0
		if _hint_label != null:
			_hint_label.visible = not _hint_label.visible


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed:
		return
	# Accept any key press or joypad button press.
	var is_key_press: bool = event is InputEventKey and (event as InputEventKey).pressed \
		and not (event as InputEventKey).echo
	var is_joypad_press: bool = event is InputEventJoypadButton \
		and (event as InputEventJoypadButton).pressed
	var is_mouse_press: bool = event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed
	if is_key_press or is_joypad_press or is_mouse_press:
		_confirmed = true
		get_viewport().set_input_as_handled()
		confirmed.emit()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _build_stars_string(stars: int) -> String:
	var result: String = ""
	for i: int in 3:
		result += STAR_FILLED if i < stars else STAR_EMPTY
		if i < 2:
			result += "  "
	return result
