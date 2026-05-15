extends CanvasLayer

const BASE_POINTS := 10
const FALL_PENALTY := 30

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var multiplier_label: Label = $MarginContainer/VBoxContainer/MultiplierLabel

var score: int = 0
var multiplier: int = 1


func _ready() -> void:
	GameEvents.fly_caught.connect(_on_fly_caught)
	GameEvents.frog_landed.connect(_on_frog_landed)
	GameEvents.frog_fell.connect(_on_frog_fell)
	GameEvents.game_started.connect(_on_game_started)
	_refresh()


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
