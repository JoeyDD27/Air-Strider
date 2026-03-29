extends Node
## Global Event Bus for decoupled communication between game systems

# Player events
signal player_damaged(current_health: int, max_health: int)
signal player_died(position: Vector2)
signal player_respawned()
signal player_jumped()
signal coins_changed(amount: int)
signal air_jump_used()
signal air_jump_restored()

# Grapple events
signal grapple_attached(anchor_point: Vector2)
signal grapple_released(velocity: Vector2)

# Weapon events
signal charge_started()
signal charge_released(charge_percent: float)
signal projectile_fired(position: Vector2, direction: Vector2, damage: int)

# Tool events
signal tool_activated(tool_name: String)
signal tool_cooldown_started(tool_name: String, duration: float)
signal tool_cooldown_ended(tool_name: String)
signal tool_equipped(tool_name: String)

# Enemy events
signal enemy_damaged(enemy: Node, remaining_health: int)
signal enemy_killed(enemy: Node, reward: int, position: Vector2)
signal all_enemies_killed()

# Room events
signal room_entered(room_id: int)
signal room_cleared(room_id: int)
signal door_opened(door: Node)

# Boss events
signal boss_phase_changed(phase: int)
signal boss_damaged(remaining_health: int, max_health: int)
signal boss_defeated()
signal depth_charge_telegraph(position: Vector2)
signal depth_charge_strike(position: Vector2)

# Platform events
signal platform_crumble_started(platform: Node)
signal platform_destroyed(position: Vector2)

# Screen effects
signal screen_shake(intensity: float, duration: float)
signal hit_stop(duration: float)
signal flash_screen(color: Color, duration: float)

# Time manipulation
signal time_scale_changed(scale: float)

# Game state
signal game_paused()
signal game_resumed()
signal game_over()
signal victory()

# Shop events
signal shop_opened()
signal shop_closed()
signal tool_purchased(tool_name: String, cost: int)

# Chapter 2 - Electric floor hazard events
signal electric_floor_activated(zone_id: int)
signal electric_floor_deactivated(zone_id: int)
signal electric_floor_warning(zone_id: int, countdown: float)

# Chapter 2 - Support aura events
signal aura_shield_applied(enemy: Node)
signal aura_shield_removed(enemy: Node)
signal aura_amp_applied(enemy: Node)
signal aura_amp_removed(enemy: Node)

# Chapter 2 - Ground-Fault Titan boss events
signal titan_slam_telegraph(position: Vector2)
signal titan_sweep_telegraph(direction: int)
signal titan_laser_telegraph(start: Vector2, end: Vector2)
signal titan_phase_shield(enabled: bool)
signal ceiling_spikes_lowering(target_y: float)

# Chapter 3 - Zone-Blade events
signal zone_blade_triggered(blade: Node, guard_post: Vector2)
signal zone_blade_recalled(blade: Node)

# Chapter 3 - Harpoon events
signal harpoon_fired(stalker: Node, direction: Vector2)
signal player_pulled(direction: Vector2, strength: float)

# Chapter 3 - Aegis-Bit events
signal aegis_bit_destroyed(bit: Node, host: Node)

# Chapter 3 - Apex-Interceptor boss events
signal interceptor_phase_changed(phase: int)
signal interceptor_minigun_sweep(angle: float)
signal interceptor_harpoon_fired(direction: Vector2)
signal interceptor_spin_slash_telegraph(position: Vector2, radius: float)
signal interceptor_defeated()

# Chapter 4 - DeathRattle and Explosion events
signal explosion_triggered(position: Vector2, radius: float, damage: int)
signal chain_reaction_started(source: Node, position: Vector2)
signal vacuum_pull_started(position: Vector2, radius: float, duration: float)
signal vacuum_pull_ended(position: Vector2)
signal fire_zone_spawned(position: Vector2, duration: float)
signal tether_attached(anchor: Node, player: Node)
signal tether_released(anchor: Node)
signal overcharger_linked(overcharger: Node, target: Node)
signal overcharger_detonated(overcharger: Node, target: Node)

# Chapter 4 - Subject 88 boss events
signal subject88_phase_changed(phase: int)
signal subject88_slam_telegraph(position: Vector2)
signal subject88_shockwave(position: Vector2, radius: float)
signal subject88_laser_sweep(start_angle: float, end_angle: float)
signal subject88_anchor_telegraph(positions: Array)
signal subject88_shockwave_telegraph(position: Vector2, radius: float)

# Chapter 5 - Medic Drone events
signal medic_tether_attached(drone: Node, target: Node)
signal medic_tether_broken(drone: Node, target: Node)
signal bonus_health_removed(enemy: Node)

# Chapter 5 - Dragoon events
signal dragoon_charge_started(dragoon: Node, direction: Vector2)

# Chapter 5 - Orbital Aegis boss events
signal orbital_aegis_phase_changed(phase: int)
signal solar_sweep_started()
signal aegis_bash_started()
signal ion_rain_warning(positions: Array)

# Module events
signal module_equipped(module_name: String)
signal module_effect_triggered(module_name: String, effect_data: Dictionary)

# Death screen events
signal death_screen_shown(death_count: int, can_phantom: bool)
signal phantom_protocol_activated()
signal pit_death_prevented(respawn_position: Vector2)

# Difficulty events
signal difficulty_changed(difficulty: int)

# Hull upgrade events
signal hull_upgrade_purchased(level: int, new_max_hp: int)

# Kill tracking (Blood-Drive Core module)
signal kill_streak_updated(kill_count: int)
signal nano_orb_spawned(position: Vector2)

# Combat Simulator events
signal simulator_entered()
signal simulator_exited(coins_earned: int)
