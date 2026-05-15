# Level Up System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Frog Level (0–3) that climbs by 1 every time the Frog eats 3 Flies in a row without Falling, granting stacking ability Bonuses across motion, tongue, and bullet time. Falling resets the level and progress to 0.

**Architecture:** A new `LevelSystem` child node on the Frog (mirroring `bullet_time.gd`) owns level state, listens to `fly_caught` / `frog_fell` / `game_started`, and publishes `GameEvents.frog_level`, `GameEvents.level_progress`, plus `level_changed` / `level_progress_changed` signals. Per-Level Bonuses are owned by their consuming systems (`frog.gd` for L1, `tongue.gd` for L2, `bullet_time.gd` for L3) — each reads `GameEvents.frog_level` and applies its own multipliers off existing base constants. Level-up flourish is a one-shot particle burst owned by `LevelSystem`. HUD shows a level label in `ScoreUI`; future HUD redesigns subscribe to the same signals.

**Tech Stack:** Godot 4.6 (GL Compatibility), GDScript. No test framework — verification is manual in the Godot editor, matching `plans/2026-05-13-codebase-cleanup.md`.

**Supporting docs:**
- `CONTEXT.md` — glossary of game terms (Frog, Fly, Frog Level, Level Progress, Bonus, etc.)
- `docs/adr/0001-level-system.md` — architectural decision + bonus table

---

## File Structure

| File | Responsibility | Touched by Task |
|------|---------------|-----------------|
| `game_events.gd` | Add `MAX_LEVEL`, `FLIES_PER_LEVEL`, `frog_level`, `level_progress`, two new signals | 1 |
| `level_system.gd` | NEW. Owns level state; subscribes to fly/fall/start; publishes to GameEvents; spawns level-up particles | 2, 8 |
| `frog.tscn` | Gains `LevelSystem` child node | 3 |
| `main.tscn` | `ScoreUI` gains a `LevelLabel` inside its VBoxContainer | 4 |
| `score.gd` | Renders `LevelLabel` text based on `level_changed` and `level_progress_changed` | 4 |
| `frog.gd` | Applies L1 charge-rate, max-jump-vy, and horizontal-velocity Bonuses | 5 |
| `tongue.gd` | Applies L2 tongue-speed and tongue-length Bonuses | 6 |
| `bullet_time.gd` | Applies L3 bullet-time DURATION Bonus at activation | 7 |

Each task ends with a manual verification step in the editor + a commit.

---

## Pre-flight

- [ ] **Step 0: Confirm baseline works**

Open the project in Godot 4.6 and press F5. Verify:
- Start screen shows; click Start.
- Frog jumps when you hold then release Space.
- Catch a fly mid-air → score goes up, multiplier appears.
- Catch a gold sparkly (special) fly → frog pulses gold.
- Press V mid-jump while sparkling → world slows ~3s.
- Walk off the platform edge → -30 points, frog respawns at spawn position facing right.
- Timer hits 0 → Game Over → Restart works.

If anything is broken before starting, stop and fix it. Otherwise proceed.

---

## Task 1: Add level state, signals, and constants to `GameEvents`

**Files:**
- Modify: `game_events.gd`

- [ ] **Step 1: Add constants, shared state, and signals to `game_events.gd`**

Open `game_events.gd`. After the existing `SPECIAL_COLOR` constant, add:

```gdscript
const MAX_LEVEL := 3
const FLIES_PER_LEVEL := 3
```

In the "Gameplay events" signal block (after `special_fly_caught`), add two new signals:

```gdscript
signal level_changed(new_level: int)
signal level_progress_changed(progress: int)
```

In the "Shared mutable state" block (after `platform_offset`), add two new fields:

```gdscript
var frog_level: int = 0
var level_progress: int = 0
```

The final file should look like:

```gdscript
extends Node

const SPECIAL_COLOR := Color(1.0, 0.84, 0.2, 1.0)
const MAX_LEVEL := 3
const FLIES_PER_LEVEL := 3

# Gameplay events
signal fly_caught(in_air: bool)
signal frog_landed
signal frog_fell
signal game_started
signal game_ended(final_score: int)
signal special_fly_caught
signal level_changed(new_level: int)
signal level_progress_changed(progress: int)

# Platform impulse events
signal platform_charge
signal platform_jump(dir_x: float)
signal platform_land(dir_x: float)

# Shared mutable state read by frog/fly/shadow each frame
var time_factor: float = 1.0
var platform_offset: Vector2 = Vector2.ZERO
var frog_level: int = 0
var level_progress: int = 0
```

- [ ] **Step 2: Verify the project still parses**

Run the scene in Godot (F5). Expected: project loads with no parse errors; gameplay unchanged (no consumers yet).

- [ ] **Step 3: Commit**

```bash
git add game_events.gd
git commit -m "feat: add level state, signals, and constants to GameEvents"
```

---

## Task 2: Create `LevelSystem` component (no flourish yet)

**Files:**
- Create: `level_system.gd`

- [ ] **Step 1: Create `level_system.gd`**

Create a new file `level_system.gd` with the full content:

```gdscript
extends Node

# Level System component.
# Owns the Frog Level (0..MAX_LEVEL) and Level Progress (0..FLIES_PER_LEVEL-1).
# Subscribes to GameEvents.fly_caught / frog_fell / game_started.
# Publishes GameEvents.frog_level and GameEvents.level_progress as shared state,
# plus level_changed and level_progress_changed signals for UI/feedback consumers.


func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	_reset(true)


func _on_fly_caught(_in_air: bool) -> void:
	if GameEvents.frog_level >= GameEvents.MAX_LEVEL:
		return
	var next_progress: int = GameEvents.level_progress + 1
	if next_progress >= GameEvents.FLIES_PER_LEVEL:
		GameEvents.frog_level += 1
		GameEvents.level_progress = 0
		GameEvents.level_progress_changed.emit(0)
		GameEvents.level_changed.emit(GameEvents.frog_level)
	else:
		GameEvents.level_progress = next_progress
		GameEvents.level_progress_changed.emit(next_progress)


func _on_frog_fell() -> void:
	_reset(false)


func _on_game_started() -> void:
	_reset(false)


func _reset(silent: bool) -> void:
	var level_changed: bool = GameEvents.frog_level != 0
	var progress_changed: bool = GameEvents.level_progress != 0
	GameEvents.frog_level = 0
	GameEvents.level_progress = 0
	if silent:
		return
	if progress_changed:
		GameEvents.level_progress_changed.emit(0)
	if level_changed:
		GameEvents.level_changed.emit(0)
```

Notes for the engineer:
- `_in_air` parameter is unused — the level counter is in_air-agnostic by design (the score multiplier cares about in_air, the level does not).
- L3 caps: when at MAX_LEVEL, additional flies do not increment progress.
- On `_ready` we `_reset(true)` silently so we don't spam signals before any consumer connects. On fall/restart we emit so the HUD updates.

- [ ] **Step 2: Verify the script parses**

Open Godot, save the file, and confirm the editor reports no syntax errors. Press F5 — the component is not yet attached, so gameplay is unchanged.

- [ ] **Step 3: Commit**

```bash
git add level_system.gd
git commit -m "feat: add LevelSystem component (counts flies, manages level transitions)"
```

---

## Task 3: Wire `LevelSystem` into the Frog scene

**Files:**
- Modify: `frog.tscn`

- [ ] **Step 1: Add the script as an `ext_resource` and a `LevelSystem` child node**

`frog.tscn` currently lists `bullet_time.gd` as `id="11_bullet_time"`. Add the level system script the same way.

At the top of `frog.tscn`, after the line:

```
[ext_resource type="Script" path="res://bullet_time.gd" id="11_bullet_time"]
```

add:

```
[ext_resource type="Script" path="res://level_system.gd" id="12_level_system"]
```

At the very bottom of `frog.tscn` (after the `BulletTime` node block), append:

```
[node name="LevelSystem" type="Node" parent="."]
script = ExtResource("12_level_system")
```

The result mirrors the existing `BulletTime` node exactly, one resource ID higher.

- [ ] **Step 2: Verify the component is live**

Open Godot. In the scene tree of `frog.tscn`, confirm a `LevelSystem` node now appears as a sibling of `BulletTime`. Press F5. Gameplay should be unchanged — no consumers yet — but no errors should be reported.

- [ ] **Step 3: Commit**

```bash
git add frog.tscn
git commit -m "feat: attach LevelSystem child node to Frog"
```

---

## Task 4: Add the `LevelLabel` HUD element

**Files:**
- Modify: `main.tscn` (add `LevelLabel` inside `ScoreUI/MarginContainer/VBoxContainer`)
- Modify: `score.gd` (wire signals, render label)

- [ ] **Step 1: Add `LevelLabel` to `main.tscn`**

In `main.tscn`, the `ScoreUI` CanvasLayer contains:

```
ScoreUI/MarginContainer/VBoxContainer
├── ScoreLabel
└── MultiplierLabel
```

Add a third child after `MultiplierLabel`. Insert the following block immediately after the existing `MultiplierLabel` node block (the one starting `[node name="MultiplierLabel" type="Label" parent="ScoreUI/MarginContainer/VBoxContainer" ...]`):

```
[node name="LevelLabel" type="Label" parent="ScoreUI/MarginContainer/VBoxContainer" unique_id=1041260866]
layout_mode = 2
size_flags_horizontal = 8
theme_override_colors/font_color = Color(0.7, 0.95, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 40
text = "Level: 0"
horizontal_alignment = 2
```

The `unique_id` value (`1041260866`) is the next number above the existing `MultiplierLabel` (`1041260865`). The `ExtResource("5_font")` reference points at the Spicy Sale font already loaded earlier in the file — do not add a new ext_resource.

- [ ] **Step 2: Add the `@onready` reference + signal handlers in `score.gd`**

In `score.gd`, add an `@onready` reference for the new label. After the existing `multiplier_label` line:

```gdscript
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel
```

In `_ready`, connect the two new GameEvents signals. After the existing `GameEvents.game_started.connect(_on_game_started)` line, add:

```gdscript
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.level_progress_changed.connect(_on_level_progress_changed)
```

Still in `_ready`, after the `_refresh()` call, add:

```gdscript
	_refresh_level()
```

Now add the two new handlers and the render helper at the bottom of the file:

```gdscript
func _on_level_changed(_new_level: int) -> void:
	_refresh_level()


func _on_level_progress_changed(_progress: int) -> void:
	_refresh_level()


func _refresh_level() -> void:
	var lvl: int = GameEvents.frog_level
	if lvl >= GameEvents.MAX_LEVEL:
		level_label.text = "Level: %d (MAX)" % lvl
	elif lvl == 0:
		level_label.text = "Level: 0"
	else:
		level_label.text = "Level: %d (%d/%d)" % [lvl, GameEvents.level_progress, GameEvents.FLIES_PER_LEVEL]
```

Note: at L0 we intentionally suppress the `(0/3)` to keep the default state clean. Progress is only surfaced mid-climb (L1, L2). This matches the spec format.

- [ ] **Step 3: Verify in editor**

Run the scene (F5). Verify:
- HUD shows `Level: 0` on the right side, smaller than the score (no `(x/3)` at L0).
- Catch one fly: text still reads `Level: 0` (progress is hidden at L0 by design).
- Catch two more flies: text becomes `Level: 1 (0/3)`.
- Catch a fly at L1: text becomes `Level: 1 (1/3)`.
- Catch enough flies to reach L2: text shows `Level: 2 (n/3)`.
- Catch three more flies without falling: text reaches `Level: 3 (MAX)`.
- Catch additional flies while at L3: text remains `Level: 3 (MAX)`.
- Fall off the platform: text resets to `Level: 0`.
- Press Restart from Game Over: text shows `Level: 0`.

If you cannot easily catch 9 flies in one run during testing, that's expected — verify the easy cases (a few catches + a fall) and the L0 → L1 → L2 transitions; trust that the cap is enforced by the explicit `>= MAX_LEVEL` guard in `level_system.gd`.

- [ ] **Step 4: Commit**

```bash
git add main.tscn score.gd
git commit -m "feat: show Level label in HUD"
```

---

## Task 5: Apply L1 Bonuses in `frog.gd`

**Files:**
- Modify: `frog.gd`

At L1+: charge accumulation rate × 1.5, `MAX_JUMP_VY` × 1.10, `MIN_JUMP_VX` and `MAX_JUMP_VX` × 1.15.

- [ ] **Step 1: Add L1 Bonus multiplier constants**

In `frog.gd`, after the existing constant block (after `SHAKE_MAX_FREQ := 55.0`), add:

```gdscript
const L1_CHARGE_SPEED_MULT := 1.5
const L1_MAX_JUMP_VY_MULT := 1.10
const L1_JUMP_VX_MULT := 1.15
```

- [ ] **Step 2: Apply the charge-rate Bonus**

In `_physics_process`, locate the existing charge-time accumulator:

```gdscript
		if charging:
			charge_time = min(charge_time + delta, MAX_CHARGE)
			_update_shake(delta)
```

Replace it with:

```gdscript
		if charging:
			var charge_mult: float = L1_CHARGE_SPEED_MULT if GameEvents.frog_level >= 1 else 1.0
			charge_time = min(charge_time + delta * charge_mult, MAX_CHARGE)
			_update_shake(delta)
```

- [ ] **Step 3: Apply the jump-vy and velocity Bonuses in `_launch`**

Locate `_launch()`. The current body computes `vy` and `vx` via `lerpf`:

```gdscript
	var vy: float = lerpf(MIN_JUMP_VY, MAX_JUMP_VY, ratio)
	var vx: float = lerpf(MIN_JUMP_VX, MAX_JUMP_VX, ratio)
```

Replace those two lines with:

```gdscript
	var max_jump_vy_mult: float = L1_MAX_JUMP_VY_MULT if GameEvents.frog_level >= 1 else 1.0
	var jump_vx_mult: float = L1_JUMP_VX_MULT if GameEvents.frog_level >= 1 else 1.0
	var effective_max_jump_vy: float = MAX_JUMP_VY * max_jump_vy_mult
	var vy: float = lerpf(MIN_JUMP_VY, effective_max_jump_vy, ratio)
	var vx: float = lerpf(MIN_JUMP_VX * jump_vx_mult, MAX_JUMP_VX * jump_vx_mult, ratio)
```

Note: `MAX_JUMP_VY` is negative (it's an upward velocity). Multiplying a negative by 1.10 makes it more negative (faster upward) — exactly what we want.

- [ ] **Step 4: Verify in editor**

Run F5. Manual test:
- At L0, jump charging feels exactly as before (the multiplier resolves to 1.0). Tap-jump distance and full-charge max height feel identical.
- Catch 3 flies in a row (e.g., a few mid-air catches) to reach L1.
- Charge a full-power jump immediately after hitting L1: it should feel snappier (≈0.8s to fully charge vs 1.2s) and the frog should travel noticeably farther and slightly higher.
- Fall off → text resets to L0 → jump again: should feel slow/short again (back to base).

If the difference between L0 and L1 is not perceptible, double-check `GameEvents.frog_level` is being read after assignment by adding a temporary `print(GameEvents.frog_level)` in `_launch`. Remove the print before committing.

- [ ] **Step 5: Commit**

```bash
git add frog.gd
git commit -m "feat: apply L1 charge, max-jump, and velocity Bonuses to Frog"
```

---

## Task 6: Apply L2 Bonuses in `tongue.gd`

**Files:**
- Modify: `tongue.gd`

At L2+: `EXTEND_SPEED` × 1.20, `RETRACT_SPEED` × 1.20, `MAX_LENGTH` × 1.15.

- [ ] **Step 1: Add L2 Bonus multiplier constants**

In `tongue.gd`, after the existing constants:

```gdscript
const MAX_LENGTH := 320.0
const EXTEND_SPEED := 1800.0
const RETRACT_SPEED := 2400.0
```

add:

```gdscript
const L2_TONGUE_SPEED_MULT := 1.20
const L2_TONGUE_LENGTH_MULT := 1.15
```

- [ ] **Step 2: Add helpers for effective values**

Below the existing variable declarations (after `var is_retracting := false`), add:

```gdscript
func _is_l2_active() -> bool:
	return GameEvents.frog_level >= 2


func _effective_max_length() -> float:
	return MAX_LENGTH * L2_TONGUE_LENGTH_MULT if _is_l2_active() else MAX_LENGTH


func _effective_speed_mult() -> float:
	return L2_TONGUE_SPEED_MULT if _is_l2_active() else 1.0
```

- [ ] **Step 3: Use the effective values in `_process`**

Locate the firing branch in `_process`:

```gdscript
	if is_firing:
		current_length += EXTEND_SPEED * delta
		if current_length >= MAX_LENGTH:
			current_length = MAX_LENGTH
			is_firing = false
			is_retracting = true
		_update_tongue()
	elif is_retracting:
		current_length -= RETRACT_SPEED * delta
		if current_length <= 0.0:
```

Replace it with:

```gdscript
	if is_firing:
		var max_len: float = _effective_max_length()
		current_length += EXTEND_SPEED * _effective_speed_mult() * delta
		if current_length >= max_len:
			current_length = max_len
			is_firing = false
			is_retracting = true
		_update_tongue()
	elif is_retracting:
		current_length -= RETRACT_SPEED * _effective_speed_mult() * delta
		if current_length <= 0.0:
```

Note: we read the effective max length once per frame at the top of the firing branch so a level-up mid-extend can still extend further on subsequent frames (does not retroactively shorten).

- [ ] **Step 4: Verify in editor**

Run F5. Manual test:
- At L0/L1, tongue feels exactly as before — same length and speed.
- Climb to L2 (eat 6 flies in a row): the tongue should now reach noticeably farther and shoot/retract faster.
- Fire from a stationary position next to the edge of the platform — at L2 the tongue tip should now extend visibly farther across the screen vs the L0/L1 distance.
- Fall off → back to L0 → tongue reach back to baseline.

- [ ] **Step 5: Commit**

```bash
git add tongue.gd
git commit -m "feat: apply L2 tongue speed and length Bonuses"
```

---

## Task 7: Apply L3 Bonus in `bullet_time.gd`

**Files:**
- Modify: `bullet_time.gd`

At L3: bullet time `DURATION` resolved at activation = 5.0 instead of 3.0.

- [ ] **Step 1: Add L3 Bonus constant**

In `bullet_time.gd`, after the existing `DURATION := 3.0` constant, add:

```gdscript
const L3_DURATION := 5.0
```

- [ ] **Step 2: Add an `_effective_duration` helper**

After the existing variable declarations (after `var pulse_phase: float = 0.0`), add:

```gdscript
func _effective_duration() -> float:
	return L3_DURATION if GameEvents.frog_level >= GameEvents.MAX_LEVEL else DURATION
```

- [ ] **Step 3: Use effective duration on activation**

Locate `_activate`:

```gdscript
func _activate() -> void:
	has_charge = false
	remaining = DURATION
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)
```

Change `remaining = DURATION` to `remaining = _effective_duration()`:

```gdscript
func _activate() -> void:
	has_charge = false
	remaining = _effective_duration()
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)
```

The duration is read at activation, so an already-active bullet time runs its full course even if the Frog Falls and level resets mid-slowdown (matches confirmed spec).

- [ ] **Step 4: Verify in editor**

Run F5. Manual test:
- Without reaching L3, catch a special fly, jump, press V — slow lasts ~3s as before.
- Climb to L3 (eat 9 flies in a row), then catch a special fly, jump, press V — slow should now last ~5s. Use the game's timer (HUD top center) as a rough reference: count the seconds the world is visibly slowed.
- Test the fall-mid-slowdown edge case: reach L3, catch a special, activate bullet time mid-jump, then deliberately walk off the platform during the slowdown. Verify the slowdown plays through its remaining time even though the Level label drops to `Level: 0 (0/3)`.

- [ ] **Step 5: Commit**

```bash
git add bullet_time.gd
git commit -m "feat: apply L3 bullet time DURATION Bonus (3s -> 5s at L3)"
```

---

## Task 8: Add level-up particle flourish to `LevelSystem`

**Files:**
- Modify: `level_system.gd`

A one-shot CPUParticles2D burst from the Frog when level increases. No sprite modulate change (avoids conflict with `bullet_time.gd::_update_visual`).

- [ ] **Step 1: Wire up sparkles in `level_system.gd`**

Open `level_system.gd`. At the top of the file (after `extends Node`), add a constant:

```gdscript
const LEVEL_UP_COLOR := Color(0.55, 0.95, 1.0, 1.0)
```

After the comment block at the top, add a field:

```gdscript
var sparkles: CPUParticles2D
```

Modify `_ready` so it sets up the particles after connecting to signals:

```gdscript
func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	_setup_sparkles()
	_reset(true)
```

Add a `_setup_sparkles` helper (mirrors `bullet_time.gd::_setup_sparkles`, but one-shot):

```gdscript
func _setup_sparkles() -> void:
	sparkles = CPUParticles2D.new()
	sparkles.amount = 30
	sparkles.lifetime = 0.8
	sparkles.one_shot = true
	sparkles.explosiveness = 0.9
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 60.0
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 60.0
	sparkles.initial_velocity_max = 160.0
	sparkles.scale_amount_min = 3.0
	sparkles.scale_amount_max = 6.0
	sparkles.color = LEVEL_UP_COLOR
	sparkles.emitting = false
	sparkles.z_index = 1
	get_parent().add_child(sparkles)
```

Now modify `_on_fly_caught` to fire the burst on level-up. The current method:

```gdscript
func _on_fly_caught(_in_air: bool) -> void:
	if GameEvents.frog_level >= GameEvents.MAX_LEVEL:
		return
	var next_progress: int = GameEvents.level_progress + 1
	if next_progress >= GameEvents.FLIES_PER_LEVEL:
		GameEvents.frog_level += 1
		GameEvents.level_progress = 0
		GameEvents.level_progress_changed.emit(0)
		GameEvents.level_changed.emit(GameEvents.frog_level)
	else:
		GameEvents.level_progress = next_progress
		GameEvents.level_progress_changed.emit(next_progress)
```

Add the burst call after the `GameEvents.level_changed.emit(...)` line so the burst follows the state update:

```gdscript
func _on_fly_caught(_in_air: bool) -> void:
	if GameEvents.frog_level >= GameEvents.MAX_LEVEL:
		return
	var next_progress: int = GameEvents.level_progress + 1
	if next_progress >= GameEvents.FLIES_PER_LEVEL:
		GameEvents.frog_level += 1
		GameEvents.level_progress = 0
		GameEvents.level_progress_changed.emit(0)
		GameEvents.level_changed.emit(GameEvents.frog_level)
		_emit_level_up_burst()
	else:
		GameEvents.level_progress = next_progress
		GameEvents.level_progress_changed.emit(next_progress)
```

Then add the helper at the bottom of the file:

```gdscript
func _emit_level_up_burst() -> void:
	if sparkles == null:
		return
	sparkles.global_position = get_parent().global_position
	sparkles.restart()
	sparkles.emitting = true
```

Note: the sparkles node is parented to the Frog (`get_parent().add_child(sparkles)`), so its position would follow the Frog naturally — but we set `global_position` explicitly on each burst so the particles are anchored at the Frog's current position when the burst starts (they shouldn't trail the Frog mid-flight).

- [ ] **Step 2: Verify in editor**

Run F5. Manual test:
- Eat 3 flies → see a cyan-white particle burst at the Frog. Level label flips to `Level: 1 (0/3)`.
- Eat 3 more → another burst on L1 → L2 transition.
- Eat 3 more → another burst on L2 → L3 transition.
- Eat additional flies at L3 → no burst (already at MAX_LEVEL, no transition).
- Falling does not emit the burst.
- Game restart does not emit the burst.
- Catching a special fly while the bullet-time gold pulse is active should still allow the level-up burst to play (the two effects are independent — particles vs sprite modulate).

- [ ] **Step 3: Commit**

```bash
git add level_system.gd
git commit -m "feat: emit cyan particle burst on Frog level-up"
```

---

## Task 9: End-to-end verification + bonus-table sanity check

**Files:** None (manual verification only).

- [ ] **Step 1: Full playthrough**

Run F5. Walk through the complete progression in one play session:

1. Start screen → click Start. HUD shows `Level: 0`.
2. Catch a fly. HUD still: `Level: 0` (no progress shown at L0). No burst.
3. Catch 2 more. HUD: `Level: 1 (0/3)`. Burst fires.
4. Immediately jump with full charge — should feel faster to charge AND travel farther / a bit higher than the very first jump did.
5. Catch 3 more flies (without falling). HUD: `Level: 2 (0/3)`. Burst fires.
6. Fire the tongue — it should visibly extend farther and faster than at L1.
7. Catch 3 more flies (without falling) — try to grab a special fly as one of them. HUD: `Level: 3 (MAX)`. Burst fires.
8. With a bullet-time charge in hand at L3, jump and press V — slowdown should last ~5s.
9. Walk off the edge. HUD resets to `Level: 0`. Frog respawns. -30 score.
10. Confirm the next jump feels like the base game (no L1 bonuses applied).

- [ ] **Step 2: Cross-reference the bonus table in `docs/adr/0001-level-system.md`**

Open `docs/adr/0001-level-system.md` and scan its bonus table. For each row, confirm:
- The owner file is the one you actually modified in this plan.
- The constant names in the file match the table (`L1_CHARGE_SPEED_MULT`, `L1_MAX_JUMP_VY_MULT`, `L1_JUMP_VX_MULT`, `L2_TONGUE_SPEED_MULT`, `L2_TONGUE_LENGTH_MULT`, `L3_DURATION`).

If any drift exists, update the ADR — it is the canonical bonus reference.

- [ ] **Step 3: Final commit (only if anything was touched)**

If you updated the ADR or fixed any small drift in step 2:

```bash
git add docs/adr/0001-level-system.md
git commit -m "docs: align Level System ADR bonus table with implementation"
```

Otherwise no commit needed — the feature is complete.

---

## Self-review summary

- **Spec coverage:** every Bonus in the spec (charge 1.5x, max jump +10%, velocity +15%, tongue 1.2x speed & 1.15x length, bullet time +2s) maps to a task (5, 6, 7). Fall reset to L0 is handled in Task 2 (`_on_frog_fell`). L0–L3 cap is handled in Task 2 (`>= MAX_LEVEL` guard). Game-restart reset is handled in Task 2 (`_on_game_started`).
- **Placeholders:** none — every step contains the actual code, exact file path, and an exact verification.
- **Type consistency:** `MAX_LEVEL` / `FLIES_PER_LEVEL` / `frog_level` / `level_progress` / `level_changed` / `level_progress_changed` are defined once on `GameEvents` (Task 1) and used consistently in `level_system.gd` (Task 2), `score.gd` (Task 4), `frog.gd` (Task 5), `tongue.gd` (Task 6), and `bullet_time.gd` (Task 7). Per-level multiplier constants (`L1_*`, `L2_*`, `L3_DURATION`) live with their consumers and are named consistently with the ADR table.
