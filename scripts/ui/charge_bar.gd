extends Control
class_name ChargeBarUI
## Weapon charge bar display

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud or not hud.is_charging:
		return

	var viewport_size = get_viewport_rect().size
	var x = viewport_size.x / 2
	var y = viewport_size.y - 100

	var bar_width = 150.0
	var bar_height = 15.0

	# Label
	draw_string(ThemeDB.fallback_font, Vector2(x - 35, y - 5), "CHARGING", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# Background
	draw_rect(Rect2(x - bar_width / 2, y, bar_width, bar_height), Color(0.2, 0.2, 0.2))

	# Charge fill
	var charge_color = Color(0.267, 0.667, 1.0)  # Blue
	if hud.charge_percent >= 1.0:
		charge_color = Color(1.0, 0.267, 0.267)  # Red when full

	draw_rect(Rect2(x - bar_width / 2, y, bar_width * hud.charge_percent, bar_height), charge_color)

	# Border
	draw_rect(Rect2(x - bar_width / 2, y, bar_width, bar_height), Color.WHITE, false, 2.0)

	# Max charge indicator
	if hud.charge_percent >= 1.0:
		draw_string(ThemeDB.fallback_font, Vector2(x - 15, y + 28), "MAX!", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.RED)
