## CameraConfig — tuning constants for CameraController.
##
## Implements: design/gdd/camera-system.md
class_name CameraConfig
extends Resource

## Camera smoothing speed passed to Camera2D.position_smoothing_speed.
## Higher values = snappier tracking. Range: 1.0 (very slow) – 20.0 (near-instant).
@export var smooth_speed: float = 5.0
