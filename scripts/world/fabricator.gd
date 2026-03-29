extends Area2D
class_name Fabricator
## Fabricator terminal - triggers the ShopMenu when player interacts

var can_interact: bool = false
var shop_menu: Node = null

var width: float = 100.0
var height: float = 150.0

func _ready() -> void:
	add_to_group("fabricator")

	# Setup collision
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height + 50)
	$CollisionShape2D.shape = shape

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
	# Open shop with Space when near fabricator
	if can_interact and Input.is_action_just_pressed("jump"):
		_open_shop()

func _open_shop() -> void:
	# Find or create shop menu
	if shop_menu == null:
		var existing = get_tree().get_nodes_in_group("shop_menu")
		if existing.size() > 0:
			shop_menu = existing[0]
		else:
			# Spawn shop menu
			var shop_scene = preload("res://scenes/ui/shop_menu.tscn")
			shop_menu = shop_scene.instantiate()
			shop_menu.add_to_group("shop_menu")
			get_tree().current_scene.add_child(shop_menu)

	if shop_menu and shop_menu.has_method("open_shop"):
		shop_menu.open_shop()

func _draw() -> void:
	# Draw fabricator body
	var rect = Rect2(-width / 2, -height / 2, width, height)
	draw_rect(rect, Color(0.3, 0.3, 0.4))
	draw_rect(rect, Color(0.5, 0.5, 0.6), false, 3.0)

	# Draw screen
	var screen_color = Color(0.1, 0.2, 0.3) if not can_interact else Color(0.1, 0.3, 0.2)
	var screen_rect = Rect2(-width / 2 + 10, -height / 2 + 10, width - 20, 60)
	draw_rect(screen_rect, screen_color)

	# Draw "FABRICATOR" text
	draw_string(ThemeDB.fallback_font, Vector2(-35, -height / 2 + 40), "FABRICATOR", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.3, 0.8, 0.3))

	# Draw buttons/lights
	for i in range(3):
		var light_x = -20 + i * 20
		var light_color = Color(0.2, 0.8, 0.2) if i == 1 else Color(0.3, 0.3, 0.3)
		draw_circle(Vector2(light_x, height / 2 - 20), 5, light_color)

	# Draw interaction prompt when player is near
	if can_interact:
		draw_string(ThemeDB.fallback_font, Vector2(-width / 2, height / 2 + 15), "[SPACE]", HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color.YELLOW)
		draw_string(ThemeDB.fallback_font, Vector2(-width / 2 + 5, height / 2 + 30), "Open Shop", HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(0.7, 0.7, 0.7))
