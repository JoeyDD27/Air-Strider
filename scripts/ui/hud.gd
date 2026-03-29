extends CanvasLayer
class_name HUD
## In-game HUD - displays health, coins, tool cooldown, charge bar

# Layout constants
const PADDING: float = 20.0
const BAR_HEIGHT: float = 20.0
const BAR_WIDTH: float = 200.0

# State
var player_health: int = 3
var player_max_health: int = 3
var player_coins: int = 0
var equipped_tool_name: String = ""
var tool_cooldown_percent: float = 0.0
var is_charging: bool = false
var charge_percent: float = 0.0
var has_air_jump: bool = false

# Module state
var equipped_module_name: String = ""
var module_status_text: String = ""

# Boss state
var show_boss_health: bool = false
var boss_health: int = 0
var boss_max_health: int = 20

@onready var health_bar: Control = $HealthBar
@onready var coin_display: Control = $CoinDisplay
@onready var tool_display: Control = $ToolDisplay
@onready var module_display: Control = $ModuleDisplay
@onready var charge_bar: Control = $ChargeBar
@onready var air_jump_indicator: Control = $AirJumpIndicator
@onready var boss_health_bar: Control = $BossHealthBar

func _ready() -> void:
	_connect_signals()
	_update_all()

func _connect_signals() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.tool_equipped.connect(_on_tool_equipped)
	EventBus.tool_cooldown_started.connect(_on_tool_cooldown_started)
	EventBus.tool_cooldown_ended.connect(_on_tool_cooldown_ended)
	EventBus.charge_started.connect(_on_charge_started)
	EventBus.charge_released.connect(_on_charge_released)
	EventBus.air_jump_used.connect(_on_air_jump_used)
	EventBus.air_jump_restored.connect(_on_air_jump_restored)
	EventBus.boss_damaged.connect(_on_boss_damaged)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.module_equipped.connect(_on_module_equipped)

func _process(_delta: float) -> void:
	# Update charge bar if charging
	if is_charging:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var player = players[0]
			charge_percent = player.charge_amount / player.max_charge
			charge_bar.queue_redraw()

	# Update tool cooldown
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].equipped_tool:
		tool_cooldown_percent = players[0].equipped_tool.get_cooldown_percent()
		tool_display.queue_redraw()

	# Update module status text
	if not players.is_empty() and players[0].equipped_module:
		module_status_text = players[0].equipped_module.get_status_text()
		module_display.queue_redraw()

func _update_all() -> void:
	player_health = GameManager.player_health
	player_max_health = GameManager.player_max_health
	player_coins = GameManager.player_coins
	equipped_tool_name = GameManager.equipped_tool
	equipped_module_name = GameManager.equipped_module

	health_bar.queue_redraw()
	coin_display.queue_redraw()
	tool_display.queue_redraw()
	module_display.queue_redraw()

func _on_player_damaged(current: int, max_hp: int) -> void:
	player_health = current
	player_max_health = max_hp
	health_bar.queue_redraw()

func _on_coins_changed(amount: int) -> void:
	player_coins = amount
	coin_display.queue_redraw()

func _on_tool_equipped(tool_name: String) -> void:
	equipped_tool_name = tool_name
	tool_display.queue_redraw()

func _on_tool_cooldown_started(_tool_name: String, _duration: float) -> void:
	tool_display.queue_redraw()

func _on_tool_cooldown_ended(_tool_name: String) -> void:
	tool_cooldown_percent = 0.0
	tool_display.queue_redraw()

func _on_charge_started() -> void:
	is_charging = true
	charge_percent = 0.0
	charge_bar.visible = true

func _on_charge_released(_percent: float) -> void:
	is_charging = false
	charge_bar.visible = false

func _on_air_jump_used() -> void:
	has_air_jump = false
	air_jump_indicator.queue_redraw()

func _on_air_jump_restored() -> void:
	has_air_jump = true
	air_jump_indicator.queue_redraw()

func _on_boss_damaged(current: int, max_hp: int) -> void:
	show_boss_health = true
	boss_health = current
	boss_max_health = max_hp
	boss_health_bar.visible = true
	boss_health_bar.queue_redraw()

func _on_boss_defeated() -> void:
	show_boss_health = false
	boss_health_bar.visible = false

func _on_player_respawned() -> void:
	player_health = GameManager.player_health
	player_max_health = GameManager.player_max_health
	has_air_jump = false
	is_charging = false
	charge_bar.visible = false
	health_bar.queue_redraw()
	air_jump_indicator.queue_redraw()

func _on_module_equipped(module_name: String) -> void:
	equipped_module_name = module_name
	module_display.queue_redraw()
