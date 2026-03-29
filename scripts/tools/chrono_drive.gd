extends ToolBase
class_name ChronoDrive
## Global slow motion - precision aiming tool

@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.25  # 25% speed

var slow_timer: float = 0.0
var is_slowing: bool = false

func _ready() -> void:
	super._ready()
	tool_name = "Chrono-Drive"
	cooldown = 15.0
	tool_color = Color(0.267, 1.0, 1.0)  # Cyan

func _process(delta: float) -> void:
	# Handle cooldown with real time (not slowed)
	if cooldown_remaining > 0:
		# Use unscaled delta for cooldown
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
		cooldown_remaining -= real_delta
		if cooldown_remaining <= 0:
			cooldown_remaining = 0
			EventBus.tool_cooldown_ended.emit(tool_name)

	if is_slowing:
		# Track duration using real time
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
		slow_timer += real_delta

		if slow_timer >= slow_duration:
			deactivate()

func _do_activate(player: Player) -> void:
	is_slowing = true
	is_active = true
	slow_timer = 0.0

	# Apply slow-mo to game
	Engine.time_scale = slow_factor
	EventBus.time_scale_changed.emit(slow_factor)

	# Visual effect
	_apply_visual_effect()

func deactivate() -> void:
	is_slowing = false
	is_active = false

	# Restore normal time
	Engine.time_scale = 1.0
	EventBus.time_scale_changed.emit(1.0)

	start_cooldown()

func _apply_visual_effect() -> void:
	# Could add screen tint or other visual feedback
	EventBus.flash_screen.emit(Color(0.2, 0.4, 0.5, 0.3), 0.2)
