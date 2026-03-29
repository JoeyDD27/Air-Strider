extends Node2D
class_name GroundFaultTitan
## Chapter 2 Boss - Ground-Fault Titan
## Arena: Electric floor (hazard) + 3 High Floating Islands (safe)
## Theme: Stay airborne or die

enum TitanPhase { INTRO, PHASE_1, INTERMISSION, PHASE_2, FINAL_PHASE, DEFEATED }
enum AttackType { VERTICAL_SLAM, HORIZON_SWEEP, EYE_LASER }

@export var max_health: int = 15

var health: int
var phase: TitanPhase = TitanPhase.INTRO
var is_dead: bool = false

# Dimensions
var body_width: float = 300.0
var body_height: float = 200.0

# Attack state
var attack_cooldown: float = 2.5
var attack_timer: float = 0.0
var current_attack: AttackType = AttackType.VERTICAL_SLAM
var attack_sequence: int = 0
var is_attacking: bool = false

# Intermission state
var intermission_casters: Array = []
var shield_active: bool = false
var intermission_count: int = 0  # Track which intermission (66% or 33%)

# Electric floor
var electric_floor: Node2D = null

# Visual
var body_color: Color = Color(0.3, 0.3, 0.5)
var eye_color: Color = Color(1.0, 0.8, 0.2)

# Player reference
var player_ref: Node2D = null

const ARC_CASTER_SCENE = preload("res://scenes/entities/ch2/arc_caster.tscn")
const SNIPER_BULLET_SCENE = preload("res://scenes/entities/sniper_bullet.tscn")
const MANTIS_SCENE = preload("res://scenes/entities/mantis.tscn")
const SNIPER_SCENE = preload("res://scenes/entities/sniper.tscn")
const MORTAR_SCENE = preload("res://scenes/entities/mortar.tscn")
const SEEKER_BEETLE_SCENE = preload("res://scenes/entities/ch2/seeker_beetle.tscn")
const REPLICATOR_SCENE = preload("res://scenes/entities/ch2/replicator.tscn")
const BUFFER_DRONE_SCENE = preload("res://scenes/entities/ch2/buffer_drone.tscn")
const AMP_PYLON_SCENE = preload("res://scenes/entities/ch2/amp_pylon.tscn")

# Island positions for targeting (same as boss room)
var island_positions: Array[Vector2] = [
	Vector2(400, 550),
	Vector2(960, 450),
	Vector2(1520, 550)
]

# Slam telegraph visuals
var slam_target_island: int = -1
var slam_telegraph_timer: float = 0.0
var slam_telegraph_active: bool = false

# Sweep telegraph visuals
var sweep_telegraph_active: bool = false
var sweep_telegraph_timer: float = 0.0
var sweep_height: float = 500.0  # Y position of horizontal laser

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health = max_health

	_setup_hitbox()
	_setup_electric_floor()

	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

	_start_intro()

func _setup_hitbox() -> void:
	var hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4   # Enemies
	hitbox.collision_mask = 16   # Player projectiles
	hitbox.add_to_group("enemies")

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(body_width, body_height)
	shape.shape = rect

	hitbox.add_child(shape)
	add_child(hitbox)

	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _setup_electric_floor() -> void:
	var floor_scene = preload("res://scenes/entities/hazards/electric_floor.tscn")
	electric_floor = floor_scene.instantiate()
	electric_floor.is_boss_controlled = true
	get_tree().current_scene.call_deferred("add_child", electric_floor)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if shield_active:
		return  # Immune during intermission

	if area.is_in_group("player_projectiles"):
		take_damage(1)
		area.queue_free()

func _start_intro() -> void:
	phase = TitanPhase.INTRO
	EventBus.boss_damaged.emit(health, max_health)
	await get_tree().create_timer(2.0).timeout
	_start_phase_1()

func _start_phase_1() -> void:
	phase = TitanPhase.PHASE_1
	_activate_electric_floor()
	EventBus.boss_phase_changed.emit(1)

func _activate_electric_floor() -> void:
	if electric_floor and electric_floor.has_method("activate"):
		electric_floor.activate()

func _deactivate_electric_floor() -> void:
	if electric_floor and electric_floor.has_method("deactivate"):
		electric_floor.deactivate()

func _process(delta: float) -> void:
	if phase == TitanPhase.INTRO or phase == TitanPhase.DEFEATED:
		queue_redraw()
		return

	if GameManager.is_phantom_mode:
		return

	if not player_ref:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0]
		else:
			return

	_check_phase_transition()

	if phase == TitanPhase.INTERMISSION:
		_handle_intermission(delta)
	elif not shield_active and not is_attacking:
		_handle_combat(delta)

	queue_redraw()

func _check_phase_transition() -> void:
	var health_ratio = float(health) / float(max_health)

	if health <= 0 and phase != TitanPhase.DEFEATED:
		_defeat()
	elif health_ratio <= 0.33 and phase == TitanPhase.PHASE_2 and intermission_count == 1:
		_start_intermission()
	elif health_ratio <= 0.66 and phase == TitanPhase.PHASE_1 and intermission_count == 0:
		_start_intermission()

func _start_intermission() -> void:
	phase = TitanPhase.INTERMISSION
	shield_active = true
	intermission_count += 1
	EventBus.titan_phase_shield.emit(true)
	_deactivate_electric_floor()

	# Spawn 2 Arc-Casters for the player to deal with
	_spawn_intermission_casters()

func _spawn_intermission_casters() -> void:
	var room = get_tree().current_scene
	var room_width = room.room_width if "room_width" in room else 1920.0
	var floor_y = room.floor_y if "floor_y" in room else 900.0

	# Spawn same enemies as room 12: Mantis, Sniper, Mortar, SeekerBeetle, ArcCaster, Replicator, BufferDrone, AmpPylon
	var spawn_data = [
		{"scene": MANTIS_SCENE, "pos": Vector2(600, floor_y - 50)},
		{"scene": SNIPER_SCENE, "pos": Vector2(900, 300)},
		{"scene": MORTAR_SCENE, "pos": Vector2(1300, 300)},
		{"scene": SEEKER_BEETLE_SCENE, "pos": Vector2(550, 400)},
		{"scene": ARC_CASTER_SCENE, "pos": Vector2(1600, floor_y - 50)},
		{"scene": REPLICATOR_SCENE, "pos": Vector2(1100, 300)},
		{"scene": BUFFER_DRONE_SCENE, "pos": Vector2(1100, 200)},
		{"scene": AMP_PYLON_SCENE, "pos": Vector2(1100, floor_y - 50)}
	]

	for data in spawn_data:
		var enemy = data.scene.instantiate()
		enemy.global_position = data.pos
		get_tree().current_scene.add_child(enemy)
		intermission_casters.append(enemy)

func _handle_intermission(_delta: float) -> void:
	# Check if casters are dead
	intermission_casters = intermission_casters.filter(func(c): return is_instance_valid(c) and (not "is_dead" in c or not c.is_dead))

	if intermission_casters.is_empty():
		_end_intermission()

func _end_intermission() -> void:
	shield_active = false
	EventBus.titan_phase_shield.emit(false)

	if intermission_count >= 2:
		# After second intermission, go to final phase
		_start_final_phase()
	else:
		phase = TitanPhase.PHASE_2
		_activate_electric_floor()
		attack_cooldown = 2.0  # Faster attacks
		EventBus.boss_phase_changed.emit(2)

func _start_final_phase() -> void:
	phase = TitanPhase.FINAL_PHASE
	_activate_electric_floor()
	attack_cooldown = 1.5
	EventBus.boss_phase_changed.emit(3)
	# Removed ceiling spikes - no longer emitting ceiling_spikes_lowering signal
	EventBus.screen_shake.emit(15.0, 0.5)

func _handle_combat(delta: float) -> void:
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		_execute_attack()
		attack_timer = 0.0
		attack_sequence = (attack_sequence + 1) % 2

func _execute_attack() -> void:
	match attack_sequence:
		0:
			_vertical_slam()
		1:
			_eye_laser()

func _vertical_slam() -> void:
	if not player_ref:
		return

	is_attacking = true

	# Pick the island closest to player to force horizontal movement
	var player_x = player_ref.global_position.x
	var closest_island = 0
	var closest_dist = 99999.0
	for i in range(island_positions.size()):
		var dist = abs(island_positions[i].x - player_x)
		if dist < closest_dist:
			closest_dist = dist
			closest_island = i

	slam_target_island = closest_island
	slam_telegraph_active = true
	slam_telegraph_timer = 1.5

	var target_pos = island_positions[slam_target_island]
	EventBus.titan_slam_telegraph.emit(target_pos)

	# 1.5s telegraph with red pillar of light
	await get_tree().create_timer(1.5).timeout

	slam_telegraph_active = false

	if is_dead:
		is_attacking = false
		return

	_spawn_slam_damage_on_island(slam_target_island)
	EventBus.screen_shake.emit(12.0, 0.3)
	is_attacking = false

func _spawn_slam_damage_on_island(island_index: int) -> void:
	var island_pos = island_positions[island_index]
	var room = get_tree().current_scene
	var room_width = room.room_width if "room_width" in room else 1920.0
	var island_width = room_width / 3.0  # Cover 1/3 of the room
	var island_height = 80.0  # Height of damage zone above platform

	var damage_area = Area2D.new()
	damage_area.collision_layer = 32  # Hazards
	damage_area.collision_mask = 1    # Player
	damage_area.monitoring = true
	damage_area.monitorable = true

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(island_width + 40, island_height)
	shape.shape = rect

	damage_area.add_child(shape)
	# Position damage zone on top of the island
	damage_area.global_position = Vector2(island_pos.x, island_pos.y - island_height / 2)
	get_tree().current_scene.add_child(damage_area)

	# Wait for physics to process the new area
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Check for player and damage
	var bodies = damage_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			body.take_damage(2)

	# Remove after brief delay
	await get_tree().create_timer(0.3).timeout
	damage_area.queue_free()

func _horizon_sweep() -> void:
	if not player_ref:
		return

	is_attacking = true

	# Horizontal laser at island height - forces player to drop below or jump over
	# Use the average height of islands (around 500) as the sweep height
	sweep_height = 500.0
	sweep_telegraph_active = true
	sweep_telegraph_timer = 1.5

	var direction = 1 if player_ref.global_position.x > global_position.x else -1
	EventBus.titan_sweep_telegraph.emit(direction)

	# 1.5s telegraph with horizontal red laser line
	await get_tree().create_timer(1.5).timeout

	sweep_telegraph_active = false

	if is_dead:
		is_attacking = false
		return

	_spawn_sweep_damage()
	EventBus.screen_shake.emit(10.0, 0.15)
	is_attacking = false

func _spawn_sweep_damage() -> void:
	var room = get_tree().current_scene
	var room_width = room.room_width if "room_width" in room else 1920.0

	# Massive horizontal laser at island height (10x larger)
	var laser_thickness = 600.0

	var damage_area = Area2D.new()
	damage_area.collision_layer = 32
	damage_area.collision_mask = 1
	damage_area.monitoring = true
	damage_area.monitorable = true

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(room_width + 200, laser_thickness)
	shape.shape = rect

	damage_area.add_child(shape)
	damage_area.global_position = Vector2(room_width / 2, sweep_height)
	get_tree().current_scene.add_child(damage_area)

	# Wait for physics to process the new area
	await get_tree().physics_frame
	await get_tree().physics_frame

	var bodies = damage_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			body.take_damage(2)

	await get_tree().create_timer(0.2).timeout
	damage_area.queue_free()

func _eye_laser() -> void:
	if not player_ref:
		return

	is_attacking = true
	var target = player_ref.global_position
	EventBus.titan_laser_telegraph.emit(global_position, target)

	await get_tree().create_timer(0.6).timeout

	if is_dead:
		is_attacking = false
		return

	_fire_laser(target)
	is_attacking = false

func _fire_laser(target: Vector2) -> void:
	var base_direction = (target - global_position).normalized()
	var base_angle = base_direction.angle()

	# Fire 5 bullets in a spread pattern
	var spread_angle = PI / 8  # 22.5 degrees total spread
	for i in range(5):
		var angle_offset = (i - 2) * (spread_angle / 4)  # -2, -1, 0, 1, 2
		var direction = Vector2.from_angle(base_angle + angle_offset)

		var bullet = SNIPER_BULLET_SCENE.instantiate()
		bullet.global_position = global_position + direction * 100
		bullet.direction = direction
		bullet.damage = 2
		bullet.speed = 1200.0
		get_tree().current_scene.add_child(bullet)

func take_damage(amount: int) -> void:
	if is_dead or phase == TitanPhase.INTRO or shield_active:
		return

	health -= amount
	EventBus.boss_damaged.emit(health, max_health)
	EventBus.hit_stop.emit(0.05)

	# Flash white
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1, 1)

func _defeat() -> void:
	phase = TitanPhase.DEFEATED
	is_dead = true

	if electric_floor:
		electric_floor.queue_free()

	EventBus.boss_defeated.emit()
	EventBus.hit_stop.emit(0.5)
	EventBus.screen_shake.emit(20.0, 1.0)

	# Death particles
	for i in range(20):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-80, 80))
		particle.color = body_color
		particle.size = randf_range(10, 25)
		get_tree().current_scene.add_child(particle)

	await get_tree().create_timer(2.0).timeout
	EventBus.victory.emit()
	queue_free()

func _draw() -> void:
	# Draw main body
	var body_rect = Rect2(-body_width / 2, -body_height / 2, body_width, body_height)
	draw_rect(body_rect, body_color)

	# Draw armor plating
	for i in range(3):
		var plate_y = -body_height / 2 + 30 + i * 60
		draw_line(Vector2(-body_width / 2 + 20, plate_y), Vector2(body_width / 2 - 20, plate_y), body_color * 0.7, 3.0)

	# Draw single giant eye
	var eye_size = 45.0
	var eye_pulse = sin(Time.get_ticks_msec() * 0.003) * 5.0
	draw_circle(Vector2(0, -20), eye_size + eye_pulse, eye_color)
	draw_circle(Vector2(0, -20), eye_size * 0.4, Color.BLACK)

	# Draw pupil tracking player
	if player_ref:
		var to_player = (player_ref.global_position - global_position).normalized()
		var pupil_offset = to_player * 10
		draw_circle(Vector2(0, -20) + pupil_offset, eye_size * 0.2, Color.RED)

	# Draw legs/supports
	for i in range(4):
		var leg_x = -body_width / 2 + 50 + i * (body_width - 100) / 3
		draw_line(Vector2(leg_x, body_height / 2), Vector2(leg_x, body_height / 2 + 80), body_color * 0.7, 15.0)
		draw_circle(Vector2(leg_x, body_height / 2 + 80), 12, body_color * 0.6)

	# Draw shield if active
	if shield_active:
		var shield_pulse = sin(Time.get_ticks_msec() * 0.005) * 0.2 + 0.6
		draw_arc(Vector2.ZERO, max(body_width, body_height) * 0.8, 0, TAU, 64, Color(0.3, 0.8, 1.0, shield_pulse), 6.0)
		draw_circle(Vector2.ZERO, max(body_width, body_height) * 0.8, Color(0.3, 0.8, 1.0, 0.1))

	# Draw phase indicator
	var phase_text = ""
	var phase_color = Color.WHITE
	match phase:
		TitanPhase.INTRO:
			phase_text = "GROUND-FAULT TITAN"
		TitanPhase.PHASE_1:
			phase_text = "PHASE 1"
			phase_color = Color.YELLOW
		TitanPhase.INTERMISSION:
			phase_text = "SHIELDED - DESTROY ALL ENEMIES"
			phase_color = Color.CYAN
		TitanPhase.PHASE_2:
			phase_text = "PHASE 2"
			phase_color = Color.ORANGE
		TitanPhase.FINAL_PHASE:
			phase_text = "FINAL PHASE"
			phase_color = Color.RED

	if phase_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-body_width / 2, -body_height / 2 - 40),
			phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, phase_color)

	# Draw attack telegraph indicators
	if is_attacking:
		match attack_sequence:
			0:  # Slam telegraph
				draw_string(ThemeDB.fallback_font, Vector2(-30, body_height / 2 + 30),
					"SLAM!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)
			1:  # Sweep telegraph
				draw_string(ThemeDB.fallback_font, Vector2(-40, body_height / 2 + 30),
					"SWEEP!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.ORANGE)
			2:  # Laser telegraph
				draw_string(ThemeDB.fallback_font, Vector2(-40, body_height / 2 + 30),
					"LASER!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)

	# Draw red pillar of light for Vertical Slam telegraph
	if slam_telegraph_active and slam_target_island >= 0:
		var island_pos = island_positions[slam_target_island]
		var local_pos = island_pos - global_position
		var room = get_tree().current_scene
		var room_width_val = room.room_width if room and "room_width" in room else 1920.0
		var pillar_width = room_width_val / 3.0  # Match slam damage width (1/3 of room)
		var pillar_alpha = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7

		# Draw pillar from ceiling to island
		draw_rect(Rect2(local_pos.x - pillar_width / 2, -1000, pillar_width, local_pos.y + 1000),
			Color(1.0, 0.2, 0.2, pillar_alpha * 0.5))
		# Draw brighter center
		draw_rect(Rect2(local_pos.x - pillar_width / 4, -1000, pillar_width / 2, local_pos.y + 1000),
			Color(1.0, 0.4, 0.4, pillar_alpha * 0.7))
		# Draw warning text
		draw_string(ThemeDB.fallback_font, Vector2(local_pos.x - 60, local_pos.y - 120),
			"SLAM INCOMING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.3, 0.3, pillar_alpha))

	# Draw horizontal laser line for Horizon Sweep telegraph
	if sweep_telegraph_active:
		var room = get_tree().current_scene
		var room_width = room.room_width if "room_width" in room else 1920.0
		var local_sweep_y = sweep_height - global_position.y
		var laser_alpha = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7

		# Draw horizontal laser line across entire screen
		draw_line(Vector2(-global_position.x - 100, local_sweep_y),
			Vector2(room_width - global_position.x + 100, local_sweep_y),
			Color(1.0, 0.2, 0.2, laser_alpha), 8.0)
		# Draw thicker glow
		draw_line(Vector2(-global_position.x - 100, local_sweep_y),
			Vector2(room_width - global_position.x + 100, local_sweep_y),
			Color(1.0, 0.4, 0.4, laser_alpha * 0.5), 20.0)
		# Draw warning text
		draw_string(ThemeDB.fallback_font, Vector2(-60, local_sweep_y - 30),
			"SWEEP INCOMING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.3, 0.3, laser_alpha))
