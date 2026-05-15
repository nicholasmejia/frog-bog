extends AnimatableBody2D

const SPRING_K_Y := 320.0
const DAMP_Y := 9.0
const SPRING_K_X := 14.0
const DAMP_X := 7.5

const CHARGE_IMPULSE_Y := 55.0
const JUMP_IMPULSE_Y := 220.0
const LAND_IMPULSE_Y := 260.0
const JUMP_IMPULSE_X := 40.0
const LAND_IMPULSE_X := 50.0

var rest_position: Vector2
var offset_x: float = 0.0
var offset_y: float = 0.0
var vel_x: float = 0.0
var vel_y: float = 0.0


func _ready() -> void:
	rest_position = position
	GameEvents.platform_charge.connect(_on_charge)
	GameEvents.platform_jump.connect(_on_jump)
	GameEvents.platform_land.connect(_on_land)
	GameEvents.game_started.connect(_reset)


func _reset() -> void:
	offset_x = 0.0
	offset_y = 0.0
	vel_x = 0.0
	vel_y = 0.0
	position = rest_position
	GameEvents.platform_offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	vel_y += (-SPRING_K_Y * offset_y - DAMP_Y * vel_y) * delta
	offset_y += vel_y * delta
	vel_x += (-SPRING_K_X * offset_x - DAMP_X * vel_x) * delta
	offset_x += vel_x * delta
	position = rest_position + Vector2(offset_x, offset_y)
	GameEvents.platform_offset = Vector2(offset_x, offset_y)


func _on_charge() -> void:
	vel_y += CHARGE_IMPULSE_Y


func _on_jump(dir_x: float) -> void:
	vel_y += JUMP_IMPULSE_Y
	vel_x -= dir_x * JUMP_IMPULSE_X


func _on_land(dir_x: float) -> void:
	vel_y += LAND_IMPULSE_Y
	vel_x += dir_x * LAND_IMPULSE_X
