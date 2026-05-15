extends Node

# Bullet-time ability component.
# Parent must be the Frog (CharacterBody2D) with an `AnimatedSprite2D` child named
# `AnimatedSprite2D`. Listens to GameEvents for special fly catches and game restarts;
# writes GameEvents.time_factor each physics frame for the world slow-down effect.

const DURATION := 3.0
const L3_DURATION := 5.0
const TARGET_FACTOR := 0.12
const LERP_RATE := 14.0
const PULSE_SPEED := 7.0

@onready var sprite: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")
var sparkles: CPUParticles2D

var has_charge: bool = false
var remaining: float = 0.0
var pulse_phase: float = 0.0


func _effective_duration() -> float:
	return L3_DURATION if GameEvents.frog_level >= GameEvents.MAX_LEVEL else DURATION


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
	remaining = _effective_duration()
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)


func _on_special_fly_caught() -> void:
	if has_charge:
		return
	has_charge = true
	sparkles.emitting = true


func _on_game_started() -> void:
	has_charge = false
	remaining = 0.0
	pulse_phase = 0.0
	GameEvents.time_factor = 1.0
	sparkles.emitting = false
	sprite.modulate = Color(1, 1, 1, 1)
