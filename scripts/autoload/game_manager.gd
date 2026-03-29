extends Node
## Global Game Manager - handles game state, room progression, and persistence

# Game state
enum GameState { MENU, PLAYING, PAUSED, ROOM_TRANSITION, PLAYER_DEATH, BOSS_INTRO, VICTORY }
var current_state: GameState = GameState.MENU

# Difficulty system
enum Difficulty { CADET, PILOT, MASTERY }
const DIFFICULTY_BASE_HP: Dictionary = {
	Difficulty.CADET: 5,
	Difficulty.PILOT: 3,
	Difficulty.MASTERY: 1
}
var current_difficulty: Difficulty = Difficulty.PILOT

# Player data
var player_health: int = 3
var player_max_health: int = 3
var player_coins: int = 0
var equipped_tool: String = ""
var owned_tools: Array[String] = []

# Module system
var equipped_module: String = ""
var owned_modules: Array[String] = []

# Hull upgrades (permanent max HP increases)
var hull_upgrade_level: int = 0  # 0-5
const HULL_UPGRADE_PRICES: Array[int] = [1000, 2000, 4000, 7000, 10000]

# Per-room state (resets on room load)
var room_death_count: Dictionary = {}  # room_id -> death count
var phoenix_used_this_room: bool = false
var current_kill_streak: int = 0
var is_phantom_mode: bool = false
var hazard_immunity_remaining: float = 0.0

# Room progression
var current_room: int = 1
var current_chapter: int = 1
var rooms_cleared: Array[int] = []

# Tool prices
const TOOL_PRICES: Dictionary = {
	"vertical_thruster": 250,
	"phalanx_shield": 400,
	"phase_shift": 600,
	"chrono_drive": 800
}

# Module prices
const MODULE_PRICES: Dictionary = {
	# Category A: Survivalists
	"gravity_anchor": 300,
	"phoenix_plating": 500,
	"spectral_phase": 400,
	# Category B: Aggressors
	"hyper_coil": 350,
	"blood_drive_core": 600,
	"reactive_shock_shell": 700,
	# Category C: Specialists
	"bounty_hunter_chip": 450,
	"aviator_gyro": 350
}

# Enemy rewards
const ENEMY_REWARDS: Dictionary = {
	# Chapter 1 enemies
	"sniper": 15,
	"mantis": 25,
	"mortar": 40,
	"furnace_crab": 500,
	# Chapter 2 enemies
	"seeker_beetle": 15,
	"arc_caster": 30,
	"replicator": 50,
	"buffer_drone": 35,
	"amp_pylon": 40,
	"ground_fault_titan": 750,
	# Chapter 3 enemies
	"zone_blade": 45,
	"tri_gunner": 35,
	"harpoon_stalker": 40,
	"aegis_bit": 20,
	"apex_interceptor": 1000,
	# Chapter 4 enemies
	"countdown": 30,
	"mag_mine": 20,
	"chain_link": 25,
	"reactor_beam": 55,
	"tether_anchor": 45,
	"fuel_tank": 35,
	"overcharger": 60,
	"subject_88": 1500,
	# Chapter 5 enemies
	"dragoon": 45,
	"medic_drone": 40,
	"orbital_aegis": 2000
}

# Chapter room mapping
const CHAPTER_ROOMS: Dictionary = {
	1: {"start": 1, "end": 10, "boss": 10, "preboss_shop": 95},
	2: {"start": 100, "end": 121, "boss": 121, "preboss_shop": 1205},
	3: {"start": 200, "end": 221, "boss": 221, "preboss_shop": 2205},
	4: {"start": 300, "end": 331, "boss": 331, "preboss_shop": 3305},
	5: {"start": 401, "end": 409, "boss": 409, "preboss_shop": 4085}
}

# Time scale for Chrono-Drive
var time_scale: float = 1.0

# Pending room rewards (coins awarded when room is cleared, not when enemy dies)
var pending_room_rewards: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()

func _connect_signals() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.all_enemies_killed.connect(_on_all_enemies_killed)
	EventBus.time_scale_changed.connect(_on_time_scale_changed)
	EventBus.tool_purchased.connect(_on_tool_purchased)

func _on_time_scale_changed(scale: float) -> void:
	time_scale = scale
	Engine.time_scale = scale

func _on_player_died(_position: Vector2) -> void:
	# Prevent multiple death handling
	if current_state == GameState.PLAYER_DEATH:
		return
	current_state = GameState.PLAYER_DEATH

	# Record death for Phantom Protocol tracking
	record_room_death()

	# Show death screen instead of immediate respawn
	EventBus.death_screen_shown.emit(get_room_death_count(), can_use_phantom_protocol())

func respawn_player() -> void:
	player_health = player_max_health
	reset_room_state()
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0  # Reset time scale

	# Check if player died in a boss room - respawn at pre-boss shop instead
	var respawn_room = current_room
	for chapter_num in CHAPTER_ROOMS:
		var chapter_data = CHAPTER_ROOMS[chapter_num]
		if current_room == chapter_data["boss"]:
			respawn_room = chapter_data["preboss_shop"]
			break

	load_room(respawn_room)

func respawn_player_for_phantom() -> void:
	## Respawn player for Phantom Protocol - does NOT reset phantom-related state
	player_health = player_max_health
	phoenix_used_this_room = false
	current_kill_streak = 0
	hazard_immunity_remaining = 0.0
	# NOTE: Do NOT reset is_phantom_mode here - it gets set by activate_phantom_protocol()
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0
	load_room(current_room)

func _on_enemy_killed(enemy: Node, reward: int, _position: Vector2) -> void:
	# Check for module coin modifiers (e.g., Bounty Hunter Chip)
	var modified_reward = reward
	var player_nodes = get_tree().get_nodes_in_group("player")
	if not player_nodes.is_empty():
		var player = player_nodes[0]
		if player.equipped_module and player.equipped_module.has_method("on_coin_drop"):
			var enemy_type = enemy.get_class() if enemy else "unknown"
			modified_reward = player.equipped_module.on_coin_drop(reward, enemy_type)

	# Accumulate rewards - coins are awarded when room is cleared, not immediately
	pending_room_rewards += modified_reward

	# Check if all enemies are killed (deferred to avoid issues during physics)
	call_deferred("_check_all_enemies_killed")

func _on_all_enemies_killed() -> void:
	# Coins are now awarded when exiting the room, not when enemies are killed
	pass

func _check_all_enemies_killed() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count = 0
	for enemy in enemies:
		# Check if enemy has is_dead property (it's a variable, not a method)
		if "is_dead" in enemy:
			if not enemy.is_dead:
				alive_count += 1
		else:
			# If no is_dead property, assume alive
			alive_count += 1

	if alive_count == 0:
		EventBus.all_enemies_killed.emit()

func _on_tool_purchased(tool_name: String, cost: int) -> void:
	if player_coins >= cost and tool_name not in owned_tools:
		player_coins -= cost
		owned_tools.append(tool_name)
		equipped_tool = tool_name
		EventBus.coins_changed.emit(player_coins)
		EventBus.tool_equipped.emit(tool_name)

func add_coins(amount: int) -> void:
	player_coins += amount
	EventBus.coins_changed.emit(player_coins)

func damage_player(amount: int) -> void:
	player_health -= amount
	player_health = max(player_health, 0)  # Clamp to 0
	EventBus.player_damaged.emit(player_health, player_max_health)
	# Note: player_died is emitted by the Player script, not here

func load_room(room_id: int) -> void:
	current_room = room_id
	pending_room_rewards = 0  # Reset pending rewards when loading a room
	player_health = player_max_health  # Restore full HP when entering a new room
	var room_path: String

	# Determine room path based on room ID
	# Special shop rooms (stored with extra digits to avoid conflicts)
	if room_id == 1205:
		# Special case: Ch2 Pre-boss shop (Room 20.5)
		room_path = "res://scenes/rooms/ch2/room_ch2_20_5.tscn"
	elif room_id == 95:
		# Special case: Ch1 Pre-boss shop (Room 9.5)
		room_path = "res://scenes/rooms/room_9_5.tscn"
	elif room_id == 2005:
		# Special case: Ch3 Shop 0.5
		room_path = "res://scenes/rooms/ch3/room_ch3_0_5.tscn"
	elif room_id == 2055:
		# Special case: Ch3 Shop 5.5
		room_path = "res://scenes/rooms/ch3/room_ch3_5_5.tscn"
	elif room_id == 2105:
		# Special case: Ch3 Shop 10.5
		room_path = "res://scenes/rooms/ch3/room_ch3_10_5.tscn"
	elif room_id == 2205:
		# Special case: Ch3 Pre-boss shop (Room 20.5)
		room_path = "res://scenes/rooms/ch3/room_ch3_20_5.tscn"
	# Chapter 4 shop rooms
	elif room_id == 3055:
		room_path = "res://scenes/rooms/ch4/room_ch4_5_5.tscn"
	elif room_id == 3105:
		room_path = "res://scenes/rooms/ch4/room_ch4_10_5.tscn"
	elif room_id == 3205:
		room_path = "res://scenes/rooms/ch4/room_ch4_20_5.tscn"
	elif room_id == 3305:
		room_path = "res://scenes/rooms/ch4/room_ch4_30_5.tscn"
	# Chapter 5 shop rooms
	elif room_id == 4055:
		room_path = "res://scenes/rooms/ch5/room_ch5_4_5.tscn"
	elif room_id == 4085:
		room_path = "res://scenes/rooms/ch5/room_ch5_8_5.tscn"
	# Standard chapter routing (check order matters: Ch5 > Ch4 > Ch3 > Ch2 > Ch1)
	elif room_id >= 400 and room_id < 500:
		# Chapter 5 rooms (400-499 maps to ch5_0, ch5_1, etc.)
		var ch5_room = room_id - 400
		room_path = "res://scenes/rooms/ch5/room_ch5_%d.tscn" % ch5_room
	elif room_id >= 300 and room_id < 400:
		# Chapter 4 rooms (300-399 maps to ch4_0, ch4_1, etc.)
		var ch4_room = room_id - 300
		room_path = "res://scenes/rooms/ch4/room_ch4_%d.tscn" % ch4_room
	elif room_id >= 200 and room_id < 300:
		# Chapter 3 rooms (200-299 maps to ch3_0, ch3_1, etc.)
		var ch3_room = room_id - 200
		room_path = "res://scenes/rooms/ch3/room_ch3_%d.tscn" % ch3_room
	elif room_id >= 100 and room_id < 200:
		# Chapter 2 rooms (100-199 maps to ch2_0, ch2_1, etc.)
		var ch2_room = room_id - 100
		room_path = "res://scenes/rooms/ch2/room_ch2_%d.tscn" % ch2_room
	elif room_id >= 1 and room_id < 100:
		# Chapter 1 rooms (1-99, excluding special IDs like 95)
		room_path = "res://scenes/rooms/room_%d.tscn" % room_id
	else:
		# Invalid room ID - fallback to room 1
		push_error("Invalid room ID: %d - falling back to room 1" % room_id)
		room_path = "res://scenes/rooms/room_1.tscn"
		current_room = 1

	if ResourceLoader.exists(room_path):
		get_tree().change_scene_to_file(room_path)
		EventBus.room_entered.emit(room_id)
	else:
		push_error("Room %d does not exist at path: %s" % [room_id, room_path])

func next_room() -> void:
	# Reset phantom mode when progressing to next room
	is_phantom_mode = false

	# Award accumulated coins when player exits the room
	if pending_room_rewards > 0:
		add_coins(pending_room_rewards)
		pending_room_rewards = 0

	if current_room not in rooms_cleared:
		rooms_cleared.append(current_room)
		EventBus.room_cleared.emit(current_room)

	# Handle special shop room IDs first (they use large numbers to avoid conflicts)
	# Chapter 5 shops
	if current_room == 4055:
		current_room = 405  # Continue after shop (position 5 -> room 6 which is ID 405)
	elif current_room == 4085:
		current_room = 409  # Pre-boss shop -> boss room
	# Chapter 4 shops
	elif current_room == 3055:
		current_room = 306  # Continue after shop 5.5
	elif current_room == 3105:
		current_room = 311  # Continue after shop 10.5
	elif current_room == 3205:
		current_room = 321  # Continue after shop 20.5
	elif current_room == 3305:
		current_room = 331  # Go to Ch4 boss room
	# Chapter 2 pre-boss shop (1205 = room 120.5)
	elif current_room == 1205:
		current_room = 121  # Go to Ch2 boss room
	# Chapter 3 shops
	elif current_room == 2005:
		current_room = 201  # Continue after shop 0.5
	elif current_room == 2055:
		current_room = 206  # Continue after shop 5.5
	elif current_room == 2105:
		current_room = 211  # Continue after shop 10.5
	elif current_room == 2205:
		current_room = 221  # Go to Ch3 boss room
	# Handle chapter 5 room progression (401-409)
	# Room flow: 401 -> 402 -> 403 -> 404 -> 4055 (shop) -> 405 -> 406 -> 407 -> 408 -> 4085 (preboss shop) -> 409 (boss)
	elif current_room >= 400 and current_room < 500:
		if current_room == 404:
			current_room = 4055  # Shop at position 5
		elif current_room == 408:
			current_room = 4085  # Pre-boss shop
		elif current_room == 409:
			# Chapter 5 boss room - can't skip past this
			return
		else:
			current_room += 1
	# Handle chapter 4 room progression (300-399)
	elif current_room >= 300 and current_room < 400:
		if current_room == 305:
			current_room = 3055  # Shop 5.5
		elif current_room == 310:
			current_room = 3105  # Shop 10.5
		elif current_room == 320:
			current_room = 3205  # Shop 20.5
		elif current_room == 330:
			current_room = 3305  # Pre-boss shop (30.5)
		elif current_room == 331:
			# Chapter 4 boss room - can't skip past this
			return
		else:
			current_room += 1
	# Handle chapter 3 room progression (200-299)
	elif current_room >= 200 and current_room < 300:
		if current_room == 205:
			current_room = 2055  # Shop 5.5
		elif current_room == 210:
			current_room = 2105  # Shop 10.5
		elif current_room == 220:
			current_room = 2205  # Shop 20.5
		elif current_room == 221:
			# Chapter 3 boss room - can't skip past this
			return
		else:
			current_room += 1
	# Handle chapter 2 room progression (100-199)
	elif current_room >= 100 and current_room < 200:
		if current_room == 120:
			current_room = 1205  # Pre-boss shop (120.5)
		elif current_room == 121:
			# Chapter 2 boss room - can't skip past this
			return
		else:
			current_room += 1
	# Handle chapter 1 room progression (1-99)
	elif current_room >= 1 and current_room < 100:
		if current_room == 10:
			# Room 10 is the boss room - can't skip past this
			return
		elif current_room == 9:
			current_room = 95  # Pre-boss shop (9.5)
		elif current_room == 95:
			current_room = 10  # Boss room
		else:
			current_room += 1
	else:
		# Invalid room ID - shouldn't happen
		push_error("next_room() called with invalid current_room: %d" % current_room)
		return

	# Auto-save progress when moving to next room
	save_game()

	# Use call_deferred to safely change scene outside physics callback
	call_deferred("_deferred_load_room", current_room)

func _deferred_load_room(room_id: int) -> void:
	load_room(room_id)

func start_game() -> void:
	# Reset player data for new game
	player_max_health = get_effective_max_hp()
	player_health = player_max_health
	player_coins = 0
	equipped_tool = ""
	owned_tools = []
	equipped_module = ""
	owned_modules = []
	current_room = 1
	rooms_cleared = []
	pending_room_rewards = 0
	room_death_count = {}
	reset_room_state()
	current_state = GameState.PLAYING
	load_room(1)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		EventBus.game_paused.emit()

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		EventBus.game_resumed.emit()

func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func can_afford_tool(tool_name: String) -> bool:
	return player_coins >= TOOL_PRICES.get(tool_name, 9999)

func get_tool_price(tool_name: String) -> int:
	return TOOL_PRICES.get(tool_name, 0)

func unequip_tool() -> void:
	## Unequip current tool
	equipped_tool = ""
	EventBus.tool_equipped.emit("")

func start_chapter_2() -> void:
	# Transition to Chapter 2 after defeating Chapter 1 boss
	current_chapter = 2
	current_room = 100  # Chapter 2 Room 0 (shop/rest)
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0
	call_deferred("load_room", 100)

func get_current_chapter() -> int:
	if current_room >= 400:
		return 5
	elif current_room >= 300:
		return 4
	elif current_room >= 200:
		return 3
	elif current_room >= 100:
		return 2
	return 1

func start_chapter_3() -> void:
	# Transition to Chapter 3 after defeating Chapter 2 boss
	current_chapter = 3
	current_room = 200  # Chapter 3 Room 0 (shop/rest)
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0
	call_deferred("load_room", 200)

func start_chapter_4() -> void:
	# Transition to Chapter 4 after defeating Chapter 3 boss
	current_chapter = 4
	current_room = 300  # Chapter 4 Room 0 (shop/rest)
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0
	call_deferred("load_room", 300)

func start_chapter_5() -> void:
	# Transition to Chapter 5 after defeating Chapter 4 boss
	current_chapter = 5
	current_room = 401  # Chapter 5 Room 1 (The Dragoon Test)
	current_state = GameState.PLAYING
	Engine.time_scale = 1.0
	call_deferred("load_room", 401)

# ============================================================
# DIFFICULTY SYSTEM
# ============================================================

func get_effective_max_hp() -> int:
	## Calculate max HP from difficulty base + hull upgrades
	return DIFFICULTY_BASE_HP[current_difficulty] + hull_upgrade_level

func set_difficulty(diff: Difficulty) -> void:
	## Change difficulty and recalculate HP
	current_difficulty = diff
	player_max_health = get_effective_max_hp()
	# Set current health to new max (full heal on difficulty change)
	player_health = player_max_health
	EventBus.difficulty_changed.emit(diff)
	# Update HUD with new HP values
	EventBus.player_damaged.emit(player_health, player_max_health)

func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.CADET:
			return "Cadet"
		Difficulty.PILOT:
			return "Pilot"
		Difficulty.MASTERY:
			return "Mastery"
	return "Unknown"

func is_cadet_difficulty() -> bool:
	## Returns true if on Cadet (easy) mode
	return current_difficulty == Difficulty.CADET

# ============================================================
# HULL UPGRADE SYSTEM
# ============================================================

func purchase_hull_upgrade() -> bool:
	## Purchase next hull upgrade level. Returns true on success.
	if hull_upgrade_level >= 5:
		return false  # Already maxed
	var price = HULL_UPGRADE_PRICES[hull_upgrade_level]
	if player_coins < price:
		return false  # Can't afford
	player_coins -= price
	hull_upgrade_level += 1
	player_max_health = get_effective_max_hp()
	# Also increase current HP by 1 (the upgrade gives +1 max HP)
	player_health = min(player_health + 1, player_max_health)
	EventBus.hull_upgrade_purchased.emit(hull_upgrade_level, player_max_health)
	EventBus.coins_changed.emit(player_coins)
	EventBus.player_damaged.emit(player_health, player_max_health)  # Update HUD
	return true

func get_next_hull_upgrade_price() -> int:
	## Get price of next hull upgrade, or -1 if maxed
	if hull_upgrade_level >= 5:
		return -1
	return HULL_UPGRADE_PRICES[hull_upgrade_level]

func can_afford_hull_upgrade() -> bool:
	var price = get_next_hull_upgrade_price()
	return price > 0 and player_coins >= price

# ============================================================
# MODULE SYSTEM
# ============================================================

func equip_module(module_name: String) -> void:
	## Equip a module (player can only have 1 equipped)
	equipped_module = module_name
	EventBus.module_equipped.emit(module_name)

func unequip_module() -> void:
	## Unequip current module
	equipped_module = ""
	EventBus.module_equipped.emit("")

func purchase_module(module_name: String) -> bool:
	## Purchase a module. Returns true on success.
	if module_name in owned_modules:
		return false  # Already owned
	var price = MODULE_PRICES.get(module_name, 9999)
	if player_coins < price:
		return false  # Can't afford
	player_coins -= price
	owned_modules.append(module_name)
	equipped_module = module_name  # Auto-equip on purchase
	EventBus.coins_changed.emit(player_coins)
	EventBus.module_equipped.emit(module_name)
	return true

func can_afford_module(module_name: String) -> bool:
	return player_coins >= MODULE_PRICES.get(module_name, 9999)

func get_module_price(module_name: String) -> int:
	return MODULE_PRICES.get(module_name, 0)

# ============================================================
# PHANTOM PROTOCOL (Level Skip)
# ============================================================

func record_room_death() -> void:
	## Record a death in the current room (for Phantom Protocol unlock)
	if current_room not in room_death_count:
		room_death_count[current_room] = 0
	room_death_count[current_room] += 1

func get_room_death_count() -> int:
	## Get number of deaths in current room
	return room_death_count.get(current_room, 0)

func can_use_phantom_protocol() -> bool:
	## Returns true if player has died 5+ times in current room
	## Disabled during boss fights
	if is_phantom_mode:
		return false

	# Check if current room is a boss room
	for chapter_num in CHAPTER_ROOMS:
		var chapter_data = CHAPTER_ROOMS[chapter_num]
		if current_room == chapter_data["boss"]:
			return false  # No rescue drone during boss fights

	return get_room_death_count() >= 5

func activate_phantom_protocol() -> void:
	## Spawn rescue drone to carry player through the room (no coins earned)
	is_phantom_mode = true  # Still track that we're in phantom mode
	pending_room_rewards = 0  # No coin reward in phantom mode
	EventBus.phantom_protocol_activated.emit()

	# Wait for scene to be ready before spawning drone
	get_tree().tree_changed.connect(_on_tree_changed_spawn_drone, CONNECT_ONE_SHOT)

func _on_tree_changed_spawn_drone() -> void:
	# Extra frame to ensure scene is fully initialized
	await get_tree().process_frame
	_spawn_phantom_drone()

func _spawn_phantom_drone() -> void:
	## Spawn the rescue drone in the loaded scene
	if get_tree().current_scene == null:
		push_error("Cannot spawn phantom drone - no current scene")
		return
	var drone_scene = preload("res://scenes/entities/phantom_drone.tscn")
	var drone = drone_scene.instantiate()
	get_tree().current_scene.add_child(drone)

# ============================================================
# PER-ROOM STATE MANAGEMENT
# ============================================================

func reset_room_state() -> void:
	## Reset per-room state variables (called on room load/respawn)
	## NOTE: is_phantom_mode is NOT reset here - it's managed by phantom protocol
	## and reset in next_room() when progressing to next room
	phoenix_used_this_room = false
	current_kill_streak = 0
	hazard_immunity_remaining = 0.0

func increment_kill_streak() -> void:
	## Track kills for Blood-Drive Core module
	current_kill_streak += 1
	EventBus.kill_streak_updated.emit(current_kill_streak)

func reset_kill_streak() -> void:
	current_kill_streak = 0

# ============================================================
# SAVE/LOAD SYSTEM
# ============================================================

const SAVE_FILE_PATH: String = "user://air_strider_save.dat"

func save_game() -> void:
	## Save current progress to file
	var save_data: Dictionary = {
		"version": 1,
		"current_room": current_room,
		"current_chapter": current_chapter,
		"rooms_cleared": rooms_cleared,
		"player_coins": player_coins,
		"equipped_tool": equipped_tool,
		"owned_tools": owned_tools,
		"equipped_module": equipped_module,
		"owned_modules": owned_modules,
		"hull_upgrade_level": hull_upgrade_level,
		"current_difficulty": current_difficulty
	}

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Game saved to %s" % SAVE_FILE_PATH)
	else:
		push_error("Failed to save game: %s" % FileAccess.get_open_error())

func load_game() -> bool:
	## Load progress from file. Returns true if successful.
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to load game: %s" % FileAccess.get_open_error())
		return false

	var save_data = file.get_var()
	file.close()

	if not save_data is Dictionary:
		push_error("Invalid save data format")
		return false

	# Restore saved state
	current_room = save_data.get("current_room", 1)
	current_chapter = save_data.get("current_chapter", 1)
	rooms_cleared = save_data.get("rooms_cleared", [])
	player_coins = save_data.get("player_coins", 0)
	equipped_tool = save_data.get("equipped_tool", "")
	owned_tools = save_data.get("owned_tools", [])
	equipped_module = save_data.get("equipped_module", "")
	owned_modules = save_data.get("owned_modules", [])
	hull_upgrade_level = save_data.get("hull_upgrade_level", 0)
	current_difficulty = save_data.get("current_difficulty", Difficulty.PILOT)

	# Recalculate HP based on difficulty and upgrades
	player_max_health = get_effective_max_hp()
	player_health = player_max_health

	print("Game loaded from %s - Room %d" % [SAVE_FILE_PATH, current_room])
	return true

func has_save_file() -> bool:
	## Check if a save file exists
	return FileAccess.file_exists(SAVE_FILE_PATH)

func delete_save() -> void:
	## Delete the save file
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("Save file deleted")

func continue_game() -> void:
	## Load saved progress and continue playing
	if load_game():
		reset_room_state()
		room_death_count = {}
		pending_room_rewards = 0
		current_state = GameState.PLAYING
		load_room(current_room)
	else:
		# No save file, start new game
		start_game()

func start_new_game() -> void:
	## Start a fresh new game (resets all progress)
	delete_save()
	# Reset hull upgrades for new game
	hull_upgrade_level = 0
	start_game()
