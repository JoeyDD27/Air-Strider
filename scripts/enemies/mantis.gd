extends EnemyBase
class_name Mantis
## Mantis enemy - patrols floor, instant kill if player lands, leaps when player swings low

enum MantisState { PATROL, ALERT, LEAP, LANDING, RETURNING }

@export var patrol_range: float = 150.0
@export var leap_threshold: float = 200.0  # Leap if player within this height
@export var patrol_speed: float = 100.0
@export var leap_speed: float = 600.0

var state: MantisState = MantisState.PATROL
var start_x: float = 0.0
var start_y: float = 0.0
var direction: int = 1
var alert_timer: float = 0.0
var landing_timer: float = 0.0

var size: float = 35.0
var color: Color = Color(0.8, 0.133, 0.133)  # Red

# Track if we need to apply gravity
var apply_gravity: bool = false

# Frame mapping: 0-1 patrol, 2-3 alert, 4-5 leap/attack, 6-7 landing, 8 death
const FRAME_PATROL = 0
const FRAME_PATROL_ALT = 1
const FRAME_ALERT = 3
const FRAME_LEAP = 5
const FRAME_LANDING = 6
const FRAME_RETURNING = 1

func _ready() -> void:
	super._ready()
	reward = GameManager.ENEMY_REWARDS.get("mantis", 25)
	start_x = global_position.x
	start_y = global_position.y
	_setup_sprite()

	# Add room boundary collision so mantis can't leap through walls
	collision_mask = collision_mask | 128  # Room boundaries layer

	# Setup floor detection area for instant kill
	_setup_kill_zone()

func _setup_kill_zone() -> void:
	# Area above mantis that kills player on contact
	var kill_zone = Area2D.new()
	kill_zone.name = "KillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1  # Player layer

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(size, size * 1.5)
	shape.shape = rect
	shape.position = Vector2(0, -size / 2)

	kill_zone.add_child(shape)
	add_child(kill_zone)

	kill_zone.body_entered.connect(_on_kill_zone_entered)

func _on_kill_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not GameManager.is_phantom_mode:
		# Instant kill!
		body.take_damage(999)

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	var player_pos = get_player_position()
	var dist_to_player = abs(player_pos.x - global_position.x)
	var player_height = global_position.y - player_pos.y  # Positive if player is above

	match state:
		MantisState.PATROL:
			_patrol(delta)

			# Check if player is swinging low
			if player_height > 0 and player_height < leap_threshold and dist_to_player < patrol_range:
				state = MantisState.ALERT
				alert_timer = 0.0

		MantisState.ALERT:
			# Brief pause before leap
			alert_timer += delta
			if alert_timer > 0.3:
				_leap(player_pos)

		MantisState.LEAP:
			# Apply gravity
			velocity.y += 980.0 * delta
			move_and_slide()

			# Check for wall collision
			if get_slide_collision_count() > 0:
				for i in range(get_slide_collision_count()):
					var collision = get_slide_collision(i)
					if collision:
						var normal = collision.get_normal()
						# If hit a wall (horizontal collision)
						if abs(normal.x) > 0.5:
							velocity.x = 0  # Stop horizontal movement

			# Check if landed (on floor or any platform)
			if is_on_floor() or (velocity.y > 0 and global_position.y >= _floor_y - 60):
				velocity = Vector2.ZERO
				state = MantisState.LANDING
				landing_timer = 0.0

		MantisState.LANDING:
			landing_timer += delta
			if landing_timer > 0.5:
				# Check if we need to return to patrol area
				if abs(global_position.x - start_x) > 10:
					state = MantisState.RETURNING
				else:
					state = MantisState.PATROL

		MantisState.RETURNING:
			# Walk back toward start_x
			var return_dir = sign(start_x - global_position.x)
			direction = return_dir
			global_position.x += patrol_speed * return_dir * delta

			# Check if reached patrol area
			if abs(global_position.x - start_x) < 10:
				state = MantisState.PATROL

	# Update sprite based on state
	if anim_sprite:
		anim_sprite.flip_h = (direction < 0)
		match state:
			MantisState.PATROL:
				_set_sprite_frame(FRAME_PATROL)
			MantisState.ALERT:
				_set_sprite_frame(FRAME_ALERT)
			MantisState.LEAP:
				_set_sprite_frame(FRAME_LEAP)
			MantisState.LANDING:
				_set_sprite_frame(FRAME_LANDING)
			MantisState.RETURNING:
				_set_sprite_frame(FRAME_RETURNING)

	queue_redraw()

func _patrol(delta: float) -> void:
	global_position.x += patrol_speed * direction * delta

	# Reverse at patrol bounds
	if global_position.x > start_x + patrol_range:
		global_position.x = start_x + patrol_range
		direction = -1
	elif global_position.x < start_x - patrol_range:
		global_position.x = start_x - patrol_range
		direction = 1

func _leap(target_pos: Vector2) -> void:
	state = MantisState.LEAP

	# Calculate leap trajectory
	var dx = target_pos.x - global_position.x
	var dy = target_pos.y - global_position.y

	# Jump toward predicted player position
	var jump_time = 0.5
	velocity.x = dx / jump_time
	velocity.y = (dy / jump_time) - (980.0 * jump_time / 2)

func _draw() -> void:
	# Draw diamond shape only if no sprite (fallback)
	if not anim_sprite:
		var draw_color = color
		if state == MantisState.ALERT:
			draw_color = Color(1, 0.267, 0.267)  # Brighter red when alert

		var points = PackedVector2Array()
		points.append(Vector2(0, -size))
		points.append(Vector2(size / 2, 0))
		points.append(Vector2(0, size / 2))
		points.append(Vector2(-size / 2, 0))
		draw_colored_polygon(points, draw_color)

		# Eye indicator
		var eye_x = direction * 5
		draw_circle(Vector2(eye_x, -10), 5, Color.WHITE)
		draw_circle(Vector2(eye_x, -10), 2, Color.BLACK)

	# Alert indicator (overlay - always draw)
	if state == MantisState.ALERT:
		draw_string(ThemeDB.fallback_font, Vector2(-5, -size - 10), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.YELLOW)
