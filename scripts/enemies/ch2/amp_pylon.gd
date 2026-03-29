extends EnemyBase
class_name AmpPylon
## Support enemy - reduces cooldowns of nearby enemies by 25%
## Counter: Destroy to slow down the room

@export var aura_radius: float = 250.0
@export var cooldown_reduction: float = 0.75  # 75% of normal cooldown = 25% faster

var affected_enemies: Array = []

var size: float = 40.0
var color: Color = Color(1.0, 0.6, 0.2)     # Orange

# Frame mapping: 0-2 idle, 3-4 active/pulsing, 5 overcharge, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_ACTIVE = 3
const FRAME_OVERCHARGE = 5

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("amp_pylon", 40)

	# Pylon is stationary, collides with platforms and hit by player projectiles
	collision_mask = 2 | 16  # Platform layer (2) + Player projectiles layer (16)
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity (pylon sits on ground)
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0

	move_and_slide()

	_update_aura()

	# Update sprite based on affected enemies
	if anim_sprite:
		if affected_enemies.size() >= 3:
			_set_sprite_frame(FRAME_OVERCHARGE)
		elif affected_enemies.size() > 0:
			_set_sprite_frame(FRAME_ACTIVE)
		else:
			_set_sprite_frame(FRAME_IDLE)

	queue_redraw()

func _update_aura() -> void:
	# First, remove amp effect from enemies that moved out of range
	for enemy in affected_enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = enemy.global_position.distance_to(global_position)
		if dist > aura_radius:
			if "cooldown_multiplier" in enemy:
				enemy.cooldown_multiplier = 1.0
			EventBus.aura_amp_removed.emit(enemy)

	# Clean up invalid references
	affected_enemies = affected_enemies.filter(func(e): return is_instance_valid(e) and (not "is_dead" in e or not e.is_dead))

	# Apply amp to enemies in range
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy is AmpPylon or enemy is BufferDrone:
			continue  # Don't amp support enemies

		var dist = enemy.global_position.distance_to(global_position)
		if dist <= aura_radius:
			if not enemy in affected_enemies:
				affected_enemies.append(enemy)
				EventBus.aura_amp_applied.emit(enemy)
			if "cooldown_multiplier" in enemy:
				enemy.cooldown_multiplier = cooldown_reduction

func die() -> void:
	# Remove amp from all enemies when pylon dies
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			if "cooldown_multiplier" in enemy:
				enemy.cooldown_multiplier = 1.0
			EventBus.aura_amp_removed.emit(enemy)
	affected_enemies.clear()
	super.die()

func _draw() -> void:
	# Draw aura radius with pulsing waves (overlay - always draw)
	var wave_time = Time.get_ticks_msec() * 0.002
	for i in range(3):
		var wave_radius = fmod(wave_time + i * 0.33, 1.0) * aura_radius
		var wave_alpha = 0.3 * (1.0 - wave_radius / aura_radius)
		draw_arc(Vector2.ZERO, wave_radius, 0, TAU, 32, Color(1.0, 0.6, 0.2, wave_alpha), 2.0)

	# Draw aura fill (overlay - always draw)
	draw_circle(Vector2.ZERO, aura_radius, Color(1.0, 0.6, 0.2, 0.03))

	# Draw pylon body only if no sprite (fallback)
	if not anim_sprite:
		var rect = Rect2(-size * 0.3, -size, size * 0.6, size * 1.5)
		draw_rect(rect, color)

		# Draw base
		draw_rect(Rect2(-size * 0.4, size * 0.3, size * 0.8, size * 0.2), color * 0.7)

		# Draw energy core (pulsing)
		var pulse = sin(Time.get_ticks_msec() * 0.008) * 0.3 + 0.7
		draw_circle(Vector2(0, -size * 0.3), size * 0.25, Color(1, 0.8, 0.3, pulse))

		# Draw lightning bolts from core
		for i in range(4):
			var angle = i * PI / 2 + Time.get_ticks_msec() * 0.003
			var bolt_end = Vector2.from_angle(angle) * size * 0.5
			_draw_mini_bolt(Vector2(0, -size * 0.3), Vector2(0, -size * 0.3) + bolt_end)

	# Draw connection indicators to affected enemies (overlay - always draw)
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			var to_enemy = enemy.global_position - global_position
			var dir = to_enemy.normalized()
			draw_line(dir * size * 0.4, dir * min(to_enemy.length(), aura_radius * 0.3), Color(1.0, 0.6, 0.2, 0.4), 1.5)

func _draw_mini_bolt(start: Vector2, end: Vector2) -> void:
	var mid = start.lerp(end, 0.5) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	draw_line(start, mid, Color(1, 0.8, 0.3, 0.8), 1.5)
	draw_line(mid, end, Color(1, 0.8, 0.3, 0.8), 1.5)
