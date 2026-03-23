## TerrainConfig — Tuning knobs for the Terrain System.
## Implements: design/gdd/terrain-system.md#tuning-knobs
##
## Create a .tres instance and assign to TerrainSystem.config to override defaults.
## Invariant: DIG_CLOSE_FAST < DIG_CLOSE_SLOW (logged as warning if violated).
class_name TerrainConfig
extends Resource

## Duration of the digging animation (INTACT → OPEN). Seconds.
@export_range(0.1, 2.0, 0.05) var dig_duration: float = 0.5

## Close timer for DIRT_SLOW cells. Seconds the hole stays open.
@export_range(2.0, 30.0, 0.5) var dig_close_slow: float = 8.0

## Close timer for DIRT_FAST cells. Seconds the hole stays open.
@export_range(1.0, 15.0, 0.5) var dig_close_fast: float = 4.0

## Duration of the closing animation (OPEN → INTACT). Seconds.
@export_range(0.2, 3.0, 0.1) var closing_duration: float = 1.0
