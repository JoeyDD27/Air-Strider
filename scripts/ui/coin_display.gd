extends Control
class_name CoinDisplayUI
## Coin counter display

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud:
		return

	var viewport_width = get_viewport_rect().size.x
	var x = viewport_width - 120
	var y = 20.0

	# Coin icon (yellow circle)
	draw_circle(Vector2(x, y + 10), 12, Color(1.0, 0.8, 0.0))
	draw_circle(Vector2(x, y + 10), 12, Color(0.8, 0.6, 0.0), false, 2.0)

	# Dollar sign
	draw_string(ThemeDB.fallback_font, Vector2(x - 4, y + 15), "$", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.6, 0.4, 0.0))

	# Coin count
	draw_string(ThemeDB.fallback_font, Vector2(x + 25, y + 16), str(hud.player_coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
