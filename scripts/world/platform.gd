extends StaticBody2D
class_name Platform
## Platform with crumble mechanic - 3 second timer when player stands on it

@export var platform_type: String = "crumble"  # "stable" or "crumble"
@export var is_grappleable: bool = true
@export var width: float = 150.0
@export var height: float = 30.0

# Crumble state
const CRUMBLE_TIME: float = 3.0
const RESPAWN_TIME: float = 2.0  # Time to respawn after destruction
var crumble_timer: float = 0.0
var respawn_timer: float = 0.0
var is_crumbling: bool = false
var is_destroyed: bool = false
var flash_timer: float = 0.0

# Colors
var base_color: Color = Color(0.29, 0.29, 0.29)  # Grey
var outline_color: Color = Color(0.133, 0.8, 0.133)  # Green (safe)

# Store original collision layer for respawn
var original_collision_layer: int = 0

# References
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var player_detector: Area2D = $PlayerDetector

func _ready() -> void:
	add_to_group("platforms")
	if is_grappleable:
		add_to_group("grapple_targets")
		# Add to grapple layer
		collision_layer |= 64  # Layer 7

	# Store original collision layer for respawn
	original_collision_layer = collision_layer

	_setup_collision_shape()
	_setup_player_detector()

func _setup_collision_shape() -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision_shape.shape = shape
	# Make platform one-way - player can jump through from below
	collision_shape.one_way_collision = true
	collision_shape.one_way_collision_margin = 16.0  # Some margin for smooth landing

func _setup_player_detector() -> void:
	# Area slightly above platform to detect player standing
	var detector_shape = RectangleShape2D.new()
	detector_shape.size = Vector2(width - 10, 20)
	player_detector.get_node("CollisionShape2D").shape = detector_shape
	player_detector.position.y = -height / 2 - 10

	player_detector.body_entered.connect(_on_player_entered)
	player_detector.body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player") and platform_type == "crumble" and not is_crumbling:
		start_crumble()

func _on_player_exited(body: Node2D) -> void:
	# Player left but crumble continues once started
	pass

func start_crumble() -> void:
	if platform_type != "crumble" or is_crumbling:
		return

	is_crumbling = true
	crumble_timer = CRUMBLE_TIME
	EventBus.platform_crumble_started.emit(self)

func _process(delta: float) -> void:
	# Handle respawn timer when destroyed
	if is_destroyed:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()
		return

	if not is_crumbling:
		return

	crumble_timer -= delta
	flash_timer += delta

	# Update outline color based on remaining time
	var ratio = crumble_timer / CRUMBLE_TIME
	if ratio > 0.66:
		outline_color = Color(0.133, 0.8, 0.133)  # Green
	elif ratio > 0.33:
		outline_color = Color(0.8, 0.8, 0.133)  # Yellow
	else:
		outline_color = Color(0.8, 0.133, 0.133)  # Red

	# Destroy when timer expires
	if crumble_timer <= 0:
		destroy()

	queue_redraw()

func destroy() -> void:
	is_destroyed = true
	respawn_timer = RESPAWN_TIME

	# Emit destruction event for particles
	EventBus.platform_destroyed.emit(global_position)

	# Spawn destruction particles
	_spawn_destruction_particles()

	# Disable collision and hide - also clear collision layer to prevent grappling
	collision_shape.set_deferred("disabled", true)
	player_detector.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)  # Prevent grapple raycast from hitting destroyed platform
	modulate.a = 0.0  # Hide platform
	queue_redraw()

func _respawn() -> void:
	# Reset platform state
	is_destroyed = false
	is_crumbling = false
	crumble_timer = 0.0
	flash_timer = 0.0
	outline_color = Color(0.133, 0.8, 0.133)  # Reset to green

	# Re-enable collision and show
	collision_shape.set_deferred("disabled", false)
	player_detector.set_deferred("monitoring", true)
	set_deferred("collision_layer", original_collision_layer)  # Restore collision layer for grappling

	# Fade in effect
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	queue_redraw()

func _spawn_destruction_particles() -> void:
	# Create simple particle burst
	for i in range(8):
		var particle = _create_particle()
		particle.global_position = global_position + Vector2(
			randf_range(-width / 2, width / 2),
			randf_range(-height / 2, height / 2)
		)
		get_tree().current_scene.add_child(particle)

func _create_particle() -> Node2D:
	var particle = Node2D.new()
	particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
	return particle

func _draw() -> void:
	if is_destroyed:
		return

	var rect = Rect2(-width / 2, -height / 2, width, height)

	# Flash effect when crumbling
	var flash = is_crumbling and fmod(flash_timer * 10, 2.0) < 1.0
	var draw_color = Color.WHITE if flash else base_color

	# Draw filled rectangle
	draw_rect(rect, draw_color)

	# Draw colored outline
	draw_rect(rect, outline_color, false, 3.0)
