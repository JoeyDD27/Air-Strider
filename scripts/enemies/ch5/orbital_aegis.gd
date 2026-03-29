extends Node2D
class_name OrbitalAegis
## Chapter 5 Boss - The Orbital Aegis
## Massive eye protected by orbiting Aegis Bits
## Phase 1: Solar Sweep + Aegis Bash
## Phase 2: Spawns Buffer Drones for invincibility, adds Ion Rain

enum BossPhase { INTRO, PHASE_1, PHASE_2, DEFEATED }
enum AttackState { IDLE, SOLAR_SWEEP, AEGIS_BASH, ION_RAIN }

@export var max_health: int = 25

var health: int
var phase: BossPhase = BossPhase.INTRO
var phase_timer: float = 0.0
var attack_timer: float = 0.0
var attack_state: AttackState = AttackState.IDLE

# Player reference
var player_ref: Node2D = null

# Aegis Bits (orbiting shields)
var aegis_bits: Array = []
var aegis_orbit_radius: float = 80.0
var aegis_orbit_speed: float = 2.0
var aegis_expanded: bool = false
var aegis_expand_radius: float = 960.0  # Half room width (1920/2) to cover entire arena
var aegis_current_radius: float = 80.0

# Solar Sweep attack
var solar_sweep_active: bool = false
var solar_sweep_angle: float = 0.0
var solar_sweep_telegraph_timer: float = 0.0
var solar_sweep_duration: float = 4.0
var solar_sweep_cooldown: float = 0.0

# Aegis Bash attack
var aegis_bash_telegraph: float = 0.0
var aegis_bash_hold_timer: float = 0.0
var aegis_bash_retracting: bool = false
var aegis_bash_cooldown: float = 0.0

# Ion Rain attack (Phase 2)
var ion_rain_active: bool = false
var ion_rain_warnings: Array = []  # Array of {position, timer}
var ion_rain_timer: float = 0.0
var ion_rain_cooldown: float = 0.0

# Buffer Drones (Phase 2 invincibility)
var buffer_drones: Array = []
var is_shielded: bool = false

# Visual
var eye_radius: float = 50.0
var glow_intensity: float = 0.0
var damage_flash: float = 0.0
var pupil_look_at: Vector2 = Vector2.ZERO
var is_dead: bool = false

# Hitbox
var hitbox: Area2D = null

# Preloaded scenes
const AEGIS_SCENE = preload("res://scenes/entities/ch3/aegis_bit.tscn")
const BUFFER_DRONE_SCENE = preload("res://scenes/entities/ch2/buffer_drone.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")

	health = max_health

	# Create hitbox
	_setup_hitbox()

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

	# Start intro
	GameManager.current_state = GameManager.GameState.BOSS_INTRO

func _setup_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.collision_layer = 4  # Enemy
	hitbox.collision_mask = 16  # Player projectiles

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = eye_radius
	shape.shape = circle
	hitbox.add_child(shape)

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_child(hitbox)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if phase == BossPhase.DEFEATED:
		return

	if area.is_in_group("player_projectiles"):
		# Check if shielded by Buffer Drones
		if is_shielded:
			area.queue_free()
			return

		_take_damage(1)
		area.queue_free()

func _take_damage(amount: int) -> void:
	if phase == BossPhase.DEFEATED:
		return

	health -= amount
	damage_flash = 0.2

	EventBus.boss_damaged.emit(health, max_health)
	EventBus.screen_shake.emit(8.0, 0.15)

	# Check phase transition
	_check_phase_transition()

	if health <= 0:
		_enter_defeated()

func _check_phase_transition() -> void:
	var health_percent = float(health) / max_health

	match phase:
		BossPhase.PHASE_1:
			if health_percent <= 0.60:
				_enter_phase_2()

func _physics_process(delta: float) -> void:
	if GameManager.is_phantom_mode:
		return

	# Allow defeated phase to continue processing for death animation
	if is_dead and phase != BossPhase.DEFEATED:
		return

	# Update flash
	if damage_flash > 0:
		damage_flash -= delta

	# Update pupil to look at player
	if player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		pupil_look_at = pupil_look_at.lerp(dir * 15, delta * 5.0)

	# Check Buffer Drone shields
	_update_shield_status()

	match phase:
		BossPhase.INTRO:
			_phase_intro(delta)
		BossPhase.PHASE_1:
			_phase_1(delta)
		BossPhase.PHASE_2:
			_phase_2(delta)
		BossPhase.DEFEATED:
			_phase_defeated(delta)

	# Update Aegis orbit
	_update_aegis_orbit(delta)

	queue_redraw()

func _update_shield_status() -> void:
	# Check if any buffer drones are still alive
	buffer_drones = buffer_drones.filter(func(d): return is_instance_valid(d) and not d.is_dead)
	is_shielded = not buffer_drones.is_empty()

# ============ INTRO ============
func _phase_intro(delta: float) -> void:
	phase_timer += delta

	glow_intensity = min(phase_timer / 2.0, 1.0)

	if phase_timer >= 2.0:
		_enter_phase_1()

func _enter_phase_1() -> void:
	phase = BossPhase.PHASE_1
	phase_timer = 0.0
	GameManager.current_state = GameManager.GameState.PLAYING

	# Spawn 3 Aegis Bits evenly distributed around the eye
	for i in range(3):
		var bit = AEGIS_SCENE.instantiate()
		bit.orbit_angle = TAU * i / 3.0  # Evenly spaced: 0, 120, 240 degrees
		bit.orbit_radius = aegis_orbit_radius
		bit.orbit_speed = aegis_orbit_speed
		bit.set_host(self)
		get_tree().current_scene.call_deferred("add_child", bit)
		aegis_bits.append(bit)

	EventBus.orbital_aegis_phase_changed.emit(1)

# ============ PHASE 1 ============
func _phase_1(delta: float) -> void:
	phase_timer += delta
	attack_timer += delta

	# Update cooldowns
	solar_sweep_cooldown -= delta
	aegis_bash_cooldown -= delta

	# Handle current attack
	match attack_state:
		AttackState.IDLE:
			_attack_idle(delta)
		AttackState.SOLAR_SWEEP:
			_attack_solar_sweep(delta)
		AttackState.AEGIS_BASH:
			_attack_aegis_bash(delta)

func _attack_idle(delta: float) -> void:
	# Choose next attack
	if attack_timer >= 2.0:
		if solar_sweep_cooldown <= 0:
			_start_solar_sweep()
		elif aegis_bash_cooldown <= 0:
			_start_aegis_bash()
		else:
			attack_timer = 0.0

func _start_solar_sweep() -> void:
	attack_state = AttackState.SOLAR_SWEEP
	solar_sweep_telegraph_timer = 1.0
	solar_sweep_active = false
	solar_sweep_angle = randf() * TAU
	EventBus.solar_sweep_started.emit()

func _attack_solar_sweep(delta: float) -> void:
	if solar_sweep_telegraph_timer > 0:
		# Telegraph phase
		solar_sweep_telegraph_timer -= delta
		if solar_sweep_telegraph_timer <= 0:
			solar_sweep_active = true
			phase_timer = 0.0
	else:
		# Active sweep
		solar_sweep_angle += (TAU / solar_sweep_duration) * delta

		# Check if laser hits player (covers entire room - 960 radius from center)
		if player_ref and solar_sweep_active:
			var to_player = player_ref.global_position - global_position
			var player_angle = to_player.angle()
			var angle_diff = abs(wrapf(player_angle - solar_sweep_angle, -PI, PI))
			if angle_diff < 0.15 and to_player.length() < 960:
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(1)

		# End after full rotation
		if phase_timer >= solar_sweep_duration:
			solar_sweep_active = false
			solar_sweep_cooldown = 5.0
			attack_state = AttackState.IDLE
			attack_timer = 0.0

func _start_aegis_bash() -> void:
	attack_state = AttackState.AEGIS_BASH
	aegis_bash_telegraph = 0.8
	aegis_expanded = false
	aegis_bash_retracting = false
	aegis_bash_hold_timer = 0.0
	EventBus.aegis_bash_started.emit()

func _attack_aegis_bash(delta: float) -> void:
	if aegis_bash_telegraph > 0:
		# Telegraph phase - bits flash
		aegis_bash_telegraph -= delta
		if aegis_bash_telegraph <= 0:
			aegis_expanded = true
	elif aegis_expanded and not aegis_bash_retracting:
		# Expanding phase
		aegis_current_radius = move_toward(aegis_current_radius, aegis_expand_radius, 800 * delta)

		# Check collision with player during expansion (50 = doubled collision radius)
		if player_ref:
			for bit in aegis_bits:
				if is_instance_valid(bit):
					var dist = bit.global_position.distance_to(player_ref.global_position)
					if dist < 50:
						if player_ref.has_method("take_damage"):
							player_ref.take_damage(1)

		if aegis_current_radius >= aegis_expand_radius:
			aegis_bash_hold_timer += delta
			if aegis_bash_hold_timer >= 0.5:
				aegis_bash_retracting = true
	elif aegis_bash_retracting:
		# Retracting phase
		aegis_current_radius = move_toward(aegis_current_radius, aegis_orbit_radius, 600 * delta)

		# Check collision during retraction too (50 = doubled collision radius)
		if player_ref:
			for bit in aegis_bits:
				if is_instance_valid(bit):
					var dist = bit.global_position.distance_to(player_ref.global_position)
					if dist < 50:
						if player_ref.has_method("take_damage"):
							player_ref.take_damage(1)

		if aegis_current_radius <= aegis_orbit_radius:
			aegis_expanded = false
			aegis_bash_retracting = false
			aegis_bash_cooldown = 4.0
			attack_state = AttackState.IDLE
			attack_timer = 0.0

# ============ PHASE 2 ============
func _enter_phase_2() -> void:
	phase = BossPhase.PHASE_2
	phase_timer = 0.0
	attack_state = AttackState.IDLE
	attack_timer = 0.0

	EventBus.boss_phase_changed.emit(2)
	EventBus.orbital_aegis_phase_changed.emit(2)
	EventBus.screen_shake.emit(15.0, 0.5)

	# Spawn 2 Buffer Drones inside the orbit
	_spawn_buffer_drones()

func _spawn_buffer_drones() -> void:
	for i in range(2):
		var drone = BUFFER_DRONE_SCENE.instantiate()
		var angle = TAU * i / 2 + PI / 4  # Offset from Aegis bits
		drone.global_position = global_position + Vector2.from_angle(angle) * 40
		get_tree().current_scene.call_deferred("add_child", drone)
		buffer_drones.append(drone)

func _phase_2(delta: float) -> void:
	phase_timer += delta
	attack_timer += delta

	# Update cooldowns
	solar_sweep_cooldown -= delta
	aegis_bash_cooldown -= delta
	ion_rain_cooldown -= delta

	# Handle current attack
	match attack_state:
		AttackState.IDLE:
			_attack_idle_phase2(delta)
		AttackState.SOLAR_SWEEP:
			_attack_solar_sweep(delta)
		AttackState.AEGIS_BASH:
			_attack_aegis_bash(delta)
		AttackState.ION_RAIN:
			_attack_ion_rain(delta)

func _attack_idle_phase2(delta: float) -> void:
	if attack_timer >= 1.5:
		# Priority: Ion Rain > Solar Sweep > Aegis Bash
		if ion_rain_cooldown <= 0:
			_start_ion_rain()
		elif solar_sweep_cooldown <= 0:
			_start_solar_sweep()
		elif aegis_bash_cooldown <= 0:
			_start_aegis_bash()
		else:
			attack_timer = 0.0

func _start_ion_rain() -> void:
	attack_state = AttackState.ION_RAIN
	ion_rain_active = true
	ion_rain_timer = 0.0
	ion_rain_warnings.clear()

	# Generate warning positions (covers full room width - 0 to 1920)
	var positions = []
	for i in range(12):  # More lasers to cover wider area
		var x = randf_range(50, 1870)  # Full room width with small margin
		positions.append(x)

	EventBus.ion_rain_warning.emit(positions)

	# Create warnings with staggered timers
	for i in range(12):
		ion_rain_warnings.append({
			"x": positions[i],
			"warning_timer": 1.0 + i * 0.2,
			"fired": false
		})

func _attack_ion_rain(delta: float) -> void:
	ion_rain_timer += delta

	# Process each warning/laser
	for warning in ion_rain_warnings:
		if warning.fired:
			continue

		warning.warning_timer -= delta
		if warning.warning_timer <= 0:
			# Fire the laser
			warning.fired = true
			_fire_ion_laser(warning.x)

	# Check if all lasers fired
	var all_fired = true
	for warning in ion_rain_warnings:
		if not warning.fired:
			all_fired = false
			break

	if all_fired and ion_rain_timer >= 4.0:
		ion_rain_active = false
		ion_rain_cooldown = 6.0
		attack_state = AttackState.IDLE
		attack_timer = 0.0

func _fire_ion_laser(x_pos: float) -> void:
	# Check if player is in the laser column
	if player_ref:
		if abs(player_ref.global_position.x - x_pos) < 30:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(1)

	EventBus.screen_shake.emit(5.0, 0.1)

# ============ AEGIS ORBIT UPDATE ============
func _update_aegis_orbit(delta: float) -> void:
	# Clean up dead bits
	aegis_bits = aegis_bits.filter(func(b): return is_instance_valid(b) and not b.is_dead)

	# Update orbit radius for active bits
	for bit in aegis_bits:
		if is_instance_valid(bit):
			bit.orbit_radius = aegis_current_radius

# ============ DEFEATED ============
func _enter_defeated() -> void:
	is_dead = true
	phase = BossPhase.DEFEATED
	phase_timer = 0.0

	EventBus.boss_defeated.emit()
	EventBus.screen_shake.emit(20.0, 1.0)

	# Destroy remaining aegis bits
	for bit in aegis_bits:
		if is_instance_valid(bit):
			bit.queue_free()
	aegis_bits.clear()

	# Destroy remaining buffer drones
	for drone in buffer_drones:
		if is_instance_valid(drone):
			drone.queue_free()
	buffer_drones.clear()

func _phase_defeated(delta: float) -> void:
	phase_timer += delta

	# Death animation
	glow_intensity = 1.0 - phase_timer / 2.0

	if phase_timer >= 2.0:
		# Spawn death particles
		_spawn_death_particles()

		# Award coins
		var boss_reward = GameManager.ENEMY_REWARDS.get("orbital_aegis", 2000)
		EventBus.enemy_killed.emit(self, boss_reward, global_position)

		# Trigger victory
		EventBus.victory.emit()
		queue_free()

func _spawn_death_particles() -> void:
	for i in range(20):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position + Vector2(
			randf_range(-80, 80),
			randf_range(-80, 80)
		)
		particle.color = Color(0.8, 0.3, 0.3)
		get_tree().current_scene.add_child(particle)

# ============ DRAW ============
func _draw() -> void:
	# Draw glow aura
	var glow_color = Color(0.8, 0.2, 0.2, 0.3 * glow_intensity)
	draw_circle(Vector2.ZERO, eye_radius + 30, glow_color)

	# Draw eye (main body)
	var eye_color = Color(0.9, 0.9, 0.95)
	if damage_flash > 0:
		eye_color = Color.WHITE
	if is_shielded:
		eye_color = Color(0.3, 0.8, 1.0)

	draw_circle(Vector2.ZERO, eye_radius, eye_color)

	# Draw iris
	var iris_color = Color(0.8, 0.2, 0.2)
	var iris_radius = eye_radius * 0.6
	draw_circle(pupil_look_at * 0.3, iris_radius, iris_color)

	# Draw pupil
	var pupil_color = Color(0.1, 0.05, 0.05)
	var pupil_radius = eye_radius * 0.3
	draw_circle(pupil_look_at * 0.5, pupil_radius, pupil_color)

	# Draw pupil highlight
	draw_circle(pupil_look_at * 0.5 + Vector2(-5, -5), 5, Color(1, 1, 1, 0.8))

	# Draw solar sweep (covers entire room - 960 radius)
	if solar_sweep_active or solar_sweep_telegraph_timer > 0:
		var sweep_alpha = 1.0 if solar_sweep_active else (1.0 - solar_sweep_telegraph_timer) * 0.5
		var beam_color = Color(1.0, 0.3, 0.1, sweep_alpha)
		var beam_length = 960.0  # Half room width to reach walls
		var beam_end = Vector2.from_angle(solar_sweep_angle) * beam_length

		# Draw beam
		draw_line(Vector2.ZERO, beam_end, beam_color, 8.0 if solar_sweep_active else 3.0)

		# Draw beam glow
		if solar_sweep_active:
			var glow = Color(1.0, 0.5, 0.2, 0.3)
			draw_line(Vector2.ZERO, beam_end, glow, 20.0)

	# Draw aegis bash telegraph
	if aegis_bash_telegraph > 0:
		var flash_alpha = sin(aegis_bash_telegraph * 20) * 0.5 + 0.5
		draw_arc(Vector2.ZERO, aegis_expand_radius, 0, TAU, 32, Color(1.0, 0.3, 0.3, flash_alpha * 0.5), 3.0)

	# Draw ion rain warnings (covers full room height)
	if ion_rain_active:
		for warning in ion_rain_warnings:
			if not warning.fired and warning.warning_timer > 0:
				var alpha = (1.0 - warning.warning_timer) * 0.8
				var x_offset = warning.x - global_position.x
				# Draw warning line from ceiling to floor (full room height)
				draw_line(Vector2(x_offset, -600), Vector2(x_offset, 600), Color(1.0, 0.8, 0.2, alpha), 3.0)
			elif warning.fired:
				# Draw active laser briefly
				var x_offset = warning.x - global_position.x
				draw_line(Vector2(x_offset, -600), Vector2(x_offset, 600), Color(1.0, 0.3, 0.1, 0.8), 12.0)

	# Draw shield indicator if protected
	if is_shielded:
		var shield_pulse = sin(phase_timer * 5) * 0.2 + 0.5
		draw_arc(Vector2.ZERO, eye_radius + 10, 0, TAU, 32, Color(0.3, 0.8, 1.0, shield_pulse), 4.0)

	# Draw health indicator ring
	var health_percent = float(health) / max_health
	var health_color = Color(0.2, 0.8, 0.2) if health_percent > 0.5 else Color(0.8, 0.8, 0.2) if health_percent > 0.25 else Color(0.8, 0.2, 0.2)
	draw_arc(Vector2.ZERO, eye_radius + 5, -PI/2, -PI/2 + TAU * health_percent, 32, health_color, 3.0)
