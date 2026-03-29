extends Node2D
class_name Subject88
## Chapter 4 Boss - Walking Meltdown with 3 phases

enum BossPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }
enum AttackState { IDLE, SLUDGE_MORTAR, SPAWN_MINES, ANCHOR_TELEGRAPH, ANCHOR_SHOT, SHOCKWAVE_TELEGRAPH, SHOCKWAVE, SLAM_TELEGRAPH, SLAM, LASER_SWEEP }

@export var max_health: int = 30

# Phase 1 settings
@export var heat_aura_radius: float = 160.0  # 8 meters = 160 pixels at 20px/m
@export var heat_damage_rate: float = 10.0
@export var mortar_cooldown: float = 4.0
@export var mine_spawn_cooldown: float = 6.0

# Phase 2 settings
@export var anchor_cooldown: float = 5.0
@export var shockwave_radius: float = 250.0
@export var shockwave_damage: int = 2

# Phase 3 settings
@export var slam_cooldown: float = 3.0
@export var laser_sweep_cooldown: float = 8.0

var health: int
var phase: BossPhase = BossPhase.INTRO
var attack_state: AttackState = AttackState.IDLE
var state_timer: float = 0.0
var attack_timer: float = 0.0
var heat_damage_timer: float = 0.0
var player_ref: Node2D = null
var is_dead: bool = false

# Movement
var move_speed: float = 60.0
var target_x: float = 0.0
var body_y: float = 0.0

# Phase 3 flight
var is_flying: bool = false
var flight_y: float = 0.0
var slam_target: Vector2 = Vector2.ZERO

# Phase 2 telegraph
var anchor_targets: Array = []
var shockwave_telegraph_active: bool = false

# Visual
var leg_animation: float = 0.0
var core_pulse: float = 0.0
var laser_angle: float = 0.0
var laser_sweep_active: bool = false

# Hitbox
var hitbox: Area2D = null

# Scene references
const MAG_MINE_SCRIPT = preload("res://scripts/enemies/ch4/mag_mine.gd")
const COUNTDOWN_SCRIPT = preload("res://scripts/enemies/ch4/countdown.gd")
const SLUDGE_MORTAR_SCRIPT = preload("res://scripts/enemies/ch4/sludge_mortar.gd")
const FIRE_ZONE_SCRIPT = preload("res://scripts/hazards/fire_zone.gd")
const EXPLOSION_SCRIPT = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health = max_health
	body_y = global_position.y
	print("Subject88 initialized with health: ", health, " max_health: ", max_health)

	_setup_hitbox()

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

	# Start intro
	phase = BossPhase.INTRO
	state_timer = 0.0

func _setup_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.collision_layer = 4   # Enemy layer
	hitbox.collision_mask = 16   # Player projectiles
	hitbox.monitoring = true
	hitbox.monitorable = true

	# Add hitbox to enemies group so projectiles can detect it
	hitbox.add_to_group("enemies")
	hitbox.add_to_group("boss")

	# Store reference to boss for damage routing
	hitbox.set_meta("boss_ref", self)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(180, 200)
	shape.shape = rect
	shape.position = Vector2(0, -120)
	hitbox.add_child(shape)

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_child(hitbox)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_projectiles"):
		_take_damage(1)
		area.queue_free()

# Public method so projectiles can call take_damage on the boss directly
func take_damage(amount: int) -> bool:
	if is_dead or phase == BossPhase.INTRO:
		return false
	_take_damage(amount)
	return true

func _take_damage(amount: int) -> void:
	if is_dead or phase == BossPhase.INTRO:
		return

	health -= amount
	print("Subject88 took ", amount, " damage. Health: ", health, "/", max_health)
	EventBus.boss_damaged.emit(health, max_health)
	EventBus.screen_shake.emit(2.0, 0.05)

	_check_phase_transition()

	if health <= 0:
		print("Subject88 defeated after taking damage!")
		_defeat()

func _check_phase_transition() -> void:
	var health_percent = float(health) / max_health

	match phase:
		BossPhase.PHASE_1:
			if health_percent <= 0.80:  # Phase 2 at 80% HP
				_enter_phase_2()
		BossPhase.PHASE_2:
			if health_percent <= 0.40:  # Phase 3 at 40% HP
				_enter_phase_3()

func _enter_phase_2() -> void:
	phase = BossPhase.PHASE_2
	attack_state = AttackState.IDLE
	state_timer = 0.0
	attack_timer = 0.0
	move_speed *= 1.2  # 20% faster

	EventBus.subject88_phase_changed.emit(2)
	EventBus.screen_shake.emit(10.0, 0.5)

func _enter_phase_3() -> void:
	phase = BossPhase.PHASE_3
	attack_state = AttackState.IDLE
	state_timer = 0.0
	attack_timer = 0.0
	is_flying = true
	heat_aura_radius *= 2.0  # Double heat aura

	EventBus.subject88_phase_changed.emit(3)
	EventBus.screen_shake.emit(15.0, 0.8)

func _defeat() -> void:
	is_dead = true
	phase = BossPhase.DEFEATED

	EventBus.boss_defeated.emit()
	EventBus.screen_shake.emit(20.0, 1.0)

	var tree = get_tree()
	if tree == null:
		EventBus.victory.emit()
		queue_free()
		return

	# Spawn multiple explosions
	for i in range(5):
		if not is_instance_valid(self) or get_tree() == null:
			break
		var explosion = Area2D.new()
		explosion.set_script(EXPLOSION_SCRIPT)
		explosion.radius = 100.0
		explosion.damage = 0  # No damage on death
		explosion.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-150, 0))
		tree.current_scene.call_deferred("add_child", explosion)
		await tree.create_timer(0.2).timeout

	# Emit victory signal after death animation
	if get_tree() != null:
		await get_tree().create_timer(0.5).timeout
	EventBus.victory.emit()

	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	state_timer += delta
	attack_timer += delta
	core_pulse += delta
	leg_animation += delta * (2.0 if not is_flying else 0.0)

	match phase:
		BossPhase.INTRO:
			_phase_intro(delta)
		BossPhase.PHASE_1:
			_phase_1(delta)
		BossPhase.PHASE_2:
			_phase_2(delta)
		BossPhase.PHASE_3:
			_phase_3(delta)

	# Heat aura damage
	if phase != BossPhase.INTRO and phase != BossPhase.DEFEATED:
		_apply_heat_damage(delta)

	queue_redraw()

func _phase_intro(delta: float) -> void:
	# Brief intro animation
	if state_timer >= 2.0:
		phase = BossPhase.PHASE_1
		state_timer = 0.0
		EventBus.subject88_phase_changed.emit(1)

func _phase_1(delta: float) -> void:
	# Move toward player slowly
	_move_toward_player(delta)

	# Attack pattern
	if attack_state == AttackState.IDLE:
		if attack_timer >= mortar_cooldown:
			_attack_sludge_mortar()
		elif attack_timer >= mine_spawn_cooldown * 0.5 and int(attack_timer) % 2 == 0:
			_attack_spawn_mines()

func _phase_2(delta: float) -> void:
	_move_toward_player(delta)

	if attack_state == AttackState.IDLE:
		if attack_timer >= anchor_cooldown:
			_attack_anchor_telegraph()
		elif attack_timer >= anchor_cooldown * 0.7:
			# Check if player is close for shockwave
			if player_ref:
				var dist = global_position.distance_to(player_ref.global_position)
				if dist < shockwave_radius * 0.8:
					_attack_shockwave_telegraph()

func _phase_3(delta: float) -> void:
	# Flying movement
	if is_flying:
		_flying_movement(delta)

	if attack_state == AttackState.IDLE:
		if attack_timer >= slam_cooldown:
			_attack_slam_telegraph()
		elif attack_timer >= laser_sweep_cooldown * 0.6 and not laser_sweep_active:
			_attack_laser_sweep()

	# Handle slam execution
	if attack_state == AttackState.SLAM:
		_execute_slam(delta)

	# Handle laser sweep
	if laser_sweep_active:
		_execute_laser_sweep(delta)

func _move_toward_player(delta: float) -> void:
	if not player_ref:
		return

	var dir = sign(player_ref.global_position.x - global_position.x)
	global_position.x += dir * move_speed * delta

func _flying_movement(delta: float) -> void:
	# Erratic flying pattern
	var hover_offset = sin(state_timer * 2.0) * 50.0 + cos(state_timer * 1.3) * 30.0
	flight_y = body_y - 150 + hover_offset

	if attack_state != AttackState.SLAM:
		global_position.y = flight_y

	# Still track player horizontally
	if player_ref and attack_state == AttackState.IDLE:
		var dir = sign(player_ref.global_position.x - global_position.x)
		global_position.x += dir * move_speed * 1.5 * delta

func _apply_heat_damage(delta: float) -> void:
	if not player_ref:
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= heat_aura_radius:
		heat_damage_timer += delta
		if heat_damage_timer >= 1.0:  # Damage every second
			player_ref.take_damage(1)
			heat_damage_timer = 0.0

# === ATTACKS ===

func _attack_sludge_mortar() -> void:
	attack_state = AttackState.SLUDGE_MORTAR
	attack_timer = 0.0

	if not player_ref:
		attack_state = AttackState.IDLE
		return

	# Fire 3 mortars
	for i in range(3):
		var mortar = Area2D.new()
		mortar.set_script(SLUDGE_MORTAR_SCRIPT)
		mortar.global_position = global_position + Vector2(0, -150)

		# Spread targets around player
		var offset = Vector2(randf_range(-100, 100), randf_range(-50, 50))
		mortar.target_position = player_ref.global_position + offset

		get_tree().current_scene.call_deferred("add_child", mortar)

		await get_tree().create_timer(0.3).timeout

	EventBus.subject88_slam_telegraph.emit(player_ref.global_position)
	attack_state = AttackState.IDLE

func _attack_spawn_mines() -> void:
	attack_state = AttackState.SPAWN_MINES

	# Spawn 3 Mag-Mines
	for i in range(3):
		var mine = CharacterBody2D.new()
		mine.set_script(MAG_MINE_SCRIPT)
		mine.global_position = global_position + Vector2(randf_range(-50, 50), -180)
		get_tree().current_scene.call_deferred("add_child", mine)

	attack_state = AttackState.IDLE

func _attack_anchor_telegraph() -> void:
	attack_state = AttackState.ANCHOR_TELEGRAPH
	attack_timer = 0.0
	state_timer = 0.0

	if not player_ref:
		attack_state = AttackState.IDLE
		return

	# Calculate anchor positions for telegraph
	var player_pos = player_ref.global_position
	anchor_targets = [
		player_pos + Vector2(-80, 50),
		player_pos + Vector2(80, 50),
		player_pos + Vector2(0, -100)
	]

	EventBus.subject88_anchor_telegraph.emit(anchor_targets)

	# Wait for telegraph then attack
	await get_tree().create_timer(0.8).timeout
	if attack_state == AttackState.ANCHOR_TELEGRAPH:
		_attack_anchor_shot()

func _attack_anchor_shot() -> void:
	attack_state = AttackState.ANCHOR_SHOT

	if not player_ref or anchor_targets.is_empty():
		anchor_targets.clear()
		attack_state = AttackState.IDLE
		return

	# Fire anchor spikes at telegraphed positions
	for pos in anchor_targets:
		# Create anchor spike visual/effect
		var spike = Area2D.new()
		spike.set_script(EXPLOSION_SCRIPT)
		spike.radius = 30.0
		spike.damage = 1
		spike.global_position = pos
		get_tree().current_scene.call_deferred("add_child", spike)

	# Apply pull to player if inside triangle
	# Simplified: just pull toward boss
	if player_ref:
		var pull_dir = (global_position - player_ref.global_position).normalized()
		player_ref.velocity += pull_dir * 200.0

	anchor_targets.clear()
	attack_state = AttackState.IDLE

func _attack_shockwave_telegraph() -> void:
	attack_state = AttackState.SHOCKWAVE_TELEGRAPH
	attack_timer = 0.0
	state_timer = 0.0
	shockwave_telegraph_active = true

	EventBus.subject88_shockwave_telegraph.emit(global_position, shockwave_radius)

	# Wait for telegraph then attack
	await get_tree().create_timer(0.6).timeout
	if attack_state == AttackState.SHOCKWAVE_TELEGRAPH:
		_attack_shockwave()

func _attack_shockwave() -> void:
	attack_state = AttackState.SHOCKWAVE
	shockwave_telegraph_active = false

	EventBus.subject88_shockwave.emit(global_position, shockwave_radius)
	EventBus.screen_shake.emit(12.0, 0.3)

	# Damage in radius
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= shockwave_radius:
			player_ref.take_damage(shockwave_damage)

	# Spawn shockwave visual
	var shockwave = Area2D.new()
	shockwave.set_script(EXPLOSION_SCRIPT)
	shockwave.radius = shockwave_radius
	shockwave.damage = 0  # Already dealt damage
	shockwave.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", shockwave)

	attack_state = AttackState.IDLE

func _attack_slam_telegraph() -> void:
	attack_state = AttackState.SLAM_TELEGRAPH
	attack_timer = 0.0

	if player_ref:
		slam_target = player_ref.global_position

	EventBus.subject88_slam_telegraph.emit(slam_target)

	# Wait for telegraph then slam
	await get_tree().create_timer(1.0).timeout
	attack_state = AttackState.SLAM
	state_timer = 0.0

func _execute_slam(delta: float) -> void:
	# Move rapidly toward slam target
	var to_target = slam_target - global_position
	var dist = to_target.length()

	if dist > 20:
		global_position += to_target.normalized() * 1500.0 * delta
	else:
		# Impact!
		_slam_impact()
		attack_state = AttackState.IDLE
		attack_timer = 0.0

func _slam_impact() -> void:
	EventBus.screen_shake.emit(15.0, 0.4)

	# Damage in radius
	var explosion = Area2D.new()
	explosion.set_script(EXPLOSION_SCRIPT)
	explosion.radius = 120.0
	explosion.damage = 2
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)

	# Spawn 2 Mag-Mines
	for i in range(2):
		var mine = CharacterBody2D.new()
		mine.set_script(MAG_MINE_SCRIPT)
		mine.global_position = global_position + Vector2(randf_range(-60, 60), -50)
		get_tree().current_scene.call_deferred("add_child", mine)

func _attack_laser_sweep() -> void:
	laser_sweep_active = true
	laser_angle = -PI / 3  # Start from left
	attack_timer = 0.0

	EventBus.subject88_laser_sweep.emit(laser_angle, PI / 3)

func _execute_laser_sweep(delta: float) -> void:
	# Sweep laser across arena
	laser_angle += delta * 0.8  # Sweep speed

	# Check if player is hit by laser
	if player_ref:
		var to_player = player_ref.global_position - global_position
		var player_angle = to_player.angle()
		if abs(player_angle - laser_angle) < 0.15:  # Hit tolerance
			player_ref.take_damage(1)

	# End sweep
	if laser_angle >= PI / 3:
		laser_sweep_active = false
		attack_timer = 0.0

func _draw() -> void:
	# Heat aura
	var aura_alpha = 0.15 + sin(core_pulse * 2.0) * 0.05
	var aura_color = Color(1.0, 0.3, 0.0, aura_alpha)
	draw_circle(Vector2.ZERO, heat_aura_radius, aura_color)
	draw_arc(Vector2.ZERO, heat_aura_radius, 0, TAU, 32, Color(1.0, 0.4, 0.0, 0.3), 3.0)

	# Body - large industrial mech
	var body_width = 160.0
	var body_height = 180.0

	if not is_flying:
		# Legs (4 quadruped legs)
		_draw_legs(body_width, body_height)

	# Main body
	var body_rect = Rect2(-body_width / 2, -body_height, body_width, body_height * 0.7)
	draw_rect(body_rect, Color(0.35, 0.35, 0.4))

	# Industrial details
	for i in range(3):
		var vent_y = -body_height + 30 + i * 40
		draw_rect(Rect2(-body_width / 2 + 10, vent_y, 20, 8), Color(0.2, 0.2, 0.25))
		draw_rect(Rect2(body_width / 2 - 30, vent_y, 20, 8), Color(0.2, 0.2, 0.25))

	# Glass tank on back (green liquid)
	var tank_rect = Rect2(-40, -body_height - 30, 80, 60)
	draw_rect(tank_rect, Color(0.2, 0.2, 0.25))
	var liquid_rect = Rect2(-35, -body_height - 25, 70, 50)
	var liquid_wave = sin(core_pulse * 3.0) * 3
	liquid_rect.position.y += liquid_wave
	draw_rect(liquid_rect, Color(0.3, 0.8, 0.2, 0.7))

	# Cracks in tank (phase 2+)
	if phase == BossPhase.PHASE_2 or phase == BossPhase.PHASE_3:
		draw_line(Vector2(-20, -body_height - 20), Vector2(10, -body_height + 10), Color(0.1, 0.1, 0.1, 0.6), 2.0)
		draw_line(Vector2(15, -body_height - 25), Vector2(-5, -body_height + 5), Color(0.1, 0.1, 0.1, 0.6), 2.0)

	# Core glow
	var core_intensity = 0.5 + sin(core_pulse * 4.0) * 0.3
	var core_color = Color(1.0, 0.5, 0.0, core_intensity)
	if phase == BossPhase.PHASE_3:
		core_color = Color(1.0, 0.2, 0.0, core_intensity)  # Red in phase 3
	draw_circle(Vector2(0, -body_height / 2), 25, core_color)
	draw_circle(Vector2(0, -body_height / 2), 15, Color(1.0, 0.8, 0.2, core_intensity))

	# Phase 3 thrusters
	if is_flying:
		for i in range(4):
			var thruster_x = -body_width / 2 + 30 + i * 35
			var flame_height = 30 + sin(core_pulse * 10.0 + i) * 10
			var flame_points = PackedVector2Array([
				Vector2(thruster_x - 10, 0),
				Vector2(thruster_x + 10, 0),
				Vector2(thruster_x, flame_height)
			])
			draw_colored_polygon(flame_points, Color(1.0, 0.5, 0.0, 0.8))
			draw_colored_polygon(PackedVector2Array([
				Vector2(thruster_x - 5, 0),
				Vector2(thruster_x + 5, 0),
				Vector2(thruster_x, flame_height * 0.7)
			]), Color(1.0, 0.8, 0.2, 0.9))

	# Laser sweep
	if laser_sweep_active:
		var laser_length = 1000.0
		var laser_end = Vector2.from_angle(laser_angle) * laser_length
		draw_line(Vector2(0, -body_height / 2), laser_end, Color(1.0, 0.0, 0.0, 0.8), 6.0)
		draw_line(Vector2(0, -body_height / 2), laser_end, Color(1.0, 0.5, 0.0, 0.5), 12.0)

	# Slam telegraph
	if attack_state == AttackState.SLAM_TELEGRAPH:
		var local_target = slam_target - global_position
		var warning_pulse = sin(state_timer * 15.0) * 0.3 + 0.5
		draw_circle(local_target, 80, Color(1.0, 0.0, 0.0, warning_pulse * 0.3))
		draw_arc(local_target, 80, 0, TAU, 16, Color(1.0, 0.0, 0.0, warning_pulse), 3.0)

	# Phase 2 anchor telegraph - show warning triangles at target positions
	if attack_state == AttackState.ANCHOR_TELEGRAPH and not anchor_targets.is_empty():
		var warning_pulse = sin(state_timer * 12.0) * 0.3 + 0.6
		for target_pos in anchor_targets:
			var local_pos = target_pos - global_position
			# Draw pulsing warning circle
			draw_circle(local_pos, 35, Color(1.0, 0.6, 0.0, warning_pulse * 0.3))
			draw_arc(local_pos, 35, 0, TAU, 12, Color(1.0, 0.6, 0.0, warning_pulse), 2.5)
			# Draw exclamation mark
			draw_line(local_pos + Vector2(0, -15), local_pos + Vector2(0, 5), Color(1.0, 0.6, 0.0, warning_pulse), 4.0)
			draw_circle(local_pos + Vector2(0, 12), 3, Color(1.0, 0.6, 0.0, warning_pulse))

	# Phase 2 shockwave telegraph - expanding warning ring
	if attack_state == AttackState.SHOCKWAVE_TELEGRAPH:
		var warning_pulse = sin(state_timer * 10.0) * 0.3 + 0.6
		var expand_factor = state_timer / 0.6  # Expands over telegraph duration
		var current_radius = shockwave_radius * expand_factor
		draw_circle(Vector2.ZERO, current_radius, Color(1.0, 0.3, 0.0, warning_pulse * 0.2))
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 24, Color(1.0, 0.3, 0.0, warning_pulse), 4.0)
		# Inner warning ring
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 24, Color(1.0, 0.0, 0.0, warning_pulse * 0.5), 2.0)

	# Health bar
	var bar_width = 150.0
	var bar_height = 10.0
	var bar_y = -body_height - 60
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2))
	var health_percent = float(health) / max_health
	var health_color = Color(0.2, 0.8, 0.2) if health_percent > 0.5 else Color(1.0, 0.5, 0.0) if health_percent > 0.25 else Color(1.0, 0.0, 0.0)
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * health_percent, bar_height), health_color)

func _draw_legs(body_width: float, body_height: float) -> void:
	var leg_swing = sin(leg_animation * 3.0) * 15.0

	# 4 legs (quadruped)
	var leg_positions = [
		Vector2(-body_width / 2 + 20, -body_height * 0.3),
		Vector2(-body_width / 2 + 50, -body_height * 0.3),
		Vector2(body_width / 2 - 50, -body_height * 0.3),
		Vector2(body_width / 2 - 20, -body_height * 0.3)
	]

	for i in range(4):
		var hip = leg_positions[i]
		var swing = leg_swing if i % 2 == 0 else -leg_swing
		var knee = hip + Vector2(swing * 0.5, 40)
		var foot = knee + Vector2(swing, 40)

		draw_line(hip, knee, Color(0.4, 0.4, 0.45), 8.0)
		draw_line(knee, foot, Color(0.35, 0.35, 0.4), 6.0)
		draw_circle(knee, 6, Color(0.3, 0.3, 0.35))
		draw_circle(foot, 8, Color(0.3, 0.3, 0.35))
