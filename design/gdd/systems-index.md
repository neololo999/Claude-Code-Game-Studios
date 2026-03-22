# Systems Index: Dig & Dash

> **Status**: Approved
> **Created**: 2026-03-22
> **Last Updated**: 2026-03-22
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Dig & Dash est un puzzle-platformer tactique 2D basé sur une grille, inspiré de
Lode Runner. Le gameplay repose sur un core loop **observer → planifier → exécuter →
réagir** où le joueur creuse des trous pour piéger des gardiens et collecte des
trésors dans des niveaux faits main de 5-10 minutes.

Les systèmes se répartissent en : une fondation de grille/terrain, un noyau de
gameplay (mouvement, creusement, IA, collecte), des couches de progression
(niveaux, mondes, scoring), l'habillage (UI, audio, feedback visuel), et une
couche meta (sauvegarde, settings, tooling). Il n'y a pas de systèmes de
networking, narration, ou economy — le jeu est délibérément focalisé.

**Piliers de design** qui contraignent la conception :
1. Puzzle d'abord, action ensuite
2. Tension constante
3. Lisibilité parfaite
4. Montée en complexité maîtrisée

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Grid System (Grille) | Foundation | MVP | Not Started | — | — |
| 2 | Terrain | Foundation | MVP | Not Started | — | Grid System |
| 3 | Input | Foundation | MVP | Not Started | — | — |
| 4 | Player Movement (Mouvement joueur) | Core | MVP | Not Started | — | Grid, Terrain, Input, Gravity |
| 5 | Dig System (Creusement) | Core | MVP | Not Started | — | Grid, Terrain, Input, Player Movement |
| 6 | Enemy AI (IA ennemie) | Core | MVP | Ready for Implementation | enemy-ai.md | Grid, Terrain, Player Movement, Gravity |
| 7 | Pickup System (Collecte) | Core | MVP | Ready for Implementation | pickup-system.md | Grid, Player Movement |
| 8 | Grid Gravity (Gravité) | Core | MVP | Not Started | — | Grid, Terrain |
| 9 | Level System (Niveau) | Gameplay | MVP | Ready for Implementation | level-system.md | Grid, Terrain, Player Movement, Dig, Enemy AI, Pickup |
| 10 | Progression / Worlds (Mondes) | Progression | Alpha | Not Started | — | Level System, Stars/Scoring |
| 11 | Stars / Scoring (Étoiles) | Progression | Vertical Slice | Not Started | — | Level System |
| 12 | Camera | Core | Vertical Slice | Not Started | — | Grid, Level System |
| 13 | HUD | UI | Vertical Slice | Not Started | — | Pickup, Dig, Level System |
| 14 | Main Menu (Menu principal) | UI | Alpha | Not Started | — | Progression/Worlds |
| 15 | Transition Screens (Écrans de transition) | UI | Alpha | Not Started | — | Level System, Stars/Scoring |
| 16 | Visual Feedback / Juice (Feedback visuel) | UI | Vertical Slice | Not Started | — | Dig, Pickup, Enemy AI |
| 17 | Audio | Audio | Vertical Slice | Not Started | — | Dig, Pickup, Enemy AI, Level System |
| 18 | Save System (Sauvegarde) | Persistence | Full Vision | Not Started | — | Progression/Worlds |
| 19 | Settings | Meta | Full Vision | Not Started | — | — |
| 20 | Level Design Tooling | Meta | Full Vision | Not Started | — | Grid, Terrain |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Foundation** | Infrastructure sur laquelle tout repose | Grid, Terrain, Input |
| **Core** | Systèmes de gameplay central | Player Movement, Dig, Enemy AI, Pickup, Gravity, Camera |
| **Gameplay** | Systèmes structurant l'expérience de jeu | Level System |
| **Progression** | Comment le joueur avance dans le jeu | Progression/Worlds, Stars/Scoring |
| **UI** | Affichage et feedback joueur | HUD, Main Menu, Transition Screens, Visual Feedback |
| **Audio** | Son et musique | Audio |
| **Persistence** | Sauvegarde et continuité | Save System |
| **Meta** | Systèmes hors du core loop | Settings, Level Design Tooling |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems Count |
|------|------------|------------------|---------------|
| **MVP** | Core loop fonctionnel : creuser-piéger-collecter dans 10 niveaux | Premier prototype jouable | 9 |
| **Vertical Slice** | Un monde complet poli avec feedback visuel/audio | Démo jouable | 5 |
| **Alpha** | Tous les mondes, progression complète, menus | Toutes features, contenu partiel | 3 |
| **Full Vision** | Sauvegarde, settings, outillage, 60 niveaux polis | Release | 3 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Grid System** — La structure de données fondamentale. Coordonnées, dimensions,
   conversion world↔grid. Tout système qui interagit avec la grille en dépend.
2. **Input** — Capture des entrées clavier. Indépendant de tout autre système.

### Core Layer (depends on Foundation)

1. **Terrain** — depends on: Grid System. Définit les propriétés de chaque case
   (destructible, timer, effets). La grille fournit les coordonnées, le terrain
   fournit le contenu.
2. **Grid Gravity** — depends on: Grid, Terrain. Gère la chute des entités quand
   le support disparaît (trou creusé, bloc détruit).
3. **Player Movement** — depends on: Grid, Terrain, Input, Gravity. Le déplacement
   du joueur sur la grille, contraint par le terrain et la gravité.
4. **Dig System** — depends on: Grid, Terrain, Input, Player Movement. Mécanisme
   de creusement à gauche/droite avec timers de fermeture.
5. **Pickup System** — depends on: Grid, Player Movement. Détection de collecte
   quand le joueur atteint une case trésor.
6. **Enemy AI** — depends on: Grid, Terrain, Player Movement, Gravity. Comportements
   de patrouille et poursuite. Dépend du mouvement joueur pour la logique de
   poursuite et de la gravité pour les chutes/pièges.

### Feature Layer (depends on Core)

1. **Level System** — depends on: Grid, Terrain, Player Movement, Dig, Enemy AI,
   Pickup. Orchestre un niveau complet : initialisation, conditions de
   victoire/défaite, restart.
2. **Stars/Scoring** — depends on: Level System. Évalue la performance du joueur
   après complétion d'un niveau.
3. **Camera** — depends on: Grid, Level System. Cadrage du niveau selon sa taille.

### Presentation Layer (depends on Features)

1. **HUD** — depends on: Pickup, Dig, Level System. Affiche les trésors restants,
   indicateurs de trous, état du niveau.
2. **Visual Feedback** — depends on: Dig, Pickup, Enemy AI. Particules, screenshake,
   animations de satisfaction.
3. **Audio** — depends on: Dig, Pickup, Enemy AI, Level System. SFX contextuels
   et musique d'ambiance.
4. **Transition Screens** — depends on: Level System, Stars/Scoring. Écrans de
   victoire/défaite avec résumé.
5. **Main Menu** — depends on: Progression/Worlds. Navigation entre mondes et niveaux.

### Polish Layer (depends on everything)

1. **Progression/Worlds** — depends on: Level System, Stars/Scoring. Séquence
   linéaire de mondes avec déblocage.
2. **Save System** — depends on: Progression/Worlds. Serialisation du progrès joueur.
3. **Settings** — standalone. Volume, plein écran, contrôles.
4. **Level Design Tooling** — depends on: Grid, Terrain. Extensions éditeur Godot
   pour créer les niveaux efficacement.

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Grid System | MVP | Foundation | S |
| 2 | Input | MVP | Foundation | S |
| 3 | Terrain | MVP | Foundation | M |
| 4 | Grid Gravity | MVP | Core | S |
| 5 | Player Movement | MVP | Core | M |
| 6 | Dig System | MVP | Core | M |
| 7 | Pickup System | MVP | Core | S |
| 8 | Enemy AI | MVP | Core | L |
| 9 | Level System | MVP | Feature | M |
| 10 | Camera | Vertical Slice | Feature | S |
| 11 | Stars/Scoring | Vertical Slice | Feature | S |
| 12 | HUD | Vertical Slice | Presentation | S |
| 13 | Visual Feedback | Vertical Slice | Presentation | M |
| 14 | Audio | Vertical Slice | Presentation | M |
| 15 | Progression/Worlds | Alpha | Polish | M |
| 16 | Main Menu | Alpha | Presentation | M |
| 17 | Transition Screens | Alpha | Presentation | S |
| 18 | Save System | Full Vision | Polish | S |
| 19 | Settings | Full Vision | Polish | S |
| 20 | Level Design Tooling | Full Vision | Polish | M |

Effort estimates: S = 1 session, M = 2-3 sessions, L = 4+ sessions.

---

## Circular Dependencies

- None found. The dependency graph is a clean DAG (Directed Acyclic Graph).

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **Enemy AI** | Design + Technical | Trouver l'équilibre entre prévisibilité (lisible, "chessable") et intelligence (tension). L'IA doit être suffisamment intéressante pour créer des puzzles mais assez lisible pour que le joueur planifie. | Prototyper tôt avec `/prototype enemy-ai`. Commencer avec un algo simple (shortest-path) et itérer. Tester avec des joueurs. |
| **Level System** | Scope | 60 niveaux de qualité est ambitieux pour un solo dev. Chaque niveau demande conception, test, itération. | Créer le Level Design Tooling tôt (malgré sa priorité "Full Vision"). Investir dans un workflow efficace dès le premier monde. |
| **Dig System** | Design | Le timing de creusement et de fermeture est critique pour le "game feel". Trop rapide = pas de tension. Trop lent = frustration. L'interaction avec différents types de terrain multiplie la complexité. | Prototyper le creusement en premier (`/prototype dig`). Tester le "feel" avant de designer les types de terrain avancés. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 20 |
| Design docs started | 0 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 0/9 |
| Vertical Slice systems designed | 0/5 |
| Alpha systems designed | 0/3 |
| Full Vision systems designed | 0/3 |

---

## Next Steps

- [x] Review and approve systems enumeration
- [x] Map dependencies and assign priorities
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Start with: `/design-system grid-system`
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype the highest-risk system early (`/prototype dig-system`)
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Plan the first implementation sprint (`/sprint-plan new`)
