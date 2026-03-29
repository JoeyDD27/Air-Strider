extends Node2D
class_name DebrisParticle
## Simple debris particle for platform destruction effects

var velocity: Vector2
var lifetime: float = 1.0
var size: float = 8.0
var color: Color = Color(0.4, 0.4, 0.4)
var gravity: float = 400.0
var rotation_speed: float = 0.0

func _ready() -> void:
	velocity = Vector2(
		randf_range(-150, 150),
		randf_range(-200, -50)
	)
	rotation_speed = randf_range(-10, 10)
	size = randf_range(4, 12)

func _process(delta: float) -> void:
	# Apply gravity
	velocity.y += gravity * delta

	# Move
	position += velocity * delta
	rotation += rotation_speed * delta

	# Fade out
	lifetime -= delta
	modulate.a = lifetime

	if lifetime <= 0:
		queue_free()

	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size / 2, -size / 2, size, size), color)
