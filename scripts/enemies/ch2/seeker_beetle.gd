extends EnemyBase
class_name SeekerBeetle
## Chapter 2 basic enemy - slow walking beetle that fires weak homing missiles

enum BeetleState { PATROL, AIMING, COOLDOWN }

@export var patrol_speed: float = 60.0
@export var patrol_range: float = 120.0
@export var fire_cooldown: float = 3.0      # Time between shots
@export var aim_time: float = 0.8           # Telegraph before firing

var state: BeetleState = BeetleState.PATROL
var start_x: float = 0.0
var direction: int = 1
var cooldown_timer: float = 0.0
var aim_timer: float = 0.0

var size: float = 25.0
var color: Color = Color(0.6, 0.4, 0.8)     # Purple

const MISSILE_SCENE = preload("res://scenes/entities/ch2/seeker_missile.tscn")

# Frame mapping: 0-2 idle/patrol, 3-4 aiming, 5 firing, 6-7 cooldown, 8 death
const FRAME_PATROL = 0
const FRAME_PATROL_ALT = 1
const FRAME_AIMING = 3
const FRAME_FIRING = 5
const FRAME_COOLDOWN = 6

func _ready() -> void:
	super._ready()
	max_health = 1
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("seeker_beetle", 15)
	start_x = global_position.x
	cooldown_timer = randf_range(0, fire_cooldown * 0.5)  # Stagger initial fire
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0

	match state:
		BeetleState.PATROL:
			_patrol(delta)
			cooldown_timer += delta / cooldown_multiplier
			if cooldown_timer >= fire_cooldown:
				state = BeetleState.AIMING
				aim_timer = 0.0

		BeetleState.AIMING:
			velocity.x = 0  # Stop moving while aiming
			aim_timer += delta
			if aim_timer >= aim_time:
				_fire_missile()
				state = BeetleState.COOLDOWN
				cooldown_timer = 0.0

		BeetleState.COOLDOWN:
			cooldown_timer += delta / cooldown_multiplier
			if cooldown_timer >= 0.5:
				state = BeetleState.PATROL

	move_and_slide()

	# Update sprite based on state
	if anim_sprite:
		anim_sprite.flip_h = (direction < 0)
		match state:
			BeetleState.PATROL:
				_set_sprite_frame(FRAME_PATROL)
			BeetleState.AIMING:
				_set_sprite_frame(FRAME_AIMING)
			BeetleState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _patrol(delta: float) -> void:
	velocity.x = patrol_speed * direction

	if global_position.x > start_x + patrol_range:
		direction = -1
	elif global_position.x < start_x - patrol_range:
		direction = 1

func _fire_missile() -> void:
	var missile = MISSILE_SCENE.instantiate()
	missile.global_position = global_position + Vector2(0, -size)
	missile.target = player_ref
	get_tree().current_scene.add_child(missile)

func _draw() -> void:
	# Draw beetle body only if no sprite (fallback)
	if not anim_sprite:
		var body_color = color if not is_shielded else Color(0.3, 0.8, 1.0, 0.8)
		draw_circle(Vector2.ZERO, size * 0.8, body_color)

		# Draw shell segments
		draw_arc(Vector2.ZERO, size * 0.6, PI * 0.2, PI * 0.8, 16, body_color * 0.7, 3.0)

		# Draw legs
		for i in range(3):
			var leg_x = -size * 0.5 + i * size * 0.5
			draw_line(Vector2(leg_x, size * 0.5), Vector2(leg_x - 5, size * 0.8), body_color * 0.6, 2.0)
			draw_line(Vector2(leg_x, size * 0.5), Vector2(leg_x + 5, size * 0.8), body_color * 0.6, 2.0)

		# Draw eyes
		draw_circle(Vector2(-8, -size * 0.3), 4, Color.WHITE)
		draw_circle(Vector2(8, -size * 0.3), 4, Color.WHITE)
		draw_circle(Vector2(-8, -size * 0.3), 2, Color.BLACK)
		draw_circle(Vector2(8, -size * 0.3), 2, Color.BLACK)

	# Draw aiming indicator (overlay - always draw)
	if state == BeetleState.AIMING:
		var aim_progress = aim_timer / aim_time
		draw_arc(Vector2.ZERO, size + 5, 0, TAU * aim_progress, 32, Color.YELLOW, 2.0)

	# Draw shield effect (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, size + 8, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
