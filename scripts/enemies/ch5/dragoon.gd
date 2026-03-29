extends EnemyBase
class_name Dragoon
## Jet-powered aerial ram unit - hovers in mid-air, locks on and charges at player

enum DragoonState { HOVERING, LOCKING_ON, CHARGING, RECOVERING }

# Frame mapping: 0-2 idle/hover, 3-4 locking on, 5 charging, 6-7 recovering, 8 death
const FRAME_HOVER = 0
const FRAME_LOCKING_ON = 3
const FRAME_CHARGING = 5
const FRAME_RECOVERING = 6

@export var lock_on_time: float = 1.5
@export var charge_speed: float = 1200.0
@export var recover_time: float = 2.0
@export var hover_amplitude: float = 20.0
@export var hover_frequency: float = 2.0

var state: DragoonState = DragoonState.HOVERING
var state_timer: float = 0.0
var hover_timer: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var trail_particles: Array = []

# Visual properties
var body_length: float = 40.0
var body_width: float = 20.0

func _ready() -> void:
	super._ready()
	max_health = 3
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("dragoon", 45)
	spawn_position = global_position
	_setup_sprite()

	# Dragoon floats - no platform collision, but collides with room boundaries
	collision_mask = 16 | 128  # Player projectiles + room boundaries

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	hover_timer += delta

	match state:
		DragoonState.HOVERING:
			_state_hovering(delta)
		DragoonState.LOCKING_ON:
			_state_locking_on(delta)
		DragoonState.CHARGING:
			_state_charging(delta)
		DragoonState.RECOVERING:
			_state_recovering(delta)

	# Check collision with player during charge
	if state == DragoonState.CHARGING:
		_check_player_collision()

	move_and_slide()

	# Check wall collision after move_and_slide (only during charge)
	if state == DragoonState.CHARGING:
		_check_wall_collision()

	# Update sprite
	if anim_sprite:
		# Rotate sprite based on charge direction
		if state == DragoonState.CHARGING or state == DragoonState.LOCKING_ON:
			anim_sprite.rotation = charge_direction.angle()
		else:
			anim_sprite.rotation = 0

		match state:
			DragoonState.HOVERING:
				_set_sprite_frame(FRAME_HOVER)
			DragoonState.LOCKING_ON:
				_set_sprite_frame(FRAME_LOCKING_ON)
			DragoonState.CHARGING:
				_set_sprite_frame(FRAME_CHARGING)
			DragoonState.RECOVERING:
				_set_sprite_frame(FRAME_RECOVERING)

	queue_redraw()

func _state_hovering(delta: float) -> void:
	state_timer += delta

	# Hover in place with sine wave motion
	var hover_offset = sin(hover_timer * hover_frequency) * hover_amplitude
	global_position.y = spawn_position.y + hover_offset
	velocity = Vector2.ZERO

	# Start locking on after player is in range and we've hovered for a bit
	if player_ref and state_timer >= 1.0:
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		if dist_to_player < 600:
			state = DragoonState.LOCKING_ON
			state_timer = 0.0

func _state_locking_on(delta: float) -> void:
	state_timer += delta

	if not player_ref:
		state = DragoonState.HOVERING
		state_timer = 0.0
		return

	# Calculate direction to player (updates during lock-on)
	charge_direction = (player_ref.global_position - global_position).normalized()

	# Keep hovering during lock-on
	var hover_offset = sin(hover_timer * hover_frequency) * hover_amplitude * 0.5
	global_position.y = spawn_position.y + hover_offset
	velocity = Vector2.ZERO

	# After lock-on time, begin charge
	if state_timer >= lock_on_time:
		state = DragoonState.CHARGING
		state_timer = 0.0
		EventBus.dragoon_charge_started.emit(self, charge_direction)

func _state_charging(delta: float) -> void:
	state_timer += delta

	# Move in charge direction at high speed
	velocity = charge_direction * charge_speed

	# Spawn trail particles
	if randf() < 0.3:
		_spawn_trail_particle()

	# Stop charging after a certain distance or time (safety limit)
	if state_timer >= 2.0:
		state = DragoonState.RECOVERING
		state_timer = 0.0
		velocity = Vector2.ZERO

func _check_wall_collision() -> void:
	# Check if we hit a wall during the last move_and_slide
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision:
				# Hit something - enter recovery
				state = DragoonState.RECOVERING
				state_timer = 0.0
				velocity = Vector2.ZERO
				# Update spawn position to current location
				spawn_position = global_position
				break

func _state_recovering(delta: float) -> void:
	state_timer += delta

	# Slow to a stop
	velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)

	# Float back toward spawn position slowly
	var return_dir = (spawn_position - global_position).normalized()
	global_position += return_dir * 50 * delta

	# After recovery, return to hovering
	if state_timer >= recover_time:
		state = DragoonState.HOVERING
		state_timer = 0.0
		spawn_position = global_position  # Update spawn position

func _check_player_collision() -> void:
	if not player_ref:
		return

	var dist = global_position.distance_to(player_ref.global_position)
	if dist < 30:  # Collision radius
		# Deal damage to player
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(damage)

		# Dragoon stops and enters recovery
		state = DragoonState.RECOVERING
		state_timer = 0.0
		velocity = Vector2.ZERO

func _spawn_trail_particle() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var particle = Node2D.new()
	particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
	particle.global_position = global_position - charge_direction * 20
	particle.color = Color(1.0, 0.6, 0.2)  # Orange flame
	tree.current_scene.add_child(particle)

func _draw() -> void:
	# Calculate rotation based on charge direction or hover
	var rotation_angle = 0.0
	if state == DragoonState.CHARGING or state == DragoonState.LOCKING_ON:
		rotation_angle = charge_direction.angle()
	else:
		rotation_angle = 0.0  # Face right when hovering

	if not anim_sprite:
		var body_color = Color(0.85, 0.7, 0.2)  # Gold
		var accent_color = Color(0.8, 0.2, 0.2)  # Red

		if is_shielded:
			body_color = Color(0.3, 0.8, 1.0, 0.8)

		# Bonus health indicator
		if bonus_health > 0:
			body_color = body_color.lerp(Color(0.2, 0.9, 0.3), 0.4)

		# Draw jet body (sleek arrow shape)
		var points = PackedVector2Array([
			Vector2(body_length/2, 0).rotated(rotation_angle),   # Nose
			Vector2(-body_length/2, -body_width/2).rotated(rotation_angle),  # Back top
			Vector2(-body_length/3, 0).rotated(rotation_angle),  # Back center indent
			Vector2(-body_length/2, body_width/2).rotated(rotation_angle)   # Back bottom
		])
		draw_colored_polygon(points, body_color)

		# Draw body outline
		for i in range(points.size()):
			var next_i = (i + 1) % points.size()
			draw_line(points[i], points[next_i], accent_color, 2.0)

		# Draw wings
		var wing_color = accent_color
		var wing_top = PackedVector2Array([
			Vector2(-body_length/4, -body_width/4).rotated(rotation_angle),
			Vector2(-body_length/2, -body_width).rotated(rotation_angle),
			Vector2(-body_length/2, -body_width/4).rotated(rotation_angle)
		])
		var wing_bottom = PackedVector2Array([
			Vector2(-body_length/4, body_width/4).rotated(rotation_angle),
			Vector2(-body_length/2, body_width).rotated(rotation_angle),
			Vector2(-body_length/2, body_width/4).rotated(rotation_angle)
		])
		draw_colored_polygon(wing_top, wing_color)
		draw_colored_polygon(wing_bottom, wing_color)

		# Draw state indicator
		var indicator_color = Color.GRAY
		match state:
			DragoonState.HOVERING:
				indicator_color = Color(0.3, 0.6, 0.3)  # Green - safe
			DragoonState.LOCKING_ON:
				indicator_color = Color(1.0, 0.8, 0.0)  # Yellow - warning
			DragoonState.CHARGING:
				indicator_color = Color(1.0, 0.2, 0.2)  # Red - danger
			DragoonState.RECOVERING:
				indicator_color = Color(0.5, 0.5, 0.5)  # Gray - stunned

		draw_circle(Vector2(0, body_width/2 + 8), 4, indicator_color)

	# Draw thruster flames when charging (always visible)
	if state == DragoonState.CHARGING:
		var flame_length = randf_range(20, 35)
		var flame_base = Vector2(-body_length/2, 0).rotated(rotation_angle)
		var flame_tip = flame_base + Vector2(-flame_length, 0).rotated(rotation_angle)

		# Outer flame (orange)
		draw_line(flame_base, flame_tip, Color(1.0, 0.5, 0.0), 10.0)
		# Inner flame (yellow)
		draw_line(flame_base, flame_base + (flame_tip - flame_base) * 0.6, Color(1.0, 0.9, 0.3), 6.0)
		# Core (white)
		draw_line(flame_base, flame_base + (flame_tip - flame_base) * 0.3, Color(1.0, 1.0, 0.8), 3.0)

	# Draw lock-on indicator (always visible)
	if state == DragoonState.LOCKING_ON and player_ref:
		var pulse = sin(state_timer * 12) * 0.5 + 0.5
		var lock_color = Color(1.0, 0.3, 0.3, pulse)

		# Draw targeting line
		var target_pos = player_ref.global_position - global_position
		draw_line(Vector2.ZERO, target_pos.normalized() * 300, lock_color, 2.0)

		# Draw targeting reticle at player
		var reticle_size = 20.0 - state_timer / lock_on_time * 10.0
		draw_arc(target_pos, reticle_size, 0, TAU, 16, lock_color, 2.0)

		# Draw lock-on progress
		var progress = state_timer / lock_on_time
		draw_arc(Vector2.ZERO, body_length/2 + 10, -PI/2, -PI/2 + TAU * progress, 16, Color(1.0, 0.6, 0.2), 3.0)

	# Shield visual (always visible)
	if is_shielded:
		draw_arc(Vector2.ZERO, body_length/2 + 15, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
