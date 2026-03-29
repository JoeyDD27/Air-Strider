extends Node2D
class_name PhantomDrone
## Rescue drone that carries the player through a room after multiple deaths
## Player earns no coins while being carried

enum DroneState { DESCENDING, ATTACHING, CARRYING, EXITING }

var state: DroneState = DroneState.DESCENDING
var player_ref: Player = null
var target_door: Door = null
var carry_offset: Vector2 = Vector2(0, -60)  # Player hangs below drone

# Movement
var speed: float = 800.0
var descent_speed: float = 600.0
var hover_amplitude: float = 5.0
var hover_speed: float = 3.0
var hover_timer: float = 0.0

# Visual
var body_width: float = 80.0
var body_height: float = 40.0
var rotor_angle: float = 0.0
var glow_intensity: float = 0.0
var attach_progress: float = 0.0

# Tractor beam
var beam_active: bool = false
var beam_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]
		beam_target = player_ref.global_position

	# Find door
	var doors = get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is Door:
			target_door = door
			break

	# Position drone above player
	if player_ref:
		global_position = Vector2(player_ref.global_position.x, player_ref.global_position.y - 300)

	# Force door open since we're in phantom mode
	if target_door:
		target_door.is_open = true
		target_door.queue_redraw()

func _physics_process(delta: float) -> void:
	hover_timer += delta
	rotor_angle += delta * 20  # Spin rotors

	match state:
		DroneState.DESCENDING:
			_process_descending(delta)
		DroneState.ATTACHING:
			_process_attaching(delta)
		DroneState.CARRYING:
			_process_carrying(delta)
		DroneState.EXITING:
			_process_exiting(delta)

	queue_redraw()

func _process_descending(delta: float) -> void:
	glow_intensity = min(glow_intensity + delta * 2, 1.0)

	if not is_instance_valid(player_ref):
		return

	# Descend toward player
	var target_y = player_ref.global_position.y - 80
	global_position.y = move_toward(global_position.y, target_y, descent_speed * delta)
	global_position.x = lerp(global_position.x, player_ref.global_position.x, delta * 3)

	# Check if close enough to attach
	if abs(global_position.y - target_y) < 10:
		state = DroneState.ATTACHING
		beam_active = true

func _process_attaching(delta: float) -> void:
	attach_progress += delta * 2  # 0.5 second attach time

	if not is_instance_valid(player_ref):
		return

	# Tractor beam pulls player up
	beam_target = lerp(beam_target, global_position + carry_offset, delta * 4)
	player_ref.global_position = lerp(player_ref.global_position, beam_target, delta * 6)
	player_ref.velocity = Vector2.ZERO

	# Disable player controls during attach
	player_ref.current_state = Player.State.DEAD  # Prevents input

	if attach_progress >= 1.0:
		state = DroneState.CARRYING
		beam_active = false

func _process_carrying(delta: float) -> void:
	if not is_instance_valid(player_ref) or not is_instance_valid(target_door):
		return

	# Hover effect
	var hover_offset = sin(hover_timer * hover_speed) * hover_amplitude

	# Move toward door
	var door_target = target_door.global_position + Vector2(0, -50)  # Slightly above door
	var direction = (door_target - global_position).normalized()

	global_position += direction * speed * delta
	global_position.y += hover_offset * delta * 10

	# Keep player attached
	player_ref.global_position = global_position + carry_offset
	player_ref.velocity = Vector2.ZERO

	# Check if reached door
	if global_position.distance_to(door_target) < 30:
		state = DroneState.EXITING
		_trigger_door_exit()

func _process_exiting(_delta: float) -> void:
	# Do nothing - scene transition will clean us up
	pass

func _trigger_door_exit() -> void:
	# Restore player state briefly so door can trigger
	if is_instance_valid(player_ref):
		player_ref.current_state = Player.State.AIRBORNE

	# Clear references before scene transition to prevent accessing freed objects
	player_ref = null
	target_door = null

	# Trigger room transition
	GameManager.call_deferred("next_room")

func _draw() -> void:
	# Main body - sleek rescue drone
	var body_color = Color(0.5, 0.3, 0.7)  # Purple
	var glow_color = Color(0.7, 0.4, 1.0, glow_intensity * 0.5)

	# Glow effect
	draw_circle(Vector2.ZERO, body_width * 0.8, glow_color)

	# Body shape
	var body_points = PackedVector2Array([
		Vector2(-body_width / 2, 0),
		Vector2(-body_width / 3, -body_height / 2),
		Vector2(body_width / 3, -body_height / 2),
		Vector2(body_width / 2, 0),
		Vector2(body_width / 3, body_height / 2),
		Vector2(-body_width / 3, body_height / 2),
	])
	draw_colored_polygon(body_points, body_color)
	draw_polyline(body_points + PackedVector2Array([body_points[0]]), Color(0.8, 0.6, 1.0), 2.0)

	# Rotors (spinning)
	_draw_rotor(Vector2(-body_width / 2 - 15, 0), rotor_angle)
	_draw_rotor(Vector2(body_width / 2 + 15, 0), -rotor_angle)

	# Center eye/sensor
	draw_circle(Vector2.ZERO, 8, Color(0.3, 0.8, 1.0))
	draw_circle(Vector2.ZERO, 5, Color.WHITE)

	# Tractor beam
	if beam_active and is_instance_valid(player_ref):
		var beam_end = player_ref.global_position - global_position
		var beam_color = Color(0.6, 0.4, 1.0, 0.4 + sin(hover_timer * 8) * 0.2)
		draw_line(Vector2(0, body_height / 2), beam_end, beam_color, 4.0)

		# Beam glow rings
		for i in range(3):
			var ring_t = fmod(attach_progress * 3 + i * 0.33, 1.0)
			var ring_pos = Vector2(0, body_height / 2).lerp(beam_end, ring_t)
			var ring_alpha = 1.0 - ring_t
			draw_circle(ring_pos, 10 + ring_t * 5, Color(0.7, 0.5, 1.0, ring_alpha * 0.5))

	# Carry cable when carrying
	if state == DroneState.CARRYING and is_instance_valid(player_ref):
		var cable_end = player_ref.global_position - global_position
		draw_line(Vector2(0, body_height / 2), cable_end + Vector2(0, -15), Color(0.4, 0.4, 0.5), 3.0)
		# Cable attachment point
		draw_circle(cable_end + Vector2(0, -15), 5, Color(0.5, 0.5, 0.6))

	# Status text
	var status_text = ""
	match state:
		DroneState.DESCENDING:
			status_text = "RESCUE INBOUND"
		DroneState.ATTACHING:
			status_text = "SECURING..."
		DroneState.CARRYING:
			status_text = "EXTRACTING"

	if status_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-50, -body_height - 10), status_text, HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(0.8, 0.6, 1.0))

func _draw_rotor(pos: Vector2, angle: float) -> void:
	var rotor_length = 20.0
	for i in range(2):
		var blade_angle = angle + i * PI
		var blade_end = pos + Vector2.from_angle(blade_angle) * rotor_length
		var blade_start = pos + Vector2.from_angle(blade_angle + PI) * rotor_length
		draw_line(blade_start, blade_end, Color(0.6, 0.6, 0.7, 0.8), 3.0)

	# Rotor hub
	draw_circle(pos, 5, Color(0.4, 0.4, 0.5))
