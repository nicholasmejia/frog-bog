# Frog Bog

A 2D Godot arcade game where a Frog catches Flies with its tongue from a single lily-pad platform. Falling off the platform is a penalty event.

## Language

**Frog**:
The player-controlled character. Owns motion, charge-jump, tongue firing, and ability components as child nodes.
_Avoid_: Player, avatar.

**Fly**:
The catchable target. Drifts horizontally with a bob. Some are **Special Flies** that grant **Bullet Time Charge** on catch.
_Avoid_: Bug, insect, target. (The spec uses "bug" colloquially; "fly" is canonical because the code uses it everywhere — `fly.gd`, `fly_caught`, `flies` group.)

**Special Fly**:
A gold, sparkly Fly. Catching one grants the Frog a single **Bullet Time Charge**.
_Avoid_: Golden fly, bonus fly.

**Platform**:
The lily pad the Frog jumps from and lands on. Springy via `platform.gd`. Falling off it is a **Fall**.
_Avoid_: Ground, floor (these names appear in scene nodes but the system concept is "Platform").

**Fall**:
The Frog leaving the viewport edge. Emits `frog_fell`, costs 30 points, resets the in-air score multiplier, and (with this feature) resets the **Frog Level** and **Level Progress**.
_Avoid_: Death, miss, fail.

**Bullet Time**:
A time-slowdown ability triggered by `V` while a **Bullet Time Charge** is held. Default duration 3.0s; **Level 3** extends it to 5.0s.
_Avoid_: Slow-mo, time stop.

**Bullet Time Charge**:
The latent one-shot resource granted by catching a **Special Fly**. Consumed on activation. Independent of **Frog Level**.

**Frog Level**:
An integer in `[0, 3]` representing the Frog's current ability tier. Each level grants a stacking set of **Bonuses**. Resets to 0 on **Fall** or `game_started`.

**Level Progress**:
An integer in `[0, FLIES_PER_LEVEL - 1]` (i.e., `[0, 2]`) tracking how many Flies have been eaten toward the next **Frog Level**. Resets to 0 on **Fall**, `game_started`, and every level-up.

**Bonus**:
A stat modifier (multiplier or override) tied to a specific **Frog Level**. Bonuses stack: at L3 the Frog holds L1 + L2 + L3 bonuses simultaneously. Owned by the consuming system (e.g., `frog.gd` owns the L1 charge/jump/velocity bonuses, `tongue.gd` owns the L2 tongue bonuses, `bullet_time.gd` owns the L3 duration bonus).

**Level System**:
The component (new `level_system.gd`, child of Frog) that owns **Frog Level** and **Level Progress** state, listens to `fly_caught` / `frog_fell` / `game_started`, and publishes state + signals on `GameEvents`.

**Ability Component**:
A child node on the Frog that owns one self-contained ability and writes shared state to `GameEvents`. Established by `bullet_time.gd`; **Level System** follows the same pattern.

**GameEvents**:
The autoloaded singleton (`game_events.gd`) that hosts the signal bus and shared read-anywhere state (`time_factor`, `platform_offset`, and now `frog_level` / `level_progress`).

## Relationships

- A **Frog** owns one or more **Ability Components** as child nodes (currently **Bullet Time**, gaining **Level System**).
- A **Frog Level** unlocks a set of **Bonuses**; each **Bonus** is applied by exactly one consumer system.
- A **Fly** caught emits `fly_caught` which **Level System** counts; on the third Fly per level, **Level System** raises **Frog Level**.
- A **Fall** clears **Frog Level** and **Level Progress** (and is otherwise unchanged in its existing score/multiplier effects).
- A **Special Fly** caught grants a **Bullet Time Charge** AND counts as 1 toward **Level Progress**.

## Example dialogue

> **Dev:** "If the **Frog** is at **Level 2** and catches a **Special Fly**, does that count toward **Level Progress**?"
> **Designer:** "Yes — every **Fly** counts as 1, **Special** or not. The **Special Fly** also grants a **Bullet Time Charge**, but the two effects are independent."

> **Dev:** "What happens to an active **Bullet Time** if the **Frog** **Falls** mid-slowdown at **Level 3**?"
> **Designer:** "The **Bullet Time** plays out its full 5 seconds. The **Fall** resets **Frog Level** to 0, but it doesn't truncate an in-flight effect."

## Flagged ambiguities

- "bug" vs "fly" — the spec uses "bug" colloquially; "Fly" is canonical because the code uses it consistently.
- "ground" / "floor" appear as Godot scene node names (`Ground`, `floor` texture path) — the system concept is "Platform" and that is the canonical term.
