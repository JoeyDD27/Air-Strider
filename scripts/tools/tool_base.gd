extends Node2D
class_name ToolBase
## Base class for all player tools

@export var tool_name: String = "Tool"
@export var cooldown: float = 5.0
@export var tool_color: Color = Color.WHITE

var cooldown_remaining: float = 0.0
var is_active: bool = false

func _ready() -> void:
	add_to_group("tools")

func _process(delta: float) -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0:
			cooldown_remaining = 0
			EventBus.tool_cooldown_ended.emit(tool_name)

func is_on_cooldown() -> bool:
	return cooldown_remaining > 0

func activate(player: Player) -> void:
	if is_on_cooldown():
		return

	_do_activate(player)
	EventBus.tool_activated.emit(tool_name)

func _do_activate(_player: Player) -> void:
	# Override in subclasses
	pass

func start_cooldown() -> void:
	cooldown_remaining = cooldown
	EventBus.tool_cooldown_started.emit(tool_name, cooldown)

func get_cooldown_percent() -> float:
	if cooldown <= 0:
		return 0.0
	return cooldown_remaining / cooldown
