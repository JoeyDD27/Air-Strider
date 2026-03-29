extends RoomBase
class_name Ch5BossRoom
## Boss arena for Chapter 5 - Orbital Aegis fight
## Open arena with floating platforms and lethal floor

const BOSS_SCENE = preload("res://scenes/entities/ch5/orbital_aegis.tscn")
const PLATFORM_SCENE = preload("res://scenes/entities/platform.tscn")

# Boss arena layout
var boss: Node2D = null
var floating_platforms: Array = []

func _ready() -> void:
	# Override room dimensions for boss arena
	room_width = 1920.0
	room_height = 1200.0
	floor_y = 1100.0
	has_floor_hazard = true  # Lethal floor - "Floor is Lava" theme

	super._ready()

	# Create floating platforms
	_create_floating_platforms()

	# Add grapple points for mobility
	_add_boss_arena_grapple_points()

	# Spawn boss
	_spawn_boss()

func _create_floating_platforms() -> void:
	# Create platforms around the arena with the boss in center
	var center = Vector2(room_width / 2, room_height / 2)

	# Outer ring of platforms
	var platform_positions = [
		Vector2(200, 800),  # Left low
		Vector2(200, 500),  # Left mid
		Vector2(200, 250),  # Left high
		Vector2(960, 900),  # Center low (safe starting area)
		Vector2(960, 350),  # Center high (above boss)
		Vector2(1720, 800),  # Right low
		Vector2(1720, 500),  # Right mid
		Vector2(1720, 250),  # Right high
		Vector2(500, 650),  # Mid-left
		Vector2(1420, 650),  # Mid-right
	]

	for pos in platform_positions:
		_create_platform(pos, 180.0)

func _create_platform(pos: Vector2, width: float) -> void:
	var platform = PLATFORM_SCENE.instantiate()
	platform.global_position = pos
	platform.width = width
	platform.platform_type = "stable"  # Boss platforms don't crumble
	add_child(platform)
	floating_platforms.append(platform)

func _add_boss_arena_grapple_points() -> void:
	# Ceiling grapple points
	var ceiling_spacing = 200.0
	for i in range(int(room_width / ceiling_spacing)):
		var x = ceiling_spacing / 2 + i * ceiling_spacing
		_create_grapple_point(Vector2(x, 80))

	# Wall grapple points
	for i in range(5):
		var y = 200 + i * 180
		_create_grapple_point(Vector2(80, y))
		_create_grapple_point(Vector2(room_width - 80, y))

	# Mid-air grapple points for dodging
	var mid_points = [
		Vector2(400, 400),
		Vector2(1520, 400),
		Vector2(960, 200),
		Vector2(600, 700),
		Vector2(1320, 700),
	]
	for point in mid_points:
		_create_grapple_point(point)

func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.global_position = Vector2(room_width / 2, 550)
	add_child(boss)

func _draw() -> void:
	# Draw background
	draw_rect(Rect2(0, 0, room_width, room_height), Color(0.1, 0.06, 0.08))

	# Draw danger zone at bottom (lava glow)
	var lava_gradient_height = 150.0
	for i in range(10):
		var y = floor_y - lava_gradient_height + i * (lava_gradient_height / 10)
		var alpha = float(i) / 10 * 0.3
		draw_line(Vector2(0, y), Vector2(room_width, y), Color(0.8, 0.2, 0.1, alpha), 2.0)

	# Draw atmospheric particles
	for i in range(15):
		var particle_pos = Vector2(
			fmod(i * 137.5 + Engine.get_physics_frames() * 0.2, room_width),
			fmod(i * 89.3 + Engine.get_physics_frames() * 0.15, room_height - 200)
		)
		draw_circle(particle_pos, 2, Color(0.5, 0.3, 0.3, 0.3))
