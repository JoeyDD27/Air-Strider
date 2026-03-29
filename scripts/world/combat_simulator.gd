extends RoomBase
class_name CombatSimulator
## Grinding arena with infinite enemy waves - coins awarded immediately

var wave_number: int = 0
var enemies_per_wave: int = 3
var spawn_timer: float = 0.0
var coins_earned: int = 0
var is_active: bool = true
var wave_delay: float = 2.0

# Room to return to when exiting
var return_room: int = 1

# Available enemy types (cycle through based on wave)
const WAVE_ENEMIES: Array = [
	# Wave 1-2: Easy enemies
	["res://scenes/entities/sniper.tscn", "res://scenes/entities/sniper.tscn"],
	# Wave 3-4: Medium enemies
	["res://scenes/entities/sniper.tscn", "res://scenes/entities/mantis.tscn"],
	# Wave 5+: Mixed harder enemies
	["res://scenes/entities/sniper.tscn", "res://scenes/entities/mantis.tscn", "res://scenes/entities/mortar.tscn"]
]

# Exit terminal in room
var exit_terminal: Area2D = null

func _ready() -> void:
	# Set room properties
	room_id = -1  # Special ID for simulator
	room_name = "Combat Simulator"
	has_floor_hazard = false  # No pit death in simulator
	room_width = 1600.0
	room_height = 800.0
	floor_y = 700.0

	# Store return room before anything else
	return_room = GameManager.current_room

	super._ready()

	# Setup simulator-specific elements
	_setup_exit_terminal()
	_add_death_screen()

	# Connect to enemy killed for immediate coin reward
	EventBus.enemy_killed.connect(_on_sim_enemy_killed)

	# Override player death behavior
	EventBus.player_died.connect(_on_sim_player_died)

	EventBus.simulator_entered.emit()

func _setup_exit_terminal() -> void:
	# Create exit terminal near spawn
	exit_terminal = Area2D.new()
	exit_terminal.name = "ExitTerminal"
	exit_terminal.position = Vector2(150, floor_y - 60)
	exit_terminal.collision_layer = 0
	exit_terminal.collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(60, 80)
	shape.shape = rect
	exit_terminal.add_child(shape)

	add_child(exit_terminal)

	exit_terminal.body_entered.connect(_on_exit_terminal_entered)

var can_exit: bool = true

func _on_exit_terminal_entered(body: Node2D) -> void:
	if body.is_in_group("player") and can_exit:
		can_exit = false  # Prevent multiple exits
		exit_simulator()

func _on_sim_enemy_killed(_enemy: Node, reward: int, _position: Vector2) -> void:
	# Award coins immediately in simulator (not pending)
	coins_earned += reward
	GameManager.add_coins(reward)

func _on_sim_player_died(_pos: Vector2) -> void:
	# Override normal death - just exit simulator
	exit_simulator()

func exit_simulator() -> void:
	is_active = false
	# Disconnect signals
	if EventBus.enemy_killed.is_connected(_on_sim_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_sim_enemy_killed)
	if EventBus.player_died.is_connected(_on_sim_player_died):
		EventBus.player_died.disconnect(_on_sim_player_died)

	EventBus.simulator_exited.emit(coins_earned)

	# Reset game state and return to shop
	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.player_health = GameManager.player_max_health
	GameManager.load_room(return_room)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Check if wave cleared
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count = 0
	for enemy in enemies:
		if "is_dead" in enemy and not enemy.is_dead:
			alive_count += 1
		elif not "is_dead" in enemy:
			alive_count += 1

	if alive_count == 0:
		spawn_timer += delta
		if spawn_timer >= wave_delay:
			spawn_timer = 0.0
			_spawn_wave()

func _spawn_wave() -> void:
	wave_number += 1
	enemies_per_wave = min(3 + wave_number, 10)  # Cap at 10 enemies per wave

	# Select enemy pool based on wave
	var pool_index = min(wave_number / 2, WAVE_ENEMIES.size() - 1)
	var enemy_pool = WAVE_ENEMIES[pool_index]

	for i in range(enemies_per_wave):
		var enemy_path = enemy_pool[randi() % enemy_pool.size()]
		if ResourceLoader.exists(enemy_path):
			var enemy_scene = load(enemy_path)
			var enemy = enemy_scene.instantiate()

			# Random spawn position (avoid edges and exit terminal)
			enemy.global_position = Vector2(
				randf_range(300, room_width - 100),
				randf_range(200, floor_y - 150)
			)
			add_child(enemy)

func _add_death_screen() -> void:
	var death_scene = preload("res://scenes/ui/death_screen.tscn")
	var death_screen = death_scene.instantiate()
	add_child(death_screen)

func _draw() -> void:
	# Draw gray arena background
	draw_rect(Rect2(0, 0, room_width, floor_y), Color(0.15, 0.15, 0.18))

	# Draw grid pattern
	var grid_spacing = 100.0
	var grid_color = Color(0.2, 0.2, 0.25)
	for x in range(0, int(room_width), int(grid_spacing)):
		draw_line(Vector2(x, 0), Vector2(x, floor_y), grid_color, 1.0)
	for y in range(0, int(floor_y), int(grid_spacing)):
		draw_line(Vector2(0, y), Vector2(room_width, y), grid_color, 1.0)

	# Draw exit terminal
	if exit_terminal:
		var term_pos = exit_terminal.position
		draw_rect(Rect2(term_pos.x - 30, term_pos.y - 40, 60, 80), Color(0.2, 0.3, 0.2))
		draw_rect(Rect2(term_pos.x - 30, term_pos.y - 40, 60, 80), Color(0.3, 0.6, 0.3), false, 2.0)
		draw_string(ThemeDB.fallback_font, term_pos + Vector2(-20, -10), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GREEN)

	# Draw wave indicator
	draw_string(ThemeDB.fallback_font, Vector2(room_width / 2 - 50, 50), "WAVE " + str(wave_number), HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Color.WHITE)

	# Draw coins earned
	draw_string(ThemeDB.fallback_font, Vector2(room_width / 2 - 60, 80), "Coins: $" + str(coins_earned), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color.YELLOW)

	# Draw "COMBAT SIMULATOR" title
	draw_string(ThemeDB.fallback_font, Vector2(room_width / 2 - 100, 25), "COMBAT SIMULATOR", HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(0.5, 0.5, 0.6))
