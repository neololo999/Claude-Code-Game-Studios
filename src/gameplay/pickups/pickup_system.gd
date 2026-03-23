## PickupSystem — treasure pickup tracking and exit-unlock logic for Dig & Dash.
##
## Listens to PlayerMovement.player_moved, erases collected cells from an O(1)
## Dictionary registry, and emits four ordered signals per the GDD contract:
##   pickup_collected → all_pickups_collected → exit_unlocked → player_reached_exit
##
## Lifecycle:
##   1. Add PickupSystem as a child of your Level node.
##   2. Call setup() to inject GridSystem + PlayerMovement dependencies.
##   3. Call initialize() with pickup positions and the exit cell for each level.
##   4. Call reset() on level restart to restore initial state without re-emitting
##      the zero-pickup edge-case signals.
##
## Implements: design/gdd/pickup-system.md
## Sprint:     production/sprints/sprint-02.md#PICK-01
class_name PickupSystem
extends Node

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum _ExitState { LOCKED, OPEN }

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when player collects a treasure. `remaining` is the new count after collection.
signal pickup_collected(col: int, row: int, remaining: int)

## Emitted when all treasures are collected (simultaneously with the last pickup_collected).
signal all_pickups_collected()

## Emitted when the exit becomes accessible (same frame as all_pickups_collected,
## or immediately during initialize() if 0 pickups — EC-01).
signal exit_unlocked()

## Emitted when player enters the open exit cell.
signal player_reached_exit()

# ---------------------------------------------------------------------------
# Public variables
# ---------------------------------------------------------------------------

## Total treasures registered at the last initialize() call.
## Stays constant across reset() calls.
var pickups_total: int = 0

## Number of uncollected treasures remaining.
## Backed by the live _pickup_cells Dictionary — always reflects current state.
var pickups_remaining: int:
	get: return _pickup_cells.size()

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

var _grid: GridSystem
var _player: PlayerMovement

## Active pickup registry. Dictionary[Vector2i, bool] for O(1) has/erase.
## NOTE: Typed dictionary (Godot 4.4+) — spec wrote untyped Dictionary,
## upgraded here to satisfy the project's mandatory static-typing standard.
var _pickup_cells: Dictionary[Vector2i, bool] = {}

## Snapshot at initialize() time, used to restore state in reset().
var _initial_pickup_cells: Array[Vector2i] = []

var _exit_cell: Vector2i = Vector2i(-1, -1)
var _exit_state: _ExitState = _ExitState.LOCKED

## True once setup() completes. Guards _on_player_moved against spurious calls.
var _is_setup: bool = false

# ---------------------------------------------------------------------------
# Public methods — Lifecycle
# ---------------------------------------------------------------------------

## Inject dependencies and subscribe to PlayerMovement.player_moved.
## Must be called exactly once before initialize().
func setup(p_grid: GridSystem, p_player: PlayerMovement) -> void:
	_grid = p_grid
	_player = p_player
	_player.player_moved.connect(_on_player_moved)
	_is_setup = true


## Register pickup positions and exit cell for this level.
##
## Clears any previous state before populating the new registry.
## EC-01: if pickup_cells is empty, emits all_pickups_collected + exit_unlocked
##        immediately so callers can skip waiting for a zero-pickup level.
func initialize(pickup_cells: Array[Vector2i], p_exit_cell: Vector2i) -> void:
	_pickup_cells.clear()
	_initial_pickup_cells = pickup_cells.duplicate()
	pickups_total = pickup_cells.size()
	for cell: Vector2i in pickup_cells:
		_pickup_cells[cell] = true
	_exit_cell = p_exit_cell
	_exit_state = _ExitState.LOCKED
	# EC-01: zero pickups → immediately open the exit.
	if pickup_cells.is_empty():
		_exit_state = _ExitState.OPEN
		all_pickups_collected.emit()
		exit_unlocked.emit()


## Restore all pickups to initial state. Called by Level System on restart.
##
## Intentionally does NOT re-emit the EC-01 zero-pickup signals — the Level
## System is responsible for wiring any "level complete at spawn" logic.
func reset() -> void:
	_pickup_cells.clear()
	for cell: Vector2i in _initial_pickup_cells:
		_pickup_cells[cell] = true
	_exit_state = _ExitState.LOCKED

# ---------------------------------------------------------------------------
# Signal callbacks (private)
# ---------------------------------------------------------------------------

## Connected to PlayerMovement.player_moved in setup().
##
## Two independent checks per move (order matters — collect first, then exit):
##   1. If to_cell is a registered pickup, erase it and emit pickup_collected.
##      When the registry empties, also emit all_pickups_collected + exit_unlocked.
##   2. If to_cell equals the exit cell and the exit is OPEN, emit player_reached_exit.
##      (Collecting the last pickup and stepping onto the exit in the same move
##       is handled correctly because check 1 sets _exit_state = OPEN before check 2.)
func _on_player_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _is_setup:
		return

	# 1. Pickup collection.
	if _pickup_cells.has(to_cell):
		_pickup_cells.erase(to_cell)
		var remaining: int = _pickup_cells.size()
		pickup_collected.emit(to_cell.x, to_cell.y, remaining)
		if remaining == 0:
			_exit_state = _ExitState.OPEN
			all_pickups_collected.emit()
			exit_unlocked.emit()

	# 2. Exit check.
	if to_cell == _exit_cell and _exit_state == _ExitState.OPEN:
		player_reached_exit.emit()
