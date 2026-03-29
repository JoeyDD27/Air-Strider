extends Control
class_name MainMenu
## Main menu screen with difficulty selection and save/load

func _ready() -> void:
	# Ensure time scale is normal
	Engine.time_scale = 1.0
	# Update button visibility based on save file
	_update_button_visibility()
	# Update difficulty display to show current setting
	_update_difficulty_display()

func _update_button_visibility() -> void:
	## Show Continue button if save exists, otherwise show only New Game
	var has_save = GameManager.has_save_file()

	if has_node("ButtonContainer/ContinueButton"):
		$ButtonContainer/ContinueButton.visible = has_save
	if has_node("ButtonContainer/NewGameButton"):
		$ButtonContainer/NewGameButton.visible = true
	# Hide legacy start button if it exists
	if has_node("ButtonContainer/StartButton"):
		$ButtonContainer/StartButton.visible = not has_save and not has_node("ButtonContainer/NewGameButton")

func _on_continue_button_pressed() -> void:
	# Continue from saved progress
	GameManager.continue_game()

func _on_new_game_button_pressed() -> void:
	# Difficulty already applied via arrow buttons
	GameManager.start_new_game()

func _on_start_button_pressed() -> void:
	# Legacy button - difficulty already applied via arrow buttons
	GameManager.start_game()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_difficulty_left_pressed() -> void:
	var new_diff = max(0, GameManager.current_difficulty - 1)
	GameManager.set_difficulty(new_diff as GameManager.Difficulty)
	_update_difficulty_display()

func _on_difficulty_right_pressed() -> void:
	var new_diff = min(2, GameManager.current_difficulty + 1)
	GameManager.set_difficulty(new_diff as GameManager.Difficulty)
	_update_difficulty_display()

func _update_difficulty_display() -> void:
	if has_node("DifficultyContainer/DifficultyLabel"):
		var label = $DifficultyContainer/DifficultyLabel
		label.text = _get_difficulty_name(GameManager.current_difficulty)
		label.add_theme_color_override("font_color", _get_difficulty_color(GameManager.current_difficulty))

	if has_node("DifficultyContainer/DifficultyDesc"):
		var desc = $DifficultyContainer/DifficultyDesc
		desc.text = _get_difficulty_desc(GameManager.current_difficulty)

func _get_difficulty_name(diff: int) -> String:
	match diff:
		0: return "CADET"
		1: return "PILOT"
		2: return "MASTERY"
	return "PILOT"

func _get_difficulty_desc(diff: int) -> String:
	match diff:
		0: return "5 HP - Pits deal 1 damage (Easy)"
		1: return "3 HP - Pits are lethal (Normal)"
		2: return "1 HP - Pits are lethal (Hard)"
	return ""

func _get_difficulty_color(diff: int) -> Color:
	match diff:
		0: return Color(0.3, 0.8, 0.3)  # Green
		1: return Color(0.8, 0.8, 0.3)  # Yellow
		2: return Color(0.9, 0.3, 0.3)  # Red
	return Color.WHITE

func _draw() -> void:
	# Draw background
	var rect = get_viewport_rect()
	draw_rect(rect, Color(0.08, 0.08, 0.12))

	# Draw title
	var title_pos = Vector2(rect.size.x / 2 - 200, 150)
	draw_string(ThemeDB.fallback_font, title_pos, "AIR STRIDER", HORIZONTAL_ALIGNMENT_CENTER, 400, 48, Color(0.3, 0.7, 1.0))

	# Draw subtitle
	var subtitle_pos = Vector2(rect.size.x / 2 - 150, 220)
	draw_string(ThemeDB.fallback_font, subtitle_pos, "Chapter 1: The Awakening", HORIZONTAL_ALIGNMENT_CENTER, 300, 24, Color(0.6, 0.6, 0.7))

	# Draw controls info
	var controls_y = rect.size.y - 150
	var controls = [
		"CONTROLS:",
		"LEFT CLICK - Grapple / Charge Weapon",
		"RIGHT CLICK - Use Tool",
		"A/D - Move Left/Right",
		"SPACE - Air Jump",
		"ESC - Pause"
	]

	for i in range(controls.size()):
		var color = Color.WHITE if i == 0 else Color(0.6, 0.6, 0.6)
		draw_string(ThemeDB.fallback_font, Vector2(50, controls_y + i * 22), controls[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
