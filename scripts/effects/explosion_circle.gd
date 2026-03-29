extends Node2D
class_name ExplosionCircle
## Visual explosion circle effect

var radius: float = 80.0
var lifetime: float = 0.3
var max_lifetime: float = 0.3
var color: Color = Color(1.0, 0.6, 0.2)

func _process(delta: float) -> void:
	lifetime -= delta

	if lifetime <= 0:
		queue_free()

	queue_redraw()

func _draw() -> void:
	var alpha = lifetime / max_lifetime
	var current_radius = radius * (1.0 - alpha * 0.5)

	# Outer circle
	draw_circle(Vector2.ZERO, current_radius, Color(color, alpha * 0.3))

	# Inner bright circle
	draw_circle(Vector2.ZERO, current_radius * 0.5, Color(1, 1, 0.8, alpha * 0.6))

	# Ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color(color, alpha), 3.0)
