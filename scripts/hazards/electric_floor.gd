extends Node2D
class_name ElectricFloor
## Full-room electric floor hazard (boss-controlled)
## Used by Ground-Fault Titan boss fight

@export var is_boss_controlled: bool = true
@export var damage: int = 1
@export var damage_interval: float = 0.2

var is_active: bool = false
var damage_timer: float = 0.0
var hazard_area: Area2D = null

var room_width: float = 1920.0
var floor_y: float = 900.0

func _ready() -> void:
	call_deferred("_setup_hazard_area")

func _setup_hazard_area() -> void:
	# Get room dimensions
	var room = get_tree().current_scene
	if room and "room_width" in room:
		room_width = room.room_width
	if room and "floor_y" in room:
		floor_y = room.floor_y

	hazard_area = Area2D.new()
	hazard_area.collision_layer = 32  # Hazards
	hazard_area.collision_mask = 1    # Player
	hazard_area.monitoring = false    # Starts inactive

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(room_width + 200, 150)
	shape.shape = rect

	hazard_area.add_child(shape)
	hazard_area.position = Vector2(room_width / 2, floor_y - 75)
	add_child(hazard_area)

func activate() -> void:
	is_active = true
	if hazard_area:
		hazard_area.monitoring = true
	EventBus.electric_floor_activated.emit(0)
	queue_redraw()

func deactivate() -> void:
	is_active = false
	if hazard_area:
		hazard_area.monitoring = false
	EventBus.electric_floor_deactivated.emit(0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_active or not hazard_area:
		return

	damage_timer += delta

	if damage_timer >= damage_interval:
		var bodies = hazard_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				body.take_damage(damage, "electric")
				damage_timer = 0.0
				break  # Only damage once per interval

func _process(_delta: float) -> void:
	if is_active:
		queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	# Draw electrified floor
	var rect = Rect2(-100, floor_y - 150 - global_position.y, room_width + 200, 150)
	draw_rect(rect, Color(1.0, 0.3, 0.3, 0.4))

	# Draw lightning effects
	var num_bolts = int(room_width / 100)
	for i in range(num_bolts):
		var x = i * 100 + randf_range(-30, 30)
		var height = randf_range(50, 120)
		_draw_lightning_bolt(Vector2(x, floor_y - global_position.y), height)

	# Draw warning text
	var warning_rect = Rect2(-100, floor_y - 150 - global_position.y, room_width + 200, 150)
	draw_rect(warning_rect, Color(1.0, 0.2, 0.2, 0.6), false, 4.0)

func _draw_lightning_bolt(base: Vector2, height: float) -> void:
	var segments = 5
	var prev = base
	for i in range(segments):
		var t = float(i + 1) / segments
		var next = Vector2(prev.x + randf_range(-20, 20), base.y - height * t)
		draw_line(prev, next, Color(1, 1, 0.5, 0.8), 2.0)
		prev = next
