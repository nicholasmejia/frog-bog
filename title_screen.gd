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


const CASCADE_DURATION := 1.5
const CASCADE_LETTER_LIFETIME := 0.55  # each wireframe letter visible for this long
const REVEAL_FLASH_DURATION := 0.25
const SUBHEADING_FLY_IN_DURATION := 0.45
const SUBHEADING_FLY_IN_OFFSET_X := 1200.0
const SUBHEADING_CRASH_FLASH_DURATION := 0.18
const SUBHEADING_RECOIL_DISTANCE := 60.0
const SUBHEADING_RECOIL_DURATION := 0.12
const SUBHEADING_SETTLE_DURATION := 0.18


func _run_sequence() -> void:
	await _play_wireframe_cascade()
	await _play_reveal_flash()
	await _play_subheading_crash()
	# Letter ripple comes in Task 8.
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
