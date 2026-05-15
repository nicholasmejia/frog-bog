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

**Title Screen**:
The pre-game branded splash showing the FROGBOG 99 logo, the "Take No Prisoners!" subheading, and a "Press SPACE to play" prompt. Plays once per launch — **Restart** from **Game Over** skips it.
_Avoid_: Start Screen, Main Menu, Splash Screen.

**Title Sequence**:
The animated reveal portion of the **Title Screen**: a wireframe cascade across the FROGBOG 99 letters with a rainbow hue cycle, a full-screen white flash that reveals the solid logo, the **Subheading Crash** of TAKE / NO / PRISONERS!, and a left-to-right **Letter Ripple** across FROGBOG 99. Followed by the **Attract State**.
_Avoid_: Intro animation, opening cinematic.

**Attract State**:
The steady-state portion of the **Title Screen** after the **Title Sequence** completes. The final composition matches `art/title_card.png` and the "Press SPACE to play" prompt blinks until the player presses SPACE.

**Subheading Crash**:
The mid-**Title Sequence** beat where TAKE flies in from the left and PRISONERS! flies in from the right, collide at center, trigger a quick screen flash that reveals NO between them, then bounce slightly outward and settle back to their final positions.

**Letter Ripple**:
The end-of-**Title Sequence** beat where each of the 9 glyphs in FROGBOG 99 bounces upward by a small visual offset in left-to-right order, creating a wave. The bounce is render-only and does not change layout.

**Pre-Game Fade**:
A black fade-out / fade-in transition that bridges the **Title Screen** (or a **Restart**) into the **Game Start Countdown**.

**Game Start Countdown**:
A "3 → 2 → 1 → Start!" sequence that plays over the live game scene before gameplay begins. The **Frog** is frozen in place; **Flies** begin spawning during the countdown so the player anticipates immediate action; the game timer is held at its starting value. "Start!" gradually fades out as the countdown ends.

**Game Start**:
The moment gameplay begins — `GameEvents.game_started` emits, the **Frog** accepts input, and the game timer begins counting down. Triggered by the end of the **Game Start Countdown**.

**Restart**:
Initiating a new game from the **Game Over** surface. Skips the **Title Screen**, runs the **Pre-Game Fade**, then the **Game Start Countdown**, then **Game Start**.
_Avoid_: New Game, Replay.

## Relationships

- A **Frog** owns one or more **Ability Components** as child nodes (currently **Bullet Time**, gaining **Level System**).
- A **Frog Level** unlocks a set of **Bonuses**; each **Bonus** is applied by exactly one consumer system.
- A **Fly** caught emits `fly_caught` which **Level System** counts; on the third Fly per level, **Level System** raises **Frog Level**.
- A **Fall** clears **Frog Level** and **Level Progress** (and is otherwise unchanged in its existing score/multiplier effects).
- A **Special Fly** caught grants a **Bullet Time Charge** AND counts as 1 toward **Level Progress**.
- The **Title Screen** plays its **Title Sequence** then settles into its **Attract State**; pressing SPACE there triggers the **Pre-Game Fade**, then the **Game Start Countdown**, then **Game Start**.
- A **Restart** from **Game Over** runs the **Pre-Game Fade** and **Game Start Countdown** but skips the **Title Screen**.
- During the **Game Start Countdown**, **Flies** spawn but the **Frog** is frozen and ignores input; `GameEvents.game_started` does NOT fire until the countdown completes.

## Example dialogue

> **Dev:** "If the **Frog** is at **Level 2** and catches a **Special Fly**, does that count toward **Level Progress**?"
> **Designer:** "Yes — every **Fly** counts as 1, **Special** or not. The **Special Fly** also grants a **Bullet Time Charge**, but the two effects are independent."

> **Dev:** "What happens to an active **Bullet Time** if the **Frog** **Falls** mid-slowdown at **Level 3**?"
> **Designer:** "The **Bullet Time** plays out its full 5 seconds. The **Fall** resets **Frog Level** to 0, but it doesn't truncate an in-flight effect."

## Flagged ambiguities

- "bug" vs "fly" — the spec uses "bug" colloquially; "Fly" is canonical because the code uses it consistently.
- "ground" / "floor" appear as Godot scene node names (`Ground`, `floor` texture path) — the system concept is "Platform" and that is the canonical term.
