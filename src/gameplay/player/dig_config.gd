class_name DigConfig
extends Resource

## Duration in seconds of the dig cooldown before the player can dig again.
## Keep in sync with TerrainConfig.close_timer_slow / close_timer_fast.
@export var dig_duration: float = 0.5

## Cooldown in seconds before the player can issue another dig.
@export var dig_cooldown: float = 0.5
