extends CharacterBody2D

const MIN_CHARGE := 0.1
const MAX_CHARGE := 1.2
const MIN_JUMP_VY := -200.0
const MAX_JUMP_VY := -950.0
const MIN_JUMP_VX := 150.0
const MAX_JUMP_VX := 500.0
const SHAKE_MIN_AMPLITUDE := 1.5
const SHAKE_MAX_AMPLITUDE := 5.0
const SHAKE_MIN_FREQ := 18.0
const SHAKE_MAX_FREQ := 55.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var tongue_origin: Marker2D = $TongueOrigin
@onready var tongue: Node2D = $TongueOrigin/Tongue
@onready var shadow: Node2D = $Shadow
@onready var dust: CPUParticles2D = $DustParticles
@onready var land_dust_left: CPUParticles2D = $LandDustLeft
@onready var land_dust_right: CPUParticles2D = $LandDustRight

const LAND_DUST_HAND_OFFSET := 55.0

const MOUTH_OFFSETS := {
	"idle": Vector2(40, 10),
	"jump": Vector2(60, -10),
	"charging": Vector2(35, 5),
	"aim_side": Vector2(-40, -20),
	"aim_down": Vector2(-20, 60),
	"aim_up": Vector2(-10, -70),
	"aim_down_angle": Vector2(-50, 50),
	"aim_up_angle": Vector2(-20, -20),
}

const ANIM_SCALES := {
	"idle": Vector2(1.0, 1.0),
	"jump": Vector2(1.0, 1.0),
	"charging": Vector2(0.48, 0.48),
}

const ANIM_POSITIONS := {
	"charging": Vector2(0, 30),
}

var facing_right := true
var charging := false
var charge_time := 0.0
var was_on_floor := true
var shake_phase := 0.0
var spawn_position := Vector2.ZERO
var mouse_at_takeoff := Vector2.ZERO
var mouse_moved_in_air := false
var in_jump_cycle: bool = false

const RESPAWN_MARGIN := 200.0


func _ready() -> void:
	spawn_position = global_position
	sprite.flip_h = not facing_right
	sprite.animation_changed.connect(_apply_anim_scale)
	sprite.play("idle")
	_apply_anim_scale()
	tongue.hit_fly.connect(_on_tongue_hit_fly)
	GameEvents.game_started.connect(_on_game_started)


func _on_tongue_hit_fly(fly) -> void:
	if fly != null and "is_special" in fly and fly.is_special:
		GameEvents.special_fly_caught.emit()
		return
	GameEvents.fly_caught.emit(not is_on_floor())


func _on_game_started() -> void:
	_reset_frog_state()


func _reset_frog_state() -> void:
	velocity = Vector2.ZERO
	charging = false
	charge_time = 0.0
	shake_phase = 0.0
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color(1, 1, 1, 1)
	facing_right = true
	sprite.flip_h = not facing_right
	sprite.play("idle")
	was_on_floor = true
	in_jump_cycle = false


func _emit_dust() -> void:
	dust.global_position = Vector2(global_position.x, shadow.anchor_y + GameEvents.platform_offset.y)
	dust.restart()
	dust.emitting = true


func _emit_landing_dust() -> void:
	var py: float = shadow.anchor_y + GameEvents.platform_offset.y
	land_dust_left.global_position = Vector2(global_position.x - LAND_DUST_HAND_OFFSET, py)
	land_dust_right.global_position = Vector2(global_position.x + LAND_DUST_HAND_OFFSET, py)
	land_dust_left.restart()
	land_dust_right.restart()
	land_dust_left.emitting = true
	land_dust_right.emitting = true


func _update_tongue_origin() -> void:
	var offset: Vector2 = MOUTH_OFFSETS.get(sprite.animation, Vector2.ZERO)
	if sprite.flip_h:
		offset.x = -offset.x
	tongue_origin.position = offset


func _apply_anim_scale() -> void:
	var s: Vector2 = ANIM_SCALES.get(sprite.animation, Vector2.ONE)
	sprite.scale = s
	sprite.position = ANIM_POSITIONS.get(sprite.animation, Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if (Input.is_action_just_pressed("shoot_tongue")
			and not is_on_floor()
			and not tongue.is_busy()):
		var aim: Vector2 = get_global_mouse_position() - tongue.global_position
		tongue.fire(aim)

	var in_air: bool = not is_on_floor()
	var tf: float = GameEvents.time_factor if in_air else 1.0

	if in_air:
		velocity += get_gravity() * delta * tf

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			charging = true
			charge_time = 0.0
			sprite.play("charging")
			GameEvents.platform_charge.emit()
		if charging:
			charge_time = min(charge_time + delta, MAX_CHARGE)
			_update_shake(delta)
		if charging and Input.is_action_just_released("jump"):
			_launch()

		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)

	if in_air and tf < 0.999:
		velocity *= tf
		move_and_slide()
		if tf > 0.001:
			velocity /= tf
	else:
		move_and_slide()
	_check_out_of_bounds()
	_update_tongue_origin()

	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor:
		if in_jump_cycle:
			in_jump_cycle = false
			tongue.cancel()
			var land_dir: float = signf(velocity.x)
			facing_right = not facing_right
			sprite.flip_h = not facing_right
			sprite.play("idle")
			_emit_landing_dust()
			GameEvents.frog_landed.emit()
			GameEvents.platform_land.emit(land_dir)
		else:
			sprite.play("idle")
	elif not on_floor_now and was_on_floor:
		if in_jump_cycle:
			mouse_at_takeoff = get_global_mouse_position()
			mouse_moved_in_air = false
			sprite.play("jump")
			sprite.flip_h = not facing_right
			_emit_dust()
			GameEvents.platform_jump.emit(1.0 if facing_right else -1.0)
	elif not on_floor_now and in_jump_cycle:
		_update_air_aim()
	was_on_floor = on_floor_now


func _update_air_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	if not mouse_moved_in_air:
		if mouse_pos.distance_squared_to(mouse_at_takeoff) < 4.0:
			return
		mouse_moved_in_air = true
	var to_mouse: Vector2 = mouse_pos - global_position
	if to_mouse.length_squared() < 1.0:
		return
	var deg: float = rad_to_deg(to_mouse.angle())
	var abs_deg: float = absf(deg)
	var anim: String
	var face_right: bool
	if abs_deg < 22.5:
		anim = "aim_side"
		face_right = true
	elif abs_deg > 157.5:
		anim = "aim_side"
		face_right = false
	elif deg >= 67.5 and deg <= 112.5:
		anim = "aim_down"
		face_right = false
	elif deg <= -67.5 and deg >= -112.5:
		anim = "aim_up"
		face_right = false
	elif deg > 22.5 and deg < 67.5:
		anim = "aim_down_angle"
		face_right = true
	elif deg > 112.5:
		anim = "aim_down_angle"
		face_right = false
	elif deg < -22.5 and deg > -67.5:
		anim = "aim_up_angle"
		face_right = true
	else:
		anim = "aim_up_angle"
		face_right = false

	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = face_right


func _check_out_of_bounds() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if (global_position.y > vp.y + RESPAWN_MARGIN
			or global_position.x < -RESPAWN_MARGIN
			or global_position.x > vp.x + RESPAWN_MARGIN):
		GameEvents.frog_fell.emit()
		_respawn()


func _respawn() -> void:
	global_position = spawn_position
	_reset_frog_state()


func _update_shake(delta: float) -> void:
	var ratio: float = clampf(charge_time / MAX_CHARGE, 0.0, 1.0)
	var freq: float = lerpf(SHAKE_MIN_FREQ, SHAKE_MAX_FREQ, ratio)
	var amp: float = lerpf(SHAKE_MIN_AMPLITUDE, SHAKE_MAX_AMPLITUDE, ratio)
	shake_phase += freq * delta
	sprite.offset = Vector2(
		sin(shake_phase * TAU) * amp,
		cos(shake_phase * TAU * 0.9) * amp * 0.5,
	)


func _launch() -> void:
	charging = false
	shake_phase = 0.0
	sprite.offset = Vector2.ZERO
	var t: float = clampf(charge_time, MIN_CHARGE, MAX_CHARGE)
	var ratio: float = (t - MIN_CHARGE) / (MAX_CHARGE - MIN_CHARGE)
	var vy: float = lerpf(MIN_JUMP_VY, MAX_JUMP_VY, ratio)
	var vx: float = lerpf(MIN_JUMP_VX, MAX_JUMP_VX, ratio)
	velocity.x = vx if facing_right else -vx
	velocity.y = vy
	charge_time = 0.0
	in_jump_cycle = true
