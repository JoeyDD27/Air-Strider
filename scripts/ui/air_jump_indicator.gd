extends Control
class_name AirJumpIndicatorUI
## Air jump availability indicator

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud or not hud.has_air_jump:
		return

	var viewport_height = get_viewport_rect().size.y
	var x = 120.0
	var y = viewport_height - 50

	# Arrow pointing up (jump indicator)
	var color = Color(0.267, 1.0, 1.0)  # Cyan

	var points = PackedVector2Array([
		Vector2(x, y - 15),
		Vector2(x + 10, y),
		Vector2(x + 5, y),
		Vector2(x + 5, y + 10),
		Vector2(x - 5, y + 10),
		Vector2(x - 5, y),
		Vector2(x - 10, y)
	])
	draw_colored_polygon(points, color)

	# Label
	draw_string(ThemeDB.fallback_font, Vector2(x - 15, y + 25), "JUMP", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
