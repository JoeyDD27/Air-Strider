extends EnemyBase
class_name TetherAnchor
## Fires tether that attaches and pulls player - Chapter 4

enum AnchorState { AIMING, FIRING, ATTACHED, COOLDOWN }

# Frame mapping: 0-2 idle, 3 aiming, 4 firing, 5 attached/pulling, 6-7 cooldown, 8 death
const FRAME_IDLE = 0
const FRAME_AIMING = 3
const FRAME_FIRING = 4
const FRAME_ATTACHED = 5
const FRAME_COOLDOWN = 6

@export var attach_range: float = 600.0
@export var fire_cooldown: float = 3.0
@export var aim_duration: float = 1.0
@export var proximity_explosion_range: float = 80.0
@export var proximity_explosion_damage: int = 2

var state: AnchorState = AnchorState.AIMING
var state_timer: float = 0.0
var aim_angle: float = 0.0
var active_tether: Node = null
var gear_rotation: float = 0.0

const TETHER_PROJECTILE = preload("res://scripts/enemies/ch4/tether_projectile.gd")
const EXPLOSION_SCRIPT = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	super._ready()
	max_health = 3
	health = max_health
	reward = 45
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	state_timer += delta
	gear_rotation += delta * 2.0

	match state:
		AnchorState.AIMING:
			_state_aiming(delta)
		AnchorState.FIRING:
			_state_firing(delta)
		AnchorState.ATTACHED:
			_state_attached(delta)
		AnchorState.COOLDOWN:
			_state_cooldown(delta)

	# Apply gravity (anchored to floor)
	velocity.y += 600 * delta
	move_and_slide()

	# Update sprite
	if anim_sprite:
		match state:
			AnchorState.AIMING:
				_set_sprite_frame(FRAME_AIMING)
			AnchorState.FIRING:
				_set_sprite_frame(FRAME_FIRING)
			AnchorState.ATTACHED:
				_set_sprite_frame(FRAME_ATTACHED)
			AnchorState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _state_aiming(delta: float) -> void:
	# Track player
	if player_ref:
		var to_player = player_ref.global_position - global_position
		aim_angle = to_player.angle()

		var dist = to_player.length()
		if dist <= attach_range and state_timer >= aim_duration:
			state = AnchorState.FIRING
			state_timer = 0.0

func _state_firing(_delta: float) -> void:
	# Fire tether projectile
	_fire_tether()
	state = AnchorState.ATTACHED
	state_timer = 0.0

func _state_attached(delta: float) -> void:
	# Check if tether is still valid
	if not is_instance_valid(active_tether):
		state = AnchorState.COOLDOWN
		state_timer = 0.0
		active_tether = null
		return

	# Gear rotation speeds up when pulling
	gear_rotation += delta * 4.0

func _state_cooldown(_delta: float) -> void:
	if state_timer >= fire_cooldown:
		state = AnchorState.AIMING
		state_timer = 0.0

func _fire_tether() -> void:
	var tether = Area2D.new()
	tether.set_script(TETHER_PROJECTILE)
	tether.global_position = global_position + Vector2.from_angle(aim_angle) * 30
	tether.direction = Vector2.from_angle(aim_angle)
	tether.owner_anchor = self
	tether.max_range = attach_range

	get_tree().current_scene.add_child(tether)
	active_tether = tether

func die() -> void:
	is_dead = true

	# Release tether if active
	if is_instance_valid(active_tether):
		active_tether.release()

	# Death rattle: Proximity explosion
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	# Only explode if player is close
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= proximity_explosion_range:
			var explosion = Area2D.new()
			explosion.set_script(EXPLOSION_SCRIPT)
			explosion.radius = proximity_explosion_range
			explosion.damage = proximity_explosion_damage
			explosion.global_position = global_position
			get_tree().current_scene.call_deferred("add_child", explosion)

			EventBus.screen_shake.emit(6.0, 0.15)

func _draw() -> void:
	var base_width = 50.0
	var base_height = 35.0
	var winch_center = Vector2(0, -base_height / 2)
	var winch_radius = 12.0

	if not anim_sprite:
		# Base block (heavy anchor)
		var base_rect = Rect2(-base_width / 2, -base_height, base_width, base_height)

		# Metal base
		draw_rect(base_rect, Color(0.4, 0.4, 0.45))

		# Bolts at corners
		draw_circle(Vector2(-base_width / 2 + 6, -base_height + 6), 4, Color(0.3, 0.3, 0.35))
		draw_circle(Vector2(base_width / 2 - 6, -base_height + 6), 4, Color(0.3, 0.3, 0.35))
		draw_circle(Vector2(-base_width / 2 + 6, -6), 4, Color(0.3, 0.3, 0.35))
		draw_circle(Vector2(base_width / 2 - 6, -6), 4, Color(0.3, 0.3, 0.35))

		# Gear/winch
		draw_circle(winch_center, winch_radius, Color(0.5, 0.5, 0.5))
		# Gear teeth
		var num_teeth = 8
		for i in range(num_teeth):
			var angle = gear_rotation + (float(i) / num_teeth) * TAU
			var tooth_start = winch_center + Vector2.from_angle(angle) * winch_radius
			var tooth_end = winch_center + Vector2.from_angle(angle) * (winch_radius + 5)
			draw_line(tooth_start, tooth_end, Color(0.4, 0.4, 0.4), 3.0)

		# Center axle
		draw_circle(winch_center, 4, Color(0.3, 0.3, 0.3))

		# Launcher turret
		var turret_length = 25.0
		var turret_width = 10.0
		var turret_end = Vector2.from_angle(aim_angle) * turret_length

		# Turret barrel
		var perp = Vector2(-sin(aim_angle), cos(aim_angle)) * turret_width / 2
		var barrel_points = PackedVector2Array([
			winch_center + perp,
			winch_center - perp,
			winch_center + turret_end - perp,
			winch_center + turret_end + perp
		])
		draw_colored_polygon(barrel_points, Color(0.35, 0.35, 0.4))

		# Barrel tip
		draw_circle(winch_center + turret_end, turret_width / 2, Color(0.3, 0.3, 0.35))

		# State indicator light
		var light_color = Color(0.2, 0.8, 0.2)  # Green = ready
		match state:
			AnchorState.AIMING:
				light_color = Color(1.0, 1.0, 0.0)  # Yellow = aiming
			AnchorState.ATTACHED:
				light_color = Color(1.0, 0.0, 0.0)  # Red = attached
				# Pulsing when pulling
				var pulse = sin(state_timer * 8.0) * 0.3 + 0.7
				light_color.a = pulse
			AnchorState.COOLDOWN:
				light_color = Color(0.5, 0.5, 0.5)  # Gray = cooldown

		draw_circle(Vector2(base_width / 2 - 10, -base_height + 10), 5, light_color)

	# Aim laser when aiming (always visible)
	if state == AnchorState.AIMING and player_ref:
		var laser_end = Vector2.from_angle(aim_angle) * attach_range
		var laser_alpha = sin(state_timer * 10.0) * 0.2 + 0.4
		draw_line(winch_center, winch_center + laser_end, Color(1.0, 0.3, 0.0, laser_alpha), 1.0)
