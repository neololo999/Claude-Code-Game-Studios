# Deprecated APIs — Godot 4.3 → 4.6.1

*Last verified: 2026-03-22*

This document lists APIs deprecated between Godot 4.3 and 4.6.1 with their
recommended replacements. Agents MUST check this before suggesting code.

---

## TileMap (Most relevant for Dig & Dash)

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| `TileMap` node | `TileMapLayer` node(s) | 4.0+ (fully deprecated) | Use multiple `TileMapLayer` nodes for different layers. Godot provides a conversion tool. |
| `TileMap.set_cell(layer, coords, ...)` | `TileMapLayer.set_cell(coords, ...)` | 4.0+ | Each `TileMapLayer` is its own node, no layer index needed |
| `TileMap.get_cell_source_id(layer, coords)` | `TileMapLayer.get_cell_source_id(coords)` | 4.0+ | Same pattern — remove layer parameter |
| `TileMap.get_used_cells(layer)` | `TileMapLayer.get_used_cells()` | 4.0+ | Same pattern |
| `TileMap.local_to_map(pos)` | `TileMapLayer.local_to_map(pos)` | 4.0+ | Same API, different node |
| `TileMap.map_to_local(coords)` | `TileMapLayer.map_to_local(coords)` | 4.0+ | Same API, different node |

## Core / General

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| Untyped `Dictionary` (no warning, but discouraged) | `Dictionary[KeyType, ValueType]` | 4.4 | Typed dictionaries provide better safety. Not a hard deprecation. |
| Resource paths without UIDs | UID-based references | 4.4 | New projects auto-use UIDs. Existing path-based references still work. |

## Physics

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| Individual tile collision bodies | Chunk-merged collision bodies (automatic) | 4.5 | Not an API deprecation — the engine automatically optimizes. Code that iterated over individual tile bodies may behave differently. |

## Rendering

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| Glow post-tonemapping | Glow pre-tonemapping | 4.6 | Not an API change — behavioral change. Glow now processes before tonemapping with "screen" blend default. |

## UI / Control

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| Unified mouse+keyboard focus | Separated mouse/keyboard focus | 4.6 | Not a hard deprecation — `focus_mode` still works. But focus visual feedback may differ between input methods. |

---

## Usage Pattern: TileMapLayer (Correct for 4.6.1)

### ❌ Old way (deprecated TileMap with layers)
```gdscript
# Don't do this — TileMap node is deprecated
var tilemap = $TileMap
tilemap.set_cell(0, Vector2i(5, 3), 1, Vector2i(0, 0))  # layer 0
tilemap.set_cell(1, Vector2i(5, 3), 2, Vector2i(0, 0))  # layer 1
var cell = tilemap.get_cell_source_id(0, Vector2i(5, 3))
```

### ✅ New way (TileMapLayer nodes)
```gdscript
# Use separate TileMapLayer nodes
var ground_layer = $GroundLayer   # TileMapLayer node
var entity_layer = $EntityLayer   # TileMapLayer node

ground_layer.set_cell(Vector2i(5, 3), 1, Vector2i(0, 0))
entity_layer.set_cell(Vector2i(5, 3), 2, Vector2i(0, 0))
var cell = ground_layer.get_cell_source_id(Vector2i(5, 3))
```

### Scene tree structure
```
Level (Node2D)
├── GroundLayer (TileMapLayer)     # Bricks, metal, sand, ice, wood
├── DecorationLayer (TileMapLayer) # Visual-only decorations
├── CollectibleLayer (TileMapLayer)# Treasures
├── Player (CharacterBody2D)
└── Enemies (Node2D)
    ├── Guard1 (CharacterBody2D)
    └── Guard2 (CharacterBody2D)
```
