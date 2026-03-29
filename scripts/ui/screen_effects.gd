extends CanvasLayer
class_name ScreenEffects
## Screen shake, flash, and other visual effects

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

var flash_color: Color = Color.WHITE
var flash_duration: float = 0.0
var flash_timer: float = 0.0

@onready var camera: Camera2D = null
@onready var flash_rect: ColorRect = $FlashRect

func _ready() -> void:
	_connect_signals()

	# Find camera
	await get_tree().process_frame
	var cameras = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		camera = cameras[0]

func _connect_signals() -> void:
	EventBus.screen_shake.connect(_on_screen_shake)
	EventBus.flash_screen.connect(_on_flash_screen)

func _process(delta: float) -> void:
	# Update shake
	if shake_timer < shake_duration:
		shake_timer += delta
		var decay = 1.0 - (shake_timer / shake_duration)
		var intensity = shake_intensity * decay

		shake_offset = Vector2(
			randf_range(-1, 1) * intensity,
			randf_range(-1, 1) * intensity
		)

		if camera:
			camera.offset = shake_offset
	else:
		shake_offset = Vector2.ZERO
		if camera:
			camera.offset = Vector2.ZERO

	# Update flash
	if flash_timer < flash_duration:
		flash_timer += delta
		var alpha = (1.0 - flash_timer / flash_duration) * flash_color.a
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, alpha)
		flash_rect.visible = true
	else:
		flash_rect.visible = false

func _on_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = 0.0

func _on_flash_screen(color: Color, duration: float) -> void:
	flash_color = color
	flash_duration = duration
	flash_timer = 0.0
