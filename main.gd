extends Node2D

const GAME_DURATION := 60.0

enum State { TITLE, PRE_GAME, COUNTDOWN, PLAYING, GAME_OVER }

@onready var frog: CharacterBody2D = $Frog
@onready var score_ui: CanvasLayer = $ScoreUI
@onready var timer_label: Label = $HUD/TimerLabel
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var pre_game_fade: CanvasLayer = $PreGameFade
@onready var countdown: CanvasLayer = $Countdown
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var final_score_label: Label = $GameOverScreen/Center/VBox/FinalScoreLabel
@onready var restart_button: Button = $GameOverScreen/Center/VBox/RestartButton
@onready var frog_portrait: CanvasLayer = $FrogPortrait

var state: int = State.TITLE
var time_left: float = GAME_DURATION
var frog_spawn: Vector2 = Vector2.ZERO


func _ready() -> void:
	frog_spawn = frog.global_position
	restart_button.pressed.connect(_on_restart_pressed)
	title_screen.start_requested.connect(_on_title_start_requested)
	pre_game_fade.faded_to_black.connect(_on_fade_to_black)
	pre_game_fade.faded_in.connect(_on_fade_in)
	countdown.countdown_finished.connect(_on_countdown_finished)
	_enter_title()


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


func _enter_title() -> void:
	state = State.TITLE
	time_left = GAME_DURATION
	_update_timer_label()
	frog.global_position = frog_spawn
	frog.set_frozen(true)
	game_over_screen.visible = false
	frog_portrait.visible = false
	get_tree().paused = true
	title_screen.play()


func _on_title_start_requested() -> void:
	_begin_pre_game()


func _on_restart_pressed() -> void:
	_begin_pre_game()


func _begin_pre_game() -> void:
	state = State.PRE_GAME
	game_over_screen.visible = false
	frog_portrait.visible = false
	# Engine stays paused; PreGameFade has process_mode = ALWAYS so it animates anyway.
	get_tree().paused = true
	pre_game_fade.play()


func _on_fade_to_black() -> void:
	# At full black, reset the world for a fresh run.
	_clear_flies()
	frog.global_position = frog_spawn
	frog.velocity = Vector2.ZERO
	frog.set_frozen(true)
	time_left = GAME_DURATION
	_update_timer_label()
	# Hide the title screen if it's still visible (e.g. first run).
	title_screen.visible = false
	frog_portrait.reset_for_new_run()


func _on_fade_in() -> void:
	# Black has just faded out; start the countdown.
	state = State.COUNTDOWN
	get_tree().paused = false  # Flies must spawn during the countdown.
	frog_portrait.visible = true
	countdown.play()


func _on_countdown_finished() -> void:
	state = State.PLAYING
	frog.set_frozen(false)
	GameEvents.game_started.emit()


func _end_game() -> void:
	state = State.GAME_OVER
	frog.set_frozen(true)
	get_tree().paused = true
	var final: int = score_ui.get_score()
	final_score_label.text = "Final Score: %d" % final
	game_over_screen.visible = true
	GameEvents.game_ended.emit(final)


func _clear_flies() -> void:
	for fly in get_tree().get_nodes_in_group("flies"):
		fly.queue_free()
