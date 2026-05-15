extends Node2D

const GAME_DURATION := 60.0

enum State { MENU, PLAYING, GAME_OVER }

@onready var frog: CharacterBody2D = $Frog
@onready var score_ui: CanvasLayer = $ScoreUI
@onready var timer_label: Label = $HUD/TimerLabel
@onready var start_screen: CanvasLayer = $StartScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var final_score_label: Label = $GameOverScreen/Center/VBox/FinalScoreLabel
@onready var start_button: Button = $StartScreen/Center/VBox/StartButton
@onready var restart_button: Button = $GameOverScreen/Center/VBox/RestartButton

var state: int = State.MENU
var time_left: float = GAME_DURATION
var frog_spawn: Vector2 = Vector2.ZERO


func _ready() -> void:
	frog_spawn = frog.global_position
	start_button.pressed.connect(_begin_game)
	restart_button.pressed.connect(_begin_game)
	_enter_menu()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_update_timer_label()
		_end_game()
		return
	_update_timer_label()


func _update_timer_label() -> void:
	timer_label.text = "Time: %d" % int(ceil(time_left))


func _enter_menu() -> void:
	state = State.MENU
	time_left = GAME_DURATION
	_update_timer_label()
	start_screen.visible = true
	game_over_screen.visible = false
	get_tree().paused = true


func _begin_game() -> void:
	_clear_flies()
	frog.global_position = frog_spawn
	frog.velocity = Vector2.ZERO
	GameEvents.game_started.emit()
	state = State.PLAYING
	time_left = GAME_DURATION
	_update_timer_label()
	start_screen.visible = false
	game_over_screen.visible = false
	get_tree().paused = false


func _end_game() -> void:
	state = State.GAME_OVER
	get_tree().paused = true
	var final: int = score_ui.get_score()
	final_score_label.text = "Final Score: %d" % final
	game_over_screen.visible = true
	GameEvents.game_ended.emit(final)


func _clear_flies() -> void:
	for fly in get_tree().get_nodes_in_group("flies"):
		fly.queue_free()
