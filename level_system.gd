extends Node

# Level System component.
# Owns the Frog Level (0..MAX_LEVEL) and Level Progress (0..FLIES_PER_LEVEL-1).
# Subscribes to GameEvents.fly_caught / frog_fell / game_started.
# Publishes GameEvents.frog_level and GameEvents.level_progress as shared state,
# plus level_changed and level_progress_changed signals for UI/feedback consumers.


func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	_reset(true)


func _on_fly_caught(_in_air: bool) -> void:
	if GameEvents.frog_level >= GameEvents.MAX_LEVEL:
		return
	var next_progress: int = GameEvents.level_progress + 1
	if next_progress >= GameEvents.FLIES_PER_LEVEL:
		GameEvents.frog_level += 1
		GameEvents.level_progress = 0
		GameEvents.level_progress_changed.emit(0)
		GameEvents.level_changed.emit(GameEvents.frog_level)
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
