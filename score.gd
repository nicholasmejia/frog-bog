extends CanvasLayer

const BASE_POINTS := 10
const FALL_PENALTY := 30

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var multiplier_label: Label = $MarginContainer/VBoxContainer/MultiplierLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel

var score: int = 0
var multiplier: int = 1


func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_landed.connect(_on_frog_landed)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.level_changed.connect(_on_level_changed)
	GameEvents.level_progress_changed.connect(_on_level_progress_changed)
	_refresh()
	_refresh_level()


func get_score() -> int:
	return score


func _on_game_started() -> void:
	score = 0
	multiplier = 1
	_refresh()


func _on_frog_fell() -> void:
	score -= FALL_PENALTY
	multiplier = 1
	_refresh()


func _on_fly_caught(in_air: bool) -> void:
	if in_air:
		score += BASE_POINTS * multiplier
		multiplier += 1
	else:
		score += BASE_POINTS
	_refresh()


func _on_frog_landed() -> void:
	multiplier = 1
	_refresh()


func _refresh() -> void:
	score_label.text = "Score: %d" % score
	if multiplier > 1:
		multiplier_label.text = "x%d" % multiplier
		multiplier_label.visible = true
	else:
		multiplier_label.visible = false


func _on_level_changed(_new_level: int) -> void:
	_refresh_level()


func _on_level_progress_changed(_progress: int) -> void:
	_refresh_level()


func _refresh_level() -> void:
	var lvl: int = GameEvents.frog_level
	if lvl >= GameEvents.MAX_LEVEL:
		level_label.text = "Level: %d (MAX)" % lvl
	elif lvl == 0:
		level_label.text = "Level: 0"  # suppress (0/3) at default state; progress shown mid-climb only
	else:
		level_label.text = "Level: %d (%d/%d)" % [lvl, GameEvents.level_progress, GameEvents.FLIES_PER_LEVEL]
