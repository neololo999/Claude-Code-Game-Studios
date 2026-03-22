# Game Concept: Dig & Dash

*Created: 2026-03-22*
*Status: Draft*

---

## Elevator Pitch

> C'est un **puzzle-platformer tactique** où vous creusez des trous pour piéger des
> gardiens et collectez des trésors à travers des niveaux complexes faits main,
> dans l'esprit fidèle de Lode Runner — modernisé visuellement, mais avec l'âme
> du classique intacte.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Puzzle-Platformer Tactique (2D, grille) |
| **Platform** | PC |
| **Target Audience** | Solvers/Achievers, nostalgiques retro, fans de puzzle-platformers |
| **Player Count** | Single-player |
| **Session Length** | 30-60 minutes |
| **Monetization** | Premium (achat unique) |
| **Estimated Scope** | Medium (8-12 mois pour la version complète) |
| **Comparable Titles** | Lode Runner (original), Baba Is You, Into the Breach |

---

## Core Fantasy

Vous êtes le **cambrioleur génial** — le voleur qui déjoue les gardiens non pas
par la force ou la vitesse, mais par l'intelligence pure. Chaque niveau est un
coffre-fort vivant avec des patrouilles de gardiens, et votre seule arme est
votre capacité à lire le terrain, anticiper les mouvements ennemis, et creuser
au bon endroit au bon moment.

La promesse émotionnelle : **le frisson du plan qui s'exécute à la perfection
sous pression** — ou l'adrénaline de l'improvisation quand tout déraille.

---

## Unique Hook

"C'est comme Lode Runner, ET AUSSI chaque niveau est un puzzle élaboré de 5-10
minutes conçu à la main, avec des types de terrain variés (métal, sable, glace,
bois) qui transforment la mécanique de creusement en un outil tactique profond."

Le creusement n'est plus un simple verbe — c'est un **langage** avec lequel le
joueur s'exprime face à chaque puzzle.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 4 | Pixel art moderne soigné, feedback audio satisfaisant sur le creusement et la collecte, animations juice |
| **Fantasy** (make-believe, role-playing) | 5 | Le joueur incarne un cambrioleur malin — l'environnement renforce ce fantasme |
| **Narrative** (drama, story arc) | N/A | Pas de narration — le niveau raconte sa propre histoire par le gameplay |
| **Challenge** (obstacle course, mastery) | 1 | Pilier central — chaque niveau est un défi cognitif croissant |
| **Fellowship** (social connection) | N/A | Jeu solo, pas de composante sociale |
| **Discovery** (exploration, secrets) | 3 | Découvrir la solution, trouver l'approche optimale, comprendre les nouvelles mécaniques |
| **Expression** (self-expression, creativity) | 6 | Multiples solutions possibles par niveau — le joueur choisit son approche |
| **Submission** (relaxation, comfort zone) | 2 | La grille est lisible, le rythme est contrôlé par le joueur, pas de twitch reflexes |

### Key Dynamics (Emergent player behaviors)

- Les joueurs vont naturellement **observer la carte entière** avant de faire
  leur premier mouvement, planifiant mentalement un chemin
- Les joueurs vont **tester des pièges** — creuser à un endroit pour voir comment
  les ennemis réagissent, puis recommencer avec une meilleure stratégie
- Les joueurs vont ressentir un **"eureka moment"** quand ils comprennent comment
  combiner les types de terrain pour résoudre un puzzle
- Les joueurs vont naturellement **optimiser** leurs solutions après la première
  complétion ("je peux faire ça plus proprement")

### Core Mechanics (Systems we build)

1. **Mouvement sur grille** — Déplacement sur grille 2D : courir horizontalement,
   grimper aux échelles, descendre par des barres/cordes, tomber par gravité
2. **Creusement** — Creuser les blocs destructibles à gauche ou à droite du joueur.
   Le trou se referme après un délai. Différents matériaux = temps de creusement
   et de fermeture différents
3. **IA ennemie classique** — Patrouilles avec comportements prévisibles et lisibles.
   Les ennemis poursuivent le joueur, tombent dans les trous, et s'en échappent
   après un délai. Plusieurs types avec comportements distincts
4. **Collecte de trésors** — Tous les trésors doivent être collectés pour ouvrir
   la sortie. Le placement des trésors EST le puzzle
5. **Types de terrain** — Brique (standard), métal (indestructible), sable (s'effrite
   seul), glace (glissant), bois (craque après passage) — chacun ajoute une
   dimension stratégique

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Multiples solutions par niveau, le joueur choisit son approche et son timing | Supporting |
| **Competence** (mastery, skill growth) | Courbe de difficulté progressive, feedback clair sur la compréhension des mécaniques, système d'étoiles | Core |
| **Relatedness** (connection, belonging) | Lien nostalgique avec le classique, sentiment d'appartenance à la culture retro gaming | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — Compléter tous les niveaux, obtenir toutes les étoiles, maîtriser chaque mécanique
- [x] **Explorers** (discovery, understanding systems, finding secrets) — Découvrir les solutions, comprendre les interactions entre types de terrain et comportements ennemis
- [ ] **Socializers** (relationships, cooperation, community) — Non applicable (jeu solo)
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — Non applicable

### Flow State Design

- **Onboarding curve** : Les 5 premiers niveaux enseignent une mécanique à la fois :
  N1 = mouvement, N2 = creusement basique, N3 = piéger un ennemi, N4 = timing
  de fermeture de trou, N5 = tout combiner. Pas de tutoriel textuel — on apprend
  en jouant.
- **Difficulty scaling** : Chaque monde introduit un nouveau concept (type de terrain
  ou type d'ennemi), l'explore en isolation sur 2-3 niveaux, puis le combine avec
  les concepts précédents. La complexité grandit organiquement.
- **Feedback clarity** : Les trésors restants sont affichés clairement. Les trous
  clignotent avant de se refermer. Les ennemis montrent leur direction de patrouille.
  Le joueur sait toujours exactement où il en est.
- **Recovery from failure** : Restart immédiat du niveau — pas de pénalité, pas de
  chargement. La mort est éducative : le joueur comprend ce qui a mal tourné et
  ajuste sa stratégie. Éventuellement un système de "undo" limité pour les niveaux
  très longs.

---

## Core Loop

### Moment-to-Moment (30 seconds)

**Observer → Planifier → Exécuter → Réagir → Recommencer**

Le joueur scanne la position des ennemis, planifie son prochain mouvement (courir
vers un trésor, creuser un piège, attirer un ennemi), exécute l'action, puis
réagit au résultat (ennemi piégé ? chemin ouvert ? danger imminent ?).

Ce qui rend ce loop satisfaisant : le creusement a un **timing** précis — il faut
anticiper pour que le trou soit prêt au bon moment. Chaque creusement est une
**décision stratégique**, pas un réflexe.

### Short-Term (5-10 minutes)

Un **niveau complet** : le joueur arrive, scanne la carte, repère les trésors et
les patrouilles, élabore un plan mental, exécute en s'adaptant, collecte le
dernier trésor, rejoint la sortie. Le "one more level" vient de : *"J'ai compris
le truc ! Le prochain sera encore mieux."*

### Session-Level (30-60 minutes)

Le joueur progresse à travers un **monde thématique** (8-10 niveaux). La difficulté
monte progressivement avec l'introduction de nouvelles mécaniques. Chaque monde
se termine par un **niveau culminant** qui combine toutes les mécaniques apprises.
Point d'arrêt naturel : fin de monde. Points d'arrêt secondaires : après chaque niveau.

### Long-Term Progression

- Progression linéaire à travers 5-6 mondes thématiques
- Système d'étoiles (1-3 par niveau) pour la replay value
- Déblocage de mondes en complétant le précédent
- Le jeu est "fini" quand tous les mondes sont complétés
- Challenge bonus : toutes les 3 étoiles

### Retention Hooks

- **Curiosité** : "Quel nouveau type de terrain/ennemi arrive dans le monde suivant ?"
- **Investment** : Progression linéaire claire, étoiles accumulées, mondes débloqués
- **Social** : N/A
- **Mastery** : "Je peux obtenir 3 étoiles sur ce niveau que j'ai rushé", optimisation
  des solutions

---

## Game Pillars

### Pillar 1: Puzzle d'abord, action ensuite
Chaque niveau est un casse-tête spatial à résoudre. L'action est la conséquence
de la réflexion, pas un substitut.

*Design test*: "Est-ce qu'on peut finir ce niveau en spammant sans réfléchir ?"
→ Si oui, le niveau est raté. On ajoute des contraintes.

### Pillar 2: Tension constante
Le joueur n'est jamais en sécurité. Même pendant qu'il réfléchit, les ennemis
bougent et les trous se referment.

*Design test*: "Est-ce que le joueur peut rester immobile indéfiniment sans
conséquence ?" → Si oui, il manque de la pression. On ajoute des patrouilles
ou un timer de fermeture.

### Pillar 3: Lisibilité parfaite
Le joueur doit pouvoir lire la grille, comprendre les options et anticiper les
conséquences de ses actions en un coup d'œil.

*Design test*: "Est-ce que le joueur est mort sans comprendre pourquoi ?"
→ Si oui, le design visuel ou la mécanique est trop opaque. On clarifie.

### Pillar 4: Montée en complexité maîtrisée
Chaque monde introduit un concept, l'explore, puis le combine avec les précédents.
Jamais deux nouvelles mécaniques en même temps.

*Design test*: "Est-ce que ce niveau utilise une mécanique qui n'a pas été
introduite en isolation ?" → Si oui, réorganiser l'ordre des niveaux.

### Anti-Pillars (What This Game Is NOT)

- **PAS un jeu d'adresse/réflexes** : La difficulté est cognitive, pas motrice.
  Pas de pixel-perfect platforming. Cela compromettrait le pilier de lisibilité
  et d'accessibilité.
- **PAS un roguelike/procédural** : Chaque niveau est fait main, testé, et calibré.
  La qualité du level design prime sur la quantité. La génération procédurale
  compromettrait le pilier "Puzzle d'abord".
- **PAS un jeu de progression RPG** : Pas de stats, pas de power-ups permanents.
  Le joueur progresse par sa compréhension, pas par des chiffres. Des stats
  compromettrait le pilier "Challenge = maîtrise cognitive".
- **PAS un jeu de score/speedrun** : Les étoiles récompensent la complétion
  propre, pas la vitesse pure.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **Lode Runner** (1983) | Mécaniques fondamentales : creuser, piéger, collecter, gravité, grille | Niveaux plus longs et complexes, types de terrain variés, esthétique pixel art moderne | Valide que ces mécaniques sont intemporelles — toujours fun après 40+ ans |
| **Baba Is You** (2019) | Niveaux puzzles faits main de haute qualité, montée en complexité maîtrisée | Notre tension est en temps réel (ennemis qui bougent), pas turn-based | Valide le marché pour des puzzle games exigeants à $15-20 |
| **Into the Breach** (2018) | Lisibilité parfaite + profondeur tactique, "tout est visible, rien n'est facile" | Notre gameplay est time-pressure plutôt que turn-based | Valide que la lisibilité et la profondeur peuvent coexister |
| **Celeste** (2018) | Pixel art moderne magnifique, game feel excellent dans un cadre rétro | Pas de précision de platforming — notre difficulté est cognitive | Valide le marché pour du pixel art premium sur PC |

**Non-game inspirations** :
- Films de casse (Ocean's 11, The Italian Job) — la satisfaction du plan parfaitement exécuté
- L'ère Thomson TO7/MO5 — la nostalgie de l'informatique française des années 80

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 30-50 ans (nostalgie rétro) + 20-35 ans (fans de puzzle games) |
| **Gaming experience** | Mid-core — à l'aise avec le challenge mais pas hardcore |
| **Time availability** | Sessions de 30-60 minutes, soirées et weekends |
| **Platform preference** | PC (Steam) |
| **Current games they play** | Baba Is You, Into the Breach, Celeste, Shovel Knight, Spelunky |
| **What they're looking for** | Un puzzle game qui fait travailler le cerveau avec une tension en temps réel, pas juste de la réflexion statique |
| **What would turn them away** | Twitch reflexes requis, progression grindy, difficulté injuste/illisible |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | **Godot 4** — parfait pour du 2D tile-based, léger, gratuit, GDScript accessible, excellent support TileMap, export PC natif |
| **Key Technical Challenges** | IA ennemie prévisible mais intéressante, système de terrain avec propriétés multiples, level design tool interne |
| **Art Style** | Pixel art moderne — sprites détaillés (16x16 ou 32x32), animations fluides, effets de particules, éclairage dynamique subtil |
| **Art Pipeline Complexity** | Medium — pixel art custom, animations frame-by-frame, tileset par monde |
| **Audio Needs** | Moderate — musique ambient par monde, SFX satisfaisants (creusement, chute, collecte, piège), pas d'audio adaptatif |
| **Networking** | None — jeu strictement single-player |
| **Content Volume** | 50-60 niveaux, 5-6 mondes, 5+ types de terrain, 3-4 types d'ennemis, 8-12h de gameplay |
| **Procedural Systems** | Aucun — tout est fait main |

---

## Risks and Open Questions

### Design Risks
- **Monotonie des niveaux longs** — 5-10 minutes par niveau sans variété suffisante
  pourrait lasser. Mitigation : variété de terrain, introduction régulière de
  mécaniques, rythme interne des niveaux.
- **Frustration du restart** — Mourir à la fin d'un niveau long est très frustrant.
  Mitigation : envisager des checkpoints mid-level ou un système d'undo limité.

### Technical Risks
- **IA ennemie** — Trouver l'équilibre entre prévisibilité (lisible) et intelligence
  (tension). L'IA doit être "chessable" — le joueur doit pouvoir prédire les
  mouvements — sans être triviale.
- **Level design tooling** — Créer 60 niveaux nécessite un outil interne efficace.
  Godot TileMap peut servir de base mais nécessitera des extensions.

### Market Risks
- **Niche** — Le Lode Runner est moins connu des jeunes générations. Le marketing
  devra positionner le jeu comme "puzzle-platformer tactique" plutôt que "clone
  de Lode Runner".
- **Concurrence indie puzzle** — Marché compétitif (Baba Is You, Patrick's Parabox).
  Notre hook doit être clair : puzzle PLUS tension temps réel.

### Scope Risks
- **Volume de niveaux** — 60 niveaux de qualité est ambitieux pour un solo dev.
  Chaque niveau demande conception, test, itération. Budget : ~1 semaine par
  5 niveaux en production.
- **Art assets** — 5-6 tilesets complets + animations joueur/ennemis + effets.
  Ambitieux en solo. Envisager un artiste freelance ou des assets modulaires.

### Open Questions
- **Checkpoints ou undo ?** — Pour les niveaux longs, faut-il des checkpoints
  mid-level, un système d'undo limité (3-5 undos), ou ni l'un ni l'autre ?
  → À tester en prototype
- **IA : combien de types nécessaires ?** — Le MVP teste avec 1 type. À quel
  moment la variété d'ennemis devient-elle nécessaire pour maintenir l'intérêt ?
  → À évaluer après le premier monde de prototype

---

## MVP Definition

**Core hypothesis** : "Les joueurs trouvent le loop creuser-piéger-collecter
engageant sur des niveaux complexes de 5-10 minutes avec une IA ennemie
classique."

**Required for MVP** :
1. Mouvement joueur sur grille (courir, grimper, tomber)
2. Creusement avec timer de fermeture
3. 1 type d'ennemi avec IA de poursuite classique
4. Collecte de trésors + sortie qui s'ouvre
5. 10 niveaux faits main (1 monde complet) avec courbe de difficulté
6. Brique standard + métal indestructible (2 types de terrain minimum)

**Explicitly NOT in MVP** (defer to later) :
- Types de terrain avancés (sable, glace, bois)
- Types d'ennemis additionnels
- Système d'étoiles et scoring
- Polish visuel (particules, éclairage, écrans de transition)
- Musique et SFX finaux
- Menus, settings, sauvegarde

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 10 niveaux, 1 monde | Core loop : mouvement, creusement, 1 ennemi, collecte | 2-3 mois |
| **Vertical Slice** | 10 niveaux polis, 2 types de terrain | Core + scoring/étoiles + 2 types d'ennemis + polish visuel + audio | 4-5 mois |
| **Alpha** | 30 niveaux, 3 mondes | Tous les types de terrain + ennemis, progression complète | 7-8 mois |
| **Full Vision** | 50-60 niveaux, 5-6 mondes | Tout poli, tous SFX/musique, menus, sauvegarde, steam integration | 10-12 mois |

---

## Next Steps

- [ ] Configurer le moteur avec `/setup-engine godot` → remplir CLAUDE.md
- [ ] Valider ce document avec `/design-review design/gdd/game-concept.md`
- [ ] Décomposer le concept en systèmes avec `/map-systems`
- [ ] Créer les GDDs par système avec `/design-system`
- [ ] Première décision d'architecture avec `/architecture-decision`
- [ ] Prototyper le core loop avec `/prototype creusement`
- [ ] Valider le core loop avec `/playtest-report`
- [ ] Planifier le premier sprint avec `/sprint-plan new`
