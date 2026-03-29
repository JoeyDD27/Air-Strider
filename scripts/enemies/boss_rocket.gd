extends Area2D
class_name BossRocket
## Homing rocket fired by Furnace Crab boss

var velocity: Vector2 = Vector2.ZERO
var speed: float = 300.0
var turn_speed: float = 2.0  # Radians per second
var damage: int = 2
var lifetime: float = 6.0
var explosion_radius: float = 60.0

var target: Node2D = null
var size: float = 15.0
var color: Color = Color(1.0, 0.3, 0.1)  # Red-orange

func _ready() -> void:
	collision_layer = 8  # Projectiles layer
	collision_mask = 1 | 2  # Player and platforms

	body_entered.connect(_on_body_entered)

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

	# Initial velocity in facing direction
	velocity = Vector2.from_angle(rotation) * speed

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		# Calculate desired direction toward player
		var to_target = (target.global_position - global_position).normalized()
		var current_dir = velocity.normalized()

		# Smoothly turn toward target
		var target_angle = to_target.angle()
		var current_angle = current_dir.angle()
		var angle_diff = _normalize_angle(target_angle - current_angle)

		var turn_amount = turn_speed * delta
		if abs(angle_diff) < turn_amount:
			current_angle = target_angle
		else:
			current_angle += sign(angle_diff) * turn_amount

		velocity = Vector2.from_angle(current_angle) * speed

	# Move
	position += velocity * delta
	rotation = velocity.angle()

	lifetime -= delta
	if lifetime <= 0:
		explode()

	queue_redraw()

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("platforms"):
		explode()
	elif body.is_in_group("player"):
		# Check if player has a shield that can block this projectile
		if _is_blocked_by_shield(body):
			# Blocked - destroy rocket without explosion damage
			_spawn_explosion()
			queue_free()
			return
		explode()

func _is_blocked_by_shield(player: Node2D) -> bool:
	# Check if player has an equipped tool with shield
	var tool = player.get("equipped_tool")
	if tool and tool.has_method("can_block_projectile"):
		# Pass the direction the projectile is traveling (toward player)
		if tool.can_block_projectile(velocity.normalized()):
			return true
	return false

func explode() -> void:
	# Check for player in explosion radius
	var space_state = get_world_2d().direct_space_state

	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 1  # Player layer

	var results = space_state.intersect_shape(query)

	for result in results:
		if result.collider.is_in_group("player"):
			result.collider.take_damage(damage)

	# Spawn explosion effect
	_spawn_explosion()

	# Screen shake
	EventBus.screen_shake.emit(8.0, 0.12)

	queue_free()

func _spawn_explosion() -> void:
	# Create explosion particles
	for i in range(10):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position
		particle.color = Color(1.0, 0.4, 0.1)
		particle.size = randf_range(6, 12)
		get_tree().current_scene.add_child(particle)

	# Create explosion circle visual
	var explosion = Node2D.new()
	explosion.set_script(preload("res://scripts/effects/explosion_circle.gd"))
	explosion.global_position = global_position
	explosion.radius = explosion_radius
	get_tree().current_scene.add_child(explosion)

func _draw() -> void:
	# Draw rocket body
	var points = PackedVector2Array()
	points.append(Vector2(size, 0))
	points.append(Vector2(-size * 0.7, -size * 0.5))
	points.append(Vector2(-size * 0.5, 0))
	points.append(Vector2(-size * 0.7, size * 0.5))
	draw_colored_polygon(points, color)

	# Draw fins
	draw_line(Vector2(-size * 0.5, 0), Vector2(-size, -size * 0.6), color * 0.8, 2.0)
	draw_line(Vector2(-size * 0.5, 0), Vector2(-size, size * 0.6), color * 0.8, 2.0)

	# Draw exhaust trail
	draw_line(Vector2(-size * 0.5, 0), Vector2(-size * 1.5, 0), Color(1, 0.6, 0.2, 0.7), 4.0)
	draw_line(Vector2(-size * 0.5, 0), Vector2(-size * 2, 0), Color(1, 0.8, 0.3, 0.4), 2.0)
