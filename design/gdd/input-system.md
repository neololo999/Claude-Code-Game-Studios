# Input System

> **Status**: Ready for Implementation
> **Author**: Game Designer + Agents
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Lisibilité parfaite

## Overview

The Input System is a **passive translator layer**. It captures raw hardware events (keyboard, gamepad) and emits normalized, discrete action events to other systems. It has no knowledge of game state — it only answers "what is the player pressing right now?"

**Model: Hold to Move (B)**
Holding a directional key triggers continuous cell-by-cell movement at a fixed step rate. Releasing stops the player cleanly at the current cell. No queuing, no sliding — the input signal is immediate and honest.

**Supported actions:**
- `move(direction: Vector2i)` — Left / Right / Up / Down
- `dig(direction: Vector2i)` — Left / Right only

**Supported devices (MVP):**
- Keyboard: WASD + Arrow keys (both layouts active simultaneously)
- Gamepad: scope TBD — see Open Questions

## Player Fantasy

Le joueur ne réfléchit pas à ses doigts — ses mains *sont* le personnage.

Chaque pression de touche produit exactement un résultat prévisible. Le joueur ressent un contrôle total et chirurgical sur chaque cellule traversée. Quand il rate un saut ou tombe dans un piège, c'est clairement *sa* faute — jamais celle des contrôles.

Le rythme naturel du jeu naît du hold : appuyer = avancer, relâcher = s'arrêter. Simple. Lire la grille, prendre une décision, agir. Les contrôles disparaissent.

## Detailed Design

### Core Rules

1. L'Input System ne connaît pas l'état du jeu. Il interroge uniquement le hardware.
2. **Hold to move** : tant qu'une touche directionnelle est maintenue, le système émet un événement `move_requested(direction)` à intervalle régulier (`MOVE_INTERVAL`).
3. La première émission est **immédiate** au `key_down`. Pas de délai initial — le joueur ressent une réponse instantanée.
4. **Dig** : touche dédiée (par défaut Z/X pour gauche/droite). Émet `dig_requested(direction)` une seule fois par pression (pas de repeat auto).
5. Priorité des directions si plusieurs touches maintenues simultanément : **dernière touche enfoncée gagne** (last-input-wins). Une seule direction active à la fois.
6. Le système expose uniquement des **actions nommées** (via Godot InputMap). Pas de référence directe aux keycodes dans la logique du jeu.

### States and Transitions

```
IDLE
  └─ key_down(direction) → MOVING  (emit move_requested immédiatement)

MOVING
  ├─ timer tick (MOVE_INTERVAL) → emit move_requested(current_direction)
  ├─ key_down(other_direction) → MOVING  (change direction, reset timer)
  └─ key_up(current_direction) → IDLE  (stop net)

IDLE ou MOVING
  └─ key_down(dig_left / dig_right) → émet dig_requested(direction)  [one-shot, ne change pas l'état]
```

### Interactions with Other Systems

| Système | Type | Description |
|---|---|---|
| Player Movement | Consumer | Reçoit `move_requested(direction)` — décide si le mouvement est légal |
| Dig System | Consumer | Reçoit `dig_requested(direction)` — décide si le creusage est légal |
| Pause / UI | Override | En état UI/pause, l'Input System ne doit pas émettre d'actions jeu |

## Formulas

**MOVE_INTERVAL** — intervalle entre deux `move_requested` consécutifs en état MOVING :

```
MOVE_INTERVAL = 1.0 / MOVE_SPEED
```

| Constante | Valeur par défaut | Unité |
|---|---|---|
| `MOVE_SPEED` | `5.0` | steps/seconde |
| `MOVE_INTERVAL` | `0.2` | secondes |

À 5 steps/s, le joueur traverse une cellule toutes les 200 ms — rythme proche du Lode Runner original (~4–6 steps/s).

`dig_requested` est one-shot : pas de formule de répétition. Le Dig System gère sa propre durée.

## Edge Cases

**EC-01 — Deux directions simultanées** : Si le joueur appuie Left puis Right (sans relâcher Left), la direction active devient Right (last-input-wins). Si Right est relâché, on revient à Left (encore maintenue). Implémentation : stack LIFO des touches directionnelles actives.

**EC-02 — Input pendant une transition de cellule** : L'Input System ne connaît pas les transitions — il émet sans attendre. C'est le Player Movement qui ignore ou met en attente les `move_requested` pendant une transition en cours.

**EC-03 — Dig pendant le mouvement** : Autorisé. `dig_requested` est émis immédiatement, indépendamment de l'état MOVING/IDLE. Le Dig System décide de l'accepter ou non.

**EC-04 — Input en pause / écran UI** : L'Input System doit cesser d'émettre des actions jeu. Implémentation recommandée : désactiver le nœud ou ignorer via `set_process_unhandled_input(false)`.

**EC-05 — Touche maintenue au lancement de scène** : Si le joueur maintient une touche lors du chargement, aucun `move_requested` ne doit être émis avant que la scène soit prête. Le système doit s'initialiser en IDLE.

## Dependencies

### Dépendances amont

Aucune. L'Input System n'a pas de prérequis — il lit directement le hardware via Godot InputMap.

### Dépendances aval (systèmes qui consomment l'Input System)

| Système | Ce qu'il consomme | Contrat attendu |
|---|---|---|
| Player Movement | `move_requested(direction: Vector2i)` | Signal émis à `MOVE_INTERVAL`, direction unitaire, premier step immédiat |
| Dig System | `dig_requested(direction: Vector2i)` | Signal one-shot par pression, direction Left ou Right uniquement |

### Propriétaire du cycle de vie

L'Input System est instancié par la scène de jeu principale. Il est actif dès que la scène est ready et inactif en pause/UI.

### Configuration requise (Godot InputMap)

Actions à déclarer dans le projet :
`move_left`, `move_right`, `move_up`, `move_down`, `dig_left`, `dig_right`

## Tuning Knobs

| Constante | Valeur par défaut | Plage suggérée | Impact |
|---|---|---|---|
| `MOVE_SPEED` | `5.0` steps/s | 3–8 | Vitesse de déplacement du joueur |
| `MOVE_INTERVAL` | `0.2` s | dérivé | Calculé : `1.0 / MOVE_SPEED` |
| `GAMEPAD_DEADZONE` | `0.5` | 0.2–0.8 | Seuil stick analogique (scope gamepad TBD) |

Ces valeurs sont stockées dans `InputConfig` (Resource Godot). `MOVE_SPEED` est le seul levier à ajuster en playtest — les autres en dérivent.

## Visual/Audio Requirements

Aucun. L'Input System est invisible — il n'émet aucun feedback direct au joueur.

Les feedbacks visuels et audio (animation de pas, son de mouvement) sont la responsabilité des systèmes consommateurs (Player Movement, Dig System).

## UI Requirements

- **MVP** : aucun remapping clavier. Bindings déclarés dans Project Settings → InputMap.
- **Full Vision (post-MVP)** : écran de remapping clavier dans les options. 6 actions à exposer : `move_left`, `move_right`, `move_up`, `move_down`, `dig_left`, `dig_right`.

## Acceptance Criteria

- **AC-01** : Appuyer `move_left` → `move_requested(Vector2i(-1, 0))` émis immédiatement.
- **AC-02** : Maintenir `move_left` → `move_requested` répété toutes les 200 ms (`MOVE_SPEED` = 5).
- **AC-03** : Relâcher `move_left` → plus aucun `move_requested` émis.
- **AC-04** : Appuyer `move_left` puis `move_right` (sans relâcher) → direction active = `Vector2i(1, 0)`.
- **AC-05** : Relâcher `move_right` (`move_left` encore maintenu) → direction revient à `Vector2i(-1, 0)`.
- **AC-06** : Appuyer `dig_left` → `dig_requested(Vector2i(-1, 0))` émis une fois.
- **AC-07** : Maintenir `dig_left` → `dig_requested` émis une seule fois (pas de repeat).
- **AC-08** : WASD et touches flèches fonctionnent simultanément (deux layouts actifs en même temps).
- **AC-09** : Quand `set_process_unhandled_input(false)`, aucun signal émis.
- **AC-10** : Au `_ready()`, état = IDLE, aucun signal émis avant le premier input utilisateur.

## Open Questions

- **OQ-01** — Support gamepad MVP ou post-MVP ? *Recommandation : post-MVP pour ne pas bloquer le prototype.*
- **OQ-02** — La stack LIFO (EC-01) est-elle gérée dans l'Input System ou le Player Movement gère-t-il lui-même la priorité de direction ?
- **OQ-03** — Le remapping clavier est-il en scope Full Vision ou post-1.0 ?
