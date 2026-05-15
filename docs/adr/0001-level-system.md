# Level System as ability component, with per-consumer bonuses

The Frog now has a Frog Level in `[0, 3]` that grows by eating 3 Flies per level (resets on Fall or game start). Each level grants stacking Bonuses across multiple subsystems (Frog motion, tongue, bullet time).

We implement this as a new `LevelSystem` child node on the Frog (mirroring `bullet_time.gd`), which owns the level/progress state, subscribes to `fly_caught` / `frog_fell` / `game_started`, and publishes `GameEvents.frog_level` (shared int, same pattern as `time_factor`) plus `GameEvents.level_changed(new_level)` and `GameEvents.level_progress_changed(progress)` signals.

Bonuses themselves are **owned by their consuming systems**, not centralized:

| Level | Bonus | Owner | Mechanism |
|---|---|---|---|
| 1 | Charge accumulation rate × 1.5 | `frog.gd` | `charge_time += delta * mult` |
| 1 | `MAX_JUMP_VY` × 1.10 (velocity, not physics-strict height) | `frog.gd` | Apply at launch |
| 1 | `MIN_JUMP_VX` and `MAX_JUMP_VX` × 1.15 | `frog.gd` | Apply at launch |
| 2 | `EXTEND_SPEED` and `RETRACT_SPEED` × 1.20 | `tongue.gd` | Apply per-frame in `_process` |
| 2 | `MAX_LENGTH` × 1.15 | `tongue.gd` | Apply per-frame in `_process` |
| 3 | Bullet Time `DURATION` 3.0 → 5.0 (resolved at activation) | `bullet_time.gd` | `remaining = _effective_duration()` |

## Considered Options

- **Centralized bonus table on `LevelSystem`** — rejected. The codebase pattern is that each ability/system owns its own tuning constants (e.g., `bullet_time.gd::DURATION`, `tongue.gd::MAX_LENGTH`). A central table would split tuning across two files for each consumer and break that precedent.
- **State on `GameEvents` directly without a `LevelSystem` node** — rejected. The level needs side effects (signals, particle flourish, level-up tint flash on the Frog sprite), which fit a component, not a passive data field.
- **State on `score.gd`** — rejected. Score and Level have different lifetimes and consumers; co-locating them couples unrelated UI to a gameplay system.

## Consequences

- Future ability levels or new bonus types are added by editing the consumer system that owns the relevant constant, plus updating this ADR's table. `LevelSystem` itself doesn't change.
- The "what does each level grant" question is answered by this ADR rather than by grepping. Keep this table current as bonuses are added/tuned.
- A future HUD redesign can replace the level label by subscribing to the same `GameEvents` signals/state — no changes to `LevelSystem` required.
