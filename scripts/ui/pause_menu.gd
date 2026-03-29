extends CanvasLayer
class_name PauseMenu
## Pause menu overlay

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_pause()
	elif GameManager.current_state == GameManager.GameState.PAUSED:
		_resume()

func _pause() -> void:
	is_paused = true
	visible = true
	_update_difficulty_label()
	GameManager.pause_game()

func _resume() -> void:
	is_paused = false
	visible = false
	GameManager.resume_game()

func _on_resume_button_pressed() -> void:
	_resume()

func _on_restart_button_pressed() -> void:
	_resume()
	GameManager.load_room(GameManager.current_room)

func _on_menu_button_pressed() -> void:
	_resume()
	GameManager.return_to_menu()

# === DIFFICULTY CONTROLS ===

func _on_difficulty_left_pressed() -> void:
	var new_diff = max(0, GameManager.current_difficulty - 1)
	GameManager.set_difficulty(new_diff as GameManager.Difficulty)
	_update_difficulty_label()

func _on_difficulty_right_pressed() -> void:
	var new_diff = min(2, GameManager.current_difficulty + 1)
	GameManager.set_difficulty(new_diff as GameManager.Difficulty)
	_update_difficulty_label()

func _update_difficulty_label() -> void:
	# Update difficulty name label
	if has_node("Panel/DifficultyContainer/DifficultyLabel"):
		var label = $Panel/DifficultyContainer/DifficultyLabel
		label.text = GameManager.get_difficulty_name()
		label.add_theme_color_override("font_color", _get_difficulty_color(GameManager.current_difficulty))

	# Update HP info
	if has_node("Panel/DifficultyContainer/DifficultyInfo"):
		var info = $Panel/DifficultyContainer/DifficultyInfo
		var base_hp = GameManager.DIFFICULTY_BASE_HP[GameManager.current_difficulty]
		var total_hp = GameManager.get_effective_max_hp()
		info.text = "HP: %d (Base: %d + %d upgrades)" % [total_hp, base_hp, GameManager.hull_upgrade_level]

func _get_difficulty_color(diff: int) -> Color:
	match diff:
		0: return Color(0.3, 0.8, 0.3)  # Green - Cadet
		1: return Color(0.8, 0.8, 0.3)  # Yellow - Pilot
		2: return Color(0.9, 0.3, 0.3)  # Red - Mastery
	return Color.WHITE
