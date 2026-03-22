# Current Best Practices — Godot 4.6.1

*Last verified: 2026-03-22*

Best practices for Godot 4.6.1, with emphasis on 2D tile-based game development.

---

## TileMap Best Practices

### 1. Use TileMapLayer, Not TileMap
The `TileMap` node is fully deprecated. Always use `TileMapLayer` nodes.
Each layer is its own node in the scene tree, giving better control over
rendering order, collision, and performance.

### 2. Strategic Layering
Use multiple `TileMapLayer` nodes for different purposes:
- **Ground layer** — Base terrain (bricks, metal, sand, etc.)
- **Background layer** — Visual decorations behind the player
- **Foreground layer** — Visual elements in front of the player
- **Collision layer** — If needed separately from visual layers
- **Navigation layer** — For AI pathfinding

### 3. Leverage Chunk TileMap Physics (4.5+)
The engine automatically merges individual tile collision bodies into larger
shapes. This dramatically improves performance for large tile maps. No code
changes needed — it's automatic.

**Tip**: If you need to detect collisions with individual tiles, use
`TileMapLayer.get_cell_source_id()` at the collision point rather than
relying on individual body signals.

### 4. Scene Collection Source (4.6+)
For tiles that need custom behavior (e.g., animated treasures, destructible
blocks), use **Scene Collection Source** in TileSet. This embeds entire
scenes as tiles, allowing per-tile scripts and animations.

### 5. Terrain Sets for Autotiling
Use terrain sets (autotiling) for natural transitions between terrain types.
Especially useful for creating smooth edges between brick and metal areas.

### 6. Y-Sorting
When mixing `TileMapLayer` nodes with sprite-based entities (player, enemies),
enable Y-sorting on parent nodes to ensure correct visual depth ordering.

---

## GDScript Best Practices (4.6.1)

### 1. Use Typed Variables
```gdscript
# Prefer typed over untyped
var speed: float = 200.0
var grid_pos: Vector2i = Vector2i.ZERO
var enemies: Array[Enemy] = []
var tile_data: Dictionary[Vector2i, int] = {}  # Typed dict (4.4+)
```

### 2. Use Signals for Decoupling
```gdscript
# Define signals with typed parameters
signal treasure_collected(position: Vector2i, value: int)
signal enemy_trapped(enemy: CharacterBody2D, hole_position: Vector2i)
signal level_completed(stars: int)
```

### 3. Use @export for Inspector Editing
```gdscript
@export var move_speed: float = 200.0
@export var dig_duration: float = 0.5
@export var hole_close_delay: float = 3.0
@export_range(1, 5) var difficulty: int = 1
```

### 4. Use Groups for Entity Management
```gdscript
# Add enemies to "enemies" group
# Then find them without hardcoded paths:
var all_enemies = get_tree().get_nodes_in_group("enemies")
```

### 5. Delta Time for All Movement
```gdscript
func _physics_process(delta: float) -> void:
    velocity = direction * move_speed  # move_speed is per-second
    move_and_slide()  # Uses delta internally
```

---

## Performance Best Practices

### 1. 2D Rendering
- Use **Compatibility** renderer for best 2D performance (not Forward+)
  unless you need advanced visual effects
- Keep draw calls under 200 for smooth 60fps
- Use texture atlases for tilesets — one large texture is faster than many small ones

### 2. Physics
- Use `CharacterBody2D` for player and enemies (not `RigidBody2D`)
- Chunk TileMap Physics handles tile collision optimization automatically
- Minimize physics layers — only enable collision between layers that need it

### 3. Node Count
- Keep total node count reasonable (< 1000 for most 2D games)
- Use object pooling for frequently created/destroyed objects (particles, effects)
- Prefer `TileMapLayer` tiles over individual Sprite2D nodes for grid elements

---

## Project Organization

```
project/
├── project.godot
├── src/
│   ├── player/
│   │   ├── player.gd
│   │   └── player.tscn
│   ├── enemies/
│   │   ├── guard.gd
│   │   ├── guard.tscn
│   │   └── enemy_ai.gd
│   ├── grid/
│   │   ├── grid_manager.gd
│   │   ├── dig_system.gd
│   │   └── terrain_types.gd
│   ├── levels/
│   │   ├── level_base.gd
│   │   ├── level_base.tscn
│   │   └── level_loader.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── hud.tscn
│   │   ├── main_menu.gd
│   │   └── main_menu.tscn
│   └── autoload/
│       ├── game_manager.gd
│       └── audio_manager.gd
├── assets/
│   ├── sprites/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── tilesets/
│   │   └── ui/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
├── levels/
│   ├── world_1/
│   │   ├── level_01.tscn
│   │   └── ...
│   └── world_2/
└── tests/
    └── ...
```

---

## Common Patterns for Dig & Dash

### Grid-Based Movement
```gdscript
# Snap movement to grid
const TILE_SIZE: int = 32

func move_to_grid(target: Vector2i) -> void:
    var world_pos = Vector2(target) * TILE_SIZE
    # Use tween for smooth visual movement
    var tween = create_tween()
    tween.tween_property(self, "position", world_pos, 0.15)
```

### Digging with Timer
```gdscript
func dig(direction: Vector2i) -> void:
    var dig_target = grid_position + direction
    if can_dig(dig_target):
        terrain_layer.set_cell(dig_target, -1)  # Remove tile
        # Start refill timer
        var timer = get_tree().create_timer(hole_close_delay)
        timer.timeout.connect(_on_hole_refill.bind(dig_target))

func _on_hole_refill(pos: Vector2i) -> void:
    terrain_layer.set_cell(pos, source_id, atlas_coords)
```
