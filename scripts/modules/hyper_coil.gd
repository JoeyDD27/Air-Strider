extends ModuleBase
class_name HyperCoil
## Reduces weapon charge time by 30%

const CHARGE_MULTIPLIER: float = 1.43  # 1 / 0.7 = ~1.43 (30% faster charging)

func _on_initialize() -> void:
	module_name = "Hyper-Coil"
	module_description = "30% faster weapon charge"
	module_color = Color(1.0, 0.2, 0.2)  # Red

func on_charge_updated(_delta: float, _current_charge: float) -> float:
	## Return faster charge speed multiplier
	return CHARGE_MULTIPLIER

func get_status_text() -> String:
	return "+30% charge"
