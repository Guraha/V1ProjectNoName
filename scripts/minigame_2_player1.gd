extends CharacterBody3D

const WALK_SPEED = 4.0
const RUN_SPEED = 8.0
const JUMP_VELOCITY = 10.0
const GRAVITY = 20.0
const TURN_SPEED = 8.0
const PUSH_FORCE = 15.0
const PUSH_DECAY = 10.0
const HIT_RECOVERY_TIME = 0.4

@onready var animation_player: AnimationPlayer = $CollisionShape3D/Character_Male_1/AnimationPlayer
@onready var character_model: Node3D = $CollisionShape3D/Character_Male_1
@onready var punch_area: Area3D = $CollisionShape3D/Character_Male_1/PunchArea

var is_jumping = false
var has_landed = false
var is_ducking = false
var is_punching = false
var is_hit = false
var target_rot_y = 0.0
var lock_rot_y = null
var landing_timer := 0.0
var hit_timer := 0.0
var external_push := Vector3.ZERO


func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- Hit Recovery ---
	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0:
			is_hit = false
		move_and_slide()
		return

	# --- Knockback / External Push ---
	if external_push.length() > 0.01:
		print_rich("[color=orange]%s being pushed: %s[/color]" % [name, external_push])
		velocity.x += external_push.x
		external_push = external_push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	elif external_push.length() > 0.001:
		external_push = Vector3.ZERO

	# --- Movement ---
	if not is_punching:
		var speed = WALK_SPEED
		if Input.is_action_pressed("run"):
			speed = RUN_SPEED
		var input_dir = Input.get_axis("move_left", "move_right")
		velocity.x = input_dir * speed
	else:
		velocity.x = 0

	# --- Punch ---
	if Input.is_action_just_pressed("ui_accept") and not is_punching and is_on_floor():
		var facing_angle = rad_to_deg(character_model.rotation.y)
		if abs(facing_angle - 90) < 10 or abs(facing_angle + 90) < 10:
			_start_punch()

	# Stop movement updates during punch
	if is_punching:
		move_and_slide()
		return

	# --- Jump ---
	if Input.is_action_just_pressed("move_forward") and is_on_floor() and not is_ducking:
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		has_landed = false
		animation_player.play("Jump")

	move_and_slide()

	# --- Landing ---
	if is_jumping and is_on_floor() and velocity.y <= 0:
		is_jumping = false
		has_landed = true
		landing_timer = 0.35

		if abs(velocity.x) < 0.1:
			animation_player.play("Jump_Land")
		else:
			has_landed = false
			if Input.is_action_pressed("run"):
				animation_player.play("Run")
			else:
				animation_player.play("Walk")

	if has_landed:
		landing_timer -= delta
		if landing_timer <= 0:
			has_landed = false
			animation_player.play("Idle")
		return

	# --- Duck ---
	if Input.is_action_just_pressed("move_backward") and not is_ducking:
		is_ducking = true
		animation_player.play("Duck")
	elif Input.is_action_pressed("move_backward") and is_ducking:
		if animation_player.current_animation != "Duck_Hold":
			animation_player.play("Duck_Hold")
	elif Input.is_action_just_released("move_backward") and is_ducking:
		is_ducking = false
		animation_player.play_backwards("Duck")

	# --- Jump Midair ---
	elif is_jumping:
		if velocity.y > 0 and animation_player.current_animation != "Jump_Idle":
			animation_player.play("Jump_Idle")

	# --- Movement Animations ---
	elif abs(velocity.x) > 0.1:
		if Input.is_action_pressed("run"):
			if animation_player.current_animation != "Run":
				animation_player.play("Run")
		else:
			if animation_player.current_animation != "Walk":
				animation_player.play("Walk")

	# --- Idle ---
	elif not is_ducking:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	# --- Facing Direction ---
	if not is_punching:
		var input_dir = Input.get_axis("move_left", "move_right")
		if abs(input_dir) > 0.1:
			target_rot_y = deg_to_rad(90) if input_dir > 0 else deg_to_rad(-90)
		else:
			target_rot_y = deg_to_rad(0)

		character_model.rotation.y = lerp_angle(
			character_model.rotation.y,
			target_rot_y,
			delta * TURN_SPEED
		)
	elif lock_rot_y != null:
		character_model.rotation.y = lock_rot_y


# --- Start Punch Sequence ---
func _start_punch():
	is_punching = true
	lock_rot_y = character_model.rotation.y
	print_rich("[color=yellow]%s started punching[/color]" % name)
	animation_player.play("Punch")

	await animation_player.animation_finished
	is_punching = false
	lock_rot_y = null
	print_rich("[color=gray]%s punch ended[/color]" % name)


# --- Punch Area Collision ---
func _on_punch_area_body_entered(body):
	print_rich("[color=light_blue]%s PunchArea triggered with: %s[/color]" % [name, body.name])

	if is_punching and body is CharacterBody3D and body != self:
		var push_dir = -character_model.global_transform.basis.z.normalized()
		push_dir.y = 0
		print_rich("[color=lime]%s hit %s with push_dir: %s[/color]" % [name, body.name, push_dir])

		body.apply_push(push_dir * PUSH_FORCE)

		if body.has_method("on_hit_react"):
			body.on_hit_react(push_dir)
	else:
		print_rich("[color=red]%s punch ignored (not punching or self)[/color]" % name)


# --- Apply Push (called externally) ---
func apply_push(push_vector: Vector3):
	external_push = push_vector
	print_rich("[color=orange]%s received push: %s[/color]" % [name, push_vector])


# --- When Hit by Punch ---
func on_hit_react(push_dir: Vector3):
	if is_hit:
		return
	is_hit = true
	hit_timer = HIT_RECOVERY_TIME
	external_push = push_dir * 0.8
	print_rich("[color=red]%s got hit! push_dir: %s[/color]" % [name, push_dir])
	animation_player.play("HitReact")
