# ADR-001 — Migration du pipeline de création de niveaux vers TileMapLayer

> **Status**: Accepted
> **Date**: 2026-03-25
> **Décideurs**: Laurent VEYRET (solo dev)
> **Contexte projet**: Dig & Dash — puzzle-platformer tactique sur grille
> **Lié à**: Sprint 10 (tâche LEVELS-PIPELINE-01)

---

## Contexte

Depuis Sprint 4, tous les niveaux de Dig & Dash sont définis dans
`src/gameplay/level/level_builder.gd` sous forme de fonctions GDScript statiques
(`_level_001()` à `_level_010()`). Chaque niveau encode sa grille de terrain en
ASCII et ses entités (joueur, ennemis, trésors) en coordonnées hardcodées.

Ce système a servi efficacement pendant le MVP et le Vertical Slice : niveaux 100%
versionnés en texte, aucune dépendance à des fichiers `.tres` complexes, intégration
simple avec `LevelSystem.load_level()`.

### Limites identifiées (2026-03-25)

| Limite | Impact concret |
|--------|---------------|
| Pas de feedback visuel pendant le design | Le level designer doit tenir la grille en mémoire |
| Boucle d'itération lente | Modifier le code → relancer Godot → tester → recommencer |
| Placement des entités en coordonnées hardcodées | Pas de drag-and-drop; erreurs fréquentes |
| Grilles ASCII illisibles au-delà de ~15×12 | Les niveaux Alpha (multi-rooms) seront ingérables |
| Impossible d'utiliser les outils visuels de Godot | Paint tiles, sélections, mirroring — tout inaccessible |

Le **GDD `game-concept.md` identifiait ce risque** : *"Level design tooling — Créer
60 niveaux nécessite un outil interne efficace."*

### Signal d'alerte dans le code

Le commit `14805c0` (2026-03-25) a introduit trois éléments révélateurs :
- `LevelTileMapBuilder` : convertit `LevelBuilder` → `TileMapLayer` pour *visualiser*
  le code dans l'éditeur (workaround, pas une solution)
- `TerrainVisualizer` : debug visuel des tiles en runtime
- `level_02.tscn` : premier vrai niveau en scène avec `TileMapLayer`

Ces trois ajouts indiquent que le pipeline code-first atteint ses limites créatives.

---

## Décision

**Nous migrons vers un pipeline TileMapLayer-first pour l'authoring de niveaux.**

À partir de Sprint 10, la **source de vérité d'un niveau** est une scène `.tscn`
contenant :
1. Un `TileMapLayer` pour le terrain (tiles visuels + Custom Data pour les
   propriétés gameplay)
2. Des nœuds enfants positionnés visuellement pour les entités
   (joueur spawn, ennemis, trésors, sortie)

`LevelBuilder` devient un artefact legacy conservé en lecture seule pour les tests
et la compatibilité. Il ne reçoit plus de nouveaux niveaux.

### Pipeline cible

```
Godot Editor
  ╔══════════════════════╗
  ║  TileMapLayer        ║  ← Level designer dessine visuellement
  ║  + Entity nodes      ║  ← Ennemis, trésors, sortie en drag-and-drop
  ╚══════════════════════╝
            │
            │  commit .tscn dans Git
            ▼
  LevelSystem.load_level("level_001")
            │
            │  LevelSceneParser.parse(scene)
            ▼
  LevelData (in-memory)   ← même structure qu'aujourd'hui
            │
            ▼
  TerrainSystem / DigSystem / etc.  ← inchangés
```

**Le `TerrainSystem`, `DigSystem`, `GridSystem` et tous les systèmes gameplay
ne changent pas.** Seul le chemin de création de `LevelData` change.

---

## Alternatives considérées

### A. Garder LevelBuilder + améliorer les outils de visualisation

*Approche actuelle avec `LevelTileMapBuilder` et `TerrainVisualizer`.*

**Pros** :
- Niveaux 100% en GDScript, diff propre dans Git
- Aucune migration nécessaire

**Cons** :
- Les outils de visualisation restent des workarounds (tu vois après coup, tu ne
  **designs pas** visuellement)
- Impossible d'exploiter Paint Tiles, Terrain Autotile, sélections rectangulaires
- Scalabilité nulle pour 60 niveaux

### B. Fichiers `.tres` LevelData sérialisés

Exporter `LevelData` comme ressource `.tres` via le `ResourceSaver`.

**Pros** : Format natif Godot, chargement rapide

**Cons** :
- `PackedInt32Array` en `.tres` = blobs illisibles dans Git (anti-pattern déjà
  identifié lors du choix de LevelBuilder en Sprint 4)
- Toujours pas d'édition visuelle

### C. Custom Godot Editor Plugin

Plugin dédié avec une grille 2D interactive.

**Pros** : UX optimale

**Cons** :
- 2-3 semaines de dev outil vs. TileMapLayer existant nativement
- Sur-engineering pour un solo dev

### D. Migration TileMapLayer (choisie)

**Pros** :
- Norme Godot 4 pour les grid-based games
- Outils natifs : Paint, Select, Terrain Autotile, Mirror, Undo/Redo illimité
- Feedback visuel immédiat
- `.tscn` lisible en texte dans Git (diff utile sur les nœuds)
- Entités = nœuds enfants → positionnement visuel, nommage explicite
- Scalable à 60+ niveaux sans coût supplémentaire

**Cons** :
- Migration des 10 niveaux existants (estimé : 0.5d avec `LevelTileMapBuilder`)
- Bridge `TileMapLayer → LevelData` à implémenter (estimé : 1.0d)

---

## Conséquences

### Positives

- **Vitesse de création multipliée** : un niveau Alpha (~20×15) en 30-60 min vs.
  plusieurs heures en code
- **Itération créative réelle** : on peut essayer une disposition, la voir, la
  corriger instantanément
- **Artiste peut contribuer** : un collaborateur non-programmeur peut créer des
  niveaux sans toucher à GDScript
- **Tilemaps natifs** : autotiling, variations de sprites par tile, animations
  de terrain — tout devient accessible pour la Full Vision

### Négatives / Risques

| Risque | Mitigation |
|--------|-----------|
| Migration des 10 niveaux existants | `LevelTileMapBuilder` déjà créé; migration quasi-automatique |
| Bridge `TileMapLayer → LevelData` introduit une couche supplémentaire | Le bridge est simple (~80 lignes) et ne touche pas les systèmes gameplay |
| `.tscn` plus verbeux que GDScript pour des grilles simples | Acceptable; la lisibilité Git sur les nœuds entités compense |
| Custom Data Layers doivent être configurés sur le Tileset | Une seule fois; configuration partagée entre tous les niveaux |

### Impact sur le sprint plan

| Sprint | Tâche ajoutée |
|--------|--------------|
| **Sprint 10** | `LEVELS-PIPELINE-01` : Implémenter `LevelSceneParser` (bridge TileMapLayer → LevelData) + porter les niveaux 001–010 en `.tscn` |
| Sprint 10+ | Tous les nouveaux niveaux créés en `.tscn` uniquement |
| Alpha close | `LevelBuilder` déprécié (marqué `@deprecated`, conservé pour les tests) |

---

## Spécification technique du bridge

### `LevelSceneParser` (nouveau, ~80 lignes)

```gdscript
## Construit un LevelData à partir d'une scène contenant un TileMapLayer.
## Nœuds convention :
##   - TileMapLayer nommé "TerrainMap"  → terrain_map
##   - Node2D nommé "PlayerSpawn"       → player_start_col/row
##   - Node2D[] dans groupe "enemies"   → enemy_spawns
##   - Node2D[] dans groupe "pickups"   → pickup_positions
##   - Node2D nommé "Exit"              → exit_col/row
class_name LevelSceneParser
extends RefCounted

static func parse(scene_root: Node) -> LevelData:
    ...
```

### Custom Data Layer sur le Tileset

| Layer name | Type | Valeur |
|------------|------|--------|
| `terrain_type` | `int` | 0=EMPTY, 1=SOLID, 2=DIRT_SLOW, 3=DIRT_FAST, 4=LADDER, 5=ROPE |

### Convention de nommage des nœuds

```
Level001 (Node — root)
├── TerrainMap (TileMapLayer)
├── PlayerSpawn (Node2D — position = grid coords × cell_size)
├── Exit (Node2D)
├── Enemies (Node)
│   ├── Enemy (Node2D — groupe "enemies")
│   └── Enemy (Node2D — groupe "enemies")
└── Pickups (Node)
    ├── Pickup (Node2D — groupe "pickups")
    └── Pickup (Node2D — groupe "pickups")
```

---

## Norme Godot 4 — Référence

Cette décision s'aligne avec les best practices Godot 4 pour les grid-based games :

- **TileMapLayer** (Godot 4.2+) est la classe recommandée ; `TileMap` est déprécié
- Les **Custom Data Layers** sur le `TileSet` sont le mécanisme canonique pour
  attacher des propriétés gameplay aux tiles (vs. lire les atlas IDs au runtime)
- Les niveaux comme **scènes instanciables** (`PackedScene`) sont le pattern
  recommandé pour les jeux à niveaux multiples
- `get_tree().change_scene_to_packed()` / `change_scene_to_file()` est l'API
  de navigation entre niveaux utilisée en production

Sources : `docs/engine-reference/godot/current-best-practices.md`,
`docs/engine-reference/godot/modules/`

---

*Document owner: Laurent VEYRET | Created: 2026-03-25*
