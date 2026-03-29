extends CanvasLayer
class_name DeathScreen
## Death screen with respawn and Phantom Protocol options

var death_count: int = 0
var can_phantom: bool = false
var is_visible_screen: bool = false

# UI positioning
var panel_width: float = 420.0
var panel_height: float = 280.0
var panel_x: float = 0.0
var panel_y: float = 0.0

# Drawing control child (CanvasLayer can't draw directly)
var draw_panel: DeathScreenPanel = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	EventBus.death_screen_shown.connect(_show_death_screen)

	# Create the drawing panel
	draw_panel = DeathScreenPanel.new()
	draw_panel.screen = self
	draw_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(draw_panel)

	# Center panel
	var viewport_size = get_viewport().get_visible_rect().size
	panel_x = (viewport_size.x - panel_width) / 2
	panel_y = (viewport_size.y - panel_height) / 2

func _show_death_screen(deaths: int, phantom_available: bool) -> void:
	death_count = deaths
	can_phantom = phantom_available
	is_visible_screen = true
	visible = true
	get_tree().paused = true
	if draw_panel:
		draw_panel.queue_redraw()

func _process(_delta: float) -> void:
	if not is_visible_screen:
		return

	# Handle input
	if Input.is_action_just_pressed("jump"):  # Space = Respawn
		_respawn()
	if Input.is_action_just_pressed("use_tool") and can_phantom:  # E = Phantom Protocol
		_activate_phantom()

func _respawn() -> void:
	is_visible_screen = false
	visible = false
	get_tree().paused = false
	GameManager.respawn_player()

func _activate_phantom() -> void:
	is_visible_screen = false
	visible = false
	get_tree().paused = false
	# IMPORTANT: We must respawn first (which loads the room fresh),
	# THEN activate phantom protocol (which spawns the drone in the loaded room)
	GameManager.respawn_player_for_phantom()
	GameManager.activate_phantom_protocol()


## Inner class that handles all drawing
class DeathScreenPanel extends Control:
	var screen: DeathScreen = null

	func _draw() -> void:
		if not screen or not screen.is_visible_screen:
			return

		# Semi-transparent dark overlay
		var viewport_size = get_viewport().get_visible_rect().size
		draw_rect(Rect2(0, 0, viewport_size.x, viewport_size.y), Color(0, 0, 0, 0.7))

		# Main panel background
		var panel_rect = Rect2(screen.panel_x, screen.panel_y, screen.panel_width, screen.panel_height)
		draw_rect(panel_rect, Color(0.08, 0.04, 0.04, 0.95))
		draw_rect(panel_rect, Color(0.8, 0.2, 0.2), false, 3.0)

		# "YOU DIED" title
		var title_x = screen.panel_x + screen.panel_width / 2 - 70
		draw_string(ThemeDB.fallback_font, Vector2(title_x, screen.panel_y + 50), "YOU DIED", HORIZONTAL_ALIGNMENT_CENTER, 140, 36, Color.RED)

		# Death count
		var death_text = "Deaths in this room: %d" % screen.death_count
		draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 20, screen.panel_y + 90), death_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.7))

		# Separator line
		draw_line(Vector2(screen.panel_x + 20, screen.panel_y + 105), Vector2(screen.panel_x + screen.panel_width - 20, screen.panel_y + 105), Color(0.4, 0.2, 0.2), 2.0)

		# Respawn option
		var respawn_rect = Rect2(screen.panel_x + 20, screen.panel_y + 120, screen.panel_width - 40, 45)
		draw_rect(respawn_rect, Color(0.15, 0.15, 0.2))
		draw_rect(respawn_rect, Color(0.4, 0.4, 0.6), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 35, screen.panel_y + 150), "[SPACE]  Respawn", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

		# Rescue Drone option
		if screen.can_phantom:
			var phantom_rect = Rect2(screen.panel_x + 20, screen.panel_y + 175, screen.panel_width - 40, 65)
			draw_rect(phantom_rect, Color(0.15, 0.08, 0.2))
			draw_rect(phantom_rect, Color(0.6, 0.3, 0.8), false, 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 35, screen.panel_y + 200), "[E]  CALL RESCUE DRONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.5, 1.0))
			draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 35, screen.panel_y + 222), "Drone carries you to exit (no coins)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.4, 0.6))
		else:
			# Show how many deaths until rescue unlocks
			var remaining = 5 - screen.death_count
			if remaining > 0:
				var unlock_text = "Rescue Drone unlocks in %d more death%s" % [remaining, "s" if remaining != 1 else ""]
				draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 20, screen.panel_y + 200), unlock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.35, 0.4))

		# Tip at bottom
		var tip_y = screen.panel_y + screen.panel_height - 25
		draw_string(ThemeDB.fallback_font, Vector2(screen.panel_x + 20, tip_y), "Tip: Modules can help with difficult sections", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.5))
