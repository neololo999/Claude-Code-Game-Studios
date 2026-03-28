class_name ArcadeHUD
extends CanvasLayer
## Simplified HUD for arcade mode - displays pickup counter and handles back/retry inputs.

@onready var _pickup_label: Label = $PickupLabel

var _pickups: PickupSystem = null
var _total: int = 0
var _collected: int = 0

signal back_requested
signal retry_requested


func _ready() -> void:
	layer = 10
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry"):
		retry_requested.emit()
		get_viewport().set_input_as_handled()


func setup(pickups: PickupSystem) -> void:
	_pickups = pickups
	if not pickups.pickup_collected.is_connected(_on_pickup_collected):
		pickups.pickup_collected.connect(_on_pickup_collected)


func initialize(total_pickups: int) -> void:
	_total = total_pickups
	_collected = 0
	_update_label()


func _on_pickup_collected(_col: int, _row: int, remaining: int) -> void:
	_collected = _total - remaining
	_update_label()


func _update_label() -> void:
	if _pickup_label:
		_pickup_label.text = "💎 %d / %d" % [_collected, _total]
