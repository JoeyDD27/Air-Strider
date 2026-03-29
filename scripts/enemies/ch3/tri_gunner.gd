extends EnemyBase
class_name TriGunner
## Heavy suppression turret - tracks player with laser, fires 10-bullet bursts

enum GunnerState { IDLE, TRACKING, FIRING, COOLDOWN }

@export var track_time: float = 1.5
@export var fire_duration: float = 3.0
@export var bullets_per_burst: int = 10
@export var fire_interval: float = 0.3
@export var bullet_speed: float = 2000.0
@export var cooldown_time: float = 2.0
@export var bullet_spread: float = 0.087  # ~5 degrees in radians

var state: GunnerState = GunnerState.IDLE
var state_timer: float = 0.0
var fire_timer: float = 0.0
var bullets_fired: int = 0
var aim_angle: float = 0.0
var locked_angle: float = 0.0
var barrel_rotation: float = 0.0

# Visual properties
var body_width: float = 50.0
var body_height: float = 40.0
var barrel_length: float = 35.0

# Preload bullet scene
const BULLET_SCENE = preload("res://scenes/entities/ch3/tri_gunner_bullet.tscn")

# Frame mapping: 0-2 idle, 3-4 tracking, 5 firing, 6-7 cooldown, 8 death
const FRAME_IDLE = 0
const FRAME_TRACKING = 3
const FRAME_FIRING = 5
const FRAME_COOLDOWN = 6

func _ready() -> void:
	super._ready()
	max_health = 4
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("tri_gunner", 35)
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	# Apply gravity (stationary but can fall)
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0
		velocity.x = 0  # Stationary turret

	# State machine
	match state:
		GunnerState.IDLE:
			_state_idle(delta)
		GunnerState.TRACKING:
			_state_tracking(delta)
		GunnerState.FIRING:
			_state_firing(delta)
		GunnerState.COOLDOWN:
			_state_cooldown(delta)

	move_and_slide()

	# Update sprite based on state
	if anim_sprite:
		match state:
			GunnerState.IDLE:
				_set_sprite_frame(FRAME_IDLE)
			GunnerState.TRACKING:
				_set_sprite_frame(FRAME_TRACKING)
			GunnerState.FIRING:
				_set_sprite_frame(FRAME_FIRING)
			GunnerState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _state_idle(delta: float) -> void:
	state_timer += delta / cooldown_multiplier

	# Rotate barrels slowly in idle
	barrel_rotation += delta * 0.5

	# Wait a bit then start tracking
	if state_timer >= 0.5 and player_ref:
		state = GunnerState.TRACKING
		state_timer = 0.0

func _state_tracking(delta: float) -> void:
	state_timer += delta / cooldown_multiplier

	if not player_ref:
		state = GunnerState.IDLE
		state_timer = 0.0
		return

	# Calculate angle to player
	var to_player = player_ref.global_position - global_position
	var target_angle = to_player.angle()

	# Smooth rotation toward player
	aim_angle = lerp_angle(aim_angle, target_angle, delta * 3.0)

	# Rotate barrels faster when tracking
	barrel_rotation += delta * 2.0

	# After track_time, lock angle and start firing
	if state_timer >= track_time:
		locked_angle = aim_angle
		state = GunnerState.FIRING
		state_timer = 0.0
		fire_timer = 0.0
		bullets_fired = 0

func _state_firing(delta: float) -> void:
	state_timer += delta / cooldown_multiplier
	fire_timer += delta / cooldown_multiplier

	# Continue tracking player while firing (slower than tracking state)
	if player_ref:
		var to_player = player_ref.global_position - global_position
		var target_angle = to_player.angle()
		aim_angle = lerp_angle(aim_angle, target_angle, delta * 2.0)

	# Spin barrels fast when firing
	barrel_rotation += delta * 10.0

	# Fire bullets at interval
	if fire_timer >= fire_interval and bullets_fired < bullets_per_burst:
		_fire_bullet()
		fire_timer = 0.0
		bullets_fired += 1

	# Done firing after all bullets or time elapsed
	if bullets_fired >= bullets_per_burst or state_timer >= fire_duration:
		state = GunnerState.COOLDOWN
		state_timer = 0.0

func _fire_bullet() -> void:
	var bullet = BULLET_SCENE.instantiate()

	# Apply small random spread
	var spread_offset = randf_range(-bullet_spread, bullet_spread)
	var fire_angle = aim_angle + spread_offset

	# Spawn at barrel tip
	var spawn_offset = Vector2.from_angle(fire_angle) * (barrel_length + 10)
	bullet.global_position = global_position + spawn_offset
	bullet.direction = Vector2.from_angle(fire_angle)
	bullet.speed = bullet_speed

	get_tree().current_scene.add_child(bullet)

	# Muzzle flash effect
	EventBus.screen_shake.emit(2.0, 0.05)

func _state_cooldown(delta: float) -> void:
	state_timer += delta / cooldown_multiplier

	# Slow barrel rotation during cooldown
	barrel_rotation += delta * 0.3

	if state_timer >= cooldown_time:
		state = GunnerState.IDLE
		state_timer = 0.0

func _draw() -> void:
	var barrel_center = Vector2(0, -5)

	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var body_color = Color(0.4, 0.4, 0.5)  # Metallic gray
		var accent_color = Color(0.8, 0.3, 0.3)  # Red accents

		if is_shielded:
			body_color = Color(0.3, 0.8, 1.0, 0.8)

		var body_rect = Rect2(-body_width/2, -body_height/2, body_width, body_height)
		draw_rect(body_rect, body_color)
		draw_rect(body_rect, accent_color, false, 2.0)

		# Draw rotating barrel assembly
		var barrel_radius = 15.0
		for i in range(3):
			var angle = barrel_rotation + (TAU / 3) * i
			var barrel_pos = barrel_center + Vector2.from_angle(angle) * barrel_radius
			var barrel_dir = Vector2.from_angle(aim_angle)
			var barrel_end = barrel_pos + barrel_dir * barrel_length

			var barrel_color = Color(0.3, 0.3, 0.35)
			if state == GunnerState.FIRING:
				barrel_color = Color(0.6, 0.4, 0.3)

			draw_line(barrel_pos, barrel_end, barrel_color, 6.0)
			draw_circle(barrel_end, 3, barrel_color)

	# Draw tracking laser (overlay - always draw)
	if state == GunnerState.TRACKING:
		var laser_length = 500.0
		var laser_end = barrel_center + Vector2.from_angle(aim_angle) * laser_length

		var pulse = sin(state_timer * 10) * 0.3 + 0.7
		var laser_color = Color(1.0, 0.2, 0.2, pulse * 0.5)
		draw_line(barrel_center, laser_end, laser_color, 2.0)
		draw_circle(laser_end, 4, Color(1.0, 0.3, 0.3, pulse))

	# Draw aim indicator when firing (overlay - always draw)
	if state == GunnerState.FIRING:
		var fire_indicator_length = 100.0
		var indicator_end = barrel_center + Vector2.from_angle(aim_angle) * fire_indicator_length
		draw_line(barrel_center, indicator_end, Color(1.0, 0.5, 0.0, 0.6), 3.0)

	# Draw reload indicator during cooldown (overlay - always draw)
	if state == GunnerState.COOLDOWN:
		var progress = state_timer / cooldown_time
		draw_arc(Vector2.ZERO, body_width/2 + 5, -PI/2, -PI/2 + TAU * progress, 16, Color(0.5, 0.8, 0.5, 0.7), 3.0)

	# Draw state indicator (overlay - always draw)
	var indicator_color = Color.GRAY
	match state:
		GunnerState.IDLE:
			indicator_color = Color(0.3, 0.3, 0.3)
		GunnerState.TRACKING:
			indicator_color = Color(1.0, 0.8, 0.0)
		GunnerState.FIRING:
			indicator_color = Color(1.0, 0.2, 0.2)
		GunnerState.COOLDOWN:
			indicator_color = Color(0.3, 0.6, 0.3)

	draw_circle(Vector2(0, body_height/2 - 5), 5, indicator_color)

	# Shield visual (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, body_width/2 + 15, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
