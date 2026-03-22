# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.6.1 |
| **Project Pinned** | 2026-03-22 |
| **LLM Knowledge Cutoff** | May 2025 (covers up to ~Godot 4.3) |
| **Risk Level** | HIGH — version is beyond LLM training data |

*Last verified: 2026-03-22*

## Summary

Godot 4.6.1 is a maintenance release of Godot 4.6, which was released on
January 26, 2026. The project spans versions 4.4 through 4.6, all of which
are beyond the LLM's training data cutoff (~4.3).

Migration between 4.x minor versions is generally safe, but agents MUST
consult the breaking changes and deprecated APIs documents before suggesting
code patterns.

## Key Changes Since Training Cutoff (4.3 → 4.6.1)

### Godot 4.4 (March 2025)
- **UIDs (Universal IDs)** for all resources — file renames no longer break references
- **Typed Dictionaries** in GDScript
- **Jolt Physics** integration for 3D (optional)
- **Embedded game window** in editor
- **2D batching** improvements for other rendering backends
- **.NET 8** support for C#

### Godot 4.5 (September 2025)
- **Chunk TileMap Physics** — merges individual collision bodies into optimized shapes (critical for our tile-based game)
- **Stencil buffer support**
- **Screen reader support** (accessibility)
- **Shader baker** — pre-compiles shaders during export
- **TileMap editor UI improvements**
- **SDL 3 gamepad input**

### Godot 4.6 (January 2026)
- **New "Modern" editor theme** (default)
- **Jolt Physics default for 3D** (doesn't affect 2D projects)
- **Flexible editor docks** — movable, floatable panels
- **TileMapLayer performance** — avoids unnecessary updates
- **Scene Collection Source for tiles** — embed entire scenes as tiles
- **Unique Node IDs** — refactoring-safe connections
- **ObjectDB snapshots** — debug memory leaks
- **UI focus separation** — mouse and keyboard focus independent
- **Glow processing change** — now before tonemapping, default blend = "screen"
- **D3D12 default renderer** on Windows

## Critical for Dig & Dash (2D Tile-Based Game)

| Feature | Version | Impact |
|---------|---------|--------|
| `TileMapLayer` (replaces `TileMap`) | 4.x | **MUST USE** — `TileMap` is deprecated, use `TileMapLayer` nodes |
| Chunk TileMap Physics | 4.5+ | **Performance** — auto-merges collision bodies, crucial for large levels |
| Scene Collection Source | 4.6+ | **Optional** — embed scenes as tiles for interactive elements |
| Typed Dictionaries | 4.4+ | **Recommended** — stronger typing in GDScript |
| UIDs | 4.4+ | **Auto-applied** — resource references are now UID-based |

## Files in This Directory

- [VERSION.md](VERSION.md) — This file (version pin + knowledge gap)
- [breaking-changes.md](breaking-changes.md) — Version-by-version breaking changes
- [deprecated-apis.md](deprecated-apis.md) — "Don't use X → Use Y" tables
- [current-best-practices.md](current-best-practices.md) — Best practices for 4.6
