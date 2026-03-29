extends CanvasLayer
class_name InventoryUI
## Player inventory - press B to toggle, drag and drop tools/modules to equip

# Preload icon textures
const TOOL_ICONS: Dictionary = {
	"vertical_thruster": preload("res://assets/icons/tools/vertical_thruster.png"),
	"phalanx_shield": preload("res://assets/icons/tools/phalanx_shield.png"),
	"phase_shift": preload("res://assets/icons/tools/phase_shift.png"),
	"chrono_drive": preload("res://assets/icons/tools/chrono_drive.png"),
}

const MODULE_ICONS: Dictionary = {
	"gravity_anchor": preload("res://assets/icons/modules/gravity_anchor.png"),
	"phoenix_plating": preload("res://assets/icons/modules/phoenix_plating.png"),
	"spectral_phase": preload("res://assets/icons/modules/spectral_phase.png"),
	"hyper_coil": preload("res://assets/icons/modules/hyper_coil.png"),
	"blood_drive_core": preload("res://assets/icons/modules/blood_drive_core.png"),
	"reactive_shock_shell": preload("res://assets/icons/modules/reactive_shock_shell.png"),
	"bounty_hunter_chip": preload("res://assets/icons/modules/bounty_hunter_chip.png"),
	"aviator_gyro": preload("res://assets/icons/modules/aviator_gyro.png"),
}

var is_open: bool = false
var dragging_tool: String = ""
var dragging_module: String = ""
var drag_start_pos: Vector2 = Vector2.ZERO
var mouse_pos: Vector2 = Vector2.ZERO
var hovered_tool_slot: int = -1
var hovered_module_slot: int = -1
var hovered_tool_equipped: bool = false
var hovered_module_equipped: bool = false

const SLOT_SIZE: float = 70.0
const SLOT_PADDING: float = 10.0
const PANEL_PADDING: float = 15.0

# Tool display data
const TOOLS_DATA: Dictionary = {
	"vertical_thruster": {"display": "Vertical Thruster", "color": Color(0.2, 0.8, 0.2)},
	"phalanx_shield": {"display": "Phalanx Shield", "color": Color(0.2, 0.5, 1.0)},
	"phase_shift": {"display": "Phase Shift", "color": Color(0.8, 0.2, 0.8)},
	"chrono_drive": {"display": "Chrono-Drive", "color": Color(1.0, 0.8, 0.2)}
}

# Module display data
const MODULES_DATA: Dictionary = {
	"gravity_anchor": {"display": "Gravity Anchor", "color": Color(0.3, 0.6, 1.0)},
	"phoenix_plating": {"display": "Phoenix Plating", "color": Color(1.0, 0.4, 0.0)},
	"spectral_phase": {"display": "Spectral Phase", "color": Color(0.6, 0.2, 0.9)},
	"hyper_coil": {"display": "Hyper-Coil", "color": Color(1.0, 0.2, 0.2)},
	"blood_drive_core": {"display": "Blood-Drive", "color": Color(0.8, 0.1, 0.1)},
	"reactive_shock_shell": {"display": "Shock-Shell", "color": Color(0.6, 0.2, 1.0)},
	"bounty_hunter_chip": {"display": "Bounty Chip", "color": Color(1.0, 0.85, 0.0)},
	"aviator_gyro": {"display": "Aviator Gyro", "color": Color(0.4, 0.8, 1.0)}
}

@onready var panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 100  # Ensure it's on top
	panel.draw.connect(_draw_panel)

func _process(_delta: float) -> void:
	# Toggle inventory with B key
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			_close_inventory()
		else:
			_open_inventory()

	if not is_open:
		return

	mouse_pos = panel.get_local_mouse_position()
	_update_hovered_slots()

	# Handle click events
	if Input.is_action_just_pressed("shoot"):  # Left click
		# Click on equipped tool to unequip
		if hovered_tool_equipped:
			GameManager.unequip_tool()
		# Click on equipped module to unequip
		elif hovered_module_equipped:
			GameManager.unequip_module()
		# Click on owned tool to equip
		elif hovered_tool_slot >= 0:
			var tools = GameManager.owned_tools
			if hovered_tool_slot < tools.size():
				var tool_name = tools[hovered_tool_slot]
				if tool_name == GameManager.equipped_tool:
					GameManager.unequip_tool()
				else:
					GameManager.equipped_tool = tool_name
					EventBus.tool_equipped.emit(tool_name)
		# Click on owned module to equip
		elif hovered_module_slot >= 0:
			var modules = GameManager.owned_modules
			if hovered_module_slot < modules.size():
				var module_name = modules[hovered_module_slot]
				if module_name == GameManager.equipped_module:
					GameManager.unequip_module()
				else:
					GameManager.equip_module(module_name)

	# Handle mouse input for drag and drop
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Tool dragging
		if dragging_tool == "" and dragging_module == "" and hovered_tool_slot >= 0:
			var tools = GameManager.owned_tools
			if hovered_tool_slot < tools.size():
				dragging_tool = tools[hovered_tool_slot]
				drag_start_pos = mouse_pos

		# Module dragging
		if dragging_tool == "" and dragging_module == "" and hovered_module_slot >= 0:
			var modules = GameManager.owned_modules
			if hovered_module_slot < modules.size():
				dragging_module = modules[hovered_module_slot]
				drag_start_pos = mouse_pos
	else:
		# Release tool
		if dragging_tool != "":
			if _is_over_tool_equipped_slot():
				GameManager.equipped_tool = dragging_tool
				EventBus.tool_equipped.emit(dragging_tool)
			dragging_tool = ""

		# Release module
		if dragging_module != "":
			if _is_over_module_equipped_slot():
				GameManager.equip_module(dragging_module)
			dragging_module = ""

	panel.queue_redraw()

func _open_inventory() -> void:
	is_open = true
	visible = true
	get_tree().paused = true  # Freeze the game
	EventBus.game_paused.emit()

func _close_inventory() -> void:
	is_open = false
	visible = false
	dragging_tool = ""
	dragging_module = ""
	get_tree().paused = false
	EventBus.game_resumed.emit()

func _update_hovered_slots() -> void:
	hovered_tool_slot = -1
	hovered_module_slot = -1
	hovered_tool_equipped = false
	hovered_module_equipped = false

	# Check equipped tool slot first
	if _is_over_tool_equipped_slot() and GameManager.equipped_tool != "":
		hovered_tool_equipped = true
		return

	# Check equipped module slot
	if _is_over_module_equipped_slot() and GameManager.equipped_module != "":
		hovered_module_equipped = true
		return

	# Check tool slots
	var tools = GameManager.owned_tools
	var tool_start_x = PANEL_PADDING
	var tool_start_y = 65.0

	for i in range(tools.size()):
		var slot_x = tool_start_x + (i % 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_y = tool_start_y + (i / 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_rect = Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE)

		if slot_rect.has_point(mouse_pos):
			hovered_tool_slot = i
			break

	# Check module slots (below tools section)
	var modules = GameManager.owned_modules
	var module_start_x = PANEL_PADDING
	var module_start_y = 220.0

	for i in range(modules.size()):
		var slot_x = module_start_x + (i % 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_y = module_start_y + (i / 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_rect = Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE)

		if slot_rect.has_point(mouse_pos):
			hovered_module_slot = i
			break

func _is_over_tool_equipped_slot() -> bool:
	var equipped_rect = _get_tool_equipped_slot_rect()
	return equipped_rect.has_point(mouse_pos)

func _is_over_module_equipped_slot() -> bool:
	var equipped_rect = _get_module_equipped_slot_rect()
	return equipped_rect.has_point(mouse_pos)

func _get_tool_equipped_slot_rect() -> Rect2:
	var panel_width = 500.0
	var slot_x = panel_width - PANEL_PADDING - SLOT_SIZE - 10
	var slot_y = 65.0
	return Rect2(slot_x, slot_y, SLOT_SIZE + 10, SLOT_SIZE + 10)

func _get_module_equipped_slot_rect() -> Rect2:
	var panel_width = 500.0
	var slot_x = panel_width - PANEL_PADDING - SLOT_SIZE - 10
	var slot_y = 220.0
	return Rect2(slot_x, slot_y, SLOT_SIZE + 10, SLOT_SIZE + 10)

func _draw_panel() -> void:
	var panel_width = 500.0
	var panel_height = 400.0
	var screen_center = Vector2(640, 360)  # Based on 1280x720 viewport

	# Background
	panel.draw_rect(Rect2(0, 0, panel_width, panel_height), Color(0.1, 0.1, 0.15, 0.95))
	panel.draw_rect(Rect2(0, 0, panel_width, panel_height), Color(0.4, 0.6, 0.8), false, 3.0)

	# Title
	panel.draw_string(ThemeDB.fallback_font, Vector2(PANEL_PADDING, 30), "INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

	# === TOOLS SECTION ===
	panel.draw_string(ThemeDB.fallback_font, Vector2(PANEL_PADDING, 55), "TOOLS (E key)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.8, 0.4))

	var tools = GameManager.owned_tools
	var tool_start_x = PANEL_PADDING
	var tool_start_y = 65.0

	for i in range(tools.size()):
		var tool_name = tools[i]
		var slot_x = tool_start_x + (i % 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_y = tool_start_y + (i / 4) * (SLOT_SIZE + SLOT_PADDING)

		if tool_name == dragging_tool:
			panel.draw_rect(Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE), Color(0.15, 0.15, 0.2))
			panel.draw_rect(Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE), Color(0.3, 0.3, 0.4), false, 2.0)
			continue

		_draw_tool_slot(slot_x, slot_y, tool_name, i == hovered_tool_slot)

	# Tool equipped slot
	var tool_equipped_rect = _get_tool_equipped_slot_rect()
	var tool_eq_color = Color(0.2, 0.3, 0.2)
	if hovered_tool_equipped:
		tool_eq_color = Color(0.4, 0.2, 0.2)  # Red tint when hovering (click to unequip)
	elif _is_over_tool_equipped_slot() and dragging_tool != "":
		tool_eq_color = Color(0.3, 0.5, 0.3)

	panel.draw_rect(tool_equipped_rect, tool_eq_color)
	var tool_border_color = Color(0.8, 0.3, 0.3) if hovered_tool_equipped else Color(0.4, 0.8, 0.4)
	panel.draw_rect(tool_equipped_rect, tool_border_color, false, 3.0)
	var tool_label = "CLICK TO UNEQUIP" if hovered_tool_equipped else "EQUIPPED"
	var tool_label_color = Color(0.8, 0.3, 0.3) if hovered_tool_equipped else Color(0.4, 0.8, 0.4)
	panel.draw_string(ThemeDB.fallback_font, Vector2(tool_equipped_rect.position.x, tool_equipped_rect.position.y - 5), tool_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tool_label_color)

	if GameManager.equipped_tool != "" and GameManager.equipped_tool != dragging_tool:
		_draw_tool_slot(tool_equipped_rect.position.x + 5, tool_equipped_rect.position.y + 5, GameManager.equipped_tool, hovered_tool_equipped)

	# === MODULES SECTION ===
	panel.draw_line(Vector2(PANEL_PADDING, 195), Vector2(panel_width - PANEL_PADDING, 195), Color(0.3, 0.3, 0.4), 2.0)
	panel.draw_string(ThemeDB.fallback_font, Vector2(PANEL_PADDING, 212), "MODULES (Passive)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.5, 1.0))

	var modules = GameManager.owned_modules
	var module_start_x = PANEL_PADDING
	var module_start_y = 220.0

	for i in range(modules.size()):
		var module_name = modules[i]
		var slot_x = module_start_x + (i % 4) * (SLOT_SIZE + SLOT_PADDING)
		var slot_y = module_start_y + (i / 4) * (SLOT_SIZE + SLOT_PADDING)

		if module_name == dragging_module:
			panel.draw_rect(Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE), Color(0.15, 0.15, 0.2))
			panel.draw_rect(Rect2(slot_x, slot_y, SLOT_SIZE, SLOT_SIZE), Color(0.3, 0.3, 0.4), false, 2.0)
			continue

		_draw_module_slot(slot_x, slot_y, module_name, i == hovered_module_slot)

	# Module equipped slot
	var module_equipped_rect = _get_module_equipped_slot_rect()
	var mod_eq_color = Color(0.25, 0.2, 0.3)
	if hovered_module_equipped:
		mod_eq_color = Color(0.4, 0.2, 0.2)  # Red tint when hovering (click to unequip)
	elif _is_over_module_equipped_slot() and dragging_module != "":
		mod_eq_color = Color(0.4, 0.3, 0.5)

	panel.draw_rect(module_equipped_rect, mod_eq_color)
	var mod_border_color = Color(0.8, 0.3, 0.3) if hovered_module_equipped else Color(0.8, 0.5, 1.0)
	panel.draw_rect(module_equipped_rect, mod_border_color, false, 3.0)
	var mod_label = "CLICK TO UNEQUIP" if hovered_module_equipped else "EQUIPPED"
	var mod_label_color = Color(0.8, 0.3, 0.3) if hovered_module_equipped else Color(0.8, 0.5, 1.0)
	panel.draw_string(ThemeDB.fallback_font, Vector2(module_equipped_rect.position.x, module_equipped_rect.position.y - 5), mod_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, mod_label_color)

	if GameManager.equipped_module != "" and GameManager.equipped_module != dragging_module:
		_draw_module_slot(module_equipped_rect.position.x + 5, module_equipped_rect.position.y + 5, GameManager.equipped_module, hovered_module_equipped)

	# Draw dragged items at mouse
	if dragging_tool != "":
		_draw_tool_slot(mouse_pos.x - SLOT_SIZE / 2, mouse_pos.y - SLOT_SIZE / 2, dragging_tool, true)
	if dragging_module != "":
		_draw_module_slot(mouse_pos.x - SLOT_SIZE / 2, mouse_pos.y - SLOT_SIZE / 2, dragging_module, true)

	# Instructions
	panel.draw_string(ThemeDB.fallback_font, Vector2(PANEL_PADDING, panel_height - 15), "Click to equip/unequip | Drag or Press B to close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.5))

func _draw_tool_slot(x: float, y: float, tool_name: String, highlighted: bool) -> void:
	var tool_data = TOOLS_DATA.get(tool_name, {"display": tool_name, "color": Color.WHITE})
	var bg_color = Color(0.2, 0.2, 0.25) if not highlighted else Color(0.25, 0.3, 0.35)
	var border_color = tool_data["color"] if highlighted else Color(0.4, 0.4, 0.4)

	panel.draw_rect(Rect2(x, y, SLOT_SIZE, SLOT_SIZE), bg_color)
	panel.draw_rect(Rect2(x, y, SLOT_SIZE, SLOT_SIZE), border_color, false, 2.0)

	# Tool icon (use texture if available)
	var icon_texture = TOOL_ICONS.get(tool_name)
	if icon_texture:
		var icon_size = 44.0
		var icon_x = x + (SLOT_SIZE - icon_size) / 2
		var icon_y = y + 4
		panel.draw_texture_rect(icon_texture, Rect2(icon_x, icon_y, icon_size, icon_size), false)
	else:
		# Fallback to colored circle
		var icon_center = Vector2(x + SLOT_SIZE / 2, y + SLOT_SIZE / 2 - 8)
		panel.draw_circle(icon_center, 16, tool_data["color"])

	# Tool name (abbreviated)
	var display_name = tool_data["display"]
	if display_name.length() > 9:
		display_name = display_name.substr(0, 8) + "."
	panel.draw_string(ThemeDB.fallback_font, Vector2(x + 3, y + SLOT_SIZE - 6), display_name, HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE - 6, 9, Color.WHITE)

func _draw_module_slot(x: float, y: float, module_name: String, highlighted: bool) -> void:
	var module_data = MODULES_DATA.get(module_name, {"display": module_name, "color": Color.WHITE})
	var bg_color = Color(0.2, 0.18, 0.25) if not highlighted else Color(0.3, 0.25, 0.4)
	var border_color = module_data["color"] if highlighted else Color(0.4, 0.35, 0.5)

	panel.draw_rect(Rect2(x, y, SLOT_SIZE, SLOT_SIZE), bg_color)
	panel.draw_rect(Rect2(x, y, SLOT_SIZE, SLOT_SIZE), border_color, false, 2.0)

	# Module icon (use texture if available)
	var icon_texture = MODULE_ICONS.get(module_name)
	if icon_texture:
		var icon_size = 44.0
		var icon_x = x + (SLOT_SIZE - icon_size) / 2
		var icon_y = y + 4
		panel.draw_texture_rect(icon_texture, Rect2(icon_x, icon_y, icon_size, icon_size), false)
	else:
		# Fallback to hexagon shape
		var icon_center = Vector2(x + SLOT_SIZE / 2, y + SLOT_SIZE / 2 - 8)
		var hex_points = PackedVector2Array()
		for i in range(6):
			var angle = i * TAU / 6 - PI / 2
			hex_points.append(icon_center + Vector2(cos(angle), sin(angle)) * 14)
		panel.draw_colored_polygon(hex_points, module_data["color"])

	# Module name (abbreviated)
	var display_name = module_data["display"]
	if display_name.length() > 9:
		display_name = display_name.substr(0, 8) + "."
	panel.draw_string(ThemeDB.fallback_font, Vector2(x + 3, y + SLOT_SIZE - 6), display_name, HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE - 6, 9, Color.WHITE)
