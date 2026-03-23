## EnemyConfig — Tuning knobs for the Enemy AI controller.
##
## Create a .tres instance and assign to EnemyController.config to override defaults.
##
## Implements: design/gdd/ai-system.md#AI-01
class_name EnemyConfig
extends Resource

## Number of grid cells the enemy can detect the player from.
@export var detection_range: int = 8

## Movement speed in grid steps per second.
@export var move_speed: float = 5.0

## Seconds the enemy waits in a trapped hole before respawning.
@export var trap_escape_time: float = 8.0

## Seconds after death before respawning at rescue position.
@export var respawn_delay: float = 2.0
