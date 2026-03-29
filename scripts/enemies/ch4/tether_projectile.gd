extends Area2D
class_name TetherProjectile
## Projectile that attaches to player and maintains pull force - Chapter 4

@export var speed: float = 1400.0
@export var pull_force: float = 300.0
@export var max_range: float = 600.0

var direction: Vector2 = Vector2.RIGHT
var owner_anchor: Node = null
var tether_attached: bool = false
var attached_player: Node = null
var distance_traveled: float = 0.0
var rope_points: Array[Vector2] = []

func _ready() -> void:
	collision_layer = 8    # Enemy projectile layer
	collision_mask = 1     # Player layer only

	_setup_collision_shape()
	body_entered.connect(_on_body_entered)

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if tether_attached:
		_handle_attached_state(delta)
	else:
		_handle_flying_state(delta)

	# Update rope visualization
	_update_rope_points()
	queue_redraw()

func _handle_flying_state(delta: float) -> void:
	# Move toward target
	global_position += direction * speed * delta
	distance_traveled += speed * delta

	# Check if exceeded max range
	if distance_traveled >= max_range:
		queue_free()

	# Check if anchor died
	if not is_instance_valid(owner_anchor) or owner_anchor.is_dead:
		queue_free()

func _handle_attached_state(delta: float) -> void:
	if not is_instance_valid(attached_player):
		_release_tether()
		return

	if not is_instance_valid(owner_anchor) or owner_anchor.is_dead:
		_release_tether()
		return

	# Keep projectile at player position
	global_position = attached_player.global_position

	# Apply pull force toward anchor
	var pull_dir = (owner_anchor.global_position - attached_player.global_position).normalized()
	attached_player.velocity += pull_dir * pull_force * delta

	# Check if rope is broken (player got too far)
	var dist = attached_player.global_position.distance_to(owner_anchor.global_position)
	if dist > max_range * 1.5:
		_release_tether()

func _on_body_entered(body: Node2D) -> void:
	if tether_attached:
		return

	if body.is_in_group("player"):
		_attach_to_player(body)

func _attach_to_player(player: Node2D) -> void:
	tether_attached = true
	attached_player = player
	set_deferred("monitoring", false)  # Stop detecting collisions (deferred for physics safety)

	EventBus.tether_attached.emit(owner_anchor, player)

func _release_tether() -> void:
	if attached_player and is_instance_valid(attached_player):
		EventBus.tether_released.emit(owner_anchor)
	queue_free()

func release() -> void:
	# Called by anchor when it dies
	_release_tether()

func _update_rope_points() -> void:
	rope_points.clear()

	if not is_instance_valid(owner_anchor):
		return

	var start = owner_anchor.global_position - global_position
	var end = Vector2.ZERO

	# Create rope with slight sag
	var num_points = 8
	for i in range(num_points + 1):
		var t = float(i) / num_points
		var point = start.lerp(end, t)

		# Add sag (parabolic curve)
		var sag = sin(t * PI) * 20.0
		point.y += sag

		rope_points.append(point)

func _draw() -> void:
	# Draw rope to anchor
	if rope_points.size() >= 2:
		for i in range(rope_points.size() - 1):
			var color = Color(0.6, 0.5, 0.3)
			if tether_attached:
				# Taut rope when attached - more red
				color = Color(0.8, 0.4, 0.2)
			draw_line(rope_points[i], rope_points[i + 1], color, 3.0)

	# Draw hook/anchor point
	if tether_attached:
		# Attached indicator
		draw_circle(Vector2.ZERO, 6, Color(1.0, 0.3, 0.0))
		draw_arc(Vector2.ZERO, 10, 0, TAU, 12, Color(1.0, 0.5, 0.0, 0.5), 2.0)
	else:
		# Flying hook
		var hook_dir = direction
		var hook_tip = hook_dir * 12
		var hook_left = hook_tip + Vector2(-hook_dir.y, hook_dir.x) * 6 - hook_dir * 8
		var hook_right = hook_tip + Vector2(hook_dir.y, -hook_dir.x) * 6 - hook_dir * 8

		draw_line(Vector2.ZERO, hook_tip, Color(0.7, 0.6, 0.4), 3.0)
		draw_line(hook_tip, hook_left, Color(0.7, 0.6, 0.4), 3.0)
		draw_line(hook_tip, hook_right, Color(0.7, 0.6, 0.4), 3.0)
