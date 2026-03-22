# Pickup System (Collecte)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Puzzle d'abord · Lisibilité parfaite

## Overview

Le Pickup System détecte quand le joueur atteint une cellule contenant un trésor,
incrémente le compteur de collecte, et notifie les systèmes avals. Quand le dernier
trésor du niveau est ramassé, il émet `all_pickups_collected` — signal que le Level
System utilise pour ouvrir la sortie.

Le système gère également les **cellules de sortie** : tant que tous les trésors ne
sont pas collectés, la sortie est verrouillée ; une fois déverrouillée, le joueur
n'a qu'à la traverser pour terminer le niveau.

**Responsabilités :**
- Maintenir la liste des pickups présents dans le niveau en cours
- Détecter la collecte quand `player_moved.to` coïncide avec une cellule pickup
- Émettre `pickup_collected(col, row)` et `all_pickups_collected` au bon moment
- Gérer l'état de la sortie (verrouillée / déverrouillée)
- Détecter quand le joueur entre sur la cellule de sortie (déverrouillée)
- Fournir `pickups_remaining: int` et `pickups_total: int` au HUD

**Hors scope :**
- Rendu des trésors (Visual Feedback / Art)
- Score ou progression méta (Level System / Progression System)
- Types de trésors multiples avec valeurs différentes (post-MVP)
- Pickups ramassables par les ennemis (hors MVP)

## Player Fantasy

Le trésor est **la raison d'être du niveau**.

Dans Dig & Dash, chaque trésor est placé intentionnellement par le level designer
pour forcer le joueur à traverser une zone dangereuse, à creuser dans une séquence
précise, ou à chronométrer sa course entre deux patrouilles. Ramasser un trésor
n'est jamais anodin — c'est toujours le résultat d'un choix tactique.

Le joueur devrait ressentir une légère tension à chaque collecte : "j'ai pris celui-là,
maintenant je dois aller là-bas." Le dernier trésor ramassé déclenche un moment
de soulagement immédiat — la sortie s'ouvre — suivi d'une dernière course vers
la porte avec les gardiens qui ont peut-être modifié leurs positions.

La sortie qui s'ouvre est une **récompense sonore et visuelle** : le signal clair que
le puzzle est résolu et qu'il ne reste plus qu'à survivre jusqu'à la porte.

*Piliers servis : Puzzle d'abord (le placement des trésors EST le puzzle),
Lisibilité parfaite (compteur de trésors restants toujours visible).*

## Detailed Design

### Core Rules

**Règle 1 — Pickup = cellule dans la grille**
Un trésor occupe une cellule unique dans la grille. Il n'y a pas d'entité physique
attachée à un pickup — c'est simplement un marqueur dans le registre du Pickup System.

**Règle 2 — Détection par coïncidence de cellule**
La collecte se déclenche quand `player_moved(from, to)` est reçu et que `to` est
dans le registre des pickups actifs. Pas d'hitbox, pas de raycast — la grille suffit.

**Règle 3 — Collecte immédiate**
La collecte est instantanée dès que le signal `player_moved` est reçu avec la bonne
destination. Pas d'animation bloquante côté Pickup System (le feedback visuel est
géré par Visual Feedback System).

**Règle 4 — Sortie verrouillée jusqu'au dernier trésor**
Au démarrage du niveau, la cellule de sortie est marquée comme `EXIT_LOCKED`. La
traverser n'a aucun effet. Quand `pickups_remaining == 0`, la sortie passe à
`EXIT_OPEN` et émet `exit_unlocked`.

**Règle 5 — Victoire par entrée sur la sortie déverrouillée**
Quand `player_moved.to == exit_cell` ET que `exit_state == EXIT_OPEN`, le Pickup
System émet `player_reached_exit`. Level System réagit en déclenchant la victoire.

**Règle 6 — Un seul trésor par cellule**
Deux trésors ne peuvent pas occuper la même cellule. Propriété garantie par le
level designer / Level System lors de l'initialisation.

**Règle 7 — Pas de spawn dynamique**
Les pickups sont définis au chargement du niveau et ne peuvent pas spawner pendant
le jeu (hors MVP). L'état initial est fourni par le Level System via `init(pickup_cells, exit_cell)`.

### States and Transitions

**Par trésor individuel :**

| État | Description |
|---|---|
| `PRESENT` | Trésor présent sur la cellule, collectible |
| `COLLECTED` | Trésor ramassé, cellule maintenant vide |

```
PRESENT
  └─ player_moved.to == cell → COLLECTED (émet pickup_collected)
```

**Pour la sortie :**

| État | Description |
|---|---|
| `EXIT_LOCKED` | Sortie inaccessible (trésors restants > 0) |
| `EXIT_OPEN` | Sortie accessible (tous les trésors collectés) |

```
EXIT_LOCKED
  └─ pickups_remaining == 0 → EXIT_OPEN (émet exit_unlocked)

EXIT_OPEN
  └─ player_moved.to == exit_cell → émet player_reached_exit
```

**Pour le système global :**

| État | Description |
|---|---|
| `IDLE` | Pas de niveau chargé |
| `ACTIVE` | Niveau en cours, trésors restants > 0 |
| `ALL_COLLECTED` | Tous les trésors ramassés, attente entrée sortie |
| `COMPLETE` | Joueur entré dans la sortie — niveau terminé |

```
IDLE
  └─ init(pickup_cells, exit_cell) → ACTIVE

ACTIVE
  └─ pickups_remaining == 0 → ALL_COLLECTED (émet all_pickups_collected)

ALL_COLLECTED
  └─ player_moved.to == exit_cell → COMPLETE (émet player_reached_exit)

COMPLETE | ANY
  └─ reset() → IDLE
```

### Interactions with Other Systems

| Système | Rôle du Pickup System | Direction |
|---|---|---|
| **Player Movement** | Consomme `player_moved(from, to)` pour détecter pickup + sortie | Consommateur (signal) |
| **Grid System** | `is_valid(col, row)` pour valider les positions au init | Consommateur |
| **Level System** | Reçoit `init(pickup_cells, exit_cell)` au démarrage du niveau ; émet `pickup_collected`, `all_pickups_collected`, `exit_unlocked`, `player_reached_exit` | Bidirectionnel |
| **HUD** | Expose `pickups_remaining: int` et `pickups_total: int` en lecture ; émet `pickup_collected` pour mise à jour en temps réel | Producteur |
| **Visual Feedback** | Émet `pickup_collected(col, row)` et `exit_unlocked` — VFX réagit (particules, flash de sortie) | Producteur |
| **Audio** | Mêmes signaux pour SFX de collecte et fanfare de déverrouillage | Producteur |

## Formulas

Le Pickup System n'a pas de formules mathématiques complexes. L'unique calcul est :

```
pickups_remaining = pickups_total - pickups_collected_count
```

```
pickup_percentage = pickups_collected_count / pickups_total  # pour le HUD optionnel
```

```
exit_is_open = (pickups_remaining == 0)
```

**Variables :**

| Variable | Type | Description |
|---|---|---|
| `pickups_total` | `int` | Nombre de trésors dans le niveau (défini à `init`) |
| `pickups_collected_count` | `int` | Nombre de trésors ramassés depuis le dernier `reset` |
| `pickups_remaining` | `int` | `pickups_total - pickups_collected_count` |
| `exit_state` | `enum` | `EXIT_LOCKED` ou `EXIT_OPEN` |
| `pickup_cells` | `Array[Vector2i]` | Positions des trésors encore PRESENT |
| `exit_cell` | `Vector2i` | Position de la sortie |

## Edge Cases

**EC-01 — Niveau avec zéro trésor**
Si `init` reçoit une liste vide de pickups, `pickups_total == 0`, le système passe
immédiatement à `ALL_COLLECTED` et la sortie s'ouvre. Ce cas est valide (niveau
de tutorial sans collecte). `exit_unlocked` est émis au init.

**EC-02 — Joueur entre sur la sortie verrouillée**
Ignoré. Le Pickup System ne réagit pas à `player_moved.to == exit_cell` si
`exit_state == EXIT_LOCKED`. Aucun signal émis. La sortie est visuellement distincte
(fermée vs ouverte) mais le système ne bloque pas le mouvement — c'est le Terrain
System qui définit si la cellule est traversable.

> **Note** : La sortie doit être traversable dans le Terrain System (EMPTY ou dédié)
> pour que le joueur puisse physiquement entrer dans la cellule. Le Pickup System
> n'impose pas de contrainte de mouvement — il détecte seulement l'entrée.

**EC-03 — Joueur meurt sur une cellule trésor**
La collecte n'a pas lieu. Le signal `player_moved` n'est pas émis quand le joueur
meurt (géré par Player Movement FSM → état `DEAD`). Le trésor reste `PRESENT`.
À la reprise (reset), le niveau est réinitialisé via `reset()`.

**EC-04 — reset() pendant collecte**
`reset()` annule tout état en cours. Liste des pickups restaurée à l'état initial,
`pickups_collected_count = 0`, `exit_state = EXIT_LOCKED`. L'état initial est
retenu depuis le dernier `init()`.

**EC-05 — Deux appels player_moved simultanés sur le même trésor**
Impossible par design — le joueur est une entité unique avec un seul état FSM. Pas
de concurrence possible.

**EC-06 — Sortie et trésor sur la même cellule**
Interdit. La cellule de sortie ne peut pas être une cellule pickup. Propriété
garantie par le level designer. Le système ne valide pas ce cas au runtime.

**EC-07 — Joueur sur la sortie en état ALL_COLLECTED, puis mort**
Si le joueur entre sur la sortie (signal émis) mais la mort est résolue avant que
Level System traite `player_reached_exit`, Level System arbitre. Le Pickup System
émet les deux signaux sans connaissance de l'ordre de résolution.

## Dependencies

### Dépendances entrantes *(Pickup System dépend de)*

| Système | Nature | Détail |
|---|---|---|
| **Player Movement** | Signal consommé | `player_moved(from: Vector2i, to: Vector2i)` — source unique de détection |
| **Grid System** | Requête | `is_valid(col, row)` — validation des positions au init |
| **Level System** | Appel de cycle de vie | `init(pickup_cells: Array[Vector2i], exit_cell: Vector2i)` et `reset()` |

### Dépendances sortantes *(ces systèmes dépendent de Pickup System)*

| Système | Ce qu'il consomme |
|---|---|
| **Level System** | `all_pickups_collected` → déclencheur logique de victoire possible ; `player_reached_exit` → victoire effective |
| **HUD** | `pickups_remaining`, `pickups_total` (lecture) ; `pickup_collected` (mise à jour display) |
| **Visual Feedback** | `pickup_collected(col, row)` → VFX trésor ; `exit_unlocked` → animation sortie |
| **Audio System** | `pickup_collected` → SFX collecte ; `all_pickups_collected` → fanfare ; `player_reached_exit` → jingle victoire |

## Tuning Knobs

Le Pickup System est intentionnellement sans paramètres tunables au MVP — il n'a
pas de timers, de multiplicateurs, ni de formules complexes à régler.

Les seuls paramètres dépendent du contenu du niveau, défini dans les données de
niveau par le level designer :

| Paramètre | Défini par | Description |
|---|---|---|
| Nombre de trésors | Données niveau | Défini case par case dans la map |
| Position de la sortie | Données niveau | Une seule sortie par niveau (MVP) |

> Post-MVP potentiel : `PICKUP_VALUE` par trésor pour un système de score ; types
> de trésors (bonus, clé) ; portes multiples. Tout cela passe par Level System.

## Visual/Audio Requirements

**MVP : aucun visuel ni audio propre au Pickup System.** Tout est délégué par signaux.

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `pickup_collected(col, row)` | Visual Feedback | Particules de collecte à la position (col, row) |
| `pickup_collected` | Audio | SFX court de collecte (type "ding" satisfaisant) |
| `all_pickups_collected` | Visual Feedback | Flash sur cellule de sortie |
| `exit_unlocked` | Visual Feedback | Animation d'ouverture de la sortie |
| `all_pickups_collected` | Audio | Fanfare courte de déverrouillage |
| `player_reached_exit` | Audio | Jingle de victoire |

## UI Requirements

**MVP : aucun élément UI géré par le Pickup System.**

Le système expose en lecture :
- `pickups_remaining: int`
- `pickups_total: int`

Le HUD System consomme ces valeurs pour afficher le compteur de trésors restants.
Format recommandé : `3/7` ou `4 restants`.

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Collecte basique | Joueur entre sur cellule trésor → `pickup_collected` émis, `pickups_remaining` décrémenté |
| AC-02 | Déverrouillage sortie | Dernier trésor ramassé → `all_pickups_collected` émis, `exit_state == EXIT_OPEN` |
| AC-03 | Sortie verrouillée ignorée | Joueur entre sur sortie verrouillée → aucun signal, joueur peut traverser normalement |
| AC-04 | Victoire par sortie | Joueur entre sur sortie ouverte → `player_reached_exit` émis |
| AC-05 | Reset complet | `reset()` → pickups tous PRESENT, `exit_state == EXIT_LOCKED`, compteurs à zéro |
| AC-06 | Niveau sans trésor | `init` avec zéro pickup → `exit_unlocked` immédiat, sortie ouverte dès le début |
| AC-07 | Mort sans collecte | Joueur meurt sur cellule trésor → trésor reste PRESENT après reset |
| AC-08 | HUD sync | `pickups_remaining` et `pickups_total` corrects à tout moment, mis à jour avant le signal `pickup_collected` |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Sorties multiples** — MVP : une seule sortie. Post-MVP : plusieurs portes, déverrouillées en séquence ou simultanément ? *Recommandation : hors MVP, Level System arbitre.* | Fermé (une seule sortie MVP) | — |
| OQ-02 | **Trésors avec valeur** — MVP : tous les trésors valent 1. Post-MVP : trésors bonus à valeur > 1 pour un système de score ? *Recommandation : oui post-MVP, nécessite Progression System.* | Ouvert | Game Design + Level System |
| OQ-03 | **Le trésor bloque-t-il le terrain ?** — La cellule trésor est-elle traversable ? *Recommandation : oui, le joueur peut se trouver sur la cellule et la collecte est automatique. Terrain System laisse la case EMPTY, Pickup System superpose le marqueur.* | Fermé (traversable, collection au passage) | — |
