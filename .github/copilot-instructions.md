# GitHub Copilot Instructions

## What This Repository Is

A **Claude Code agent architecture template** for indie game development — not a game itself. It provides 48 specialized subagents, 37 slash-command skills, 8 hooks, and 11 path-scoped coding rules that transform a Claude Code session into a structured game studio. Users clone this template, then build their game inside it.

## Technology Stack

- **Engine**: Godot 4.6.1
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Version Control**: Trunk-based development
- **Testing Framework**: GUT (Godot Unit Test)
- **Build System**: SCons (engine), Godot Export Templates

## Key Project Directories

```
.claude/agents/     # 48 agent definitions (markdown + YAML frontmatter)
.claude/skills/     # 37 slash commands (one subdirectory per skill)
.claude/hooks/      # 8 bash hook scripts
.claude/rules/      # 11 path-scoped coding standards
.claude/docs/       # Internal architecture docs (agent map, quick-start, templates)
src/                # Game source (core/, gameplay/, ai/, networking/, ui/, tools/)
design/gdd/         # Game design documents (one file per mechanic)
docs/engine-reference/godot/  # Version-pinned Godot API snapshots
tests/unit/         # GUT unit tests
tests/integration/  # GUT integration tests
prototypes/         # Throwaway prototypes (isolated from src/)
production/         # Sprint plans, milestones, release tracking
```

## Collaboration Protocol (Critical)

This system is **user-driven, not autonomous**. Every agent interaction must follow:

**Question → Options → Decision → Draft → Approval**

- Always ask clarifying questions before proposing solutions
- Present 2–4 options with pros/cons before making changes
- Show drafts/summaries before requesting write approval
- Ask "May I write this to [filepath]?" before using any write/edit tool
- Never commit without explicit user instruction
- Multi-file changes require explicit approval for the full changeset

## GDScript Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables/Functions | snake_case | `move_speed`, `get_health()` |
| Signals | snake_case past tense | `health_changed` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |

## Path-Scoped Coding Rules

These are enforced automatically by `.claude/rules/` when editing files at these paths:

| Path | Key Rules |
|------|-----------|
| `src/gameplay/**` | All values from external config (never hardcoded); always use delta time; no direct UI references; no singletons |
| `src/systems/**` | Zero allocations in hot paths (pre-allocate/pool); systems must never depend on gameplay code; config via `*_config.gd` resources; communicate via signals only |
| `src/ai/**` | Performance budgets required; data-driven parameters; must be debuggable |
| `src/networking/**` | Server-authoritative; versioned messages; security-conscious |
| `src/ui/**` | No game state ownership; localization-ready strings; accessibility required |
| `tests/**` | Naming: `test_[system]_[scenario]_[expected_result]`; strict Arrange/Act/Assert; no external state dependencies |
| `prototypes/**` | Relaxed standards; README required per prototype with hypothesis, status, and findings |
| `design/gdd/**` | Must contain all 8 required sections (Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria) |

## Testing

Run tests via GUT inside Godot. No standalone CLI test runner exists.

- Unit tests live in `tests/unit/`
- Integration tests live in `tests/integration/`
- Test naming: `test_[system]_[scenario]_[expected_result]`
- Every bug fix requires a regression test

## Agent Architecture

Agents are organized into three tiers. Always use the agent at the appropriate tier:

- **Tier 1 — Directors** (`creative-director`, `technical-director`, `producer`): High-level decisions, conflict resolution, cross-department coordination
- **Tier 2 — Department Leads** (`game-designer`, `lead-programmer`, `art-director`, `audio-director`, `narrative-director`, `qa-lead`): Domain ownership
- **Tier 3 — Specialists** (`gameplay-programmer`, `engine-programmer`, `systems-designer`, `level-designer`, `writer`, `qa-tester`, etc.): Hands-on execution

For Godot projects, use: `godot-specialist` → `godot-gdscript-specialist`, `godot-shader-specialist`, `godot-gdextension-specialist`

Domain conflicts escalate to: `creative-director` (design) or `technical-director` (technical). Cross-department changes are coordinated by `producer`.

## Hooks (Auto-Run)

| Hook | Trigger |
|------|---------|
| `validate-commit.sh` | `git commit` — checks hardcoded values, TODO format, JSON validity |
| `validate-push.sh` | `git push` — warns on protected branch pushes |
| `validate-assets.sh` | Writes to `assets/` — validates naming conventions |
| `session-start.sh` | Session open — loads sprint context |
| `detect-gaps.sh` | Session open — suggests `/start` on fresh projects |

Hooks fail gracefully if optional tools (`jq`, Python 3) are missing.

## Common Slash Commands

| Command | Purpose |
|---------|---------|
| `/start` | First-time onboarding — detects project state, guides to right workflow |
| `/setup-engine godot 4.6` | Configure engine (updates `technical-preferences.md`) |
| `/brainstorm` | Guided game concept ideation |
| `/design-system` | Section-by-section GDD authoring |
| `/code-review` | Architecture and quality review |
| `/sprint-plan` | Generate/update sprint plan |
| `/prototype` | Rapid throwaway prototype workflow |
| `/architecture-decision` | Create an ADR in `docs/architecture/` |

## Prototype Lifecycle Rule

Prototype code is **never migrated to production** — it is always rewritten. `prototypes/` is isolated: production code must not reference or import from it. Each prototype needs its own subdirectory with a `README.md` documenting hypothesis, run instructions, status, and findings.

## Engine Reference Docs

Version-pinned Godot API snapshots live in `docs/engine-reference/godot/`. Always consult these before writing engine API code — do not rely on training data for version-specific APIs.

## Design Document Standard

Every mechanic gets its own file in `design/gdd/`. All 8 sections are required; omitting any section is a validation failure on commit. Balance values must link to their source formula.
