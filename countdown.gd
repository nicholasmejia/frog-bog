extends CanvasLayer

# Game Start Countdown.
# Shows "3" -> "2" -> "1" -> "Start!" at the center of the viewport.
# Each numeric beat is shown for BEAT_DURATION; "Start!" pops in then fades out
# over START_FADE_DURATION. Emits `countdown_finished` when the final fade ends.

const BEAT_DURATION := 1.0
const POP_IN_DURATION := 0.15
const POP_IN_SCALE := 1.5
const START_HOLD := 0.4
const START_FADE_DURATION := 0.4

signal countdown_finished

@onready var label: Label = $Label

var _running: bool = false


func _ready() -> void:
	visible = false
	label.modulate.a = 0.0
	label.scale = Vector2.ONE


func play() -> void:
	if _running:
		return
	_running = true
	visible = true
	_play_beat("3")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_beat("2")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_beat("1")
	await get_tree().create_timer(BEAT_DURATION).timeout
	_play_start()
	await get_tree().create_timer(START_HOLD + START_FADE_DURATION).timeout
	visible = false
	_running = false
	countdown_finished.emit()


func _play_beat(text: String) -> void:
	label.text = text
	label.scale = Vector2(POP_IN_SCALE, POP_IN_SCALE)
	label.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, POP_IN_DURATION)
	tween.tween_property(label, "modulate:a", 1.0, POP_IN_DURATION)


func _play_start() -> void:
	label.text = "Start!"
	label.scale = Vector2(POP_IN_SCALE, POP_IN_SCALE)
	label.modulate.a = 0.0
	var pop: Tween = create_tween().set_parallel(true)
	pop.tween_property(label, "scale", Vector2.ONE, POP_IN_DURATION)
	pop.tween_property(label, "modulate:a", 1.0, POP_IN_DURATION)
	await pop.finished
	await get_tree().create_timer(START_HOLD).timeout
	var fade: Tween = create_tween()
	fade.tween_property(label, "modulate:a", 0.0, START_FADE_DURATION)
