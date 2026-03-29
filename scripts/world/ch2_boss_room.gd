extends RoomBase
class_name Ch2BossRoom
## Chapter 2 Boss Room - Ground-Fault Titan arena
## Features: Electric floor, 3 floating islands, descending ceiling spikes

var ceiling_spikes_y: float = -100.0
var spikes_target_y: float = 400.0
var spikes_lowering: bool = false
var ceiling_hazard: Area2D = null

# Floating islands positions (3 safe zones)
var island_positions: Array[Vector2] = [
	Vector2(400, 550),
	Vector2(960, 450),
	Vector2(1520, 550)
]

func _ready() -> void:
	# Set up boss room dimensions
	room_width = 1920.0
	room_height = 1200.0
	floor_y = 1000.0
	has_floor_hazard = false  # Electric floor handles this instead

	super._ready()

	_create_floating_islands()
	_add_ceiling_grapple_points()

	# Connect boss signals
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.ceiling_spikes_lowering.connect(_on_ceiling_spikes_lowering)
	EventBus.boss_defeated.connect(_on_boss_defeated)

func _create_floating_islands() -> void:
	var platform_scene = preload("res://scenes/entities/platform.tscn")

	for i in range(island_positions.size()):
		var platform = platform_scene.instantiate()
		platform.global_position = island_positions[i]
		platform.platform_type = "stable"
		platform.width = 200.0
		add_child(platform)

func _add_ceiling_grapple_points() -> void:
	# Add extra ceiling grapple points for boss arena
	var spacing = 150.0
	for i in range(int(room_width / spacing)):
		var x = spacing / 2 + i * spacing
		_create_grapple_point(Vector2(x, 100))

func _on_boss_phase_changed(phase: int) -> void:
	# Ceiling spikes removed - no longer activating on phase 3
	pass

func _on_ceiling_spikes_lowering(target_y: float) -> void:
	spikes_target_y = target_y
	spikes_lowering = true

func _on_boss_defeated() -> void:
	spikes_lowering = false
	# Remove ceiling hazard
	if ceiling_hazard:
		ceiling_hazard.queue_free()
		ceiling_hazard = null

func _process(delta: float) -> void:
	if spikes_lowering and ceiling_spikes_y < spikes_target_y:
		ceiling_spikes_y += 40.0 * delta
		_update_ceiling_hazard()

	queue_redraw()

func _update_ceiling_hazard() -> void:
	if not ceiling_hazard:
		ceiling_hazard = Area2D.new()
		ceiling_hazard.name = "CeilingSpikes"
		ceiling_hazard.collision_layer = 32  # Hazards
		ceiling_hazard.collision_mask = 1    # Player

		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(room_width + 200, 100)
		shape.shape = rect
		ceiling_hazard.add_child(shape)

		add_child(ceiling_hazard)
		ceiling_hazard.body_entered.connect(_on_ceiling_entered)

	ceiling_hazard.position = Vector2(room_width / 2, ceiling_spikes_y + 50)

func _on_ceiling_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(999)  # Instant death

func _draw() -> void:
	# Draw ceiling spikes when lowering
	if ceiling_spikes_y > 0:
		var spike_color = Color(0.5, 0.5, 0.6)
		var num_spikes = int(room_width / 50)
		for i in range(num_spikes):
			var x = 25 + i * 50
			var points = PackedVector2Array([
				Vector2(x - 20, ceiling_spikes_y - 50),
				Vector2(x, ceiling_spikes_y + 50),
				Vector2(x + 20, ceiling_spikes_y - 50)
			])
			draw_colored_polygon(points, spike_color)

		# Draw spike base
		draw_rect(Rect2(-100, ceiling_spikes_y - 100, room_width + 200, 50), spike_color * 0.8)

	# Draw warning text when spikes are lowering
	if spikes_lowering:
		var warning_alpha = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
		draw_string(ThemeDB.fallback_font, Vector2(room_width / 2 - 100, ceiling_spikes_y + 100),
			"CEILING DESCENDING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 0.3, 0.3, warning_alpha))
