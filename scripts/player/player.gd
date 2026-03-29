extends CharacterBody2D
class_name Player
## Player controller with grapple hook, momentum physics, and charged weapon

# Physics constants
const GRAVITY: float = 600.0  # Reduced from 980 for slower falling
const INPUT_FORCE: float = 1500.0  # Buffed 200% (was 500)
const CHARGE_INPUT_MULTIPLIER: float = 0.2  # 20% directional authority while charging
const GROUND_JUMP_FORCE: float = 450.0  # Normal jump from ground
const AIR_JUMP_FORCE: float = 200.0  # Weak air jump after grapple release
const MAX_GRAPPLE_DISTANCE: float = 800.0
const MAX_VELOCITY: float = 1500.0  # Cap velocity to prevent wall clipping

# Player state
enum State { AIRBORNE, GRAPPLING, CHARGING, DEAD, INVINCIBLE }
var current_state: State = State.AIRBORNE

# Grapple variables
var is_grappling: bool = false
var grapple_anchor: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var min_rope_length: float = 50.0

# Combat variables
var is_charging: bool = false
var charge_amount: float = 0.0
var max_charge: float = 1.0
var charge_speed: float = 2.0

# Double jump
var has_double_jump: bool = true  # Resets when landing

# Invincibility
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var invincibility_duration: float = 0.5

# Visual
var size: float = 60.0
var color: Color = Color(0.267, 0.533, 1.0)  # Blue
var facing_direction: int = 1  # 1 = right, -1 = left

# Animation timing
var idle_pose_timer: float = 0.0
var idle_pose_duration: float = 3.0  # Seconds to hold each idle pose
var current_idle_pose: int = 0
const RISING_VELOCITY_THRESHOLD: float = -100.0  # Negative Y = going up

# Firing animation state
var is_firing_release: bool = false  # True when playing release frames after shot
var firing_release_timer: float = 0.0
const FIRING_RELEASE_DURATION: float = 0.2  # Duration of release animation

# Death animation state
var is_playing_death_anim: bool = false
var death_start_time: float = 0.0  # Real time when death started
const DEATH_HIT_STOP_DURATION: float = 0.3  # Time freeze on death
const DEATH_ANIM_DURATION: float = 0.75  # Death animation length
const GHOST_ANIM_DURATION: float = 0.5  # Ghost fade animation length
var death_phase: int = 0  # 0=hit_stop, 1=death_anim, 2=ghost_anim, 3=done
var phase_start_time: float = 0.0  # Real time when current phase started

# Hand offsets for grapple rope attachment (in sprite local coordinates)
# Scaled by sprite scale when used
const HAND_OFFSETS_AIRBORNE: Array = [
	Vector2(-25, -70),   # frame 0 - rising, left hand up high
	Vector2(-25, -70),   # frame 1 - rising, left hand up high
	Vector2(-30, -20),   # frame 2 - falling, left hand curled pose
	Vector2(-30, -20),   # frame 3 - falling, left hand curled pose
]

# Hand offsets for grapple_up animation (character reaching upward)
# Scaled down 70% so offsets are smaller
const HAND_OFFSETS_GRAPPLE_UP_RIGHT: Array = [
	Vector2(-20, -40),   # frame 0 - reaching up-right
	Vector2(-20, -40),   # frame 1
]

# Hand offsets for grapple_up_left animation (flipped version)
const HAND_OFFSETS_GRAPPLE_UP_LEFT: Array = [
	Vector2(20, -40),    # frame 0 - reaching up-left (mirrored X)
	Vector2(20, -40),    # frame 1
]

# Hand offsets for grapple_down/idle animation
const HAND_OFFSETS_IDLE: Array = [
	Vector2(-20, -10),   # frame 0 - idle pose
	Vector2(-20, -10),   # frame 1
	Vector2(-20, -10),   # frame 2
	Vector2(-20, -10),   # frame 3
]

# Grapple facing direction (locked when grappling)
var grapple_facing: int = 1

# Tool reference
var equipped_tool: Node = null

# Module reference
var equipped_module: Node = null

# Safe position tracking (for Gravity Anchor module)
var last_safe_position: Vector2 = Vector2.ZERO
var safe_position_timer: float = 0.0
const SAFE_POSITION_CHECK_INTERVAL: float = 0.5

# References
@onready var grapple_line: Line2D = $GrappleLine
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	_setup_collision()
	_connect_signals()
	_load_equipped_tool()
	_load_equipped_module()
	last_safe_position = global_position
	# Grant spawn invincibility to give player time to react
	_start_invincibility(2.0)

func _load_equipped_tool() -> void:
	# Load equipped tool from GameManager when player spawns
	if GameManager.equipped_tool != "":
		var tool_path = "res://scenes/entities/tools/%s.tscn" % GameManager.equipped_tool
		if ResourceLoader.exists(tool_path):
			var tool_scene = load(tool_path)
			equipped_tool = tool_scene.instantiate()
			add_child(equipped_tool)

func _load_equipped_module() -> void:
	# Load equipped module from GameManager when player spawns
	if GameManager.equipped_module != "":
		var module_path = "res://scenes/entities/modules/%s.tscn" % GameManager.equipped_module
		if ResourceLoader.exists(module_path):
			var module_scene = load(module_path)
			equipped_module = module_scene.instantiate()
			add_child(equipped_module)
			equipped_module.initialize(self)

func _setup_collision() -> void:
	# Set collision layers (player layer)
	collision_layer = 1
	# Collide with platforms, enemies, projectiles, hazards, room boundaries
	# Layer 2=platforms, 4=enemies, 8=projectiles, 32=hazards, 128=room boundaries
	collision_mask = 2 | 4 | 8 | 32 | 128

func _connect_signals() -> void:
	EventBus.player_respawned.connect(_on_respawned)
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.module_equipped.connect(_on_module_equipped)

func _physics_process(delta: float) -> void:
	# Handle death animation sequence (only if actually dying, not just DEAD state from phantom drone)
	if current_state == State.DEAD and is_playing_death_anim:
		_process_death_animation(delta)
		return

	# Skip all processing if being carried by phantom drone
	if current_state == State.DEAD:
		return

	# Update invincibility
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			current_state = State.AIRBORNE

	# Track safe position for Gravity Anchor module
	_update_safe_position(delta)

	# Handle input
	_handle_input(delta)

	# Apply physics based on state
	if is_grappling:
		_update_grapple_physics(delta)
	else:
		_update_free_physics(delta)

	# Update charge with module modifier
	if is_charging:
		var charge_mult = 1.0
		if equipped_module and equipped_module.has_method("on_charge_updated"):
			charge_mult = equipped_module.on_charge_updated(delta, charge_amount / max_charge)
		charge_amount = min(charge_amount + charge_speed * charge_mult * delta, max_charge)

	# Move and handle collisions
	move_and_slide()

	# Update grapple line visual
	_update_grapple_visual()

	# Update facing direction based on horizontal velocity
	if abs(velocity.x) > 10:
		facing_direction = 1 if velocity.x > 0 else -1

	# Update idle pose timer (for holding poses for a few seconds)
	if is_on_floor() and abs(velocity.x) <= 10 and current_state != State.DEAD:
		idle_pose_timer += delta
		if idle_pose_timer >= idle_pose_duration:
			idle_pose_timer = 0.0
			# Cycle through idle poses (4 frames: 0, 1, 2, 3)
			current_idle_pose += 1
			if current_idle_pose >= 4:
				current_idle_pose = 0

	# Update firing release animation timer
	if is_firing_release:
		firing_release_timer += delta
		if firing_release_timer >= FIRING_RELEASE_DURATION:
			is_firing_release = false

	# Update sprite animation
	_update_animation()

	# Queue redraw for charge arc overlay (always redraw to clear when not charging)
	queue_redraw()

func _handle_input(delta: float) -> void:
	# Get mouse position for aiming
	var mouse_pos = get_global_mouse_position()

	# Grapple input (right click) - cannot grapple while charging
	if Input.is_action_just_pressed("grapple"):
		if is_grappling:
			_release_grapple()
		elif not is_charging:
			_try_grapple(mouse_pos)

	# Shoot input (left click) - hold to charge, release to fire
	# Cannot charge while Phalanx Shield is active or in Phantom mode
	var shield_blocking = equipped_tool and equipped_tool.get("shield_active") == true
	if Input.is_action_just_pressed("shoot") and not is_grappling and not shield_blocking and can_attack():
		_start_charging()

	if is_charging:
		if Input.is_action_just_released("shoot"):
			_fire_weapon(mouse_pos)

	# Tool input (E key)
	if Input.is_action_just_pressed("use_tool") and equipped_tool:
		equipped_tool.activate(self)

	# Jump (space) - works when on ground OR has double jump available
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			_ground_jump()
			has_double_jump = true  # Reset double jump when on ground
		elif has_double_jump and not is_grappling:
			_double_jump()

	# Reset double jump when landing
	if is_on_floor() and not has_double_jump:
		has_double_jump = true

	# Reset hazard plating immunity when landing safely
	if is_on_floor() and equipped_module and equipped_module.has_method("reset_immunity"):
		equipped_module.reset_immunity()

	# Directional input
	var input_dir = Input.get_axis("move_left", "move_right")
	var input_force = Vector2(input_dir * INPUT_FORCE, 0)

	# Apply input with charge penalty
	if is_charging:
		input_force *= CHARGE_INPUT_MULTIPLIER

	if not is_grappling:
		velocity.x += input_force.x * delta

func _try_grapple(target: Vector2) -> void:
	# Check if module prevents grappling (e.g., via can_grapple returning false)
	if equipped_module and equipped_module.has_method("can_grapple"):
		if not equipped_module.can_grapple():
			return  # Module blocks grappling

	var direction = (target - global_position).normalized()
	var distance_to_target = global_position.distance_to(target)
	var space_state = get_world_2d().direct_space_state

	# Determine grapple layer - module can override (e.g., Spectral Phase only grapples walls)
	# Always include room boundaries (layer 128) so everyone can grapple walls
	var grapple_layer = 2 | 128  # Default: platforms + room boundaries
	if equipped_module and equipped_module.has_method("get_grapple_layer"):
		grapple_layer = equipped_module.get_grapple_layer() | 128  # Always add walls

	# Cast ray to clicked position (unlimited distance)
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * max(distance_to_target, 10000.0),
		grapple_layer
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]  # Exclude self from raycast

	var result = space_state.intersect_ray(query)

	if result:
		_attach_grapple(result.position)

func _attach_grapple(anchor: Vector2) -> void:
	is_grappling = true
	grapple_anchor = anchor
	rope_length = global_position.distance_to(anchor)
	current_state = State.GRAPPLING

	# Lock facing direction based on rope direction (face toward anchor)
	grapple_facing = 1 if anchor.x >= global_position.x else -1

	EventBus.grapple_attached.emit(anchor)

func _release_grapple() -> void:
	is_grappling = false
	current_state = State.AIRBORNE

	# 100% momentum preservation - velocity stays unchanged
	EventBus.grapple_released.emit(velocity)

func _update_grapple_physics(delta: float) -> void:
	# Vector from player to anchor (direction to pull)
	var to_anchor = grapple_anchor - global_position
	var distance = to_anchor.length()
	var pull_direction = to_anchor.normalized()

	# Moderate pull strength for good momentum building
	var tension_strength = 2500.0  # Reduced from 8000 for balanced feel

	# Apply gravity (reduced while grappling)
	velocity.y += GRAVITY * 0.7 * delta

	# Pull toward anchor - builds momentum
	velocity += pull_direction * tension_strength * delta

	# Add swing boost based on tangential movement (reduced)
	var tangent = Vector2(-pull_direction.y, pull_direction.x)
	var tangent_speed = velocity.dot(tangent)
	velocity += tangent * abs(tangent_speed) * 0.2 * delta  # Reduced swing amplification

	# When rope is taut, enforce pendulum constraint
	if distance >= rope_length:
		# Decompose velocity into radial and tangential components
		var radial_speed = velocity.dot(pull_direction)
		var tangential_velocity = velocity - pull_direction * radial_speed

		# Keep all tangential velocity (swing motion) but remove outward radial
		if radial_speed < 0:  # Moving away from anchor
			velocity = tangential_velocity

		# Enforce rope length constraint
		global_position = grapple_anchor - pull_direction * rope_length

	# Shortening rope when moving toward anchor
	elif distance < rope_length - 5:
		rope_length = distance + 5

	# Cap velocity to prevent wall clipping
	velocity = velocity.limit_length(MAX_VELOCITY)

func _update_free_physics(delta: float) -> void:
	# Apply gravity with module modifier
	var gravity_mult = 1.0
	if equipped_module and equipped_module.has_method("get_gravity_multiplier"):
		gravity_mult = equipped_module.get_gravity_multiplier()
	velocity.y += GRAVITY * gravity_mult * delta

	# Cap velocity to prevent wall clipping
	velocity = velocity.limit_length(MAX_VELOCITY)

func _update_safe_position(delta: float) -> void:
	# Track last safe position (on floor, not in hazard) for Gravity Anchor
	safe_position_timer += delta
	if safe_position_timer >= SAFE_POSITION_CHECK_INTERVAL:
		safe_position_timer = 0.0
		if is_on_floor():
			last_safe_position = global_position

func _start_charging() -> void:
	is_charging = true
	charge_amount = 0.0
	current_state = State.CHARGING
	EventBus.charge_started.emit()

func _fire_weapon(target: Vector2) -> void:
	var charge_percent = charge_amount / max_charge

	# Only fire if fully charged
	if charge_percent < 1.0:
		# Cancel charge without firing
		is_charging = false
		charge_amount = 0.0
		current_state = State.AIRBORNE
		EventBus.charge_released.emit(0.0)
		return

	var direction = (target - global_position).normalized()

	# Full charge = max damage (3)
	var damage = 3

	is_charging = false
	charge_amount = 0.0
	current_state = State.AIRBORNE

	# Start firing release animation
	is_firing_release = true
	firing_release_timer = 0.0

	EventBus.charge_released.emit(charge_percent)
	EventBus.projectile_fired.emit(global_position, direction, damage)

	# Spawn projectile
	_spawn_projectile(direction, damage)

func _spawn_projectile(direction: Vector2, damage: int) -> void:
	var projectile_scene = preload("res://scenes/entities/player_projectile.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position + direction * 20
	projectile.direction = direction
	projectile.damage = damage
	get_tree().current_scene.add_child(projectile)

func _ground_jump() -> void:
	velocity.y = -GROUND_JUMP_FORCE
	EventBus.player_jumped.emit()

func _double_jump() -> void:
	has_double_jump = false
	velocity.y = -AIR_JUMP_FORCE
	EventBus.air_jump_used.emit()

func take_damage(amount: int, source: String = "enemy") -> void:
	# Phantom mode = invincible
	if GameManager.is_phantom_mode:
		return

	if is_invincible or current_state == State.DEAD:
		return

	var modified_amount = amount
	var respawn_pos: Vector2 = Vector2.ZERO

	# Check module intercept (before applying damage)
	if equipped_module and equipped_module.has_method("on_player_damaged"):
		var result = equipped_module.on_player_damaged(amount, source)
		if result.get("prevent", false):
			return  # Module cancelled the damage
		modified_amount = result.get("amount", amount)
		respawn_pos = result.get("respawn_position", Vector2.ZERO)

	GameManager.damage_player(modified_amount)

	if GameManager.player_health <= 0:
		# Check if module can prevent death (e.g., Phoenix Plating)
		if equipped_module and equipped_module.has_method("on_player_died"):
			var death_result = equipped_module.on_player_died()
			if death_result.get("prevent", false):
				# Module saved us from death
				var new_health = death_result.get("set_health", 1)
				GameManager.player_health = new_health
				var inv_dur = death_result.get("invincibility_duration", 0.5)
				_start_invincibility(inv_dur)
				EventBus.player_damaged.emit(GameManager.player_health, GameManager.player_max_health)
				# Teleport if respawn position was set
				if respawn_pos != Vector2.ZERO:
					global_position = respawn_pos
				return
		_die()
	else:
		# Teleport if respawn position was set (e.g., Gravity Anchor)
		if respawn_pos != Vector2.ZERO:
			global_position = respawn_pos
		# Brief invincibility after taking damage
		_start_invincibility(0.5)

func _start_invincibility(duration: float) -> void:
	is_invincible = true
	invincibility_timer = duration
	current_state = State.INVINCIBLE

func _die() -> void:
	current_state = State.DEAD
	is_grappling = false
	is_charging = false

	# Start death animation sequence using real time
	is_playing_death_anim = true
	death_start_time = Time.get_ticks_msec() / 1000.0
	phase_start_time = death_start_time
	death_phase = 0  # Start with hit stop

	# Trigger hit stop (freeze game briefly)
	Engine.time_scale = 0.0

	# Screen shake on death
	EventBus.screen_shake.emit(10.0, 0.3)

	# Play death animation
	if anim_sprite:
		anim_sprite.play("death")
		anim_sprite.modulate = Color.WHITE

func _process_death_animation(_delta: float) -> void:
	# Use real time (unaffected by Engine.time_scale)
	var current_time = Time.get_ticks_msec() / 1000.0
	var phase_elapsed = current_time - phase_start_time

	match death_phase:
		0:  # Hit stop phase - time is frozen
			if phase_elapsed >= DEATH_HIT_STOP_DURATION:
				# End hit stop, start death animation
				Engine.time_scale = 1.0
				death_phase = 1
				phase_start_time = current_time
				if anim_sprite:
					anim_sprite.play("death")
		1:  # Death animation phase
			# Progress through death frames based on timer
			if anim_sprite:
				var progress = phase_elapsed / DEATH_ANIM_DURATION
				var frame = int(progress * 6)  # 6 death frames
				anim_sprite.stop()
				anim_sprite.frame = min(frame, 5)

			if phase_elapsed >= DEATH_ANIM_DURATION:
				# Transition to ghost phase
				death_phase = 2
				phase_start_time = current_time
				if anim_sprite:
					anim_sprite.play("ghost")
		2:  # Ghost fade animation phase
			if anim_sprite:
				# Progress through ghost frames
				var progress = phase_elapsed / GHOST_ANIM_DURATION
				var frame = int(progress * 4)  # 4 ghost frames
				anim_sprite.stop()
				anim_sprite.frame = min(frame, 3)
				# Fade out
				anim_sprite.modulate.a = 1.0 - progress

			if phase_elapsed >= GHOST_ANIM_DURATION:
				# Death animation complete
				death_phase = 3
				is_playing_death_anim = false
				# Now emit death signal and trigger respawn
				EventBus.player_died.emit(global_position)
		3:  # Done - waiting for respawn
			pass

	# Update visuals during death (don't call normal update)
	queue_redraw()

func _on_respawned() -> void:
	current_state = State.AIRBORNE
	is_grappling = false
	is_charging = false
	has_double_jump = true
	charge_amount = 0.0
	# Reset death animation state
	is_playing_death_anim = false
	death_phase = 0
	# Ensure time scale is restored
	Engine.time_scale = 1.0
	# Restore sprite visibility
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE

func _on_tool_equipped(tool_name: String) -> void:
	# Remove old tool if exists
	if equipped_tool:
		equipped_tool.queue_free()
		equipped_tool = null

	# If unequipping (empty string), just return
	if tool_name == "":
		return

	# Load and instantiate new tool
	var tool_path = "res://scenes/entities/tools/%s.tscn" % tool_name
	if ResourceLoader.exists(tool_path):
		var tool_scene = load(tool_path)
		equipped_tool = tool_scene.instantiate()
		add_child(equipped_tool)
		# Start tool on full cooldown to prevent swap abuse
		if equipped_tool.has_method("start_cooldown"):
			equipped_tool.start_cooldown()

func _on_module_equipped(module_name: String) -> void:
	# Remove old module if exists
	if equipped_module:
		equipped_module.queue_free()
		equipped_module = null

	# Load and instantiate new module
	if module_name != "":
		var module_path = "res://scenes/entities/modules/%s.tscn" % module_name
		if ResourceLoader.exists(module_path):
			var module_scene = load(module_path)
			equipped_module = module_scene.instantiate()
			add_child(equipped_module)
			equipped_module.initialize(self)

func _update_grapple_visual() -> void:
	if is_grappling:
		grapple_line.visible = true
		grapple_line.clear_points()

		# Determine which hand offset array to use based on current animation
		var current_anim = anim_sprite.animation if anim_sprite else "idle"
		var current_frame = anim_sprite.frame if anim_sprite else 0
		var hand_offset: Vector2

		if current_anim == "grapple_up_right":
			current_frame = clamp(current_frame, 0, HAND_OFFSETS_GRAPPLE_UP_RIGHT.size() - 1)
			hand_offset = HAND_OFFSETS_GRAPPLE_UP_RIGHT[current_frame]
		elif current_anim == "grapple_up_left":
			current_frame = clamp(current_frame, 0, HAND_OFFSETS_GRAPPLE_UP_LEFT.size() - 1)
			hand_offset = HAND_OFFSETS_GRAPPLE_UP_LEFT[current_frame]
		elif current_anim == "grapple_down" or current_anim == "idle":
			current_frame = clamp(current_frame, 0, HAND_OFFSETS_IDLE.size() - 1)
			hand_offset = HAND_OFFSETS_IDLE[current_frame]
			# Flip X offset based on facing direction for idle/grapple_down
			if grapple_facing < 0:
				hand_offset.x = -hand_offset.x
		else:
			# Fallback to airborne offsets
			current_frame = clamp(current_frame, 0, HAND_OFFSETS_AIRBORNE.size() - 1)
			hand_offset = HAND_OFFSETS_AIRBORNE[current_frame]

		# Apply sprite scale
		hand_offset = hand_offset * anim_sprite.scale.x

		grapple_line.add_point(hand_offset)  # Hand position (local)
		grapple_line.add_point(grapple_anchor - global_position)  # Anchor (local)
	else:
		grapple_line.visible = false

func _update_animation() -> void:
	if not anim_sprite:
		return

	var anim_name: String = "idle"
	var use_manual_frame: bool = false
	var manual_frame: int = 0

	if current_state == State.DEAD:
		# Death animation is handled by _process_death_animation
		return
	elif GameManager.is_phantom_mode:
		anim_name = "ghost"
	elif is_firing_release:
		# Playing release frame after shot (frame 5 = firing with muzzle flash)
		anim_name = "firing"
		use_manual_frame = true
		manual_frame = 5  # The firing pose with muzzle flash
	elif current_state == State.CHARGING:
		# Charging animation - progress through frames 0-4 based on charge, hold at 4 when full
		anim_name = "firing"
		use_manual_frame = true
		var charge_percent = charge_amount / max_charge
		if charge_percent >= 1.0:
			# Fully charged - hold at ready-to-fire frame (frame 4)
			manual_frame = 4
		else:
			# Building up charge - frames 0-3 based on charge progress
			manual_frame = int(charge_percent * 4.0)  # 0-3 during charge
	elif current_state == State.GRAPPLING:
		# Use grapple-specific animation based on direction to anchor
		var to_anchor = grapple_anchor - global_position
		var angle_to_anchor = to_anchor.angle()

		# Determine grapple direction based on angle to anchor
		# Angles: 0 = right, PI/-PI = left, -PI/2 = up, PI/2 = down
		# Horizontal (straight left/right): only within 15 degrees of horizontal (use idle)
		# Up: anything above horizontal (use grapple_up)
		# Down: anything below horizontal (use idle/grapple_down)

		var horizontal_threshold = PI / 12  # ~15 degrees

		if abs(angle_to_anchor) < horizontal_threshold or abs(angle_to_anchor) > PI - horizontal_threshold:
			# Nearly straight horizontal - use idle (grapple_down) for now
			anim_name = "grapple_down"
		elif angle_to_anchor < 0:
			# Grappling upward (any upward angle) - use grapple_up animation
			if to_anchor.x < 0:
				anim_name = "grapple_up_left"
			else:
				anim_name = "grapple_up_right"
		else:
			# Grappling downward - use idle animation (grapple_down)
			anim_name = "grapple_down"

		use_manual_frame = true
		manual_frame = 0 if fmod(Time.get_ticks_msec() / 200.0, 2.0) < 1.0 else 1
	elif not is_on_floor():
		# Use direction-specific airborne animation instead of flip_h
		var dir = facing_direction
		anim_name = "airborne_left" if dir < 0 else "airborne_right"
		use_manual_frame = true
		# Use velocity to determine which airborne frame to show
		# Going up fast (negative Y velocity) = "tall/stretched" pose (frames 0-1)
		# Falling or slow upward = "relaxed/falling" pose (frames 2-3)
		if velocity.y < RISING_VELOCITY_THRESHOLD:
			# Rising fast - use frames 0 or 1 (alternate based on time for subtle motion)
			manual_frame = 0 if fmod(Time.get_ticks_msec() / 200.0, 2.0) < 1.0 else 1
		else:
			# Falling or slow - use frames 2 or 3
			manual_frame = 2 if fmod(Time.get_ticks_msec() / 200.0, 2.0) < 1.0 else 3
	elif abs(velocity.x) > 10:
		anim_name = "run"
	else:
		anim_name = "idle"
		use_manual_frame = true
		# Hold each idle pose for a few seconds before switching
		manual_frame = current_idle_pose

	# Handle animation changes
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)
		# Reset idle pose timer when entering idle
		if anim_name == "idle":
			idle_pose_timer = 0.0
			current_idle_pose = 0

	# Set manual frame for idle and airborne
	if use_manual_frame:
		anim_sprite.stop()
		anim_sprite.frame = manual_frame

	# Flip sprite based on facing direction
	# Airborne and grapple_up animations have direction built-in, so don't flip them
	if anim_name.begins_with("airborne") or anim_name.begins_with("grapple_up"):
		anim_sprite.flip_h = false
	elif anim_name == "grapple_down":
		# For horizontal/down grapple, flip based on anchor direction
		anim_sprite.flip_h = (grapple_facing < 0)
	elif is_grappling:
		# When grappling, lock direction based on rope direction (don't flip with movement)
		anim_sprite.flip_h = (grapple_facing < 0)
	else:
		anim_sprite.flip_h = (facing_direction < 0)

	# Invincibility flicker effect
	if is_invincible:
		if fmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0:
			anim_sprite.modulate.a = 0.3
		else:
			anim_sprite.modulate.a = 1.0
	elif GameManager.is_phantom_mode:
		anim_sprite.modulate = Color(0.7, 0.5, 1.0, 0.7)
	else:
		anim_sprite.modulate = Color.WHITE

func _draw() -> void:
	# Draw charge indicator arc overlay (kept procedural since it's dynamic)
	if is_charging:
		var charge_percent = charge_amount / max_charge
		var charge_color = Color.RED if charge_percent >= 1.0 else Color.WHITE
		var arc_end = -PI / 2 + PI * 2 * charge_percent
		draw_arc(Vector2.ZERO, size * 0.8, -PI / 2, arc_end, 32, charge_color, 2.0)

# Called when entering hazard zones
func _on_hazard_entered() -> void:
	take_damage(999, "pit")  # Instant death from pit

func can_attack() -> bool:
	## Returns false if player cannot attack (phantom mode, etc.)
	return not GameManager.is_phantom_mode
