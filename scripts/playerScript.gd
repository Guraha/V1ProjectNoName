extends CharacterBody3D

@export var walk_speed := 4.0
@export var run_speed := 8.0
@export var jump_velocity := 4.5
@export var gravity := 9.8

@onready var pivot: Node3D = $CollisionShape3D/Pivot
@onready var camera_rig: SpringArm3D = $SpringArmPivot/CameraRig
@onready var anim_player: AnimationPlayer = $CollisionShape3D/Pivot/Character_Male_1/AnimationPlayer

var was_on_floor := true
var jump_started := false

# --- Landing signal method variables ---
var is_landing := false
var next_anim := "Idle"

func _ready():
	anim_player.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	var input_dir = Vector3.ZERO

	# --- Camera-relative movement ---
	var cam_basis = camera_rig.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	input_dir = (
		(right * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))) +
		(forward * (Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")))
	).normalized()

	# --- Gravity and Jump ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			jump_started = true

	# --- Walk / Run speed ---
	var current_speed = walk_speed
	if Input.is_action_pressed("run"):
		current_speed = run_speed

	# --- Apply movement ---
	if input_dir != Vector3.ZERO:
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.z * current_speed

		# Rotate the visible mesh (pivot) toward movement direction
		var target_rotation = atan2(input_dir.x, input_dir.z)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_rotation, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	# --- Animation logic ---
	_update_animation(input_dir)
	was_on_floor = is_on_floor()


func _update_animation(input_dir: Vector3):
	# --- Jump start ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump_started = true
		anim_player.play("Jump")
		is_landing = false
		return

	# --- In air ---
	if not is_on_floor():
		anim_player.play("Jump_Idle")
		return

	# --- Landing detection ---
	if not was_on_floor and is_on_floor():
		if jump_started:
			# Only play Jump_Land if the player *actually jumped* and isn't moving
			if input_dir.length() < 0.1:
				anim_player.play("Jump_Land")
				is_landing = true
			else:
				anim_player.play("Run" if Input.is_action_pressed("run") else "Walk")
			jump_started = false
			return
		else:
			# Fell without jumping — just blend back to movement/idle
			if input_dir.length() > 0.1:
				anim_player.play("Run" if Input.is_action_pressed("run") else "Walk")
			else:
				anim_player.play("Idle")
			return

	# --- Wait for landing animation to finish ---
	if is_landing:
		return

	# --- Movement / Idle ---
	if input_dir.length() > 0.1:
		anim_player.play("Run" if Input.is_action_pressed("run") else "Walk")
	else:
		anim_player.play("Idle")




# --- Animation finished signal ---
func _on_animation_finished(anim_name):
	if anim_name == "Jump_Land" and is_landing:
		is_landing = false
		anim_player.play(next_anim)
