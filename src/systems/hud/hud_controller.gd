## HUDController — viewport-space HUD for Dig & Dash.
##
## Displays:
##   - Treasure counter  (top-left):  "💎 X / Y"
##   - Dig cooldown bar  (bottom):    depletes during cooldown, fills when READY
##   - Exit indicator    (top-right): hidden until exit unlocked
##
## Node structure (add to CanvasLayer layer=10 in level_01.tscn):
##   HUDController (this script on root CanvasLayer or a Control child)
##     └── TreasureLabel  (Label)
##     └── DigBarBg       (ColorRect — background, full width)
##     └── DigBarFill     (ColorRect — scaled by cooldown ratio)
##     └── ExitLabel      (Label)
##
## Implements: design/gdd/hud-system.md
class_name HUDController
extends CanvasLayer

const MARGIN: int = 8

## Node references — set in _ready via node paths.
@onready var _treasure_label: Label   = $TreasureLabel
@onready var _dig_bar_fill: ColorRect  = $DigBarFill
@onready var _dig_bar_bg: ColorRect    = $DigBarBg
@onready var _exit_label: Label        = $ExitLabel

var _pickups: PickupSystem  = null
var _dig: DigSystem         = null
var _total_pickups: int     = 0
var _collected: int         = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 10
	_update_treasure_label()
	_exit_label.visible = false


func _process(_delta: float) -> void:
	if _dig == null:
		return
	var ratio: float = _dig.get_cooldown_ratio()
	# Bar fill: full width when ready (ratio=0), empty when just started (ratio=1).
	var bar_width: float = _dig_bar_bg.size.x * (1.0 - ratio)
	_dig_bar_fill.size.x = bar_width


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wire signals. Call once in LevelSystem._initialize_level() after all systems set up.
func setup(pickups: PickupSystem, dig: DigSystem, level_sys: LevelSystem) -> void:
	_pickups = pickups
	_dig     = dig

	if not pickups.pickup_collected.is_connected(_on_pickup_collected):
		pickups.pickup_collected.connect(_on_pickup_collected)
	if not pickups.exit_unlocked.is_connected(_on_exit_unlocked):
		pickups.exit_unlocked.connect(_on_exit_unlocked)
	if not level_sys.level_restarted.is_connected(_on_level_restarted):
		level_sys.level_restarted.connect(_on_level_restarted)
	if not level_sys.level_started.is_connected(_on_level_started):
		level_sys.level_started.connect(_on_level_started)


## Reset and set treasure total for a new level. Called by LevelSystem each load.
func initialize(total_pickups: int) -> void:
	_total_pickups = total_pickups
	_collected     = 0
	_update_treasure_label()
	if _exit_label:
		_exit_label.visible = false
	if _dig_bar_fill:
		_dig_bar_fill.size.x = _dig_bar_bg.size.x if _dig_bar_bg else 0.0


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_pickup_collected(_col: int, _row: int, remaining: int) -> void:
	_collected = _total_pickups - remaining
	_update_treasure_label()


func _on_exit_unlocked() -> void:
	_exit_label.visible = true


func _on_level_restarted() -> void:
	_collected = 0
	_update_treasure_label()
	_exit_label.visible = false


func _on_level_started(_index: int) -> void:
	# LevelSystem calls initialize() explicitly — this just ensures label refreshes.
	_update_treasure_label()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_treasure_label() -> void:
	if _treasure_label:
		_treasure_label.text = "%d / %d collected" % [_collected, _total_pickups]
