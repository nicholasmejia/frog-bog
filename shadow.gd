extends Node2D

# Drop-shadow component for the Frog.
# Must be parented to a CharacterBody2D that exposes a `charging: bool` and has a child
# `CollisionShape2D` whose shape is a RectangleShape2D. Process order relies on tree
# ordering: this node's `_physics_process` runs after the parent's, so it reads
# up-to-date frog state each frame.

const MAX_HEIGHT := 200.0
const MIN_SCALE := 1.0
const MAX_SCALE := 1.8
const MAX_ALPHA := 0.55
const MIN_ALPHA := 0.15
const LERP_RATE := 16.0
const RADIUS_X := 60.0
const RADIUS_Y := 14.0
const SEGMENTS := 32

@export var anchor_y: float = 790.0

@onready var frog: CharacterBody2D = get_parent()

var feet_offset: float = 0.0
var scale_t: float = 0.0
var alpha_t: float = 0.0


func _ready() -> void:
	var collision: CollisionShape2D = frog.get_node("CollisionShape2D")
	var rect: RectangleShape2D = collision.shape as RectangleShape2D
	assert(rect != null, "shadow.gd expects frog's CollisionShape2D to use a RectangleShape2D")
	feet_offset = collision.position.y + rect.size.y * 0.5


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var a: float = TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(a) * RADIUS_X, sin(a) * RADIUS_Y))
	draw_colored_polygon(pts, Color(0, 0, 0, 1))


func _physics_process(delta: float) -> void:
	var feet_y: float = frog.global_position.y + feet_offset
	var height: float = maxf(0.0, anchor_y - feet_y)
	var height_t: float = clampf(height / MAX_HEIGHT, 0.0, 1.0)
	var in_air: bool = not frog.is_on_floor()
	var target_scale_t: float = 1.0 if frog.charging else height_t
	var target_alpha_t: float = height_t if in_air else 0.0
	var k: float = clampf(LERP_RATE * delta, 0.0, 1.0)
	scale_t = lerpf(scale_t, target_scale_t, k)
	alpha_t = lerpf(alpha_t, target_alpha_t, k)
	var s: float = lerpf(MIN_SCALE, MAX_SCALE, scale_t)
	var a: float = lerpf(MAX_ALPHA, MIN_ALPHA, alpha_t)
	global_position = Vector2(frog.global_position.x, anchor_y + GameEvents.platform_offset.y)
	scale = Vector2(s, s)
	modulate.a = a
