# Level System (Système de niveau)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Puzzle d'abord · Tension constante · Lisibilité parfaite

## Overview

Le Level System est l'**orchestrateur** du jeu. Il charge les données d'un niveau,
initialise tous les sous-systèmes avec les informations contenues dans cette donnée
(grille, terrain, positions de spawn, trésors, sortie, gardiens), et gère le cycle
de vie complet d'un niveau : démarrage, mort et restart, victoire, et passage au
niveau suivant.

C'est le seul système qui connaît l'existence de tous les autres. Chaque autre
système est un silos indépendant — le Level System est le chef d'orchestre qui
les fait jouer ensemble.

**Responsabilités :**
- Charger les données de niveau depuis un fichier `LevelData` Resource
- Appeler `init()` et `reset()` sur tous les sous-systèmes dans l'ordre correct
- Écouter les événements critiques : `enemy_reached_player`, `player_reached_exit`
- Déclencher la mort du joueur, le restart, et la victoire
- Maintenir le compteur de morts (vies illimitées au MVP, stat uniquement)
- Séquencer les niveaux (passer au suivant après victoire)
- Exposer l'état global au HUD : niveau en cours, morts, trésors restants

**Hors scope :**
- Rendu, UI, écrans de transition (Transition Screens — Vertical Slice)
- Timer de niveau et étoiles de performance (Stars/Scoring — Vertical Slice)
- Progression méta, déblocage de mondes (Progression/Worlds — Alpha)
- Sauvegarde de progression (Save System — Alpha)
- Éditeur de niveaux (Level Design Tooling — Full Vision)

## Player Fantasy

Le joueur ne voit jamais le Level System — il ne ressent que son travail.

Ce qui compte pour l'expérience : le niveau **démarre sans accroc**, le restart
après une mort est **instantané et frustration-free**, et la transition vers le
niveau suivant **valide la victoire sans briser le rythme**.

Dans Dig & Dash, le restart est une mécanique de jeu fondamentale. Le joueur
mort régulièrement en expérimentant — c'est le cœur de l'apprentissage du puzzle.
Un restart en dessous de 300ms (fondu rapide) signifie que le joueur peut
itérer sans rupture de concentration. La mort ne doit pas punir, elle doit
enseigner.

La **victoire** est un moment de satisfaction pure : le joueur a résolu le puzzle,
il entre dans la sortie, et le système l'amène vers le prochain défi sans friction.

*Piliers servis : Puzzle d'abord (le restart rapide encourage l'expérimentation),
Tension constante (le niveau démarre avec tous les gardiens actifs dès le début),
Lisibilité parfaite (state global clair pour le joueur à tout moment).*

## Detailed Design

### Core Rules

**Règle 1 — Source de vérité unique : LevelData**
Chaque niveau est défini par une `LevelData` Resource Godot. Ce fichier contient
toutes les données nécessaires à initialiser le niveau : grille, terrain, positions
de spawn, pickups, sortie, gardiens. Aucun sous-système ne lit les données de
niveau directement — tout passe par le Level System.

**Règle 2 — Séquence d'initialisation stricte**
L'initialisation suit un ordre précis pour respecter les dépendances entre systèmes :
1. Grid System — définit les dimensions de la grille
2. Terrain System — charge la carte de terrain (dépend de Grid)
3. Grid Gravity — s'enregistre avec les dimensions (dépend de Grid)
4. Player Movement — place le joueur au spawn (dépend de Grid, Terrain, Gravity)
5. Enemy AI — place les gardiens à leurs spawns (dépend de Grid, Terrain, Gravity)
6. Pickup System — enregistre positions des trésors et de la sortie
7. Input System — activé (le joueur peut jouer)

**Règle 3 — Vies illimitées au MVP**
Il n'y a pas de compteur de vies. Le joueur peut mourir et recommencer autant de
fois que nécessaire. `death_count` est maintenu comme statistique uniquement
(pour Stars/Scoring futur).

**Règle 4 — Restart = reset de tous les sous-systèmes**
À la mort du joueur, le Level System appelle `reset()` sur tous les sous-systèmes
dans l'ordre inverse de l'initialisation, puis les réinitialise avec les données
originales du `LevelData`. Le niveau repart à l'état exact du début.

**Règle 5 — Victoire par signal Pickup System**
La victoire est déclenchée par `player_reached_exit` du Pickup System. Le Level
System n'a pas d'autre condition de victoire au MVP.

**Règle 6 — Séquence de niveaux linéaire**
Les niveaux sont numérotés `level_001`, `level_002`, …. Après victoire, le Level
System charge le niveau suivant. MVP : 10 niveaux. Pas de choix de niveau, pas
de menu inter-niveau au MVP.

**Règle 7 — Mort arbitrée par le Level System**
`enemy_reached_player` → Level System → émet `player_died` → Player Movement
passe en `DEAD`. Le Level System est l'unique émetteur de `player_died`. Aucun
autre système ne peut tuer le joueur directement.

**Règle 8 — Délai de restart**
Après la mort, un bref `DEATH_FREEZE_TIME` (0.5s) se coule avant le restart.
Ce délai permet à l'animation de mort de jouer et évite un restart réflexe
accidentel. Passé ce délai, le restart est automatique (pas d'input nécessaire).

### States and Transitions

| État | Description |
|---|---|
| `IDLE` | Aucun niveau chargé (menu principal ou chargement) |
| `LOADING` | Chargement des assets du niveau en cours |
| `RUNNING` | Niveau actif — joueur joue |
| `DYING` | Joueur mort, freeze de `DEATH_FREEZE_TIME` avant restart |
| `RESTARTING` | Reset de tous les sous-systèmes en cours |
| `VICTORY` | Joueur entré dans la sortie, niveau terminé |
| `TRANSITIONING` | Passage au niveau suivant (fondu/transition) |

```
IDLE
  └─ load_level(level_id) → LOADING

LOADING
  └─ tous les assets prêts → RUNNING (init() de tous les sous-systèmes)

RUNNING
  ├─ enemy_reached_player → DYING (émet player_died)
  └─ player_reached_exit → VICTORY

DYING
  └─ DEATH_FREEZE_TIME écoulé → RESTARTING

RESTARTING
  └─ reset() complet → RUNNING (re-init de tous les sous-systèmes)

VICTORY
  └─ VICTORY_HOLD_TIME écoulé → TRANSITIONING

TRANSITIONING
  ├─ niveau suivant existe → LOADING (load_level(current_level + 1))
  └─ dernier niveau → IDLE (retour menu — MVP: afficher écran "fin de jeu" simple)
```

### Lifecycle — Séquence d'init détaillée

```
load_level(level_id):
  1. Charger LevelData Resource depuis "res://levels/{level_id}.tres"
  2. GridSystem.init(level_data.grid_width, level_data.grid_height)
  3. TerrainSystem.init(level_data.terrain_map)
  4. GridGravity.init(level_data.grid_width, level_data.grid_height)
  5. PlayerMovement.init(level_data.player_spawn)
  6. EnemyAI.init(level_data.enemy_spawns, level_data.enemy_rescate_positions)
  7. PickupSystem.init(level_data.pickup_cells, level_data.exit_cell)
  8. InputSystem.enable()
  9. state = RUNNING
```

```
restart():
  1. InputSystem.disable()
  2. EnemyAI.reset()
  3. PickupSystem.reset()
  4. PlayerMovement.reset()
  5. GridGravity.reset()
  6. TerrainSystem.reset()
  7. Re-init dans l'ordre d'init (avec les données LevelData déjà chargées)
  8. InputSystem.enable()
  9. state = RUNNING
```

### LevelData Resource — Structure

```
class_name LevelData extends Resource

@export var grid_width: int
@export var grid_height: int
@export var terrain_map: Array[Array]        # [row][col] → TileType enum
@export var player_spawn: Vector2i
@export var enemy_spawns: Array[Vector2i]
@export var enemy_rescate_positions: Array[Vector2i]  # par index gardien
@export var pickup_cells: Array[Vector2i]
@export var exit_cell: Vector2i
@export var level_name: String               # affiché dans le HUD (optionnel)
@export var level_index: int                 # numéro du niveau (1-based)
```

Résout **OQ-02 du Enemy AI** : les positions rescate sont définies dans le
`LevelData` par le level designer, une par gardien.

### Interactions with Other Systems

| Système | Ce que Level System lui envoie | Ce que Level System reçoit |
|---|---|---|
| **Grid System** | `init(width, height)`, `reset()` | — |
| **Terrain System** | `init(terrain_map)`, `reset()` | — |
| **Grid Gravity** | `init(width, height)`, `reset()` | — |
| **Player Movement** | `init(spawn_pos)`, `reset()`, émet `player_died` | Signal `player_died` reçu par Player Movement pour passer DEAD (Level System est l'émetteur) |
| **Enemy AI** | `init(spawns, rescate_positions)`, `reset()` | Signal `enemy_reached_player(enemy_id, cell)` |
| **Pickup System** | `init(pickup_cells, exit_cell)`, `reset()` | Signaux `player_reached_exit`, `all_pickups_collected` |
| **Input System** | `enable()`, `disable()` | — |
| **HUD** | Expose `current_level`, `death_count`, state global | — |
| **Audio System** | Émet `level_started`, `level_victory`, `player_died` | — |
| **Visual Feedback** | Émet `player_died`, `level_victory` | — |

## Formulas

Le Level System ne contient pas de formules mathématiques. Ses calculs sont des
conditions booléennes et des transitions d'état.

```
next_level_id = current_level_id + 1
has_next_level = (next_level_id <= MAX_LEVEL_INDEX)
```

**Timers :**

| Timer | Durée | Description |
|---|---|---|
| `DEATH_FREEZE_TIME` | 0.5 s | Freeze après mort avant restart |
| `VICTORY_HOLD_TIME` | 1.5 s | Maintien de l'état VICTORY avant transition |

## Edge Cases

**EC-01 — Dernier niveau complété**
`next_level_id > MAX_LEVEL_INDEX` → Level System passe en `IDLE` et affiche un
écran "fin de jeu" minimal. MVP : un simple message "Félicitations — X niveaux
complétés". Pas de Transition Screen (Vertical Slice).

**EC-02 — enemy_reached_player et player_reached_exit au même instant**
Si les deux signaux arrivent dans le même frame :
- La mort est prioritaire : `enemy_reached_player` est traité en premier.
- La victoire est annulée.
- Ordre de traitement : DYING s'enclenche, `player_reached_exit` est ignoré
  pendant l'état DYING.

**EC-03 — Plusieurs enemy_reached_player dans le même frame**
La mort ne se déclenche qu'une fois. Le Level System passe en DYING au premier
signal ; les suivants du même frame sont ignorés.

**EC-04 — LevelData manquant ou corrompu**
Le Level System restera en LOADING. En debug, loggue l'erreur. MVP : crash graceful
avec message d'erreur affiché. Pas de gestion d'erreur robuste au MVP.

**EC-05 — reset() pendant LOADING**
Impossible par design — l'Input System est désactivé pendant LOADING. Le joueur
ne peut pas mourir avant que RUNNING soit actif.

**EC-06 — Victoire en état DYING (mort résolue juste après entrée sortie)**
L'état DYING est prioritaire. La victoire ne peut être déclenchée que depuis
l'état RUNNING. Si `player_reached_exit` arrive après `enemy_reached_player`,
la mort prime (EC-02).

**EC-07 — Appel reset() externe (par exemple, touche "restart")**
MVP : le joueur peut redémarrer manuellement le niveau à tout moment. Input
"restart" (ex : touche R) déclenche directement `restart()` depuis l'état
RUNNING. Implémenté par Level System, pas par Input System.

**EC-08 — Gardien en position de spawn bloquée par joueur**
Le Level System place le joueur avant les gardiens (ordre init). Si un gardien
`spawn == player_spawn` (erreur de design), le gardien est quand même placé
et `enemy_reached_player` sera émis immédiatement. Responsabilité du level
designer d'éviter ce cas. Aucune validation au runtime au MVP.

## Dependencies

### Dépendances entrantes *(Level System dépend de)*

| Système | Nature | Détail |
|---|---|---|
| **Grid System** | Appel cycle de vie | `init`, `reset` |
| **Terrain System** | Appel cycle de vie | `init(terrain_map)`, `reset` |
| **Grid Gravity** | Appel cycle de vie | `init`, `reset` |
| **Player Movement** | Appel + signal reçu | `init(spawn)`, `reset` ; émet `player_died` |
| **Enemy AI** | Appel + signal reçu | `init(spawns, rescate)`, `reset` ; signal `enemy_reached_player` |
| **Pickup System** | Appel + signal reçu | `init(pickups, exit)`, `reset` ; signaux `player_reached_exit`, `all_pickups_collected` |
| **Input System** | Appel | `enable()`, `disable()` |
| **LevelData Resource** | Données | `.tres` par niveau dans `res://levels/` |

### Dépendances sortantes *(ces systèmes dépendent de Level System)*

| Système | Ce qu'il consomme |
|---|---|
| **HUD** | `current_level_index`, `death_count`, `level_name` en lecture |
| **Visual Feedback** | Signaux `player_died`, `level_victory`, `level_started` |
| **Audio System** | Signaux `player_died`, `level_victory`, `level_started` |
| **Stars/Scoring** *(Vertical Slice)* | `death_count`, `completion_time` à la fin du niveau |
| **Transition Screens** *(Vertical Slice)* | Événements `level_victory`, `level_started` pour animer les transitions |
| **Progression/Worlds** *(Alpha)* | Notification de niveau complété |

## Tuning Knobs

| Paramètre | Défaut | Plage | Impact |
|---|---|---|---|
| `DEATH_FREEZE_TIME` | 0.5 s | 0.2–1.5 s | Durée du freeze après mort avant restart. Court = punition légère, Long = frustration sur erreurs répétées |
| `VICTORY_HOLD_TIME` | 1.5 s | 0.5–3.0 s | Maintien de l'état victoire avant transition. Trop court = pas de satisfaction, Trop long = impatience |

**Stockage** : Constantes dans `LevelConfig` Resource ou directement en `const`
dans le script LevelSystem au MVP (pas de config externe nécessaire).

**Niveaux disponibles** : définis par les fichiers `.tres` présents dans
`res://levels/`. Le Level System scanne le dossier au démarrage et construit
sa liste ordonnée. `MAX_LEVEL_INDEX` = nombre de fichiers trouvés.

## Visual/Audio Requirements

**MVP : aucun visuel propre au Level System.** Tout est délégué par signaux.

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `level_started(level_index)` | Audio | Musique du niveau (loop) |
| `player_died` | Visual Feedback | Animation mort joueur + flash rouge |
| `player_died` | Audio | SFX mort joueur |
| `level_victory` | Visual Feedback | Effet de victoire sur la sortie |
| `level_victory` | Audio | Jingle de victoire + arrêt musique |

Post-MVP (Vertical Slice) : Transition Screens animera les entrées/sorties de
niveaux. Level System émettra `level_transitioning_out` et `level_transitioning_in`
pour synchroniser.

## UI Requirements

**MVP : aucun élément UI géré par Level System.**

Le Level System expose en lecture pour le HUD (Vertical Slice) :

| Propriété | Type | Description |
|---|---|---|
| `current_level_index` | `int` | Numéro du niveau (1-based) |
| `level_name` | `String` | Nom du niveau (depuis LevelData) |
| `death_count` | `int` | Nombre de morts sur ce niveau |
| `level_state` | `enum` | État actuel (RUNNING, DYING, VICTORY…) |

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Chargement niveau | `load_level("level_001")` → tous les sous-systèmes initialisés, joueur au spawn, gardiens à leurs spawns, trésors placés |
| AC-02 | Mort par gardien | `enemy_reached_player` → `player_died` émis, état passe en DYING |
| AC-03 | Restart automatique | Après DEATH_FREEZE_TIME → restart(), tous les sous-systèmes reset, joueur au spawn, gardiens à leurs spawns initiaux, trésors restaurés |
| AC-04 | Victoire | `player_reached_exit` → état VICTORY, `level_victory` émis |
| AC-05 | Niveau suivant | Après VICTORY_HOLD_TIME → `load_level(current + 1)` |
| AC-06 | Fin du jeu | Dernier niveau terminé → état IDLE, message de fin |
| AC-07 | Mort prioritaire | `enemy_reached_player` et `player_reached_exit` même frame → mort prime |
| AC-08 | Restart manuel | Touche R en RUNNING → `restart()` déclenché, comportement identique à mort |
| AC-09 | Compteur morts | `death_count` incrémenté à chaque mort, remis à 0 au chargement d'un nouveau niveau |
| AC-10 | Init ordonné | Grid → Terrain → Gravity → Player → Enemy → Pickup → Input : ordre toujours respecté |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Format de séquence de niveaux** — Les niveaux sont-ils dans un seul dossier `res://levels/` scannés par ordre alphabétique, ou définis dans un fichier de séquence explicite (ex : `level_sequence.json`) ? *Recommandation : fichier de séquence explicite pour plus de flexibilité (permettre des niveaux cachés, des ordres non-linéaires post-MVP).* | Ouvert | Technical Direction |
| OQ-02 | **Restart manuel par input** — Quelle touche ? Faut-il une confirmation (éviter les restarts accidentels) ? *Recommandation : touche R, restart immédiat sans confirmation au MVP (cohérent avec le rythme "mort = apprendre vite").* | Ouvert | UX |
| OQ-03 | **Chevauchement mort + victoire** — EC-02 établit que la mort prime. Est-ce que le joueur peut trouver ça injuste si il atteint la sortie au même frame où un gardien l'attrape ? *Recommandation : oui, mort prime — l'ambiguïté est résolue en faveur de la tension. Post-MVP : VICTORY_PRIORITY possible via UX testing.* | Fermé (mort prime au MVP) | — |
| OQ-04 | **LevelData : scan automatique ou séquence explicite** — Voir OQ-01. | Dupliqué | — |
