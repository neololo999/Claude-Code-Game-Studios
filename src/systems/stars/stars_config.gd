## StarsConfig — par times and star threshold constants for StarsSystem.
##
## Par times are calibrated during VS-INT-01: set each value to 1.2× the
## designer's clean-solve time, rounded to the nearest 5 seconds.
## Placeholder: 60 s/level until calibration is complete.
##
## Implements: design/gdd/stars-scoring.md
class_name StarsConfig
extends Object

## Par time in seconds per level_id.
## 3 stars ≤ par, 2 stars ≤ par × 1.5, 1 star = any completion.
## If a level_id is absent, PAR_DEFAULT is used.
const PAR_TIMES: Dictionary = {
	"level_001": 60.0,
	"level_002": 60.0,
	"level_003": 60.0,
	"level_004": 60.0,
	"level_005": 60.0,
	"level_006": 60.0,
	"level_007": 60.0,
	"level_008": 60.0,
	"level_009": 60.0,
	"level_010": 60.0,
}

## Fallback par time for levels not in PAR_TIMES.
const PAR_DEFAULT: float = 60.0

## Multiplier applied to par_time to define the 2-star threshold.
const TWO_STAR_MULTIPLIER: float = 1.5

## How long (seconds) StarsDisplay remains visible before auto-dismissing.
const DISPLAY_DURATION: float = 2.0
