extends CanvasLayer
class_name VictoryScreen
## Victory screen shown after defeating the boss

@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var continue_button: Button = $Panel/ButtonContainer/ContinueButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	EventBus.victory.connect(_show_victory)

func _show_victory() -> void:
	visible = true
	get_tree().paused = true

	# Update subtitle based on chapter
	var chapter = GameManager.get_current_chapter()
	if chapter == 5:
		# Game complete! Special celebration screen
		title_label.text = "CONGRATULATIONS!"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
		subtitle_label.text = "You defeated the Orbital Aegis!\n\nYou have conquered all 5 chapters\nand beaten Air Strider!\n\nThank you for playing!"
		continue_button.text = "MAIN MENU"
	elif chapter == 4:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		subtitle_label.text = "You defeated Subject 88!\nChapter 4 Complete"
		continue_button.text = "CONTINUE"
	elif chapter == 3:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		subtitle_label.text = "You defeated the Apex-Interceptor!\nChapter 3 Complete"
		continue_button.text = "CONTINUE"
	elif chapter == 2:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		subtitle_label.text = "You defeated the Ground-Fault Titan!\nChapter 2 Complete"
		continue_button.text = "CONTINUE"
	else:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		subtitle_label.text = "You defeated the Furnace Crab!\nChapter 1 Complete"
		continue_button.text = "CONTINUE"

func _on_menu_button_pressed() -> void:
	visible = false
	get_tree().paused = false
	GameManager.return_to_menu()

func _on_continue_button_pressed() -> void:
	visible = false
	get_tree().paused = false

	# Check which chapter we just completed (use get_current_chapter() for accuracy)
	var chapter = GameManager.get_current_chapter()
	var room = GameManager.current_room

	if chapter == 1 and room == 10:
		# Completed Chapter 1 boss - transition to Chapter 2
		GameManager.start_chapter_2()
	elif chapter == 2 and room == 121:
		# Completed Chapter 2 boss - transition to Chapter 3
		GameManager.start_chapter_3()
	elif chapter == 3 and room == 221:
		# Completed Chapter 3 boss - transition to Chapter 4
		GameManager.start_chapter_4()
	elif chapter == 4 and room == 331:
		# Completed Chapter 4 boss - transition to Chapter 5
		GameManager.start_chapter_5()
	elif chapter == 5 and room == 409:
		# Completed Chapter 5 boss - game complete!
		# Delete save file since game is finished
		GameManager.delete_save()
		GameManager.return_to_menu()
	else:
		# Fallback - shouldn't happen but log warning
		push_warning("Victory screen: Unknown boss room chapter=%d room=%d" % [chapter, room])
		GameManager.return_to_menu()
