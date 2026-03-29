extends ModuleBase
class_name SpectralPhase
## Makes player phase through all platforms but can still grapple room boundaries
## Cannot land on platforms, can only grapple to walls/ceiling/floor

var original_collision_mask: int = 0
var phase_active: bool = true

func _on_initialize() -> void:
	module_name = "Spectral Phase"
	module_description = "Phase through platforms. Grapple walls only."
	module_color = Color(0.6, 0.2, 0.9)  # Purple/spectral

	# Store original collision mask and disable platform collision
	if player_ref:
		original_collision_mask = player_ref.collision_mask
		# Remove layer 2 (platforms) from collision mask
		# Original mask: 2 | 4 | 8 | 32 | 128 = 174
		# Without layer 2: 4 | 8 | 32 | 128 = 172
		# Room boundaries (layer 128) remain active so player stays in bounds
		player_ref.collision_mask = original_collision_mask & ~2

func _exit_tree() -> void:
	# Restore original collision mask when module is removed
	if player_ref and is_instance_valid(player_ref):
		player_ref.collision_mask = original_collision_mask

func get_grapple_layer() -> int:
	## Returns the collision layer for grappling
	## Spectral Phase cannot grapple to platforms (layer 2)
	## Room boundaries (128) are always added by player, so return 0
	return 0

func get_status_text() -> String:
	return "PHASING"
