# Grid System (Système de Grille)

> **Status**: In Design
> **Author**: Laurent + agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Lisibilité parfaite · Puzzle d'abord, action ensuite

## Overview

Le Grid System est l'infrastructure de données centrale du jeu. Il représente le niveau
comme une grille rectangulaire 2D de cellules discrètes, fournit le référentiel de
coordonnées `(col, row)` utilisé par tous les autres systèmes, et expose les fonctions
de conversion entre coordonnées grille et coordonnées monde (pixels).

Le joueur n'interagit jamais directement avec ce système — c'est un contrat technique
invisible qui rend possible tout le reste : mouvement case par case, logique de
creusement, IA des gardiens, placement des trésors. Sans lui, il n'existe aucun espace
commun dans lequel les systèmes peuvent se parler.

Le Grid System est **passif et sans état gameplay** : il ne contient pas le contenu
des cellules (c'est le rôle du Terrain System), il ne fait pas bouger les entités,
il ne simule pas la physique. Il est uniquement responsable de la géométrie de la grille.

## Player Fantasy

Le Grid System ne produit pas de fantasy propre — il est l'infrastructure silencieuse.
Sa contribution émotionnelle est **la lisibilité et la prévisibilité** : le joueur *sent*
que le monde obéit à des règles strictes et régulières. Chaque case a exactement la même
taille, les déplacements sont discrets et déterministes, il n'y a aucune ambiguïté sur
"où est le personnage".

Cette régularité est ce qui rend les puzzles *équitables*. Le joueur peut planifier
mentalement ses actions parce que la grille est un espace de raisonnement logique, pas
un espace fluide et imprévisible. La grille est la promesse implicite :
**"Ce que tu vois est ce qui est."**

*Pilier servi : Lisibilité parfaite — la grille est le socle qui garantit que toute
information visuelle correspond exactement à l'état gameplay.*

## Detailed Design

### Core Rules

**Structure de la grille**
- La grille est un tableau 2D rectangulaire de dimensions `cols × rows` (entiers)
- Les coordonnées sont `(col, row)` avec `col ∈ [0, cols-1]` et `row ∈ [0, rows-1]`
- `(0, 0)` est la cellule en haut à gauche. `col` augmente vers la droite, `row` augmente
  vers le bas
- Chaque cellule a une taille fixe en pixels définie par `CELL_SIZE` (tunable, défaut : 32px)
- La grille ne se redimensionne pas en cours de niveau

**Contenu des cellules**
- La grille stocke uniquement les **IDs de terrain** par cellule (entier). Le contenu
  sémantique appartient au Terrain System
- La grille ne stocke pas les entités (joueur, gardiens) — elles sont positionnées en
  world-space et interrogent la grille via conversion de coordonnées

**Conversions de coordonnées**
- `grid_to_world(col, row)` → centre de la cellule en pixels :
  `Vector2(col * CELL_SIZE + CELL_SIZE/2, row * CELL_SIZE + CELL_SIZE/2)`
- `world_to_grid(world_pos)` → cellule contenant ce point :
  `Vector2i(floor(world_pos.x / CELL_SIZE), floor(world_pos.y / CELL_SIZE))`
- Une position world hors des limites de la grille est **invalide** et doit être rejetée
  par `is_valid(col, row)`

**Voisins**
- La grille expose `get_neighbors(col, row)` retournant les 4 cellules adjacentes
  (haut, bas, gauche, droite) existantes
- Pas de voisins diagonaux dans le core — les systèmes qui en ont besoin calculent
  eux-mêmes

### States and Transitions

Le Grid System n'a pas d'états gameplay. Il a uniquement un cycle de vie de niveau :

**`UNINITIALIZED`** → **`LOADED`** → **`UNLOADED`**

| Transition | Déclencheur | Ce qui se passe |
|---|---|---|
| `UNINITIALIZED → LOADED` | Level System charge un niveau | La grille est allouée avec `cols × rows`, toutes les cellules sont remplies avec les IDs de terrain depuis les données du niveau |
| `LOADED → UNLOADED` | Level System décharge le niveau | La grille est libérée de la mémoire |

**Contraintes :**
- Aucun autre système ne peut interroger la grille avant qu'elle soit `LOADED`
- La grille ne peut pas être modifiée structurellement (redimensionnée) une fois `LOADED`
  — seul le contenu des cellules peut changer (via le Terrain System)
- La modification d'une cellule émet le signal `cell_changed(col, row, old_id, new_id)`
  que les systèmes abonnés peuvent consommer

### Interactions with Other Systems

| Système | Rôle de la grille | Direction |
|---|---|---|
| **Terrain System** | Lit et écrit les IDs de cellule. Seul système autorisé à modifier le contenu de la grille. Émet `cell_changed` via la grille. | Bidirectionnel |
| **Player Movement** | Appelle `world_to_grid` pour trouver sa cellule courante, `grid_to_world` pour se positionner au centre d'une cellule, `is_valid` pour valider une destination | Consommateur |
| **Dig System** | Interroge `get_neighbors` pour trouver la cellule à creuser, puis demande au Terrain System de modifier l'ID | Consommateur |
| **Enemy AI** | Même usage que Player Movement pour naviguer sur la grille. Utilise `get_neighbors` pour le pathfinding case par case | Consommateur |
| **Grid Gravity** | S'abonne à `cell_changed` pour détecter quand une cellule devient vide sous une entité, déclenche la chute | Consommateur (signal) |
| **Pickup System** | Utilise `world_to_grid` pour déterminer sur quelle cellule se trouve un trésor ou le joueur | Consommateur |
| **Level System** | Initialise la grille au chargement du niveau (dimensions + données terrain), la détruit au déchargement | Propriétaire du cycle de vie |
| **Camera** | Lit `cols`, `rows` et `CELL_SIZE` pour calculer les limites de scroll de la caméra | Consommateur (lecture seule) |

## Formulas

### Conversion grille → monde (centre de cellule)

```
world_x = col × CELL_SIZE + CELL_SIZE / 2
world_y = row × CELL_SIZE + CELL_SIZE / 2
```

| Variable | Domaine | Description |
|---|---|---|
| `col` | `[0, cols-1]` | Indice de colonne |
| `row` | `[0, rows-1]` | Indice de ligne |
| `CELL_SIZE` | 32 (défaut) | Taille d'une cellule en pixels |

Exemple — `(col=2, row=3)` avec CELL_SIZE=32 → `Vector2(80, 112)`

---

### Conversion monde → grille

```
col = floor(world_x / CELL_SIZE)
row = floor(world_y / CELL_SIZE)
```

Résultat à valider avec `is_valid()` avant utilisation.

Exemple — `world=(85, 115)` avec CELL_SIZE=32 → `Vector2i(2, 3)`

---

### Validation de coordonnées

```
is_valid(col, row) = (0 ≤ col < cols) ∧ (0 ≤ row < rows)
```

---

### Dimensions du monde en pixels

```
world_width  = cols × CELL_SIZE
world_height = rows × CELL_SIZE
```

Plages valides :
- `cols` ∈ [10, 40]
- `rows` ∈ [8, 25]
- `CELL_SIZE` ∈ [16, 64]

## Edge Cases

| Cas | Comportement attendu |
|---|---|
| `world_to_grid` avec `world_x` multiple exact de `CELL_SIZE` (ex: 64.0) | `floor(64/32) = 2` — la bordure appartient à la cellule de droite/bas. Pas d'ambiguïté. |
| Appel d'une fonction d'accès (`get_cell`, `grid_to_world`, etc.) en état `UNINITIALIZED` | Retourne une erreur. Aucun crash. Aucun résultat partiel retourné. |
| `is_valid(-1, 0)` ou toute coordonnée négative | Retourne `false`. Condition `0 ≤ col` le couvre. Pas de valeur enveloppée, pas d'accès mémoire invalide. |
| Modification de cellule déclenchée depuis un handler de `cell_changed` (réentrance) | La modification secondaire est mise en file d'attente. Jamais appelée récursivement. La grille ne supporte pas les modifications réentrantes pendant l'émission d'un signal. |
| Transition `UNLOADED` entre deux niveaux | Les abonnés existants à `cell_changed` sont déconnectés automatiquement. Reconnexion lors du prochain `LOADED`. |

## Dependencies

### Dépendances entrantes *(la grille dépend de ces systèmes)*

| Système | Nature | Détail |
|---|---|---|
| Level System | Propriétaire du cycle de vie | Fournit `cols`, `rows`, les données de cellules au chargement ; déclenche `LOADED` et `UNLOADED` |

### Dépendances sortantes *(ces systèmes dépendent de la grille)*

| Système | Ce qu'il consomme |
|---|---|
| Terrain System | `get_cell`, `set_cell`, signal `cell_changed` |
| Player Movement | `grid_to_world`, `world_to_grid`, `is_valid`, `get_neighbors` |
| Dig System | `get_cell`, `set_cell` |
| Enemy AI | `grid_to_world`, `world_to_grid`, `get_neighbors` |
| Grid Gravity | Signal `cell_changed`, `get_cell` |
| Pickup System | `grid_to_world`, `get_cell` |
| Camera System | `grid_to_world`, `world_width`, `world_height` |

> La grille ne consomme aucun autre système gameplay. C'est le nœud racine du graphe de dépendances.

## Tuning Knobs

| Paramètre | Valeur par défaut | Plage safe | Impact |
|---|---|---|---|
| `CELL_SIZE` | 32 px | 16 – 64 px | Résolution visuelle, précision des hitboxes, coût mémoire tilemap |
| `cols` | 28 | 10 – 40 | Largeur du niveau en cellules |
| `rows` | 16 | 8 – 25 | Hauteur du niveau en cellules |

**Notes d'ajustement :**
- `CELL_SIZE` < 16 : sprites illisibles et collisions imprécises.
- `CELL_SIZE` > 64 : niveaux trop petits pour les puzzles prévus.
- `cols` × `rows` > 800 cellules : surveiller les performances de `get_neighbors` sur les passes IA complètes.
- `CELL_SIZE` est une constante globale — ne pas le faire varier par niveau (décision locked sauf ADR contraire).

## Visual/Audio Requirements

**Visuels**
- La grille est **invisible en gameplay**. Aucun rendu de lignes de grille par défaut.
- En **mode debug/éditeur** uniquement : affichage optionnel d'un overlay de grille (lignes fines, couleur configurable, opacité ≤ 50%).
- La grille ne possède aucun sprite, shader, ni matériau. Le rendu est entièrement délégué au Terrain System et aux entités.

**Audio**
- Aucun son produit par la grille. Système technique pur, sans événements audio.

## UI Requirements

Aucune UI joueur exposée. Système technique invisible pour le joueur.

## Acceptance Criteria

| # | Critère | Comment tester |
|---|---|---|
| AC-1 | `grid_to_world(2, 3)` avec CELL_SIZE=32 retourne `Vector2(80, 112)` | Test unitaire |
| AC-2 | `world_to_grid(Vector2(85, 115))` avec CELL_SIZE=32 retourne `Vector2i(2, 3)` | Test unitaire |
| AC-3 | `is_valid(-1, 0)` retourne `false` | Test unitaire |
| AC-4 | `is_valid(0, 0)` et `is_valid(cols-1, rows-1)` retournent `true` | Test unitaire |
| AC-5 | `is_valid(cols, 0)` retourne `false` | Test unitaire |
| AC-6 | Appel de `get_cell` en état `UNINITIALIZED` retourne une erreur sans crash | Test unitaire |
| AC-7 | `get_neighbors(1, 1)` retourne exactement 4 voisins | Test unitaire |
| AC-8 | `get_neighbors(0, 0)` retourne exactement 2 voisins (coin) | Test unitaire |
| AC-9 | Modification d'une cellule via `set_cell` émet le signal `cell_changed` avec les bons paramètres `(col, row, old_id, new_id)` | Test unitaire |
| AC-10 | Aucun élément visuel de grille n'est visible en mode gameplay (overlay désactivé) | Test manuel QA |

## Open Questions

1. **`CELL_SIZE` fixe ou variable par niveau ?**
   Actuellement locké à 32 units global. Un niveau "zoomed-in" avec CELL_SIZE=64 est-il envisagé ? Si oui → ADR requis avant implémentation.

2. **Grilles non-rectangulaires ?**
   Le design actuel suppose une grille `cols × rows` rectangulaire. Les niveaux avec zones inaccessibles structurelles sont gérés via des cellules VOID dans le Terrain System. À confirmer qu'aucune architecture de grille non-rectangulaire n'est nécessaire.

3. **Grilles multiples par niveau ?**
   Niveau sur deux plans (ex: avant-plan jouable + arrière-plan décoratif) → deux instances de Grid ou une seule grille avec couches ? Décision à prendre avant le Terrain System.

4. **`CELL_SIZE` en unités Godot vs pixels écran ?**
   `CELL_SIZE=32` = 32 unités Godot, pas nécessairement 32 pixels écran en cas de zoom caméra. À clarifier et documenter avec le Camera System.
