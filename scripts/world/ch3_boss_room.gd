extends RoomBase
class_name Ch3BossRoom
## Boss arena for Chapter 3 - Apex-Interceptor fight
## Ring of floating islands around a central kill zone

const BOSS_SCENE = preload("res://scenes/entities/ch3/apex_interceptor.tscn")
const PLATFORM_SCENE = preload("res://scenes/entities/platform.tscn")

# Boss arena layout
var boss: Node2D = null
var floating_islands: Array = []

func _ready() -> void:
	# Override room dimensions for boss arena
	room_width = 2400.0
	room_height = 1400.0
	floor_y = 1300.0
	has_floor_hazard = false  # No floor hazard - danger from boss attacks

	super._ready()

	# Create floating island ring
	_create_floating_islands()

	# Add extra grapple points for mobility
	_add_boss_arena_grapple_points()

	# Spawn boss
	_spawn_boss()

func _create_floating_islands() -> void:
	# Create a ring of small floating islands around the center
	# Center is the "kill zone" with no platforms

	var center = Vector2(room_width / 2, room_height / 2)
	var ring_radius = 500.0
	var island_count = 8

	for i in range(island_count):
		var angle = TAU * i / island_count
		var island_pos = center + Vector2.from_angle(angle) * ring_radius

		# Vary island heights slightly
		island_pos.y += randf_range(-50, 50)

		_create_island(island_pos, 150.0 + randf_range(-20, 20))

	# Add some inner islands for more mobility
	var inner_radius = 250.0
	for i in range(4):
		var angle = TAU * i / 4 + PI/8  # Offset from outer ring
		var island_pos = center + Vector2.from_angle(angle) * inner_radius
		_create_island(island_pos, 100.0)

func _create_island(pos: Vector2, width: float) -> void:
	var platform = PLATFORM_SCENE.instantiate()
	platform.global_position = pos
	platform.width = width
	platform.platform_type = "stable"  # Boss platforms don't crumble
	add_child(platform)
	floating_islands.append(platform)

func _add_boss_arena_grapple_points() -> void:
	# Extra dense grapple points on ceiling
	var spacing = 150.0

	for i in range(int(room_width / spacing)):
		var x = spacing / 2 + i * spacing
		_create_grapple_point(Vector2(x, 80))

	# Corner grapple points
	var corners = [
		Vector2(100, 100),
		Vector2(room_width - 100, 100),
		Vector2(100, room_height - 200),
		Vector2(room_width - 100, room_height - 200)
	]
	for corner in corners:
		_create_grapple_point(corner)

	# Mid-wall grapple points
	for i in range(6):
		var y = 200 + i * 180
		_create_grapple_point(Vector2(80, y))
		_create_grapple_point(Vector2(room_width - 80, y))

func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.global_position = Vector2(room_width / 2, 400)
	add_child(boss)

func _draw() -> void:
	# Draw background
	draw_rect(Rect2(0, 0, room_width, room_height), Color(0.08, 0.06, 0.1))

	# Draw arena boundary visual
	var center = Vector2(room_width / 2, room_height / 2)

	# Draw kill zone indicator in center
	var kill_zone_color = Color(0.3, 0.1, 0.1, 0.3)
	draw_circle(center, 200, kill_zone_color)

	# Draw arena ring
	draw_arc(center, 500, 0, TAU, 64, Color(0.2, 0.15, 0.25, 0.5), 3.0)

	# Draw atmospheric particles (simple dots)
	for i in range(20):
		var particle_pos = Vector2(
			fmod(i * 137.5 + Engine.get_physics_frames() * 0.3, room_width),
			fmod(i * 89.3 + Engine.get_physics_frames() * 0.2, room_height)
		)
		draw_circle(particle_pos, 2, Color(0.4, 0.3, 0.5, 0.3))
