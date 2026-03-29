extends ToolBase
class_name VerticalThruster
## Instant upward launch - panic button for recovery

@export var launch_force: float = 800.0

func _ready() -> void:
	super._ready()
	tool_name = "Vertical Thruster"
	cooldown = 12.0
	tool_color = Color(1.0, 0.533, 0.267)  # Orange

func _do_activate(player: Player) -> void:
	# Instant upward launch
	player.velocity.y = -launch_force

	# Cancel some horizontal momentum
	player.velocity.x *= 0.5

	# Release grapple if attached
	if player.is_grappling:
		player._release_grapple()

	# Visual effect
	_spawn_thruster_effect(player.global_position)

	# Screen shake
	EventBus.screen_shake.emit(8.0, 0.15)

	start_cooldown()

func _spawn_thruster_effect(pos: Vector2) -> void:
	# Spawn upward particles
	for i in range(8):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = pos + Vector2(randf_range(-15, 15), 20)
		particle.color = tool_color
		particle.velocity = Vector2(randf_range(-50, 50), randf_range(100, 200))
		get_tree().current_scene.add_child(particle)
