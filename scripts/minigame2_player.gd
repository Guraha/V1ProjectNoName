extends CharacterBody3D

# ─── CONSTANTS ───────────────────────────────────────────────────────────────
const WALK_SPEED = 4.0
const RUN_SPEED = 8.0
const JUMP_VELOCITY = 10.0
const GRAVITY = 20.0
const TURN_SPEED = 8.0
const PUSH_FORCE = 15.0
const PUSH_DECAY = 10.0
const HIT_RECOVERY_TIME = 0.4

# ─── PLAYER CONFIG ───────────────────────────────────────────────────────────
@export var player_id: int = 1  # 1 = Player 1, 2 = Player 2

# ─── NODE REFERENCES ─────────────────────────────────────────────────────────
@onready var character_model: Node3D
@onready var animation_player: AnimationPlayer
@onready var punch_area: Area3D

# ─── STATE VARIABLES ─────────────────────────────────────────────────────────
var input_prefix: String = ""
var is_jumping = false
var has_landed = false
var is_ducking = false
var is_punching = false
var punch_active = false
var is_hit = false
var target_rot_y = 0.0
var lock_rot_y = null
var landing_timer := 0.0
var hit_timer := 0.0
var external_push := Vector3.ZERO

# ─── INITIALIZATION ──────────────────────────────────────────────────────────
func _ready() -> void:
	input_prefix = "" if player_id == 1 else "_p2"
	character_model = $CollisionShape3D.get_node("Character_Male_1" if player_id == 1 else "Character_Female_1")
	animation_player = character_model.get_node("AnimationPlayer")
	punch_area = character_model.get_node("PunchArea")


# ─── PHYSICS PROCESS ─────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# --- Hit recovery ---
	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0:
			is_hit = false
			velocity.x = 0
		else:
			velocity.x = external_push.x
			external_push.x = move_toward(external_push.x, 0, PUSH_DECAY * delta)
		move_and_slide()
		return

	# --- External push decay ---
	if external_push.length() > 0.01:
		velocity.x += external_push.x
		external_push = external_push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	elif external_push.length() > 0.001:
		external_push = Vector3.ZERO

	# --- Movement input ---
	var input_dir = Input.get_axis("move_left" + input_prefix, "move_right" + input_prefix)
	var speed = RUN_SPEED if Input.is_action_pressed("run" + input_prefix) else WALK_SPEED
	if not is_punching:
		velocity.x = input_dir * speed + external_push.x
	else:
		velocity.x = external_push.x

	# --- Decay push ---
	external_push.x = move_toward(external_push.x, 0, PUSH_DECAY * delta)

	# --- Punch ---
	if Input.is_action_just_pressed("ui_accept" + input_prefix) and not is_punching and is_on_floor():
		_start_punch()
	if is_punching:
		move_and_slide()
		return

	# --- Jump ---
	if Input.is_action_just_pressed("move_forward" + input_prefix) and is_on_floor() and not is_ducking:
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		has_landed = false
		animation_player.play("Jump")

	# --- Move the character ---
	move_and_slide()

	# --- Landing logic ---
	if is_jumping and is_on_floor() and velocity.y <= 0:
		is_jumping = false
		has_landed = true
		landing_timer = 0.35
		animation_player.play("Jump_Land")

	if has_landed:
		landing_timer -= delta
		if landing_timer <= 0:
			has_landed = false
			animation_player.play("Idle")
		return

	# --- Ducking ---
	if Input.is_action_just_pressed("move_backward" + input_prefix) and not is_ducking:
		is_ducking = true
		animation_player.play("Duck")
	elif Input.is_action_pressed("move_backward" + input_prefix) and is_ducking:
		if animation_player.current_animation != "Duck_Hold":
			animation_player.play("Duck_Hold")
	elif Input.is_action_just_released("move_backward" + input_prefix) and is_ducking:
		is_ducking = false
		animation_player.play_backwards("Duck")

	# --- Movement animations ---
	if not is_jumping and abs(velocity.x) > 0.1:
		if Input.is_action_pressed("run" + input_prefix):
			if animation_player.current_animation != "Run":
				animation_player.play("Run")
		else:
			if animation_player.current_animation != "Walk":
				animation_player.play("Walk")
	elif not is_jumping and not is_ducking and velocity.x == 0:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	# --- Facing direction ---
	if not is_punching:
		if abs(input_dir) > 0.1:
			target_rot_y = deg_to_rad(90) if input_dir > 0 else deg_to_rad(-90)
		else:
			target_rot_y = deg_to_rad(0)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rot_y, delta * TURN_SPEED)
	elif lock_rot_y != null:
		character_model.rotation.y = lock_rot_y

# ─── PUNCH ───────────────────────────────────────────────────────────────────
func _start_punch():
	is_punching = true
	punch_active = true
	lock_rot_y = character_model.rotation.y
	punch_area.monitoring = true
	animation_player.play("Punch")

	await animation_player.animation_finished

	is_punching = false
	punch_active = false
	punch_area.monitoring = false
	lock_rot_y = null

# ─── PUNCH AREA SIGNAL ───────────────────────────────────────────────────────
func _on_punch_area_body_entered(body):
	if punch_active and body is CharacterBody3D and body != self:
		var push_dir = Vector3.ZERO
		push_dir.x = 1 if body.global_transform.origin.x > global_transform.origin.x else -1
		push_dir = push_dir.normalized()
		if body.has_method("apply_push"):
			body.apply_push(push_dir * PUSH_FORCE)
		if body.has_method("on_hit_react"):
			body.on_hit_react(push_dir)

# ─── APPLY PUSH / HIT ─────────────────────────────────────────────────────────
func apply_push(push_vector: Vector3):
	external_push = push_vector

func on_hit_react(push_dir: Vector3):
	if is_hit:
		return
	is_hit = true
	hit_timer = HIT_RECOVERY_TIME
	external_push = push_dir * 0.8
	animation_player.play("HitReact")
