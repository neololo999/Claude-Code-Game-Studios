# Player Movement (Mouvement joueur)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Tension constante · Lisibilité parfaite

## Overview

Le Player Movement est le **contrôleur d'entité du joueur**. Il reçoit les intentions
de mouvement de l'Input System, les valide contre le Terrain et la grille, puis déplace
le joueur case par case avec snap au centre de la cellule cible.

Le système distingue trois modes de déplacement : **horizontal** (gauche/droite sur
cases traversables), **vertical sur structure** (montée/descente sur LADDER ou ROPE),
et **chute** (déclenchée par Grid Gravity). Il est le seul responsable de la position
du joueur dans la grille.

Player Movement ne prend pas de décisions de gameplay hors mouvement — il valide
et exécute. La légalité du terrain vient du Terrain System, la logique gravitationnelle
vient de Grid Gravity, les intentions viennent de l'Input System.

**Responsabilités :**
- Valider et exécuter les `move_requested` (horizontal et vertical sur structure)
- Écouter `entity_should_fall` et exécuter la chute case par case
- Maintenir `current_cell: Vector2i` (position joueur dans la grille)
- Enregistrer et mettre à jour la position dans Grid Gravity
- Émettre `player_moved(from, to)` et `player_died` pour les systèmes consommateurs

**Hors scope :**
- Détection de collision joueur/gardien (Level System)
- Animation du joueur (Visual Feedback System)
- Creusement (Dig System)
- Mort du joueur et restart (Level System)

## Player Fantasy

Chaque pas est une **décision assumée**.

Dans Dig & Dash, le joueur n'est jamais surpris par où il se retrouve — il y est
allédelibérément. Le mouvement case par case, synchronisé avec le rythme du hold,
crée une sensation d'horlogerie : chaque cellule traversée est un tick, chaque
arrêt est une ponctuation. Le joueur lit la grille, planifie, puis agit — et le
mouvement répond exactement à son intention.

La **précision chirurgicale** est la récompense invisible. Quand le joueur traverse
un couloir flanqué de deux gardiens en timing parfait, c'est parce qu'il a compté les
cases à l'avance. Le mouvement discret rend cette comptabilité possible et satisfaisante.

Les **échelles et cordes** sont des refuges. Grimper sur une échelle quand un gardien
approche, c'est utiliser la verticalité comme arme défensive. La montée est plus lente,
mais elle ouvre des angles que le déplacement horizontal ne permet pas.

La **chute** est la conséquence de l'inattention — jamais un accident physique. Le
calcul est toujours possible à l'avance. Tomber est une sanction choisie ou subie,
jamais un glitch.

*Piliers servis : Lisibilité parfaite (chaque pas = 1 case = prédictible), Tension
constante (chaque déplacement est une prise de risque calculée).*

## Detailed Design

### Core Rules

**Règle 1 — Mouvement case par case**
Chaque déplacement déplace le joueur exactement d'une cellule. Le joueur snaps
au centre de la cellule destination via `grid_to_world(col, row)`. Pas d'interpolation
de position — le déplacement est discret et immédiat.

**Règle 2 — Validation avant exécution**
Avant tout déplacement, Player Movement vérifie :
- La cellule destination est dans les limites de la grille (`is_valid`)
- La cellule destination est traversable (`is_traversable`)
- Le joueur est autorisé à se déplacer dans cette direction (règles de gravité et
  de structure ci-dessous)

**Règle 3 — Mouvement horizontal**
Autorisé si : `is_traversable(col±1, row)` ET (`is_grounded(col, row)` OU
`is_climbable(col, row)`). On ne peut pas courir dans le vide — la gravité exige
un support ou une structure.

**Règle 4 — Mouvement vertical (structure seulement)**
- Monter (`row - 1`) : autorisé si `is_climbable(col, row)` (sur LADDER/ROPE) ET
  `is_traversable(col, row - 1)`.
- Descendre (`row + 1`) : autorisé si `is_climbable(col, row)` ET
  (`is_traversable(col, row + 1)` OU `is_climbable(col, row + 1)`).
- Pas de saut, pas de montée libre — uniquement sur LADDER ou ROPE.

**Règle 5 — Buffering des inputs pendant transition**
Si un `move_requested` arrive pendant qu'une transition est en cours, il est
**bufférisé** (maximum 1 input en buffer). À la fin de la transition, le buffer
est consommé. Si un second `move_requested` arrive avant consommation, il remplace
le précédent (last-input-wins, cohérent avec l'Input System).

**Règle 6 — Chute**
Sur réception de `entity_should_fall(player_id)`, Player Movement passe en état
`FALLING` et exécute une chute case par case à `FALL_SPEED` (0.1 s/case) jusqu'à
réception de `entity_landed(player_id)`. Pendant la chute, les `move_requested`
horizontaux sont ignorés. Les descentes de LADDER ne sont pas des chutes.

**Règle 7 — Spawn et reset**
Sur `reset()`, le joueur est replacé sur la cellule de spawn définie par le Level
System, snappé au centre, et re-enregistré dans Grid Gravity.

### States and Transitions

| État | Description |
|---|---|
| `IDLE` | Joueur au sol ou sur structure, en attente d'input |
| `MOVING` | Transition en cours vers la cellule cible (horizontal ou vertical) |
| `FALLING` | Chute case par case, déclenchée par Grid Gravity |
| `DEAD` | Joueur mort, plus aucun mouvement accepté jusqu'au reset |

```
IDLE
  ├─ move_requested(left/right) + validé → MOVING  (déplacement horizontal)
  ├─ move_requested(up/down) + validé + is_climbable → MOVING  (montée/descente)
  └─ entity_should_fall → FALLING

MOVING
  ├─ snap_complete + is_grounded → IDLE
  ├─ snap_complete + NOT is_grounded → FALLING  (bord de plateforme)
  ├─ snap_complete + is_climbable → IDLE  (resté sur structure)
  └─ move_requested pendant transition → buffer (max 1, last-wins)

FALLING
  ├─ entity_landed → IDLE
  └─ move_requested → ignoré

IDLE | MOVING | FALLING
  └─ player_died émis par Level System → DEAD

DEAD
  └─ reset() → IDLE  (spawn position)
```

**Durée de transition** : `MOVE_INTERVAL` (0.2 s par case, synchronisé avec Input
System) pour MOVING horizontal/vertical. `FALL_SPEED` (0.1 s par case) pour FALLING.

### Interactions with Other Systems

| Système | Rôle de Player Movement | Direction |
|---|---|---|
| **Input System** | Consomme `move_requested(direction)` | Consommateur (signal) |
| **Terrain System** | Requête `is_traversable`, `is_solid`, `is_climbable` à chaque validation | Consommateur (requêtes) |
| **Grid System** | Requête `is_valid`, appelle `grid_to_world` pour snap, `world_to_grid` pour position | Consommateur (requêtes) |
| **Grid Gravity** | `register_entity` au spawn, `unregister_entity` à la mort, mise à jour de position après chaque déplacement ; reçoit `entity_should_fall`, `entity_landed` | Bidirectionnel |
| **Enemy AI** | Émet `player_moved(from, to)` — l'IA consomme pour sa logique de poursuite | Producteur (signal) |
| **Pickup System** | Émet `player_moved` — Pickup consomme pour détecter si la cellule contient un trésor | Producteur (signal) |
| **Level System** | Reçoit `spawn_position` au `reset()` ; émet `player_died` vers Level System | Bidirectionnel |
| **Dig System** | Aucune interaction directe. Dig System utilise la position du joueur depuis Grid Gravity | Indirect |

## Formulas

### Validation du mouvement horizontal

```
can_move_horizontal(col, row, dx) =
    is_valid(col + dx, row)
    AND is_traversable(col + dx, row)
    AND (is_grounded(col, row) OR is_climbable(col, row))
```

| Variable | Description |
|---|---|
| `dx` | Direction horizontale : `-1` (gauche) ou `+1` (droite) |
| `is_valid` | Grid System — cellule dans les limites de la grille |
| `is_traversable` | Terrain System — EMPTY, LADDER, ROPE, ou OPEN |
| `is_grounded` | Grid Gravity — support solide ou cellule climbable sous/sur l'entité |
| `is_climbable` | Terrain System — LADDER ou ROPE |

---

### Validation de la montée

```
can_climb_up(col, row) =
    is_climbable(col, row)          # sur LADDER ou ROPE
    AND is_traversable(col, row - 1)  # cellule au-dessus accessible
```

---

### Validation de la descente

```
can_climb_down(col, row) =
    is_climbable(col, row)          # sur LADDER ou ROPE
    AND (is_traversable(col, row + 1) OR is_climbable(col, row + 1))
```

Note : descendre d'une LADDER sur du sol (SOLID en row+1) termine `is_climbable` —
le joueur atterrit en bas de l'échelle en état IDLE.

---

### Durée de transition

```
MOVE_DURATION = 1.0 / MOVE_SPEED   # héritée de InputConfig
FALL_DURATION_PER_CELL = FALL_SPEED  # héritée de GravityConfig
```

| Constante | Valeur par défaut | Source |
|---|---|---|
| `MOVE_SPEED` | 5.0 steps/s | InputConfig Resource |
| `MOVE_DURATION` | 0.2 s | Calculée |
| `FALL_SPEED` | 0.1 s/case | GravityConfig Resource |

## Edge Cases

**EC-01 — Input bufférisé pendant transition**
Si `move_requested` arrive pendant MOVING, il est bufférisé (1 slot, last-wins).
À la fin de la transition, le buffer est consommé et re-validé. Si la destination
bufférisée n'est plus valide au moment de la consommation, le Buffer est vidé et
le joueur reste en IDLE.

**EC-02 — Cellule destination devient invalide pendant la transition**
Edge case improbable (le terrain ne change pas pendant la transition du joueur sauf
dig actif sur une autre case). Comportement : la validation est re-effectuée au
moment du snap. Si invalide, le joueur reste sur la cellule d'origine.

**EC-03 — Joueur atteint le bord horizontal de la grille**
`is_valid(col + dx, row)` = false → mouvement bloqué. Pas de wrap-around.

**EC-04 — Joueur arrive sur une cellule LADDER/ROPE après une chute**
Sur `entity_landed`, si `is_climbable(col, row)` = true, le joueur entre en IDLE
(il est sur la structure, pas en chute libre). Il peut alors grimper normalement.

**EC-05 — Joueur au sommet d'une LADDER, move_up**
`is_traversable(col, row - 1)` = false (plafond ou bord) → montée bloquée.
Le joueur reste au sommet de l'échelle.

**EC-06 — Joueur tente de se déplacer horizontalement en FALLING**
`move_requested` horizontal ignoré pendant FALLING (Règle 6). Pas de dérive latérale.

**EC-07 — move_requested(up) quand le joueur n'est pas sur LADDER/ROPE**
`is_climbable(col, row)` = false → mouvement vertical ignoré. Le joueur ne peut
pas sauter.

**EC-08 — reset() avec le joueur en état FALLING**
Reset force l'état IDLE quelle que soit l'état actuel. Les timers de transition
sont annulés. Le joueur est repositionné sur spawn_position.

## Dependencies

### Dépendances entrantes *(Player Movement dépend de ces systèmes)*

| Système | Nature | Détail |
|---|---|---|
| **Input System** | Signal consommé | `move_requested(direction: Vector2i)` — intention de déplacement |
| **Grid System** | Requêtes | `is_valid`, `grid_to_world`, `world_to_grid` |
| **Terrain System** | Requêtes | `is_traversable`, `is_solid`, `is_climbable` |
| **Grid Gravity** | Signaux reçus + appels | `entity_should_fall`, `entity_landed` ; appels `register_entity`, `unregister_entity` |
| **Level System** | Cycle de vie | Fournit `spawn_position` au reset ; déclenche `reset()` |

### Dépendances sortantes *(ces systèmes dépendent de Player Movement)*

| Système | Ce qu'il consomme |
|---|---|
| **Grid Gravity** | Mise à jour de position après chaque déplacement (`register_entity` avec nouvelle cellule) |
| **Enemy AI** | Signal `player_moved(from: Vector2i, to: Vector2i)` — pour logique de poursuite |
| **Pickup System** | Signal `player_moved(from, to)` — pour détecter la collecte |
| **Level System** | Signal `player_died` — pour déclencher la séquence de mort/restart |

> Player Movement est l'un des nœuds les plus connectés du graphe : il consomme
> les 4 systèmes de fondation (Grid, Terrain, Input, Gravity) et produit des signaux
> pour 4 systèmes de gameplay (Enemy AI, Pickup, Level System, Grid Gravity mis à jour).

## Tuning Knobs

| Paramètre | Valeur par défaut | Source | Impact |
|---|---|---|---|
| `MOVE_SPEED` | 5.0 steps/s | InputConfig Resource | Vitesse de déplacement horizontal et vertical sur structure |
| `MOVE_DURATION` | 0.2 s | Calculée (`1/MOVE_SPEED`) | Durée d'une transition de cellule |
| `FALL_SPEED` | 0.1 s/case | GravityConfig Resource | Vitesse de chute (partagée avec Grid Gravity) |

Player Movement ne détient pas ses propres constantes — il lit `InputConfig` et
`GravityConfig`. Cela garantit la cohérence : modifier `MOVE_SPEED` dans l'éditeur
affecte simultanément l'Input System et Player Movement.

**Contrainte de cohérence** : `FALL_SPEED` (0.1 s) < `MOVE_DURATION` (0.2 s) —
la chute est perçue comme plus rapide que la marche. Cette asymétrie renforce la
sensation de danger gravitationnel.

## Visual/Audio Requirements

**MVP : aucun visuel ni audio propre à Player Movement.**

Player Movement émet des signaux que les systèmes de présentation consomment :

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `player_moved(from, to)` | Visual Feedback System | Animation de déplacement du sprite |
| `player_moved(from, to)` | Audio System | Son de pas selon le type de terrain |
| `entity_should_fall` → FALLING | Visual Feedback System | Animation de chute |
| `entity_landed` | Visual Feedback System | Puff d'impact, frame de landing |
| `player_died` | Visual Feedback System | Animation de mort |
| `player_died` | Audio System | Son de mort |

Player Movement ne connaît pas les sprites, les animations, ni les buses audio.
Il émet, les autres réagissent.

## UI Requirements

**MVP : aucun élément UI.**

La position du joueur est communiquée par sa présence visuelle dans la grille.
Aucun indicateur d'état de mouvement n'est affiché au joueur.

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Mouvement horizontal légal | `move_requested(left)` sur case traversable + grounded → joueur se déplace à gauche |
| AC-02 | Mouvement horizontal bloqué | `move_requested(left)` vers mur (non traversable) → joueur reste immobile |
| AC-03 | Mouvement dans le vide bloqué | `move_requested(left)` depuis case non grounded et non climbable → bloqué (gravité prend le dessus) |
| AC-04 | Montée sur LADDER | `move_requested(up)` sur LADDER → joueur monte d'une case |
| AC-05 | Descente sur LADDER | `move_requested(down)` sur LADDER → joueur descend d'une case |
| AC-06 | Chute déclenchée | `entity_should_fall` reçu → joueur tombe à `FALL_SPEED` par case |
| AC-07 | Atterrissage | `entity_landed` reçu → joueur snap sur cellule, état IDLE |
| AC-08 | Input bufférisé | `move_requested` pendant transition → exécuté après snap si toujours valide |
| AC-09 | Input ignoré en FALLING | `move_requested(left/right)` pendant chute → ignoré, pas de dérive |
| AC-10 | Signal player_moved émis | Après chaque déplacement réussi → `player_moved(from, to)` émis |
| AC-11 | Reset → spawn | `reset()` → joueur replacé sur spawn_position, état IDLE |
| AC-12 | Bord de grille | `move_requested` vers case hors grille → bloqué, pas de crash |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Comportement ROPE** — Le joueur peut-il lâcher une corde en appuyant bas (tomber volontairement) ? Ou doit-il atteindre l'extrémité de la corde pour tomber ? *Recommandation : lâcher = appuyer bas sur ROPE non terminée par SOLID.* | Ouvert | Design |
| OQ-02 | **Collision joueur/gardien** — Qui détecte l'overlap de positions ? Level System (polling) ou Enemy AI (signal quand il arrive sur la cellule du joueur) ? *Recommandation : Enemy AI émet `enemy_reached_player` → Level System réagit.* | Ouvert | Enemy AI GDD |
| OQ-03 | **Stack LIFO Input (EC-01 Input System)** — La stack LIFO des directions est-elle gérée dans l'Input System ou Player Movement absorbe-t-il le buffering et l'Input System émet simplement chaque key_down ? OQ-02 de l'Input System non résolu. | Ouvert | Input System GDD |
