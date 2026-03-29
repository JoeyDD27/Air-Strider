extends ModuleBase
class_name GravityAnchor
## Prevents pit deaths. Falling into void deals 1 damage and respawns on last safe ground.
## Works on all difficulty levels - the only way to survive pits without dying.

func _on_initialize() -> void:
	module_name = "Gravity Anchor"
	module_description = "Pit deaths deal 1 damage + respawn on safe ground"
	module_color = Color(0.3, 0.6, 1.0)  # Blue

func on_player_damaged(amount: int, source: String) -> Dictionary:
	## Intercept pit deaths and convert to survivable damage

	# Only intercept pit deaths (999 damage from floor hazard)
	if amount >= 999 and source == "pit":
		var safe_pos = player_ref.last_safe_position if player_ref else Vector2.ZERO

		# Emit event for visual/audio feedback
		EventBus.pit_death_prevented.emit(safe_pos)
		EventBus.module_effect_triggered.emit("gravity_anchor", {
			"saved": true,
			"respawn_position": safe_pos
		})

		# Return modified damage: 1 damage instead of instant death, teleport to safe position
		return {
			"amount": 1,
			"respawn_position": safe_pos,
			"prevent_death_if_survives": true
		}

	return {}

func get_status_text() -> String:
	return "Pit protect"
