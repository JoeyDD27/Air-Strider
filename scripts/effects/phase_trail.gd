extends Node2D
class_name PhaseTrail
## Visual trail effect for Phase Shift - uses player sprite silhouettes

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var trail_color: Color = Color(0.667, 0.267, 1.0)
var lifetime: float = 0.3
var max_lifetime: float = 0.3

# Store player sprite info for ghost silhouettes
var player_texture: Texture2D = null
var player_flip_h: bool = false
var sprite_scale: Vector2 = Vector2(0.7, 0.7)

# Ghost sprites along the trail
var ghost_sprites: Array[Sprite2D] = []

func _ready() -> void:
	# Get player reference to copy sprite info
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
		if anim_sprite and anim_sprite.sprite_frames:
			var anim_name = anim_sprite.animation
			var frame = anim_sprite.frame
			player_texture = anim_sprite.sprite_frames.get_frame_texture(anim_name, frame)
			player_flip_h = anim_sprite.flip_h
			sprite_scale = anim_sprite.scale

	# Create ghost sprites along the path
	_create_ghost_sprites()

func _create_ghost_sprites() -> void:
	var num_ghosts = 5
	for i in range(num_ghosts):
		var t = float(i) / float(num_ghosts - 1)
		var pos = start_pos.lerp(end_pos, t)

		var ghost = Sprite2D.new()
		if player_texture:
			ghost.texture = player_texture
			ghost.scale = sprite_scale
			ghost.flip_h = player_flip_h
		ghost.global_position = pos
		ghost.modulate = Color(trail_color, 0.6 * (1.0 - t * 0.5))
		add_child(ghost)
		ghost_sprites.append(ghost)

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	# Fade out ghost sprites
	var alpha = lifetime / max_lifetime
	for i in range(ghost_sprites.size()):
		var t = float(i) / float(ghost_sprites.size() - 1) if ghost_sprites.size() > 1 else 0.0
		var ghost_alpha = alpha * 0.6 * (1.0 - t * 0.5)
		ghost_sprites[i].modulate = Color(trail_color, ghost_alpha)

	queue_redraw()

func _draw() -> void:
	var alpha = lifetime / max_lifetime

	# Draw line between positions
	var local_start = start_pos - global_position
	var local_end = end_pos - global_position

	draw_line(local_start, local_end, Color(trail_color, alpha * 0.8), 4.0)
