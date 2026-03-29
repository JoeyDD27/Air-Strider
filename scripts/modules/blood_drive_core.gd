extends ModuleBase
class_name BloodDriveCore
## Every 5 kills spawns a Nano-Orb that flies to the player and heals 1 HP

const KILLS_REQUIRED: int = 5
const NANO_ORB_SCENE_PATH: String = "res://scenes/entities/nano_orb.tscn"

var nano_orb_scene: PackedScene = null

func _on_initialize() -> void:
	module_name = "Blood-Drive Core"
	module_description = "Every 5 kills spawns healing orb"
	module_color = Color(0.8, 0.1, 0.1)  # Dark red

	# Connect to enemy killed signal
	EventBus.enemy_killed.connect(_on_enemy_killed_signal)

	# Preload nano orb scene
	if ResourceLoader.exists(NANO_ORB_SCENE_PATH):
		nano_orb_scene = load(NANO_ORB_SCENE_PATH)

func _on_enemy_killed_signal(_enemy: Node, _reward: int, position: Vector2) -> void:
	## Track kills and spawn orb at threshold
	GameManager.increment_kill_streak()

	if GameManager.current_kill_streak >= KILLS_REQUIRED:
		GameManager.reset_kill_streak()
		_spawn_nano_orb(position)

func _spawn_nano_orb(pos: Vector2) -> void:
	if not nano_orb_scene:
		push_warning("BloodDriveCore: NanoOrb scene not found")
		return

	var orb = nano_orb_scene.instantiate()
	orb.global_position = pos
	if player_ref:
		orb.target = player_ref
	get_tree().current_scene.call_deferred("add_child", orb)

	EventBus.nano_orb_spawned.emit(pos)
	EventBus.module_effect_triggered.emit("blood_drive_core", {
		"orb_spawned": true,
		"position": pos
	})

func get_status_text() -> String:
	var kills: int = int(GameManager.current_kill_streak)
	return "%d/%d kills" % [kills, KILLS_REQUIRED]

func _exit_tree() -> void:
	# Disconnect signal when module is removed
	if EventBus.enemy_killed.is_connected(_on_enemy_killed_signal):
		EventBus.enemy_killed.disconnect(_on_enemy_killed_signal)
