extends Node2D
class_name ModuleBase
## Base class for passive player modules (equipped alongside tools)
## Modules provide persistent effects - different from tools which are active abilities

@export var module_name: String = "Module"
@export var module_description: String = ""
@export var module_color: Color = Color.WHITE

# Reference to player (set when initialized)
var player_ref: Player = null

func _ready() -> void:
	add_to_group("modules")

func initialize(player: Player) -> void:
	## Called when module is loaded onto player
	player_ref = player
	_on_initialize()

func _on_initialize() -> void:
	## Override in subclasses for setup (connect signals, etc.)
	pass

# ============================================================
# HOOK METHODS - Override these in subclasses
# ============================================================

func on_player_damaged(amount: int, source: String) -> Dictionary:
	## Called BEFORE damage is applied. Return modified values.
	## @param amount: The incoming damage amount
	## @param source: Damage source identifier ("pit", "electric", "fire", "enemy", etc.)
	## @return Dictionary with optional keys:
	##   - "prevent": bool - If true, cancel damage entirely
	##   - "amount": int - Modified damage amount
	##   - "respawn_position": Vector2 - Teleport player here after damage
	##   - "prevent_death_if_survives": bool - Don't die even if damage would kill
	return {}

func on_player_died() -> Dictionary:
	## Called when player would die (health reached 0).
	## @return Dictionary with optional keys:
	##   - "prevent": bool - If true, player survives
	##   - "set_health": int - Set health to this value
	##   - "invincibility_duration": float - Grant invincibility for this duration
	return {}

func on_enemy_killed(enemy: Node, position: Vector2, reward: int) -> void:
	## Called when an enemy is killed.
	## @param enemy: The enemy node (may be invalid if already freed)
	## @param position: World position where enemy died
	## @param reward: Base coin reward for this enemy
	pass

func on_charge_started() -> void:
	## Called when weapon charge begins.
	pass

func on_charge_updated(delta: float, current_charge: float) -> float:
	## Called during charging. Return modified charge speed multiplier.
	## @param delta: Frame delta time
	## @param current_charge: Current charge amount (0.0 to 1.0)
	## @return Charge speed multiplier (1.0 = normal, 1.43 = 30% faster, etc.)
	return 1.0

func on_coin_drop(base_amount: int, enemy_type: String) -> int:
	## Called when coins would drop from enemy. Return modified amount.
	## @param base_amount: Original coin drop amount
	## @param enemy_type: The enemy type identifier
	## @return Modified coin amount
	return base_amount

func get_gravity_multiplier() -> float:
	## Return gravity modifier for player (1.0 = normal).
	## Called every physics frame when player is airborne.
	return 1.0

func is_aiming_midair() -> bool:
	## Utility: Check if player is currently charging weapon while airborne.
	if not player_ref:
		return false
	return player_ref.is_charging and not player_ref.is_on_floor()

# ============================================================
# VISUAL FEEDBACK
# ============================================================

func _draw() -> void:
	## Override in subclasses to draw module-specific visuals
	pass

func get_status_text() -> String:
	## Return status text to show in HUD (e.g., "Kill Streak: 3/5")
	return ""
