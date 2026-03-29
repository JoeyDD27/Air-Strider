extends EnemyBase
class_name Countdown
## Fast rushing enemy with fuse timer - Chapter 4

enum CountdownState { PATROL, CHASE, FUSE_LIT, EXPLODING }

# Frame mapping: 0-2 idle/patrol, 3-4 chase, 5 fuse lit, 6-7 damaged, 8 death
const FRAME_PATROL = 0
const FRAME_CHASE = 3
const FRAME_FUSE_LIT = 5
const FRAME_EXPLODING = 8

@export var patrol_speed: float = 80.0
@export var chase_speed: float = 500.0
@export var detection_range: float = 400.0
@export var fuse_trigger_range: float = 100.0
@export var fuse_duration: float = 1.5
@export var explosion_radius: float = 150.0
@export var explosion_damage: int = 3
@export var jump_velocity: float = -450.0
@export var fly_force: float = -300.0
@export var fly_duration: float = 0.8
@export var jump_cooldown: float = 1.5

var state: CountdownState = CountdownState.PATROL
var state_timer: float = 0.0
var fuse_timer: float = 0.0
var patrol_direction: float = 1.0
var beep_timer: float = 0.0
var display_digits: String = "99"
var jump_timer: float = 0.0
var is_flying: bool = false
var fly_timer: float = 0.0

const EXPLOSION_SCRIPT = preload("res://scripts/hazards/explosion_area.gd")

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = 30
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	state_timer += delta

	match state:
		CountdownState.PATROL:
			_state_patrol(delta)
		CountdownState.CHASE:
			_state_chase(delta)
		CountdownState.FUSE_LIT:
			_state_fuse_lit(delta)
		CountdownState.EXPLODING:
			_state_exploding(delta)

	# Apply gravity
	velocity.y += 600 * delta

	move_and_slide()

	# Update sprite
	if anim_sprite:
		_update_sprite_facing(player_ref.global_position.x if player_ref else global_position.x + patrol_direction)
		match state:
			CountdownState.PATROL:
				_set_sprite_frame(FRAME_PATROL)
			CountdownState.CHASE:
				_set_sprite_frame(FRAME_CHASE)
			CountdownState.FUSE_LIT:
				_set_sprite_frame(FRAME_FUSE_LIT)
			CountdownState.EXPLODING:
				_set_sprite_frame(FRAME_EXPLODING)

	queue_redraw()

func _state_patrol(delta: float) -> void:
	velocity.x = patrol_speed * patrol_direction

	# Turn at walls
	if is_on_wall():
		patrol_direction *= -1

	# Check for player detection
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= detection_range:
			state = CountdownState.CHASE
			state_timer = 0.0

func _state_chase(delta: float) -> void:
	if not player_ref:
		state = CountdownState.PATROL
		return

	# Update jump cooldown
	jump_timer -= delta

	# Update fly timer
	if is_flying:
		fly_timer -= delta
		if fly_timer <= 0:
			is_flying = false

	# Sprint toward player
	var dir_to_player = sign(player_ref.global_position.x - global_position.x)
	velocity.x = chase_speed * dir_to_player

	# Jump toward player if they're above us
	var height_diff = player_ref.global_position.y - global_position.y
	if height_diff < -50 and is_on_floor() and jump_timer <= 0:
		# Player is above - jump!
		velocity.y = jump_velocity
		jump_timer = jump_cooldown
		is_flying = true
		fly_timer = fly_duration

	# Apply fly force when airborne and flying
	if is_flying and not is_on_floor():
		velocity.y += fly_force * delta  # Counter gravity for short flight

	# Check if close enough to trigger fuse
	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= fuse_trigger_range:
		state = CountdownState.FUSE_LIT
		state_timer = 0.0
		fuse_timer = 0.0

	# Lost player (too far)
	if dist > detection_range * 1.5:
		state = CountdownState.PATROL
		state_timer = 0.0

func _state_fuse_lit(delta: float) -> void:
	fuse_timer += delta
	beep_timer += delta
	jump_timer -= delta

	# Update fly timer
	if is_flying:
		fly_timer -= delta
		if fly_timer <= 0:
			is_flying = false

	# Update display
	var remaining = fuse_duration - fuse_timer
	display_digits = "%02d" % int(remaining * 100)

	# Still chase while fuse is lit!
	if player_ref:
		var dir_to_player = sign(player_ref.global_position.x - global_position.x)
		velocity.x = chase_speed * 0.7 * dir_to_player  # Slightly slower when fuse lit

		# Jump toward player if they're above us (even more aggressive when fuse lit!)
		var height_diff = player_ref.global_position.y - global_position.y
		if height_diff < -30 and is_on_floor() and jump_timer <= 0:
			velocity.y = jump_velocity * 1.2  # Stronger jump when fuse lit
			jump_timer = jump_cooldown * 0.7  # Shorter cooldown
			is_flying = true
			fly_timer = fly_duration

	# Apply fly force when airborne and flying
	if is_flying and not is_on_floor():
		velocity.y += fly_force * 1.3 * delta  # Stronger flight when fuse lit

	# Beep sound effect (visual feedback)
	if beep_timer >= 0.15 - (fuse_timer / fuse_duration) * 0.1:  # Beeps get faster
		beep_timer = 0.0
		# Would play beep sound here

	# Fuse complete - explode
	if fuse_timer >= fuse_duration:
		state = CountdownState.EXPLODING
		state_timer = 0.0

func _state_exploding(_delta: float) -> void:
	velocity.x = 0
	die()

func die() -> void:
	is_dead = true

	# Death rattle: Big explosion
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

	# Big screen shake for major explosion
	EventBus.screen_shake.emit(10.0, 0.25)

func _draw() -> void:
	var body_width = 25.0
	var body_height = 40.0

	if not anim_sprite:
		# Bipedal robot body (headless)

		# Legs
		var leg_offset = sin(state_timer * 15.0) * 8 if state != CountdownState.PATROL else sin(state_timer * 5.0) * 4
		draw_line(Vector2(-8, 0), Vector2(-12, 15 + abs(leg_offset) * 0.3), Color(0.4, 0.4, 0.4), 5.0)
		draw_line(Vector2(8, 0), Vector2(12, 15 - abs(leg_offset) * 0.3), Color(0.4, 0.4, 0.4), 5.0)

		# Feet
		draw_circle(Vector2(-12, 15 + abs(leg_offset) * 0.3), 4, Color(0.3, 0.3, 0.3))
		draw_circle(Vector2(12, 15 - abs(leg_offset) * 0.3), 4, Color(0.3, 0.3, 0.3))

		# Main body (torso)
		var body_rect = Rect2(-body_width / 2, -body_height, body_width, body_height)
		draw_rect(body_rect, Color(0.5, 0.5, 0.55))

		# Digital counter display on chest
		var display_rect = Rect2(-15, -body_height + 8, 30, 20)
		var display_color = Color(0.1, 0.1, 0.1)
		if state == CountdownState.FUSE_LIT:
			# Flashing red when fuse lit
			var flash = sin(fuse_timer * 20.0) > 0
			display_color = Color(0.3, 0.0, 0.0) if flash else Color(0.1, 0.0, 0.0)
		draw_rect(display_rect, display_color)

		# Display text
		var text_color = Color(0.0, 1.0, 0.0)  # Green digits
		if state == CountdownState.FUSE_LIT:
			text_color = Color(1.0, 0.0, 0.0)  # Red when fuse lit
			# Draw simplified digits
			_draw_digit(display_digits[0], Vector2(-10, -body_height + 12), text_color)
			_draw_digit(display_digits[1], Vector2(4, -body_height + 12), text_color)
		else:
			_draw_digit("9", Vector2(-10, -body_height + 12), text_color)
			_draw_digit("9", Vector2(4, -body_height + 12), text_color)

		# Arms
		draw_line(Vector2(-body_width / 2, -body_height + 25), Vector2(-body_width / 2 - 10, -body_height + 35), Color(0.4, 0.4, 0.4), 4.0)
		draw_line(Vector2(body_width / 2, -body_height + 25), Vector2(body_width / 2 + 10, -body_height + 35), Color(0.4, 0.4, 0.4), 4.0)

		# Warning stripes at top (where head would be)
		var stripe_rect = Rect2(-body_width / 2, -body_height - 5, body_width, 8)
		draw_rect(stripe_rect, Color(1.0, 0.8, 0.0))
		for i in range(5):
			var stripe_x = -body_width / 2 + i * 10
			draw_line(Vector2(stripe_x, -body_height - 5), Vector2(stripe_x + 5, -body_height + 3), Color(0.1, 0.1, 0.1), 3.0)

	# State indicator (always drawn - flashing glow when fuse lit)
	if state == CountdownState.FUSE_LIT:
		var body_rect = Rect2(-body_width / 2, -body_height, body_width, body_height)
		# Flashing body glow
		var glow_alpha = sin(fuse_timer * 15.0) * 0.3 + 0.4
		draw_rect(body_rect, Color(1.0, 0.2, 0.0, glow_alpha))

func _draw_digit(digit: String, pos: Vector2, color: Color) -> void:
	# Simplified 7-segment style digit drawing
	var w = 8.0
	var h = 14.0

	match digit:
		"0":
			draw_rect(Rect2(pos.x, pos.y, w, h), color, false, 2.0)
		"1":
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h), color, 2.0)
		"2":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(0, h), color, 2.0)
			draw_line(pos + Vector2(0, h), pos + Vector2(w, h), color, 2.0)
		"3":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h), pos + Vector2(w, h), color, 2.0)
		"4":
			draw_line(pos, pos + Vector2(0, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h), color, 2.0)
		"5":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos, pos + Vector2(0, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(w, h/2), pos + Vector2(w, h), color, 2.0)
			draw_line(pos + Vector2(0, h), pos + Vector2(w, h), color, 2.0)
		"6":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos, pos + Vector2(0, h), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(w, h/2), pos + Vector2(w, h), color, 2.0)
			draw_line(pos + Vector2(0, h), pos + Vector2(w, h), color, 2.0)
		"7":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h), color, 2.0)
		"8":
			draw_rect(Rect2(pos.x, pos.y, w, h), color, false, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
		"9":
			draw_line(pos, pos + Vector2(w, 0), color, 2.0)
			draw_line(pos, pos + Vector2(0, h/2), color, 2.0)
			draw_line(pos + Vector2(0, h/2), pos + Vector2(w, h/2), color, 2.0)
			draw_line(pos + Vector2(w, 0), pos + Vector2(w, h), color, 2.0)
			draw_line(pos + Vector2(0, h), pos + Vector2(w, h), color, 2.0)
