## MainMenu — world-select screen shown on game launch.
##
## Reads world state from the ProgressionSystem autoload and builds world
## cards dynamically. One card per world; unlocked worlds have an active
## Start button, locked worlds are greyed out.
##
## Navigation: arrow keys / gamepad d-pad cycle focus between cards.
## Pressing Enter / ui_accept on an unlocked card starts that world.
##
## Null-safe: if ProgressionSystem autoload is not registered, shows a
## single fallback card that launches level_001 directly.
##
## Implements: design/gdd/main-menu.md
class_name MainMenu
extends Control

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const LEVEL_SCENE: String = "res://scenes/levels/level_01.tscn"
const CARD_MIN_WIDTH: int  = 180
const CARD_SPACING: int    = 20
const LOCKED_ALPHA: float  = 0.45
## Type alias — ProgressionSystem has no class_name (conflicts with autoload).
const _ProgSys := preload("res://src/systems/progression/progression_system.gd")

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _card_buttons: Array[Button] = []

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	# Allow Escape to do nothing (no quit from menu in Alpha).
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Background.
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer centred VBox wrapped in a full-rect CenterContainer.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 24)
	center.add_child(outer)

	# Title.
	var title: Label = Label.new()
	title.text = "Dig & Dash"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)

	# Subtitle.
	var subtitle: Label = Label.new()
	subtitle.text = "Select World"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	outer.add_child(subtitle)

	# World cards row.
	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", CARD_SPACING)
	outer.add_child(cards_row)

	var prog: _ProgSys = \
		get_node_or_null("/root/ProgressionSystem") as _ProgSys

	if prog != null:
		for world: WorldData in prog.get_all_worlds():
			var state: Dictionary = prog.get_world_state(world.world_id)
			_build_world_card(cards_row, world.world_id, world.world_name, state)
	else:
		# Fallback: single hard-coded World 1 card.
		push_warning("MainMenu: ProgressionSystem autoload not found — showing fallback card.")
		_build_fallback_card(cards_row)

	# Auto-focus: restore to current world or first card.
	_auto_focus(prog)


func _build_world_card(
		parent: HBoxContainer,
		world_id: String,
		world_name: String,
		state: Dictionary) -> void:

	var unlocked: bool = state.get("unlocked", false)
	var total_stars: int = state.get("total_stars", 0)
	var max_stars: int   = state.get("max_stars", 0)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	if not unlocked:
		panel.modulate.a = LOCKED_ALPHA
	parent.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = world_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	var stars_label: Label = Label.new()
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.text = "%d / %d ⭐" % [total_stars, max_stars]
	vbox.add_child(stars_label)

	var btn: Button = Button.new()
	btn.text = "Start" if unlocked else "🔒 Locked"
	btn.disabled = not unlocked
	btn.custom_minimum_size = Vector2(CARD_MIN_WIDTH - 16, 32)
	if unlocked:
		btn.pressed.connect(_on_start_pressed.bind(world_id))
	vbox.add_child(btn)

	if unlocked:
		_card_buttons.append(btn)


func _build_fallback_card(parent: HBoxContainer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	parent.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = "World 1 – The Mines"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var btn: Button = Button.new()
	btn.text = "Start"
	btn.custom_minimum_size = Vector2(CARD_MIN_WIDTH - 16, 32)
	btn.pressed.connect(_on_fallback_start_pressed)
	vbox.add_child(btn)
	_card_buttons.append(btn)


func _auto_focus(prog: _ProgSys) -> void:
	if _card_buttons.is_empty():
		return
	var focus_idx: int = 0
	if prog != null:
		var current_world: String = prog._save_slot.current_world_id
		var all_worlds: Array[WorldData] = prog.get_all_worlds()
		for i: int in all_worlds.size():
			if all_worlds[i].world_id == current_world \
					and prog.is_world_unlocked(current_world):
				# Find the matching button index (unlocked cards only).
				var unlocked_count: int = 0
				for w: WorldData in all_worlds:
					if prog.is_world_unlocked(w.world_id):
						if w.world_id == current_world:
							focus_idx = unlocked_count
							break
						unlocked_count += 1
				break
	_card_buttons[focus_idx].grab_focus()

# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_start_pressed(world_id: String) -> void:
	var prog: _ProgSys = \
		get_node_or_null("/root/ProgressionSystem") as _ProgSys
	if prog == null:
		_on_fallback_start_pressed()
		return
	# Determine the first level of this world.
	var world_state: Dictionary = prog.get_world_state(world_id)
	var level_ids: Array = world_state.get("level_ids", [])
	var first_level: String = level_ids[0] if not level_ids.is_empty() else "level_001"
	prog.start_level(world_id, first_level)
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_fallback_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)
