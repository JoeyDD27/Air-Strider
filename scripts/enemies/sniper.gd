extends EnemyBase
class_name Sniper
## Sniper enemy - tracks player with laser, fires when player moves too slowly

@export var tracking_speed: float = 2.0  # Radians per second
@export var fire_threshold: float = 0.3  # Fire when player speed < 30% of max
@export var max_speed_reference: float = 800.0  # Reference for "slow" calculation

var aim_angle: float = 0.0
var target_angle: float = 0.0
var laser_length: float = 1000.0
var charge_time: float = 0.0
var fire_delay: float = 0.5  # Seconds before firing when player is slow

var size: float = 30.0
var color: Color = Color(0.8, 0.133, 0.133)  # Red

# Frame mapping: 0-2 idle, 3-4 charging, 5 firing, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_TRACKING = 1
const FRAME_CHARGING = 3
const FRAME_FIRING = 5

func _ready() -> void:
	super._ready()
	reward = GameManager.ENEMY_REWARDS.get("sniper", 15)
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	# Calculate angle to player
	var to_player = get_player_position() - global_position
	target_angle = to_player.angle()

	# Smoothly rotate toward player
	var angle_diff = _normalize_angle(target_angle - aim_angle)

	var rotate_amount = tracking_speed * delta
	if abs(angle_diff) < rotate_amount:
		aim_angle = target_angle
	else:
		aim_angle += sign(angle_diff) * rotate_amount

	# Check if player is moving slowly
	var player_speed = get_player_velocity().length()
	var speed_ratio = player_speed / max_speed_reference

	if speed_ratio < fire_threshold:
		# Player is slow - charge up
		charge_time += delta
		if charge_time >= fire_delay:
			fire()
			charge_time = 0.0
	else:
		# Player is moving - reset charge
		charge_time = 0.0

	# Update sprite
	if anim_sprite:
		anim_sprite.rotation = aim_angle  # Rotate to aim
		if charge_time > 0:
			_set_sprite_frame(FRAME_CHARGING if charge_time < fire_delay * 0.8 else FRAME_FIRING)
		else:
			_set_sprite_frame(FRAME_TRACKING)

	queue_redraw()

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func fire() -> void:
	# Spawn a fast bullet toward the player
	var bullet_scene = preload("res://scenes/entities/sniper_bullet.tscn")
	var bullet = bullet_scene.instantiate()

	# Set bullet properties
	bullet.global_position = global_position + Vector2.from_angle(aim_angle) * 20  # Spawn slightly in front
	bullet.direction = Vector2.from_angle(aim_angle)
	bullet.damage = damage
	bullet.speed = 1800.0  # Very fast bullet

	get_tree().current_scene.add_child(bullet)

func _draw() -> void:
	# Draw laser sight overlay (dynamic - can't be sprite)
	var laser_alpha = 0.3 + charge_time * 0.7 if charge_time > 0 else 0.3
	var laser_width = 2.0 if charge_time > 0 else 1.0
	var laser_color = Color(1, 0, 0, laser_alpha)

	var laser_end = Vector2.from_angle(aim_angle) * laser_length
	draw_line(Vector2.ZERO, laser_end, laser_color, laser_width)

	# Draw dashed line effect
	var dash_length = 10.0
	var num_dashes = int(laser_length / (dash_length * 2))
	for i in range(num_dashes):
		var start = Vector2.from_angle(aim_angle) * (i * dash_length * 2)
		var end = Vector2.from_angle(aim_angle) * (i * dash_length * 2 + dash_length)
		draw_line(start, end, laser_color, laser_width)

	# Draw triangle body only if no sprite (fallback for procedural rendering)
	if not anim_sprite:
		var points = PackedVector2Array()
		var forward = Vector2.from_angle(aim_angle) * size
		var back_left = Vector2.from_angle(aim_angle + PI * 0.8) * size * 0.6
		var back_right = Vector2.from_angle(aim_angle - PI * 0.8) * size * 0.6
		points.append(forward)
		points.append(back_left)
		points.append(back_right)
		draw_colored_polygon(points, color)

	# Draw charging indicator arc
	if charge_time > 0:
		var charge_percent = charge_time / fire_delay
		draw_arc(Vector2.ZERO, 35, 0, TAU * charge_percent, 32, Color.YELLOW, 2.0)
