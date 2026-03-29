extends EnemyBase
class_name ZoneBlade
## Territory denial melee samurai - guards a position and attacks when triggered

enum BladeState { GUARDING, TRIGGERED, PURSUING, SLASH_TELEGRAPH, SLASHING, RECALL, HEALING }

# Guard post position (set in scene or via code)
@export var guard_post: Vector2 = Vector2.ZERO
@export var trigger_radius: float = 240.0  # ~15 meters
@export var pursuit_speed: float = 400.0
@export var aggro_duration: float = 3.0
@export var slash_damage: int = 2
@export var slash_range: float = 60.0
@export var slash_width: float = 80.0

# State tracking
var state: BladeState = BladeState.GUARDING
var state_timer: float = 0.0
var aggro_timer: float = 0.0
var slash_hitbox_active: bool = false

# Visual
var katana_angle: float = 0.0
var katana_glow: float = 0.0
var recall_particles: Array = []

# Size
var body_width: float = 30.0
var body_height: float = 60.0

# Frame mapping: 0-2 guarding, 3-4 triggered/pursuing, 5 slashing, 6-7 recall/healing, 8 death
const FRAME_GUARDING = 0
const FRAME_TRIGGERED = 3
const FRAME_PURSUING = 4
const FRAME_SLASHING = 5
const FRAME_RECALL = 6
const FRAME_HEALING = 7

func _ready() -> void:
	super._ready()
	max_health = 3
	health = max_health
	reward = GameManager.ENEMY_REWARDS.get("zone_blade", 45)

	# Store initial position as guard post if not set
	if guard_post == Vector2.ZERO:
		guard_post = global_position
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 600 * delta
	else:
		velocity.y = 0

	# State machine
	match state:
		BladeState.GUARDING:
			_state_guarding(delta)
		BladeState.TRIGGERED:
			_state_triggered(delta)
		BladeState.PURSUING:
			_state_pursuing(delta)
		BladeState.SLASH_TELEGRAPH:
			_state_slash_telegraph(delta)
		BladeState.SLASHING:
			_state_slashing(delta)
		BladeState.RECALL:
			_state_recall(delta)
		BladeState.HEALING:
			_state_healing(delta)

	move_and_slide()

	# Update sprite based on state
	if anim_sprite:
		if velocity.x != 0:
			anim_sprite.flip_h = (velocity.x < 0)
		match state:
			BladeState.GUARDING:
				_set_sprite_frame(FRAME_GUARDING)
			BladeState.TRIGGERED:
				_set_sprite_frame(FRAME_TRIGGERED)
			BladeState.PURSUING, BladeState.SLASH_TELEGRAPH:
				_set_sprite_frame(FRAME_PURSUING)
			BladeState.SLASHING:
				_set_sprite_frame(FRAME_SLASHING)
			BladeState.RECALL:
				_set_sprite_frame(FRAME_RECALL)
			BladeState.HEALING:
				_set_sprite_frame(FRAME_HEALING)

	queue_redraw()

func _state_guarding(_delta: float) -> void:
	velocity.x = 0
	katana_angle = lerp(katana_angle, -PI / 4, 0.1)  # Resting position

	if not player_ref:
		return

	var dist_to_player = global_position.distance_to(player_ref.global_position)

	# Check trigger conditions
	if dist_to_player < trigger_radius:
		_enter_triggered()

func _enter_triggered() -> void:
	state = BladeState.TRIGGERED
	state_timer = 0.0
	aggro_timer = 0.0
	EventBus.zone_blade_triggered.emit(self, guard_post)
	EventBus.screen_shake.emit(5.0, 0.2)

func _state_triggered(delta: float) -> void:
	state_timer += delta / cooldown_multiplier
	katana_glow = min(katana_glow + delta * 5, 1.0)

	# Brief telegraph before pursuit
	if state_timer >= 0.3:
		state = BladeState.PURSUING
		state_timer = 0.0

func _state_pursuing(delta: float) -> void:
	aggro_timer += delta

	if not player_ref:
		_enter_recall()
		return

	# Move toward player
	var to_player = player_ref.global_position - global_position
	var dir_x = sign(to_player.x)
	velocity.x = dir_x * pursuit_speed

	# Jump if player is above
	if to_player.y < -100 and is_on_floor():
		velocity.y = -500

	# Check if close enough to slash
	var dist_to_player = global_position.distance_to(player_ref.global_position)
	if dist_to_player < slash_range:
		_enter_slash_telegraph()
		return

	# Force recall after aggro duration
	if aggro_timer >= aggro_duration:
		_enter_recall()

	# Update katana angle toward player
	katana_angle = lerp_angle(katana_angle, to_player.angle(), 0.2)

func _enter_slash_telegraph() -> void:
	state = BladeState.SLASH_TELEGRAPH
	state_timer = 0.0
	velocity.x = 0

func _state_slash_telegraph(delta: float) -> void:
	state_timer += delta / cooldown_multiplier

	# Wind up animation - raise katana
	katana_angle = lerp_angle(katana_angle, -PI * 0.75, 0.3)
	katana_glow = 1.0

	if state_timer >= 0.2:
		_execute_slash()

func _execute_slash() -> void:
	state = BladeState.SLASHING
	state_timer = 0.0
	slash_hitbox_active = true

	# Screen shake on slash
	EventBus.screen_shake.emit(8.0, 0.15)

	# Check for player hit
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < slash_range + 20:
			player_ref.take_damage(slash_damage)

func _state_slashing(delta: float) -> void:
	state_timer += delta

	# Swing animation
	katana_angle = lerp_angle(katana_angle, PI * 0.5, 0.5)

	if state_timer >= 0.3:
		slash_hitbox_active = false
		_enter_recall()

func _enter_recall() -> void:
	state = BladeState.RECALL
	state_timer = 0.0
	velocity = Vector2.ZERO

	# Spawn recall particles at current position
	_spawn_recall_particles()

	EventBus.zone_blade_recalled.emit(self)

func _spawn_recall_particles() -> void:
	for i in range(8):
		recall_particles.append({
			"pos": global_position + Vector2(randf_range(-20, 20), randf_range(-30, 30)),
			"vel": Vector2(randf_range(-100, 100), randf_range(-150, -50)),
			"life": 0.5
		})

func _state_recall(delta: float) -> void:
	state_timer += delta

	# Update particles
	for p in recall_particles:
		p.pos += p.vel * delta
		p.vel.y += 200 * delta
		p.life -= delta
	recall_particles = recall_particles.filter(func(p): return p.life > 0)

	# Teleport back to guard post
	if state_timer >= 0.3:
		global_position = guard_post
		state = BladeState.HEALING
		state_timer = 0.0

func _state_healing(delta: float) -> void:
	state_timer += delta
	katana_glow = max(katana_glow - delta * 2, 0.0)

	# Heal to full
	health = max_health

	if state_timer >= 0.5:
		state = BladeState.GUARDING
		state_timer = 0.0
		aggro_timer = 0.0

func _draw() -> void:
	# Determine colors based on state
	var accent_color = Color(0.2, 0.8, 1.0)  # Cyan energy

	if state in [BladeState.TRIGGERED, BladeState.PURSUING, BladeState.SLASH_TELEGRAPH, BladeState.SLASHING]:
		accent_color = Color(1.0, 0.3, 0.3)  # Red glow

	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var body_color = Color(0.3, 0.3, 0.4)  # Dark metallic

		if state in [BladeState.TRIGGERED, BladeState.PURSUING, BladeState.SLASH_TELEGRAPH, BladeState.SLASHING]:
			body_color = Color(0.5, 0.2, 0.2)  # Red tint when aggressive

		if is_shielded:
			body_color = Color(0.3, 0.8, 1.0, 0.8)  # Cyan when buffer-shielded

		var body_points = PackedVector2Array([
			Vector2(-body_width/2, body_height/2),
			Vector2(-body_width/2, -body_height/4),
			Vector2(-body_width/4, -body_height/2),
			Vector2(0, -body_height/2 - 10),
			Vector2(body_width/4, -body_height/2),
			Vector2(body_width/2, -body_height/4),
			Vector2(body_width/2, body_height/2),
		])
		draw_colored_polygon(body_points, body_color)

		# Draw helmet visor
		var visor_color = accent_color
		visor_color.a = 0.5 + katana_glow * 0.5
		draw_rect(Rect2(-10, -body_height/2 + 5, 20, 8), visor_color)

		# Draw katana
		var katana_origin = Vector2(body_width/4, -body_height/4)
		var katana_length = 50.0
		var katana_end = katana_origin + Vector2.from_angle(katana_angle) * katana_length

		var blade_color = Color(0.9, 0.95, 1.0)
		if katana_glow > 0:
			blade_color = blade_color.lerp(accent_color, katana_glow)
		draw_line(katana_origin, katana_end, blade_color, 3.0)

		if katana_glow > 0:
			var glow_color = accent_color
			glow_color.a = katana_glow * 0.5
			draw_line(katana_origin, katana_end, glow_color, 8.0)

	# Draw slash arc when attacking (overlay - always draw)
	if state == BladeState.SLASHING and slash_hitbox_active:
		var slash_color = Color(1.0, 0.5, 0.3, 0.6)
		draw_arc(Vector2.ZERO, slash_range, -PI/2, PI/2, 16, slash_color, 4.0)

	# Draw recall particles (overlay - always draw)
	for p in recall_particles:
		var local_pos = p.pos - global_position
		var alpha = p.life / 0.5
		draw_circle(local_pos, 4, Color(accent_color.r, accent_color.g, accent_color.b, alpha))

	# Draw trigger radius indicator when guarding (overlay - always draw)
	if state == BladeState.GUARDING:
		var radius_color = Color(1.0, 0.3, 0.3, 0.1)
		draw_arc(Vector2.ZERO, trigger_radius, 0, TAU, 32, radius_color, 1.0)

	# Shield visual (overlay - always draw)
	if is_shielded:
		draw_arc(Vector2.ZERO, body_width + 15, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.5), 3.0)
