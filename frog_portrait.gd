extends CanvasLayer

# Frog Portrait HUD.
# Displays one of seven state portraits (Idle, Charging, Jumping, BulletTime,
# LevelUp, Hurt, EatFinished) over a static Frame. Each portrait is its own
# TextureRect child of Anchor — independently positioned and sized in the editor.
# Texture selection follows a base-state + single-override model: base = continuous
# game state, override = timed reaction (LevelUp/Hurt 2s, EatFinished 1s). New
# overrides replace old. When the override timer expires, the base state resumes.
# Game-over is itself a base state (highest priority) that pins EatFinished until
# restart.

enum PortraitState { IDLE, CHARGING, JUMPING, BULLET_TIME, LEVEL_UP, HURT, EAT_FINISHED }

const OVERRIDE_DURATION := 2.0
const EAT_FINISHED_DURATION := 1.0

@onready var _portraits: Dictionary = {
	PortraitState.IDLE:         $Anchor/Idle,
	PortraitState.CHARGING:     $Anchor/Charging,
	PortraitState.JUMPING:      $Anchor/Jumping,
	PortraitState.BULLET_TIME:  $Anchor/BulletTime,
	PortraitState.LEVEL_UP:     $Anchor/LevelUp,
	PortraitState.HURT:         $Anchor/Hurt,
	PortraitState.EAT_FINISHED: $Anchor/EatFinished,
}

var _override_state: int = -1
var _override_remaining: float = 0.0
var _game_over: bool = false
var _current_applied: int = -1
var _levelup_pending: bool = false


func _ready() -> void:
	GameEvents.tongue_returned.connect(_on_tongue_returned)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.game_ended.connect(_on_game_ended)
	_apply_state(PortraitState.IDLE)


func _process(delta: float) -> void:
	if _override_remaining > 0.0:
		_override_remaining -= delta
		if _override_remaining <= 0.0:
			_override_remaining = 0.0
			_override_state = -1
	var desired: int = _compute_desired_state()
	if desired != _current_applied:
		_apply_state(desired)


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


func _apply_state(state: int) -> void:
	_current_applied = state
	for s in _portraits:
		_portraits[s].visible = (s == state)


func _trigger_override(state: int, duration: float = OVERRIDE_DURATION) -> void:
	_override_state = state
	_override_remaining = duration


func _on_level_changed(new_level: int) -> void:
	if new_level <= 0:
		_levelup_pending = false
		return
	_levelup_pending = true
	_trigger_override(PortraitState.LEVEL_UP)


func _on_frog_fell() -> void:
	_levelup_pending = false
	_trigger_override(PortraitState.HURT)


func _on_tongue_returned(caught_fly: bool) -> void:
	var was_levelup: bool = _levelup_pending
	_levelup_pending = false
	if not caught_fly:
		return
	if was_levelup:
		return
	_trigger_override(PortraitState.EAT_FINISHED, EAT_FINISHED_DURATION)


func _on_game_started() -> void:
	reset_for_new_run()


func reset_for_new_run() -> void:
	_game_over = false
	_override_state = -1
	_override_remaining = 0.0
	_levelup_pending = false
	_apply_state(PortraitState.IDLE)


func _on_game_ended(_final_score: int) -> void:
	_game_over = true
