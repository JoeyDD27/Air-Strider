extends Node2D
class_name FurnaceCrab
## Boss: Furnace Crab - shoots bullets and rockets at player

enum CrabPhase { INTRO, PHASE_1, PHASE_2, PHASE_3, DEFEATED }

@export var max_health: int = 10

var health: int
var phase: CrabPhase = CrabPhase.INTRO
var is_dead: bool = false

# Dimensions
var body_width: float = 300.0
var body_height: float = 200.0

# Attack state
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var bullet_burst_count: int = 0
var burst_timer: float = 0.0

# Visual
var body_color: Color = Color(0.533, 0.267, 0.133)  # Brown
var claw_color: Color = Color(0.667, 0.333, 0.2)  # Lighter brown
var eye_color: Color = Color(1.0, 0.4, 0.0)  # Orange

# Player reference
var player_ref: Node2D = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health = max_health

	# Setup hitbox for player projectiles
	_setup_hitbox()

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

	# Start intro
	_start_intro()

func _setup_hitbox() -> void:
	# Create Area2D for collision detection with player projectiles
	var hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4  # Enemies layer (layer 3)
	hitbox.collision_mask = 16  # Player projectiles layer (layer 5)
	hitbox.add_to_group("enemies")

	# Create collision shape matching body size
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(body_width, body_height)
	shape.shape = rect

	hitbox.add_child(shape)
	add_child(hitbox)

	# Connect area signal to detect player projectiles
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Check if it's a player projectile
	if area.is_in_group("player_projectiles") or area is PlayerProjectile:
		take_damage(1)  # 1 damage per hit, 10 hits to kill
		area.queue_free()

func _start_intro() -> void:
	phase = CrabPhase.INTRO
	# Brief delay before fight starts
	await get_tree().create_timer(1.5).timeout
	phase = CrabPhase.PHASE_1
	EventBus.boss_phase_changed.emit(1)

func _process(delta: float) -> void:
	if phase == CrabPhase.INTRO or phase == CrabPhase.DEFEATED:
		queue_redraw()
		return

	if not player_ref or GameManager.is_phantom_mode:
		return

	# Check phase transitions
	_check_phase_transition()

	# Handle burst firing
	if bullet_burst_count > 0:
		burst_timer += delta
		if burst_timer >= 0.2:  # Fire every 0.2 seconds during burst
			burst_timer = 0.0
			_fire_at_player()
			bullet_burst_count -= 1
	else:
		# Attack cycle
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			_start_attack()
			attack_timer = 0.0

	queue_redraw()

func _check_phase_transition() -> void:
	var health_ratio = float(health) / float(max_health)

	if health <= 0 and phase != CrabPhase.DEFEATED:
		_defeat()
	elif health_ratio <= 0.25 and phase != CrabPhase.PHASE_3:
		phase = CrabPhase.PHASE_3
		attack_cooldown = 1.0
		EventBus.boss_phase_changed.emit(3)
	elif health_ratio <= 0.5 and phase == CrabPhase.PHASE_1:
		phase = CrabPhase.PHASE_2
		attack_cooldown = 1.2
		EventBus.boss_phase_changed.emit(2)

func _defeat() -> void:
	phase = CrabPhase.DEFEATED
	is_dead = true
	EventBus.boss_defeated.emit()
	EventBus.hit_stop.emit(0.5)

	# Victory after delay
	await get_tree().create_timer(2.0).timeout
	EventBus.victory.emit()

func _start_attack() -> void:
	match phase:
		CrabPhase.PHASE_1:
			# Fire burst of 3 bullets
			bullet_burst_count = 3
			burst_timer = 0.0
		CrabPhase.PHASE_2:
			# Fire rockets
			_fire_rocket()
		CrabPhase.PHASE_3:
			# Fire rockets
			_fire_rocket()

func _fire_at_player() -> void:
	if not player_ref:
		return

	# Calculate direction to player
	var direction = (player_ref.global_position - global_position).normalized()

	# Spawn bullet
	var bullet_scene = preload("res://scenes/entities/sniper_bullet.tscn")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + direction * 50
	bullet.direction = direction
	bullet.damage = 1
	bullet.speed = 600.0  # Slower than sniper bullets
	get_tree().current_scene.add_child(bullet)

func _fire_rocket() -> void:
	if not player_ref:
		return

	# Calculate direction to player
	var direction = (player_ref.global_position - global_position).normalized()

	# Spawn rocket
	var rocket_scene = preload("res://scenes/entities/boss_rocket.tscn")
	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position + direction * 80
	rocket.rotation = direction.angle()
	rocket.damage = 2
	get_tree().current_scene.add_child(rocket)

func take_damage(amount: int) -> void:
	if is_dead or phase == CrabPhase.INTRO:
		return

	health -= amount
	EventBus.boss_damaged.emit(health, max_health)

	# Flash effect
	modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1, 1)

func _draw() -> void:
	# Draw main body (shell)
	var body_rect = Rect2(-body_width / 2, -body_height / 2, body_width, body_height)

	# Shell shape (rounded top)
	draw_rect(body_rect, body_color)

	# Shell segments
	for i in range(3):
		var segment_x = -body_width / 3 + i * body_width / 3
		draw_line(
			Vector2(segment_x, -body_height / 2),
			Vector2(segment_x, body_height / 3),
			Color(body_color * 0.7),
			3.0
		)

	# Eyes
	draw_circle(Vector2(-50, -30), 20, eye_color)
	draw_circle(Vector2(50, -30), 20, eye_color)
	draw_circle(Vector2(-50, -30), 8, Color.BLACK)
	draw_circle(Vector2(50, -30), 8, Color.BLACK)

	# Draw claws
	_draw_claw(-body_width / 2 - 50, body_height / 4, true)
	_draw_claw(body_width / 2 + 50, body_height / 4, false)

	# Draw phase indicator
	_draw_phase_indicator()

func _draw_claw(base_x: float, base_y: float, is_left: bool) -> void:
	var claw_x = base_x

	# Claw arm
	var arm_rect = Rect2(
		claw_x - 30 if is_left else claw_x,
		base_y - 20,
		60,
		40
	)
	draw_rect(arm_rect, claw_color)

	# Pincer
	var pincer_x = claw_x + (-50 if is_left else 50)
	var points_top = PackedVector2Array([
		Vector2(pincer_x, base_y - 30),
		Vector2(pincer_x + (-40 if is_left else 40), base_y - 10),
		Vector2(pincer_x, base_y)
	])
	var points_bottom = PackedVector2Array([
		Vector2(pincer_x, base_y),
		Vector2(pincer_x + (-40 if is_left else 40), base_y + 10),
		Vector2(pincer_x, base_y + 30)
	])
	draw_colored_polygon(points_top, claw_color)
	draw_colored_polygon(points_bottom, claw_color)

func _draw_phase_indicator() -> void:
	var phase_text = ""
	var phase_color = Color.WHITE
	match phase:
		CrabPhase.PHASE_1:
			phase_text = "PHASE 1"
			phase_color = Color.GREEN
		CrabPhase.PHASE_2:
			phase_text = "PHASE 2"
			phase_color = Color.YELLOW
		CrabPhase.PHASE_3:
			phase_text = "PHASE 3"
			phase_color = Color.RED

	if phase_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-40, -body_height / 2 - 20), phase_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, phase_color)
