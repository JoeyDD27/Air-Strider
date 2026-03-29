extends CharacterBody2D
class_name EnemyBase
## Base class for all enemies

@export var max_health: int = 1
@export var damage: int = 1
@export var reward: int = 15

var health: int
var is_dead: bool = false
var player_ref: Node2D = null

# Support aura effects (Chapter 2)
var is_shielded: bool = false  # Set by Buffer-Drone - blocks all damage
var cooldown_multiplier: float = 1.0  # Set by Amp-Pylon - lower = faster actions

# Bonus health system (Chapter 5 - Medic Drone)
var bonus_health: int = 0  # Extra HP segments that absorb damage first
var bonus_health_source: Node = null  # Reference to the Medic Drone providing bonus

var _floor_y: float = 900.0  # Default floor level, updated from room
var _room_width: float = 1920.0  # Default room width, updated from room
var _room_margin: float = 30.0  # Margin to keep enemies away from walls

# Sprite support (optional - null if using procedural _draw())
var anim_sprite: AnimatedSprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	health = max_health

	# Set collision layers
	collision_layer = 4  # Enemy layer (layer 3)
	collision_mask = 2 | 16 | 128  # Platforms, player projectiles, and room boundaries

	# Get floor_y and room_width from current room for boundary checking
	var tree = get_tree()
	if tree and tree.current_scene:
		if "floor_y" in tree.current_scene:
			_floor_y = tree.current_scene.floor_y
		if "room_width" in tree.current_scene:
			_room_width = tree.current_scene.room_width

	# Find player reference (with null check for dynamically spawned enemies)
	if tree == null:
		return
	await tree.process_frame
	tree = get_tree()
	if tree == null:
		return
	var players = tree.get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

func _process(_delta: float) -> void:
	if is_dead:
		return

	# Horizontal boundary check: keep enemies within room walls
	if global_position.x < _room_margin:
		global_position.x = _room_margin
		velocity.x = max(velocity.x, 0)  # Stop leftward movement
	elif global_position.x > _room_width - _room_margin:
		global_position.x = _room_width - _room_margin
		velocity.x = min(velocity.x, 0)  # Stop rightward movement

	# Vertical boundary check: clamp enemies to stand on the floor instead of falling through
	# This catches enemies that fall off platforms - they land on floor_y instead of dying
	if global_position.y > _floor_y - 50:
		# Clamp to floor level (slightly above floor_y to stand on it)
		global_position.y = _floor_y - 50
		velocity.y = 0

func take_damage(amount: int) -> bool:
	if is_dead:
		return false

	# Shield blocks all damage (Chapter 2 Buffer-Drone aura)
	if is_shielded:
		return false

	# Bonus health absorbs damage first (Chapter 5 - Medic Drone)
	if bonus_health > 0:
		var absorbed = min(amount, bonus_health)
		bonus_health -= absorbed
		amount -= absorbed
		EventBus.enemy_damaged.emit(self, health + bonus_health)
		_flash_white()
		if bonus_health <= 0:
			bonus_health_source = null
			EventBus.bonus_health_removed.emit(self)
		if amount <= 0:
			return true

	health -= amount
	EventBus.enemy_damaged.emit(self, health)

	# Visual feedback
	_flash_white()

	if health <= 0:
		die()

	return true

func _flash_white() -> void:
	var tree = get_tree()
	if tree == null:
		return
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE
		await tree.create_timer(0.1).timeout
		if not is_dead and is_inside_tree():
			_update_sprite_shield_visual()
	else:
		modulate = Color.WHITE
		await tree.create_timer(0.1).timeout
		if not is_dead and is_inside_tree():
			modulate = Color(1, 1, 1, 1)

func die() -> void:
	is_dead = true
	EventBus.enemy_killed.emit(self, reward, global_position)

	# Death effect
	_spawn_death_particles()

	# Remove from scene
	queue_free()

func _spawn_death_particles() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	for i in range(5):
		var particle = Node2D.new()
		particle.set_script(preload("res://scripts/effects/debris_particle.gd"))
		particle.global_position = global_position + Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)
		particle.color = Color(0.8, 0.2, 0.2)  # Red particles
		tree.current_scene.add_child(particle)

func get_player_position() -> Vector2:
	if player_ref:
		return player_ref.global_position
	return Vector2.ZERO

func get_player_velocity() -> Vector2:
	if player_ref:
		return player_ref.velocity
	return Vector2.ZERO

## Returns true if the player is in phantom mode (invincible ghost mode)
## Enemies should check this and ignore the player when true
func is_player_phantom() -> bool:
	return GameManager.is_phantom_mode

## Returns true if this enemy should ignore the player (dead, no ref, or phantom mode)
func should_ignore_player() -> bool:
	return is_dead or player_ref == null or GameManager.is_phantom_mode

# Sprite support methods
func _setup_sprite() -> void:
	"""Initialize sprite reference if AnimatedSprite2D child exists"""
	anim_sprite = get_node_or_null("AnimatedSprite2D")

func _update_sprite_facing(target_x: float) -> void:
	"""Update sprite flip based on target direction"""
	if anim_sprite:
		anim_sprite.flip_h = (target_x < global_position.x)

func _set_sprite_frame(frame: int) -> void:
	"""Set sprite to specific frame (stops auto-animation)"""
	if anim_sprite:
		anim_sprite.stop()
		anim_sprite.frame = frame

func _update_sprite_shield_visual() -> void:
	"""Apply shield tint to sprite if shielded"""
	if anim_sprite:
		if is_shielded:
			anim_sprite.modulate = Color(0.3, 0.8, 1.0, 0.9)
		else:
			anim_sprite.modulate = Color.WHITE
