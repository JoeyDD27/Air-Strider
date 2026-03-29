extends EnemyBase
class_name Mortar
## Mortar enemy - fires explosive shells in arcs at player's platform

@export var fire_rate: float = 0.5  # Shots per second (fires once per 2 seconds)
@export var arc_height: float = 300.0
@export var explosion_radius: float = 80.0

var fire_timer: float = 0.0
var size: float = 40.0
var color: Color = Color(0.8, 0.133, 0.133)  # Red
var barrel_color: Color = Color(0.533, 0.133, 0.133)  # Darker red

# Frame mapping: 0-2 idle, 3-4 charging, 5 firing, 6-7 reload, 8 death
const FRAME_IDLE = 0
const FRAME_ELEVATING = 2
const FRAME_FIRING = 5
const FRAME_RELOAD = 6

func _ready() -> void:
	super._ready()
	reward = GameManager.ENEMY_REWARDS.get("mortar", 40)
	fire_timer = randf_range(0, 1.0 / fire_rate)  # Randomize initial fire time
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if should_ignore_player():
		return

	fire_timer += delta

	if fire_timer >= 1.0 / fire_rate:
		fire_timer = 0.0
		fire_at_player()

	# Update sprite based on reload progress
	if anim_sprite:
		var reload_percent = fire_timer / (1.0 / fire_rate)
		if reload_percent < 0.2:
			_set_sprite_frame(FRAME_FIRING)  # Just fired
		elif reload_percent < 0.8:
			_set_sprite_frame(FRAME_RELOAD)  # Reloading
		else:
			_set_sprite_frame(FRAME_ELEVATING)  # Ready to fire

	queue_redraw()

func fire_at_player() -> void:
	var target_pos = get_player_position()

	# Calculate arc trajectory
	var dx = target_pos.x - global_position.x
	var dy = target_pos.y - global_position.y

	# Simple projectile motion calculation
	var gravity = 980.0
	var time_to_target = sqrt(2 * arc_height / gravity) * 2

	var vx = dx / time_to_target
	var vy = (dy - 0.5 * gravity * time_to_target * time_to_target) / time_to_target

	# Spawn mortar shell
	_spawn_shell(Vector2(vx, vy))

func _spawn_shell(initial_velocity: Vector2) -> void:
	var shell_scene = preload("res://scenes/entities/mortar_shell.tscn")
	var shell = shell_scene.instantiate()
	shell.global_position = global_position + Vector2(0, -size / 2 - 15)
	shell.velocity = initial_velocity
	shell.explosion_radius = explosion_radius
	shell.damage = damage
	get_tree().current_scene.add_child(shell)

func _draw() -> void:
	# Draw body only if no sprite (fallback)
	if not anim_sprite:
		var rect = Rect2(-size / 2, -size / 2, size, size)
		draw_rect(rect, color)
		var barrel_rect = Rect2(-8, -size / 2 - 15, 16, 20)
		draw_rect(barrel_rect, barrel_color)

	# Draw reload indicator (overlay)
	var reload_percent = fire_timer / (1.0 / fire_rate)
	if reload_percent < 1.0:
		draw_arc(Vector2.ZERO, 30, 0, TAU * reload_percent, 32, Color.ORANGE, 2.0)
