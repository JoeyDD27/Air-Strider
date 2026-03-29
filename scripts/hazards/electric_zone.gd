extends Area2D
class_name ElectricZone
## Individual electrified zone created by Arc-Caster enemies

@export var zone_width: float = 400.0
@export var zone_height: float = 200.0
@export var damage: int = 1
@export var damage_interval: float = 0.3  # Damage tick rate

var owner_id: int = 0  # ID of the Arc-Caster that created this zone
var damage_timer: float = 0.0

func _ready() -> void:
	collision_layer = 32  # Hazards layer
	collision_mask = 1    # Player layer
	monitoring = true

	_setup_collision_shape()
	body_entered.connect(_on_body_entered)

func _setup_collision_shape() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(zone_width, zone_height)
	shape.shape = rect
	shape.position = Vector2(0, -zone_height / 2)
	add_child(shape)

func _process(delta: float) -> void:
	damage_timer += delta
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# Continuous damage to player in zone
	if damage_timer >= damage_interval:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				body.take_damage(damage, "electric")
				damage_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage, "electric")
		damage_timer = 0.0

func _draw() -> void:
	# Draw electrified floor area
	var rect = Rect2(-zone_width / 2, -zone_height, zone_width, zone_height)
	draw_rect(rect, Color(1.0, 0.3, 0.3, 0.3))

	# Draw electric arcs
	var num_arcs = int(zone_width / 50)
	for i in range(num_arcs):
		var x = -zone_width / 2 + i * 50 + randf_range(-10, 10)
		var height = randf_range(zone_height * 0.3, zone_height * 0.8)
		_draw_lightning(Vector2(x, 0), Vector2(x + randf_range(-20, 20), -height))

	# Draw warning border
	draw_rect(rect, Color(1.0, 0.2, 0.2, 0.8), false, 3.0)

func _draw_lightning(start: Vector2, end: Vector2) -> void:
	var segments = 4
	var prev = start
	for i in range(segments):
		var t = float(i + 1) / segments
		var next = start.lerp(end, t)
		if i < segments - 1:
			next.x += randf_range(-15, 15)
		draw_line(prev, next, Color(1, 1, 0.5, 0.9), 2.0)
		prev = next
