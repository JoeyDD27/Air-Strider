extends EnemyBase
class_name MedicDrone
## Healing support drone - attaches green tether to an enemy, granting +3 bonus HP
## When drone dies, all bonus health is instantly removed from target

enum MedicState { SEEKING_TARGET, TETHERED, REPOSITIONING }

# Frame mapping: 0-2 idle/seeking, 3-4 tethering, 5 tethered/healing, 6-7 damaged, 8 death
const FRAME_SEEKING = 0
const FRAME_TETHERING = 3
const FRAME_TETHERED = 5

@export var tether_range: float = 300.0
@export var bonus_hp_amount: int = 3
@export var drift_speed: float = 60.0
@export var orbit_distance: float = 80.0

var state: MedicState = MedicState.SEEKING_TARGET
var tethered_target: Node = null
var hover_offset: float = 0.0
var base_y: float = 0.0
var orbit_angle: float = 0.0

var size: float = 20.0
var color: Color = Color(0.3, 0.9, 0.4)  # Green

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("medic_drone", 40)
	base_y = global_position.y
	_setup_sprite()

	# Drone floats - no ground collision
	collision_mask = 16  # Only player projectiles

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	hover_offset += delta * 2.5
	orbit_angle += delta * 1.5

	match state:
		MedicState.SEEKING_TARGET:
			_state_seeking(delta)
		MedicState.TETHERED:
			_state_tethered(delta)
		MedicState.REPOSITIONING:
			_state_repositioning(delta)

	# Update sprite
	if anim_sprite:
		match state:
			MedicState.SEEKING_TARGET:
				_set_sprite_frame(FRAME_SEEKING)
			MedicState.TETHERED:
				_set_sprite_frame(FRAME_TETHERED)
			MedicState.REPOSITIONING:
				_set_sprite_frame(FRAME_TETHERING)

	queue_redraw()

func _state_seeking(delta: float) -> void:
	# Hover in place
	global_position.y = base_y + sin(hover_offset) * 10.0

	# Drift toward player to find targets near combat
	if player_ref:
		var diff_x = player_ref.global_position.x - global_position.x
		if abs(diff_x) > 100:
			global_position.x += sign(diff_x) * drift_speed * 0.5 * delta

	# Look for a valid target to tether
	var target = _find_best_target()
	if target:
		_attach_tether(target)
		state = MedicState.TETHERED

func _state_tethered(delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(tethered_target) or tethered_target.is_dead:
		_detach_tether()
		state = MedicState.SEEKING_TARGET
		return

	# Orbit around the tethered target
	var orbit_pos = tethered_target.global_position + Vector2.from_angle(orbit_angle) * orbit_distance
	orbit_pos.y -= 30  # Float above target

	# Smoothly move to orbit position
	global_position = global_position.lerp(orbit_pos, delta * 3.0)

	# Add slight bob
	global_position.y += sin(hover_offset) * 5.0

func _state_repositioning(delta: float) -> void:
	# Transition state - not currently used but available for future mechanics
	state = MedicState.SEEKING_TARGET

func _find_best_target() -> Node:
	## Find the best enemy to tether (nearest that doesn't already have bonus health)
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node = null
	var best_dist: float = tether_range

	for enemy in all_enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not enemy is EnemyBase:
			continue
		# Skip other support drones
		if enemy is MedicDrone or enemy is BufferDrone:
			continue
		# Skip enemies that already have bonus health
		if enemy.bonus_health > 0:
			continue
		# Skip dead enemies
		if enemy.is_dead:
			continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = enemy

	return best_target

func _attach_tether(target: Node) -> void:
	tethered_target = target
	target.bonus_health = bonus_hp_amount
	target.bonus_health_source = self
	EventBus.medic_tether_attached.emit(self, target)

func _detach_tether() -> void:
	if is_instance_valid(tethered_target):
		tethered_target.bonus_health = 0
		tethered_target.bonus_health_source = null
		EventBus.medic_tether_broken.emit(self, tethered_target)
		EventBus.bonus_health_removed.emit(tethered_target)
	tethered_target = null

func die() -> void:
	# Remove all bonus health when drone dies
	_detach_tether()
	super.die()

func _draw() -> void:
	# Draw tether beam if attached (always visible)
	if state == MedicState.TETHERED and is_instance_valid(tethered_target):
		var to_target = tethered_target.global_position - global_position

		# Pulsing tether beam
		var pulse = sin(Time.get_ticks_msec() * 0.008) * 0.3 + 0.7
		var tether_color = Color(0.3, 0.9, 0.4, pulse)

		# Main beam
		draw_line(Vector2.ZERO, to_target, tether_color, 3.0)

		# Energy particles along beam
		var particle_count = 5
		for i in range(particle_count):
			var t = fmod(float(i) / particle_count + Time.get_ticks_msec() * 0.001, 1.0)
			var particle_pos = to_target * t
			draw_circle(particle_pos, 3, Color(0.5, 1.0, 0.6, pulse))

		# Draw bonus health indicator on target
		var indicator_pos = to_target + Vector2(0, -40)
		for i in range(bonus_hp_amount):
			var heart_x = indicator_pos.x + (i - 1) * 12
			draw_circle(Vector2(heart_x, indicator_pos.y), 5, Color(0.3, 0.9, 0.4, 0.8))

	if not anim_sprite:
		# Draw drone body (small rounded shape)
		draw_circle(Vector2.ZERO, size, color)

		# Draw medical cross
		var cross_color = Color.WHITE
		var cross_width = 4.0
		var cross_length = size * 0.6
		draw_line(Vector2(-cross_length/2, 0), Vector2(cross_length/2, 0), cross_color, cross_width)
		draw_line(Vector2(0, -cross_length/2), Vector2(0, cross_length/2), cross_color, cross_width)

		# Draw rotors
		var rotor_angle = Time.get_ticks_msec() * 0.015
		for i in range(4):
			var angle = rotor_angle + i * PI / 2
			var rotor_pos = Vector2.from_angle(angle) * (size + 8)
			draw_circle(rotor_pos, 4, color * 0.7)

		# State indicator
		var indicator_color = Color.GRAY
		match state:
			MedicState.SEEKING_TARGET:
				indicator_color = Color(0.8, 0.8, 0.3)  # Yellow - searching
			MedicState.TETHERED:
				indicator_color = Color(0.3, 0.9, 0.4)  # Green - healing
			MedicState.REPOSITIONING:
				indicator_color = Color(0.5, 0.5, 0.5)  # Gray

		draw_circle(Vector2(0, size + 10), 3, indicator_color)

	# Draw healing glow (always visible)
	var glow_pulse = sin(Time.get_ticks_msec() * 0.006) * 0.2 + 0.3
	draw_circle(Vector2.ZERO, size + 5, Color(0.3, 0.9, 0.4, glow_pulse))
