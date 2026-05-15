# Title Screen & Game Start Countdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `$StartScreen` with a fully animated **Title Screen** (Title Sequence → Attract State) and a **Game Start Countdown** (3 → 2 → 1 → Start!) that bridges the Title Screen and gameplay through a **Pre-Game Fade**. Restart from Game Over re-runs the Pre-Game Fade and Countdown but skips the Title Screen.

**Architecture:** Three new sibling CanvasLayer scenes (`title_screen.tscn`, `pre_game_fade.tscn`, `countdown.tscn`) live alongside the existing `$GameOverScreen` in `main.tscn`. Each owns its own animation logic and emits a single completion signal that drives the `Main` state machine. `main.gd`'s `enum State` grows from `{ MENU, PLAYING, GAME_OVER }` to `{ TITLE, PRE_GAME, COUNTDOWN, PLAYING, GAME_OVER }`. The Frog gains a `frozen` flag (set during COUNTDOWN) so the engine doesn't have to be paused — Flies spawn and the world ticks during the countdown. Letter positioning lives in the `title_screen.tscn` scene (Sprite2D nodes placed visually); the script only animates relative offsets.

**Tech Stack:** Godot 4.6 (GL Compatibility), GDScript. No test framework — verification is manual in the Godot editor (matches `plans/2026-05-13-codebase-cleanup.md` and `plans/2026-05-14-level-up-system.md`). After every GDScript edit, run a headless parse-check.

**Supporting docs:**
- `CONTEXT.md` — glossary; updated during the grill-with-docs session that produced this plan (Title Screen, Title Sequence, Attract State, Subheading Crash, Letter Ripple, Pre-Game Fade, Game Start Countdown, Game Start, Restart).
- `art/title_card.png` — the target final composition the Title Screen renders.
- `art/title_no_text.png` — the Title Screen background.
- `art/title_text/` — letter glyph PNGs (solid + `_wireframe`).

---

## File Structure

| File | Responsibility | Touched by Task |
|------|---------------|-----------------|
| `frog.gd` | Add `frozen` flag + `set_frozen()`; skip input/movement when frozen | 1 |
| `pre_game_fade.gd` | NEW. Black ColorRect that tweens alpha; emits `faded_out` and `faded_in` | 2 |
| `pre_game_fade.tscn` | NEW. CanvasLayer wrapping a fullscreen ColorRect with `process_mode = ALWAYS` | 2 |
| `countdown.gd` | NEW. Plays "3 → 2 → 1 → Start!" with per-beat pop-in/fade-out; emits `countdown_finished` | 3 |
| `countdown.tscn` | NEW. CanvasLayer + center Label using `Spicy Sale.ttf` | 3 |
| `title_screen.tscn` | NEW. All 9 FROGBOG 99 sprite pairs (solid + wireframe) + 3 subheading sprites + black/white overlays + "Press SPACE to play" Label, all positioned visually | 4 |
| `title_screen.gd` | NEW. Owns the Title Sequence (cascade → flash → reveal → subheading crash → letter ripple → attract). Emits `start_requested` when SPACE is pressed during Attract State | 5, 6, 7, 8, 9 |
| `main.gd` | State machine refactor: TITLE / PRE_GAME / COUNTDOWN / PLAYING / GAME_OVER. Wires title/fade/countdown signals. Restart routes through fade + countdown | 10, 11 |
| `main.tscn` | Delete `$StartScreen`; instance `$TitleScreen`, `$PreGameFade`, `$Countdown` | 10 |

Each task ends with a parse-check + manual verification + commit.

---

## Pre-flight

- [ ] **Step 0: Confirm baseline works**

Open the project in Godot 4.6 and press F5. Verify:
- Start screen shows; click Start.
- Frog jumps when you hold then release Space.
- Catch a fly mid-air → score goes up.
- Walk off the platform edge → -30 points, frog respawns at spawn position facing right.
- Timer hits 0 → Game Over → Restart works.

Then run the headless parse check to confirm a clean baseline:

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

If anything is broken before starting, stop and fix it. Otherwise proceed.

---

## Task 1: Add `frozen` flag to `frog.gd`

**Files:**
- Modify: `frog.gd`

The Frog must be visible-but-inert during the Game Start Countdown. We add a `frozen` flag that short-circuits `_physics_process`. The Frog stays at its spawn position with idle animation; charge input does nothing.

- [ ] **Step 1: Add `frozen` field and setter**

Open `frog.gd`. After the `var in_jump_cycle: bool = false` line (line 57), add:

```gdscript
var frozen: bool = false
```

Then, after `_reset_frog_state()` (around line 95, before `_emit_dust`), add:

```gdscript
func set_frozen(value: bool) -> void:
	frozen = value
	if frozen:
		velocity = Vector2.ZERO
		charging = false
		charge_time = 0.0
		shake_phase = 0.0
		sprite.offset = Vector2.ZERO
		sprite.play("idle")
```

- [ ] **Step 2: Short-circuit `_physics_process` when frozen**

In `_physics_process(delta)` (line 126), add an early return at the very top:

```gdscript
func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return

	if (Input.is_action_just_pressed("shoot_tongue")
			and not is_on_floor()
			and not tongue.is_busy()):
		# ... rest unchanged
```

- [ ] **Step 3: Parse-check**

Run:
```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 4: Manual verification**

Press F5. Click Start. Verify gameplay still works exactly as before (the `frozen` flag defaults to `false`, so nothing should change).

- [ ] **Step 5: Commit**

```bash
git add frog.gd
git commit -m "feat: add frozen flag to Frog for use during Game Start Countdown"
```

---

## Task 2: Create `PreGameFade` scene + script

**Files:**
- Create: `pre_game_fade.gd`
- Create: `pre_game_fade.tscn`

Black overlay that fades the screen out, holds, and fades back in. Used to bridge Title Screen → Countdown and Game Over → Countdown.

- [ ] **Step 1: Create `pre_game_fade.gd`**

Create a new file `pre_game_fade.gd`:

```gdscript
extends CanvasLayer

# Pre-Game Fade.
# A full-screen black overlay that fades out (to opaque black) and back in (to clear).
# Used to bridge the Title Screen into the Game Start Countdown, and to
# bridge a Restart from Game Over into a fresh Game Start Countdown.

const FADE_OUT_DURATION := 0.4
const HOLD_BLACK_DURATION := 0.1
const FADE_IN_DURATION := 0.4

signal faded_to_black
signal faded_in

@onready var rect: ColorRect = $Rect


func _ready() -> void:
	rect.color = Color(0, 0, 0, 0)
	visible = false


func play() -> void:
	visible = true
	rect.color = Color(0, 0, 0, 0)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void: faded_to_black.emit())
	tween.tween_interval(HOLD_BLACK_DURATION)
	tween.tween_property(rect, "color:a", 0.0, FADE_IN_DURATION)
	tween.tween_callback(func() -> void:
		visible = false
		faded_in.emit()
	)
```

- [ ] **Step 2: Create `pre_game_fade.tscn`**

In Godot, create a new scene with root node `CanvasLayer`, name it `PreGameFade`. Set:
- `layer = 100` (above gameplay, below GameOver)
- `process_mode = Process Mode > Always` (so it animates while paused)
- Attach `pre_game_fade.gd`

Add a child `ColorRect` named `Rect`:
- `anchors_preset = Full Rect` (anchor_right = 1.0, anchor_bottom = 1.0)
- `color = Color(0, 0, 0, 0)`
- `mouse_filter = Ignore`

Save as `res://pre_game_fade.tscn`.

- [ ] **Step 3: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add pre_game_fade.gd pre_game_fade.tscn pre_game_fade.gd.uid pre_game_fade.tscn.uid 2>/dev/null; git add pre_game_fade.gd pre_game_fade.tscn
git commit -m "feat: add Pre-Game Fade overlay component"
```

---

## Task 3: Create `Countdown` scene + script

**Files:**
- Create: `countdown.gd`
- Create: `countdown.tscn`

The Game Start Countdown shows "3", "2", "1", "Start!" in sequence at the center of the viewport. Each beat lasts 1.0s. "Start!" gradually fades out as the countdown ends (so the player sees gameplay begin without an abrupt cut).

- [ ] **Step 1: Create `countdown.gd`**

Create a new file `countdown.gd`:

```gdscript
extends CanvasLayer

# Game Start Countdown.
# Shows "3" -> "2" -> "1" -> "Start!" at the center of the viewport.
# Each numeric beat is shown for BEAT_DURATION; "Start!" pops in then fades out
# over START_FADE_DURATION. Emits `countdown_finished` when the final fade ends.

const BEAT_DURATION := 1.0
const POP_IN_DURATION := 0.15
const POP_IN_SCALE := 1.5
const START_HOLD := 0.4
const START_FADE_DURATION := 0.4

signal countdown_finished

@onready var label: Label = $Label

var _running: bool = false


func _ready() -> void:
	visible = false
	label.modulate.a = 0.0
	label.scale = Vector2.ONE


func play() -> void:
	if _running:
		return
	_running = true
	visible = true
	_play_beat("3")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_beat("2")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_beat("1")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_start()
	await get_tree().create_timer(START_HOLD + START_FADE_DURATION).timeout
	visible = false
	_running = false
	countdown_finished.emit()


func _play_beat(text: String) -> void:
	label.text = text
	label.scale = Vector2(POP_IN_SCALE, POP_IN_SCALE)
	label.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, POP_IN_DURATION)
	tween.tween_property(label, "modulate:a", 1.0, POP_IN_DURATION)


func _play_start() -> void:
	label.text = "Start!"
	label.scale = Vector2(POP_IN_SCALE, POP_IN_SCALE)
	label.modulate.a = 0.0
	var pop: Tween = create_tween().set_parallel(true)
	pop.tween_property(label, "scale", Vector2.ONE, POP_IN_DURATION)
	pop.tween_property(label, "modulate:a", 1.0, POP_IN_DURATION)
	await pop.finished
	await get_tree().create_timer(START_HOLD).timeout
	var fade: Tween = create_tween()
	fade.tween_property(label, "modulate:a", 0.0, START_FADE_DURATION)
```

- [ ] **Step 2: Create `countdown.tscn`**

In Godot, create a new scene with root node `CanvasLayer`, name it `Countdown`. Set:
- `layer = 50`
- `process_mode = Inherit` (countdown runs while engine is unpaused — the Game Start Countdown is NOT a paused state)
- Attach `countdown.gd`

Add a child `Label` named `Label`:
- `anchors_preset = Center` (anchor_left = anchor_right = 0.5; anchor_top = anchor_bottom = 0.5)
- `offset_left = -300`, `offset_right = 300`, `offset_top = -150`, `offset_bottom = 150`
- `text = "3"`
- `horizontal_alignment = Center`, `vertical_alignment = Center`
- `theme_override_fonts/font` = `res://fonts/Spicy Sale.ttf`
- `theme_override_font_sizes/font_size` = `200`
- `theme_override_colors/font_color` = `Color(1, 1, 1, 1)`
- `theme_override_colors/font_outline_color` = `Color(0, 0, 0, 1)`
- `theme_override_constants/outline_size` = `12`
- `pivot_offset` = `Vector2(300, 150)` (center of the label box, so scale tweens look centered)
- `mouse_filter = Ignore`

Save as `res://countdown.tscn`.

- [ ] **Step 3: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add countdown.gd countdown.tscn
git commit -m "feat: add Game Start Countdown overlay component"
```

---

## Task 4: Build `title_screen.tscn` with all assets positioned

**Files:**
- Create: `title_screen.tscn`

This is the layout-only task — the script comes later. The scene is built visually in the Godot editor to match `art/title_card.png`. The script (Tasks 5-9) will read each sprite's scene-defined position as its "home" and animate from there.

- [ ] **Step 1: Create the scene shell**

In Godot, create a new scene with root node `CanvasLayer`, name it `TitleScreen`. Set:
- `layer = 80` (above gameplay/HUD, below PreGameFade and GameOver)
- `process_mode = Always`

Save as `res://title_screen.tscn`.

- [ ] **Step 2: Add the background and overlays**

Add these direct children of the `TitleScreen` CanvasLayer in this order (later children render on top):

1. `Background` (`Sprite2D`):
   - `texture = res://art/title_no_text.png`
   - `centered = false`
   - `position = (0, 0)`
   - `modulate = Color(1, 1, 1, 1)` (will be hidden initially via the Black overlay above it)

2. `LogoLayer` (`Node2D`): a container for the FROGBOG 99 letters. Position `(0, 0)`. (Letter sprites go inside this in Step 3.)

3. `SubheadingLayer` (`Node2D`): a container for TAKE / NO / PRISONERS!. Position `(0, 0)`. (Subheading sprites go inside this in Step 4.)

4. `PressToPlay` (`Label`):
   - `anchors_preset = Bottom Wide`
   - `offset_top = -120`, `offset_bottom = -40`
   - `text = "Press SPACE to play"`
   - `horizontal_alignment = Center`, `vertical_alignment = Center`
   - `theme_override_fonts/font = res://fonts/Spicy Sale.ttf`
   - `theme_override_font_sizes/font_size = 56`
   - `theme_override_colors/font_color = Color(1, 1, 1, 1)`
   - `theme_override_colors/font_outline_color = Color(0, 0, 0, 1)`
   - `theme_override_constants/outline_size = 6`
   - `modulate = Color(1, 1, 1, 0)` (starts hidden)
   - `mouse_filter = Ignore`

5. `WhiteFlash` (`ColorRect`):
   - `anchors_preset = Full Rect`
   - `color = Color(1, 1, 1, 0)`
   - `mouse_filter = Ignore`

6. `Black` (`ColorRect`):
   - `anchors_preset = Full Rect`
   - `color = Color(0, 0, 0, 1)`
   - `mouse_filter = Ignore`
   - (This sits on top initially to cover everything; the Title Sequence will fade it out.)

- [ ] **Step 3: Add the FROGBOG 99 letter pairs**

Inside `LogoLayer`, add 9 child `Node2D` containers — one per glyph slot — named `L0_F`, `L1_R`, `L2_O`, `L3_G`, `L4_B`, `L5_O`, `L6_G`, `L7_9`, `L8_9`. (The `L<index>_<glyph>` naming makes ordering unambiguous in code.)

For each container:
- Position it at the desired final on-screen position of that glyph's center (approximately match `art/title_card.png` — the FROGBOG row is centered around y=180, with x spaced across roughly 100..1450).
- Add two `Sprite2D` children: `Solid` and `Wireframe`.
- `Solid.texture` = the matching solid PNG (`F.png`, `R.png`, `O.png`, `G.png`, `B.png`, `O.png`, `G.png`, `9.png`, `9.png`)
- `Wireframe.texture` = the matching wireframe PNG (same names with `_wireframe` suffix)
- `Solid.modulate = Color(1, 1, 1, 0)` (hidden)
- `Wireframe.modulate = Color(1, 1, 1, 0)` (hidden)
- Both sprites: `centered = true`, position `(0, 0)` (the container holds the world position).
- Set `Solid.scale` and `Wireframe.scale` to ~`Vector2(0.3, 0.3)` and tune until the composition matches `title_card.png`. Per-letter scale tuning is expected; do not assume uniform scale.

Goal: with the Black overlay temporarily hidden in the editor, the 9 solid letters should compose `FROGBOG 99` matching the title card.

- [ ] **Step 4: Add the subheading sprites**

Inside `SubheadingLayer`, add three child `Sprite2D` nodes:

1. `Take`:
   - `texture = res://art/title_text/TAKE.png`
   - `centered = true`
   - `position` = the final on-screen position of TAKE (left side of the subheading row, y ≈ 380 — match `title_card.png`)
   - `modulate = Color(1, 1, 1, 0)`
   - `scale` ≈ `Vector2(0.3, 0.3)` (tune to match title card)

2. `No`:
   - `texture = res://art/title_text/NO.png`
   - `centered = true`
   - `position` = the final on-screen position of NO (between TAKE and PRISONERS!)
   - `modulate = Color(1, 1, 1, 0)`
   - `scale` ≈ `Vector2(0.18, 0.18)` (smaller than TAKE/PRISONERS to match the title card composition; tune as needed)

3. `Prisoners`:
   - `texture = res://art/title_text/PRISONERS.png`
   - `centered = true`
   - `position` = the final on-screen position of PRISONERS! (right side)
   - `modulate = Color(1, 1, 1, 0)`
   - `scale` ≈ `Vector2(0.3, 0.3)` (tune)

- [ ] **Step 5: Visually verify the composition**

Temporarily set `Black.color.a = 0`, set every letter/subheading `modulate.a = 1`, and inspect the editor view. Confirm the composition closely matches `art/title_card.png`. Tune positions and scales as needed. When done, set `Black.color.a` back to `1.0` and all letter/subheading `modulate.a` back to `0.0`. Save the scene.

- [ ] **Step 6: Commit**

```bash
git add title_screen.tscn
git commit -m "feat: add title_screen.tscn with positioned letter and subheading sprites"
```

---

## Task 5: `title_screen.gd` skeleton + state machine + skip handling

**Files:**
- Create: `title_screen.gd`

The script owns the Title Sequence playback. We start with an empty skeleton that exposes the `start_requested` signal, the SPACE handling (skip → Attract State; from Attract State → emit `start_requested`), and a `play()` entry point that does nothing yet. Subsequent tasks fill in each phase.

- [ ] **Step 1: Create `title_screen.gd`**

Create `title_screen.gd`:

```gdscript
extends CanvasLayer

# Title Screen.
# Owns the Title Sequence (wireframe cascade -> screen flash -> solid reveal ->
# subheading crash -> letter ripple) and the Attract State ("Press SPACE to play"
# blink). Pressing SPACE during the sequence skips to the Attract State; pressing
# SPACE during the Attract State emits `start_requested`.

signal start_requested

enum Phase { IDLE, SEQUENCE, ATTRACT }

@onready var black: ColorRect = $Black
@onready var white_flash: ColorRect = $WhiteFlash
@onready var background: Sprite2D = $Background
@onready var logo_layer: Node2D = $LogoLayer
@onready var subheading_layer: Node2D = $SubheadingLayer
@onready var take: Sprite2D = $SubheadingLayer/Take
@onready var no_word: Sprite2D = $SubheadingLayer/No
@onready var prisoners: Sprite2D = $SubheadingLayer/Prisoners
@onready var press_to_play: Label = $PressToPlay

var phase: int = Phase.IDLE
var _letter_homes: Array[Vector2] = []
var _subheading_homes: Dictionary = {}
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	visible = false
	_capture_homes()


func play() -> void:
	visible = true
	phase = Phase.SEQUENCE
	_reset_to_initial_visuals()
	_run_sequence()


func _capture_homes() -> void:
	_letter_homes.clear()
	for child in logo_layer.get_children():
		_letter_homes.append((child as Node2D).position)
	_subheading_homes = {
		"take": take.position,
		"no": no_word.position,
		"prisoners": prisoners.position,
	}


func _reset_to_initial_visuals() -> void:
	black.color = Color(0, 0, 0, 1)
	white_flash.color = Color(1, 1, 1, 0)
	for container in logo_layer.get_children():
		var solid: Sprite2D = container.get_node("Solid")
		var wireframe: Sprite2D = container.get_node("Wireframe")
		solid.modulate = Color(1, 1, 1, 0)
		wireframe.modulate = Color(1, 1, 1, 0)
		(container as Node2D).position = _letter_homes[container.get_index()]
	take.modulate = Color(1, 1, 1, 0)
	no_word.modulate = Color(1, 1, 1, 0)
	prisoners.modulate = Color(1, 1, 1, 0)
	take.position = _subheading_homes["take"]
	no_word.position = _subheading_homes["no"]
	prisoners.position = _subheading_homes["prisoners"]
	press_to_play.modulate = Color(1, 1, 1, 0)


func _run_sequence() -> void:
	# Filled in by Tasks 6, 7, 8, 9.
	_enter_attract_state()


func _enter_attract_state() -> void:
	phase = Phase.ATTRACT
	# Fully populated by Task 9; for now, just compose the final image.
	black.color = Color(0, 0, 0, 0)
	white_flash.color = Color(1, 1, 1, 0)
	for container in logo_layer.get_children():
		var solid: Sprite2D = container.get_node("Solid")
		var wireframe: Sprite2D = container.get_node("Wireframe")
		solid.modulate = Color(1, 1, 1, 1)
		wireframe.modulate = Color(1, 1, 1, 0)
	take.modulate = Color(1, 1, 1, 1)
	no_word.modulate = Color(1, 1, 1, 1)
	prisoners.modulate = Color(1, 1, 1, 1)
	press_to_play.modulate = Color(1, 1, 1, 1)


func _kill_active_tweens() -> void:
	for t in _active_tweens:
		if t and t.is_valid():
			t.kill()
	_active_tweens.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("jump"):
		return
	if phase == Phase.SEQUENCE:
		_kill_active_tweens()
		_enter_attract_state()
		get_viewport().set_input_as_handled()
	elif phase == Phase.ATTRACT:
		phase = Phase.IDLE
		start_requested.emit()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Attach the script in `title_screen.tscn`**

In the Godot editor, open `title_screen.tscn`, select the root `TitleScreen` CanvasLayer node, and attach `res://title_screen.gd`. Save the scene.

- [ ] **Step 3: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add title_screen.gd title_screen.tscn
git commit -m "feat: add TitleScreen skeleton with skip handling and phase enum"
```

---

## Task 6: Wireframe Cascade + Reveal Flash

**Files:**
- Modify: `title_screen.gd`

Implement the first beat of the Title Sequence: each wireframe letter fades in then out in a left-to-right cascade with a rainbow hue spread across the row. Total cascade duration ~1.5s. Then a full-screen white flash (alpha 1 → 0 over 0.25s) hides the swap from wireframes (now hidden) to solid letters (now revealed) with the black overlay also fading away.

- [ ] **Step 1: Implement cascade and flash, replacing the placeholder `_run_sequence`**

In `title_screen.gd`, replace the existing `_run_sequence()` body with:

```gdscript
const CASCADE_DURATION := 1.5
const CASCADE_LETTER_LIFETIME := 0.55  # each wireframe letter visible for this long
const REVEAL_FLASH_DURATION := 0.25


func _run_sequence() -> void:
	await _play_wireframe_cascade()
	await _play_reveal_flash()
	# Subheading crash + letter ripple come in later tasks.
	_enter_attract_state()


func _play_wireframe_cascade() -> void:
	var letter_count: int = logo_layer.get_child_count()
	var stagger: float = (CASCADE_DURATION - CASCADE_LETTER_LIFETIME) / float(max(letter_count - 1, 1))
	for i in range(letter_count):
		var container: Node2D = logo_layer.get_child(i) as Node2D
		var wireframe: Sprite2D = container.get_node("Wireframe")
		var hue: float = float(i) / float(letter_count)
		var hue_color: Color = Color.from_hsv(hue, 1.0, 1.0, 1.0)
		var start_delay: float = float(i) * stagger
		var t: Tween = create_tween().set_parallel(true)
		_active_tweens.append(t)
		# Fade in
		t.tween_property(wireframe, "modulate", Color(hue_color.r, hue_color.g, hue_color.b, 1.0), CASCADE_LETTER_LIFETIME * 0.5).set_delay(start_delay)
		# Fade out
		t.chain().tween_property(wireframe, "modulate", Color(hue_color.r, hue_color.g, hue_color.b, 0.0), CASCADE_LETTER_LIFETIME * 0.5)
	await get_tree().create_timer(CASCADE_DURATION).timeout


func _play_reveal_flash() -> void:
	# Show solid letters and remove black overlay UNDER the white flash so the
	# swap is hidden by the flash.
	var flash_in: Tween = create_tween()
	_active_tweens.append(flash_in)
	flash_in.tween_property(white_flash, "color:a", 1.0, REVEAL_FLASH_DURATION * 0.3)
	await flash_in.finished
	black.color.a = 0.0
	for container in logo_layer.get_children():
		var solid: Sprite2D = container.get_node("Solid")
		var wireframe: Sprite2D = container.get_node("Wireframe")
		solid.modulate = Color(1, 1, 1, 1)
		wireframe.modulate = Color(1, 1, 1, 0)
	var flash_out: Tween = create_tween()
	_active_tweens.append(flash_out)
	flash_out.tween_property(white_flash, "color:a", 0.0, REVEAL_FLASH_DURATION * 0.7)
	await flash_out.finished
```

Also keep the existing `_enter_attract_state()` from Task 5 — don't delete it, the sequence eventually calls it.

- [ ] **Step 2: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Manual verification**

We can't run the scene from `main.tscn` yet (Task 10 wires it in). Instead, set `title_screen.tscn` as the temporary main scene:
1. In Godot: Project → Project Settings → Application → Run → Main Scene → set to `title_screen.tscn`.
2. Add a temporary `_ready` line below `_capture_homes()` in `title_screen.gd`: `play()` (just for this manual test).
3. Press F5. Verify:
   - Screen starts black, wireframe letters cascade L→R with rainbow hues over ~1.5s.
   - White flash, then solid FROGBOG 99 visible over the title_no_text background.
   - The subheading sprites + "Press SPACE to play" all snap into place at the end (they'll be properly animated in later tasks).
4. Revert: remove the temporary `play()` line; reset Main Scene back to `main.tscn` (uid: `uid://c46nyqp4ij0rp`, or use the file picker).

- [ ] **Step 4: Commit**

```bash
git add title_screen.gd
git commit -m "feat: implement Title Sequence wireframe cascade and reveal flash"
```

---

## Task 7: Subheading Crash

**Files:**
- Modify: `title_screen.gd`

Implement the next beat: TAKE flies in from off-screen-left, PRISONERS! flies in from off-screen-right, both arrive at center simultaneously, white flash, NO appears between them, TAKE and PRISONERS! recoil outward then settle back to home.

- [ ] **Step 1: Implement the subheading crash and call it from the sequence**

In `title_screen.gd`, add these constants (alongside the existing CASCADE/REVEAL constants):

```gdscript
const SUBHEADING_FLY_IN_DURATION := 0.45
const SUBHEADING_FLY_IN_OFFSET_X := 1200.0
const SUBHEADING_CRASH_FLASH_DURATION := 0.18
const SUBHEADING_RECOIL_DISTANCE := 60.0
const SUBHEADING_RECOIL_DURATION := 0.12
const SUBHEADING_SETTLE_DURATION := 0.18
```

Add the function:

```gdscript
func _play_subheading_crash() -> void:
	# Position TAKE and PRISONERS! off-screen at their start positions.
	take.position = _subheading_homes["take"] + Vector2(-SUBHEADING_FLY_IN_OFFSET_X, 0)
	prisoners.position = _subheading_homes["prisoners"] + Vector2(SUBHEADING_FLY_IN_OFFSET_X, 0)
	take.modulate = Color(1, 1, 1, 1)
	prisoners.modulate = Color(1, 1, 1, 1)

	var fly_in: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tweens.append(fly_in)
	fly_in.tween_property(take, "position", _subheading_homes["take"], SUBHEADING_FLY_IN_DURATION)
	fly_in.tween_property(prisoners, "position", _subheading_homes["prisoners"], SUBHEADING_FLY_IN_DURATION)
	await fly_in.finished

	# Crash flash + NO reveal happen simultaneously.
	var flash: Tween = create_tween()
	_active_tweens.append(flash)
	flash.tween_property(white_flash, "color:a", 1.0, SUBHEADING_CRASH_FLASH_DURATION * 0.3)
	flash.tween_property(white_flash, "color:a", 0.0, SUBHEADING_CRASH_FLASH_DURATION * 0.7)
	no_word.modulate = Color(1, 1, 1, 1)

	# Recoil outward...
	var recoil: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tweens.append(recoil)
	recoil.tween_property(take, "position", _subheading_homes["take"] + Vector2(-SUBHEADING_RECOIL_DISTANCE, 0), SUBHEADING_RECOIL_DURATION)
	recoil.tween_property(prisoners, "position", _subheading_homes["prisoners"] + Vector2(SUBHEADING_RECOIL_DISTANCE, 0), SUBHEADING_RECOIL_DURATION)
	await recoil.finished

	# ...then settle back to home.
	var settle: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tweens.append(settle)
	settle.tween_property(take, "position", _subheading_homes["take"], SUBHEADING_SETTLE_DURATION)
	settle.tween_property(prisoners, "position", _subheading_homes["prisoners"], SUBHEADING_SETTLE_DURATION)
	await settle.finished
```

Update `_run_sequence()` to call it:

```gdscript
func _run_sequence() -> void:
	await _play_wireframe_cascade()
	await _play_reveal_flash()
	await _play_subheading_crash()
	# Letter ripple comes in Task 8.
	_enter_attract_state()
```

- [ ] **Step 2: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Manual verification**

Repeat the temporary-main-scene trick from Task 6 Step 3 (set `title_screen.tscn` as main, add `play()` to `_ready`, F5). Verify TAKE and PRISONERS! fly in, collide with a flash, NO pops in between them, TAKE/PRISONERS! recoil and settle. Then revert the project setting and the temporary `play()` line.

- [ ] **Step 4: Commit**

```bash
git add title_screen.gd
git commit -m "feat: implement Subheading Crash beat of the Title Sequence"
```

---

## Task 8: Letter Ripple

**Files:**
- Modify: `title_screen.gd`

Each FROGBOG 99 glyph bounces upward by a small visual offset, in left-to-right order, creating a wave. The bounce is render-only — we offset the container's `position.y`, not its `_letter_homes` value.

- [ ] **Step 1: Implement the letter ripple and call it from the sequence**

In `title_screen.gd`, add constants:

```gdscript
const RIPPLE_BOUNCE_HEIGHT := 40.0
const RIPPLE_BOUNCE_DURATION := 0.18
const RIPPLE_STAGGER := 0.07
```

Add the function:

```gdscript
func _play_letter_ripple() -> void:
	var letter_count: int = logo_layer.get_child_count()
	for i in range(letter_count):
		var container: Node2D = logo_layer.get_child(i) as Node2D
		var home: Vector2 = _letter_homes[i]
		var up_pos: Vector2 = home + Vector2(0, -RIPPLE_BOUNCE_HEIGHT)
		var t: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tweens.append(t)
		t.tween_interval(float(i) * RIPPLE_STAGGER)
		t.tween_property(container, "position", up_pos, RIPPLE_BOUNCE_DURATION * 0.5)
		t.tween_property(container, "position", home, RIPPLE_BOUNCE_DURATION * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Wait for the last letter's full bounce to complete.
	var total: float = float(letter_count - 1) * RIPPLE_STAGGER + RIPPLE_BOUNCE_DURATION
	await get_tree().create_timer(total).timeout
```

Update `_run_sequence()`:

```gdscript
func _run_sequence() -> void:
	await _play_wireframe_cascade()
	await _play_reveal_flash()
	await _play_subheading_crash()
	await _play_letter_ripple()
	_enter_attract_state()
```

- [ ] **Step 2: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Manual verification**

Temporary-main-scene + `play()` again. Verify the ripple plays after the subheading crash settles, and that letters return exactly to their original positions (no drift).

- [ ] **Step 4: Commit**

```bash
git add title_screen.gd
git commit -m "feat: implement Letter Ripple beat of the Title Sequence"
```

---

## Task 9: Attract State (fade in + blink "Press SPACE to play")

**Files:**
- Modify: `title_screen.gd`

After the ripple, the Title Screen enters the Attract State: "Press SPACE to play" fades in at the bottom and blinks in a loop until SPACE is pressed (the SPACE handler is already in `_unhandled_input` from Task 5).

- [ ] **Step 1: Replace `_enter_attract_state()` with a real implementation**

In `title_screen.gd`, add constants:

```gdscript
const PROMPT_FADE_IN_DURATION := 0.35
const PROMPT_BLINK_PERIOD := 1.0  # one full on/off cycle
const PROMPT_BLINK_MIN_ALPHA := 0.25
```

Add a member field at the top with the other vars:

```gdscript
var _blink_tween: Tween = null
```

Replace the existing `_enter_attract_state()` body with:

```gdscript
func _enter_attract_state() -> void:
	phase = Phase.ATTRACT
	# Snap to the final composition in case we got here via skip.
	black.color = Color(0, 0, 0, 0)
	white_flash.color = Color(1, 1, 1, 0)
	for container in logo_layer.get_children():
		var solid: Sprite2D = container.get_node("Solid")
		var wireframe: Sprite2D = container.get_node("Wireframe")
		solid.modulate = Color(1, 1, 1, 1)
		wireframe.modulate = Color(1, 1, 1, 0)
		(container as Node2D).position = _letter_homes[container.get_index()]
	take.modulate = Color(1, 1, 1, 1)
	no_word.modulate = Color(1, 1, 1, 1)
	prisoners.modulate = Color(1, 1, 1, 1)
	take.position = _subheading_homes["take"]
	prisoners.position = _subheading_homes["prisoners"]
	no_word.position = _subheading_homes["no"]

	press_to_play.modulate = Color(1, 1, 1, 0)
	var fade: Tween = create_tween()
	_active_tweens.append(fade)
	fade.tween_property(press_to_play, "modulate:a", 1.0, PROMPT_FADE_IN_DURATION)
	await fade.finished
	_start_blink()


func _start_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(press_to_play, "modulate:a", PROMPT_BLINK_MIN_ALPHA, PROMPT_BLINK_PERIOD * 0.5)
	_blink_tween.tween_property(press_to_play, "modulate:a", 1.0, PROMPT_BLINK_PERIOD * 0.5)


func _stop_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
		_blink_tween = null
```

Update `_unhandled_input` to stop the blink and hide the screen when start is requested:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("jump"):
		return
	if phase == Phase.SEQUENCE:
		_kill_active_tweens()
		_enter_attract_state()
		get_viewport().set_input_as_handled()
	elif phase == Phase.ATTRACT:
		phase = Phase.IDLE
		_stop_blink()
		_kill_active_tweens()
		visible = false
		start_requested.emit()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Manual verification**

Temporary-main-scene + `play()`. Verify the full Title Sequence runs end-to-end and "Press SPACE to play" fades in and blinks. Press SPACE during the cascade — verify it skips to the Attract State (final composition + blinking prompt). Press SPACE during the Attract State — verify the title screen hides.

- [ ] **Step 4: Revert any temporary changes from Tasks 6-9**

Make sure:
- `project.godot`'s Main Scene is back to `main.tscn` (uid `uid://c46nyqp4ij0rp`).
- There is no spurious `play()` call inside `_ready()` of `title_screen.gd`.

- [ ] **Step 5: Commit**

```bash
git add title_screen.gd
git commit -m "feat: implement Attract State with fade-in and blinking prompt"
```

---

## Task 10: Wire `TitleScreen`, `PreGameFade`, `Countdown` into `main.tscn`; remove `StartScreen`

**Files:**
- Modify: `main.tscn`

Replace the placeholder `StartScreen` CanvasLayer with the three new components. Leave `GameOverScreen` untouched.

- [ ] **Step 1: Open `main.tscn` in the Godot editor**

- [ ] **Step 2: Delete `StartScreen` and all its children**

In the scene tree, right-click `StartScreen` → Delete Node. (We're keeping the `GameOverScreen` for now.)

- [ ] **Step 3: Instance the three new scenes as siblings of `GameOverScreen`**

Use Scene → Instance Child Scene three times:

1. Instance `res://title_screen.tscn` — node name `TitleScreen`.
2. Instance `res://pre_game_fade.tscn` — node name `PreGameFade`.
3. Instance `res://countdown.tscn` — node name `Countdown`.

The order in the scene tree (which controls draw order for sibling CanvasLayers when their `layer` is equal — which it isn't here, but for clarity) should be: `TitleScreen`, `Countdown`, `PreGameFade`, `GameOverScreen`.

- [ ] **Step 4: Save `main.tscn`**

- [ ] **Step 5: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 6: Commit**

```bash
git add main.tscn
git commit -m "chore: replace StartScreen placeholder with TitleScreen + PreGameFade + Countdown"
```

---

## Task 11: Refactor `main.gd` state machine to drive the new flow

**Files:**
- Modify: `main.gd`

Replace `enum State { MENU, PLAYING, GAME_OVER }` with the five-state version, route through TitleScreen → PreGameFade → Countdown on launch, and through PreGameFade → Countdown on Restart.

- [ ] **Step 1: Replace the entire contents of `main.gd`**

Replace `main.gd` with:

```gdscript
extends Node2D

const GAME_DURATION := 60.0

enum State { TITLE, PRE_GAME, COUNTDOWN, PLAYING, GAME_OVER }

@onready var frog: CharacterBody2D = $Frog
@onready var score_ui: CanvasLayer = $ScoreUI
@onready var timer_label: Label = $HUD/TimerLabel
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var pre_game_fade: CanvasLayer = $PreGameFade
@onready var countdown: CanvasLayer = $Countdown
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var final_score_label: Label = $GameOverScreen/Center/VBox/FinalScoreLabel
@onready var restart_button: Button = $GameOverScreen/Center/VBox/RestartButton

var state: int = State.TITLE
var time_left: float = GAME_DURATION
var frog_spawn: Vector2 = Vector2.ZERO


func _ready() -> void:
	frog_spawn = frog.global_position
	restart_button.pressed.connect(_on_restart_pressed)
	title_screen.start_requested.connect(_on_title_start_requested)
	pre_game_fade.faded_to_black.connect(_on_fade_to_black)
	pre_game_fade.faded_in.connect(_on_fade_in)
	countdown.countdown_finished.connect(_on_countdown_finished)
	_enter_title()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_update_timer_label()
		_end_game()
		return
	_update_timer_label()


func _update_timer_label() -> void:
	timer_label.text = "Time: %d" % int(ceil(time_left))


func _enter_title() -> void:
	state = State.TITLE
	time_left = GAME_DURATION
	_update_timer_label()
	frog.global_position = frog_spawn
	frog.set_frozen(true)
	game_over_screen.visible = false
	get_tree().paused = true
	title_screen.play()


func _on_title_start_requested() -> void:
	_begin_pre_game()


func _on_restart_pressed() -> void:
	_begin_pre_game()


func _begin_pre_game() -> void:
	state = State.PRE_GAME
	game_over_screen.visible = false
	# Engine stays paused; PreGameFade has process_mode = ALWAYS so it animates anyway.
	get_tree().paused = true
	pre_game_fade.play()


func _on_fade_to_black() -> void:
	# At full black, reset the world for a fresh run.
	_clear_flies()
	frog.global_position = frog_spawn
	frog.velocity = Vector2.ZERO
	frog.set_frozen(true)
	time_left = GAME_DURATION
	_update_timer_label()
	# Hide the title screen if it's still visible (e.g. first run).
	title_screen.visible = false


func _on_fade_in() -> void:
	# Black has just faded out; start the countdown.
	state = State.COUNTDOWN
	get_tree().paused = false  # Flies must spawn during the countdown.
	countdown.play()


func _on_countdown_finished() -> void:
	state = State.PLAYING
	frog.set_frozen(false)
	GameEvents.game_started.emit()


func _end_game() -> void:
	state = State.GAME_OVER
	frog.set_frozen(true)
	get_tree().paused = true
	var final: int = score_ui.get_score()
	final_score_label.text = "Final Score: %d" % final
	game_over_screen.visible = true
	GameEvents.game_ended.emit(final)


func _clear_flies() -> void:
	for fly in get_tree().get_nodes_in_group("flies"):
		fly.queue_free()
```

- [ ] **Step 2: Parse-check**

```bash
Godot --headless --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|Compile Error)" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 3: Manual verification — full flow**

Press F5. Verify:
1. Title Screen plays the full Title Sequence (cascade → flash → reveal → subheading crash → letter ripple) and lands in the Attract State.
2. Press SPACE → Title Screen hides → screen fades to black → fades back in to the game scene.
3. During fade-in, Flies are already spawning, but the Frog is frozen at spawn (no input response).
4. Countdown shows 3 → 2 → 1 → Start! at the center.
5. "Start!" fades out as the Frog becomes controllable; the timer begins counting down from 60.
6. Play normally — catch a fly, fall off, etc.
7. Let the timer hit 0 → Game Over → click Restart.
8. Restart: screen fades to black → Title Screen does NOT replay → fades in to game scene → Countdown plays again → game starts.
9. Press SPACE during the Title Sequence on first launch (relaunch the game from F5) → cascade is interrupted, Attract State appears immediately, prompt blinks. Pressing SPACE again continues normally into Pre-Game Fade.

If the Restart flow shows a flicker of the Game Over screen during the fade, fix it by hiding `game_over_screen` in `_begin_pre_game` (already done) — confirm it works.

- [ ] **Step 4: Commit**

```bash
git add main.gd
git commit -m "feat: route Main through TITLE/PRE_GAME/COUNTDOWN/PLAYING/GAME_OVER"
```

---

## Task 12: Final integration sweep

**Files:**
- None (verification only)

A read-through pass to confirm we didn't leave any rough edges.

- [ ] **Step 1: Re-run the full flow from Task 11 Step 3**

End-to-end: launch → title → start → countdown → play → game over → restart → countdown → play. No regressions.

- [ ] **Step 2: Confirm no leftover references to `StartScreen` or `start_button`**

Run:
```bash
grep -rn "StartScreen\|start_button" /Users/nicholasmejia/godot/frog-bog --include="*.gd" --include="*.tscn"
```
Expected: no matches (the StartScreen placeholder is fully gone).

- [ ] **Step 3: Confirm `art/title_no_text.png` is now imported (Godot generates a `.import` sidecar on first scene load)**

Run:
```bash
ls /Users/nicholasmejia/godot/frog-bog/art/title_no_text.png /Users/nicholasmejia/godot/frog-bog/art/title_no_text.png.import 2>&1
```
Expected: both files present. If the `.import` file is missing, open the project in Godot once (it auto-imports on load) and commit the `.import` file.

- [ ] **Step 4: Confirm all new assets have `.import` sidecars**

Run:
```bash
ls /Users/nicholasmejia/godot/frog-bog/art/title_text/*.import 2>&1 | wc -l
```
Expected: 15 (one `.import` per PNG in `title_text/`).

- [ ] **Step 5: Stage and commit any newly generated `.import` / `.uid` files from the editor**

Run:
```bash
git status
```
If there are new `.import` or `.uid` files that the editor produced for the new scenes/textures, stage and commit them:

```bash
git add art/title_text/*.import art/title_no_text.png.import
git add *.uid
git commit -m "chore: track Godot import sidecars for title screen assets"
```

- [ ] **Step 6: Final commit-of-record (no-op if everything is already clean)**

If nothing remains to commit, skip. Otherwise:
```bash
git status
```
And resolve as needed.

---

## Self-review checklist (already applied during authoring)

- Spec coverage: every beat from the user's spec (black start, wireframe cascade with rainbow, white flash → reveal, subheading crash with NO appearing on impact, letter ripple, blinking prompt) is covered by a task.
- Plus the additions from grilling: Pre-Game Fade and Game Start Countdown (Tasks 2, 3, 11), Restart re-runs fade + countdown but skips title (Task 11).
- No placeholders, no "implement later" markers — every step contains the actual code or precise editor steps.
- Type/name consistency: `start_requested`, `faded_to_black`, `faded_in`, `countdown_finished`, `set_frozen`, `frozen`, `_letter_homes`, `_subheading_homes` are spelled identically wherever they appear.
- Audio is explicitly out of scope per the user's confirmation.
- Position values for letter sprites are intentionally left "tune to match `title_card.png`" because Task 4 hands that to the human in the editor (per the Option-2 decision from the grill).
