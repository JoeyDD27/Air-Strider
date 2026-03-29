extends Node2D
class_name FloorDangerLine
## Visual indicator for dangerous lava floor - pulsing red line

var room_width: float = 1920.0
var pulse_time: float = 0.0

func _ready() -> void:
	# Get room width from meta if set
	if has_meta("room_width"):
		room_width = get_meta("room_width")

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	# Pulsing red glow effect
	var pulse = sin(pulse_time * 3.0) * 0.3 + 0.7
	var warning_color = Color(1.0, 0.2, 0.1, pulse)

	# Draw main danger line
	draw_line(Vector2(-100, 0), Vector2(room_width + 100, 0), warning_color, 4.0)

	# Draw secondary glow lines for emphasis
	var glow_alpha = pulse * 0.4
	draw_line(Vector2(-100, -3), Vector2(room_width + 100, -3), Color(1.0, 0.4, 0.2, glow_alpha), 2.0)
	draw_line(Vector2(-100, 3), Vector2(room_width + 100, 3), Color(1.0, 0.4, 0.2, glow_alpha), 2.0)

	# Draw warning stripes along the line
	var stripe_spacing = 80.0
	var stripe_width = 30.0
	for i in range(int((room_width + 200) / stripe_spacing)):
		var x = -100 + i * stripe_spacing + fmod(pulse_time * 20, stripe_spacing)
		draw_line(Vector2(x, -8), Vector2(x + stripe_width, -8), Color(1.0, 0.8, 0.0, pulse * 0.6), 3.0)
