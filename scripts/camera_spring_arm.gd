extends Node3D

@export var mouse_sensibility: float = 0.005
@export var zoom_step: float = 0.5
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0

@export_range(-90.0, 0.0, 0.1, "radians_as_degrees")
var min_vertical_angle: float = -PI / 2

@export_range(0.0, 90.0, 0.1, "radians_as_degrees")
var max_vertical_angle: float = PI / 4
@onready var camera_rig: SpringArm3D = $CameraRig


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse look ---
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)

		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

	# --- Mouse wheel zoom ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_rig.spring_length = clamp(camera_rig.spring_length - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_rig.spring_length = clamp(camera_rig.spring_length + zoom_step, min_zoom, max_zoom)

		# --- Toggle mouse capture ---
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_toggle_mouse_capture()

	# --- Optional keyboard toggle ---
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_mouse_capture()


func _toggle_mouse_capture() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
