class_name PickupSprite
extends Sprite2D
## Auto-hides when its grid cell is collected.
## Attach to pickup Sprite2D nodes and set grid_cell to match the Marker2D position.

## The grid cell this pickup represents (set by parent or in inspector)
@export var grid_cell: Vector2i = Vector2i.ZERO

var _pickups: PickupSystem = null


func setup(pickups: PickupSystem, cell: Vector2i) -> void:
	_pickups = pickups
	grid_cell = cell
	if not pickups.pickup_collected.is_connected(_on_pickup_collected):
		pickups.pickup_collected.connect(_on_pickup_collected)


func _on_pickup_collected(col: int, row: int, _remaining: int) -> void:
	if col == grid_cell.x and row == grid_cell.y:
		visible = false
