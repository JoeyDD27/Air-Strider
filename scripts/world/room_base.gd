extends Node2D
class_name RoomBase
## Base class for all game rooms

@export var room_id: int = 1
@export var room_name: String = "Room"
@export var has_floor_hazard: bool = false  # Only room 1 has floor hazard
@export var floor_y: float = 900.0  # Increased for bigger room
@export var room_width: float = 1920.0  # Wider room
@export var room_height: float = 1000.0  # Taller room

var player: Player = null

func _ready() -> void:
	_spawn_player()
	_setup_camera()
	_setup_walls()
	_setup_floor_hazard()
	_setup_wall_grapple_points()
	_setup_wall_frame_visual()
	_add_hud()
	_add_screen_effects()
	_add_pause_menu()
	_add_victory_screen()
	_add_inventory_ui()
	_add_death_screen()

	# Reset per-room state (Phoenix Plating, kill streak, etc.)
	GameManager.reset_room_state()

	# Emit room entered
	EventBus.room_entered.emit(room_id)

func _spawn_player() -> void:
	var player_scene = preload("res://scenes/entities/player.tscn")
	player = player_scene.instantiate()
	player.global_position = $SpawnPoint.global_position if has_node("SpawnPoint") else Vector2(100, 300)
	add_child(player)

func _setup_camera() -> void:
	var camera = Camera2D.new()
	camera.name = "Camera"
	camera.add_to_group("camera")
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0

	# Zoom out to see the whole room
	# Calculate zoom needed to fit room (with some padding)
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_x = viewport_size.x / room_width
	var zoom_y = viewport_size.y / room_height
	var zoom_level = min(zoom_x, zoom_y) * 0.9  # 90% to add padding

	# Don't zoom in more than 1.0 (normal view)
	zoom_level = min(zoom_level, 0.6)  # Cap at 0.6 for comfortable viewing

	camera.zoom = Vector2(zoom_level, zoom_level)

	# Set camera limits based on room size
	camera.limit_left = -50
	camera.limit_top = -50
	camera.limit_right = int(room_width + 50)
	camera.limit_bottom = int(floor_y + 100)

	player.add_child(camera)
	camera.make_current()

func _setup_walls() -> void:
	# Create invisible walls around the room to prevent player from falling out
	var wall_thickness = 50.0

	# Left wall
	_create_wall(Vector2(-wall_thickness / 2, room_height / 2), Vector2(wall_thickness, room_height + 400))
	# Right wall
	_create_wall(Vector2(room_width + wall_thickness / 2, room_height / 2), Vector2(wall_thickness, room_height + 400))
	# Ceiling
	_create_wall(Vector2(room_width / 2, -wall_thickness / 2), Vector2(room_width + 100, wall_thickness))
	# Floor (solid ground to stand on)
	_create_wall(Vector2(room_width / 2, floor_y + wall_thickness / 2), Vector2(room_width + 100, wall_thickness))

func _create_wall(pos: Vector2, size: Vector2) -> void:
	var wall = StaticBody2D.new()
	wall.name = "Wall"
	wall.position = pos
	wall.collision_layer = 128  # Room boundaries layer (layer 8) - always collides with player
	wall.collision_mask = 0

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect

	wall.add_child(shape)
	add_child(wall)

func _setup_floor_hazard() -> void:
	if not has_floor_hazard:
		return

	# Create floor death zone (above the solid floor)
	var hazard = Area2D.new()
	hazard.name = "FloorHazard"
	hazard.collision_layer = 0  # Don't need to be detected
	hazard.collision_mask = 1  # Detect player layer
	hazard.monitoring = true
	hazard.monitorable = false

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(10000, 50)  # Wide hazard zone
	shape.shape = rect

	hazard.add_child(shape)
	hazard.position = Vector2(room_width / 2, floor_y - 25)  # Just above floor
	add_child(hazard)

	hazard.body_entered.connect(_on_floor_hazard_entered)

	# Add red danger line visual indicator
	_create_floor_danger_line()

func _on_floor_hazard_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Pass "pit" as damage source for module intercept (Gravity Anchor)
		# Pits always deal lethal damage - only Gravity Anchor module can save from pits
		body.take_damage(999, "pit")

func _create_floor_danger_line() -> void:
	# Create a visual red line to indicate the floor is dangerous (lava)
	var danger_line = Node2D.new()
	danger_line.name = "FloorDangerLine"
	danger_line.position = Vector2(0, floor_y - 5)
	danger_line.set_script(preload("res://scripts/effects/floor_danger_line.gd"))
	danger_line.set_meta("room_width", room_width)
	add_child(danger_line)

func _setup_wall_grapple_points() -> void:
	# Add grapple points on ceiling and walls for better traversal
	var grapple_spacing = 200.0

	# Ceiling grapple points
	for i in range(int(room_width / grapple_spacing)):
		var x = grapple_spacing / 2 + i * grapple_spacing
		_create_grapple_point(Vector2(x, 50))

	# Left wall grapple points
	for i in range(int(room_height / grapple_spacing)):
		var y = grapple_spacing / 2 + i * grapple_spacing
		_create_grapple_point(Vector2(50, y))

	# Right wall grapple points
	for i in range(int(room_height / grapple_spacing)):
		var y = grapple_spacing / 2 + i * grapple_spacing
		_create_grapple_point(Vector2(room_width - 50, y))

func _create_grapple_point(pos: Vector2) -> void:
	var point = StaticBody2D.new()
	point.name = "GrapplePoint"
	point.position = pos
	point.collision_layer = 64  # Grapple targets layer (layer 7)
	point.collision_mask = 0

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle

	point.add_child(shape)
	add_child(point)

	# Store reference for drawing
	point.set_meta("is_grapple_point", true)

func _setup_wall_frame_visual() -> void:
	# Create visual wall frame to indicate grappleable walls
	var wall_frame = Node2D.new()
	wall_frame.name = "WallFrame"
	wall_frame.set_script(preload("res://scripts/effects/wall_frame.gd"))
	wall_frame.set_meta("room_width", room_width)
	wall_frame.set_meta("room_height", room_height)
	wall_frame.set_meta("floor_y", floor_y)
	add_child(wall_frame)

func _add_hud() -> void:
	var hud_scene = preload("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)

func _add_screen_effects() -> void:
	var effects_scene = preload("res://scenes/ui/screen_effects.tscn")
	var effects = effects_scene.instantiate()
	add_child(effects)

func _add_pause_menu() -> void:
	var pause_scene = preload("res://scenes/ui/pause_menu.tscn")
	var pause_menu = pause_scene.instantiate()
	add_child(pause_menu)

func _add_victory_screen() -> void:
	var victory_scene = preload("res://scenes/ui/victory_screen.tscn")
	var victory_screen = victory_scene.instantiate()
	add_child(victory_screen)

func _add_inventory_ui() -> void:
	var inventory_scene = preload("res://scenes/ui/inventory_ui.tscn")
	var inventory_ui = inventory_scene.instantiate()
	add_child(inventory_ui)

func _add_death_screen() -> void:
	var death_scene = preload("res://scenes/ui/death_screen.tscn")
	var death_screen = death_scene.instantiate()
	add_child(death_screen)
