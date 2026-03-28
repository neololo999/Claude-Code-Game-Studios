---
paths:
  - "src/systems/**"
---

# Systems Code Rules

- ZERO allocations in hot paths (update loops, physics, rendering) — pre-allocate, pool, reuse
- All public APIs must have doc comments with usage examples
- Systems must NEVER depend on gameplay code (dependency direction: systems ← gameplay)
- Each system must support graceful degradation if dependencies are unavailable
- Profile before AND after every optimization — document measured numbers
- Config values must come from their paired `*_config.gd` resource, never hardcoded
- Systems communicate with gameplay via signals — no direct cross-system node references
- All systems must be independently initializable for testing
