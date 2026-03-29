extends Area2D
class_name AegisBit
## Orbiting shield unit that blocks projectiles for its host enemy

@export var orbit_radius: float = 60.0
@export var orbit_speed: float = 2.0  # Radians per second
@export var hits_to_destroy: int = 3
@export var host_path: NodePath = ""

var host: Node2D = null
var orbit_angle: float = 0.0
var current_hits: int = 0
var is_dead: bool = false

# Visual
var flash_timer: float = 0.0
var crack_level: int = 0  # 0, 1, 2 based on damage taken

# Reward
var reward: int = 20

# Sprite support (added for consistency with other enemies)
var anim_sprite: AnimatedSprite2D = null

# Frame mapping: 0-2 orbiting, 3-4 damage1, 5-6 damage2, 7-8 damaged/death
const FRAME_ORBIT = 0
const FRAME_DAMAGE_1 = 3
const FRAME_DAMAGE_2 = 5

func _ready() -> void:
	# Add to enemies group so rooms track it
	add_to_group("enemies")

	# Set collision layers
	collision_layer = 4    # Enemy layer
	collision_mask = 16    # Player projectiles only

	# Connect area entered signal
	area_entered.connect(_on_area_entered)

	# Get host from path if set
	if host_path:
		host = get_node_or_null(host_path)

	# Only randomize starting angle if not already set (e.g., by boss)
	if orbit_angle == 0.0:
		orbit_angle = randf() * TAU

	# Get reward from GameManager
	reward = GameManager.ENEMY_REWARDS.get("aegis_bit", 20)

	# Setup sprite if available
	anim_sprite = get_node_or_null("AnimatedSprite2D")

func set_host(new_host: Node2D) -> void:
	host = new_host

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	# Update flash timer
	if flash_timer > 0:
		flash_timer -= delta

	# Check if host is still valid
	if not is_instance_valid(host):
		_destroy()
		return

	# Check if host is dead
	if "is_dead" in host and host.is_dead:
		_destroy()
		return

	# Update orbit
	orbit_angle += orbit_speed * delta
	global_position = host.global_position + Vector2.from_angle(orbit_angle) * orbit_radius

	# Update sprite based on damage and rotation
	if anim_sprite:
		anim_sprite.rotation = orbit_angle + PI / 2  # Rotate with orbit
		if flash_timer > 0:
			anim_sprite.modulate = Color.WHITE
		else:
			anim_sprite.modulate = Color(1, 1, 1, 1)
		# Frame based on damage
		if crack_level >= 2:
			anim_sprite.frame = FRAME_DAMAGE_2
		elif crack_level >= 1:
			anim_sprite.frame = FRAME_DAMAGE_1
		else:
			anim_sprite.frame = FRAME_ORBIT

	queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	# Check if it's a player projectile
	if area.is_in_group("player_projectiles"):
		# Block the projectile
		area.queue_free()

		# Take damage
		current_hits += 1
		crack_level = current_hits
		flash_timer = 0.15

		# Emit damage signal
		EventBus.enemy_damaged.emit(self, hits_to_destroy - current_hits)

		# Check if destroyed
		if current_hits >= hits_to_destroy:
			_destroy()

func _destroy() -> void:
	if is_dead:
		return

	is_dead = true

	# Emit signals
	EventBus.aegis_bit_destroyed.emit(self, host)
	EventBus.enemy_killed.emit(self, reward, global_position)

	# Spawn particles
	_spawn_death_particles()

	queue_free()

func _spawn_death_particles() -> void:
	for i in range(6):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position + Vector2(
			randf_range(-15, 15),
			randf_range(-15, 15)
		)
		particle.color = Color(0.3, 0.8, 1.0)  # Cyan particles
		get_tree().current_scene.add_child(particle)

func _draw() -> void:
	var hex_radius = 30.0  # Doubled from 15

	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var base_color = Color(0.3, 0.8, 1.0)  # Cyan
		if flash_timer > 0:
			base_color = Color.WHITE

		# Draw hexagonal plate
		var hex_points = PackedVector2Array()
		for i in range(6):
			var angle = TAU * i / 6 - PI/6
			hex_points.append(Vector2.from_angle(angle) * hex_radius)

		draw_colored_polygon(hex_points, base_color)

		# Draw outline
		var outline_color = Color(0.5, 0.9, 1.0)
		for i in range(6):
			var start = hex_points[i]
			var end = hex_points[(i + 1) % 6]
			draw_line(start, end, outline_color, 2.0)

		# Draw crack indicators based on damage
		var crack_color = Color(0.1, 0.1, 0.2, 0.8)
		if crack_level >= 1:
			draw_line(Vector2(-10, -16), Vector2(6, 4), crack_color, 3.0)
		if crack_level >= 2:
			draw_line(Vector2(8, -12), Vector2(-4, 10), crack_color, 3.0)
			draw_line(Vector2(-16, 0), Vector2(0, 16), crack_color, 2.5)

		# Draw core
		draw_circle(Vector2.ZERO, 10, Color(0.8, 0.95, 1.0))

	# Draw glow effect (overlay - always draw)
	var glow_alpha = 0.3 + sin(orbit_angle * 3) * 0.1
	var glow_color = Color(0.3, 0.8, 1.0, glow_alpha)
	draw_circle(Vector2.ZERO, hex_radius + 10, glow_color)
