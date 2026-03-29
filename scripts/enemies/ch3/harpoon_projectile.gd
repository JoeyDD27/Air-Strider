extends Area2D
class_name HarpoonProjectile
## Harpoon hook that pulls player toward the stalker on hit

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1600.0
var damage: int = 1
var pull_strength: float = 1200.0
var lifetime: float = 2.0

var owner_stalker: Node2D = null
var age: float = 0.0

func _ready() -> void:
	# Set collision layers
	collision_layer = 8   # Projectiles (layer 4)
	collision_mask = 1    # Player only (no platforms - hooks pass through islands)

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Set rotation to match direction
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# Move harpoon
	global_position += direction * speed * delta

	# Age and destroy
	age += delta
	if age >= lifetime:
		_notify_stalker_miss()
		queue_free()

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hit_player(body)
	# Hooks no longer blocked by platforms - they pass through islands

func _hit_player(player: Node2D) -> void:
	# Deal damage (respects invincibility)
	if player.has_method("take_damage"):
		player.take_damage(damage)

	# ALWAYS apply pull impulse - even during invincibility!
	# This is intentional - displacement is the real threat
	if is_instance_valid(owner_stalker):
		var pull_dir = (owner_stalker.global_position - player.global_position).normalized()
		player.velocity += pull_dir * pull_strength

		# Emit signal for effects/feedback
		EventBus.player_pulled.emit(pull_dir, pull_strength)

		# Notify stalker
		if owner_stalker.has_method("on_harpoon_hit"):
			owner_stalker.on_harpoon_hit()

	# Screen shake on hit
	EventBus.screen_shake.emit(12.0, 0.2)

	queue_free()

func _notify_stalker_miss() -> void:
	if is_instance_valid(owner_stalker) and owner_stalker.has_method("on_harpoon_hit"):
		# Stalker will handle state transition
		pass  # The stalker tracks our validity and handles miss

func _draw() -> void:
	# Draw harpoon head (arrow shape)
	var head_points = PackedVector2Array([
		Vector2(15, 0),    # Tip
		Vector2(-5, -8),   # Upper barb
		Vector2(0, 0),     # Center notch
		Vector2(-5, 8),    # Lower barb
	])
	draw_colored_polygon(head_points, Color(0.7, 0.7, 0.8))

	# Draw shaft
	draw_line(Vector2(-5, 0), Vector2(-25, 0), Color(0.5, 0.4, 0.3), 4.0)

	# Draw glow effect
	var glow_color = Color(0.8, 0.3, 0.3, 0.4)
	draw_circle(Vector2(10, 0), 12, glow_color)
