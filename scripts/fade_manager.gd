extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var tween: Tween

func _ready() -> void:
	# Start fully transparent and ignore mouse input
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Fade out, switch, then fade in
func fade_to_scene(scene_path: String):
	# Block input during transition
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	await fade_out()
	await switch_scene(scene_path)
	await fade_in()
	
	# Allow input again after transition
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Manual scene switch to avoid black flash
func switch_scene(new_scene_path: String):
	var new_scene = load(new_scene_path).instantiate()
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

# Fade to black
func fade_out(duration := 0.3):
	if tween: tween.kill()
	tween = get_tree().create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)
	await tween.finished

# Fade back in
func fade_in(duration := 0.3):
	if tween: tween.kill()
	tween = get_tree().create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	await tween.finished
