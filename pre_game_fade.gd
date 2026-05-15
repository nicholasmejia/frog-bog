extends CanvasLayer

# Pre-Game Fade.
# A full-screen black overlay that fades out (to opaque black) and back in (to clear).
# Used to bridge the Title Screen into the Game Start Countdown, and to
# bridge a Restart from Game Over into a fresh Game Start Countdown.

const FADE_OUT_DURATION := 0.4
const HOLD_BLACK_DURATION := 0.1
const FADE_IN_DURATION := 0.4

signal faded_to_black
signal faded_in

@onready var rect: ColorRect = $Rect


func _ready() -> void:
	rect.color = Color(0, 0, 0, 0)
	visible = false


func play() -> void:
	visible = true
	rect.color = Color(0, 0, 0, 0)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void: faded_to_black.emit())
	tween.tween_interval(HOLD_BLACK_DURATION)
	tween.tween_property(rect, "color:a", 0.0, FADE_IN_DURATION)
	tween.tween_callback(func() -> void:
		visible = false
		faded_in.emit()
	)
