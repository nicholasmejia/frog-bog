# Frog Portrait Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an animated portrait HUD element in the bottom-left corner that displays one of seven frog state portraits over a static frame, driven by a base-state + single-override state machine derived from the frog's current gameplay state.

**Architecture:** A new `frog_portrait.tscn` (CanvasLayer, `process_mode = ALWAYS`) instanced into `main.tscn`, with `frog_portrait.gd` as its script. Each frame the portrait selects its texture as: `override if override.timer > 0 else base_state_priority_winner`. Base state is computed from new shared booleans on `GameEvents` (`is_charging`, `is_jumping`, `bullet_time_active`) plus a local `_game_over` flag. Overrides are 2-second timed reactions to discrete signals (`level_changed`, `frog_fell`, new `tongue_returned(caught_fly)`). A newer override replaces an older one. Texture swap is dict-driven so future per-state position offsets (next upgrade) are a pure data edit. Visibility is owned by `main.gd`, matching the pattern used for `TitleScreen` / `GameOverScreen`.

**Tech Stack:** Godot 4.x, GDScript. No new addons; verification via the established headless parse-check workflow plus a scripted manual playtest checklist.

---

## File Structure

**New files:**
- `frog_portrait.gd` — portrait state machine + per-frame state computation + override timer. Single file, ~120 lines.
- `frog_portrait.tscn` — scene: `FrogPortrait` (CanvasLayer) → `Anchor` (Control, anchored bottom-left) → `Frame` (TextureRect) + `Sprite` (TextureRect). Initial state `visible = false`.

**Modified files:**
- `game_events.gd` — add 3 shared booleans (`is_charging`, `is_jumping`, `bullet_time_active`) and 1 new signal (`tongue_returned(caught_fly: bool)`).
- `frog.gd` — mirror `charging` / `in_jump_cycle` writes into `GameEvents.is_charging` / `GameEvents.is_jumping`; track per-shot tongue catch and emit `GameEvents.tongue_returned(...)` on tongue cycle completion.
- `bullet_time.gd` — mirror `remaining > 0` into `GameEvents.bullet_time_active`.
- `main.gd` — toggle `frog_portrait.visible` at the same transition points it already toggles other HUD scenes.
- `main.tscn` — instance `frog_portrait.tscn` as a top-level child.
- `CONTEXT.md` — already updated during grilling; no further changes here.

---

## Task 1: Add GameEvents shared state and `tongue_returned` signal

**Files:**
- Modify: `game_events.gd`

- [ ] **Step 1: Add the new signal and three shared booleans**

Edit `game_events.gd`. After the existing `signal special_fly_caught` line (around line 13), add the new signal. After `var level_progress: int = 0` (line 26), add the new booleans.

The full resulting state block at the bottom of the file should read:

```gdscript
# Shared mutable state read by frog/fly/shadow each frame
var time_factor: float = 1.0
var platform_offset: Vector2 = Vector2.ZERO
var frog_level: int = 0
var level_progress: int = 0
var is_charging: bool = false
var is_jumping: bool = false
var bullet_time_active: bool = false
```

And add (place near the other gameplay event signals, e.g. just after `signal special_fly_caught`):

```gdscript
signal tongue_returned(caught_fly: bool)
```

- [ ] **Step 2: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output (no errors).

- [ ] **Step 3: Commit**

```bash
git add game_events.gd
git commit -m "feat(events): add shared continuous-state booleans and tongue_returned signal for HUD consumers"
```

---

## Task 2: Publish `is_charging` and `is_jumping` from `frog.gd`

**Files:**
- Modify: `frog.gd`

- [ ] **Step 1: Mirror charging writes**

In `frog.gd`, every place that assigns to the `charging` member must also write to `GameEvents.is_charging`. Find these sites:

- `_reset_frog_state()` (around line 84) — already sets `charging = false`. Add immediately after:

```gdscript
    GameEvents.is_charging = false
```

- `set_frozen(value)` (around line 98) — in the `if frozen:` branch, after `charging = false`:

```gdscript
        GameEvents.is_charging = false
```

- `_physics_process(delta)` — there are two assignments to `charging`:
  - Around line 157: `charging = true` (jump pressed). Add after it:

```gdscript
            GameEvents.is_charging = true
```

  - In `_launch()` (around line 276): `charging = false`. Add after it:

```gdscript
    GameEvents.is_charging = false
```

- [ ] **Step 2: Mirror in_jump_cycle writes**

Find every assignment to `in_jump_cycle`:

- `_reset_frog_state()` (around line 95): `in_jump_cycle = false`. Add after:

```gdscript
    GameEvents.is_jumping = false
```

- `_physics_process(delta)`, landing branch (around line 183): `in_jump_cycle = false`. Add after:

```gdscript
            GameEvents.is_jumping = false
```

- `_launch()` (around line 289): `in_jump_cycle = true`. Add after:

```gdscript
    GameEvents.is_jumping = true
```

Note: `set_frozen(true)` does NOT currently reset `in_jump_cycle` directly — `_reset_frog_state` handles it via `_on_game_started`. The frozen branch zeroes velocity and clears charging, which is correct; jumping is implicitly handled by the respawn/reset path. No new line needed in `set_frozen` for is_jumping.

- [ ] **Step 3: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add frog.gd
git commit -m "feat(frog): publish is_charging and is_jumping to GameEvents for HUD consumers"
```

---

## Task 3: Emit `tongue_returned(caught_fly)` from `frog.gd`

**Files:**
- Modify: `frog.gd`

- [ ] **Step 1: Add a per-shot catch flag and tongue-busy tracker**

Add two new member variables in `frog.gd`, alongside the existing flags (after `var frozen: bool = false` around line 58):

```gdscript
var _tongue_caught_this_shot: bool = false
var _tongue_was_busy: bool = false
```

- [ ] **Step 2: Reset the catch flag when a new tongue shot starts**

In `_physics_process(delta)`, find the block where the tongue is fired (around lines 143-147):

```gdscript
    if (Input.is_action_just_pressed("shoot_tongue")
            and not is_on_floor()
            and not tongue.is_busy()):
        var aim: Vector2 = get_global_mouse_position() - tongue.global_position
        tongue.fire(aim)
```

Add a line setting the flag false just before `tongue.fire(aim)`:

```gdscript
    if (Input.is_action_just_pressed("shoot_tongue")
            and not is_on_floor()
            and not tongue.is_busy()):
        var aim: Vector2 = get_global_mouse_position() - tongue.global_position
        _tongue_caught_this_shot = false
        tongue.fire(aim)
```

- [ ] **Step 3: Set the catch flag when a fly is hit**

In `_on_tongue_hit_fly(fly)` (around line 73), add a line at the top (before the special-fly branch) that records this shot caught something:

```gdscript
func _on_tongue_hit_fly(fly) -> void:
    _tongue_caught_this_shot = true
    if fly != null and "is_special" in fly and fly.is_special:
        GameEvents.special_fly_caught.emit()
        return
    GameEvents.fly_caught.emit(not is_on_floor())
```

- [ ] **Step 4: Detect tongue cycle completion and emit the signal**

At the very end of `_physics_process(delta)` (after `was_on_floor = on_floor_now`, around line 204), add a tongue-busy transition check:

```gdscript
    var tongue_busy_now: bool = tongue.is_busy()
    if _tongue_was_busy and not tongue_busy_now:
        GameEvents.tongue_returned.emit(_tongue_caught_this_shot)
        _tongue_caught_this_shot = false
    _tongue_was_busy = tongue_busy_now
```

- [ ] **Step 5: Reset trackers when frog state resets**

In `_reset_frog_state()` (around line 84), add at the bottom of the function:

```gdscript
    _tongue_caught_this_shot = false
    _tongue_was_busy = false
```

- [ ] **Step 6: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 7: Manual smoke test**

Launch the game (`Godot --path /Users/nicholasmejia/godot/frog-bog`). Jump, fire tongue, hit a fly. Then jump, fire tongue, miss. Confirm no script errors in the console either way.

- [ ] **Step 8: Commit**

```bash
git add frog.gd
git commit -m "feat(frog): emit tongue_returned signal with per-shot catch flag"
```

---

## Task 4: Publish `bullet_time_active` from `bullet_time.gd`

**Files:**
- Modify: `bullet_time.gd`

- [ ] **Step 1: Mirror active-state into GameEvents**

In `bullet_time.gd`, edit `_update_time(delta)` (around line 58). Currently:

```gdscript
func _update_time(delta: float) -> void:
    if remaining > 0.0:
        remaining -= delta
        if remaining <= 0.0:
            remaining = 0.0
    var target: float = TARGET_FACTOR if remaining > 0.0 else 1.0
    var t: float = clampf(LERP_RATE * delta, 0.0, 1.0)
    GameEvents.time_factor = lerpf(GameEvents.time_factor, target, t)
```

Add the publish line after the remaining-update block:

```gdscript
func _update_time(delta: float) -> void:
    if remaining > 0.0:
        remaining -= delta
        if remaining <= 0.0:
            remaining = 0.0
    GameEvents.bullet_time_active = remaining > 0.0
    var target: float = TARGET_FACTOR if remaining > 0.0 else 1.0
    var t: float = clampf(LERP_RATE * delta, 0.0, 1.0)
    GameEvents.time_factor = lerpf(GameEvents.time_factor, target, t)
```

- [ ] **Step 2: Reset on game start**

In `_on_game_started()` (around line 91), add the reset after `remaining = 0.0`:

```gdscript
func _on_game_started() -> void:
    has_charge = false
    remaining = 0.0
    pulse_phase = 0.0
    GameEvents.time_factor = 1.0
    GameEvents.bullet_time_active = false
    sparkles.emitting = false
    sprite.modulate = Color(1, 1, 1, 1)
```

- [ ] **Step 3: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add bullet_time.gd
git commit -m "feat(bullet_time): publish bullet_time_active to GameEvents for HUD consumers"
```

---

## Task 5: Create the `frog_portrait.tscn` scene

**Files:**
- Create: `frog_portrait.tscn`

- [ ] **Step 1: Author the scene file**

Create `/Users/nicholasmejia/godot/frog-bog/frog_portrait.tscn` with the following contents. (Note: the script and texture `uid` fields are not strictly required — Godot will assign them on first editor open. The `path` references are what matter for loading.)

```
[gd_scene load_steps=10 format=3 uid="uid://b1frogportrait001"]

[ext_resource type="Script" path="res://frog_portrait.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/Frame.png" id="2_frame"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/Idle.png" id="3_idle"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/Charging.png" id="4_charging"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/Jumping.png" id="5_jumping"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/BulletTime.png" id="6_bullettime"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/LevelUp.png" id="7_levelup"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/Hurt.png" id="8_hurt"]
[ext_resource type="Texture2D" path="res://art/clean_portraits/EatFinished.png" id="9_eatfinished"]

[node name="FrogPortrait" type="CanvasLayer"]
process_mode = 3
visible = false
script = ExtResource("1_script")

[node name="Anchor" type="Control" parent="."]
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = -20.0
offset_right = 20.0
offset_bottom = -20.0
grow_vertical = 0
mouse_filter = 2

[node name="Frame" type="TextureRect" parent="Anchor"]
texture = ExtResource("2_frame")
stretch_mode = 0
mouse_filter = 2

[node name="Sprite" type="TextureRect" parent="Anchor"]
texture = ExtResource("3_idle")
stretch_mode = 0
mouse_filter = 2
```

Notes about the scene values used above:
- `process_mode = 3` on the CanvasLayer is `PROCESS_MODE_ALWAYS` (so override timers keep ticking during tree pauses like the game-over screen).
- `anchors_preset = 2` is `PRESET_BOTTOM_LEFT` for the Anchor Control.
- `offset_top = -20.0`, `offset_left = 20.0` shifts the anchor 20px right and 20px up from the bottom-left viewport corner — these are placeholders the user will tune visually in the editor.
- `mouse_filter = 2` is `MOUSE_FILTER_IGNORE` on all UI nodes (HUD is non-interactive).
- `Sprite` is listed after `Frame` in the tree, so it renders on top.
- Both `Frame` and `Sprite` use default `position = Vector2.ZERO` and `size = Vector2.ZERO` (`TextureRect` sizes itself to its texture by default). The user will fine-tune `Sprite.position` visually to center it over the frame.

- [ ] **Step 2: Open the editor once to let Godot assign UIDs**

Run: `Godot --editor --path /Users/nicholasmejia/godot/frog-bog`

In the editor, open `frog_portrait.tscn` in the Scene tab. Godot will resolve and assign uids on save. Save the scene (Ctrl+S) and close the editor. (This step is only needed because `frog_portrait.gd` does not exist yet; we create it in Task 6 and the editor will rewrite the ext_resource references then.)

If Godot complains about the missing script in step 2, that is expected — close the editor without saving and proceed. The script is created in Task 6, and the scene is fully re-validated in Task 7.

- [ ] **Step 3: Commit (scene only; script comes next)**

```bash
git add frog_portrait.tscn
git commit -m "feat(hud): add frog_portrait scene with Frame/Sprite under bottom-left Anchor"
```

---

## Task 6: Create the `frog_portrait.gd` script

**Files:**
- Create: `frog_portrait.gd`

- [ ] **Step 1: Write the full script**

Create `/Users/nicholasmejia/godot/frog-bog/frog_portrait.gd` with this exact contents:

```gdscript
extends CanvasLayer

# Frog Portrait HUD.
# Displays one of seven state portraits (Idle, Charging, Jumping, BulletTime,
# LevelUp, Hurt, EatFinished) over a static Frame. Texture selection follows a
# base-state + single-override model: base = continuous game state, override =
# 2-second timed reaction. New overrides replace old. When the override timer
# expires, the base state resumes. Game-over is itself a base state (highest
# priority) that pins EatFinished until restart.

enum PortraitState { IDLE, CHARGING, JUMPING, BULLET_TIME, LEVEL_UP, HURT, EAT_FINISHED }

const OVERRIDE_DURATION := 2.0
const OFFSET_TWEEN_TIME := 0.08

const PORTRAIT_CONFIG := {
    PortraitState.IDLE:         { "texture": preload("res://art/clean_portraits/Idle.png"),        "offset": Vector2.ZERO },
    PortraitState.CHARGING:     { "texture": preload("res://art/clean_portraits/Charging.png"),    "offset": Vector2.ZERO },
    PortraitState.JUMPING:      { "texture": preload("res://art/clean_portraits/Jumping.png"),     "offset": Vector2.ZERO },
    PortraitState.BULLET_TIME:  { "texture": preload("res://art/clean_portraits/BulletTime.png"),  "offset": Vector2.ZERO },
    PortraitState.LEVEL_UP:     { "texture": preload("res://art/clean_portraits/LevelUp.png"),     "offset": Vector2.ZERO },
    PortraitState.HURT:         { "texture": preload("res://art/clean_portraits/Hurt.png"),        "offset": Vector2.ZERO },
    PortraitState.EAT_FINISHED: { "texture": preload("res://art/clean_portraits/EatFinished.png"), "offset": Vector2.ZERO },
}

@onready var sprite: TextureRect = $Anchor/Sprite

var _override_state: int = -1
var _override_remaining: float = 0.0
var _game_over: bool = false
var _current_applied: int = -1
var _offset_tween: Tween = null
var _levelup_pending: bool = false


func _ready() -> void:
    GameEvents.tongue_returned.connect(_on_tongue_returned)
    GameEvents.level_changed.connect(_on_level_changed)
    GameEvents.frog_fell.connect(_on_frog_fell)
    GameEvents.game_started.connect(_on_game_started)
    GameEvents.game_ended.connect(_on_game_ended)
    _apply_state(PortraitState.IDLE, true)


func _process(delta: float) -> void:
    if _override_remaining > 0.0:
        _override_remaining -= delta
        if _override_remaining <= 0.0:
            _override_remaining = 0.0
            _override_state = -1
    var desired: int = _compute_desired_state()
    if desired != _current_applied:
        _apply_state(desired, false)


func _compute_desired_state() -> int:
    if _override_state != -1:
        return _override_state
    if _game_over:
        return PortraitState.EAT_FINISHED
    if GameEvents.bullet_time_active:
        return PortraitState.BULLET_TIME
    if GameEvents.is_charging:
        return PortraitState.CHARGING
    if GameEvents.is_jumping:
        return PortraitState.JUMPING
    return PortraitState.IDLE


func _apply_state(state: int, instant: bool) -> void:
    _current_applied = state
    var cfg: Dictionary = PORTRAIT_CONFIG[state]
    sprite.texture = cfg["texture"]
    var target_offset: Vector2 = cfg["offset"]
    if _offset_tween != null and _offset_tween.is_valid():
        _offset_tween.kill()
    if instant or target_offset == sprite.position:
        sprite.position = target_offset
        return
    _offset_tween = create_tween()
    _offset_tween.tween_property(sprite, "position", target_offset, OFFSET_TWEEN_TIME)


func _trigger_override(state: int) -> void:
    _override_state = state
    _override_remaining = OVERRIDE_DURATION


func _on_level_changed(new_level: int) -> void:
    if new_level <= 0:
        _levelup_pending = false
        return
    _levelup_pending = true
    _trigger_override(PortraitState.LEVEL_UP)


func _on_frog_fell() -> void:
    _levelup_pending = false
    _trigger_override(PortraitState.HURT)


func _on_tongue_returned(caught_fly: bool) -> void:
    var was_levelup: bool = _levelup_pending
    _levelup_pending = false
    if not caught_fly:
        return
    if was_levelup:
        return
    _trigger_override(PortraitState.EAT_FINISHED)


func _on_game_started() -> void:
    _game_over = false
    _override_state = -1
    _override_remaining = 0.0
    _levelup_pending = false
    _apply_state(PortraitState.IDLE, true)


func _on_game_ended(_final_score: int) -> void:
    _game_over = true
```

**How LevelUp wins the same-catch collision with EatFinished:** The two events have very different emission timing — `level_changed` fires synchronously inside `frog._on_tongue_hit_fly` (the moment the tongue's Area2D collides with a fly, mid-frame), while `tongue_returned` fires N frames later at the end of `_physics_process` when the tongue retract completes. So `tongue_returned` always arrives AFTER `level_changed`. To ensure LevelUp wins, the portrait tracks `_levelup_pending` — set true when `level_changed(new_level > 0)` fires, snapshotted-then-cleared at every `tongue_returned`. If `was_levelup` is true when the tongue returns, the EatFinished override is suppressed (LevelUp remains showing). Subsequent independent catches (Path C: new catch during a still-active LevelUp window) correctly fire EatFinished because the flag was cleared at the previous catch's tongue cycle end. `_on_frog_fell` defensively clears the flag so a mid-shot fall doesn't carry stale state. Mid-shot resets in `frog.gd._reset_frog_state()` also clear `_tongue_caught_this_shot`, so a fall mid-catch causes `tongue_returned(false)` (or no emission at all) — preventing a post-fall EatFinished from overriding the Hurt override.

- [ ] **Step 2: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add frog_portrait.gd
git commit -m "feat(hud): add frog_portrait state machine with base+override and dict-driven config"
```

---

## Task 7: Wire `frog_portrait.tscn` into `main.tscn`

**Files:**
- Modify: `main.tscn`

- [ ] **Step 1: Add the ext_resource entry**

In `main.tscn`, find the block of `ext_resource` declarations at the top (lines 3-13). Add a new line for the portrait scene (place it after the `pre_game_fade` ext_resource):

```
[ext_resource type="PackedScene" path="res://frog_portrait.tscn" id="12_portrait"]
```

(The `uid` is omitted — Godot will resolve it when the editor opens the file.)

- [ ] **Step 2: Add the node instance**

Add a new node instance line near the bottom of the file, after the `PreGameFade` instance (around line 126):

```
[node name="FrogPortrait" parent="." instance=ExtResource("12_portrait")]
```

- [ ] **Step 3: Open the editor to resolve UIDs**

Run: `Godot --editor --path /Users/nicholasmejia/godot/frog-bog`

Open `main.tscn`, confirm `FrogPortrait` appears in the Scene tab and the portrait is visible in the editor viewport at the bottom-left of the play area (it will be hidden at runtime but visible in editor preview). Save (Ctrl+S) and close.

- [ ] **Step 4: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add main.tscn frog_portrait.tscn
git commit -m "feat(hud): instance FrogPortrait into main scene"
```

---

## Task 8: Wire visibility into `main.gd`

**Files:**
- Modify: `main.gd`

- [ ] **Step 1: Add an `@onready` reference to the portrait**

In `main.gd`, after the existing `@onready` declarations (around line 15), add:

```gdscript
@onready var frog_portrait: CanvasLayer = $FrogPortrait
```

- [ ] **Step 2: Hide on title entry**

In `_enter_title()` (around line 48), add `frog_portrait.visible = false` near the existing visibility resets. The full updated function:

```gdscript
func _enter_title() -> void:
    state = State.TITLE
    time_left = GAME_DURATION
    _update_timer_label()
    frog.global_position = frog_spawn
    frog.set_frozen(true)
    game_over_screen.visible = false
    frog_portrait.visible = false
    get_tree().paused = true
    title_screen.play()
```

- [ ] **Step 3: Hide on pre-game entry**

In `_begin_pre_game()` (around line 67):

```gdscript
func _begin_pre_game() -> void:
    state = State.PRE_GAME
    game_over_screen.visible = false
    frog_portrait.visible = false
    # Engine stays paused; PreGameFade has process_mode = ALWAYS so it animates anyway.
    get_tree().paused = true
    pre_game_fade.play()
```

- [ ] **Step 4: Show when fade-in completes (countdown begins)**

In `_on_fade_in()` (around line 87):

```gdscript
func _on_fade_in() -> void:
    # Black has just faded out; start the countdown.
    state = State.COUNTDOWN
    get_tree().paused = false  # Flies must spawn during the countdown.
    frog_portrait.visible = true
    countdown.play()
```

- [ ] **Step 5: Parse-check**

Run: `Godot --headless --editor --quit | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)"`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add main.gd
git commit -m "feat(main): toggle frog_portrait visibility at title/pregame/countdown transitions"
```

---

## Task 9: Manual verification playtest

**Files:** none modified — this is the verification gate before declaring the feature complete.

- [ ] **Step 1: Launch the game**

Run: `Godot --path /Users/nicholasmejia/godot/frog-bog`

- [ ] **Step 2: Verify visibility lifecycle**

- Title Screen plays. **Frog Portrait is NOT visible.** ✓
- Press SPACE. Pre-game fade to black plays. **Portrait still NOT visible.** ✓
- Fade back in, Countdown ("3, 2, 1, Start!") plays. **Portrait appears, showing Idle.** ✓
- Gameplay begins. Portrait remains on screen for the rest of the run.

- [ ] **Step 3: Verify each portrait state in isolation**

| Action | Expected portrait |
|---|---|
| Stand still on platform | Idle |
| Hold SPACE (charging a jump) | Charging |
| Release SPACE, frog jumps; in air | Jumping |
| Frog lands back on platform | Idle |
| In air, fire tongue, catch a regular fly | EatFinished for 2s, then Idle (or Jumping if still airborne) |
| In air, fire tongue, miss | No portrait change (stays Jumping) |
| Walk off / fall off the platform | Hurt for 2s, then Idle |
| Eat 3 flies to level up | LevelUp for 2s, then back to current base |
| Catch a Special Fly, press V to activate Bullet Time | BulletTime for the full 3s (or 5s at Level 3), then back to current base |

- [ ] **Step 4: Verify override collisions**

| Scenario | Expected behavior |
|---|---|
| Activate BulletTime in air → catch a regular fly | BulletTime → EatFinished (2s) → BulletTime resumes if time remaining → Jumping/Idle |
| Activate BulletTime → catch fly that triggers level-up | BulletTime → LevelUp (2s, NOT EatFinished) → BulletTime resumes if time remaining |
| Fall mid-jump | Jumping → Hurt (2s) → Idle |
| Fall while BulletTime active | BulletTime → Hurt (2s) → BulletTime resumes if time remaining → Idle |
| Fall in the final 2 seconds of the round (timer expires during Hurt) | Hurt completes its full 2s, then settles into EatFinished (game-over base state) |

- [ ] **Step 5: Verify game-over and restart**

- Let the timer run out. **Game Over screen appears, portrait shows EatFinished.** ✓
- Click Restart. Fade plays, countdown plays. **Portrait shows Idle when gameplay resumes (game-over flag cleared).** ✓

- [ ] **Step 6: Verify Frame stability**

Throughout all of the above, the **Portrait Frame** (background) never moves or changes — only the inner **Portrait Sprite** texture swaps.

- [ ] **Step 7: Visual fine-tuning**

This is the equivalent of the title-letter manual adjustment. Open `frog_portrait.tscn` in the editor and tune:
- `Anchor.offset_left` / `offset_top` — to position the whole portrait in the corner.
- `Sprite.position` — to center the inner sprite over the Frame visually.

Save and commit if values change:

```bash
git add frog_portrait.tscn
git commit -m "chore(hud): tune frog portrait placement in editor"
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ Idle / Charging / Jumping / BulletTime / LevelUp / Hurt / EatFinished — all seven states mapped (Task 6 dict).
- ✅ Charging while space held — read from `GameEvents.is_charging` (Tasks 2, 6).
- ✅ Jumping from release until landing — read from `GameEvents.is_jumping` (Tasks 2, 6).
- ✅ LevelUp 2s after level-up — override on `level_changed` (Task 6, gated to `new_level > 0` to ignore reset emissions).
- ✅ Hurt 2s after fall — override on `frog_fell` (Task 6).
- ✅ BulletTime for the duration of bullet time — read from `GameEvents.bullet_time_active` (Tasks 4, 6).
- ✅ EatFinished 2s after tongue retracts with catch — override on new `tongue_returned(true)` signal (Tasks 1, 3, 6).
- ✅ EatFinished persists after game over until restart — base state via `_game_over` flag, set on `game_ended`, cleared on `game_started` (Task 6).
- ✅ Bottom-left HUD placement — Anchor preset bottom-left (Task 5).
- ✅ Frame.png as background, portrait sprites overlaid — Frame + Sprite siblings under Anchor (Task 5).
- ✅ Designed for future per-state position offsets — dict already carries `offset` Vector2, all zero today, Tween scaffolded (Task 6).
- ✅ Newer override replaces older — `_trigger_override` unconditionally overwrites `_override_state` and resets timer (Task 6).
- ✅ Base state resumes after override expires — `_compute_desired_state()` checks override first, then falls through to base (Task 6).

**Type consistency check:** `PortraitState` enum used consistently as `int` parameter type. `Vector2` used consistently for offsets. `TextureRect` used for both `Frame` and `Sprite`. `GameEvents.is_charging` / `is_jumping` / `bullet_time_active` referenced identically in publishers (Tasks 2, 4) and consumer (Task 6). Signal name `tongue_returned(caught_fly: bool)` consistent across emission site (Task 3) and connection (Task 6).

**No placeholders.** Every step shows the exact code to write and the exact command to run.

**Plan complete.** Saved to `plans/2026-05-16-frog-portrait.md`.
