extends Control
class_name ToolDisplayUI
## Equipped tool display with cooldown

# Preload tool icon textures
const TOOL_ICONS: Dictionary = {
	"vertical_thruster": preload("res://assets/icons/tools/vertical_thruster.png"),
	"phalanx_shield": preload("res://assets/icons/tools/phalanx_shield.png"),
	"phase_shift": preload("res://assets/icons/tools/phase_shift.png"),
	"chrono_drive": preload("res://assets/icons/tools/chrono_drive.png"),
}

func _draw() -> void:
	var hud = get_parent() as HUD
	if not hud:
		return

	var viewport_height = get_viewport_rect().size.y
	var x = 20.0
	var y = viewport_height - 100

	var box_size = 80.0

	# Tool box background
	draw_rect(Rect2(x, y, box_size, box_size), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(x, y, box_size, box_size), Color(0.4, 0.4, 0.4), false, 2.0)

	if hud.equipped_tool_name != "":
		# Draw tool icon
		var icon_texture = TOOL_ICONS.get(hud.equipped_tool_name)
		if icon_texture:
			var icon_size = 50.0
			var icon_x = x + (box_size - icon_size) / 2
			var icon_y = y + 3
			draw_texture_rect(icon_texture, Rect2(icon_x, icon_y, icon_size, icon_size), false)

		# Tool name
		var display_name = _get_tool_display_name(hud.equipped_tool_name)
		draw_string(ThemeDB.fallback_font, Vector2(x + 5, y + 58), display_name, HORIZONTAL_ALIGNMENT_LEFT, box_size - 10, 10, Color.WHITE)

		# Cooldown overlay
		if hud.tool_cooldown_percent > 0:
			var cooldown_height = box_size * hud.tool_cooldown_percent
			draw_rect(Rect2(x, y, box_size, cooldown_height), Color(0, 0, 0, 0.7))

			# Cooldown time (centered in the box)
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty() and players[0].equipped_tool:
				var remaining = players[0].equipped_tool.cooldown_remaining
				var cd_text = "%.1fs" % remaining
				draw_string(ThemeDB.fallback_font, Vector2(x + 18, y + 45), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 45), "NO TOOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.4))

	# Keybind hint
	draw_string(ThemeDB.fallback_font, Vector2(x + 25, y + box_size - 5), "[E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))

func _get_tool_display_name(tool_name: String) -> String:
	match tool_name:
		"vertical_thruster":
			return "THRUSTER"
		"phalanx_shield":
			return "SHIELD"
		"phase_shift":
			return "PHASE"
		"chrono_drive":
			return "CHRONO"
		_:
			return tool_name.to_upper().substr(0, 8)
