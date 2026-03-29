extends ModuleBase
class_name ReactiveShockShell
## Taking damage releases a shockwave that deals 3 damage to all nearby enemies

const SHOCKWAVE_RADIUS: float = 150.0
const SHOCKWAVE_DAMAGE: int = 3  # Deals same damage as one player bullet
const SHOCKWAVE_SCENE: PackedScene = preload("res://scenes/effects/shockwave_effect.tscn")

func _on_initialize() -> void:
	module_name = "Reactive Shock-Shell"
	module_description = "Damage releases shockwave (3 dmg)"
	module_color = Color(0.6, 0.2, 1.0)  # Purple

func on_player_damaged(amount: int, source: String) -> Dictionary:
	## Called when player takes damage - trigger shockwave
	_release_shockwave()
	# Don't prevent or modify the damage, just trigger shockwave as a reaction
	return {}

func _release_shockwave() -> void:
	if not is_instance_valid(player_ref):
		return

	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var pos = player_ref.global_position
	var enemies = tree.get_nodes_in_group("enemies")
	var damaged_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue

		var dist = pos.distance_to(enemy.global_position)
		if dist > SHOCKWAVE_RADIUS:
			continue

		# Deal damage to all enemies in range
		if enemy.has_method("take_damage"):
			enemy.take_damage(SHOCKWAVE_DAMAGE)
			damaged_count += 1

	# Spawn visual effect immediately (not deferred for reliability)
	var effect = SHOCKWAVE_SCENE.instantiate()
	effect.global_position = pos
	effect.radius = SHOCKWAVE_RADIUS
	effect.color = module_color
	tree.current_scene.add_child(effect)

	# Flash player purple briefly to indicate shockwave fired
	player_ref.modulate = module_color
	tree.create_timer(0.1).timeout.connect(func():
		if is_instance_valid(player_ref):
			player_ref.modulate = Color.WHITE
	)

	EventBus.module_effect_triggered.emit("reactive_shock_shell", {
		"position": pos,
		"enemies_damaged": damaged_count
	})

func get_status_text() -> String:
	return "Dmg=Shock"
