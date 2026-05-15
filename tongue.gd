extends Node2D

signal hit_fly(fly)

@onready var line: Line2D = $Line2D
@onready var tip: Sprite2D = $Tip
@onready var tip_hitbox: Area2D = $TipHitbox

const MAX_LENGTH := 320.0
const EXTEND_SPEED := 1800.0
const RETRACT_SPEED := 2400.0

var direction := Vector2.RIGHT
var current_length := 0.0
var is_firing := false
var is_retracting := false


func _ready() -> void:
	visible = false
	line.points = [Vector2.ZERO, Vector2.ZERO]
	tip_hitbox.monitoring = false
	tip_hitbox.monitorable = false
	tip_hitbox.add_to_group("tongue_tip")
	tip_hitbox.area_entered.connect(_on_tip_hitbox_area_entered)


func is_busy() -> bool:
	return is_firing or is_retracting


func cancel() -> void:
	is_firing = false
	is_retracting = false
	current_length = 0.0
	visible = false
	tip_hitbox.monitoring = false
	tip_hitbox.monitorable = false
	_update_tongue()


func fire(aim_direction: Vector2) -> void:
	if aim_direction.length_squared() < 0.001:
		return
	direction = aim_direction.normalized()
	current_length = 0.0
	is_firing = true
	is_retracting = false
	visible = true
	tip_hitbox.monitoring = true
	tip_hitbox.monitorable = true
	_update_tongue()


func _process(delta: float) -> void:
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
			current_length = 0.0
			is_retracting = false
			visible = false
			tip_hitbox.monitoring = false
			tip_hitbox.monitorable = false
		_update_tongue()


func _update_tongue() -> void:
	var end_pos := direction * current_length
	line.points = [Vector2.ZERO, end_pos]
	tip.position = end_pos
	tip_hitbox.position = end_pos
	tip.rotation = direction.angle()


func _on_tip_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("flies"):
		hit_fly.emit(area)
		is_firing = false
		is_retracting = true
