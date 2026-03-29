extends RoomBase
class_name Ch2RoomBase
## Chapter 2 room base - extends RoomBase with electric floor support
## Theme: "Airstrike" - Ground = Danger, Air = Safe

@export var has_electric_floor: bool = false
@export var electric_floor_default_on: bool = false

var electric_floor: Node2D = null

func _ready() -> void:
	super._ready()

	if has_electric_floor:
		_setup_electric_floor()

func _setup_electric_floor() -> void:
	var floor_scene = preload("res://scenes/entities/hazards/electric_floor.tscn")
	electric_floor = floor_scene.instantiate()
	electric_floor.is_boss_controlled = false
	add_child(electric_floor)

	if electric_floor_default_on:
		# Delay activation to allow room to fully load
		await get_tree().process_frame
		electric_floor.activate()

func activate_electric_floor() -> void:
	if electric_floor:
		electric_floor.activate()

func deactivate_electric_floor() -> void:
	if electric_floor:
		electric_floor.deactivate()

func is_electric_floor_active() -> bool:
	if electric_floor:
		return electric_floor.is_active
	return false
