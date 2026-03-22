# Grid Gravity (Gravité)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Tension constante · Puzzle d'abord, action ensuite

## Overview

Le Grid Gravity est le système qui simule la gravité discrète pour toutes les entités
mobiles (joueur, gardiens) dans la grille. Il répond à une question simple à chaque
tick : *"cette entité est-elle supportée ?"* — et si non, il la fait tomber case par
case jusqu'à ce qu'elle le soit.

La gravité dans Dig & Dash n'est pas physique : elle est **déterministe et case par
case**, synchronisée avec le mouvement discret. Une entité ne glisse pas vers le bas
en continu — elle *snap* de cellule en cellule. Cela préserve la lisibilité du puzzle :
le joueur peut anticiper exactement où il tombera, à quelle vitesse.

Le Grid Gravity est un système **passif-réactif** : il ne pilote pas lui-même les
entités, il expose une interface de requête (`is_grounded`, `get_fall_destination`) et
un signal (`entity_should_fall`) que les systèmes de mouvement consomment. Il s'abonne
au signal `cell_changed` de la grille pour détecter quand une cellule sous une entité
disparaît (trou creusé), et notifie immédiatement le système concerné.

**Responsabilités** :
- Déterminer si une entité est au sol (`is_grounded`)
- Signaler quand une entité doit commencer à tomber
- Calculer la cellule d'atterrissage

**Hors scope** :
- Exécuter le mouvement de chute (délégué à Player Movement / Enemy AI)
- Timer de refermeture des trous (Terrain System)
- Détection de collision horizontale

## Player Fantasy

La gravité est la **sanction invisible**.

Quand le joueur creuse un trou sous un gardien et le voit tomber, il ressent une
satisfaction mécanique pure : *j'ai compris les règles, j'ai exploité les règles,
j'ai gagné.* Mais cette même gravité s'applique à lui — tomber dans un trou qu'il
a lui-même creusé, ou rater son timing et se retrouver piégé, c'est le revers de
la médaille.

La gravité discrète crée une **lisibilité totale** qui amplifie la tension. Le joueur
ne se demande jamais "est-ce que je vais tomber ?" — il *sait* qu'il va tomber, il
sait où il va atterrir, et c'est précisément cette certitude qui rend le danger
délibéré plutôt qu'accidentel. Chaque chute est une conséquence d'un choix, pas
d'un glitch physique.

Les LADDER et ROPE sont des **ruptures de la gravité** — des lignes de vie. Atteindre
une échelle depuis le bord d'un précipice, c'est le souffle court avant le calme.
Ce contraste — gravité implacable / appui sécurisant — est le battement émotionnel
de chaque niveau.

*Piliers servis : Tension constante (la gravité est une menace permanente), Puzzle
d'abord (les conséquences gravitationnelles se calculent à l'avance).*

## Detailed Design

### Core Rules

**Règle 1 — Support**
Une entité est *supportée* si au moins l'une de ces conditions est vraie :
- La cellule immédiatement en dessous (`row + 1`) est `is_solid` = true (SOLID, DIRT_*, LADDER)
- L'entité est sur une LADDER (`is_climbable` = true sur sa cellule courante)
- L'entité est sur une ROPE (`is_climbable` = true sur une cellule ROPE)
- L'entité est en train d'effectuer une action de creusement (immunité temporaire)

**Règle 2 — Chute case par case**
Si une entité n'est pas supportée, elle tombe d'une cellule vers le bas à chaque
*fall tick*. La vitesse de chute est fixée par `FALL_SPEED` (en secondes par case).
La chute continue jusqu'à ce que l'entité soit à nouveau supportée.

**Règle 3 — Atterrissage**
L'entité s'aligne au centre de la cellule d'atterrissage (via `grid_to_world`). Snap
immédiat à la grille — pas d'interpolation de position.

**Règle 4 — Chute déclenchée par disparition de support**
Quand `cell_changed` est reçu et que la cellule modifiée est directement sous une
entité enregistrée, Grid Gravity émet `entity_should_fall(entity_id)`. Le système de
mouvement de l'entité reçoit ce signal et exécute la chute.

**Règle 5 — Tracking des entités (Option B — Push avec registre)**
Les entités s'enregistrent avec `register_entity(id, col, row)`. Grid Gravity maintient
un dictionnaire `cell → [entity_ids]`. Sur `cell_changed`, il vérifie si la cellule
affectée était un support pour une entité enregistrée et émet `entity_should_fall` si
nécessaire. Ce registre sert également à répondre à `cell_occupied(col, row)` — résout
OQ-01 du Terrain GDD.

### States and Transitions

Une entité enregistrée peut être dans ces états de gravité :

| État | Description |
|---|---|
| `GROUNDED` | Entité supportée, pas de chute |
| `FALLING` | Entité en chute, `fall_timer` actif |
| `LANDING` | Frame d'atterrissage — snap à la grille, signal `entity_landed` émis |

`GROUNDED → FALLING` : `cell_changed` détecte que le support a disparu sous l'entité,
ou appel `notify_support_removed(entity_id)`  
`FALLING → LANDING` : la cellule destination (`row + 1`) est solide  
`LANDING → GROUNDED` : frame suivante après l'atterrissage

### Interactions with Other Systems

| Système | Rôle de Grid Gravity | Direction |
|---|---|---|
| **Grid System** | S'abonne à `cell_changed(col, row, old_id, new_id)` | Consommateur (signal) |
| **Terrain System** | Appelle `is_solid`, `is_climbable` pour évaluer le support | Consommateur |
| **Player Movement** | Reçoit `entity_should_fall`, appelle `is_grounded`, consomme `entity_landed` | Producteur de signaux |
| **Enemy AI** | Même usage que Player Movement | Producteur de signaux |
| **Dig System** | Déclenche indirectement `cell_changed` via Terrain → Grid | Indirect |

## Formulas

### Évaluation du support

```
is_grounded(col, row) =
    is_solid(col, row + 1)          # cellule sous l'entité est solide
    OR is_climbable(col, row)       # entité sur LADDER ou ROPE
```

| Variable | Domaine | Description |
|---|---|---|
| `col`, `row` | `[0, cols-1]` × `[0, rows-1]` | Position courante de l'entité |
| `is_solid(col, row+1)` | bool | Terrain System — SOLID, DIRT_*, LADDER sous l'entité |
| `is_climbable(col, row)` | bool | Terrain System — LADDER ou ROPE sur la cellule de l'entité |

Cas limite : `row + 1 >= rows` (bas de la grille) → traité comme SOLID (sol invisible).
L'entité ne peut pas sortir par le bas.

---

### Vitesse de chute

```
fall_tick_duration = FALL_SPEED   # secondes par case
```

| Variable | Défaut | Plage | Description |
|---|---|---|---|
| `FALL_SPEED` | 0.1 s | 0.05–0.5 s | Durée d'un tick de chute (une case vers le bas) |

Exemple : `FALL_SPEED = 0.1 s` → chute de 10 cases en 1 seconde.

---

### Cellule d'occupation (pour blocage de refermeture)

```
cell_occupied(col, row) = _entities.has(Vector2i(col, row))
```

Retourne `true` si au moins une entité est enregistrée sur cette cellule. Résout OQ-01
du Terrain GDD — le Terrain System appelle `cell_occupied` avant d'autoriser la
transition CLOSING → INTACT.

## Edge Cases

**EC-01 — Entité déjà en bas de la grille (`row = rows - 1`)**
`is_grounded` évalue `row + 1 >= rows` → retourne `true`. L'entité ne tombe pas hors
grille. Comportement : sol invisible implicite en bas de grille.

**EC-02 — Deux trous creusés simultanément sous deux entités sur la même colonne**
Chaque entité reçoit `entity_should_fall` indépendamment. Les chutes sont exécutées
de façon séquentielle par les systèmes de mouvement respectifs. Pas de conflit au
niveau de Grid Gravity.

**EC-03 — Entité sur LADDER ou ROPE quand la cellule sous elle devient traversable**
`is_grounded` retourne `true` car `is_climbable(col, row)` est `true`. Pas de chute.
L'entité reste sur l'échelle/corde tant qu'elle y est.

**EC-04 — Entité en cours de creusement (Dig System actif)**
L'immunité de chute pendant le creusement est signalée au Grid Gravity via
`notify_digging(entity_id, true/false)`. Grid Gravity ignore `entity_should_fall`
pour cette entité tant que l'immunité est active.

**EC-05 — Entité non enregistrée appelle `is_grounded`**
`is_grounded` est une requête stateless — fonctionne sans enregistrement. Retourne
le résultat basé sur Terrain + Grid uniquement.

**EC-06 — `cell_changed` reçu pour une cellule qui n'est pas un support de l'entité**
Grid Gravity vérifie `changed_cell == Vector2i(entity_col, entity_row + 1)`. Si faux,
signal ignoré. Pas de faux positifs de chute.

**EC-07 — Reset de niveau**
`reset()` vide le registre `_entities`. Toutes les entités se ré-enregistrent au
début du niveau suivant via leur système respectif.

## Dependencies

### Dépendances entrantes *(Grid Gravity dépend de ces systèmes)*

| Système | Nature | Détail |
|---|---|---|
| **Grid System** | Signal abonné | `cell_changed(col, row, old_id, new_id)` — détecte la disparition de support |
| **Terrain System** | Requêtes de propriété | `is_solid`, `is_climbable` pour évaluer `is_grounded` |
| **Level System** | Cycle de vie | Déclenche `reset()` entre les niveaux |

### Dépendances sortantes *(ces systèmes dépendent de Grid Gravity)*

| Système | Ce qu'il consomme |
|---|---|
| **Player Movement** | `is_grounded(col, row)`, signal `entity_should_fall`, signal `entity_landed`, `register_entity`, `unregister_entity` |
| **Enemy AI** | Même interface que Player Movement |
| **Terrain System** | `cell_occupied(col, row)` — pour bloquer la refermeture des trous (résolution OQ-01) |

> Grid Gravity est un nœud intermédiaire dans le graphe de dépendances : il consomme
> Grid + Terrain, et produit l'interface de gravité pour les systèmes de mouvement
> et de terrain.

## Tuning Knobs

| Paramètre | Défaut | Plage | Impact |
|---|---|---|---|
| `FALL_SPEED` | 0.1 s | 0.05–0.5 s | Durée d'un tick de chute (une case vers le bas) |

**Stockage** : regroupé dans une `GravityConfig` Resource (fichier `.tres`), chargée par
Grid Gravity au `_ready`. Permet de modifier les valeurs en éditeur sans toucher au code.

**Contrainte de cohérence** : `FALL_SPEED` doit être inférieur à `DIG_DURATION` (0.5 s
par défaut dans le Dig System). Si la chute est plus lente que le creusement, un gardien
pourrait commencer à creuser avant d'avoir terminé sa chute — incohérence de state.

> Valeur de départ recommandée : 0.1 s. À tuner via playtest sur la vitesse perçue
> par le joueur. L'objectif est que la chute soit *remarquée mais pas lente*.

## Visual/Audio Requirements

**MVP : aucun visuel ni audio propre à Grid Gravity.**

Le système est invisible par nature. Les retours visuels et sonores de la chute sont
la responsabilité des systèmes consommateurs :

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `entity_should_fall(entity_id)` | Player Movement / Enemy AI | Déclenche l'animation de chute de l'entité |
| `entity_landed(entity_id)` | Visual Feedback System | Puff de poussière ou effet d'impact |
| `entity_landed(entity_id)` | Audio System | Son d'atterrissage selon le type de terrain |

Grid Gravity émet les signaux — les systèmes de présentation les écoutent et réagissent.
Pas de duplication de logique visuelle.

## UI Requirements

**MVP : aucun élément UI.**

Grid Gravity est un système purement logique. Il n'a pas d'état à afficher au joueur —
la gravité est communiquée par le comportement visuel des entités, pas par un indicateur
UI.

Si un mode debug est souhaité ultérieurement (hors scope MVP) :
- Overlay de visualisation des entités enregistrées (cases colorées)
- État de gravité par entité (`GROUNDED` / `FALLING` / `LANDING`)

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Support SOLID | Entité avec SOLID en `row+1` → `is_grounded` = `true` |
| AC-02 | Absence de support | Entité avec EMPTY en `row+1` (pas sur LADDER/ROPE) → `is_grounded` = `false` + signal `entity_should_fall` émis |
| AC-03 | Entité sur LADDER | `is_grounded` = `true` quelle que soit la cellule en dessous, tant que `is_climbable` sur cellule courante |
| AC-04 | Trou creusé sous entité | Signal `entity_should_fall` émis dans la même frame où `cell_changed` est reçu |
| AC-05 | Durée de chute | Chute de 5 cases = `5 × FALL_SPEED` secondes (±1 frame) |
| AC-06 | `cell_occupied` | Retourne `true` si entité enregistrée sur la case, `false` sinon |
| AC-07 | `reset()` | Après `reset()`, aucune entité dans le registre ; `cell_occupied` retourne `false` partout |
| AC-08 | Bas de grille | Entité à `row = rows - 1` → `is_grounded` = `true`, pas de signal `entity_should_fall` |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Immunité de creusement** — qui signal l'immunité au Grid Gravity ? `notify_digging(entity_id, true)` est l'interface prévue, mais c'est le Dig System qui doit l'appeler. Confirmer dans le Dig System GDD. | Ouvert | Dig System GDD |
| OQ-02 | **Chute simultanée joueur + gardien sur la même cellule** — si les deux tombent dans la même colonne et arrivent sur la même case au même instant, qui a la priorité ? Collision ou cohabitation ? | Ouvert | Player Movement + Enemy AI GDD |
