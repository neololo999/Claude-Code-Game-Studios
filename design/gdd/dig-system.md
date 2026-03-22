# Dig System (Creusement)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Puzzle d'abord, action ensuite · Tension constante

## Overview

Le Dig System est le **déclencheur de creusement**. Il reçoit les intentions de
creusement de l'Input System (`dig_requested`), valide que le joueur peut creuser
dans la direction demandée, puis ordonne au Terrain System de passer la cellule
cible en état `DIGGING`. Il notifie Grid Gravity de l'immunité temporaire du joueur
pendant l'animation de creusement.

Le Dig System ne gère pas les timers de refermeture — c'est le Terrain System qui
possède ce cycle de vie. Le Dig System ne sait pas ce qui se passe après avoir
déclenché le creusement : il délègue complètement.

**Responsabilités :**
- Valider la légalité d'un creusement (position joueur, direction, type de cellule)
- Envoyer `dig_request(col, row)` au Terrain System
- Notifier Grid Gravity via `notify_digging(player_id, true/false)` pour l'immunité
- Empêcher le joueur de creuser pendant qu'un creusement est en cours (cooldown)
- Émettre `dig_started(col, row)` et `dig_completed(col, row)` pour les consommateurs

**Hors scope :**
- Timer de refermeture (Terrain System)
- Animation de creusement (Visual Feedback System)
- Mouvement du joueur pendant le creusement (Player Movement)
- Creusement par les gardiens (Enemy AI — si applicable post-MVP)

## Player Fantasy

Creuser est le **seul acte actif d'agression** du joueur.

Dans un jeu à la Lode Runner, il n'y a pas d'arme, pas d'attaque directe. Le joueur
ne peut pas tuer un gardien en le frappant — il le *piège*. Creuser un trou à ses
pieds, anticiper sa trajectory, choisir le bon moment : c'est l'expression d'une
intelligence tactique, pas d'un réflexe.

La satisfaction vient du **timing parfait** : creuser une case juste avant qu'un
gardien passe dessus, puis le regarder tomber. La mécanique est simple — une touche,
une case — mais les implications stratégiques sont profondes. Chaque trou est une
décision : où, quand, combien.

La **contrainte de direction** (gauche/droite uniquement, jamais vers le bas ou le
haut) force le joueur à se positionner correctement avant d'agir. Ce n'est pas une
limitation frustrante — c'est la règle qui crée le jeu.

*Piliers servis : Puzzle d'abord (creuser sans plan = piège pour soi-même), Tension
constante (l'acte de creuser expose le joueur pendant DIG_DURATION).*

## Detailed Design

### Core Rules

**Règle 1 — Direction de creusement**
Le joueur ne peut creuser qu'à gauche ou à droite (`Vector2i(-1, 0)` ou
`Vector2i(1, 0)`). La cellule cible est à `(player_col + dx, player_row)` — même
rang vertical que le joueur.

**Règle 2 — Conditions de validité**
Un creusement est valide si toutes ces conditions sont vraies :
- Le joueur est en état `IDLE` ou `MOVING` horizontal (pas en `FALLING` ni `DEAD`)
- La cellule cible est `is_destructible(col + dx, row)` = true
- La cellule cible est en état `INTACT` (pas déjà DIGGING, OPEN, ou CLOSING)
- Le joueur est au sol (`is_grounded` = true) — on ne creuse pas en l'air

**Règle 3 — Immunité gravitationnelle**
Dès que le creusement commence, `notify_digging(player_id, true)` est envoyé à
Grid Gravity. Le joueur ne peut pas tomber pendant l'animation de creusement
(`DIG_DURATION = 0.5s`), même si la cellule sous lui disparaît pendant ce temps.
À la fin de l'animation, `notify_digging(player_id, false)` est envoyé.

**Règle 4 — Cooldown**
Pendant `DIG_DURATION` (0.5 s), le Dig System est en cooldown : un second
`dig_requested` est ignoré. Un unique creusement à la fois par joueur.

**Règle 5 — Le Terrain System valide en dernier**
Si `dig_request(col, row)` est envoyé mais que le Terrain System rejette (cellule
non destructible entre la validation du Dig System et l'exécution), le Dig System
ignore silencieusement le rejet. Pas de retry, pas de signal d'erreur.

### States and Transitions

```
READY
  └─ dig_requested(dx) + valide → DIGGING  (envoie dig_request, notify_digging=true)

DIGGING
  └─ DIG_DURATION écoulé → READY  (notify_digging=false, émet dig_completed)
```

Le Dig System est intentionnellement simple : deux états, un timer.

### Interactions with Other Systems

| Système | Rôle du Dig System | Direction |
|---|---|---|
| **Input System** | Consomme `dig_requested(direction: Vector2i)` | Consommateur (signal) |
| **Player Movement** | Lit la position joueur (`current_cell`) et l'état (`is_grounded`, pas FALLING) | Consommateur (lecture) |
| **Terrain System** | Envoie `dig_request(col, row)` pour déclencher INTACT → DIGGING | Producteur (commande) |
| **Grid Gravity** | Appelle `notify_digging(player_id, true/false)` pour immunité | Producteur (appel) |
| **Visual Feedback System** | Émet `dig_started(col, row)` — consommé pour l'animation | Producteur (signal) |
| **Audio System** | Même signal `dig_started` pour son de creusement | Producteur (signal) |

## Formulas

### Validation du creusement

```
can_dig(player_col, player_row, dx) =
    player_state IN [IDLE, MOVING]
    AND is_grounded(player_col, player_row)
    AND is_destructible(player_col + dx, player_row)
    AND terrain_state(player_col + dx, player_row) == INTACT
    AND dig_cooldown_remaining == 0
```

| Variable | Source | Description |
|---|---|---|
| `player_state` | Player Movement | État du FSM du joueur |
| `is_grounded` | Grid Gravity | Joueur supporté |
| `is_destructible` | Terrain System | Cellule peut être creusée |
| `terrain_state` | Terrain System | État actuel de la cellule |
| `dig_cooldown_remaining` | Dig System interne | Timer du cooldown en cours |

---

### Cooldown

```
DIG_COOLDOWN = DIG_DURATION    # 0.5s — synchronisé avec l'animation terrain
```

Le cooldown est égal à `DIG_DURATION` du Terrain System. Les deux sont lus depuis
la même `TerrainConfig` Resource pour garantir la cohérence.

## Edge Cases

**EC-01 — `dig_requested` pendant le cooldown**
Le deuxième `dig_requested` est ignoré. Pas de buffer, pas de retry. L'Input System
garantit que `dig_requested` est one-shot (pas de repeat auto), donc cet EC ne se
produit que si le joueur appuie deux fois très vite.

**EC-02 — Le joueur commence à tomber pendant DIG_DURATION**
L'immunité `notify_digging(true)` protège le joueur. Grid Gravity ne peut pas
émettre `entity_should_fall` pour ce joueur. À la fin de `DIG_DURATION`,
`notify_digging(false)` est envoyé et Grid Gravity réévalue immédiatement le support.

**EC-03 — La cellule cible est OPEN ou CLOSING quand `dig_requested` arrive**
`terrain_state != INTACT` → `can_dig` = false. Creusement ignoré. Un trou déjà
ouvert ne peut pas être "re-creusé".

**EC-04 — Le joueur est sur LADDER/ROPE et appuie sur dig**
`is_grounded` sur LADDER = true (Règle 3 du Grid Gravity). Donc creuser depuis une
échelle est **autorisé** si la cellule adjacente est destructible. Décision
intentionnelle : les échelles sont des positions de creusement stratégiques.

**EC-05 — Le joueur est en FALLING quand `dig_requested` arrive**
`player_state == FALLING` → `can_dig` = false. Ignore. On ne creuse pas en tombant.

**EC-06 — reset() pendant DIG_DURATION**
`reset()` force l'état READY, annule le timer, et appelle `notify_digging(false)`
immédiatement. L'immunité est levée avant le repositionnement au spawn.

**EC-07 — Cellule cible hors grille (`col + dx < 0` ou `>= cols`)**
`is_destructible` sur une cellule hors limites = false (Grid System retourne une
cellule invalide). `can_dig` = false. Pas de dig hors grille.

## Dependencies

### Dépendances entrantes *(Dig System dépend de ces systèmes)*

| Système | Nature | Détail |
|---|---|---|
| **Input System** | Signal consommé | `dig_requested(direction: Vector2i)` — one-shot par pression |
| **Player Movement** | Lecture d'état | Position `current_cell`, état FSM (IDLE/MOVING/FALLING/DEAD) |
| **Grid Gravity** | Appel | `notify_digging(player_id, bool)` — immunité gravitationnelle |
| **Terrain System** | Requêtes + Commande | `is_destructible`, `get_tile_state` ; commande `dig_request(col, row)` |
| **Level System** | Cycle de vie | `reset()` entre les niveaux |

### Dépendances sortantes *(ces systèmes dépendent de Dig System)*

| Système | Ce qu'il consomme |
|---|---|
| **Terrain System** | Commande `dig_request(col, row)` — déclenche INTACT → DIGGING |
| **Grid Gravity** | `notify_digging(player_id, true/false)` — résout OQ-01 du Grid Gravity GDD |
| **Visual Feedback System** | Signal `dig_started(col, row)` — animation de creusement |
| **Audio System** | Signal `dig_started(col, row)` — son de creusement |

> **Résolution OQ-01 Grid Gravity** : le Dig System est bien le propriétaire de
> l'appel `notify_digging`. Il appelle `notify_digging(true)` au début du creusement
> et `notify_digging(false)` à la fin. La question ouverte est fermée.

## Tuning Knobs

| Paramètre | Valeur par défaut | Source | Impact |
|---|---|---|---|
| `DIG_DURATION` | 0.5 s | TerrainConfig Resource | Durée du cooldown ; synchronisé avec l'animation terrain |

Le Dig System ne détient pas ses propres constantes — il lit `TerrainConfig`.
`DIG_DURATION` est la seule variable qui affecte le Dig System directement.

**Contrainte de cohérence** : `DIG_DURATION` (0.5 s) > `FALL_SPEED` (0.1 s/case).
Un gardien peut chuter 5 cases pendant que le joueur creuse — garantit que le
piégeage est possible dans des configurations réalistes.

## Visual/Audio Requirements

**MVP : aucun visuel ni audio propre au Dig System.**

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `dig_started(col, row)` | Visual Feedback System | Animation de creusement sur la cellule cible |
| `dig_started(col, row)` | Audio System | Son de pioche / creusement |
| `dig_completed(col, row)` | Visual Feedback System | Transition vers l'état trou ouvert |

La transition visuelle `DIGGING → OPEN` est gérée par le Terrain System + Visual
Feedback System. Le Dig System émet uniquement le signal de début.

## UI Requirements

**MVP : aucun élément UI.**

Le creusement est communiqué par le feedback visuel sur la cellule creusée.
Aucun indicateur de cooldown n'est prévu (le joueur perçoit naturellement la durée
via l'animation terrain).

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Creusement valide | `dig_requested(left)` avec cellule DIRT à gauche + joueur grounded → la cellule passe en DIGGING |
| AC-02 | Creusement bloqué (non destructible) | `dig_requested` vers SOLID non destructible → ignoré, cellule inchangée |
| AC-03 | Creusement bloqué (en l'air) | `dig_requested` pendant FALLING → ignoré |
| AC-04 | Cooldown | Second `dig_requested` dans les 0.5s → ignoré |
| AC-05 | Immunité gravitationnelle | Pendant DIG_DURATION, `entity_should_fall` non émis pour le joueur |
| AC-06 | Fin de cooldown | Après DIG_DURATION, un nouveau `dig_requested` est accepté |
| AC-07 | Signal dig_started | `dig_started(col, row)` émis à chaque creusement valide |
| AC-08 | Creusement sur LADDER | Joueur sur LADDER + cellule DIRT adjacente → creusement autorisé |
| AC-09 | Cellule déjà OPEN | `dig_requested` vers cellule OPEN → ignoré |
| AC-10 | Reset | `reset()` pendant DIG_DURATION → état READY, notify_digging(false) appelé |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Creusement par les gardiens** — Les gardiens peuvent-ils creuser ? Dans Lode Runner original, non. Option post-MVP : gardien "runner" peut creuser. Hors scope MVP. | Ouvert | Enemy AI GDD |
| OQ-02 | **Deux joueurs co-op** — hors scope pour ce projet (single-player), mais le `player_id` dans `notify_digging` anticipe une extension multi-entité si nécessaire. | Fermé (N/A MVP) | — |
