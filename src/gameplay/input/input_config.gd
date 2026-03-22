## InputConfig — Tuning knobs for the Input System.
## Implements: design/gdd/input-system.md#tuning-knobs
##
## Attach a custom .tres instance to InputSystem.config to override defaults.
class_name InputConfig
extends Resource

## Steps per second: how many cells the player crosses per second while holding a direction.
## Tuning range: 3–8. Default 5.0 matches Lode Runner original feel (~200 ms/cell).
@export_range(1.0, 20.0, 0.5) var move_speed: float = 5.0

## Dead-zone threshold for gamepad left-stick / D-pad analog input (0–1).
## Only used when gamepad support is enabled (post-MVP — see OQ-01).
@export_range(0.1, 0.9, 0.05) var gamepad_deadzone: float = 0.5

## Derived from move_speed. Do not set directly.
var move_interval: float:
	get:
		return 1.0 / move_speed
