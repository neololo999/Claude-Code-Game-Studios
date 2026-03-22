# Enemy AI (IA ennemie)

> **Status**: Ready for Implementation
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Tension constante · Lisibilité parfaite · Puzzle d'abord

## Overview

L'Enemy AI est le système qui pilote les **gardiens** — les antagonistes du joueur.
Chaque gardien est une entité autonome qui patrouille, poursuit le joueur quand il
est à portée, tombe dans les trous, et s'en échappe après un délai.

Le comportement de l'IA est **délibérément prévisible et lisible** : les gardiens
suivent des règles simples et déterministes qui permettent au joueur de les anticiper.
Ce n'est pas une IA difficile à battre — c'est une IA *lisible*, qui rend le puzzle
soluble par la réflexion.

Chaque gardien est géré comme une entité indépendante avec son propre état, sa
propre position dans la grille, et son propre cycle de gravité enregistré dans
Grid Gravity.

**Responsabilités :**
- Déplacer chaque gardien case par case selon les règles de comportement
- Basculer entre patrouille et poursuite selon la visibilité du joueur
- Gérer la chute dans les trous et l'évasion après `TRAP_ESCAPE_TIME`
- Émettre `enemy_reached_player` quand un gardien atteint la cellule du joueur
- S'enregistrer dans Grid Gravity et mettre à jour la position

**Hors scope :**
- Collision physique (pas de contact physique — seule la cellule commune déclenche la mort)
- Creusement par les gardiens (hors MVP)
- Coordination inter-gardiens (pas de comportement de groupe)
- Pathfinding A* complexe (comportement greedy suffisant pour MVP)

## Player Fantasy

Le gardien est une **contrainte prévisible, pas une surprise**.

Dans Dig & Dash, le joueur ne meurt jamais à cause d'un comportement d'IA imprévisible.
Il meurt parce qu'il a mal calculé, mal anticipé, ou pris un risque délibéré. Les
gardiens bougent selon des règles que le joueur peut apprendre, mémoriser, et
exploiter.

Voir un gardien tomber dans un trou qu'on vient de creuser juste à la bonne profondeur,
c'est la récompense d'un calcul réussi. Voir un gardien qu'on croyait piégé s'évader
et revenir, c'est la pression qui force à agir vite.

La **lisibilité des patrouilles** est fondamentale : chaque gardien a un comportement
de base visible dès le début du niveau — le joueur peut lire le terrain, compter les
cases, et construire son plan avant de faire un seul mouvement.

*Piliers servis : Lisibilité parfaite (comportement IA déterministe et observable),
Tension constante (les gardiens créent une pression permanente), Puzzle d'abord
(la solution optimale exploite les règles de l'IA).*

## Detailed Design

### Core Rules

**Règle 1 — Mouvement case par case**
Un gardien se déplace d'une case à la fois, exactement comme le joueur. Même
`MOVE_SPEED` par défaut. Snap au centre de la cellule. Pas d'interpolation.

**Règle 2 — Deux comportements : PATROL et CHASE**
- **PATROL** : le gardien patrouille horizontalement sur sa plateforme. Il avance
  dans sa direction courante jusqu'à un obstacle (mur, bord, trou non traversable),
  puis fait demi-tour.
- **CHASE** : si le joueur est visible (même colonne ou même rangée, ligne de vue
  dégagée), le gardien entre en CHASE et se déplace vers le joueur par le chemin
  le plus court (greedy : réduire la distance manhatanne case par case).

**Règle 3 — Transition PATROL ↔ CHASE**
- PATROL → CHASE : joueur dans le rayon de détection (`DETECTION_RANGE` cases) ET
  dans la ligne de vue (pas de mur SOLID entre gardien et joueur sur la même rangée
  ou colonne).
- CHASE → PATROL : joueur hors de portée (`> DETECTION_RANGE`) OU ligne de vue
  coupée. Le gardien reprend sa patrouille à la position actuelle.

**Règle 4 — Gravité**
Les gardiens sont soumis à la même gravité que le joueur. Enregistrés dans Grid
Gravity, ils reçoivent `entity_should_fall` et tombent case par case. Pendant la
chute, l'IA est suspendue (le gardien ne se déplace pas horizontalement).

**Règle 5 — Piégeage et évasion**
Quand un gardien tombe dans une cellule `OPEN` (trou creusé) et que sa cellule
passe en `CLOSING`, il est piégé. Il entre en `TRAPPED` et attend `TRAP_ESCAPE_TIME`.
À l'expiration, il se téléporte sur la rangée du haut du niveau (rescate position)
et reprend son comportement normal. Si la cellule se referme (`INTACT`) avant
l'expiration, le gardien meurt et respawne (comportement identique au rescate).

**Règle 6 — Détection de collision avec le joueur**
Si, après un déplacement, le gardien occupe la même cellule que le joueur, il
émet `enemy_reached_player(enemy_id, cell)`. Le Level System réagit en
déclenchant la mort du joueur. Résout OQ-02 de Player Movement.

**Règle 7 — Mouvements verticaux**
Les gardiens peuvent emprunter les LADDER et ROPE, avec les mêmes règles que le
joueur. En mode CHASE et si le joueur est sur une rangée différente, le gardien
priorise le déplacement vertical sur structure pour réduire la distance.

### States and Transitions

| État | Description |
|---|---|
| `PATROL` | Déplacement horizontal, demi-tour sur obstacle |
| `CHASE` | Déplacement greedy vers le joueur |
| `FALLING` | Chute case par case, IA suspendue |
| `TRAPPED` | Dans un trou, timer d'évasion actif |
| `DEAD` | Mort (refermeture sur gardien), en attente de respawn |

```
PATROL
  ├─ joueur détecté dans DETECTION_RANGE + ligne de vue → CHASE
  └─ obstacle atteint → demi-tour, reste PATROL

CHASE
  ├─ joueur hors portée / ligne de vue coupée → PATROL
  ├─ arrive sur cellule du joueur → émet enemy_reached_player
  └─ entity_should_fall → FALLING

PATROL | CHASE
  └─ entity_should_fall → FALLING

FALLING
  └─ entity_landed → PATROL ou CHASE (réévalue la détection)

PATROL | CHASE | FALLING
  └─ atterrit sur cellule OPEN (trou) → TRAPPED

TRAPPED
  ├─ TRAP_ESCAPE_TIME écoulé → DEAD (respawn)
  └─ cellule CLOSING avant timer → DEAD (respawn)

DEAD
  └─ RESPAWN_DELAY écoulé → PATROL (position rescate en haut du niveau)
```

### Interactions with Other Systems

| Système | Rôle de l'Enemy AI | Direction |
|---|---|---|
| **Grid System** | `is_valid`, `grid_to_world`, `world_to_grid`, `get_neighbors` pour pathfinding | Consommateur |
| **Terrain System** | `is_traversable`, `is_solid`, `is_climbable`, `get_tile_state` pour validation mouvement et détection trou | Consommateur |
| **Grid Gravity** | `register_entity`, `entity_should_fall`, `entity_landed`, mise à jour position, `cell_occupied` | Bidirectionnel |
| **Player Movement** | Consomme `player_moved(from, to)` pour mettre à jour la position cible en CHASE | Consommateur (signal) |
| **Level System** | Émet `enemy_reached_player` → Level System déclenche mort joueur ; reçoit spawns positions au reset | Producteur + Consommateur |
| **Visual Feedback** | Émet `enemy_fell`, `enemy_trapped`, `enemy_escaped` | Producteur (signaux) |

## Formulas

### Détection du joueur

```
player_visible(guard_col, guard_row, player_col, player_row) =
    manhattan_distance <= DETECTION_RANGE
    AND line_of_sight_clear(guard, player)
```

```
manhattan_distance(g, p) = abs(g.col - p.col) + abs(g.row - p.row)
```

```
line_of_sight_clear(g, p) =
    (g.row == p.row AND no SOLID between g.col and p.col on row g.row)
    OR (g.col == p.col AND no SOLID between g.row and p.row on col g.col)
```

Note : la ligne de vue n'est vérifiée que sur la même rangée **ou** la même colonne.
Pas de diagonale.

---

### Greedy move vers le joueur (CHASE)

```
next_cell = argmin over valid_neighbors of manhattan_distance(neighbor, player_cell)
```

Priorité de tie-breaking : horizontal > vertical (le gardien préfère s'aligner
horizontalement avant de monter/descendre).

| Variable | Description |
|---|---|
| `valid_neighbors` | Cases adjacentes traversables et accessibles (is_traversable + règles gravité) |
| `player_cell` | Dernière position connue du joueur (mise à jour sur `player_moved`) |

---

### Paramètres temporels

```
ENEMY_MOVE_SPEED = MOVE_SPEED   # 5.0 steps/s par défaut — même vitesse que joueur
TRAP_ESCAPE_TIME = 8.0 s        # temps avant évasion du trou
RESPAWN_DELAY = 2.0 s           # délai avant réapparition
```

| Constante | Défaut | Plage | Impact |
|---|---|---|---|
| `DETECTION_RANGE` | 8 cases | 4–16 | Rayon de détection du joueur |
| `ENEMY_MOVE_SPEED` | 5.0 steps/s | 3–7 | Vitesse de déplacement gardien |
| `TRAP_ESCAPE_TIME` | 8.0 s | 4–15 | Temps avant sortie du trou |
| `RESPAWN_DELAY` | 2.0 s | 1–5 | Délai avant réapparition |

## Edge Cases

**EC-01 — Gardien face à un trou en PATROL**
En patrouille, un gardien ne saute pas volontairement dans un trou. Si la case
devant lui est `OPEN` (traversable mais non solide), il fait demi-tour comme pour
un mur. Seule la chute involontaire (support enlevé sous lui) l'envoie dans un trou.

**EC-02 — Deux gardiens sur la même cellule**
Autorisé — les gardiens peuvent se superposer. Chacun agit indépendamment.
Aucune résolution de collision entre gardiens.

**EC-03 — Gardien piégé dans un trou qui se referme avant TRAP_ESCAPE_TIME**
Le gardien passe directement en `DEAD` → respawn. Idem si la cellule passe en
`CLOSING` : le gardien est forcé de sortir (via respawn), la refermeture est
bloquée par `cell_occupied` jusqu'au respawn, puis se complète.

**EC-04 — Le joueur est en FALLING quand un gardien l'atteint**
La détection est basée sur la cellule courante (`current_cell`). Si le joueur
est en transition de chute, `enemy_reached_player` est émis dès que les cellules
coïncident. Level System gère la mort.

**EC-05 — Gardien en CHASE, joueur sur LADDER**
Le gardien peut aussi emprunter les LADDER pour s'approcher. Il utilise le chemin
greedy qui inclut les mouvements verticaux sur structure.

**EC-06 — Gardien au bord de la grille en PATROL**
`is_valid(col + dx, row)` = false → demi-tour. Comportement identique à un mur.

**EC-07 — reset() avec gardiens en TRAPPED ou FALLING**
`reset()` force tous les gardiens à leur position de spawn définie par le Level
System. Tous les timers annulés, tous les états réinitialisés à `PATROL`.

**EC-08 — Gardien en CHASE, dernière position connue du joueur obsolète**
Si le joueur n'est plus visible (ligne de vue coupée), le gardien se déplace vers
la dernière position connue (`CHASE` jusqu'à y arriver), puis bascule en `PATROL`.
Pas de "mémoire" au-delà de la dernière position connue.

## Dependencies

### Dépendances entrantes *(Enemy AI dépend de ces systèmes)*

| Système | Nature | Détail |
|---|---|---|
| **Grid System** | Requêtes | `is_valid`, `grid_to_world`, `world_to_grid`, `get_neighbors` |
| **Terrain System** | Requêtes | `is_traversable`, `is_solid`, `is_climbable`, `get_tile_state`, `get_dig_timer_remaining` |
| **Grid Gravity** | Signaux + Appels | `entity_should_fall`, `entity_landed` ; `register_entity`, `unregister_entity`, `cell_occupied` |
| **Player Movement** | Signal consommé | `player_moved(from, to)` — mise à jour de la cible de poursuite |
| **Level System** | Cycle de vie | Positions de spawn + rescate au reset |

### Dépendances sortantes *(ces systèmes dépendent de Enemy AI)*

| Système | Ce qu'il consomme |
|---|---|
| **Grid Gravity** | Position mise à jour après chaque déplacement (`register_entity` avec nouvelle cellule) |
| **Level System** | Signal `enemy_reached_player(enemy_id, cell)` — déclenche mort joueur. **Résout OQ-02 de Player Movement.** |
| **Visual Feedback System** | `enemy_moved`, `enemy_fell`, `enemy_trapped`, `enemy_escaped`, `enemy_died` |
| **Audio System** | Mêmes signaux pour sons d'IA |

## Tuning Knobs

| Paramètre | Défaut | Plage | Source | Impact |
|---|---|---|---|---|
| `DETECTION_RANGE` | 8 cases | 4–16 | EnemyConfig Resource | Rayon de détection |
| `ENEMY_MOVE_SPEED` | 5.0 steps/s | 3–7 | EnemyConfig Resource | Vitesse gardien. Égale à celle du joueur par défaut — à réduire pour faciliter |
| `TRAP_ESCAPE_TIME` | 8.0 s | 4–15 | EnemyConfig Resource | Fenêtre de piégeage |
| `RESPAWN_DELAY` | 2.0 s | 1–5 | EnemyConfig Resource | Délai de réapparition |

**Stockage** : `EnemyConfig` Resource (`.tres`), une instance par type de gardien
si plusieurs types sont introduits post-MVP.

**Contrainte de cohérence** :
- `TRAP_ESCAPE_TIME` doit être > `CLOSE_TIMER_FAST` (4s) pour que les gardiens
  puissent être piégés même avec les blocs rapides.
- `ENEMY_MOVE_SPEED` ≤ `MOVE_SPEED` joueur recommandé au MVP pour que le joueur
  soit toujours capable de distancer un gardien en ligne droite.

## Visual/Audio Requirements

**MVP : aucun visuel ni audio propre à Enemy AI.**

| Signal émis | Consommateur | Retour attendu |
|---|---|---|
| `enemy_moved(id, from, to)` | Visual Feedback | Animation de déplacement du gardien |
| `enemy_fell(id)` | Visual Feedback | Déclenchement de l'animation de chute |
| `enemy_trapped(id, cell)` | Visual Feedback | Animation "gardien piégé" (gardien visible dans le trou) |
| `enemy_escaped(id)` | Visual Feedback | Animation d'évasion + son |
| `enemy_died(id)` | Visual Feedback | Disparition + son |
| `enemy_reached_player` | Level System | (pas de feedback direct — Level System déclenche mort joueur) |

## UI Requirements

**MVP : aucun élément UI.**

Les gardiens sont entièrement communiqués par leurs sprites dans la grille.
Aucun indicateur de détection ou de statut de gardien n'est prévu.

## Acceptance Criteria

| ID | Critère | Condition de réussite |
|---|---|---|
| AC-01 | Patrouille | Gardien sans joueur visible → se déplace horizontalement, fait demi-tour sur obstacle |
| AC-02 | Demi-tour sur trou | Gardien en PATROL face à une cellule OPEN → demi-tour, ne saute pas |
| AC-03 | Détection joueur | Joueur à ≤ DETECTION_RANGE cases, même rangée, ligne claire → CHASE |
| AC-04 | Poursuite greedy | En CHASE, gardien réduit la distance de Manhattan à chaque step |
| AC-05 | Retour patrouille | Joueur hors de DETECTION_RANGE → gardien repasse en PATROL |
| AC-06 | Gravité gardien | Support enlevé sous gardien → `entity_should_fall` → gardien tombe |
| AC-07 | Piégeage | Gardien atterrit sur cellule OPEN → état TRAPPED, timer actif |
| AC-08 | Évasion | Après TRAP_ESCAPE_TIME → gardien respawn en position rescate |
| AC-09 | Collision joueur | Gardien arrive sur cellule joueur → `enemy_reached_player` émis |
| AC-10 | Mont d'échelle | Gardien en CHASE peut emprunter LADDER pour raccourcir la distance |
| AC-11 | Reset | `reset()` → tous les gardiens replacés à leur spawn, état PATROL |
| AC-12 | Signal player_moved | Gardien met à jour sa cible de poursuite sur `player_moved` |

## Open Questions

| ID | Question | Statut | Responsable |
|---|---|---|---|
| OQ-01 | **Types de gardiens** — MVP : un seul type. Post-MVP : introduire un "runner" (plus rapide) ou un "digger" (peut creuser). Ces types auraient leur propre EnemyConfig. | Ouvert | Game Design |
| OQ-02 | **Rescate position** — La position de réapparition est-elle fixe (haut du niveau, colonne définie par le level designer) ou aléatoire sur la rangée supérieure ? *Recommandation : fixe, définie par le level designer dans les données du niveau.* | Ouvert | Level System GDD |
| OQ-03 | **Ligne de vue diagonale** — Le rayon de détection est actuellement orthogonal uniquement. Faut-il ajouter les diagonales ? *Recommandation : non pour MVP — simplifie la lisibilité.* | Fermé (non pour MVP) | — |
