extends Area2D
class_name FireZone
## Persistent fire damage zone - Chapter 4 (spawned by Fuel-Tank death)

@export var radius: float = 120.0
@export var duration: float = 10.0
@export var damage_per_tick: int = 1
@export var damage_interval: float = 0.5

var time_elapsed: float = 0.0
var damage_timer: float = 0.0
var flame_particles: Array[Dictionary] = []

func _ready() -> void:
	collision_layer = 32  # Hazards layer
	collision_mask = 1    # Player layer
	monitoring = true

	_setup_collision_shape()
	body_entered.connect(_on_body_entered)

	# Initialize flame particles
	_setup_flame_particles()

	# Emit signal
	EventBus.fire_zone_spawned.emit(global_position, duration)

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func _setup_flame_particles() -> void:
	for i in range(12):
		var angle = randf() * TAU
		var dist = randf() * radius * 0.8
		flame_particles.append({
			"offset": Vector2.from_angle(angle) * dist,
			"phase": randf() * TAU,
			"size": randf_range(15, 30)
		})

func _process(delta: float) -> void:
	time_elapsed += delta
	queue_redraw()

	if time_elapsed >= duration:
		queue_free()

func _physics_process(delta: float) -> void:
	damage_timer += delta

	# Continuous damage to player in zone
	if damage_timer >= damage_interval:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				body.take_damage(damage_per_tick, "fire")
				damage_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage_per_tick, "fire")
		damage_timer = 0.0

func _draw() -> void:
	var remaining = 1.0 - (time_elapsed / duration)
	var fade_alpha = min(remaining * 2.0, 1.0)  # Start fading at 50% duration

	# Draw base fire area
	draw_circle(Vector2.ZERO, radius, Color(0.8, 0.2, 0.0, 0.3 * fade_alpha))

	# Draw flame particles
	var time = Time.get_ticks_msec() * 0.001
	for particle in flame_particles:
		var wave = sin(time * 3.0 + particle.phase)
		var flame_height = particle.size * (0.8 + wave * 0.4)
		var pos = particle.offset

		# Flame shape (triangle pointing up)
		var points = PackedVector2Array([
			pos + Vector2(-particle.size * 0.3, 0),
			pos + Vector2(particle.size * 0.3, 0),
			pos + Vector2(0, -flame_height)
		])

		# Orange-yellow gradient based on height
		var color = Color(1.0, 0.4 + wave * 0.3, 0.0, 0.7 * fade_alpha)
		draw_colored_polygon(points, color)

	# Draw border ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.3, 0.0, 0.6 * fade_alpha), 3.0)

	# Warning text effect (pulsing)
	var pulse = sin(time * 4.0) * 0.2 + 0.8
	draw_arc(Vector2.ZERO, radius * 0.9, 0, TAU, 16, Color(1.0, 0.6, 0.0, 0.3 * pulse * fade_alpha), 2.0)
