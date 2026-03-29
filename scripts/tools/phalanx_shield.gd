extends ToolBase
class_name PhalanxShield
## Directional barrier that blocks enemy projectiles

@export var shield_arc: float = PI / 2  # 90 degree coverage

var shield_direction: float = 0.0
var shield_active: bool = false
var player_ref: Player = null

# Shield collision detection
var shield_area: Area2D = null
var shield_collision: CollisionShape2D = null
var shield_radius: float = 80.0  # Radius of shield detection area (must be larger than player collision)

func _ready() -> void:
	super._ready()
	tool_name = "Phalanx Shield"
	cooldown = 5.0
	tool_color = Color(0.267, 1.0, 0.267)  # Green
	_setup_shield_collision()

func _setup_shield_collision() -> void:
	# Create Area2D for detecting projectiles at the shield barrier
	shield_area = Area2D.new()
	shield_area.collision_layer = 0  # Shield doesn't occupy any layer
	shield_area.collision_mask = 8   # Detect enemy projectiles (layer 8)
	shield_area.monitoring = true
	shield_area.monitorable = false
	add_child(shield_area)

	# Create circular collision shape
	shield_collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = shield_radius
	shield_collision.shape = circle_shape
	shield_collision.disabled = true  # Start disabled until shield activates
	shield_area.add_child(shield_collision)

	# Connect signal for projectile detection
	shield_area.area_entered.connect(_on_projectile_entered)

func _process(delta: float) -> void:
	super._process(delta)

	if shield_active and player_ref:
		# Update shield direction to face mouse
		var mouse_pos = player_ref.get_global_mouse_position()
		shield_direction = (mouse_pos - player_ref.global_position).angle()
		queue_redraw()

func _do_activate(player: Player) -> void:
	player_ref = player

	if shield_active:
		deactivate()
	else:
		shield_active = true
		is_active = true
		shield_collision.disabled = false  # Enable collision detection

		# Shield faces mouse direction
		var mouse_pos = player.get_global_mouse_position()
		shield_direction = (mouse_pos - player.global_position).angle()

func deactivate() -> void:
	shield_active = false
	is_active = false
	shield_collision.disabled = true  # Disable collision detection
	queue_redraw()  # Clear the shield visual immediately
	start_cooldown()

func can_block_projectile(projectile_direction: Vector2) -> bool:
	if not shield_active:
		return false

	# Check if projectile comes from shielded direction
	var incoming_angle = projectile_direction.angle()
	var angle_diff = _normalize_angle(incoming_angle - shield_direction)

	# Block if projectile is coming from the direction we're facing
	return abs(angle_diff) > PI - shield_arc / 2

func _on_projectile_entered(area: Area2D) -> void:
	# Check if this is a projectile we should block
	if not shield_active or not player_ref:
		return

	# Get projectile direction from velocity or direction property
	var projectile_dir: Vector2 = Vector2.ZERO

	if "velocity" in area and area.velocity is Vector2:
		projectile_dir = area.velocity.normalized()
	elif "direction" in area and area.direction is Vector2:
		projectile_dir = area.direction.normalized()
	else:
		# Unknown projectile type - calculate direction from position
		projectile_dir = (player_ref.global_position - area.global_position).normalized()

	# Check if projectile is coming from the shielded direction
	if can_block_projectile(projectile_dir):
		# Spawn hit effect at shield location (not at player)
		_spawn_shield_block_effect(area.global_position)
		area.queue_free()

func _spawn_shield_block_effect(pos: Vector2) -> void:
	# Visual feedback when shield blocks a projectile
	for i in range(6):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = pos
		particle.color = tool_color  # Green particles for shield block
		particle.size = randf_range(4, 8)
		get_tree().current_scene.add_child(particle)

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _draw() -> void:
	if not shield_active or not player_ref:
		return

	# Draw shield arc
	var radius = player_ref.size + 15
	var start_angle = shield_direction - shield_arc / 2
	var end_angle = shield_direction + shield_arc / 2

	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 32, tool_color, 5.0)

	# Draw shield glow
	draw_arc(Vector2.ZERO, radius + 3, start_angle, end_angle, 32, Color(tool_color, 0.3), 10.0)
