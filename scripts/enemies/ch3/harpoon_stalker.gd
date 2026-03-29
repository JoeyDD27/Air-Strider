extends EnemyBase
class_name HarpoonStalker
## Displacement enemy - fires harpoon that pulls player toward stalker

enum StalkerState { PATROLLING, AIMING, FIRING, REELING, COOLDOWN }

@export var patrol_speed: float = 80.0
@export var patrol_range: float = 200.0
@export var aim_time: float = 0.8
@export var fire_cooldown: float = 4.0
@export var harpoon_speed: float = 1600.0
@export var harpoon_range: float = 800.0
@export var pull_strength: float = 1200.0
@export var harpoon_damage: int = 1

var state: StalkerState = StalkerState.PATROLLING
var state_timer: float = 0.0
var patrol_direction: int = 1
var patrol_origin: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0

# Harpoon tracking
var active_harpoon: Node2D = null
var rope_end: Vector2 = Vector2.ZERO

# Visual
var body_size: float = 35.0
var leg_angle: float = 0.0

const HARPOON_SCENE = preload("res://scenes/entities/ch3/harpoon_projectile.tscn")

# Frame mapping: 0-2 patrol, 3-4 aiming, 5 firing, 6-7 reeling/cooldown, 8 death
const FRAME_PATROL = 0
const FRAME_AIMING = 3
const FRAME_FIRING = 5
const FRAME_REELING = 6
const FRAME_COOLDOWN = 7

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("harpoon_stalker", 40)
	patrol_origin = global_position
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0

	# Animate legs
	leg_angle = sin(state_timer * 8) * 0.3

	# State machine
	match state:
		StalkerState.PATROLLING:
			_state_patrolling(delta)
		StalkerState.AIMING:
			_state_aiming(delta)
		StalkerState.FIRING:
			_state_firing(delta)
		StalkerState.REELING:
			_state_reeling(delta)
		StalkerState.COOLDOWN:
			_state_cooldown(delta)

	move_and_slide()

	# Update sprite based on state
	if anim_sprite:
		if state == StalkerState.PATROLLING:
			anim_sprite.flip_h = (patrol_direction < 0)
		match state:
			StalkerState.PATROLLING:
				_set_sprite_frame(FRAME_PATROL)
			StalkerState.AIMING:
				_set_sprite_frame(FRAME_AIMING)
			StalkerState.FIRING:
				_set_sprite_frame(FRAME_FIRING)
			StalkerState.REELING:
				_set_sprite_frame(FRAME_REELING)
			StalkerState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _state_patrolling(delta: float) -> void:
	state_timer += delta

	# Patrol back and forth
	velocity.x = patrol_direction * patrol_speed

	# Reverse at patrol bounds
	var dist_from_origin = global_position.x - patrol_origin.x
	if abs(dist_from_origin) > patrol_range:
		patrol_direction *= -1

	# Check if player is in range to start aiming
	if player_ref:
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		if dist_to_player < harpoon_range:
			state = StalkerState.AIMING
			state_timer = 0.0
			velocity.x = 0

func _state_aiming(delta: float) -> void:
	state_timer += delta / cooldown_multiplier
	velocity.x = 0

	if not player_ref:
		state = StalkerState.PATROLLING
		state_timer = 0.0
		return

	# Track player
	var to_player = player_ref.global_position - global_position
	aim_angle = lerp_angle(aim_angle, to_player.angle(), delta * 5.0)

	# Fire after aim time
	if state_timer >= aim_time:
		_fire_harpoon()
		state = StalkerState.FIRING
		state_timer = 0.0

func _fire_harpoon() -> void:
	var harpoon = HARPOON_SCENE.instantiate()
	harpoon.global_position = global_position + Vector2.from_angle(aim_angle) * 20
	harpoon.direction = Vector2.from_angle(aim_angle)
	harpoon.speed = harpoon_speed
	harpoon.owner_stalker = self
	harpoon.pull_strength = pull_strength
	harpoon.damage = harpoon_damage

	active_harpoon = harpoon
	get_tree().current_scene.add_child(harpoon)

	EventBus.harpoon_fired.emit(self, Vector2.from_angle(aim_angle))

func _state_firing(delta: float) -> void:
	state_timer += delta

	# Track harpoon position for rope
	if is_instance_valid(active_harpoon):
		rope_end = active_harpoon.global_position
	else:
		# Harpoon hit something or expired
		state = StalkerState.REELING
		state_timer = 0.0
		active_harpoon = null

	# Timeout if harpoon travels too far
	if state_timer > 1.0:
		if is_instance_valid(active_harpoon):
			active_harpoon.queue_free()
		active_harpoon = null
		state = StalkerState.REELING
		state_timer = 0.0

func _state_reeling(delta: float) -> void:
	state_timer += delta

	# Animate rope reeling back
	rope_end = rope_end.lerp(global_position, delta * 5.0)

	if state_timer >= 0.5:
		state = StalkerState.COOLDOWN
		state_timer = 0.0

func _state_cooldown(delta: float) -> void:
	state_timer += delta / cooldown_multiplier

	# Resume patrol after cooldown
	if state_timer >= fire_cooldown:
		state = StalkerState.PATROLLING
		state_timer = 0.0

# Called by harpoon when it hits player
func on_harpoon_hit() -> void:
	if state == StalkerState.FIRING:
		state = StalkerState.REELING
		state_timer = 0.0
		active_harpoon = null

func _draw() -> void:
	var launcher_pos = Vector2(0, -body_size * 0.3)
	var launcher_dir = Vector2.from_angle(aim_angle)
	var accent_color = Color(0.6, 0.2, 0.6)  # Purple accent

	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var body_color = Color(0.35, 0.3, 0.4)  # Dark purple-gray

		if is_shielded:
			body_color = Color(0.3, 0.8, 1.0, 0.8)

		# Draw spider legs
		var leg_base_y = body_size * 0.3
		for side in [-1, 1]:
			for i in range(4):
				var leg_x_offset = (i - 1.5) * 10 * side
				var leg_y_offset = sin(leg_angle + i * 0.5) * 5

				var leg_start = Vector2(leg_x_offset, leg_base_y)
				var leg_mid = leg_start + Vector2(side * 20, 10 + leg_y_offset)
				var leg_end = leg_mid + Vector2(side * 15, 15)

				draw_line(leg_start, leg_mid, body_color, 3.0)
				draw_line(leg_mid, leg_end, body_color, 2.0)

		# Draw body
		var body_points = PackedVector2Array()
		for i in range(12):
			var angle = TAU * i / 12
			var radius = body_size * 0.5
			if i % 2 == 0:
				radius *= 0.9
			body_points.append(Vector2.from_angle(angle) * radius)
		draw_colored_polygon(body_points, body_color)

		# Draw harpoon launcher
		var launcher_end = launcher_pos + launcher_dir * 25
		draw_line(launcher_pos, launcher_end, Color(0.5, 0.5, 0.5), 8.0)
		draw_circle(launcher_end, 5, accent_color)

		# Draw eyes
		for i in range(4):
			var eye_angle = -PI/4 + i * (PI/2 / 3)
			var eye_pos = Vector2.from_angle(eye_angle) * (body_size * 0.25)
			var eye_color = Color(1.0, 0.3, 0.3) if state == StalkerState.AIMING else Color(0.8, 0.6, 0.0)
			draw_circle(eye_pos, 3, eye_color)

	# Draw targeting laser when aiming (overlay - always draw)
	if state == StalkerState.AIMING:
		var laser_length = 300.0
		var laser_end_pos = launcher_pos + launcher_dir * laser_length

		var pulse = sin(state_timer * 15) * 0.3 + 0.7
		var laser_color = Color(1.0, 0.2, 0.2, pulse * 0.6)
		draw_line(launcher_pos, laser_end_pos, laser_color, 2.0)

		# Targeting reticle
		draw_arc(laser_end_pos, 10, 0, TAU, 16, Color(1.0, 0.3, 0.3, pulse), 2.0)

	# Draw rope to active harpoon or reeling rope (overlay - always draw)
	if state in [StalkerState.FIRING, StalkerState.REELING]:
		var rope_color = Color(0.6, 0.5, 0.4, 0.8)
		var rope_local_end = rope_end - global_position
		draw_line(launcher_pos, rope_local_end, rope_color, 2.0)

	# Shield visual (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, body_size + 10, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
