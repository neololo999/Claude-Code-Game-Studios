# Terrain System (Système de Terrain)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Lisibilité parfaite · Puzzle d'abord, action ensuite

## Overview

Le Terrain System est la couche sémantique au-dessus de la grille. Il associe chaque ID de cellule à un **type de terrain** avec ses propriétés : traversabilité, destructibilité, comportement vis-à-vis de la gravité, support pour les entités. Il est le seul système autorisé à modifier le contenu de la grille.

Au chargement d'un niveau, le Terrain System lit les données brutes et initialise la grille. En cours de jeu, quand le Dig System demande de creuser une cellule, le Terrain System valide l'opération, informe la grille (signal `cell_changed`), et démarre le timer de refermeture. Une fois le timer écoulé, il referme le trou si la cellule est libre.

Le Terrain System ne déplace pas les entités — il expose uniquement des **requêtes de propriété** (`is_solid`, `is_traversable`, `is_climbable`, `is_destructible`, `get_tile_type`) que les autres systèmes consultent pour prendre leurs décisions. Cette séparation garantit que la logique terrain est centralisée et non dupliquée dans chaque système consommateur.

## Player Fantasy

Le Terrain System ne produit pas de fantasy directe — le joueur ne "voit" pas les types de terrain en tant que données. Ce qu'il *ressent*, c'est la **résistance différenciée du monde** : certains blocs cèdent sous son pic, d'autres non. Cette résistance est ce qui donne au creusement sa profondeur tactique.

Chaque type de terrain est une contrainte lisible. Le joueur apprend rapidement : "métal = immuable, bois = creusable lent, sable = creusable rapide, brique = creusable moyen". Ces règles deviennent de la grammaire — le niveau les combine pour construire des puzzles.

Le timer de refermeture d'un trou est le battement cardiaque du jeu. Le joueur creuse, le trou s'ouvre, le gardien tombe, le trou se referme. Toute la tension vient du fait que le joueur *sait* que cette fenêtre est limitée — il doit agir, pas planifier à l'infini.

*Pilier servi : Tension constante — le terrain est le mécanisme qui transforme une décision de creusement en une course contre le temps.*

## Detailed Design

### Core Rules

**Types de terrain**

| ID | Nom | Traversable | Climbable | Support gravité | Destructible | Timer refermeture |
|---|---|---|---|---|---|---|
| `0` | `EMPTY` | ✅ | ❌ | ❌ | ❌ | — |
| `1` | `SOLID` | ❌ | ❌ | ✅ | ❌ | — |
| `2` | `DIRT_SLOW` | ❌ → ✅ (après creusement) | ❌ | ✅ | ✅ | Long (tunable) |
| `3` | `DIRT_FAST` | ❌ → ✅ (après creusement) | ❌ | ✅ | ✅ | Court (tunable) |
| `4` | `LADDER` | ✅ | ✅ | ✅ | ❌ | — |
| `5` | `ROPE` | ✅ (horizontal seulement) | ✅ (suspension) | ❌ | ❌ | — |

**Règles de traversabilité**
1. Une cellule est **traversable** si le joueur ou un gardien peut l'occuper en se déplaçant dessus (EMPTY, LADDER, ROPE, cellule creusée en état OPEN)
2. Une cellule est **solide** si elle bloque le passage et sert de support à une entité posée dessus (SOLID, DIRT_SLOW, DIRT_FAST non creusés)
3. Une cellule est **climbable** si une entité peut s'y déplacer verticalement sans tomber (LADDER : montée/descente ; ROPE : déplacement horizontal en suspension)
4. Une cellule est **support de gravité** si une entité posée juste au-dessus ne tombe pas. Les cellules EMPTY et ROPE ne sont pas support.
5. Seul le Dig System peut déclencher le creusement d'une cellule. Le Terrain System valide la requête (`is_destructible`) et gère le timer.
6. Une cellule ROPE ne peut être creusée. Une corde au-dessus d'un trou creusé reste en place.

**Cycle de creusement**
- Une cellule destructible passe par les états : `INTACT → DIGGING → OPEN → CLOSING → INTACT`
- En état `OPEN`, la cellule est traversable et n'est plus un support
- Le timer de refermeture démarre dès que la cellule passe en `OPEN`
- Si une entité occupe la cellule au moment de `CLOSING → INTACT`, la refermeture est bloquée jusqu'à ce que la cellule soit libérée *(provisoire : à confirmer avec Grid Gravity)*

### States and Transitions

Chaque cellule destructible a son propre cycle de vie indépendant :

```
INTACT ──[dig_requested]──► DIGGING ──[dig_complete]──► OPEN
                                                          │
                                                    [timer start]
                                                          │
INTACT ◄──[cell_free]── CLOSING ◄──[timer_expired]───────┘
         (if blocked: wait)
```

| État | Description | Traversable | Support |
|---|---|---|---|
| `INTACT` | État par défaut. Bloc plein. | ❌ | ✅ |
| `DIGGING` | Animation de creusement en cours. Pas encore traversable. | ❌ | ✅ |
| `OPEN` | Trou ouvert. Traversable, plus de support. Timer actif. | ✅ | ❌ |
| `CLOSING` | Animation de refermeture. Bloquée si entité présente. | ✅ | ❌ |

Les cellules non destructibles (EMPTY, SOLID, LADDER, ROPE) n'ont pas de machine à états — elles sont statiques.

### Interactions with Other Systems

| Système | Ce que le Terrain System fournit | Direction |
|---|---|---|
| **Grid System** | Lit et écrit les IDs de cellule via la grille. Déclenche `cell_changed` lors de tout changement d'état | Bidirectionnel |
| **Dig System** | Reçoit `dig_request(col, row)`. Valide (`is_destructible`), démarre la transition `INTACT → DIGGING → OPEN`, gère le timer de refermeture | Consommateur (commandes) |
| **Player Movement** | Répond aux requêtes `is_traversable(col, row)`, `is_solid(col, row)`, `is_climbable(col, row)` | Fournisseur (requêtes) |
| **Grid Gravity** | S'abonne à `cell_changed` pour détecter quand un support disparaît (INTACT→OPEN). Fournit l'état d'occupation d'une cellule pour bloquer/débloquer la refermeture | Bidirectionnel (signal + callback) |
| **Enemy AI** | Même interface que Player Movement. Consulte aussi `get_dig_timer_remaining(col, row)` pour évaluer la dangerosité d'un trou | Fournisseur |
| **Level System** | Initialise tous les tiles au chargement du niveau. Réinitialise les timers au restart | Propriétaire du cycle de vie |

## Formulas

### Durée d'animation de creusement (DIGGING)

```
DIG_DURATION = dig_animation_frames / frame_rate
```

Durée purement visuelle correspondant à l'animation de creusement avant que le trou soit ouvert. Valeur défaut : `0.5s` (tunable).

---

### Timers de refermeture

```
CLOSE_TIMER_SLOW = DIG_CLOSE_SLOW    # défaut : 8.0s
CLOSE_TIMER_FAST = DIG_CLOSE_FAST    # défaut : 4.0s
```

Le timer démarre dès l'entrée en état `OPEN`. La durée `CLOSING` (animation) est fixe :

```
CLOSING_DURATION = 1.0s   # défaut, tunable
```

Séquence complète pour `DIRT_SLOW` :
```
DIGGING (0.5s) → OPEN (8.0s) → CLOSING (1.0s) → INTACT
```

---

### Blocage de refermeture

Si une entité occupe la cellule au moment de `CLOSING → INTACT`, la refermeture est suspendue :
```
while cell_occupied(col, row):
    wait   # pas de timeout — responsabilité de Grid Gravity de résoudre
```

La refermeture reprend dès que `cell_occupied` retourne `false`.

---

| Variable | Défaut | Unité | Description |
|---|---|---|---|
| `DIG_DURATION` | 0.5 | s | Durée animation de creusement |
| `DIG_CLOSE_SLOW` | 8.0 | s | Timer refermeture DIRT_SLOW |
| `DIG_CLOSE_FAST` | 4.0 | s | Timer refermeture DIRT_FAST |
| `CLOSING_DURATION` | 1.0 | s | Durée animation de fermeture |

## Edge Cases

**EC-01 — Creusement d'une cellule déjà en état OPEN**
Si le Dig System demande de creuser une cellule déjà `OPEN` (ou `DIGGING`/`CLOSING`), le Terrain System rejette silencieusement la requête. Un trou ouvert ne peut pas être "recreusé".

**EC-02 — Entité piégée dans la fermeture**
Si une entité se trouve dans la cellule au moment où `CLOSING → INTACT` se déclenche, la refermeture est bloquée. L'entité reste dans la cellule. La refermeture reprend dès que la cellule est libérée. La résolution de la sortie d'entité appartient à Grid Gravity / Player Movement — le Terrain System ne force pas les entités hors de la cellule.

**EC-03 — Chargement de niveau avec des IDs de terrain inconnus**
Si le Level System fournit un ID de terrain non référencé dans le `TerrainConfig`, le Terrain System substitue `EMPTY` et log un avertissement. Le jeu continue sans crash.

**EC-04 — Restart de niveau avec des trous ouverts**
Au restart, le Level System demande la réinitialisation complète du Terrain System. Tous les timers actifs sont annulés et toutes les cellules sont remises à `INTACT`. Aucun état résiduel ne subsiste entre deux tentatives.

**EC-05 — Deux requêtes de creusement simultanées sur la même cellule**
Impossible par construction : le Dig System est la seule source de `dig_request`, et l'Input System produit un signal one-shot par action. Si deux requêtes arrivent dans le même frame (bug upstream), la première est traitée, la seconde rejetée car la cellule est déjà en état `DIGGING`.

**EC-06 — ROPE au-dessus d'un trou creusé**
La corde est non-destructible et n'est pas liée à la cellule en dessous. Quand la cellule sous la corde passe à `OPEN`, la corde reste intacte. Une entité sur la corde reste supportée par la corde (pas de gravity drop).

## Dependencies

**Upstream (ce dont le Terrain System dépend)**

| Système | Nature de la dépendance |
|---|---|
| **Grid System** | Fournit le stockage des IDs de cellule, le signal `cell_changed`, et les fonctions de validation de coordonnées. Le Terrain System ne peut pas fonctionner sans la grille initialisée. |

Aucune autre dépendance upstream.

---

**Downstream (ce qui dépend du Terrain System)**

| Système | Ce qu'il attend |
|---|---|
| **Player Movement** | `is_traversable(col, row)`, `is_solid(col, row)`, `is_climbable(col, row)` — synchrone, sans side-effects |
| **Dig System** | `is_destructible(col, row)`, `dig_request(col, row)` — déclenche le cycle INTACT→OPEN |
| **Grid Gravity** | Signal `cell_changed` + `is_solid(col, row)` pour détecter les supports perdus |
| **Enemy AI** | Même interface que Player Movement + `get_dig_timer_remaining(col, row)` |
| **Level System** | `initialize(data)` au chargement, `reset()` au restart |
| **Level Design Tooling** | Lecture des types de terrain et de leurs propriétés pour la palette d'édition |

---

**Contrats d'interface exposés**

```
is_traversable(col: int, row: int) → bool
is_solid(col: int, row: int) → bool
is_climbable(col: int, row: int) → bool
is_destructible(col: int, row: int) → bool
get_tile_type(col: int, row: int) → TileType
get_dig_state(col: int, row: int) → DigState
get_dig_timer_remaining(col: int, row: int) → float
dig_request(col: int, row: int) → void
initialize(level_data: LevelData) → void
reset() → void
```

## Tuning Knobs

| Knob | Défaut | Plage | Description |
|---|---|---|---|
| `DIG_DURATION` | 0.5 s | 0.1–2.0 s | Durée de l'animation de creusement (DIGGING) |
| `DIG_CLOSE_SLOW` | 8.0 s | 2.0–30.0 s | Timer de refermeture pour DIRT_SLOW |
| `DIG_CLOSE_FAST` | 4.0 s | 1.0–15.0 s | Timer de refermeture pour DIRT_FAST |
| `CLOSING_DURATION` | 1.0 s | 0.2–3.0 s | Durée de l'animation de fermeture |

Toutes ces valeurs sont stockées dans une `TerrainConfig` (Resource Godot) et ne doivent jamais être hardcodées.

**Invariant à respecter :** `DIG_CLOSE_FAST < DIG_CLOSE_SLOW` — si une mise à jour du config viole cet invariant, un avertissement est loggé au `_ready`.

## Visual/Audio Requirements

**Visuels requis**

| Élément | Description | Priorité |
|---|---|---|
| Sprite INTACT | Tile statique par type (SOLID, DIRT_SLOW, DIRT_FAST, LADDER, ROPE) | MVP |
| Animation DIGGING | Frames d'animation de creusement (4–8 frames) | MVP |
| Sprite OPEN | Trou ouvert visible — fond vide sous les bords | MVP |
| Animation CLOSING | Frames de refermeture, jouée en sens inverse ou séquence dédiée | MVP |

Le Terrain System émet des signaux d'état (`dig_state_changed`) que le Visual Feedback System consomme pour déclencher les animations. Le Terrain System ne fait pas de rendu lui-même.

**Audio requis**

| Événement | Son attendu | Priorité |
|---|---|---|
| INTACT → DIGGING | Son de creusement (impact, matière) | MVP |
| CLOSING → INTACT | Son de refermeture (bloc qui se reforme) | MVP |

Les événements audio sont déclenchés via le signal `dig_state_changed` — le Terrain System ne joue pas de sons directement.

## UI Requirements

**MVP** : Aucun. Le Terrain System n'a pas d'interface utilisateur propre.

**Full Vision** : Le Level Design Tooling affichera une palette des types de terrain avec leurs propriétés pour l'éditeur de niveaux. Hors scope de ce GDD.

## Acceptance Criteria

**AC-01** — Étant donné une grille initialisée, `is_traversable` retourne `true` pour EMPTY, LADDER, ROPE et `false` pour SOLID, DIRT_SLOW, DIRT_FAST (non creusés).

**AC-02** — Étant donné une cellule DIRT_SLOW, `dig_request` la fait passer en DIGGING puis OPEN après `DIG_DURATION` secondes.

**AC-03** — Étant donné une cellule en état OPEN, le timer de refermeture expire et la cellule passe en CLOSING puis INTACT.

**AC-04** — Étant donné une cellule DIRT_SLOW et une cellule DIRT_FAST creusées simultanément, DIRT_FAST referme avant DIRT_SLOW.

**AC-05** — Étant donné une entité dans une cellule en CLOSING, la refermeture est bloquée jusqu'à ce que l'entité quitte la cellule.

**AC-06** — Étant donné `dig_request` sur une cellule SOLID, la requête est rejetée et la cellule reste INTACT.

**AC-07** — Étant donné `dig_request` sur une cellule déjà en état OPEN, la requête est rejetée silencieusement.

**AC-08** — Étant donné un `reset()`, tous les timers actifs sont annulés et toutes les cellules destructibles reviennent à INTACT.

**AC-09** — Étant donné un ID de terrain inconnu au chargement, le Terrain System substitue EMPTY et log un avertissement sans crasher.

**AC-10** — `is_climbable` retourne `true` uniquement pour LADDER et ROPE, et `false` pour tous les autres types.

## Open Questions

**OQ-01 — Propriétaire du blocage de refermeture (EC-02)**
Le Terrain System attend que `cell_occupied` retourne `false`, mais qui implémente cette requête ? Grid Gravity semble le candidat naturel (il track les entités sur les cellules). À clarifier lors du design de Grid Gravity.
*Statut : Provisoire — décision déléguée au GDD Grid Gravity.*

**OQ-02 — Gestion des LADDER/ROPE dans les niveaux**
Les LADDER et ROPE sont-elles des tiles indépendantes, ou peuvent-elles coexister avec d'autres tiles (ex : une LADDER posée sur DIRT) ? Le Level Design Tooling devra trancher ce point.
*Statut : Ouvert — à décider lors du GDD Level Design Tooling ou du design d'un premier niveau.*

**OQ-03 — Tile EMPTY en bord de niveau**
Une cellule hors limites doit-elle être traitée comme EMPTY (traversable) ou SOLID (mur invisible) par les requêtes de propriété ? Actuellement : les requêtes sur des coordonnées hors limites retournent SOLID par défaut (comportement sécuritaire).
*Statut : Provisoire — à confirmer avec Player Movement et Enemy AI.*
