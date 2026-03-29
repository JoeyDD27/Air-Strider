extends EnemyBase
class_name Overcharger
## Links to nearby enemy and buffs them - kills linked target on death - Chapter 4

# Frame mapping: 0-2 idle/searching, 3-4 linking, 5 linked/active, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_SEARCHING = 2
const FRAME_LINKING = 3
const FRAME_LINKED = 5

@export var link_range: float = 300.0
@export var speed_buff: float = 1.5  # 50% faster
@export var explosion_radius_buff: float = 1.3  # 30% larger explosions

var linked_enemy: Node = null
var link_beam_offset: float = 0.0
var pulse_timer: float = 0.0
var electric_arcs: Array[Dictionary] = []
var original_cooldown_multiplier: float = 1.0

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = 60
	_setup_sprite()

	# Initialize electric arc visuals
	for i in range(4):
		electric_arcs.append({
			"offset": randf() * TAU,
			"amplitude": randf_range(10, 20)
		})

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	pulse_timer += delta
	link_beam_offset += delta * 8.0

	# Manage linked enemy
	_update_link()

	# Floating movement (hover in place)
	var hover = sin(pulse_timer * 2.0) * 30.0
	velocity.y = hover

	move_and_slide()

	# Update sprite
	if anim_sprite:
		if linked_enemy and is_instance_valid(linked_enemy):
			_set_sprite_frame(FRAME_LINKED)
		else:
			_set_sprite_frame(FRAME_SEARCHING)

	queue_redraw()

func _update_link() -> void:
	# Check if current link is still valid
	if linked_enemy != null:
		if not is_instance_valid(linked_enemy) or linked_enemy.is_dead:
			_clear_link()
		else:
			var dist = global_position.distance_to(linked_enemy.global_position)
			if dist > link_range * 1.2:
				_clear_link()
			else:
				# Keep applying buffs
				_apply_buffs()
				return

	# Find new link target
	_find_new_link_target()

func _find_new_link_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node = null
	var closest_dist: float = link_range

	for enemy in enemies:
		# Skip self and other Overchargers
		if enemy == self:
			continue
		if enemy is Overcharger:
			continue
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy

	if closest_enemy:
		_establish_link(closest_enemy)

func _establish_link(target: Node) -> void:
	linked_enemy = target

	# Store original values for restoration
	if "cooldown_multiplier" in target:
		original_cooldown_multiplier = target.cooldown_multiplier

	EventBus.overcharger_linked.emit(self, target)

func _apply_buffs() -> void:
	if not is_instance_valid(linked_enemy):
		return

	# Apply speed buff via cooldown multiplier (lower = faster)
	if "cooldown_multiplier" in linked_enemy:
		linked_enemy.cooldown_multiplier = 1.0 / speed_buff

	# Apply explosion radius buff if enemy has it
	# Note: This requires enemies to check this property
	if "explosion_radius" in linked_enemy:
		# Don't stack - just set to buffed value
		pass  # Applied once at link time

func _clear_link() -> void:
	if is_instance_valid(linked_enemy):
		# Restore original cooldown
		if "cooldown_multiplier" in linked_enemy:
			linked_enemy.cooldown_multiplier = original_cooldown_multiplier

	linked_enemy = null

func die() -> void:
	is_dead = true

	# Death rattle: Kill linked enemy instantly
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	if linked_enemy and is_instance_valid(linked_enemy) and not linked_enemy.is_dead:
		# Instant kill linked target (triggers THEIR death rattle!)
		EventBus.overcharger_detonated.emit(self, linked_enemy)

		# Deal massive damage to kill them
		linked_enemy.take_damage(9999)

		# Screen shake for dramatic detonation
		EventBus.screen_shake.emit(8.0, 0.2)

func _draw() -> void:
	# Draw link beam to target (always visible)
	if linked_enemy and is_instance_valid(linked_enemy):
		var target_pos = linked_enemy.global_position - global_position
		_draw_energy_beam(Vector2.ZERO, target_pos)

	var body_height = 40.0
	var body_width = 25.0

	if not anim_sprite:
		# Main body - floating pylon

		# Outer shell (hexagonal-ish)
		var hex_points = PackedVector2Array()
		for i in range(6):
			var angle = (float(i) / 6) * TAU - PI / 2
			var radius = body_width / 2 if i % 2 == 0 else body_width / 2 - 5
			hex_points.append(Vector2.from_angle(angle) * radius + Vector2(0, -body_height / 2))
		draw_colored_polygon(hex_points, Color(0.25, 0.25, 0.3))

		# Energy core
		var core_pulse = sin(pulse_timer * 4.0) * 0.2 + 0.8
		var core_color = Color(0.8, 0.4, 1.0, core_pulse)
		if linked_enemy:
			core_color = Color(1.0, 0.8, 0.2, core_pulse)  # Yellow when linked

		draw_circle(Vector2(0, -body_height / 2), 10, core_color)
		draw_circle(Vector2(0, -body_height / 2), 6, Color(1.0, 1.0, 1.0, core_pulse * 0.8))

		# Top and bottom caps
		draw_circle(Vector2(0, -body_height + 5), 8, Color(0.3, 0.3, 0.35))
		draw_circle(Vector2(0, -5), 8, Color(0.3, 0.3, 0.35))

		# Antenna
		draw_line(Vector2(0, -body_height + 5), Vector2(0, -body_height - 10), Color(0.4, 0.4, 0.4), 2.0)
		var antenna_glow = Color(0.5, 0.3, 1.0, 0.8) if not linked_enemy else Color(1.0, 0.6, 0.0, 0.8)
		draw_circle(Vector2(0, -body_height - 12), 4, antenna_glow)

	# Electric arcs around body (always visible)
	for arc in electric_arcs:
		var arc_start_angle = pulse_timer * 2.0 + arc.offset
		var arc_end_angle = arc_start_angle + PI / 2
		var arc_radius = body_width / 2 + arc.amplitude * sin(pulse_timer * 3.0 + arc.offset)
		draw_arc(Vector2(0, -body_height / 2), arc_radius, arc_start_angle, arc_end_angle, 8,
			Color(0.6, 0.4, 1.0, 0.6), 2.0)

	# Link range indicator (faint) - always visible
	if not linked_enemy:
		var range_alpha = 0.1 + sin(pulse_timer) * 0.05
		draw_arc(Vector2(0, -body_height / 2), link_range, 0, TAU, 32, Color(0.5, 0.3, 1.0, range_alpha), 1.0)

func _draw_energy_beam(start: Vector2, end: Vector2) -> void:
	var beam_length = start.distance_to(end)
	var beam_dir = (end - start).normalized()

	# Main beam
	draw_line(start, end, Color(1.0, 0.8, 0.2, 0.8), 3.0)

	# Energy particles flowing along beam
	var num_particles = 5
	for i in range(num_particles):
		var t = fmod(link_beam_offset * 0.5 + float(i) / num_particles, 1.0)
		var particle_pos = start.lerp(end, t)

		# Oscillate perpendicular to beam
		var perp = Vector2(-beam_dir.y, beam_dir.x)
		var wave = sin(t * TAU * 3 + link_beam_offset) * 8
		particle_pos += perp * wave

		draw_circle(particle_pos, 4, Color(1.0, 0.9, 0.3, 0.9))

	# Glow at connection points
	draw_circle(start, 8, Color(1.0, 0.8, 0.2, 0.5))
	draw_circle(end, 8, Color(1.0, 0.8, 0.2, 0.5))
