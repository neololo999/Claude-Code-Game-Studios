## TransitionConfig — tuning constants for TransitionSystem screens.
##
## Implements: design/gdd/transition-screens.md
class_name TransitionConfig
extends RefCounted

## CanvasLayer order for transition screen overlays.
## Must be above StarsDisplay (20) and HUD (10).
const CANVAS_LAYER: int = 30

## Background overlay colour for all transition screens.
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)

## Interval (seconds) for the "Press any key" hint blink on VictoryScreen.
const HINT_BLINK_INTERVAL: float = 0.6
