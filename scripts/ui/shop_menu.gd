extends CanvasLayer
class_name ShopMenu
## Full-screen shop menu with mouse controls - opened from Fabricator

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

# Tab system
enum ShopTab { TOOLS, MODULES, UPGRADES }
var current_tab: ShopTab = ShopTab.TOOLS

# Item data
const TOOLS: Array = [
	{"name": "vertical_thruster", "display": "Vertical Thruster", "price": 250, "desc": "Launch upward instantly", "color": Color(0.2, 0.8, 0.2)},
	{"name": "phalanx_shield", "display": "Phalanx Shield", "price": 400, "desc": "Block projectiles", "color": Color(0.2, 0.5, 1.0)},
	{"name": "phase_shift", "display": "Phase Shift", "price": 600, "desc": "Dash with invincibility", "color": Color(0.8, 0.2, 0.8)},
	{"name": "chrono_drive", "display": "Chrono-Drive", "price": 800, "desc": "Slow down time", "color": Color(1.0, 0.8, 0.2)}
]

const MODULES: Array = [
	{"name": "gravity_anchor", "display": "Gravity Anchor", "price": 300, "desc": "Pit = 1 dmg + respawn", "color": Color(0.3, 0.6, 1.0)},
	{"name": "phoenix_plating", "display": "Phoenix Plating", "price": 500, "desc": "Survive 1 fatal hit/room", "color": Color(1.0, 0.4, 0.0)},
	{"name": "spectral_phase", "display": "Spectral Phase", "price": 400, "desc": "Phase platforms, grapple walls", "color": Color(0.6, 0.2, 0.9)},
	{"name": "hyper_coil", "display": "Hyper-Coil", "price": 350, "desc": "30% faster charge", "color": Color(1.0, 0.2, 0.2)},
	{"name": "blood_drive_core", "display": "Blood-Drive", "price": 600, "desc": "5 kills = heal orb", "color": Color(0.8, 0.1, 0.1)},
	{"name": "reactive_shock_shell", "display": "Shock-Shell", "price": 700, "desc": "Damage = shockwave", "color": Color(0.6, 0.2, 1.0)},
	{"name": "bounty_hunter_chip", "display": "Bounty Chip", "price": 450, "desc": "50% double coins", "color": Color(1.0, 0.85, 0.0)},
	{"name": "aviator_gyro", "display": "Aviator Gyro", "price": 350, "desc": "Fall 50% slower", "color": Color(0.4, 0.8, 1.0)}
]

# Layout constants
const PANEL_WIDTH: float = 700.0
const PANEL_HEIGHT: float = 500.0
const ITEM_WIDTH: float = 150.0
const ITEM_HEIGHT: float = 100.0
const ITEM_PADDING: float = 10.0

# UI tracking
var mouse_pos: Vector2 = Vector2.ZERO
var hovered_item: int = -1
var hovered_tab: int = -1

@onready var panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 100
	panel.draw.connect(_draw_panel)
	panel.gui_input.connect(_on_panel_input)

func _process(_delta: float) -> void:
	if not is_open:
		return

	mouse_pos = panel.get_local_mouse_position()
	_update_hovered_elements()
	panel.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Close with Escape or B
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		close_shop()
		get_viewport().set_input_as_handled()

func _on_panel_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check tab clicks
		if hovered_tab >= 0:
			current_tab = hovered_tab as ShopTab
			hovered_item = -1
		# Check item clicks
		elif hovered_item >= 0:
			_try_purchase(hovered_item)

func open_shop() -> void:
	is_open = true
	visible = true
	current_tab = ShopTab.TOOLS
	hovered_item = -1
	hovered_tab = -1
	get_tree().paused = true
	EventBus.shop_opened.emit()

func close_shop() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	EventBus.shop_closed.emit()

func _update_hovered_elements() -> void:
	hovered_item = -1
	hovered_tab = -1

	# Check tab hover
	var tab_y = 50.0
	var tab_width = 100.0
	var tab_height = 35.0
	var tab_start_x = 50.0

	for i in range(3):
		var tab_x = tab_start_x + i * (tab_width + 10)
		var tab_rect = Rect2(tab_x, tab_y, tab_width, tab_height)
		if tab_rect.has_point(mouse_pos):
			hovered_tab = i
			return

	# Check item hover based on current tab
	var items = _get_current_items()
	var start_x = 50.0
	var start_y = 110.0
	var cols = 4

	for i in range(items.size()):
		var col = i % cols
		var row = i / cols
		var item_x = start_x + col * (ITEM_WIDTH + ITEM_PADDING)
		var item_y = start_y + row * (ITEM_HEIGHT + ITEM_PADDING)
		var item_rect = Rect2(item_x, item_y, ITEM_WIDTH, ITEM_HEIGHT)

		if item_rect.has_point(mouse_pos):
			hovered_item = i
			return

	# Check upgrade button hover (for upgrades tab)
	if current_tab == ShopTab.UPGRADES:
		var button_rect = Rect2(PANEL_WIDTH / 2 - 100, 280, 200, 50)
		if button_rect.has_point(mouse_pos) and GameManager.hull_upgrade_level < 5:
			hovered_item = 0

func _get_current_items() -> Array:
	match current_tab:
		ShopTab.TOOLS:
			return TOOLS
		ShopTab.MODULES:
			return MODULES
		ShopTab.UPGRADES:
			return []
	return []

func _try_purchase(index: int) -> void:
	match current_tab:
		ShopTab.TOOLS:
			_try_purchase_tool(index)
		ShopTab.MODULES:
			_try_purchase_module(index)
		ShopTab.UPGRADES:
			_try_purchase_hull_upgrade()

func _try_purchase_tool(index: int) -> void:
	if index >= TOOLS.size():
		return
	var tool_data = TOOLS[index]
	var tool_name = tool_data["name"]
	var price = tool_data["price"]

	if tool_name in GameManager.owned_tools:
		# Already owned - just equip
		GameManager.equipped_tool = tool_name
		EventBus.tool_equipped.emit(tool_name)
	elif GameManager.can_afford_tool(tool_name):
		# Purchase
		EventBus.tool_purchased.emit(tool_name, price)

func _try_purchase_module(index: int) -> void:
	if index >= MODULES.size():
		return
	var module_data = MODULES[index]
	var module_name = module_data["name"]

	if module_name in GameManager.owned_modules:
		# Already owned - just equip
		GameManager.equip_module(module_name)
	elif GameManager.can_afford_module(module_name):
		# Purchase
		GameManager.purchase_module(module_name)

func _try_purchase_hull_upgrade() -> void:
	GameManager.purchase_hull_upgrade()

func _draw_panel() -> void:
	# Background overlay
	panel.draw_rect(Rect2(-1000, -1000, 3000, 3000), Color(0, 0, 0, 0.7))

	# Main panel
	var panel_rect = Rect2(0, 0, PANEL_WIDTH, PANEL_HEIGHT)
	panel.draw_rect(panel_rect, Color(0.1, 0.1, 0.15, 0.98))
	panel.draw_rect(panel_rect, Color(0.3, 0.5, 0.7), false, 3.0)

	# Title
	panel.draw_string(ThemeDB.fallback_font, Vector2(50, 35), "FABRICATOR SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.8, 0.3))

	# Coins display
	panel.draw_string(ThemeDB.fallback_font, Vector2(PANEL_WIDTH - 180, 35), "Coins: $" + str(GameManager.player_coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)

	# Draw tabs
	_draw_tabs()

	# Draw content based on current tab
	match current_tab:
		ShopTab.TOOLS:
			_draw_items_grid(TOOLS)
		ShopTab.MODULES:
			_draw_items_grid(MODULES)
		ShopTab.UPGRADES:
			_draw_upgrades()

	# Instructions
	panel.draw_string(ThemeDB.fallback_font, Vector2(50, PANEL_HEIGHT - 20), "Click to Buy/Equip  |  ESC or B to Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5))

func _draw_tabs() -> void:
	var tab_names = ["TOOLS", "MODULES", "UPGRADES"]
	var tab_y = 50.0
	var tab_width = 100.0
	var tab_height = 35.0
	var tab_start_x = 50.0

	for i in range(3):
		var tab_x = tab_start_x + i * (tab_width + 10)
		var is_active = (i == current_tab)
		var is_hovered = (i == hovered_tab)

		var tab_color = Color(0.2, 0.35, 0.5) if is_active else Color(0.15, 0.15, 0.2)
		if is_hovered and not is_active:
			tab_color = Color(0.18, 0.25, 0.35)

		var border_color = Color(0.4, 0.8, 1.0) if is_active else Color(0.3, 0.3, 0.4)
		if is_hovered:
			border_color = Color(0.5, 0.8, 1.0)

		panel.draw_rect(Rect2(tab_x, tab_y, tab_width, tab_height), tab_color)
		panel.draw_rect(Rect2(tab_x, tab_y, tab_width, tab_height), border_color, false, 2.0)
		panel.draw_string(ThemeDB.fallback_font, Vector2(tab_x + 10, tab_y + 24), tab_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if is_active else Color(0.6, 0.6, 0.6))

func _draw_items_grid(items: Array) -> void:
	var start_x = 50.0
	var start_y = 110.0
	var cols = 4

	for i in range(items.size()):
		var item = items[i]
		var col = i % cols
		var row = i / cols
		var item_x = start_x + col * (ITEM_WIDTH + ITEM_PADDING)
		var item_y = start_y + row * (ITEM_HEIGHT + ITEM_PADDING)

		_draw_item_card(item_x, item_y, item, i == hovered_item)

func _draw_item_card(x: float, y: float, item: Dictionary, is_hovered: bool) -> void:
	var item_name = item["name"]
	var is_tool = item in TOOLS
	var is_owned = false
	var is_equipped = false
	var can_afford = false

	if is_tool:
		is_owned = item_name in GameManager.owned_tools
		is_equipped = item_name == GameManager.equipped_tool
		can_afford = GameManager.can_afford_tool(item_name)
	else:
		is_owned = item_name in GameManager.owned_modules
		is_equipped = item_name == GameManager.equipped_module
		can_afford = GameManager.can_afford_module(item_name)

	# Background
	var bg_color = Color(0.15, 0.15, 0.2)
	if is_hovered:
		bg_color = Color(0.2, 0.25, 0.35)
	if is_equipped:
		bg_color = Color(0.15, 0.25, 0.15)

	panel.draw_rect(Rect2(x, y, ITEM_WIDTH, ITEM_HEIGHT), bg_color)

	# Border
	var border_color = item.get("color", Color.WHITE)
	if is_hovered:
		border_color = border_color.lightened(0.3)
	panel.draw_rect(Rect2(x, y, ITEM_WIDTH, ITEM_HEIGHT), border_color, false, 2.0 if is_hovered else 1.0)

	# Icon (use texture if available, fallback to shapes)
	var icon_size = 36.0
	var icon_x = x + 8
	var icon_y = y + 8
	var icon_texture: Texture2D = null

	if is_tool:
		icon_texture = TOOL_ICONS.get(item_name)
	else:
		icon_texture = MODULE_ICONS.get(item_name)

	if icon_texture:
		panel.draw_texture_rect(icon_texture, Rect2(icon_x, icon_y, icon_size, icon_size), false)
	else:
		# Fallback to procedural shapes
		var icon_center = Vector2(x + 26, y + 26)
		if is_tool:
			panel.draw_circle(icon_center, 16, item.get("color", Color.WHITE))
		else:
			var hex_points = PackedVector2Array()
			for j in range(6):
				var angle = j * TAU / 6 - PI / 2
				hex_points.append(icon_center + Vector2(cos(angle), sin(angle)) * 14)
			panel.draw_colored_polygon(hex_points, item.get("color", Color.WHITE))

	# Name (positioned to the right of icon)
	panel.draw_string(ThemeDB.fallback_font, Vector2(x + 50, y + 22), item["display"], HORIZONTAL_ALIGNMENT_LEFT, ITEM_WIDTH - 55, 12, Color.WHITE)

	# Description
	panel.draw_string(ThemeDB.fallback_font, Vector2(x + 50, y + 40), item["desc"], HORIZONTAL_ALIGNMENT_LEFT, ITEM_WIDTH - 55, 10, Color(0.6, 0.6, 0.6))

	# Status/Price
	var status_text = ""
	var status_color = Color.YELLOW

	if is_equipped:
		status_text = "EQUIPPED"
		status_color = Color(0.3, 1.0, 0.3)
	elif is_owned:
		status_text = "Click to Equip"
		status_color = Color(0.5, 0.8, 0.5)
	else:
		status_text = "$" + str(item["price"])
		if can_afford:
			status_color = Color.YELLOW
			if is_hovered:
				status_text = "Click to Buy - $" + str(item["price"])
		else:
			status_color = Color(0.8, 0.3, 0.3)
			status_text = "$" + str(item["price"]) + " (Need more)"

	panel.draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + ITEM_HEIGHT - 12), status_text, HORIZONTAL_ALIGNMENT_LEFT, ITEM_WIDTH - 20, 11, status_color)

func _draw_upgrades() -> void:
	var center_x = PANEL_WIDTH / 2
	var start_y = 130.0

	# Title
	panel.draw_string(ThemeDB.fallback_font, Vector2(center_x - 120, start_y), "HULL REINFORCEMENT", HORIZONTAL_ALIGNMENT_CENTER, 240, 22, Color.WHITE)

	# Current HP info
	var current_max = GameManager.get_effective_max_hp()
	var base_hp = GameManager.DIFFICULTY_BASE_HP[GameManager.current_difficulty]
	var info_text = "Current Max HP: %d (Base: %d + Upgrades: %d)" % [current_max, base_hp, GameManager.hull_upgrade_level]
	panel.draw_string(ThemeDB.fallback_font, Vector2(center_x - 180, start_y + 40), info_text, HORIZONTAL_ALIGNMENT_CENTER, 360, 14, Color(0.7, 0.7, 0.7))

	# Progress bar
	var bar_width = 400.0
	var bar_height = 30.0
	var bar_x = center_x - bar_width / 2
	var bar_y = start_y + 70

	panel.draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.15, 0.15, 0.2))

	var segment_width = bar_width / 5
	for i in range(5):
		var seg_x = bar_x + i * segment_width
		if i < GameManager.hull_upgrade_level:
			panel.draw_rect(Rect2(seg_x + 2, bar_y + 2, segment_width - 4, bar_height - 4), Color(0.3, 0.8, 0.3))
		panel.draw_line(Vector2(seg_x, bar_y), Vector2(seg_x, bar_y + bar_height), Color(0.3, 0.3, 0.4), 2.0)
		panel.draw_string(ThemeDB.fallback_font, Vector2(seg_x + segment_width / 2 - 8, bar_y + 22), "+%d HP" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	panel.draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.4, 0.4, 0.5), false, 2.0)

	# Upgrade button
	var button_y = start_y + 140
	var button_width = 250.0
	var button_height = 50.0
	var button_x = center_x - button_width / 2

	if GameManager.hull_upgrade_level >= 5:
		# Maxed out
		panel.draw_rect(Rect2(button_x, button_y, button_width, button_height), Color(0.2, 0.3, 0.2))
		panel.draw_rect(Rect2(button_x, button_y, button_width, button_height), Color(0.3, 0.6, 0.3), false, 2.0)
		panel.draw_string(ThemeDB.fallback_font, Vector2(button_x + 40, button_y + 32), "MAX LEVEL REACHED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1.0, 0.3))
	else:
		var next_price = GameManager.get_next_hull_upgrade_price()
		var can_afford = GameManager.can_afford_hull_upgrade()
		var is_hovered = hovered_item == 0

		var button_color = Color(0.2, 0.3, 0.4)
		if is_hovered and can_afford:
			button_color = Color(0.25, 0.4, 0.5)
		elif not can_afford:
			button_color = Color(0.25, 0.2, 0.2)

		var border_color = Color(0.4, 0.8, 1.0) if can_afford else Color(0.5, 0.3, 0.3)
		if is_hovered:
			border_color = border_color.lightened(0.2)

		panel.draw_rect(Rect2(button_x, button_y, button_width, button_height), button_color)
		panel.draw_rect(Rect2(button_x, button_y, button_width, button_height), border_color, false, 2.0)

		var button_text = "UPGRADE +1 HP - $%d" % next_price
		var text_color = Color.WHITE if can_afford else Color(0.6, 0.4, 0.4)
		panel.draw_string(ThemeDB.fallback_font, Vector2(button_x + 25, button_y + 32), button_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

		if not can_afford:
			panel.draw_string(ThemeDB.fallback_font, Vector2(button_x + 60, button_y + 70), "Not enough coins", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.4, 0.4))
