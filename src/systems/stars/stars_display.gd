## StarsDisplay — transient CanvasLayer overlay shown after level victory.
##
## Displays 1–3 star icons and the elapsed completion time for
## StarsConfig.DISPLAY_DURATION seconds, then is freed by StarsSystem.
##
## Instantiated at runtime by StarsSystem._show_display(). Not a persistent
## scene node — do not add to the scene tree directly.
##
## Layout:
##   CanvasLayer (layer=20)
##     └── Control (full-rect anchor)
##           ├── Background (ColorRect — semi-transparent black)
##           ├── StarsLabel (Label — star icons)
##           └── TimeLabel  (Label — "Completed in X.Xs")
##
## Implements: design/gdd/stars-scoring.md
class_name StarsDisplay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const STAR_FILLED: String = "⭐"
const STAR_EMPTY:  String = "☆"
const BG_COLOR:    Color  = Color(0.0, 0.0, 0.0, 0.6)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Populate and show the display. Call immediately after add_child().
## stars: 1–3. elapsed: completion time in seconds.
func initialize(stars: int, elapsed: float) -> void:
	layer = 20

	# Root control — fills the viewport.
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Semi-transparent background.
	var bg: ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Container centred on screen.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(vbox)

	# Stars row.
	var stars_label: Label = Label.new()
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.text = _build_stars_string(stars)
	vbox.add_child(stars_label)

	# Time row.
	var time_label: Label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.text = "Completed in %.1fs" % elapsed
	vbox.add_child(time_label)

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
