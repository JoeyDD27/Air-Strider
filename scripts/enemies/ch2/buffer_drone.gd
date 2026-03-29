extends EnemyBase
class_name BufferDrone
## Support enemy - shields nearby enemies with invincibility aura
## Counter: Bullets pass through shields to hit the drone - hunt drone first

@export var aura_radius: float = 200.0
@export var hover_height: float = 150.0
@export var drift_speed: float = 40.0

var affected_enemies: Array = []
var hover_offset: float = 0.0
var base_y: float = 0.0

var size: float = 30.0
var color: Color = Color(0.3, 0.8, 1.0)     # Cyan

# Frame mapping: 0-2 idle/hover, 3-4 shielding active, 5 projecting, 6-7 damaged, 8 death
const FRAME_IDLE = 0
const FRAME_HOVER = 1
const FRAME_SHIELDING = 3

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("buffer_drone", 35)
	base_y = global_position.y

	# Drone floats - no ground collision needed, only hit by player projectiles
	collision_mask = 16  # Only player projectiles
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	# Hover movement (bobbing up and down)
	hover_offset += delta * 2.0
	var hover_y = sin(hover_offset) * 15.0
	global_position.y = base_y + hover_y

	# Gentle drift toward player x position
	var diff_x = player_ref.global_position.x - global_position.x
	if abs(diff_x) > 50:
		global_position.x += sign(diff_x) * drift_speed * delta

	# Update aura effects on nearby enemies
	_update_aura()

	# Update sprite based on shielding status
	if anim_sprite:
		if affected_enemies.size() > 0:
			_set_sprite_frame(FRAME_SHIELDING)
		else:
			# Alternate between hover frames based on hover offset
			_set_sprite_frame(FRAME_IDLE if int(hover_offset) % 2 == 0 else FRAME_HOVER)

	queue_redraw()

func _update_aura() -> void:
	# First, remove shields from enemies that moved out of range
	for enemy in affected_enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = enemy.global_position.distance_to(global_position)
		if dist > aura_radius:
			enemy.is_shielded = false
			enemy.queue_redraw()
			EventBus.aura_shield_removed.emit(enemy)

	# Clean up invalid references
	affected_enemies = affected_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)

	# Find enemies in range and apply shield
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not enemy is EnemyBase:
			continue  # Skip non-EnemyBase entities (like AegisBit)
		if enemy is BufferDrone or enemy is AmpPylon:
			continue  # Don't shield other support enemies

		var dist = enemy.global_position.distance_to(global_position)
		if dist <= aura_radius:
			if not enemy in affected_enemies:
				affected_enemies.append(enemy)
				EventBus.aura_shield_applied.emit(enemy)
			enemy.is_shielded = true

func die() -> void:
	# Remove all shields when drone dies
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			enemy.is_shielded = false
			enemy.queue_redraw()
			EventBus.aura_shield_removed.emit(enemy)
	affected_enemies.clear()
	super.die()

func _draw() -> void:
	# Draw aura radius (overlay - always draw)
	var pulse = sin(Time.get_ticks_msec() * 0.003) * 0.1 + 0.15
	draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 64, Color(0.3, 0.8, 1.0, pulse), 2.0)

	# Draw aura fill (overlay - always draw)
	draw_circle(Vector2.ZERO, aura_radius, Color(0.3, 0.8, 1.0, 0.05))

	# Draw drone body only if no sprite (fallback)
	if not anim_sprite:
		var points = PackedVector2Array()
		points.append(Vector2(0, -size))
		points.append(Vector2(size * 0.6, 0))
		points.append(Vector2(0, size * 0.5))
		points.append(Vector2(-size * 0.6, 0))
		draw_colored_polygon(points, color)

		# Draw shield projector core (pulsing glow)
		var core_pulse = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		draw_circle(Vector2.ZERO, size * 0.3, Color(1, 1, 1, core_pulse))

		# Draw rotors/wings
		var rotor_angle = Time.get_ticks_msec() * 0.01
		for i in range(4):
			var angle = rotor_angle + i * PI / 2
			var rotor_pos = Vector2.from_angle(angle) * size * 0.5
			draw_circle(rotor_pos, 5, color * 0.7)

	# Draw connection lines to shielded enemies (overlay - always draw)
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			var to_enemy = enemy.global_position - global_position
			draw_line(Vector2.ZERO, to_enemy, Color(0.3, 0.8, 1.0, 0.3), 1.0)
