extends EnemyBase
class_name FuelTank
## Passive wandering enemy that spawns FireZone on death - Chapter 4

enum FuelTankState { WANDERING, TURNING }

# Frame mapping: 0-2 idle/wander, 3-4 turning, 5 damaged, 6-7 leaking, 8 death
const FRAME_IDLE = 0
const FRAME_WANDER = 1
const FRAME_TURNING = 3

@export var wander_speed: float = 40.0
@export var wander_range: float = 100.0
@export var fire_zone_radius: float = 120.0
@export var fire_zone_duration: float = 10.0
@export var fire_zone_damage: int = 1

var state: FuelTankState = FuelTankState.WANDERING
var state_timer: float = 0.0
var move_direction: float = 1.0  # 1 = right, -1 = left
var start_x: float = 0.0
var liquid_slosh: float = 0.0

const FIRE_ZONE_SCRIPT = preload("res://scripts/hazards/fire_zone.gd")

func _ready() -> void:
	super._ready()
	max_health = 2
	health = max_health
	reward = 35
	start_x = global_position.x
	_setup_sprite()

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_phantom_mode:
		return

	state_timer += delta
	liquid_slosh += delta * 3.0

	match state:
		FuelTankState.WANDERING:
			_state_wandering(delta)
		FuelTankState.TURNING:
			_state_turning(delta)

	move_and_slide()

	# Update sprite
	if anim_sprite:
		_update_sprite_facing(global_position.x + move_direction)
		match state:
			FuelTankState.WANDERING:
				_set_sprite_frame(FRAME_WANDER)
			FuelTankState.TURNING:
				_set_sprite_frame(FRAME_TURNING)

	queue_redraw()

func _state_wandering(delta: float) -> void:
	velocity.x = wander_speed * move_direction

	# Apply gravity
	velocity.y += 600 * delta

	# Check if we've wandered too far from start position
	var dist_from_start = global_position.x - start_x
	if abs(dist_from_start) > wander_range:
		state = FuelTankState.TURNING
		state_timer = 0.0

	# Also turn if we hit a wall
	if is_on_wall():
		state = FuelTankState.TURNING
		state_timer = 0.0

func _state_turning(delta: float) -> void:
	velocity.x = 0
	velocity.y += 600 * delta

	if state_timer >= 0.3:
		move_direction *= -1
		state = FuelTankState.WANDERING
		state_timer = 0.0

func die() -> void:
	is_dead = true

	# Death rattle: Spawn FireZone
	_execute_death_rattle()

	EventBus.enemy_killed.emit(self, reward, global_position)
	_spawn_death_particles()
	queue_free()

func _execute_death_rattle() -> void:
	var fire_zone = Area2D.new()
	fire_zone.set_script(FIRE_ZONE_SCRIPT)
	fire_zone.radius = fire_zone_radius
	fire_zone.duration = fire_zone_duration
	fire_zone.damage_per_tick = fire_zone_damage
	fire_zone.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", fire_zone)

	# Screen shake for dramatic effect
	EventBus.screen_shake.emit(5.0, 0.2)

func _draw() -> void:
	var barrel_width = 30.0
	var barrel_height = 45.0

	if not anim_sprite:
		# Barrel body
		var rect = Rect2(-barrel_width / 2, -barrel_height, barrel_width, barrel_height)

		# Main barrel (dark gray metal)
		draw_rect(rect, Color(0.3, 0.3, 0.35))

		# Metal bands
		draw_rect(Rect2(-barrel_width / 2 - 2, -barrel_height + 5, barrel_width + 4, 6), Color(0.4, 0.4, 0.45))
		draw_rect(Rect2(-barrel_width / 2 - 2, -barrel_height / 2 - 3, barrel_width + 4, 6), Color(0.4, 0.4, 0.45))
		draw_rect(Rect2(-barrel_width / 2 - 2, -8, barrel_width + 4, 6), Color(0.4, 0.4, 0.45))

		# Liquid level indicator (sloshing)
		var slosh_offset = sin(liquid_slosh) * 3.0
		var liquid_rect = Rect2(-barrel_width / 2 + 3, -barrel_height + 12 + slosh_offset, barrel_width - 6, barrel_height - 18)
		draw_rect(liquid_rect, Color(0.2, 0.8, 0.1, 0.7))

		# Warning label
		var label_rect = Rect2(-10, -barrel_height / 2 - 8, 20, 16)
		draw_rect(label_rect, Color(1.0, 0.8, 0.0))
		# Hazard symbol (simple triangle)
		var triangle = PackedVector2Array([
			Vector2(0, -barrel_height / 2 - 5),
			Vector2(-6, -barrel_height / 2 + 5),
			Vector2(6, -barrel_height / 2 + 5)
		])
		draw_colored_polygon(triangle, Color(0.1, 0.1, 0.1))

		# Small legs
		draw_line(Vector2(-barrel_width / 2 + 5, 0), Vector2(-barrel_width / 2, 8), Color(0.3, 0.3, 0.35), 4.0)
		draw_line(Vector2(barrel_width / 2 - 5, 0), Vector2(barrel_width / 2, 8), Color(0.3, 0.3, 0.35), 4.0)

	# Direction indicator (subtle) - always visible
	if state == FuelTankState.WANDERING:
		var arrow_x = move_direction * 20
		draw_line(Vector2(0, -barrel_height / 2), Vector2(arrow_x, -barrel_height / 2), Color(0.5, 0.5, 0.5, 0.5), 2.0)
