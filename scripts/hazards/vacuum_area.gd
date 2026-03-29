extends Area2D
class_name VacuumArea
## Pulls player toward center, then explodes - Chapter 4 (Reactor-Beam death rattle)

@export var radius: float = 200.0
@export var duration: float = 1.5
@export var pull_strength: float = 400.0
@export var final_explosion_radius: float = 180.0
@export var final_explosion_damage: int = 3

var time_elapsed: float = 0.0
var has_exploded: bool = false

const EXPLOSION_SCENE = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	collision_layer = 32  # Hazards layer
	collision_mask = 1    # Player layer
	monitoring = true

	_setup_collision_shape()

	# Emit signal
	EventBus.vacuum_pull_started.emit(global_position, radius, duration)

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	time_elapsed += delta

	# Pull player toward center
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		var dist = global_position.distance_to(player.global_position)
		if dist <= radius and dist > 10:  # Avoid division by zero
			var pull_dir = (global_position - player.global_position).normalized()
			# Pull force increases as time progresses (more urgent near explosion)
			var urgency = 0.5 + (time_elapsed / duration) * 0.5
			player.velocity += pull_dir * pull_strength * urgency * delta

	# Explode after duration
	if time_elapsed >= duration and not has_exploded:
		_final_explosion()

func _final_explosion() -> void:
	has_exploded = true
	EventBus.vacuum_pull_ended.emit(global_position)

	# Spawn the final explosion
	var explosion = Area2D.new()
	explosion.set_script(EXPLOSION_SCENE)
	explosion.radius = final_explosion_radius
	explosion.damage = final_explosion_damage
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)

	# Screen effects
	EventBus.screen_shake.emit(12.0, 0.3)

	queue_free()

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var progress = time_elapsed / duration
	var pulse = sin(Time.get_ticks_msec() * 0.015) * 0.1 + 0.9

	# Swirling vortex effect - multiple rings spiraling inward
	var num_rings = 5
	for i in range(num_rings):
		var ring_progress = fmod(progress * 2.0 + float(i) / num_rings, 1.0)
		var ring_radius = radius * (1.0 - ring_progress)
		var ring_alpha = (1.0 - ring_progress) * 0.6

		# Spiral angle
		var angle_offset = ring_progress * TAU * 2.0
		draw_arc(Vector2.ZERO, ring_radius, angle_offset, angle_offset + PI, 16,
			Color(0.5, 0.0, 1.0, ring_alpha * pulse), 3.0)

	# Center glow (intensifies over time)
	var center_intensity = 0.3 + progress * 0.7
	var center_radius = 30 + progress * 20
	draw_circle(Vector2.ZERO, center_radius, Color(0.8, 0.3, 1.0, center_intensity * pulse))

	# Warning outer ring
	var warning_alpha = 0.5 + sin(Time.get_ticks_msec() * 0.02) * 0.3
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.0, 0.5, warning_alpha), 2.0)

	# Particle trails being sucked in
	var num_particles = 8
	for i in range(num_particles):
		var angle = (float(i) / num_particles) * TAU + Time.get_ticks_msec() * 0.003
		var particle_progress = fmod(Time.get_ticks_msec() * 0.001 + float(i) * 0.1, 1.0)
		var particle_dist = radius * (1.0 - particle_progress)
		var particle_pos = Vector2.from_angle(angle) * particle_dist
		var particle_size = 5 * (1.0 - particle_progress)
		draw_circle(particle_pos, particle_size, Color(0.7, 0.4, 1.0, 0.8 * (1.0 - particle_progress)))
