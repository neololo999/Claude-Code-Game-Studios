## GravityConfig — Tuning knobs for the GridGravity system.
## Implements: design/gdd/grid-gravity.md#tuning-knobs
##
## Invariant: fall_speed should be less than TerrainConfig.dig_duration (0.5s default).
class_name GravityConfig
extends Resource

## Duration of one fall tick (one cell down). Seconds.
@export_range(0.05, 0.5, 0.01) var fall_speed: float = 0.1
