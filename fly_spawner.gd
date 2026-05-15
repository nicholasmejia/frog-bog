extends Node2D

@export var fly_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var spawn_interval_jitter: float = 0.5
@export var min_speed: float = 120.0
@export var max_speed: float = 280.0
@export var spawn_y_min: float = 150.0
@export var spawn_y_max: float = 550.0
@export var off_screen_margin: float = 120.0
@export var auto_start: bool = true
@export var special_chance: float = 0.10

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	if auto_start:
		_schedule_next()


func _schedule_next() -> void:
	var jitter: float = randf_range(-spawn_interval_jitter, spawn_interval_jitter)
	timer.start(maxf(0.1, spawn_interval + jitter))


func _on_timer_timeout() -> void:
	_spawn_fly()
	_schedule_next()


func _spawn_fly() -> void:
	if fly_scene == null:
		return
	var fly := fly_scene.instantiate()
	var vp_x: float = get_viewport().get_visible_rect().size.x
	var from_left: bool = randf() < 0.5
	var spawn_x: float = -off_screen_margin if from_left else vp_x + off_screen_margin
	var spawn_y: float = randf_range(spawn_y_min, spawn_y_max)
	fly.position = Vector2(spawn_x, spawn_y)
	fly.direction = Vector2.RIGHT if from_left else Vector2.LEFT
	fly.speed = randf_range(min_speed, max_speed)
	fly.is_special = randf() < special_chance
	get_parent().add_child(fly)
