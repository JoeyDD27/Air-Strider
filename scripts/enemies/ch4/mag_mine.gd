extends EnemyBase
class_name MagMine
## Floating mine that passes through walls - Chapter 4

# Frame mapping: 0-2 idle, 3-4 tracking, 5 close, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_TRACKING = 2
const FRAME_CLOSE = 5

@export var acceleration: float = 200.0
@export var max_speed: float = 150.0
@export var explosion_radius: float = 150.0
@export var explosion_damage: int = 3

var pulse_timer: float = 0.0
var trail_positions: Array[Vector2] = []
var max_trail_length: int = 8

const EXPLOSION_SCRIPT = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	super._ready()
	max_health = 1
	health = max_health
	reward = 20
	_setup_sprite()

	# Override collision mask - no platforms, just player projectiles
	collision_mask = 16  # Player projectiles only (no layer 2 platforms)

	# Setup contact detection area for player collision
	_setup_contact_area()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	pulse_timer += delta

	# Store trail position
	if trail_positions.size() == 0 or global_position.distance_to(trail_positions[0]) > 10:
		trail_positions.insert(0, global_position)
		if trail_positions.size() > max_trail_length:
			trail_positions.pop_back()

	# Calculate acceleration toward player (no pathfinding)
	if player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		velocity += dir * acceleration * delta
		velocity = velocity.limit_length(max_speed)

	# Direct position update - bypasses platform collision entirely
	global_position += velocity * delta

	# Keep within reasonable bounds (room boundaries)
	# This is a soft constraint - mine can still phase through internal walls
	global_position.x = clamp(global_position.x, -100, 3000)
	global_position.y = clamp(global_position.y, -100, 2000)

	# Check for collision with player (manual check since we bypass move_and_slide)
	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 40:  # Contact range (increased for reliability)
			_contact_explosion()

	# Update sprite
	if anim_sprite:
		if player_ref:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < 100:
				_set_sprite_frame(FRAME_CLOSE)
			else:
				_set_sprite_frame(FRAME_TRACKING)
		else:
			_set_sprite_frame(FRAME_IDLE)

	queue_redraw()

func _setup_contact_area() -> void:
	var contact_area = Area2D.new()
	contact_area.name = "ContactArea"
	contact_area.collision_layer = 0
	contact_area.collision_mask = 1  # Player layer

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0  # Contact radius
	shape.shape = circle

	contact_area.add_child(shape)
	add_child(contact_area)

	contact_area.body_entered.connect(_on_contact_area_body_entered)

func _on_contact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		_contact_explosion()

func _contact_explosion() -> void:
	if is_dead:
		return
	# Explode on contact with player
	die()

func die() -> void:
	is_dead = true

	# Death rattle: Small explosion
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	var explosion = Area2D.new()
	explosion.set_script(EXPLOSION_SCRIPT)
	explosion.radius = explosion_radius
	explosion.damage = explosion_damage
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)

func _draw() -> void:
	# Draw trail (always visible)
	for i in range(trail_positions.size()):
		var alpha = 1.0 - (float(i) / trail_positions.size())
		var local_pos = trail_positions[i] - global_position
		var size = 8 * (1.0 - float(i) / trail_positions.size())
		draw_circle(local_pos, size, Color(0.3, 0.8, 1.0, alpha * 0.3))

	var pulse = sin(pulse_timer * 5.0) * 0.15 + 1.0
	var base_radius = 18.0 * pulse

	if not anim_sprite:
		# Main body - spiked sphere

		# Core glow
		draw_circle(Vector2.ZERO, base_radius * 0.6, Color(0.2, 0.6, 1.0, 0.8))

		# Outer shell
		draw_arc(Vector2.ZERO, base_radius, 0, TAU, 32, Color(0.5, 0.8, 1.0), 3.0)

		# Spikes
		var num_spikes = 8
		for i in range(num_spikes):
			var angle = (float(i) / num_spikes) * TAU + pulse_timer * 0.5
			var inner = Vector2.from_angle(angle) * base_radius
			var outer = Vector2.from_angle(angle) * (base_radius + 12)
			draw_line(inner, outer, Color(0.7, 0.9, 1.0), 3.0)

			# Spike tip glow
			draw_circle(outer, 3, Color(0.4, 0.7, 1.0, 0.6))

	# Magnetic field indicator (faint rings) - always visible
	var field_pulse = sin(pulse_timer * 2.0) * 0.2 + 0.8
	draw_arc(Vector2.ZERO, base_radius + 25, 0, TAU, 16, Color(0.3, 0.6, 1.0, 0.2 * field_pulse), 1.0)

	# Direction indicator (toward player) - always visible
	if player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		var indicator_pos = dir * (base_radius + 8)
		draw_circle(indicator_pos, 4, Color(1.0, 0.3, 0.3, 0.7))
