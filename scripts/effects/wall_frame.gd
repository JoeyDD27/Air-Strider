extends Node2D
## Visual wall frame indicating grappleable walls around the room

var room_width: float = 1920.0
var room_height: float = 1000.0
var floor_y: float = 900.0

# Frame styling
var frame_color: Color = Color(0.3, 0.5, 0.7, 0.6)  # Blue-gray, semi-transparent
var frame_thickness: float = 8.0
var corner_size: float = 30.0
var grapple_indicator_color: Color = Color(0.4, 0.8, 0.4, 0.5)  # Green tint for grapple points
var pulse_timer: float = 0.0

func _ready() -> void:
	# Get room dimensions from metadata
	if has_meta("room_width"):
		room_width = get_meta("room_width")
	if has_meta("room_height"):
		room_height = get_meta("room_height")
	if has_meta("floor_y"):
		floor_y = get_meta("floor_y")

func _process(delta: float) -> void:
	pulse_timer += delta
	queue_redraw()

func _draw() -> void:
	# Frame boundaries match actual wall collision edges
	# Walls are at x=0, x=room_width, y=0, y=floor_y
	var left = 0.0
	var right = room_width
	var top = 0.0
	var bottom = floor_y

	# Pulsing alpha for grapple indicators
	var pulse_alpha = 0.3 + sin(pulse_timer * 2.0) * 0.15
	var indicator_color = Color(grapple_indicator_color.r, grapple_indicator_color.g, grapple_indicator_color.b, pulse_alpha)

	# Draw main frame outline
	# Left wall
	draw_line(Vector2(left, top), Vector2(left, bottom), frame_color, frame_thickness)
	# Right wall
	draw_line(Vector2(right, top), Vector2(right, bottom), frame_color, frame_thickness)
	# Ceiling
	draw_line(Vector2(left, top), Vector2(right, top), frame_color, frame_thickness)
	# Floor line (if no hazard, otherwise the danger line shows)
	draw_line(Vector2(left, bottom), Vector2(right, bottom), frame_color, frame_thickness * 0.5)

	# Draw corner brackets to emphasize the frame
	_draw_corner(Vector2(left, top), 1, 1)  # Top-left
	_draw_corner(Vector2(right, top), -1, 1)  # Top-right
	_draw_corner(Vector2(left, bottom), 1, -1)  # Bottom-left
	_draw_corner(Vector2(right, bottom), -1, -1)  # Bottom-right

	# Draw grapple point indicators along walls
	var grapple_spacing = 200.0

	# Left wall grapple indicators
	for i in range(int(room_height / grapple_spacing)):
		var y = grapple_spacing / 2 + i * grapple_spacing
		if y < floor_y - 50:
			_draw_grapple_indicator(Vector2(left + 25, y), indicator_color)

	# Right wall grapple indicators
	for i in range(int(room_height / grapple_spacing)):
		var y = grapple_spacing / 2 + i * grapple_spacing
		if y < floor_y - 50:
			_draw_grapple_indicator(Vector2(right - 25, y), indicator_color)

	# Ceiling grapple indicators
	for i in range(int(room_width / grapple_spacing)):
		var x = grapple_spacing / 2 + i * grapple_spacing
		_draw_grapple_indicator(Vector2(x, top + 25), indicator_color)

func _draw_corner(pos: Vector2, dir_x: int, dir_y: int) -> void:
	var corner_color = Color(0.5, 0.7, 0.9, 0.8)  # Brighter for corners
	var thickness = frame_thickness * 1.5

	# Horizontal part of corner
	draw_line(pos, pos + Vector2(corner_size * dir_x, 0), corner_color, thickness)
	# Vertical part of corner
	draw_line(pos, pos + Vector2(0, corner_size * dir_y), corner_color, thickness)

func _draw_grapple_indicator(pos: Vector2, color: Color) -> void:
	# Draw a small diamond/rhombus shape to indicate grapple point
	var size = 8.0
	var points = PackedVector2Array([
		pos + Vector2(0, -size),  # Top
		pos + Vector2(size, 0),   # Right
		pos + Vector2(0, size),   # Bottom
		pos + Vector2(-size, 0)   # Left
	])
	draw_colored_polygon(points, color)

	# Draw outline
	var outline_color = Color(color.r, color.g, color.b, color.a + 0.2)
	for i in range(4):
		draw_line(points[i], points[(i + 1) % 4], outline_color, 1.5)
