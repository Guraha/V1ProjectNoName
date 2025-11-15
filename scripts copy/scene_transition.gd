extends CanvasLayer

# Singleton for smooth scene transitions without black flashes

@onready var color_rect: ColorRect = $ColorRect
var is_transitioning: bool = false

func _ready() -> void:
	# Start completely transparent
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(scene_path: String, fade_duration: float = 0.3) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input during transition
	
	# Fade to black
	var tween := create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 1), fade_duration)
	await tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(scene_path)
	
	# Wait one frame for new scene to load
	await get_tree().process_frame
	
	# Fade from black
	var tween2 := create_tween()
	tween2.tween_property(color_rect, "color", Color(0, 0, 0, 0), fade_duration)
	await tween2.finished
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
