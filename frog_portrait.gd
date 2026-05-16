extends CanvasLayer

# Frog Portrait HUD.
# Displays one of seven state portraits (Idle, Charging, Jumping, BulletTime,
# LevelUp, Hurt, EatFinished) over a static Frame. Texture selection follows a
# base-state + single-override model: base = continuous game state, override =
# 2-second timed reaction. New overrides replace old. When the override timer
# expires, the base state resumes. Game-over is itself a base state (highest
# priority) that pins EatFinished until restart.

enum PortraitState { IDLE, CHARGING, JUMPING, BULLET_TIME, LEVEL_UP, HURT, EAT_FINISHED }

const OVERRIDE_DURATION := 2.0
const OFFSET_TWEEN_TIME := 0.08

const PORTRAIT_CONFIG := {
	PortraitState.IDLE:         { "texture": preload("res://art/clean_portraits/Idle.png"),        "offset": Vector2.ZERO },
	PortraitState.CHARGING:     { "texture": preload("res://art/clean_portraits/Charging.png"),    "offset": Vector2.ZERO },
	PortraitState.JUMPING:      { "texture": preload("res://art/clean_portraits/Jumping.png"),     "offset": Vector2.ZERO },
	PortraitState.BULLET_TIME:  { "texture": preload("res://art/clean_portraits/BulletTime.png"),  "offset": Vector2.ZERO },
	PortraitState.LEVEL_UP:     { "texture": preload("res://art/clean_portraits/LevelUp.png"),     "offset": Vector2.ZERO },
	PortraitState.HURT:         { "texture": preload("res://art/clean_portraits/Hurt.png"),        "offset": Vector2.ZERO },
	PortraitState.EAT_FINISHED: { "texture": preload("res://art/clean_portraits/EatFinished.png"), "offset": Vector2.ZERO },
}

@onready var sprite: TextureRect = $Anchor/Sprite

var _override_state: int = -1
var _override_remaining: float = 0.0
var _game_over: bool = false
var _current_applied: int = -1
var _offset_tween: Tween = null


func _ready() -> void:
	GameEvents.tongue_returned.connect(_on_tongue_returned)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.game_ended.connect(_on_game_ended)
	_apply_state(PortraitState.IDLE, true)


func _process(delta: float) -> void:
	if _override_remaining > 0.0:
		_override_remaining -= delta
		if _override_remaining <= 0.0:
			_override_remaining = 0.0
			_override_state = -1
	var desired: int = _compute_desired_state()
	if desired != _current_applied:
		_apply_state(desired, false)


func _compute_desired_state() -> int:
	if _override_state != -1:
		return _override_state
	if _game_over:
		return PortraitState.EAT_FINISHED
	if GameEvents.bullet_time_active:
		return PortraitState.BULLET_TIME
	if GameEvents.is_charging:
		return PortraitState.CHARGING
	if GameEvents.is_jumping:
		return PortraitState.JUMPING
	return PortraitState.IDLE


func _apply_state(state: int, instant: bool) -> void:
	_current_applied = state
	var cfg: Dictionary = PORTRAIT_CONFIG[state]
	sprite.texture = cfg["texture"]
	var target_offset: Vector2 = cfg["offset"]
	if _offset_tween != null and _offset_tween.is_valid():
		_offset_tween.kill()
	if instant or target_offset == sprite.position:
		sprite.position = target_offset
		return
	_offset_tween = create_tween()
	_offset_tween.tween_property(sprite, "position", target_offset, OFFSET_TWEEN_TIME)


func _trigger_override(state: int) -> void:
	_override_state = state
	_override_remaining = OVERRIDE_DURATION


func _on_level_changed(new_level: int) -> void:
	if new_level <= 0:
		return
	_trigger_override(PortraitState.LEVEL_UP)


func _on_frog_fell() -> void:
	_trigger_override(PortraitState.HURT)


func _on_tongue_returned(caught_fly: bool) -> void:
	if not caught_fly:
		return
	_trigger_override(PortraitState.EAT_FINISHED)


func _on_game_started() -> void:
	_game_over = false
	_override_state = -1
	_override_remaining = 0.0
	_apply_state(PortraitState.IDLE, true)


func _on_game_ended(_final_score: int) -> void:
	_game_over = true
