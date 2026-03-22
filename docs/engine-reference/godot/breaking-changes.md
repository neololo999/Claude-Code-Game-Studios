# Breaking Changes — Godot 4.3 → 4.6.1

*Last verified: 2026-03-22*

This document covers breaking changes across versions 4.4, 4.5, and 4.6 that
may affect code written against Godot 4.3 APIs.

---

## Godot 4.3 → 4.4

### Core
- **UID system** — All resources now have Universal IDs. When opening a 4.3
  project in 4.4, run the UID upgrade tool to convert resource references.
  `.uid` files will be created alongside resources.
- **Typed Dictionaries** — GDScript now supports typed dictionaries
  (`var d: Dictionary[String, int]`). Existing untyped dictionaries still work.

### TileMap
- `TileMap` node continues to be deprecated in favor of `TileMapLayer`.
  Use the built-in conversion tool if still using `TileMap`.

### Physics
- **Jolt Physics** available as an option for 3D (does not affect 2D projects).

### GDScript
- Typed dictionaries may cause warnings in code that mixes types in dictionaries.
- Minor changes to error messages and diagnostics formatting.

### Rendering
- 2D batching behavior changes for non-default rendering backends.
- **Ubershaders** and **pipeline pre-compilation** may change shader loading behavior.

---

## Godot 4.4 → 4.5

### TileMap (Critical for Dig & Dash)
- **Chunk TileMap Physics** — Collision bodies for tiles are now automatically
  merged into larger shapes. This is a performance improvement but may change
  collision behavior if code relied on individual tile collision bodies.
  - If you used `body_entered` signals on individual tiles, test that detection
    still works as expected.
  - The optimization is automatic and generally transparent.

### Input
- **SDL 3 gamepad input** replaces SDL 2. Gamepad mappings may differ slightly.

### Rendering
- Stencil buffer changes may affect custom shaders that assumed no stencil.
- Minor SMAA and ambient occlusion behavior changes.

### Accessibility
- Screen reader support adds new properties to UI nodes. Existing code unaffected.

---

## Godot 4.5 → 4.6

### GUI / UI (May affect menus)
- **UI Focus separation** — Mouse focus and keyboard focus are now independent.
  Code that relied on a unified `focus_entered` / `focus_exited` behavior may
  need adjustment. Specifically:
  - `Control.focus_mode` behavior is unchanged
  - But styling and visual feedback for focus may now differ between mouse
    and keyboard interactions
  - Test all UI navigation code

### Rendering
- **Glow processing** now occurs before tonemapping (was after). Default blend
  mode changed to "screen". Visual appearance of glow effects will change.
  Review any scenes using glow.
- **D3D12 is default renderer** on Windows for new projects. Existing projects
  keep their renderer setting.

### TileMap
- **TileMapLayer** nodes now avoid unnecessary updates — performance improvement,
  no API changes.
- **Scene Collection Source** — New feature allowing scenes as tiles. No breaking
  changes, purely additive.

### Editor
- **New "Modern" theme** is now default. No code impact.
- **Unique Node IDs** — Nodes get internal unique IDs for safer refactoring.
  No API changes, purely internal improvement.
- **Flexible docks** — Editor UX change, no code impact.

### GDScript
- **Language server improvements** — Better docstring rendering.
- **Debugger "Step Out"** button — New debugging feature, no code impact.

### GDExtension
- Parameters and return values can be declared as `required`.
- Interface is now JSON-based. Only affects native extensions, not GDScript.

---

## Summary: Impact on Dig & Dash

| Area | Risk | Action Required |
|------|------|----------------|
| TileMap → TileMapLayer | ⚠️ Medium | Use `TileMapLayer` from the start (not deprecated `TileMap`) |
| Chunk Physics | ✅ Low | Automatic optimization, test collision signals |
| UI Focus | ⚠️ Medium | Test menu navigation with keyboard and mouse |
| Glow Effects | ✅ Low | Review visual settings if using glow |
| UID System | ✅ Low | Automatic for new projects |
| Typed Dictionaries | ✅ Low | Use for cleaner code, not required |
