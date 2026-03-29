extends Area2D
class_name TriGunnerBullet
## High-speed bullet from Tri-Gunner turret

var direction: Vector2 = Vector2.RIGHT
var speed: float = 2000.0
var damage: int = 1
var lifetime: float = 3.0

var age: float = 0.0
var trail_positions: Array = []
const MAX_TRAIL = 5

func _ready() -> void:
	# Set collision layers
	collision_layer = 8   # Projectiles (layer 4)
	collision_mask = 1    # Player only

	# Connect signal
	body_entered.connect(_on_body_entered)

	# Set rotation to match direction
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# Move bullet
	global_position += direction * speed * delta

	# Track trail
	trail_positions.push_front(global_position)
	if trail_positions.size() > MAX_TRAIL:
		trail_positions.pop_back()

	# Age and destroy
	age += delta
	if age >= lifetime:
		queue_free()

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Check for shield tool
		if _is_blocked_by_shield(body):
			queue_free()
			return

		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)

		queue_free()

func _is_blocked_by_shield(player: Node2D) -> bool:
	var tool = player.get("equipped_tool")
	if tool and tool.has_method("can_block_projectile"):
		if tool.can_block_projectile(direction):
			return true
	return false

func _draw() -> void:
	# Draw bullet core
	var bullet_color = Color(1.0, 0.6, 0.2)  # Orange-yellow
	draw_circle(Vector2.ZERO, 4, bullet_color)

	# Draw glow
	var glow_color = Color(1.0, 0.4, 0.1, 0.5)
	draw_circle(Vector2.ZERO, 8, glow_color)

	# Draw trail
	for i in range(trail_positions.size()):
		var trail_pos = trail_positions[i] - global_position
		var alpha = 1.0 - (float(i) / MAX_TRAIL)
		var trail_color = Color(1.0, 0.5, 0.2, alpha * 0.5)
		var trail_size = 3.0 * (1.0 - float(i) / MAX_TRAIL)
		draw_circle(trail_pos, trail_size, trail_color)
