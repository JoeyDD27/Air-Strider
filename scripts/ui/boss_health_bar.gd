extends Control
class_name BossHealthBarUI
## Boss health bar display

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud or not hud.show_boss_health:
		return

	var viewport_width = get_viewport_rect().size.x
	var bar_width = 400.0
	var bar_height = 30.0
	var x = (viewport_width - bar_width) / 2
	var y = 50.0

	# Boss name - show correct name based on chapter
	var boss_name = "FURNACE CRAB"
	if GameManager.get_current_chapter() == 2:
		boss_name = "GROUND-FAULT TITAN"
	elif GameManager.get_current_chapter() == 3:
		boss_name = "APEX-INTERCEPTOR"
	elif GameManager.get_current_chapter() == 4:
		boss_name = "SUBJECT 88"
	elif GameManager.get_current_chapter() == 5:
		boss_name = "ORBITAL AEGIS"
	draw_string(ThemeDB.fallback_font, Vector2(viewport_width / 2 - 80, y - 10), boss_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1.0, 0.4, 0.0))

	# Background
	draw_rect(Rect2(x, y, bar_width, bar_height), Color(0.2, 0.2, 0.2))

	# Health fill
	var health_ratio = float(hud.boss_health) / float(hud.boss_max_health)
	draw_rect(Rect2(x, y, bar_width * health_ratio, bar_height), Color(0.8, 0.133, 0.133))

	# Phase markers (at 50% and 25%)
	draw_rect(Rect2(x + bar_width * 0.5 - 1, y, 2, bar_height), Color.WHITE)
	draw_rect(Rect2(x + bar_width * 0.25 - 1, y, 2, bar_height), Color.WHITE)

	# Border
	draw_rect(Rect2(x, y, bar_width, bar_height), Color(1.0, 0.4, 0.0), false, 3.0)
