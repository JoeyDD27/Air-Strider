extends Area2D
class_name SludgeMortar
## Arcing projectile that spawns FireZone on impact - Chapter 4 (Subject 88 attack)

@export var speed: float = 400.0
@export var fire_zone_radius: float = 100.0
@export var fire_zone_duration: float = 8.0
@export var fire_zone_damage: int = 1

var target_position: Vector2 = Vector2.ZERO
var start_position: Vector2 = Vector2.ZERO
var flight_time: float = 0.0
var total_flight_time: float = 1.5
var peak_height: float = 200.0

const FIRE_ZONE_SCRIPT = preload("res://scripts/hazards/fire_zone.gd")

func _ready() -> void:
	collision_layer = 8    # Enemy projectile layer
	collision_mask = 1     # Player layer

	start_position = global_position
	_setup_collision_shape()

	# Calculate flight time based on distance
	var dist = start_position.distance_to(target_position)
	total_flight_time = dist / speed

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	flight_time += delta

	# Parabolic arc
	var t = flight_time / total_flight_time
	t = clamp(t, 0.0, 1.0)

	# Horizontal interpolation
	var new_pos = start_position.lerp(target_position, t)

	# Vertical arc (parabola)
	var arc_height = peak_height * (1.0 - pow(2.0 * t - 1.0, 2))
	new_pos.y -= arc_height

	global_position = new_pos

	# Rotation based on velocity direction
	if t < 1.0:
		var prev_t = max(0, t - 0.05)
		var prev_pos = start_position.lerp(target_position, prev_t)
		var prev_arc = peak_height * (1.0 - pow(2.0 * prev_t - 1.0, 2))
		prev_pos.y -= prev_arc
		rotation = (new_pos - prev_pos).angle()

	# Check if reached target
	if t >= 1.0:
		_impact()

	queue_redraw()

func _impact() -> void:
	# Spawn fire zone at impact location
	var fire_zone = Area2D.new()
	fire_zone.set_script(FIRE_ZONE_SCRIPT)
	fire_zone.radius = fire_zone_radius
	fire_zone.duration = fire_zone_duration
	fire_zone.damage_per_tick = fire_zone_damage
	fire_zone.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", fire_zone)

	# Impact effects
	EventBus.screen_shake.emit(4.0, 0.1)

	queue_free()

func _draw() -> void:
	# Sludge bomb visual
	var bomb_radius = 12.0

	# Main body (green sludge)
	draw_circle(Vector2.ZERO, bomb_radius, Color(0.3, 0.7, 0.2))

	# Darker core
	draw_circle(Vector2.ZERO, bomb_radius * 0.6, Color(0.2, 0.5, 0.1))

	# Dripping effect
	var drip_angle = -rotation + PI / 2  # Drips downward relative to world
	for i in range(3):
		var offset = Vector2.from_angle(drip_angle + randf_range(-0.3, 0.3)) * (bomb_radius + i * 4)
		draw_circle(offset, 4 - i, Color(0.3, 0.7, 0.2, 0.7 - i * 0.2))

	# Highlight
	draw_circle(Vector2(-3, -3), 4, Color(0.5, 0.9, 0.4, 0.5))
