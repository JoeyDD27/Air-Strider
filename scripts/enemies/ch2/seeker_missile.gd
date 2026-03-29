extends Area2D
class_name SeekerMissile
## Weak homing missile fired by Seeker-Beetle enemies
## Slower and less agile than boss rockets

var velocity: Vector2 = Vector2.ZERO
var speed: float = 200.0            # Slower than boss rockets (300)
var turn_speed: float = 1.5         # Less agile (vs 2.0)
var damage: int = 1
var lifetime: float = 4.0           # Shorter lifetime

var target: Node2D = null
var size: float = 10.0
var color: Color = Color(0.8, 0.4, 1.0)  # Purple

func _ready() -> void:
	collision_layer = 8   # Enemy projectiles layer
	collision_mask = 1 | 2  # Player and platforms

	body_entered.connect(_on_body_entered)

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

	# Initial upward velocity
	velocity = Vector2(0, -speed)

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
		queue_free()

	queue_redraw()

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("platforms"):
		_spawn_hit_effect()
		queue_free()
	elif body.is_in_group("player"):
		# Check if player has a shield that can block this projectile
		if _is_blocked_by_shield(body):
			_spawn_hit_effect()
			queue_free()
			return
		body.take_damage(damage)
		_spawn_hit_effect()
		queue_free()

func _is_blocked_by_shield(player: Node2D) -> bool:
	# Check if player has an equipped tool with shield
	var tool = player.get("equipped_tool")
	if tool and tool.has_method("can_block_projectile"):
		# Pass the direction the projectile is traveling (toward player)
		if tool.can_block_projectile(velocity.normalized()):
			return true
	return false

func _spawn_hit_effect() -> void:
	# Small particle burst on hit
	for i in range(4):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position
		particle.color = color
		particle.size = randf_range(3, 6)
		get_tree().current_scene.add_child(particle)

func _draw() -> void:
	# Draw small missile shape
	var points = PackedVector2Array()
	points.append(Vector2(size, 0))
	points.append(Vector2(-size * 0.5, -size * 0.4))
	points.append(Vector2(-size * 0.3, 0))
	points.append(Vector2(-size * 0.5, size * 0.4))
	draw_colored_polygon(points, color)

	# Draw trail
	draw_line(Vector2(-size * 0.3, 0), Vector2(-size, 0), Color(1, 0.6, 0.8, 0.6), 2.0)
