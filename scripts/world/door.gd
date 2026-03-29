extends Area2D
class_name Door
## Door for room transitions

@export var next_room_id: int = 2
@export var width: float = 50.0
@export var height: float = 100.0
@export var requires_clear: bool = true

var is_open: bool = false
var door_color: Color = Color(0.2, 0.6, 0.2)  # Green when open
var door_closed_color: Color = Color(0.5, 0.2, 0.2)  # Red when closed

func _ready() -> void:
	add_to_group("doors")

	# Setup collision - detect player
	collision_layer = 0
	collision_mask = 1  # Detect player
	monitoring = true

	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	$CollisionShape2D.shape = shape

	body_entered.connect(_on_body_entered)

	# Connect to room cleared event
	EventBus.all_enemies_killed.connect(_on_room_cleared)

	# Check if this is a shop room (no enemies) - wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame  # Wait extra frame for enemies to register
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count = 0
	for enemy in enemies:
		if not enemy.get("is_dead"):
			alive_count += 1
	if alive_count == 0 or not requires_clear:
		_open_door()

func _on_room_cleared() -> void:
	_open_door()

# Also check periodically in case signal was missed
func _process(_delta: float) -> void:
	if is_open or not requires_clear:
		return

	# Check if all enemies are dead
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count = 0
	for enemy in enemies:
		if "is_dead" in enemy:
			if not enemy.is_dead:
				alive_count += 1
		elif is_instance_valid(enemy):
			alive_count += 1

	if alive_count == 0:
		_open_door()

func _open_door() -> void:
	is_open = true
	EventBus.door_opened.emit(self)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_open:
		# Use call_deferred to avoid physics callback errors
		GameManager.call_deferred("next_room")

func _draw() -> void:
	var rect = Rect2(-width / 2, -height / 2, width, height)
	var color = door_color if is_open else door_closed_color

	# Draw door frame
	draw_rect(rect, color, false, 4.0)

	# Draw door fill (partially transparent)
	draw_rect(rect, Color(color, 0.3))

	# Draw arrow indicator if open
	if is_open:
		var arrow_points = PackedVector2Array([
			Vector2(10, 0),
			Vector2(-5, -10),
			Vector2(-5, 10)
		])
		draw_colored_polygon(arrow_points, Color.WHITE)
