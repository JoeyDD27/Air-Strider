extends Area2D
class_name SimulatorTerminal
## Interactive terminal that teleports player to Combat Simulator for coin farming

var can_interact: bool = false
var width: float = 60.0
var height: float = 90.0

func _ready() -> void:
	add_to_group("simulator_terminals")

	# Setup collision
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width, height + 30)
	shape.shape = rect

	if not has_node("CollisionShape2D"):
		add_child(shape)
	else:
		$CollisionShape2D.shape = rect

	collision_layer = 0
	collision_mask = 1  # Detect player

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = true
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = false
		queue_redraw()

func _process(_delta: float) -> void:
	if can_interact and Input.is_action_just_pressed("jump"):
		_enter_simulator()

func _enter_simulator() -> void:
	# Load combat simulator
	var sim_path = "res://scenes/rooms/combat_simulator.tscn"
	if ResourceLoader.exists(sim_path):
		get_tree().change_scene_to_file(sim_path)
	else:
		push_error("Combat Simulator scene not found at: " + sim_path)

func _draw() -> void:
	# Draw terminal body
	var body_color = Color(0.2, 0.25, 0.3)
	var screen_color = Color(0.1, 0.3, 0.2) if not can_interact else Color(0.2, 0.6, 0.3)

	# Main body
	draw_rect(Rect2(-width / 2, -height / 2, width, height), body_color)
	draw_rect(Rect2(-width / 2, -height / 2, width, height), Color(0.4, 0.45, 0.5), false, 2.0)

	# Screen
	var screen_rect = Rect2(-width / 2 + 8, -height / 2 + 10, width - 16, 45)
	draw_rect(screen_rect, screen_color)
	draw_rect(screen_rect, Color(0.3, 0.5, 0.3), false, 1.0)

	# Screen text
	draw_string(ThemeDB.fallback_font, Vector2(-width / 2 + 12, -height / 2 + 30), "COMBAT", HORIZONTAL_ALIGNMENT_LEFT, width - 20, 10, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-width / 2 + 20, -height / 2 + 45), "SIM", HORIZONTAL_ALIGNMENT_LEFT, width - 30, 12, Color.WHITE)

	# Buttons/lights
	for i in range(3):
		var light_x = -15 + i * 15
		var light_y = height / 2 - 25
		var light_color = Color(0.8, 0.2, 0.2) if i == 0 else Color(0.2, 0.8, 0.2) if i == 1 else Color(0.2, 0.2, 0.8)
		draw_circle(Vector2(light_x, light_y), 4, light_color)

	# Interaction prompt
	if can_interact:
		draw_string(ThemeDB.fallback_font, Vector2(-width / 2, height / 2 + 15), "[SPACE]", HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color.YELLOW)
		draw_string(ThemeDB.fallback_font, Vector2(-width / 2, height / 2 + 30), "Enter", HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(0.7, 0.7, 0.7))
