extends Node2D
class_name ApexInterceptor
## Chapter 3 Boss - The Apex-Interceptor (Unit 00)
## Three phases: Iron Curtain (Sword), Gravity Trap (Hook+Blade), Executioner (Cycle)

enum BossPhase { INTRO, IRON_CURTAIN, GRAVITY_TRAP, EXECUTIONER, DEFEATED }

@export var max_health: int = 20

var health: int
var phase: BossPhase = BossPhase.INTRO
var phase_timer: float = 0.0
var attack_timer: float = 0.0

# Player reference
var player_ref: Node2D = null

# Phase 1: Iron Curtain - Sword swing with red arc telegraph
var aegis_bits: Array = []
var sword_swing_cooldown: float = 0.0
var sword_swing_telegraph_timer: float = 0.0  # Telegraph before swing
var sword_swing_active: bool = false
var sword_swing_timer: float = 0.0  # Duration of swing animation
var sword_swing_angle: float = 0.0  # Angle to swing towards
var sword_arc_start: float = 0.0
var sword_arc_end: float = 0.0
var is_telegraphing_swing: bool = false

# Phase 2: Gravity Trap - Hook + quick blade combo every 2 seconds
var hook_cooldown: float = 0.0
var is_firing_hook: bool = false
var hook_projectile: Node2D = null
var quick_blade_active: bool = false
var quick_blade_timer: float = 0.0
var small_blade_angle: float = 0.0

# Phase 3: Executioner - Cycle between bullet spam and hook+hit
enum ExecutionerAttack { BULLET_SPAM, HOOK_COMBO, PAUSE }
var current_executioner_attack: ExecutionerAttack = ExecutionerAttack.BULLET_SPAM
var executioner_attack_timer: float = 0.0
var bullet_spam_timer: float = 0.0
var bullets_fired_in_spam: int = 0
var hook_combo_started: bool = false
var pause_timer: float = 0.0
var next_attack_after_pause: ExecutionerAttack = ExecutionerAttack.BULLET_SPAM

# Visual
var body_width: float = 80.0
var body_height: float = 120.0
var glow_intensity: float = 0.0
var damage_flash: float = 0.0

# Hitbox
var hitbox: Area2D = null

# Preloaded scenes
const BULLET_SCENE = preload("res://scenes/entities/ch3/tri_gunner_bullet.tscn")
const AEGIS_SCENE = preload("res://scenes/entities/ch3/aegis_bit.tscn")
const HARPOON_SCENE = preload("res://scenes/entities/ch3/harpoon_projectile.tscn")

# Helper function to get the shortest angle difference between two angles
func angle_difference(from_angle: float, to_angle: float) -> float:
	var diff = fmod(to_angle - from_angle + PI, TAU) - PI
	return diff

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")

	health = max_health

	# Create hitbox
	_setup_hitbox()

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

	# Start intro
	GameManager.current_state = GameManager.GameState.BOSS_INTRO

func _setup_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.collision_layer = 4  # Enemy
	hitbox.collision_mask = 16  # Player projectiles

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(body_width, body_height)
	shape.shape = rect
	hitbox.add_child(shape)

	hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_child(hitbox)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if phase == BossPhase.DEFEATED:
		return

	# Boss is always damageable, even with aegis bits active
	if area.is_in_group("player_projectiles"):
		_take_damage(1)
		area.queue_free()

func _has_active_aegis_bits() -> bool:
	aegis_bits = aegis_bits.filter(func(b): return is_instance_valid(b) and not b.is_dead)
	return not aegis_bits.is_empty()

func _take_damage(amount: int) -> void:
	if phase == BossPhase.DEFEATED:
		return

	health -= amount
	damage_flash = 0.2

	EventBus.boss_damaged.emit(health, max_health)
	EventBus.screen_shake.emit(8.0, 0.15)

	# Check phase transitions
	_check_phase_transition()

	if health <= 0:
		_enter_defeated()

func _check_phase_transition() -> void:
	var health_percent = float(health) / max_health

	match phase:
		BossPhase.IRON_CURTAIN:
			if health_percent <= 0.80:
				_enter_gravity_trap()
		BossPhase.GRAVITY_TRAP:
			if health_percent <= 0.50:
				_enter_executioner()

var is_dead: bool = false

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return
	# Update flash
	if damage_flash > 0:
		damage_flash -= delta

	match phase:
		BossPhase.INTRO:
			_phase_intro(delta)
		BossPhase.IRON_CURTAIN:
			_phase_iron_curtain(delta)
		BossPhase.GRAVITY_TRAP:
			_phase_gravity_trap(delta)
		BossPhase.EXECUTIONER:
			_phase_executioner(delta)
		BossPhase.DEFEATED:
			_phase_defeated(delta)

	queue_redraw()

# ============ INTRO ============
func _phase_intro(delta: float) -> void:
	phase_timer += delta

	# Rise into position
	if phase_timer < 2.0:
		glow_intensity = phase_timer / 2.0
	else:
		_enter_iron_curtain()

func _enter_iron_curtain() -> void:
	phase = BossPhase.IRON_CURTAIN
	phase_timer = 0.0
	GameManager.current_state = GameManager.GameState.PLAYING

	# Spawn 6 Aegis Bits
	for i in range(6):
		var bit = AEGIS_SCENE.instantiate()
		bit.orbit_angle = TAU * i / 6
		bit.orbit_radius = 80.0
		bit.set_host(self)
		get_tree().current_scene.add_child(bit)
		aegis_bits.append(bit)

	EventBus.boss_phase_changed.emit(1)

# ============ PHASE 1: IRON CURTAIN ============
func _phase_iron_curtain(delta: float) -> void:
	phase_timer += delta
	sword_swing_cooldown -= delta

	# Chase player directly (both X and Y)
	if player_ref:
		var target_pos = player_ref.global_position
		global_position.x = lerp(global_position.x, target_pos.x, delta * 0.9)
		global_position.y = lerp(global_position.y, target_pos.y, delta * 0.9)

	# Telegraph phase - show red arc before swinging
	if is_telegraphing_swing:
		sword_swing_telegraph_timer -= delta
		if sword_swing_telegraph_timer <= 0:
			# Execute the swing!
			is_telegraphing_swing = false
			sword_swing_active = true
			sword_swing_timer = 0.3  # Swing duration
			_execute_sword_swing_damage()

	# Swing animation
	if sword_swing_active:
		sword_swing_timer -= delta
		if sword_swing_timer <= 0:
			sword_swing_active = false
			sword_swing_cooldown = 2.0  # Cooldown between swings

	# Start new attack if ready
	if sword_swing_cooldown <= 0 and not is_telegraphing_swing and not sword_swing_active:
		_start_sword_swing_telegraph()

	# Update glow
	glow_intensity = 0.5 + sin(phase_timer * 3) * 0.2

func _start_sword_swing_telegraph() -> void:
	if not player_ref:
		return

	is_telegraphing_swing = true
	sword_swing_telegraph_timer = 0.8  # Time to show telegraph before swing

	# Calculate angle to player
	var to_player = player_ref.global_position - global_position
	sword_swing_angle = to_player.angle()

	# Define the arc (60 degree arc centered on player direction)
	sword_arc_start = sword_swing_angle - PI/6
	sword_arc_end = sword_swing_angle + PI/6

func _execute_sword_swing_damage() -> void:
	if not player_ref:
		return

	# Check if player is within the swing arc and range
	var to_player = player_ref.global_position - global_position
	var dist = to_player.length()
	var angle_to_player = to_player.angle()

	# Sword reach is 150 pixels
	if dist < 150:
		# Check if player angle is within the arc
		var angle_diff = abs(angle_difference(angle_to_player, sword_swing_angle))
		if angle_diff < PI/6:  # Within 30 degrees of swing direction
			player_ref.take_damage(2)
			EventBus.screen_shake.emit(15.0, 0.25)

# ============ PHASE 2: GRAVITY TRAP ============
func _enter_gravity_trap() -> void:
	phase = BossPhase.GRAVITY_TRAP
	phase_timer = 0.0
	hook_cooldown = 1.0  # Initial delay before first hook

	# Destroy remaining aegis bits (deferred to avoid physics callback issues)
	for bit in aegis_bits:
		if is_instance_valid(bit):
			bit.call_deferred("queue_free")
	aegis_bits.clear()

	EventBus.boss_phase_changed.emit(2)
	EventBus.screen_shake.emit(15.0, 0.3)

func _phase_gravity_trap(delta: float) -> void:
	phase_timer += delta
	hook_cooldown -= delta

	if not player_ref:
		return

	# Chase player directly (both X and Y)
	var target_pos = player_ref.global_position
	global_position.x = lerp(global_position.x, target_pos.x, delta * 1.2)
	global_position.y = lerp(global_position.y, target_pos.y, delta * 1.2)

	# Quick blade swing after hook hits
	if quick_blade_active:
		quick_blade_timer -= delta
		if quick_blade_timer <= 0:
			quick_blade_active = false
			hook_cooldown = 2.0  # 2 second cooldown between hook attempts

	# Track hook projectile
	if is_firing_hook:
		if not is_instance_valid(hook_projectile):
			# Hook expired/missed - reset
			is_firing_hook = false
			hook_cooldown = 2.0

	# Fire hook every 2 seconds if not already firing
	if hook_cooldown <= 0 and not is_firing_hook and not quick_blade_active:
		_fire_phase2_hook()

	# Glow orange during this phase
	glow_intensity = 0.6 + sin(phase_timer * 4) * 0.2

func _fire_phase2_hook() -> void:
	if not player_ref:
		return

	is_firing_hook = true

	# Fire harpoon at player
	var harpoon = HARPOON_SCENE.instantiate()
	var to_player = (player_ref.global_position - global_position).normalized()
	harpoon.global_position = global_position + to_player * 50
	harpoon.direction = to_player
	harpoon.speed = 1800.0
	harpoon.owner_stalker = self
	harpoon.pull_strength = 1200.0
	harpoon.damage = 1
	hook_projectile = harpoon
	get_tree().current_scene.add_child(harpoon)

func on_harpoon_hit() -> void:
	# Called when hook hits player - immediately swing small blade
	is_firing_hook = false
	hook_projectile = null
	_execute_quick_blade_swing()

func _execute_quick_blade_swing() -> void:
	quick_blade_active = true
	quick_blade_timer = 0.2  # Very quick swing

	# Calculate angle to player for the swing
	if player_ref:
		var to_player = player_ref.global_position - global_position
		small_blade_angle = to_player.angle()

		# Damage player - they just got hooked in, so they should be close
		var dist = to_player.length()
		if dist < 200:  # Generous range since they were just pulled
			player_ref.take_damage(2)
			EventBus.screen_shake.emit(12.0, 0.2)

# ============ PHASE 3: EXECUTIONER ============
func _enter_executioner() -> void:
	phase = BossPhase.EXECUTIONER
	phase_timer = 0.0
	current_executioner_attack = ExecutionerAttack.BULLET_SPAM
	executioner_attack_timer = 0.0
	bullet_spam_timer = 0.0
	bullets_fired_in_spam = 0
	hook_combo_started = false
	is_firing_hook = false
	quick_blade_active = false

	EventBus.boss_phase_changed.emit(3)
	EventBus.screen_shake.emit(20.0, 0.5)

func _phase_executioner(delta: float) -> void:
	phase_timer += delta
	executioner_attack_timer += delta

	if not player_ref:
		return

	# Chase player aggressively (both X and Y)
	var target_pos = player_ref.global_position
	global_position.x = lerp(global_position.x, target_pos.x, delta * 1.5)
	global_position.y = lerp(global_position.y, target_pos.y, delta * 1.5)

	# Glow red intensely
	glow_intensity = 0.9 + sin(phase_timer * 5) * 0.1

	match current_executioner_attack:
		ExecutionerAttack.BULLET_SPAM:
			_execute_bullet_spam_attack(delta)
		ExecutionerAttack.HOOK_COMBO:
			_execute_hook_combo_attack(delta)
		ExecutionerAttack.PAUSE:
			_execute_pause(delta)

func _execute_bullet_spam_attack(delta: float) -> void:
	# Fire 10 bullets over 3 seconds (like Tri-Gunner)
	bullet_spam_timer += delta

	# Fire at intervals: 10 bullets over 3 seconds = 1 bullet every 0.3 seconds
	var fire_interval = 0.3
	var expected_bullets = int(bullet_spam_timer / fire_interval)

	while bullets_fired_in_spam < expected_bullets and bullets_fired_in_spam < 10:
		_fire_spam_bullet()
		bullets_fired_in_spam += 1

	# After 3 seconds (10 bullets fired), pause then switch to hook combo
	if bullet_spam_timer >= 3.0:
		_start_pause(ExecutionerAttack.HOOK_COMBO)

func _fire_spam_bullet() -> void:
	if not player_ref:
		return

	var bullet = BULLET_SCENE.instantiate()

	# Aim at player with slight spread
	var to_player = (player_ref.global_position - global_position).normalized()
	var spread = randf_range(-0.1, 0.1)  # Small spread
	var fire_angle = to_player.angle() + spread

	bullet.global_position = global_position + Vector2.from_angle(fire_angle) * 50
	bullet.direction = Vector2.from_angle(fire_angle)
	bullet.speed = 1800.0
	get_tree().current_scene.add_child(bullet)

	EventBus.screen_shake.emit(2.0, 0.05)

func _execute_hook_combo_attack(delta: float) -> void:
	# Phase 2 style attack: hook + hit, ends immediately if hook misses

	# Quick blade swing after hook hits
	if quick_blade_active:
		quick_blade_timer -= delta
		if quick_blade_timer <= 0:
			quick_blade_active = false
			# Combo finished - switch back to bullet spam
			_switch_to_bullet_spam()
			return

	# Track hook projectile
	if is_firing_hook:
		if not is_instance_valid(hook_projectile):
			# Hook expired/missed - attack ends immediately, switch to bullet spam
			is_firing_hook = false
			_switch_to_bullet_spam()
			return

	# Start hook combo if not started
	if not hook_combo_started and not is_firing_hook and not quick_blade_active:
		hook_combo_started = true
		_fire_executioner_hook()

func _fire_executioner_hook() -> void:
	if not player_ref:
		_switch_to_bullet_spam()
		return

	is_firing_hook = true

	# Fire harpoon at player
	var harpoon = HARPOON_SCENE.instantiate()
	var to_player = (player_ref.global_position - global_position).normalized()
	harpoon.global_position = global_position + to_player * 50
	harpoon.direction = to_player
	harpoon.speed = 2000.0  # Faster in phase 3
	harpoon.owner_stalker = self
	harpoon.pull_strength = 1400.0
	harpoon.damage = 1
	hook_projectile = harpoon
	get_tree().current_scene.add_child(harpoon)

func _switch_to_bullet_spam() -> void:
	_start_pause(ExecutionerAttack.BULLET_SPAM)

func _start_pause(next_attack: ExecutionerAttack) -> void:
	current_executioner_attack = ExecutionerAttack.PAUSE
	pause_timer = 1.0  # 1 second pause between attacks
	next_attack_after_pause = next_attack
	executioner_attack_timer = 0.0

func _execute_pause(delta: float) -> void:
	pause_timer -= delta
	if pause_timer <= 0:
		# Resume with next attack
		current_executioner_attack = next_attack_after_pause
		executioner_attack_timer = 0.0
		if next_attack_after_pause == ExecutionerAttack.BULLET_SPAM:
			bullet_spam_timer = 0.0
			bullets_fired_in_spam = 0
		elif next_attack_after_pause == ExecutionerAttack.HOOK_COMBO:
			hook_combo_started = false
			is_firing_hook = false

# ============ DEFEATED ============
func _enter_defeated() -> void:
	phase = BossPhase.DEFEATED
	phase_timer = 0.0

	# Clean up aegis bits
	for bit in aegis_bits:
		if is_instance_valid(bit):
			bit.queue_free()
	aegis_bits.clear()

	# Clean up any active hook projectile
	if is_instance_valid(hook_projectile):
		hook_projectile.queue_free()
		hook_projectile = null

	EventBus.boss_defeated.emit()
	EventBus.interceptor_defeated.emit()
	EventBus.screen_shake.emit(25.0, 1.0)

func _phase_defeated(delta: float) -> void:
	phase_timer += delta
	glow_intensity = max(0, 1.0 - phase_timer)

	if phase_timer >= 2.0:
		# Award coins
		var reward = GameManager.ENEMY_REWARDS.get("apex_interceptor", 1000)
		EventBus.enemy_killed.emit(self, reward, global_position)
		EventBus.victory.emit()
		queue_free()

# ============ DRAWING ============
func _draw() -> void:
	# Damage flash
	var flash_color = Color.WHITE if damage_flash > 0 else Color(1, 1, 1, 0)

	match phase:
		BossPhase.INTRO:
			_draw_intro_form()
		BossPhase.IRON_CURTAIN:
			_draw_gunner_form()
		BossPhase.GRAVITY_TRAP:
			_draw_stalker_form()
		BossPhase.EXECUTIONER:
			_draw_blade_form()
		BossPhase.DEFEATED:
			_draw_defeated_form()

func _draw_intro_form() -> void:
	var alpha = glow_intensity
	var body_color = Color(0.3, 0.3, 0.4, alpha)
	_draw_base_body(body_color)

func _draw_gunner_form() -> void:
	var body_color = Color(0.3, 0.35, 0.5)
	if damage_flash > 0:
		body_color = Color.WHITE
	_draw_base_body(body_color)

	# Draw the large sword
	var sword_color = Color(0.6, 0.6, 0.7)
	var sword_glow = Color(0.8, 0.3, 0.3, 0.6)

	# Draw sword pointing toward swing direction or default up
	var sword_angle = sword_swing_angle if is_telegraphing_swing or sword_swing_active else -PI/2
	var sword_length = 120.0
	var sword_start = Vector2.ZERO
	var sword_end = sword_start + Vector2.from_angle(sword_angle) * sword_length

	draw_line(sword_start, sword_end, sword_color, 10.0)
	draw_line(sword_start, sword_end, sword_glow, 16.0)

	# Draw red arc telegraph before swing
	if is_telegraphing_swing:
		var telegraph_alpha = (0.8 - sword_swing_telegraph_timer) / 0.8 * 0.8
		var arc_color = Color(1.0, 0.2, 0.1, telegraph_alpha)
		var arc_radius = 140.0
		draw_arc(Vector2.ZERO, arc_radius, sword_arc_start, sword_arc_end, 16, arc_color, 8.0)

		# Fill the arc area
		var fill_color = Color(1.0, 0.1, 0.0, telegraph_alpha * 0.3)
		var arc_points = PackedVector2Array()
		arc_points.append(Vector2.ZERO)
		for i in range(17):
			var angle = sword_arc_start + (sword_arc_end - sword_arc_start) * i / 16.0
			arc_points.append(Vector2.from_angle(angle) * arc_radius)
		draw_colored_polygon(arc_points, fill_color)

	# Draw swing effect
	if sword_swing_active:
		var swing_progress = 1.0 - sword_swing_timer / 0.3
		var swing_alpha = 1.0 - swing_progress
		var swing_color = Color(1.0, 0.5, 0.2, swing_alpha)
		draw_arc(Vector2.ZERO, 140.0, sword_arc_start, sword_arc_end, 16, swing_color, 12.0)

	# Draw glow
	var glow_color = Color(0.3, 0.5, 1.0, glow_intensity * 0.3)
	draw_circle(Vector2.ZERO, body_width, glow_color)

func _draw_stalker_form() -> void:
	var body_color = Color(0.4, 0.3, 0.35)
	if damage_flash > 0:
		body_color = Color.WHITE
	_draw_base_body(body_color)

	# Draw hook launcher on left arm
	var hook_color = Color(0.5, 0.5, 0.6)
	draw_line(Vector2(-body_width/2, 0), Vector2(-body_width/2 - 40, 0), hook_color, 8.0)
	draw_circle(Vector2(-body_width/2 - 40, 0), 6, hook_color)

	# Draw small blade on right arm
	var blade_color = Color(0.7, 0.4, 0.3)
	var blade_angle = small_blade_angle if quick_blade_active else PI/4
	var blade_start = Vector2(body_width/2, 0)
	var blade_end = blade_start + Vector2.from_angle(blade_angle) * 60
	draw_line(blade_start, blade_end, blade_color, 6.0)

	# Draw quick blade swing effect
	if quick_blade_active:
		var swing_alpha = quick_blade_timer / 0.2
		var swing_color = Color(1.0, 0.6, 0.3, swing_alpha)
		draw_arc(Vector2(body_width/2, 0), 60, small_blade_angle - PI/4, small_blade_angle + PI/4, 12, swing_color, 10.0)

	# Draw hook line if firing
	if is_firing_hook and is_instance_valid(hook_projectile):
		var line_color = Color(0.6, 0.6, 0.7, 0.8)
		var hook_pos = hook_projectile.global_position - global_position
		draw_line(Vector2(-body_width/2 - 40, 0), hook_pos, line_color, 3.0)

	# Glow
	var glow_color = Color(1.0, 0.5, 0.2, glow_intensity * 0.4)
	draw_circle(Vector2.ZERO, body_width * 0.8, glow_color)

func _draw_blade_form() -> void:
	var body_color = Color(0.5, 0.2, 0.2)
	if damage_flash > 0:
		body_color = Color.WHITE
	_draw_base_body(body_color)

	# Draw attack indicator based on current attack type
	match current_executioner_attack:
		ExecutionerAttack.BULLET_SPAM:
			# Draw gun barrels for bullet spam
			var gun_color = Color(0.6, 0.3, 0.3)
			if player_ref:
				var to_player = (player_ref.global_position - global_position).normalized()
				var barrel_end = to_player * 60
				draw_line(Vector2.ZERO, barrel_end, gun_color, 8.0)
				draw_circle(barrel_end, 5, Color(1.0, 0.5, 0.2))

			# Muzzle flash effect during firing
			if bullets_fired_in_spam > 0 and bullet_spam_timer < 3.0:
				var flash_alpha = 0.5 + sin(bullet_spam_timer * 20) * 0.5
				draw_circle(Vector2.ZERO, 30, Color(1.0, 0.6, 0.2, flash_alpha * 0.3))

		ExecutionerAttack.HOOK_COMBO:
			# Draw hook launcher and small blade (like phase 2)
			var hook_color = Color(0.5, 0.5, 0.6)
			draw_line(Vector2(-body_width/2, 0), Vector2(-body_width/2 - 40, 0), hook_color, 8.0)
			draw_circle(Vector2(-body_width/2 - 40, 0), 6, hook_color)

			var blade_color = Color(0.9, 0.4, 0.3)
			var blade_angle = small_blade_angle if quick_blade_active else PI/4
			var blade_start = Vector2(body_width/2, 0)
			var blade_end = blade_start + Vector2.from_angle(blade_angle) * 60
			draw_line(blade_start, blade_end, blade_color, 6.0)

			# Quick blade swing effect
			if quick_blade_active:
				var swing_alpha = quick_blade_timer / 0.2
				var swing_color = Color(1.0, 0.6, 0.3, swing_alpha)
				draw_arc(Vector2(body_width/2, 0), 60, small_blade_angle - PI/4, small_blade_angle + PI/4, 12, swing_color, 10.0)

			# Hook line
			if is_firing_hook and is_instance_valid(hook_projectile):
				var line_color = Color(0.6, 0.6, 0.7, 0.8)
				var hook_pos = hook_projectile.global_position - global_position
				draw_line(Vector2(-body_width/2 - 40, 0), hook_pos, line_color, 3.0)

	# Intense red glow
	var glow_color = Color(1.0, 0.1, 0.0, glow_intensity * 0.5)
	draw_circle(Vector2.ZERO, body_width * 1.2, glow_color)

func _draw_defeated_form() -> void:
	var alpha = max(0, 1.0 - phase_timer / 2.0)
	var body_color = Color(0.5, 0.3, 0.3, alpha)
	_draw_base_body(body_color)

	# Explosion particles effect
	for i in range(8):
		var angle = TAU * i / 8 + phase_timer * 2
		var dist = phase_timer * 100
		var particle_pos = Vector2.from_angle(angle) * dist
		var particle_alpha = max(0, 1.0 - phase_timer)
		draw_circle(particle_pos, 10, Color(1.0, 0.5, 0.2, particle_alpha))

func _draw_base_body(color: Color) -> void:
	# Main body (humanoid mech)
	var body_points = PackedVector2Array([
		Vector2(-body_width/2, body_height/2),     # Bottom left
		Vector2(-body_width/2, -body_height/4),    # Left waist
		Vector2(-body_width/3, -body_height/2),    # Left shoulder
		Vector2(0, -body_height/2 - 20),           # Head
		Vector2(body_width/3, -body_height/2),     # Right shoulder
		Vector2(body_width/2, -body_height/4),     # Right waist
		Vector2(body_width/2, body_height/2),      # Bottom right
	])
	draw_colored_polygon(body_points, color)

	# Draw eye/visor
	var eye_color = Color(1.0, 0.3, 0.3) if phase != BossPhase.INTRO else Color(0.5, 0.5, 0.5)
	draw_rect(Rect2(-15, -body_height/2 - 5, 30, 10), eye_color)
