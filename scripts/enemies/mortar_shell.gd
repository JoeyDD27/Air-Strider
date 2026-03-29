extends Area2D
class_name MortarShell
## Explosive shell fired by Mortar enemy

var velocity: Vector2 = Vector2.ZERO
var shell_gravity: float = 980.0
var explosion_radius: float = 80.0
var damage: int = 1
var lifetime: float = 5.0

var size: float = 12.0
var color: Color = Color(1.0, 0.5, 0.0)  # Orange

func _ready() -> void:
	collision_layer = 8  # Projectiles layer
	collision_mask = 1 | 2  # Player and platforms

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += shell_gravity * delta

	# Move
	position += velocity * delta

	# Rotate to face velocity direction
	rotation = velocity.angle()

	lifetime -= delta
	if lifetime <= 0:
		explode()

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("platforms"):
		explode()
	elif body.is_in_group("player"):
		# Check if player has a shield that can block this projectile
		if _is_blocked_by_shield(body):
			# Blocked - destroy shell without explosion damage
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
	EventBus.screen_shake.emit(10.0, 0.15)

	queue_free()

func _spawn_explosion() -> void:
	# Create explosion particles
	for i in range(12):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position
		particle.color = Color(1.0, 0.5, 0.0)  # Orange
		particle.size = randf_range(8, 16)
		get_tree().current_scene.add_child(particle)

	# Create explosion circle visual
	var explosion = Node2D.new()
	explosion.set_script(preload("res://scripts/effects/explosion_circle.gd"))
	explosion.global_position = global_position
	explosion.radius = explosion_radius
	get_tree().current_scene.add_child(explosion)

func _draw() -> void:
	# Draw shell shape
	var points = PackedVector2Array()
	points.append(Vector2(size, 0))
	points.append(Vector2(-size / 2, -size / 2))
	points.append(Vector2(-size / 2, size / 2))
	draw_colored_polygon(points, color)

	# Draw trail
	draw_line(Vector2.ZERO, Vector2(-size * 2, 0), Color(1, 0.8, 0.3, 0.5), 3.0)
