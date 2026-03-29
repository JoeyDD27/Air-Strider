extends ModuleBase
class_name BountyHunterChip
## 50% chance enemies drop double coins

var last_doubled: bool = false  # Track for visual feedback

func _on_initialize() -> void:
	module_name = "Bounty Hunter Chip"
	module_description = "50% chance for double coins"
	module_color = Color(1.0, 0.85, 0.0)  # Gold

func on_coin_drop(base_amount: int, _enemy_type: String) -> int:
	## 50% chance to double the coin drop
	if randf() < 0.5:
		last_doubled = true
		EventBus.module_effect_triggered.emit("bounty_hunter_chip", {"doubled": true, "amount": base_amount * 2})
		return base_amount * 2
	last_doubled = false
	return base_amount

func get_status_text() -> String:
	return "50% 2x coins"
