extends Area2D
class_name SniperBullet
## Fast bullet fired by sniper enemies

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1800.0  # Very fast bullet
var damage: int = 1
var lifetime: float = 3.0

func _ready() -> void:
	# Set collision layers - enemy projectile
	collision_layer = 8  # Projectiles layer (layer 4)
	collision_mask = 1  # Player only (bullets pass through platforms)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Check if player has a shield that can block this projectile
		if _is_blocked_by_shield(body):
			queue_free()
			return
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func _is_blocked_by_shield(player: Node2D) -> bool:
	# Check if player has an equipped tool with shield
	var tool = player.get("equipped_tool")
	if tool and tool.has_method("can_block_projectile"):
		# Pass the direction the projectile is traveling (toward player)
		if tool.can_block_projectile(direction):
			return true
	return false

func _on_area_entered(_area: Area2D) -> void:
	pass  # Don't interact with other areas

func _draw() -> void:
	# Draw as red elongated bullet
	var bullet_color = Color(1.0, 0.2, 0.2)  # Red
	draw_circle(Vector2.ZERO, 5, bullet_color)
	draw_line(Vector2.ZERO, -direction * 12, bullet_color, 3.0)
