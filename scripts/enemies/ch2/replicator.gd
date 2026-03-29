extends EnemyBase
class_name Replicator
## Chapter 2 spawner - spawns Seeker-Beetles periodically
## Priority target - kill first to stop the swarm

@export var spawn_interval: float = 8.0     # Normal: 8s, Amped: 6s effective
@export var max_beetles: int = 3

var spawn_timer: float = 0.0
var spawned_beetles: Array = []

var size: float = 45.0
var color: Color = Color(0.4, 0.8, 0.4)     # Green

const BEETLE_SCENE = preload("res://scenes/entities/ch2/seeker_beetle.tscn")

# Frame mapping: 0-2 idle, 3-4 charging/preparing, 5 spawning, 6-7 cooldown, 8 death
const FRAME_IDLE = 0
const FRAME_CHARGING = 3
const FRAME_SPAWNING = 5
const FRAME_COOLDOWN = 6

func _ready() -> void:
	super._ready()
	max_health = 3
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("replicator", 50)
	spawn_timer = spawn_interval * 0.5      # Initial delay before first spawn
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Clean up dead beetles from tracking array
	spawned_beetles = spawned_beetles.filter(func(b): return is_instance_valid(b) and not b.is_dead)

	spawn_timer += delta / cooldown_multiplier

	if spawn_timer >= spawn_interval and spawned_beetles.size() < max_beetles:
		_spawn_beetle()
		spawn_timer = 0.0

	# Update sprite based on spawn progress
	if anim_sprite:
		var spawn_progress = spawn_timer / spawn_interval
		if spawn_progress > 0.8:
			_set_sprite_frame(FRAME_SPAWNING)
		elif spawn_progress > 0.5:
			_set_sprite_frame(FRAME_CHARGING)
		else:
			_set_sprite_frame(FRAME_IDLE)

	queue_redraw()

func _spawn_beetle() -> void:
	var beetle = BEETLE_SCENE.instantiate()
	beetle.global_position = global_position + Vector2(randf_range(-50, 50), -size)
	get_tree().current_scene.add_child(beetle)
	spawned_beetles.append(beetle)

func _draw() -> void:
	var spawn_progress = spawn_timer / spawn_interval

	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var body_color = color if not is_shielded else Color(0.3, 0.8, 1.0, 0.8)

		# Draw main body (square with rounded corners effect)
		var rect = Rect2(-size / 2, -size / 2, size, size)
		draw_rect(rect, body_color)

		# Draw inner machinery
		draw_rect(Rect2(-size * 0.3, -size * 0.3, size * 0.6, size * 0.6), body_color * 0.6)

		# Draw "hatch" when about to spawn
		if spawn_progress > 0.8:
			var hatch_open = (spawn_progress - 0.8) / 0.2
			draw_line(Vector2(-size * 0.3, -size / 2), Vector2(-size * 0.3, -size / 2 - 10 * hatch_open), body_color, 3.0)
			draw_line(Vector2(size * 0.3, -size / 2), Vector2(size * 0.3, -size / 2 - 10 * hatch_open), body_color, 3.0)

	# Draw spawn progress arc (overlay - always draw)
	draw_arc(Vector2.ZERO, size * 0.6, -PI / 2, -PI / 2 + TAU * spawn_progress, 32, Color.WHITE, 3.0)

	# Draw beetle count indicators at bottom (overlay - always draw)
	for i in range(max_beetles):
		var indicator_x = -size / 2 + 15 + i * 15
		var indicator_color = Color.YELLOW if i < spawned_beetles.size() else Color(0.3, 0.3, 0.3)
		draw_circle(Vector2(indicator_x, size / 2 + 10), 5, indicator_color)

	# Draw shield (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, size * 0.8 + 8, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
