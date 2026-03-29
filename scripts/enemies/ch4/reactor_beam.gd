extends EnemyBase
class_name ReactorBeam
## Stationary sniper with vacuum pull death rattle - Chapter 4

enum ReactorState { IDLE, TRACKING, CHARGING, FIRING, COOLDOWN }

# Frame mapping: 0-2 idle, 3 tracking, 4 charging, 5 firing, 6-7 cooldown, 8 death
const FRAME_IDLE = 0
const FRAME_TRACKING = 3
const FRAME_CHARGING = 4
const FRAME_FIRING = 5
const FRAME_COOLDOWN = 6

@export var track_duration: float = 1.5
@export var charge_duration: float = 1.0
@export var fire_cooldown: float = 2.0
@export var beam_damage: int = 2
@export var beam_range: float = 800.0
@export var vacuum_radius: float = 200.0
@export var vacuum_duration: float = 1.5
@export var vacuum_strength: float = 400.0
@export var explosion_radius: float = 180.0
@export var explosion_damage: int = 3

var state: ReactorState = ReactorState.IDLE
var state_timer: float = 0.0
var aim_angle: float = 0.0
var locked_angle: float = 0.0
var charge_level: float = 0.0
var lens_glow: float = 0.0

const VACUUM_SCRIPT = preload("res://scripts/hazards/vacuum_area.gd")

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = 55
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	state_timer += delta

	match state:
		ReactorState.IDLE:
			_state_idle(delta)
		ReactorState.TRACKING:
			_state_tracking(delta)
		ReactorState.CHARGING:
			_state_charging(delta)
		ReactorState.FIRING:
			_state_firing(delta)
		ReactorState.COOLDOWN:
			_state_cooldown(delta)

	# Stationary - no movement, just gravity to stick to platform
	velocity.y += 600 * delta
	velocity.x = 0
	move_and_slide()

	# Update sprite
	if anim_sprite:
		match state:
			ReactorState.IDLE:
				_set_sprite_frame(FRAME_IDLE)
			ReactorState.TRACKING:
				_set_sprite_frame(FRAME_TRACKING)
			ReactorState.CHARGING:
				_set_sprite_frame(FRAME_CHARGING)
			ReactorState.FIRING:
				_set_sprite_frame(FRAME_FIRING)
			ReactorState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _state_idle(_delta: float) -> void:
	# Check for player in range
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= beam_range:
			state = ReactorState.TRACKING
			state_timer = 0.0

func _state_tracking(delta: float) -> void:
	# Track player with red laser sight
	if player_ref:
		var to_player = player_ref.global_position - global_position
		aim_angle = lerp_angle(aim_angle, to_player.angle(), delta * 3.0)

		var dist = to_player.length()
		if dist > beam_range * 1.2:
			state = ReactorState.IDLE
			state_timer = 0.0
			return

	lens_glow = state_timer / track_duration * 0.5

	if state_timer >= track_duration:
		state = ReactorState.CHARGING
		state_timer = 0.0
		locked_angle = aim_angle  # Lock aim

func _state_charging(delta: float) -> void:
	# Locked aim, charging up
	charge_level = state_timer / charge_duration
	lens_glow = 0.5 + charge_level * 0.5

	if state_timer >= charge_duration:
		state = ReactorState.FIRING
		state_timer = 0.0
		_fire_beam()

func _state_firing(_delta: float) -> void:
	lens_glow = 1.0

	if state_timer >= 0.2:  # Brief firing state
		state = ReactorState.COOLDOWN
		state_timer = 0.0
		charge_level = 0.0
		lens_glow = 0.0

func _state_cooldown(_delta: float) -> void:
	lens_glow = 0.0

	if state_timer >= fire_cooldown:
		state = ReactorState.IDLE
		state_timer = 0.0

func _fire_beam() -> void:
	# Instant hitscan beam
	var beam_dir = Vector2.from_angle(locked_angle)
	var beam_end = global_position + beam_dir * beam_range

	# Check if player is hit (simple raycast approximation)
	if player_ref:
		var to_player = player_ref.global_position - global_position
		var player_dist = to_player.length()
		var dot = to_player.normalized().dot(beam_dir)

		# If player is roughly in beam path
		if dot > 0.95 and player_dist <= beam_range:
			player_ref.take_damage(beam_damage)

	EventBus.screen_shake.emit(4.0, 0.1)

func die() -> void:
	is_dead = true

	# Death rattle: Vacuum pull then explosion
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	# Spawn vacuum area that pulls then explodes
	var vacuum = Area2D.new()
	vacuum.set_script(VACUUM_SCRIPT)
	vacuum.radius = vacuum_radius
	vacuum.duration = vacuum_duration
	vacuum.pull_strength = vacuum_strength
	vacuum.final_explosion_radius = explosion_radius
	vacuum.final_explosion_damage = explosion_damage
	vacuum.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", vacuum)

	# Initial screen effect
	EventBus.screen_shake.emit(3.0, 0.1)

func _draw() -> void:
	var base_width = 30.0
	var base_height = 20.0
	var tower_height = 50.0
	var lens_center = Vector2(0, -base_height - tower_height + 5)
	var lens_radius = 15.0

	if not anim_sprite:
		# Glass cannon turret body

		# Base platform
		var base_rect = Rect2(-base_width / 2, -base_height, base_width, base_height)
		draw_rect(base_rect, Color(0.35, 0.35, 0.4))

		# Support struts
		draw_line(Vector2(-base_width / 2 + 5, -base_height), Vector2(-8, -base_height - tower_height + 15), Color(0.4, 0.4, 0.45), 3.0)
		draw_line(Vector2(base_width / 2 - 5, -base_height), Vector2(8, -base_height - tower_height + 15), Color(0.4, 0.4, 0.45), 3.0)

		# Central tower
		var tower_rect = Rect2(-10, -base_height - tower_height, 20, tower_height)
		draw_rect(tower_rect, Color(0.3, 0.3, 0.35))

		# Lens mount
		draw_circle(lens_center, lens_radius + 3, Color(0.25, 0.25, 0.3))

		# Glass lens (cyan/blue)
		var lens_color = Color(0.3, 0.8, 1.0, 0.8)
		if lens_glow > 0:
			lens_color = lens_color.lerp(Color(1.0, 0.3, 0.0), lens_glow)
		draw_circle(lens_center, lens_radius, lens_color)

		# Lens inner detail
		draw_circle(lens_center, lens_radius * 0.6, Color(0.5, 0.9, 1.0, 0.6).lerp(Color(1.0, 0.5, 0.0), lens_glow))
		draw_circle(lens_center, lens_radius * 0.3, Color(0.8, 1.0, 1.0, 0.8).lerp(Color(1.0, 0.8, 0.0), lens_glow))

		# State indicator lights
		var light_y = -base_height - 10
		for i in range(3):
			var light_x = -8 + i * 8
			var light_on = false
			match state:
				ReactorState.TRACKING:
					light_on = i == 0
				ReactorState.CHARGING:
					light_on = i <= 1
				ReactorState.FIRING:
					light_on = true
			var light_color = Color(0.2, 0.2, 0.2) if not light_on else Color(1.0, 0.3, 0.0)
			draw_circle(Vector2(light_x, light_y), 3, light_color)

		# Fragile indicator (glass body)
		if health == 1:
			# Crack lines when damaged
			draw_line(lens_center + Vector2(-5, -8), lens_center + Vector2(3, 5), Color(0.2, 0.2, 0.2, 0.5), 1.0)
			draw_line(lens_center + Vector2(6, -6), lens_center + Vector2(-2, 8), Color(0.2, 0.2, 0.2, 0.5), 1.0)

	# Aiming laser (always visible)
	if state == ReactorState.TRACKING:
		var laser_end = Vector2.from_angle(aim_angle) * beam_range
		var laser_alpha = 0.3 + sin(state_timer * 15.0) * 0.1
		draw_line(lens_center, lens_center + laser_end, Color(1.0, 0.0, 0.0, laser_alpha), 1.0)

	# Locked aim indicator (always visible)
	if state == ReactorState.CHARGING:
		var laser_end = Vector2.from_angle(locked_angle) * beam_range
		var charge_width = 1.0 + charge_level * 4.0
		draw_line(lens_center, lens_center + laser_end, Color(1.0, 0.5, 0.0, 0.6), charge_width)

		# Charging arc around lens
		var charge_arc = charge_level * TAU
		draw_arc(lens_center, lens_radius + 8, 0, charge_arc, 16, Color(1.0, 0.6, 0.0), 3.0)

	# Firing beam (always visible)
	if state == ReactorState.FIRING:
		var laser_end = Vector2.from_angle(locked_angle) * beam_range
		draw_line(lens_center, lens_center + laser_end, Color(1.0, 0.8, 0.0, 1.0), 8.0)
		draw_line(lens_center, lens_center + laser_end, Color(1.0, 1.0, 0.8, 0.8), 4.0)
