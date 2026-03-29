extends Area2D
class_name PlayerProjectile
## Projectile fired by the player's charged weapon

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1200.0
var damage: int = 1
var lifetime: float = 2.0

func _ready() -> void:
	add_to_group("player_projectiles")

	# Set collision layers
	collision_layer = 16  # Player projectiles layer (layer 5)
	collision_mask = 4  # Enemies only (bullets pass through platforms)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			var hit = body.take_damage(damage)
			if hit:
				queue_free()
			# If shielded, projectile passes through

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			var hit = area.take_damage(damage)
			if hit:
				queue_free()
			# If shielded, projectile passes through
		# Note: Boss hitboxes handle damage via their own area_entered signal
		# Do NOT add boss_ref routing here - it causes double damage

func _draw() -> void:
	# Draw as yellow/orange elongated shape
	var charge_color = Color(1.0, 0.8, 0.2)  # Yellow-orange
	draw_circle(Vector2.ZERO, 16, charge_color)
	draw_line(Vector2.ZERO, -direction * 15, charge_color, 4.0)
