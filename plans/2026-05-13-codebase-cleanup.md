# Codebase Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce `frog.gd` from ~370 lines to ~180 by extracting the shadow logic into `shadow.gd` and bullet-time into its own component, plus remove duplicated constants and dead code. No behavior changes.

**Architecture:** Move single-responsibility chunks out of the bloated `frog.gd` into the child nodes that own them. Shadow becomes self-driving from `shadow.gd` reading frog state via `get_parent()`. Bullet-time becomes a `BulletTime` child node on the Frog that owns its own state, sparkles, input handling, and time-factor lerping. Shared visual constants (gold color) move to `game_events.gd`. No git repo is initialized for this project, so verification is by running the scene in the Godot editor after each task.

**Tech Stack:** Godot 4.6, GDScript, no test framework (verification is manual in the editor).

---

## File Structure

| File | Responsibility | Touched by Task |
|------|---------------|-----------------|
| `frog.gd` | Frog input, motion, animation, dust, jump-cycle tracking | 1, 2, 3, 4 |
| `frog.tscn` | Frog scene; gains `BulletTime` child node | 4 |
| `shadow.gd` | Drop-shadow drawing **and** size/alpha/position calc | 3 |
| `bullet_time.gd` | NEW. Charge state + 3s lerped time-factor + gold pulse + sparkles + input | 4 |
| `fly.gd` | Fly motion + special pulse; references `GameEvents.SPECIAL_COLOR` | 2 |
| `game_events.gd` | Autoload bus; gains `SPECIAL_COLOR` constant | 2 |
| `main.gd` | Game state machine | 1 |
| `score.gd` | Score UI | 1 |

---

## Pre-flight

- [ ] **Step 0: Confirm baseline works**

Open Godot, run the scene (F5), and confirm:
- Start screen shows, click Start
- Frog faces right at spawn
- Jump, catch a fly mid-air → score goes up + multiplier appears
- Catch a special (gold sparkly) fly → frog sparkles gold
- Press V mid-jump while sparkling → world slows for 3s
- Fall off ledge → -30 points, frog respawns facing right
- Timer hits 0 → Game Over with Restart
- Restart → frog faces right, all state reset

If anything is broken before starting, fix it first. Otherwise proceed.

---

## Task 1: Delete dead code

**Files:**
- Modify: `score.gd` (remove unused handler)
- Modify: `main.gd` (remove unused `@onready`)
- Modify: `shadow.gd` (remove unused exports)

- [ ] **Step 1: Remove the stub `_on_game_ended` from `score.gd`**

Edit `score.gd`. Remove these lines:

```gdscript
func _on_game_ended(_final_score: int) -> void:
	pass
```

And remove the connection line in `_ready()`:

```gdscript
	GameEvents.game_ended.connect(_on_game_ended)
```

- [ ] **Step 2: Remove unused `fly_spawner` reference in `main.gd`**

Edit `main.gd`. Delete:

```gdscript
@onready var fly_spawner: Node2D = $FlySpawner
```

- [ ] **Step 3: Remove unused exports from `shadow.gd`**

Edit `shadow.gd`. Remove these lines (they're never set externally and would be replaced when shadow logic moves in Task 3):

```gdscript
@export var radius_x: float = 60.0
@export var radius_y: float = 14.0
@export var color: Color = Color(0, 0, 0, 1)
```

Replace their usage in `_draw()` to use local constants for now (Task 3 will rework this entirely):

```gdscript
func _draw() -> void:
	const RADIUS_X := 60.0
	const RADIUS_Y := 14.0
	var pts := PackedVector2Array()
	const SEGMENTS := 32
	for i in SEGMENTS:
		var a: float = TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(a) * RADIUS_X, sin(a) * RADIUS_Y))
	draw_colored_polygon(pts, Color(0, 0, 0, 1))
```

- [ ] **Step 4: Verify in editor**

Run the scene (F5). Confirm:
- Score still updates
- Shadow still renders under frog

No regressions expected — this is dead code removal.

---

## Task 2: Centralize `SPECIAL_COLOR`

**Files:**
- Modify: `game_events.gd` (add constant)
- Modify: `frog.gd` (use `GameEvents.SPECIAL_COLOR`)
- Modify: `fly.gd` (use `GameEvents.SPECIAL_COLOR`)

- [ ] **Step 1: Add the constant to `game_events.gd`**

Edit `game_events.gd`. Add this near the top (under `extends Node`):

```gdscript
const SPECIAL_COLOR := Color(1.0, 0.84, 0.2, 1.0)
```

- [ ] **Step 2: Remove the duplicate from `frog.gd`**

Edit `frog.gd`. Delete this line:

```gdscript
const SPECIAL_COLOR := Color(1.0, 0.84, 0.2, 1.0)
```

Then find all uses of `SPECIAL_COLOR` in `frog.gd` and replace with `GameEvents.SPECIAL_COLOR`. There are three: inside `_setup_frog_sparkles`, inside `_update_charge_visual`, and the original const declaration.

- [ ] **Step 3: Remove the duplicate from `fly.gd`**

Edit `fly.gd`. Delete:

```gdscript
const SPECIAL_COLOR := Color(1.0, 0.84, 0.2, 1.0)
```

Then replace all uses of `SPECIAL_COLOR` with `GameEvents.SPECIAL_COLOR`. There are two: inside `_setup_special_visuals` and inside the special-pulse modulate calculation in `_process`.

- [ ] **Step 4: Verify in editor**

Run the scene. Eat a special fly. Confirm:
- Frog still sparkles gold
- Special fly still pulses gold

---

## Task 3: Move shadow logic into `shadow.gd`

**Files:**
- Modify: `shadow.gd` (gain all shadow calc)
- Modify: `frog.gd` (lose `_update_shadow`, related constants/vars, `ground_y`, and the call site)

This task removes ~25 lines from `frog.gd` and the misleadingly-named `ground_y` export. The shadow becomes self-driving and reads frog state from `get_parent()`. The "feet offset" magic 95.0 becomes a derivation from the actual frog `CollisionShape2D`.

- [ ] **Step 1: Rewrite `shadow.gd` to own the calc**

Replace the entire contents of `shadow.gd` with:

```gdscript
extends Node2D

const MAX_HEIGHT := 200.0
const MIN_SCALE := 1.0
const MAX_SCALE := 1.8
const MAX_ALPHA := 0.55
const MIN_ALPHA := 0.15
const LERP_RATE := 16.0
const RADIUS_X := 60.0
const RADIUS_Y := 14.0
const SEGMENTS := 32

@export var anchor_y: float = 790.0

@onready var frog: CharacterBody2D = get_parent()
@onready var frog_collision: CollisionShape2D = frog.get_node("CollisionShape2D")

var scale_t: float = 0.0
var alpha_t: float = 0.0


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var a: float = TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(a) * RADIUS_X, sin(a) * RADIUS_Y))
	draw_colored_polygon(pts, Color(0, 0, 0, 1))


func _physics_process(delta: float) -> void:
	var feet_offset: float = frog_collision.position.y + (frog_collision.shape as RectangleShape2D).size.y * 0.5
	var feet_y: float = frog.global_position.y + feet_offset
	var height: float = maxf(0.0, anchor_y - feet_y)
	var height_t: float = clampf(height / MAX_HEIGHT, 0.0, 1.0)
	var in_air: bool = not frog.is_on_floor()
	var target_scale_t: float = 1.0 if frog.charging else height_t
	var target_alpha_t: float = height_t if in_air else 0.0
	var k: float = clampf(LERP_RATE * delta, 0.0, 1.0)
	scale_t = lerpf(scale_t, target_scale_t, k)
	alpha_t = lerpf(alpha_t, target_alpha_t, k)
	var s: float = lerpf(MIN_SCALE, MAX_SCALE, scale_t)
	var a: float = lerpf(MAX_ALPHA, MIN_ALPHA, alpha_t)
	global_position = Vector2(frog.global_position.x, anchor_y + GameEvents.platform_offset.y)
	scale = Vector2(s, s)
	modulate.a = a
```

- [ ] **Step 2: Remove shadow logic from `frog.gd`**

Edit `frog.gd`:

a. Delete the `ground_y` export:

```gdscript
@export var ground_y: float = 790.0
```

b. Delete the shadow constants:

```gdscript
const SHADOW_MAX_HEIGHT := 200.0
const SHADOW_MIN_SCALE := 1.0
const SHADOW_MAX_SCALE := 1.8
const SHADOW_MAX_ALPHA := 0.55
const SHADOW_MIN_ALPHA := 0.15
const SHADOW_LERP_RATE := 16.0
```

c. Delete the shadow state vars:

```gdscript
var shadow_t: float = 0.0
var shadow_alpha_t: float = 0.0
```

d. Delete the `shadow` `@onready` reference:

```gdscript
@onready var shadow: Node2D = $Shadow
```

e. Delete the entire `_update_shadow` function (lines from `func _update_shadow(delta: float) -> void:` through its end).

f. In `_physics_process`, delete the call site:

```gdscript
	_update_shadow(delta)
```

- [ ] **Step 3: Update dust functions in `frog.gd` to use the shadow's anchor**

The dust still references `ground_y`. Since `ground_y` is gone, replace with a local reference to the shadow's anchor. Add an `@onready` for the shadow back (it's needed for dust positioning only):

```gdscript
@onready var shadow: Node2D = $Shadow
```

Then edit `_emit_dust`:

```gdscript
func _emit_dust() -> void:
	dust.global_position = Vector2(global_position.x, shadow.anchor_y + GameEvents.platform_offset.y)
	dust.restart()
	dust.emitting = true
```

And `_emit_landing_dust`:

```gdscript
func _emit_landing_dust() -> void:
	var py: float = shadow.anchor_y + GameEvents.platform_offset.y
	land_dust_left.global_position = Vector2(global_position.x - LAND_DUST_HAND_OFFSET, py)
	land_dust_right.global_position = Vector2(global_position.x + LAND_DUST_HAND_OFFSET, py)
	land_dust_left.restart()
	land_dust_right.restart()
	land_dust_left.emitting = true
	land_dust_right.emitting = true
```

- [ ] **Step 4: Verify in editor**

Run the scene. Confirm:
- Shadow renders under frog when grounded (full alpha, normal size)
- Charging the jump → shadow grows (smoothly)
- Jumping → shadow fades with altitude during ascent
- Descending → shadow alpha tracks height back to full
- Landing dust + takeoff dust still puffs at the visible pad surface, not floating above
- Falling off ledge + respawn → shadow snaps back correctly

---

## Task 4: Extract `BulletTime` component

**Files:**
- Create: `bullet_time.gd`
- Modify: `frog.tscn` (add `BulletTime` child node)
- Modify: `frog.gd` (remove all bullet-time concerns)

This removes ~80 lines from `frog.gd`. The component listens to `GameEvents.special_fly_caught` (which `frog.gd` already emits), owns its sparkles, and reaches the frog's sprite via `get_parent()` for the gold pulse modulation.

- [ ] **Step 1: Create `bullet_time.gd`**

Create the file `bullet_time.gd` with this content:

```gdscript
extends Node

const DURATION := 3.0
const TARGET_FACTOR := 0.12
const LERP_RATE := 14.0
const PULSE_SPEED := 7.0

@onready var sprite: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")
var sparkles: CPUParticles2D

var has_charge: bool = false
var remaining: float = 0.0
var pulse_phase: float = 0.0


func _ready() -> void:
	_setup_sparkles()
	GameEvents.special_fly_caught.connect(_on_special_fly_caught)
	GameEvents.game_started.connect(_on_game_started)


func _setup_sparkles() -> void:
	sparkles = CPUParticles2D.new()
	sparkles.amount = 22
	sparkles.lifetime = 0.75
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 70.0
	sparkles.direction = Vector2.ZERO
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 20.0
	sparkles.initial_velocity_max = 60.0
	sparkles.scale_amount_min = 3.0
	sparkles.scale_amount_max = 6.0
	sparkles.color = GameEvents.SPECIAL_COLOR
	sparkles.emitting = false
	sparkles.z_index = 1
	get_parent().add_child(sparkles)


func _physics_process(delta: float) -> void:
	_update_time(delta)
	_update_visual(delta)
	if Input.is_action_just_pressed("bullet_time") and has_charge and remaining <= 0.0:
		_activate()


func _update_time(delta: float) -> void:
	if remaining > 0.0:
		remaining -= delta
		if remaining <= 0.0:
			remaining = 0.0
			GameEvents.bullet_time_active_changed.emit(false)
	var target: float = TARGET_FACTOR if remaining > 0.0 else 1.0
	var t: float = clampf(LERP_RATE * delta, 0.0, 1.0)
	GameEvents.time_factor = lerpf(GameEvents.time_factor, target, t)


func _update_visual(delta: float) -> void:
	if has_charge:
		pulse_phase += delta * PULSE_SPEED
		var pulse: float = (sin(pulse_phase) + 1.0) * 0.5
		sprite.modulate = Color(1, 1, 1).lerp(GameEvents.SPECIAL_COLOR, pulse * 0.75)
	elif sprite.modulate != Color(1, 1, 1, 1):
		sprite.modulate = Color(1, 1, 1, 1)


func _activate() -> void:
	has_charge = false
	remaining = DURATION
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)
	GameEvents.bullet_time_charge_changed.emit(false)
	GameEvents.bullet_time_active_changed.emit(true)


func _on_special_fly_caught() -> void:
	if has_charge:
		return
	has_charge = true
	sparkles.emitting = true
	GameEvents.bullet_time_charge_changed.emit(true)


func _on_game_started() -> void:
	has_charge = false
	remaining = 0.0
	pulse_phase = 0.0
	GameEvents.time_factor = 1.0
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)
	GameEvents.bullet_time_charge_changed.emit(false)
	GameEvents.bullet_time_active_changed.emit(false)
```

Note: sparkles are added as a child of the **frog** (`get_parent().add_child(sparkles)`) so they sit at the frog's transform, matching current behavior.

- [ ] **Step 2: Add `BulletTime` node to `frog.tscn`**

Edit `frog.tscn`. Add a new `ext_resource` for the script. Find the existing `[ext_resource]` block and add a line for `bullet_time.gd`:

```
[ext_resource type="Script" path="res://bullet_time.gd" id="11_bullet_time"]
```

Then append a new node block at the bottom of the file (under the existing `LandDustRight` block):

```
[node name="BulletTime" type="Node" parent="."]
script = ExtResource("11_bullet_time")
```

- [ ] **Step 3: Remove bullet-time concerns from `frog.gd`**

Edit `frog.gd`:

a. Delete the bullet-time constants:

```gdscript
const BULLET_TIME_DURATION := 3.0
const BULLET_TIME_FACTOR := 0.12
const BULLET_TIME_LERP_RATE := 14.0
const CHARGE_PULSE_SPEED := 7.0
```

b. Delete the bullet-time vars:

```gdscript
var has_bullet_time_charge := false
var bullet_time_remaining := 0.0
var charge_pulse_phase := 0.0
var frog_sparkles: CPUParticles2D
```

c. In `_ready()`, delete the sparkle setup call:

```gdscript
	_setup_frog_sparkles()
```

d. Delete the entire `_setup_frog_sparkles` function.

e. Replace `_on_tongue_hit_fly` with the simplified version:

```gdscript
func _on_tongue_hit_fly(fly) -> void:
	if fly != null and "is_special" in fly and fly.is_special:
		GameEvents.special_fly_caught.emit()
		return
	GameEvents.fly_caught.emit(not is_on_floor())
```

f. Replace `_on_game_started` with the trimmed version:

```gdscript
func _on_game_started() -> void:
	_reset_frog_state()
```

g. Delete the entire `_activate_bullet_time` function.

h. Delete the entire `_update_bullet_time` function.

i. Delete the entire `_update_charge_visual` function.

j. In `_physics_process`, delete these three lines at the top:

```gdscript
	_update_bullet_time(delta)
	_update_charge_visual(delta)

	if (Input.is_action_just_pressed("bullet_time")
			and has_bullet_time_charge
			and bullet_time_remaining <= 0.0):
		_activate_bullet_time()
```

- [ ] **Step 4: Verify in editor**

Run the scene. Confirm:
- Catching a regular fly mid-air → score +10 * multiplier, multiplier increments
- Catching a special (gold sparkly) fly → frog starts gold-pulsing and sparkling, no score change
- Catching a second special fly while already charged → no change (single charge cap)
- Pressing V mid-jump with charge → world smoothly slows to ~12% for 3 seconds, then ramps back
- Pressing V mid-jump without charge → nothing happens
- Game restart → frog stops sparkling, time factor back to 1.0, no charge

If sparkles appear at the wrong z-order (behind the frog or floating elsewhere), verify the `get_parent().add_child(sparkles)` line in `bullet_time.gd` and the `z_index = 1` value.

---

## Final Verification

- [ ] **Run a full playthrough**

Run the scene from start to a full 60-second game. Verify:
- All scoring works (regular flies, multiplier, fall penalty)
- Shadow tracks correctly (size on crouch, alpha on ascent, opaque on descent/grounded)
- Lily pad bobs/sways on charge/jump/land
- Frog rides the pad during bobs
- Special flies grant bullet-time charge
- Bullet-time activation slows flies + frog airborne motion
- Falling off → respawn faces right
- Restart from Game Over → frog faces right, all state clean

- [ ] **Count lines**

Confirm `frog.gd` is now around 180 lines (was ~370):

```bash
wc -l /Users/nicholasmejia/godot/frog-bog/frog.gd
```

Expected: ~175–195 lines.

---

## Self-Review Notes

- **Spec coverage:** All audit items 1, 2, 4, 7 from the audit are addressed (dead code, SPECIAL_COLOR, shadow extraction, BulletTime extraction). Items 5 (`game_events.gd` splitting), 6 (frog feet magic — partially addressed in Task 3 by deriving from `CollisionShape2D`), 8 (scene-based particles), 9 (`_physics_process` further splitting), and 10 (bullet-time velocity scaling comment) are intentionally deferred — they're nice-to-haves with low impact.
- **No placeholders:** Every step contains the actual code to write or delete and the actual files to touch.
- **Naming consistency:** `shadow.anchor_y` is referenced in `frog.gd` dust functions (Task 3 Step 3) and defined as `@export var anchor_y` in the new `shadow.gd` (Task 3 Step 1). `bullet_time.gd` does not expose its internal `has_charge` to other scripts — state is communicated via existing `GameEvents.bullet_time_*` signals.
