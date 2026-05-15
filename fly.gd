extends Area2D

@export var speed: float = 180.0
@export var direction: Vector2 = Vector2.RIGHT
@export var bob_amplitude: float = 18.0
@export var bob_frequency: float = 3.0
@export var is_special: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var bob_phase: float = randf() * TAU
var base_y: float = 0.0
var pulse_phase: float = 0.0
var sparkles: CPUParticles2D


func _ready() -> void:
	add_to_group("flies")
	base_y = global_position.y
	area_entered.connect(_on_area_entered)
	_update_facing()
	if is_special:
		_setup_special_visuals()


func _setup_special_visuals() -> void:
	sparkles = CPUParticles2D.new()
	sparkles.amount = 18
	sparkles.lifetime = 0.6
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 26.0
	sparkles.direction = Vector2.ZERO
	sparkles.spread = 180.0
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 15.0
	sparkles.initial_velocity_max = 50.0
	sparkles.scale_amount_min = 2.0
	sparkles.scale_amount_max = 5.0
	sparkles.color = GameEvents.SPECIAL_COLOR
	sparkles.z_index = -1
	add_child(sparkles)
	sparkles.emitting = true


func _process(delta: float) -> void:
	var tf: float = GameEvents.time_factor
	bob_phase += bob_frequency * delta * tf
	var step: Vector2 = direction.normalized() * speed * tf * delta
	global_position.x += step.x
	base_y += step.y
	global_position.y = base_y + sin(bob_phase) * bob_amplitude

	if is_special:
		pulse_phase += delta * 9.0
		var t: float = (sin(pulse_phase) + 1.0) * 0.5
		sprite.modulate = Color(1.0, 1.0, 1.0).lerp(GameEvents.SPECIAL_COLOR, t)

	var vp_x: float = get_viewport_rect().size.x
	if global_position.x < -200.0 or global_position.x > vp_x + 200.0:
		queue_free()


func _update_facing() -> void:
	sprite.flip_h = direction.x > 0.0
	sprite.play("default" if sprite.sprite_frames.has_animation("default") else sprite.sprite_frames.get_animation_names()[0])


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("tongue_tip"):
		queue_free()
