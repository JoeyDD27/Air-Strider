extends Node2D
class_name ShockwaveEffect
## Expanding ring visual effect for shockwave attacks

@export var radius: float = 150.0
@export var duration: float = 0.3
@export var color: Color = Color(0.6, 0.2, 1.0)
@export var line_width: float = 4.0

var current_radius: float = 0.0
var elapsed: float = 0.0

func _ready() -> void:
	z_index = 100  # Draw above most things

func _process(delta: float) -> void:
	elapsed += delta

	# Expand radius over duration
	var progress = elapsed / duration
	current_radius = radius * progress

	# Fade out as it expands
	var alpha = 1.0 - progress

	if progress >= 1.0:
		queue_free()
		return

	modulate.a = alpha
	queue_redraw()

func _draw() -> void:
	# Main ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, color, line_width)

	# Inner ring (faster)
	var inner_radius = current_radius * 0.7
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.5), line_width * 0.5)

	# Electric sparks around the edge
	var spark_count = 8
	for i in range(spark_count):
		var angle = i * TAU / spark_count + elapsed * 10
		var spark_pos = Vector2(cos(angle), sin(angle)) * current_radius
		var spark_end = spark_pos + Vector2(cos(angle + 0.3), sin(angle + 0.3)) * 15
		draw_line(spark_pos, spark_end, Color.WHITE, 2.0)
