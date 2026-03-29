extends EnemyBase
class_name ChainLink
## Slow floating mine with chain reaction death - Chapter 4

# Frame mapping: 0-2 idle/drift, 3-4 near chain, 5 triggered, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_NEAR_CHAIN = 3
const FRAME_TRIGGERED = 5

@export var drift_speed: float = 80.0
@export var chain_radius: float = 150.0
@export var explosion_damage: int = 3
@export var flocking_separation: float = 60.0
@export var contact_radius: float = 40.0

var drift_direction: Vector2 = Vector2.ZERO
var hover_offset: float = 0.0
var pulse_timer: float = 0.0
var nearby_links: Array[Node] = []

const EXPLOSION_SCRIPT = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	super._ready()
	max_health = 1
	health = max_health
	reward = 25
	_setup_sprite()

	# Add to chain_link group for chain reaction detection
	add_to_group("chain_link")

	# Random initial drift direction
	drift_direction = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)).normalized()
	hover_offset = randf() * TAU

	# Setup contact detection area for player collision
	_setup_contact_area()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	pulse_timer += delta
	hover_offset += delta * 2.0

	# Update nearby chain-links for visualization
	_update_nearby_links()

	# Calculate movement with flocking
	var final_velocity = _calculate_flocking_velocity(delta)

	# Apply movement (floating, no gravity)
	velocity = final_velocity
	move_and_slide()

	# Check for contact with player
	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < contact_radius:
			_contact_explosion()

	# Update sprite
	if anim_sprite:
		if nearby_links.size() > 0:
			_set_sprite_frame(FRAME_NEAR_CHAIN)
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
	circle.radius = contact_radius  # Use the export variable (default 40)
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

func _calculate_flocking_velocity(delta: float) -> Vector2:
	var result = Vector2.ZERO

	# Drift toward player (slowly)
	if player_ref:
		var to_player = (player_ref.global_position - global_position).normalized()
		result += to_player * drift_speed

	# Separation from other chain-links
	var chain_links = get_tree().get_nodes_in_group("chain_link")
	var separation = Vector2.ZERO
	var nearby_count = 0

	for link in chain_links:
		if link == self or not is_instance_valid(link) or link.is_dead:
			continue
		var dist = global_position.distance_to(link.global_position)
		if dist < flocking_separation and dist > 0:
			var away = (global_position - link.global_position).normalized()
			separation += away * (flocking_separation - dist) / flocking_separation
			nearby_count += 1

	if nearby_count > 0:
		result += separation * 50.0  # Separation strength

	# Hover bob
	result.y += sin(hover_offset) * 20.0

	return result

func _update_nearby_links() -> void:
	nearby_links.clear()
	var chain_links = get_tree().get_nodes_in_group("chain_link")
	for link in chain_links:
		if link == self or not is_instance_valid(link) or link.is_dead:
			continue
		var dist = global_position.distance_to(link.global_position)
		if dist <= chain_radius * 1.2:  # Slightly larger for visual
			nearby_links.append(link)

func die() -> void:
	is_dead = true

	# Death rattle: Chain reaction explosion
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	# Spawn explosion
	var explosion = Area2D.new()
	explosion.set_script(EXPLOSION_SCRIPT)
	explosion.radius = chain_radius
	explosion.damage = explosion_damage
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)

	# Chain reaction: Damage nearby Chain-Links
	var chain_links = get_tree().get_nodes_in_group("chain_link")
	var triggered_links: Array[Node] = []

	for link in chain_links:
		if link == self or not is_instance_valid(link) or link.is_dead:
			continue
		var dist = global_position.distance_to(link.global_position)
		if dist <= chain_radius:
			triggered_links.append(link)
			# Use call_deferred to avoid modifying during iteration
			link.call_deferred("take_damage", 999)

	if triggered_links.size() > 0:
		EventBus.chain_reaction_started.emit(self, global_position)

	# Screen shake scales with chain size
	var shake_intensity = 5.0 + triggered_links.size() * 2.0
	EventBus.screen_shake.emit(shake_intensity, 0.15)

func _draw() -> void:
	# Draw connection lines to nearby chain-links (always visible)
	for link in nearby_links:
		if is_instance_valid(link) and not link.is_dead:
			var local_pos = link.global_position - global_position
			var dist = local_pos.length()
			var alpha = 1.0 - (dist / (chain_radius * 1.2))

			# Energy beam connection
			var beam_color = Color(1.0, 0.5, 0.0, alpha * 0.5)
			draw_line(Vector2.ZERO, local_pos, beam_color, 2.0)

			# Pulsing energy particles along beam
			var num_particles = 3
			for i in range(num_particles):
				var t = fmod(pulse_timer * 2.0 + float(i) / num_particles, 1.0)
				var particle_pos = local_pos * t
				draw_circle(particle_pos, 3, Color(1.0, 0.7, 0.2, alpha * 0.7))

	var pulse = sin(pulse_timer * 3.0) * 0.1 + 1.0
	var base_radius = 15.0 * pulse

	if not anim_sprite:
		# Main body - spherical drone

		# Outer shell (semi-transparent)
		draw_arc(Vector2.ZERO, base_radius + 5, 0, TAU, 24, Color(0.8, 0.5, 0.2, 0.4), 2.0)

		# Core body
		draw_circle(Vector2.ZERO, base_radius, Color(0.3, 0.3, 0.35))

		# Glowing center
		var glow_pulse = sin(pulse_timer * 4.0) * 0.2 + 0.8
		draw_circle(Vector2.ZERO, base_radius * 0.5, Color(1.0, 0.6, 0.0, glow_pulse))

		# Green liquid tank
		var tank_rect = Rect2(-6, -base_radius * 0.7, 12, base_radius)
		draw_rect(tank_rect, Color(0.2, 0.8, 0.2, 0.6))

		# Small fins/wings
		var fin_angle = pulse_timer * 0.5
		for i in range(3):
			var angle = fin_angle + (float(i) / 3) * TAU
			var fin_start = Vector2.from_angle(angle) * base_radius
			var fin_end = Vector2.from_angle(angle) * (base_radius + 8)
			draw_line(fin_start, fin_end, Color(0.5, 0.5, 0.5), 3.0)

	# Chain reaction indicator ring (always visible)
	var indicator_alpha = 0.15 + sin(pulse_timer * 2.0) * 0.1
	draw_arc(Vector2.ZERO, chain_radius, 0, TAU, 32, Color(1.0, 0.5, 0.0, indicator_alpha), 1.0)
