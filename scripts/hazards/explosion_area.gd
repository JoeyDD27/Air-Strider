extends Area2D
class_name ExplosionArea
## Instant explosion damage area with visual effect - Chapter 4

@export var radius: float = 80.0
@export var damage: int = 1

var lifetime: float = 0.3  # Visual duration before removal
var time_elapsed: float = 0.0
var has_damaged: bool = false
var damage_check_frames: int = 0  # Track frames for damage check

func _ready() -> void:
	collision_layer = 32  # Hazards layer
	collision_mask = 1    # Player layer
	monitoring = true

	_setup_collision_shape()

	# Emit signal
	EventBus.explosion_triggered.emit(global_position, radius, damage)
	EventBus.screen_shake.emit(6.0, 0.15)

	# Also do a manual distance check for immediate damage
	_deal_damage_by_distance()

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func _deal_damage_by_distance() -> void:
	# Manual distance check - more reliable than Area2D overlap on first frame
	if has_damaged:
		return

	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist <= radius:
				has_damaged = true
				player.take_damage(damage, "hazard")
				return

func _deal_damage() -> void:
	if has_damaged:
		return

	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			has_damaged = true
			body.take_damage(damage, "hazard")
			return

func _process(delta: float) -> void:
	time_elapsed += delta

	# Check for damage multiple times in case player enters explosion area
	if not has_damaged:
		damage_check_frames += 1
		if damage_check_frames <= 3:  # Check for first 3 frames
			_deal_damage()
		if not has_damaged:
			_deal_damage_by_distance()

	queue_redraw()

	if time_elapsed >= lifetime:
		queue_free()

func _draw() -> void:
	# Expanding ring effect
	var progress = time_elapsed / lifetime
	var current_radius = radius * (0.3 + progress * 0.7)
	var alpha = 1.0 - progress

	# Outer ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color(1.0, 0.5, 0.0, alpha * 0.8), 4.0)

	# Inner glow
	var inner_radius = current_radius * 0.6
	draw_circle(Vector2.ZERO, inner_radius, Color(1.0, 0.8, 0.2, alpha * 0.5))

	# Core
	var core_radius = current_radius * 0.3
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 1.0, 0.8, alpha * 0.7))
