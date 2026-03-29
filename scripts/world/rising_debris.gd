extends StaticBody2D
class_name RisingDebris
## Rising platform spawned by Furnace Crab - player can grapple to stay airborne

@export var rise_speed: float = 80.0
@export var width: float = 200.0
@export var height: float = 60.0

# Crumble state (same as regular platforms)
const CRUMBLE_TIME: float = 3.0
var crumble_timer: float = 0.0
var is_crumbling: bool = false
var is_destroyed: bool = false
var flash_timer: float = 0.0

# Ceiling death zone
var ceiling_y: float = 100.0

# Colors
var base_color: Color = Color(0.4, 0.3, 0.25)  # Rocky brown
var outline_color: Color = Color(0.133, 0.8, 0.133)  # Green

func _ready() -> void:
	add_to_group("platforms")
	add_to_group("grapple_targets")
	add_to_group("rising_debris")

	# Set collision
	collision_layer = 2 | 64  # Platform and grapple layer

	_setup_collision()
	_setup_player_detector()

func _setup_collision() -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	$CollisionShape2D.shape = shape

func _setup_player_detector() -> void:
	var detector = Area2D.new()
	detector.name = "PlayerDetector"
	detector.collision_layer = 0
	detector.collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width - 10, 20)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2 - 10)

	detector.add_child(shape)
	add_child(detector)

	detector.body_entered.connect(_on_player_entered)

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_crumbling:
		start_crumble()

func start_crumble() -> void:
	if is_crumbling:
		return
	is_crumbling = true
	crumble_timer = CRUMBLE_TIME

func _process(delta: float) -> void:
	# Rise upward
	global_position.y -= rise_speed * delta

	# Destroy if hit ceiling
	if global_position.y < ceiling_y:
		destroy()
		return

	# Handle crumbling
	if is_crumbling and not is_destroyed:
		crumble_timer -= delta
		flash_timer += delta

		var ratio = crumble_timer / CRUMBLE_TIME
		if ratio > 0.66:
			outline_color = Color(0.133, 0.8, 0.133)
		elif ratio > 0.33:
			outline_color = Color(0.8, 0.8, 0.133)
		else:
			outline_color = Color(0.8, 0.133, 0.133)

		if crumble_timer <= 0:
			destroy()

	queue_redraw()

func destroy() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	EventBus.platform_destroyed.emit(global_position)

	# Spawn particles
	for i in range(6):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position + Vector2(
			randf_range(-width / 2, width / 2),
			randf_range(-height / 2, height / 2)
		)
		particle.color = base_color
		get_tree().current_scene.add_child(particle)

	queue_free()

func _draw() -> void:
	if is_destroyed:
		return

	var rect = Rect2(-width / 2, -height / 2, width, height)

	var flash = is_crumbling and fmod(flash_timer * 10, 2.0) < 1.0
	var draw_color = Color.WHITE if flash else base_color

	draw_rect(rect, draw_color)
	draw_rect(rect, outline_color, false, 3.0)

	# Draw rocky texture lines
	draw_line(Vector2(-width / 3, -height / 2), Vector2(-width / 4, height / 2), Color(base_color * 0.8), 2.0)
	draw_line(Vector2(width / 4, -height / 2), Vector2(width / 3, height / 2), Color(base_color * 0.8), 2.0)
