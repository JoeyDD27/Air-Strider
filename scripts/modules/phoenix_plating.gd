extends ModuleBase
class_name PhoenixPlating
## Once per room, survive fatal damage with 1 HP and 2s invincibility

const REVIVE_INVINCIBILITY: float = 2.0

func _on_initialize() -> void:
	module_name = "Phoenix Plating"
	module_description = "Once per room, survive fatal hit with 1 HP"
	module_color = Color(1.0, 0.4, 0.0)  # Orange/flame

func on_player_died() -> Dictionary:
	## Check if we can prevent this death

	# Already used this room?
	if GameManager.phoenix_used_this_room:
		return {}

	# Mark as used for this room
	GameManager.phoenix_used_this_room = true

	# Emit feedback
	EventBus.module_effect_triggered.emit("phoenix_plating", {
		"survived": true,
		"invincibility": REVIVE_INVINCIBILITY
	})

	# Prevent death, set to 1 HP, grant extended invincibility
	return {
		"prevent": true,
		"set_health": 1,
		"invincibility_duration": REVIVE_INVINCIBILITY
	}

func get_status_text() -> String:
	## Show status in HUD
	if GameManager.phoenix_used_this_room:
		return "USED"
	return "READY"
