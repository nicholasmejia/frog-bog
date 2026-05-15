extends Node

const LEVEL_UP_COLOR := Color(0.55, 0.95, 1.0, 1.0)

# Level System component.
# Owns the Frog Level (0..MAX_LEVEL) and Level Progress (0..FLIES_PER_LEVEL-1).
# Subscribes to GameEvents.fly_caught / frog_fell / game_started.
# Publishes GameEvents.frog_level and GameEvents.level_progress as shared state,
# plus level_changed and level_progress_changed signals for UI/feedback consumers.

var sparkles: CPUParticles2D


func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	_setup_sparkles()
	_reset(true)


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


func _on_frog_fell() -> void:
	_reset(false)


func _on_game_started() -> void:
	_reset(false)


func _reset(silent: bool) -> void:
	var had_level: bool = GameEvents.frog_level != 0
	var had_progress: bool = GameEvents.level_progress != 0
	GameEvents.frog_level = 0
	GameEvents.level_progress = 0
	if silent:
		return
	if had_progress:
		GameEvents.level_progress_changed.emit(0)
	if had_level:
		GameEvents.level_changed.emit(0)


func _emit_level_up_burst() -> void:
	if sparkles == null:
		return
	sparkles.global_position = get_parent().global_position
	sparkles.restart()
	sparkles.emitting = true
