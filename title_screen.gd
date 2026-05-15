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
