# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does signal-driven cell-coincidence detection correctly handle
#            all pickup collection and exit-unlock states?
# Date: 2026-03-22
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal pickup_collected(col: int, row: int)
signal all_pickups_collected()
signal exit_unlocked()
signal player_reached_exit()

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum ExitState { LOCKED, OPEN }
enum SystemState { IDLE, ACTIVE, ALL_COLLECTED, COMPLETE }

# ---------------------------------------------------------------------------
# Public read-only properties (HUD consumes these)
# ---------------------------------------------------------------------------

var pickups_total: int = 0
var pickups_remaining: int = 0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _pickup_cells: Array[Vector2i] = []
var _initial_pickup_cells: Array[Vector2i] = []
var _exit_cell: Vector2i = Vector2i(-1, -1)
var _exit_state: ExitState = ExitState.LOCKED
var _system_state: SystemState = SystemState.IDLE

# ---------------------------------------------------------------------------
# Lifecycle API (called by Level System)
# ---------------------------------------------------------------------------

func init(pickup_cells: Array[Vector2i], exit_cell: Vector2i) -> void:
	_pickup_cells = pickup_cells.duplicate()
	_initial_pickup_cells = pickup_cells.duplicate()
	_exit_cell = exit_cell
	_exit_state = ExitState.LOCKED
	pickups_total = pickup_cells.size()
	pickups_remaining = pickups_total

	# EC-01: zero-treasure level → exit opens immediately
	if pickups_total == 0:
		_exit_state = ExitState.OPEN
		_system_state = SystemState.ALL_COLLECTED
		all_pickups_collected.emit()
		exit_unlocked.emit()
	else:
		_system_state = SystemState.ACTIVE


func reset() -> void:
	_pickup_cells = _initial_pickup_cells.duplicate()
	pickups_remaining = pickups_total
	_exit_state = ExitState.LOCKED
	_system_state = SystemState.IDLE if pickups_total == 0 else SystemState.ACTIVE

# ---------------------------------------------------------------------------
# Input: player_moved signal handler
# ---------------------------------------------------------------------------

func on_player_moved(_from: Vector2i, to: Vector2i) -> void:
	if _system_state == SystemState.IDLE or _system_state == SystemState.COMPLETE:
		return

	# Check pickup collection first
	var idx: int = _pickup_cells.find(to)
	if idx != -1:
		_pickup_cells.remove_at(idx)
		pickups_remaining -= 1
		pickup_collected.emit(to.x, to.y)

		if pickups_remaining == 0:
			_system_state = SystemState.ALL_COLLECTED
			_exit_state = ExitState.OPEN
			all_pickups_collected.emit()
			exit_unlocked.emit()

	# Check exit cell
	if to == _exit_cell:
		if _exit_state == ExitState.OPEN:
			_system_state = SystemState.COMPLETE
			player_reached_exit.emit()
		# EC-02: locked exit — no signal, no effect
