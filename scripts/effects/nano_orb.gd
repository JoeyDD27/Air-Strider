extends Area2D
class_name NanoOrb
## Healing orb that flies toward the player and heals 1 HP on contact

@export var speed: float = 600.0  # 50% faster
@export var heal_amount: int = 1
@export var acceleration: float = 2400.0  # 200% stronger homing (3x original)
@export var max_speed: float = 900.0  # 50% faster
@export var lifetime: float = 10.0  # Auto-despawn after this time

var target: Node2D = null
var velocity: Vector2 = Vector2.ZERO
var orb_color: Color = Color(0.8, 0.2, 0.2)  # Red healing orb
var size: float = 10.0
var pulse_timer: float = 0.0
var age: float = 0.0

func _ready() -> void:
	add_to_group("nano_orbs")
	_setup_collision()
	body_entered.connect(_on_body_entered)

	# Find player if no target set
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0]

	# Initial random velocity (slight scatter before homing)
	velocity = Vector2(randf_range(-100, 100), randf_range(-200, -100))

func _setup_collision() -> void:
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = size
	collision.shape = shape
	add_child(collision)

	# Orb layer - detect player
	collision_layer = 0
	collision_mask = 1  # Player layer
	monitoring = true
	monitorable = false

func _physics_process(delta: float) -> void:
	age += delta
	pulse_timer += delta

	# Auto-despawn after lifetime
	if age >= lifetime:
		queue_free()
		return

	# Home toward target
	if is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		velocity += direction * acceleration * delta
		velocity = velocity.limit_length(max_speed)

	# Move
	global_position += velocity * delta

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_heal_player()
		queue_free()

func _heal_player() -> void:
	# Heal the player
	if GameManager.player_health < GameManager.player_max_health:
		GameManager.player_health = min(GameManager.player_health + heal_amount, GameManager.player_max_health)
		EventBus.player_damaged.emit(GameManager.player_health, GameManager.player_max_health)

	# Visual/audio feedback could be added here
	EventBus.module_effect_triggered.emit("nano_orb", {"healed": heal_amount})

func _draw() -> void:
	# Pulsing orb effect
	var pulse = sin(pulse_timer * 8) * 0.2 + 0.8
	var draw_size = size * pulse

	# Outer glow
	draw_circle(Vector2.ZERO, draw_size + 4, Color(orb_color.r, orb_color.g, orb_color.b, 0.3))

	# Main orb
	draw_circle(Vector2.ZERO, draw_size, orb_color)

	# Inner highlight
	draw_circle(Vector2(-2, -2), draw_size * 0.4, Color(1, 0.5, 0.5))

	# Cross/plus symbol for healing
	var cross_color = Color.WHITE
	draw_line(Vector2(-4, 0), Vector2(4, 0), cross_color, 2.0)
	draw_line(Vector2(0, -4), Vector2(0, 4), cross_color, 2.0)
