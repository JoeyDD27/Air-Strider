extends ToolBase
class_name PhaseShift
## Short dash with invincibility - evasion tool

@export var dash_distance: float = 150.0
@export var invincibility_duration: float = 0.5

func _ready() -> void:
	super._ready()
	tool_name = "Phase Shift"
	cooldown = 12.0
	tool_color = Color(0.667, 0.267, 1.0)  # Purple

func _do_activate(player: Player) -> void:
	var start_pos = player.global_position

	# Get dash direction from mouse
	var mouse_pos = player.get_global_mouse_position()
	var direction = (mouse_pos - player.global_position).normalized()

	# If no mouse direction, dash in movement direction
	if direction.length() < 0.1:
		direction = Vector2.RIGHT if player.velocity.x >= 0 else Vector2.LEFT

	# Release grapple if attached
	if player.is_grappling:
		player._release_grapple()

	# Teleport player
	player.global_position = player.global_position + direction * dash_distance

	# Grant invincibility
	player._start_invincibility(invincibility_duration)

	# Visual effect - trail between positions
	_spawn_phase_trail(start_pos, player.global_position)

	start_cooldown()

func _spawn_phase_trail(start: Vector2, end: Vector2) -> void:
	var trail = Node2D.new()
	trail.set_script(preload("res://scripts/effects/phase_trail.gd"))
	trail.start_pos = start
	trail.end_pos = end
	trail.trail_color = tool_color
	get_tree().current_scene.add_child(trail)
