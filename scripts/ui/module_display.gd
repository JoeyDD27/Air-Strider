extends Control
class_name ModuleDisplayUI
## Equipped module display with status indicator

# Preload module icon textures
const MODULE_ICONS: Dictionary = {
	"gravity_anchor": preload("res://assets/icons/modules/gravity_anchor.png"),
	"phoenix_plating": preload("res://assets/icons/modules/phoenix_plating.png"),
	"spectral_phase": preload("res://assets/icons/modules/spectral_phase.png"),
	"hyper_coil": preload("res://assets/icons/modules/hyper_coil.png"),
	"blood_drive_core": preload("res://assets/icons/modules/blood_drive_core.png"),
	"reactive_shock_shell": preload("res://assets/icons/modules/reactive_shock_shell.png"),
	"bounty_hunter_chip": preload("res://assets/icons/modules/bounty_hunter_chip.png"),
	"aviator_gyro": preload("res://assets/icons/modules/aviator_gyro.png"),
}

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud:
		return

	var viewport_height = get_viewport_rect().size.y
	# Position next to tool display (tool is at x=20, width=80, so module starts at x=110)
	var x = 110.0
	var y = viewport_height - 100

	var box_size = 80.0

	# Module box background
	draw_rect(Rect2(x, y, box_size, box_size), Color(0.12, 0.12, 0.15))
	draw_rect(Rect2(x, y, box_size, box_size), Color(0.35, 0.35, 0.45), false, 2.0)

	if hud.equipped_module_name != "":
		# Draw module icon
		var icon_texture = MODULE_ICONS.get(hud.equipped_module_name)
		if icon_texture:
			var icon_size = 50.0
			var icon_x = x + (box_size - icon_size) / 2
			var icon_y = y + 3
			draw_texture_rect(icon_texture, Rect2(icon_x, icon_y, icon_size, icon_size), false)

		# Module name
		var display_name = _get_module_display_name(hud.equipped_module_name)
		draw_string(ThemeDB.fallback_font, Vector2(x + 5, y + 58), display_name, HORIZONTAL_ALIGNMENT_LEFT, box_size - 10, 10, Color.WHITE)

		# Status text (from module)
		var status_text = hud.module_status_text
		if status_text != "":
			draw_string(ThemeDB.fallback_font, Vector2(x + 5, y + 72), status_text, HORIZONTAL_ALIGNMENT_LEFT, box_size - 10, 9, Color(0.7, 0.7, 0.7))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(x + 5, y + 45), "NO MODULE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))

func _get_module_display_name(module_name: String) -> String:
	match module_name:
		"gravity_anchor":
			return "ANCHOR"
		"phoenix_plating":
			return "PHOENIX"
		"spectral_phase":
			return "SPECTRAL"
		"hyper_coil":
			return "COIL"
		"blood_drive_core":
			return "BLOOD"
		"reactive_shock_shell":
			return "SHOCK"
		"bounty_hunter_chip":
			return "BOUNTY"
		"aviator_gyro":
			return "AVIATOR"
		_:
			return module_name.to_upper().substr(0, 8)
