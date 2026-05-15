extends Node

const SPECIAL_COLOR := Color(1.0, 0.84, 0.2, 1.0)

# Gameplay events
signal fly_caught(in_air: bool)
signal frog_landed
signal frog_fell
signal game_started
signal game_ended(final_score: int)
signal special_fly_caught

# Platform impulse events
signal platform_charge
signal platform_jump(dir_x: float)
signal platform_land(dir_x: float)

# Shared mutable state read by frog/fly/shadow each frame
var time_factor: float = 1.0
var platform_offset: Vector2 = Vector2.ZERO
