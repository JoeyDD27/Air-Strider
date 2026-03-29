extends Control
class_name HealthBarUI
## Health bar display

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud:
		return

	var x = 20.0
	var y = 20.0
	var bar_width = 200.0
	var bar_height = 20.0

	# Label
	draw_string(ThemeDB.fallback_font, Vector2(x, y + 14), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Background
	draw_rect(Rect2(x, y + 20, bar_width, bar_height), Color(0.2, 0.2, 0.2))

	# Health fill
	var health_ratio = float(hud.player_health) / float(hud.player_max_health)
	var health_color = Color(0.133, 0.8, 0.133)  # Green
	if health_ratio <= 0.5:
		health_color = Color(0.8, 0.8, 0.133)  # Yellow
	if health_ratio <= 0.25:
		health_color = Color(0.8, 0.133, 0.133)  # Red

	draw_rect(Rect2(x, y + 20, bar_width * health_ratio, bar_height), health_color)

	# Border
	draw_rect(Rect2(x, y + 20, bar_width, bar_height), Color.WHITE, false, 2.0)

	# Health text
	var health_text = "%d / %d" % [hud.player_health, hud.player_max_health]
	draw_string(ThemeDB.fallback_font, Vector2(x + bar_width / 2 - 20, y + 36), health_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
