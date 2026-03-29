extends RoomBase
class_name BossRoom
## Special room class for boss fights

var debris_spawn_timer: float = 0.0
var debris_spawn_rate: float = 2.0  # Seconds between debris spawns
var rising_magma_y: float = 2400.0
var magma_rise_speed: float = 20.0
var magma_max_y: float = 1800.0
var current_boss_phase: int = 1
var debris_speed_multiplier: float = 1.0

func _ready() -> void:
	super._ready()
	has_floor_hazard = false  # Boss room handles hazards differently

	# Connect boss events
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	# Initialize boss health bar
	await get_tree().process_frame
	var bosses = get_tree().get_nodes_in_group("boss")
	if not bosses.is_empty():
		var boss = bosses[0]
		EventBus.boss_damaged.emit(boss.health, boss.max_health)

func _process(delta: float) -> void:
	# Spawn debris periodically
	debris_spawn_timer += delta
	if debris_spawn_timer >= debris_spawn_rate:
		debris_spawn_timer = 0.0
		_spawn_debris()

	# Rise magma slowly
	if rising_magma_y > magma_max_y:
		rising_magma_y -= magma_rise_speed * delta
		_update_magma_hazard()

func _spawn_debris() -> void:
	var debris = preload("res://scenes/entities/rising_debris.tscn").instantiate()
	debris.global_position = Vector2(
		randf_range(100, room_width - 100),
		rising_magma_y + randf_range(100, 300)
	)
	debris.ceiling_y = 100  # Destroy at ceiling
	debris.rise_speed = 80.0 * debris_speed_multiplier  # Apply speed multiplier
	add_child(debris)

func _update_magma_hazard() -> void:
	# Update or create magma hazard area
	# Hitbox extends from rising_magma_y down to floor_y + some buffer
	var hitbox_height = floor_y + 200 - rising_magma_y

	if not has_node("MagmaHazard"):
		var hazard = Area2D.new()
		hazard.name = "MagmaHazard"
		hazard.collision_layer = 32
		hazard.collision_mask = 1

		var shape = CollisionShape2D.new()
		shape.name = "Shape"
		var rect = RectangleShape2D.new()
		rect.size = Vector2(room_width + 100, hitbox_height)
		shape.shape = rect
		hazard.add_child(shape)

		add_child(hazard)
		hazard.body_entered.connect(_on_magma_entered)
	else:
		# Update hitbox size as magma rises
		var shape = $MagmaHazard/Shape
		if shape and shape.shape:
			shape.shape.size = Vector2(room_width + 100, hitbox_height)

	# Center the hitbox
	# Top edge at rising_magma_y, extends down to floor_y + 200
	var center_y = rising_magma_y + hitbox_height / 2
	$MagmaHazard.position = Vector2(room_width / 2, center_y)

func _on_magma_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body._on_hazard_entered()

func _on_boss_phase_changed(phase: int) -> void:
	current_boss_phase = phase
	# Speed up debris spawn in later phases
	match phase:
		2:
			debris_spawn_rate = 1.5
			magma_rise_speed = 30.0
			debris_speed_multiplier = 1.0
		3:
			debris_spawn_rate = 1.0
			magma_rise_speed = 40.0
			debris_speed_multiplier = 2.0  # Double speed floating rocks in phase 3

func _on_boss_defeated() -> void:
	# Stop spawning debris
	debris_spawn_rate = 999.0
	magma_rise_speed = 0.0

func _draw() -> void:
	# Draw magma from rising_magma_y down to the bottom of the room
	# Draw lava slightly ABOVE hitbox so players see it before touching
	var lava_visual_offset = -30.0  # Draw lava 30px higher than hitbox
	var lava_top = rising_magma_y + lava_visual_offset
	var lava_height = floor_y + 200 - lava_top  # Extend well past floor_y

	var magma_color = Color(1.0, 0.3, 0.0, 0.8)
	var magma_rect = Rect2(-50, lava_top, room_width + 100, lava_height)
	draw_rect(magma_rect, magma_color)

	# Draw magma glow above the lava surface
	var glow_color = Color(1.0, 0.5, 0.1, 0.3)
	draw_rect(Rect2(-50, lava_top - 50, room_width + 100, 50), glow_color)

	# Draw bright surface line at the lava surface
	var surface_color = Color(1.0, 0.8, 0.2, 0.9)
	draw_rect(Rect2(-50, lava_top, room_width + 100, 8), surface_color)
