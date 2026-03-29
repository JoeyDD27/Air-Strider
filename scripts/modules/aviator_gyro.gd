extends ModuleBase
class_name AviatorGyro
## Fall 50% slower at all times

const GRAVITY_REDUCTION: float = 0.5  # 50% less gravity (fall slower)

func _on_initialize() -> void:
	module_name = "Aviator Gyro"
	module_description = "Fall 50% slower"
	module_color = Color(0.4, 0.8, 1.0)  # Light blue/cyan

func get_gravity_multiplier() -> float:
	## Always reduce gravity by 50%
	return GRAVITY_REDUCTION

func get_status_text() -> String:
	return "50% gravity"
