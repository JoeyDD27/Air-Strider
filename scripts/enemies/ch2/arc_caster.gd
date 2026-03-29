extends EnemyBase
class_name ArcCaster
## Chapter 2 zoner - charges then electrifies a floor zone
## Yellow phase = charging, Red phase = floor is dangerous

enum CasterState { IDLE, CHARGING, ELECTRIFYING, COOLDOWN }

@export var charge_time: float = 2.0        # Yellow phase duration
@export var electrify_time: float = 3.0     # Red phase duration
@export var cooldown_time: float = 2.0
@export var zone_width: float = 400.0       # Width of electrified area
@export var zone_height: float = 200.0      # Height from floor (2x for better coverage)

var state: CasterState = CasterState.IDLE
var state_timer: float = 0.0
var electric_zone: Node2D = null

var size: float = 35.0
var color: Color = Color(1.0, 0.8, 0.2)     # Yellow-gold

const ELECTRIC_ZONE_SCENE = preload("res://scenes/entities/hazards/electric_zone.tscn")

# Frame mapping: 0-2 idle, 3-4 charging, 5 electrifying, 6-7 cooldown, 8 death
const FRAME_IDLE = 0
const FRAME_CHARGING = 3
const FRAME_ELECTRIFYING = 5
const FRAME_COOLDOWN = 6

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("arc_caster", 30)

	# Start with random offset to desynchronize multiple casters
	state_timer = randf_range(0, cooldown_time * 0.5)
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

	state_timer += delta / cooldown_multiplier

	match state:
		CasterState.IDLE:
			if state_timer >= cooldown_time:
				_start_charging()

		CasterState.CHARGING:
			if state_timer >= charge_time:
				_start_electrifying()

		CasterState.ELECTRIFYING:
			if state_timer >= electrify_time:
				_stop_electrifying()

		CasterState.COOLDOWN:
			if state_timer >= cooldown_time:
				state = CasterState.IDLE
				state_timer = 0.0

	# Update sprite based on state
	if anim_sprite:
		match state:
			CasterState.IDLE:
				_set_sprite_frame(FRAME_IDLE)
			CasterState.CHARGING:
				_set_sprite_frame(FRAME_CHARGING)
			CasterState.ELECTRIFYING:
				_set_sprite_frame(FRAME_ELECTRIFYING)
			CasterState.COOLDOWN:
				_set_sprite_frame(FRAME_COOLDOWN)

	queue_redraw()

func _start_charging() -> void:
	state = CasterState.CHARGING
	state_timer = 0.0
	EventBus.electric_floor_warning.emit(get_instance_id(), charge_time)

func _start_electrifying() -> void:
	state = CasterState.ELECTRIFYING
	state_timer = 0.0
	_spawn_electric_zone()
	EventBus.electric_floor_activated.emit(get_instance_id())

func _stop_electrifying() -> void:
	state = CasterState.COOLDOWN
	state_timer = 0.0
	_destroy_electric_zone()
	EventBus.electric_floor_deactivated.emit(get_instance_id())

func _spawn_electric_zone() -> void:
	electric_zone = ELECTRIC_ZONE_SCENE.instantiate()
	electric_zone.global_position = Vector2(global_position.x, _get_floor_y())
	electric_zone.zone_width = zone_width
	electric_zone.zone_height = zone_height
	electric_zone.owner_id = get_instance_id()
	get_tree().current_scene.add_child(electric_zone)

func _destroy_electric_zone() -> void:
	if electric_zone and is_instance_valid(electric_zone):
		electric_zone.queue_free()
		electric_zone = null

func _get_floor_y() -> float:
	# Get floor_y from room
	var room = get_tree().current_scene
	if room and "floor_y" in room:
		return room.floor_y
	return 900.0  # Default

func die() -> void:
	_destroy_electric_zone()
	super.die()

func _draw() -> void:
	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var draw_color = color

		# State-based coloring
		match state:
			CasterState.CHARGING:
				draw_color = Color(1.0, 1.0, 0.0)  # Bright yellow
				var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
				draw_color.a = pulse
			CasterState.ELECTRIFYING:
				draw_color = Color(1.0, 0.2, 0.2)  # Red

		if is_shielded:
			draw_color = Color(0.3, 0.8, 1.0, 0.8)

		# Draw body (hexagon shape)
		var points = PackedVector2Array()
		for i in range(6):
			var angle = i * PI / 3 - PI / 6
			points.append(Vector2.from_angle(angle) * size)
		draw_colored_polygon(points, draw_color)

		# Draw core
		draw_circle(Vector2.ZERO, size * 0.4, draw_color * 0.6)

	# Draw charge indicator (overlay - always draw)
	if state == CasterState.CHARGING:
		var progress = state_timer / charge_time
		draw_arc(Vector2.ZERO, size + 8, 0, TAU * progress, 32, Color.YELLOW, 3.0)

	# Draw electrify indicator (overlay - always draw)
	if state == CasterState.ELECTRIFYING:
		var progress = 1.0 - (state_timer / electrify_time)
		draw_arc(Vector2.ZERO, size + 8, 0, TAU * progress, 32, Color.RED, 3.0)

	# Draw electricity effect when active (overlay - always draw)
	if state == CasterState.ELECTRIFYING:
		for i in range(3):
			var angle = randf() * TAU
			var length = randf_range(size, size * 1.5)
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * length, Color(1, 1, 0.5, 0.8), 2.0)

	# Draw shield (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, size + 12, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)

	# Draw zone preview during charging (overlay - always draw)
	if state == CasterState.CHARGING:
		var floor_y = _get_floor_y() - global_position.y
		var zone_rect = Rect2(-zone_width / 2, floor_y - zone_height, zone_width, zone_height)
		draw_rect(zone_rect, Color(1.0, 1.0, 0.0, 0.2))
		draw_rect(zone_rect, Color(1.0, 1.0, 0.0, 0.5), false, 2.0)
