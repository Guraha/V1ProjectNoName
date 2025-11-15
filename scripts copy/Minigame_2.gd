extends Node3D

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS - Tunable timing and animation values
# ═══════════════════════════════════════════════════════════════════════════════
const LABEL_FADE_DURATION: float = 0.3
const SCORE_BOUNCE_DURATION: float = 0.3
const TIMER_PULSE_DURATION: float = 0.5
const TIMER_URGENT_DURATION: float = 0.2
const PLAYER_BOUNCE_DURATION: float = 0.4
const PLAYER_BOUNCE_HEIGHT: float = 1.5
const HIGHLIGHT_SCALE_DURATION: float = 0.3
const HIGHLIGHT_FADE_DURATION: float = 0.2
const TYPEWRITER_SPEED: float = 0.03
const ROUND_START_DELAY: float = 0.5
const ANSWER_REVEAL_DELAY: float = 2.5
const TRANSITION_DELAY: float = 0.8
const INPUT_UNLOCK_DELAY: float = 0.5
const TIMER_WARNING_THRESHOLD: int = 5
const WINNING_SCORE: int = 15
const QUESTION_BASE_SCALE: float = 1.0
const QUESTION_MIN_SCALE: float = 0.6   # More aggressive minimum for long questions
const QUESTION_MAX_SCALE: float = 1.2
const OPTION_BASE_SCALE: float = 1.0
const OPTION_MIN_SCALE: float = 0.8     # More aggressive minimum for long options
const OPTION_MAX_SCALE: float = 1.0

const QUESTION_IDEAL_CHARS: int = 50  # Questions start scaling earlier
const OPTION_IDEAL_CHARS: int = 20    # Options start scaling earlier (4-5 words)

# ═══════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════
enum GameState {
	PREPARE,           # Getting ready for a new round
	QUESTION_DISPLAY,  # Showing question and options
	WAITING_INPUT,     # Accepting player input
	ANSWER_REVEAL,     # Showing correct/wrong answers
	TRANSITION,        # Moving to next round
	GAME_OVER          # Game finished
}

var current_state: GameState = GameState.PREPARE
var overlapping_areas: Array[String] = []

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE NODES
# ═══════════════════════════════════════════════════════════════════════════════
@onready var area_a: Area3D = $SubViewport/ALabel/Area3D
@onready var area_b: Area3D = $SubViewport/BLabel/Area3D
@onready var area_c: Area3D = $SubViewport/CLabel/Area3D
@onready var area_d: Area3D = $SubViewport/DLabel/Area3D
@onready var timer: Timer = $SubViewport/Timer
@onready var skip_timer = $SubViewport/SkipTimer
@onready var skip_hint_p1_ui = $SubViewport/Hint/Control_Hint/SkipHintP1
@onready var skip_hint_p2_ui = $SubViewport/Hint/Control_Hint/SkipHintP2
@onready var timer_value: Label3D = $SubViewport/TimerValue
@onready var question_label: Label3D = $SubViewport/QuestionLabel
@onready var labelA: Label3D = $SubViewport/ALabel/Area3D/ValueLabel
@onready var labelB: Label3D = $SubViewport/BLabel/Area3D/ValueLabel
@onready var labelC: Label3D = $SubViewport/CLabel/Area3D/ValueLabel
@onready var labelD: Label3D = $SubViewport/DLabel/Area3D/ValueLabel
@onready var player1: CharacterBody3D = $SubViewport/Player1
@onready var player2: CharacterBody3D = $SubViewport/Player2
@onready var player1_score_label: Label = $Player1/Score
@onready var player2_score_label: Label = $Player2/Score
@onready var highlight_a: MeshInstance3D = $SubViewport/ALabel/Area3D/Highlight
@onready var highlight_b: MeshInstance3D = $SubViewport/BLabel/Area3D/Highlight
@onready var highlight_c: MeshInstance3D = $SubViewport/CLabel/Area3D/Highlight
@onready var highlight_d: MeshInstance3D = $SubViewport/DLabel/Area3D/Highlight
@onready var get_ready_overlay: Label3D = $SubViewport/GetReadyOverlay
@onready var optionA: Label3D = $SubViewport/ALabel/Area3D/OptionLabel
@onready var optionB: Label3D = $SubViewport/BLabel/Area3D/OptionLabel
@onready var optionC: Label3D = $SubViewport/CLabel/Area3D/OptionLabel
@onready var optionD: Label3D = $SubViewport/DLabel/Area3D/OptionLabel

# Spawn points
@onready var spawn_p1: Marker3D = $SubViewport/spawn_p1
@onready var spawn_p2: Marker3D = $SubViewport/spawn_p2

#Relocation points
@onready var relocate_spawn_p_1: Marker3D = $SubViewport/relocateSpawn_p1
@onready var relocate_spawn_p_2: Marker3D = $SubViewport/relocateSpawn_p2

@onready var main_menu: ColorRect = $Control/MainMenu
@onready var main_menu_screen: MarginContainer = $Control/MainMenu/MainMenu
@onready var return_to_game: Button = $Control/MainMenu/MainMenu/VBoxContainer/ReturnToGame
@onready var restart: Button = $Control/MainMenu/MainMenu/VBoxContainer/Restart
@onready var option: Button = $Control/MainMenu/MainMenu/VBoxContainer/Option
@onready var return_to_main_menu: Button = $Control/MainMenu/MainMenu/VBoxContainer/ReturnToMainMenu
@onready var option_screen: MarginContainer = $Control/MainMenu/OptionScreen
@onready var background_music: HSlider = $Control/MainMenu/OptionScreen/VBoxContainer/MarginContainer/HSlider
@onready var sfx_music: HSlider = $Control/MainMenu/OptionScreen/VBoxContainer/MarginContainer2/HSlider
@onready var back: Button = $Control/MainMenu/OptionScreen/VBoxContainer/MarginContainer4/Back

@onready var orange: ColorRect = $Panel/HBoxContainer/Orange #Player 1
@onready var yellow: ColorRect = $Panel/HBoxContainer/Yellow #Player 2

@onready var Player2_animation_player: AnimationPlayer = $SubViewport/Player2/CollisionShape3D/Character_Female_1/AnimationPlayer
@onready var Player1_animation_player: AnimationPlayer = $SubViewport/Player1/CollisionShape3D/Character_Male_1/AnimationPlayer

var orange_tween = null
var yellow_tween = null

# ═══════════════════════════════════════════════════════════════════════════════
# PARTICLE SYSTEMS - REMOVED FOR PERFORMANCE
# ═══════════════════════════════════════════════════════════════════════════════
# Particle systems removed to eliminate lag during player switching

# ═══════════════════════════════════════════════════════════════════════════════
# GAME STATE VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════
var player1_score: int = 0
var player2_score: int = 0
var current_player: int = 1
var chosen_answer: String = ""
var correct_answer: String = ""
var current_question_index: int = 0
var is_ready_for_input: bool = false

# Initial lobby ready states
var player1_ready: bool = false
var player2_ready: bool = false
var initial_lobby_completed: bool = false

# Debug timing
var debug_start_time: int = 0
var debug_frame_count: int = 0

# Timer optimization
var last_timer_value: int = -1

# ═══════════════════════════════════════════════════════════════════════════════
# QUESTION BANK
# ═══════════════════════════════════════════════════════════════════════════════
var question_data: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALS & TWEENS
# ═══════════════════════════════════════════════════════════════════════════════
var mat_green: StandardMaterial3D
var mat_red: StandardMaterial3D
var mat_yellow: StandardMaterial3D
var mat_glow_green: StandardMaterial3D
var mat_glow_red: StandardMaterial3D

# Border-only materials (transparent with emission)
var mat_border_green: StandardMaterial3D
var mat_border_red: StandardMaterial3D
var mat_border_yellow: StandardMaterial3D

# Tween management - REMOVED FOR PERFORMANCE
# All tween animations removed to eliminate lag during player switching

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	SFX.play_bgm("minigame_2")
	debug_start_time = Time.get_ticks_msec()
	print("[DEBUG] _ready() started at ", debug_start_time)
	print("[DEBUG] Skipped material creation - will lazy load")
	
	skip_hint_p1_ui.visible = false
	skip_hint_p2_ui.visible = false
	
	# Load from GameData if available
	if GameData.imported_questions.size() > 0:
		question_data = GameData.imported_questions.duplicate(true)
		print("✅ Loaded imported questions:", question_data.size())
	else:
		print("⚠️ No imported questions found, using default fallback.")
		question_data = [
			{"q":"What is the capital of France?", "A":"Berlin", "B":"Paris", "C":"Rome", "D":"Madrid", "answer":"B"},
			{"q":"Largest planet in the Solar System?", "A":"Earth", "B":"Mars", "C":"Jupiter", "D":"Venus", "answer":"C"},
			{"q":"What color do you get by mixing red and blue?", "A":"Green", "B":"Purple", "C":"Orange", "D":"Brown", "answer":"B"}
		]

	#Connect timeout signal
	if not skip_timer.timeout.is_connected(_on_skip_timer_timeout):
		skip_timer.timeout.connect(_on_skip_timer_timeout)


	# Connect timer safely
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	# Connect area signals
	var signal_start := Time.get_ticks_msec()
	_connect_area_signals()
	print("[DEBUG] Area signals connected in ", Time.get_ticks_msec() - signal_start, "ms")

	# Initial visual state
	_hide_all_highlights()
	
	# Only spawn player 1 initially - player 2 spawns when needed
	var spawn_start := Time.get_ticks_msec()
	_set_player_active(player1, true)
	player1.global_transform = spawn_p1.global_transform
	
	# Keep player2 disabled until their turn
	#_set_player_active(player2, false)
	#player2.global_transform = relocate_spawn_p_2.global_transform
	player2.global_transform = spawn_p2.global_transform

	print("[DEBUG] Player 1 spawned in ", Time.get_ticks_msec() - spawn_start, "ms")
	
	# Set score labels directly (no animations)
	player1_score_label.text = str(player1_score)
	player2_score_label.text = str(player2_score)
	_update_background_progress()

	# Start with delay
	# Show initial lobby - wait for both players to press their buttons
	_set_state(GameState.PREPARE)
	
	# Hide game labels initially
	_hide_game_labels()
	
	get_ready_overlay.visible = true
	get_ready_overlay.text = "Player 1: Not Ready\nPlayer 2: Not Ready"
	
	print("[DEBUG] _ready() completed in ", Time.get_ticks_msec() - debug_start_time, "ms")
		# === Main Menu Buttons ===
	return_to_game.pressed.connect(_on_return_to_game_pressed)
	restart.pressed.connect(_on_restart_pressed)
	return_to_main_menu.pressed.connect(_on_return_to_main_menu_pressed)
	option.pressed.connect(_on_option_pressed)
	back.pressed.connect(_on_back_pressed)
	
		# === Sliders ===
	background_music.value = SFX.music_volume * 100
	sfx_music.value = SFX.sfx_volume * 100
	background_music.value_changed.connect(_on_music_slider_changed)
	sfx_music.value_changed.connect(_on_sfx_slider_changed)
	# Initialize menu visibility
	main_menu.visible = false
	main_menu_screen.visible = true
	option_screen.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════
func _set_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	
	# Clean transitions based on state
	match old_state:
		GameState.WAITING_INPUT:
			is_ready_for_input = false
	
	# State entry actions
	match new_state:
		GameState.PREPARE:
			chosen_answer = ""
			_hide_all_highlights()
		GameState.WAITING_INPUT:
			is_ready_for_input = true
		GameState.GAME_OVER:
			timer.stop()

# ═══════════════════════════════════════════════════════════════════════════════
# CORE GAME LOOP
# ═══════════════════════════════════════════════════════════════════════════════
func start_round() -> void:
	print("[DEBUG] start_round() called at ", Time.get_ticks_msec() - debug_start_time, "ms")
	
	if question_data.size() == 0:
		print("No questions available.")
		return
	
	# Show all game labels when round starts (spread over frames to avoid spike)
	var label_start := Time.get_ticks_msec()
	question_label.visible = true
	await get_tree().process_frame
	labelA.visible = true
	labelB.visible = true
	await get_tree().process_frame
	labelC.visible = true
	labelD.visible = true
	await get_tree().process_frame
	optionA.visible = true
	optionB.visible = true
	optionC.visible = true
	optionD.visible = true
	timer_value.visible = true
	print("[DEBUG] Labels shown in ", Time.get_ticks_msec() - label_start, "ms")
	
	_set_state(GameState.QUESTION_DISPLAY)
	timer.stop()
	
	# Reset timer value and color
	timer_value.text = "15"
	last_timer_value = 15
	timer_value.modulate = Color(1, 1, 0)
	
	# Ensure question index wraps
	if current_question_index >= question_data.size():
		current_question_index = 0

	var data = question_data[current_question_index]
	correct_answer = data.get("answer", "A")

	# Reposition current player to spawn
	var spawn_start := Time.get_ticks_msec()
	_spawn_current_player()
	print("[DEBUG] Player spawned in ", Time.get_ticks_msec() - spawn_start, "ms")
	_update_skip_hint()
	
	# Set question text directly
	question_label.text = data["q"]
	_adjust_label3d_scale(question_label, QUESTION_BASE_SCALE, QUESTION_MIN_SCALE, QUESTION_MAX_SCALE, QUESTION_IDEAL_CHARS)
	
	# Set answer labels directly
	labelA.text = data["A"]
	labelB.text = data["B"]
	labelC.text = data["C"]
	labelD.text = data["D"]

	# Auto-scale all answer labels
	_adjust_label3d_scale(labelA, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(labelB, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(labelC, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(labelD, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)

	# Option label nodes (if visible on UI separately)
	_adjust_label3d_scale(optionA, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(optionB, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(optionC, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)
	_adjust_label3d_scale(optionD, OPTION_BASE_SCALE, OPTION_MIN_SCALE, OPTION_MAX_SCALE, OPTION_IDEAL_CHARS)

	# Start countdown immediately
	timer.start(10.0)
	_set_state(GameState.WAITING_INPUT)
	
	print("[DEBUG] start_round() completed")

func _process(_delta: float) -> void:
	# Debug FPS for first 10 seconds
	debug_frame_count += 1
	var elapsed := Time.get_ticks_msec() - debug_start_time
	if elapsed < 10000:  # First 10 seconds
		if debug_frame_count % 60 == 0:  # Log every 60 frames
			var fps := Engine.get_frames_per_second()
			var frame_time := _delta * 1000.0
			print("[DEBUG] Time: ", elapsed, "ms | FPS: ", fps, " | Frame time: ", "%.2f" % frame_time, "ms")
	
	# Always check for skip buttons
	_check_skip_input()
	
	if timer.is_stopped() or current_state != GameState.WAITING_INPUT:
		return
	
	# Only update timer text when the value actually changes
	var time_left := int(ceil(timer.time_left))
	if time_left != last_timer_value:
		timer_value.text = str(time_left)
		last_timer_value = time_left
		
		# Change timer color when time is running low (no animation)
		if time_left <= TIMER_WARNING_THRESHOLD and not timer_value.modulate.is_equal_approx(Color.RED):
			timer_value.modulate = Color.RED
			SFX.play_5timer_warning()
			
			# 👇 Check for skip buttons each frame
			_check_skip_input()

# ══════════════════════════════════════════════════════════════════════════════
# SKIP TIMER — PLAYER 1 (Left Ctrl) / PLAYER 2 (Right Ctrl)
# ═══════════════════════════════════════════════════════════════════════════════
func _check_skip_input() -> void:
	if current_state != GameState.WAITING_INPUT:
		return
	if timer.is_stopped():
		return

	# Player 1 skip
	if Input.is_action_just_pressed("player1_skip") and current_player == 1:
		print("[DEBUG] ⏩ Player 1 pressed skip!")
		_trigger_skip()

	# Player 2 skip
	elif Input.is_action_just_pressed("player2_skip") and current_player == 2:
		print("[DEBUG] ⏩ Player 2 pressed skip!")
		_trigger_skip()


func _trigger_skip() -> void:
	# Optional: small debounce so skip can't be spammed
	if not skip_timer.is_stopped():
		return
	skip_timer.start(0.01)     # Start SkipTimer — fires its timeout() almost instantly
	
	# Hide skip hints initially
	skip_hint_p1_ui.visible = false
	skip_hint_p2_ui.visible = false


func _on_skip_timer_timeout() -> void:
	print("[DEBUG] ⏳ SkipTimer finished —
	 skipping question!")
	timer.stop()           # stop the main timer
	# Stop countdown sound
	SFX.stop_countdown()   # <- Make sure this function exists
	_check_answer()        # call your existing answer-check logic
	
func _on_area_entered(body: Node, answer: String) -> void:
	if body != get_current_player() or current_state != GameState.WAITING_INPUT:
		return
	if not overlapping_areas.has(answer):
		overlapping_areas.append(answer)
		SFX.play_move() 
	_update_highlight()

func _update_skip_hint():
	skip_hint_p1_ui.visible = (current_player == 1)
	skip_hint_p2_ui.visible = (current_player == 2)

func _on_area_exited(body: Node, answer: String) -> void:
	if body != get_current_player() or current_state != GameState.WAITING_INPUT:
		return
	overlapping_areas.erase(answer)
	
	_update_highlight()
	
func _update_highlight() -> void:
	if overlapping_areas.size() > 0:
		var top_answer := overlapping_areas[overlapping_areas.size() - 1]
		chosen_answer = top_answer
		_highlight_selected(top_answer)
	else:
		chosen_answer = ""
		_hide_all_highlights()

func _on_timer_timeout() -> void:
	if current_state != GameState.WAITING_INPUT:
		return

	timer_value.text = "0"
	_check_answer()


func _check_answer() -> void:
	_set_state(GameState.ANSWER_REVEAL)
	timer.stop()

	var player := get_current_player()
	if player.has_method("set_velocity"):
		player.velocity = Vector3.ZERO
	# REMOVE this line ↓
	# _set_player_active(player, false)


	if chosen_answer == "":
		print("⏰ Time's up — no answer chosen.")
		print("[DEBUG] Playing wrong SFX...")
		SFX.play_wrong()
		_show_feedback(false)
		# Play a brief "no answer" animation to match the timing of wrong/correct
		await get_tree().create_timer(1.0).timeout  # Brief pause for consistency
	elif chosen_answer == correct_answer:
		print("[DEBUG] ✅ Correct answer! Playing correct SFX...")
		SFX.play_correct()
		await _add_score()  # Wait for the wave animation to finish
		_show_feedback(true)
	else:
		print("[DEBUG] ❌ Wrong answer! Playing wrong SFX...")
		SFX.play_wrong()
		_show_feedback(false)
		# 🦆 Play "Duck" animation when answer is wrong
		# CRITICAL: Disable player's physics process to prevent animation override
		player.set_physics_process(false)
		
		# Rotate character to face forward (toward camera)
		var character_model = _get_player_character_model(player)
		if character_model:
			character_model.rotation.y = deg_to_rad(0)  # Face forward
		
		var anim_player = _get_player_animation_player(player)
		if anim_player and anim_player.has_animation("Duck"):
			print("[DEBUG] Playing Duck animation")
			anim_player.play("Duck")
			await anim_player.animation_finished
			print("[DEBUG] Duck animation finished")
		else:
			print("[DEBUG] ⚠️ Duck animation not available")
			await get_tree().create_timer(1.0).timeout  # fallback delay
		# Re-enable player physics
		player.set_physics_process(true)

	# Reveal correct and wrong highlights (runs while animations complete)
	await _highlight_correct_answer()

	# REMOVED: No extra delay - proceed immediately to next question

	# Check for winner
	if player1_score >= WINNING_SCORE or player2_score >= WINNING_SCORE:
		_set_state(GameState.GAME_OVER)
		_end_game()
	else:
		# Move question index advancement into _next_turn to centralize turn transition logic.
		# This prevents cases where the increment could be missed due to timing or
		# different call paths. _next_turn will now advance the question index and
		# start the next round.
		_set_state(GameState.TRANSITION)
		_next_turn()

func _add_score() -> void:
	if current_player == 1:
		player1_score += 1
		player1_score_label.text = str(player1_score)

		# Trigger wave animation for Player 1
		# CRITICAL: Disable player's physics process to prevent animation override
		player1.set_physics_process(false)
		
		# Rotate character to face forward (toward camera)
		var character_model = _get_player_character_model(player1)
		if character_model:
			character_model.rotation.y = deg_to_rad(0)  # Face forward
		
		var anim_player = _get_player_animation_player(player1)
		if anim_player and anim_player.has_animation("Wave"):
			print("[DEBUG] 👋 Playing Wave animation for Player 1")
			anim_player.play("Wave")
			# Wait for animation to finish
			await anim_player.animation_finished
			print("[DEBUG] Wave animation finished for Player 1")
			player1.set_physics_process(true)
		else:
			print("[DEBUG] ⚠️ Wave animation not available for Player 1")
			player1.set_physics_process(true)  # Re-enable immediately if animation not found
	else:
		player2_score += 1
		player2_score_label.text = str(player2_score)

		# Trigger wave animation for Player 2
		# CRITICAL: Disable player's physics process to prevent animation override
		player2.set_physics_process(false)
		
		# Rotate character to face forward (toward camera)
		var character_model = _get_player_character_model(player2)
		if character_model:
			character_model.rotation.y = deg_to_rad(0)  # Face forward
		
		var anim_player = _get_player_animation_player(player2)
		if anim_player and anim_player.has_animation("Wave"):
			print("[DEBUG] 👋 Playing Wave animation for Player 2")
			anim_player.play("Wave")
			# Wait for animation to finish
			await anim_player.animation_finished
			print("[DEBUG] Wave animation finished for Player 2")
			player2.set_physics_process(true)
		else:
			print("[DEBUG] ⚠️ Wave animation not available for Player 2")
			player2.set_physics_process(true)  # Re-enable immediately if animation not found

	# Update the background progress bars to reflect new scores
	_update_background_progress()


func _show_feedback(is_correct: bool) -> void:
	if is_correct:
		print("✅ Correct!")
	else:
		print("❌ Wrong!")

func _next_turn() -> void:
	# Advance to the next question index when moving to the next turn.
	# This centralizes the progression so every turn reliably uses the next question.
	current_question_index += 1
	var old_player := get_current_player()
	_despawn_player(old_player)

	# Switch to new player
	current_player = 2 if current_player == 1 else 1
	var new_player := get_current_player()

	# Teleport to spawn
	var spawn_point := spawn_p1 if current_player == 1 else spawn_p2
	new_player.global_transform = spawn_point.global_transform
	new_player.velocity = Vector3.ZERO

	_set_player_active(new_player, true)

	_set_state(GameState.PREPARE)
	start_round()

func _end_game() -> void:
	_set_player_active(player1, false)
	_set_player_active(player2, false)

	print("🎮 Game Over!")

	var winner_id: int = 0  # Declare outside first

	if player1_score > player2_score:
		print("🏆 Player 1 Wins!")
		winner_id = 1
	elif player2_score > player1_score:
		print("🏆 Player 2 Wins!")
		winner_id = 2
	else:
		print("🤝 It's a tie!")
		winner_id = 0  # optional for tie handling

	# Switch to GameoverScene
	_go_to_gameover_scene(winner_id)

func _go_to_gameover_scene(winner_id: int) -> void:
	# Pause game and reset input
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Store winner and minimap in GameData
	GameData.winner_id = winner_id
	GameData.current_minimap = 2
	
	# Use FadeManager for smooth transition
	FadeManager.fade_to_scene("res://scenes/GameoverScene.tscn")


func get_current_player() -> Node:
	return player1 if current_player == 1 else player2

# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALS - LAZY LOADED FOR PERFORMANCE
# ═══════════════════════════════════════════════════════════════════════════════
func _get_border_green() -> StandardMaterial3D:
	if mat_border_green == null:
		mat_border_green = _create_border_material(Color(0, 1, 0), Color(0, 3, 0))
	return mat_border_green

func _get_border_red() -> StandardMaterial3D:
	if mat_border_red == null:
		mat_border_red = _create_border_material(Color(1, 0, 0), Color(3, 0, 0))
	return mat_border_red

func _get_border_yellow() -> StandardMaterial3D:
	if mat_border_yellow == null:
		mat_border_yellow = _create_border_material(Color(1, 1, 0), Color(3, 3, 0))
	return mat_border_yellow

func _create_material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 1.0
	return mat

func _create_border_material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, 0.05)
	mat.emission_enabled = true
	mat.emission = emission * 0.3
	mat.emission_energy_multiplier = 0.8
	mat.rim_enabled = true
	mat.rim = 0.5
	mat.rim_tint = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL EFFECTS - HIGHLIGHTS
# ═══════════════════════════════════════════════════════════════════════════════
func _highlight_correct_answer() -> void:
	var highlights := {"A": highlight_a, "B": highlight_b, "C": highlight_c, "D": highlight_d}
	
	# Show all highlights instantly (no animations)
	for key in highlights.keys():
		var h: MeshInstance3D = highlights[key]
		h.scale = Vector3.ONE
		
		var is_correct: bool = (key == correct_answer)
		h.set_surface_override_material(0, _get_border_green() if is_correct else _get_border_red())
		h.visible = true
	
	await get_tree().create_timer(ANSWER_REVEAL_DELAY).timeout
	
	_hide_all_highlights()

func _highlight_selected(answer: String) -> void:
	var highlights := {"A": highlight_a, "B": highlight_b, "C": highlight_c, "D": highlight_d}
	
	for k in highlights.keys():
		var h: MeshInstance3D = highlights[k]
		var is_selected: bool = (k == answer)
		h.visible = is_selected
		
		if is_selected:
			h.set_surface_override_material(0, _get_border_yellow())
			h.scale = Vector3.ONE

func _hide_all_highlights() -> void:
	for h in [highlight_a, highlight_b, highlight_c, highlight_d]:
		h.visible = false
		h.scale = Vector3.ONE

# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL EFFECTS - REMOVED FOR PERFORMANCE
# ═══════════════════════════════════════════════════════════════════════════════
# All tween animations and visual effects removed to eliminate lag

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════
func _get_player_animation_player(player: CharacterBody3D) -> AnimationPlayer:
	# Navigate to AnimationPlayer based on player structure:
	# Player -> CollisionShape3D -> Character_Male_X or Character_Female_X -> AnimationPlayer
	var collision_shape = player.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		print("⚠️ CollisionShape3D not found on player")
		return null
	
	# Try both character models
	for model_name in ["Character_Male_1", "Character_Female_1", "Character_Male_2", "Character_Female_2"]:
		var character_model = collision_shape.get_node_or_null(model_name)
		if character_model:
			var anim_player = character_model.get_node_or_null("AnimationPlayer")
			if anim_player:
				return anim_player
			else:
				print("⚠️ AnimationPlayer not found in ", model_name)
	
	print("⚠️ No character model found under CollisionShape3D")
	return null

func _get_player_character_model(player: CharacterBody3D) -> Node3D:
	# Navigate to character model based on player structure:
	# Player -> CollisionShape3D -> Character_Male_X or Character_Female_X
	var collision_shape = player.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		print("⚠️ CollisionShape3D not found on player")
		return null
	
	# Try both character models
	for model_name in ["Character_Male_1", "Character_Female_1", "Character_Male_2", "Character_Female_2"]:
		var character_model = collision_shape.get_node_or_null(model_name)
		if character_model:
			return character_model
	
	print("⚠️ No character model found under CollisionShape3D")
	return null

func _connect_area_signals() -> void:
	for area_pair in [{"area":area_a, "id":"A"}, {"area":area_b, "id":"B"}, {"area":area_c, "id":"C"}, {"area":area_d, "id":"D"}]:
		var a: Area3D = area_pair["area"]
		var id: String = area_pair["id"]
		
		for conn in a.body_entered.get_connections():
			a.body_entered.disconnect(conn["callable"])
		for conn in a.body_exited.get_connections():
			a.body_exited.disconnect(conn["callable"])
			
		a.body_entered.connect(_on_area_entered.bind(id))
		a.body_exited.connect(_on_area_exited.bind(id))

# ═══════════════════════════════════════════════════════════════════════════════
# PLAYER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════
func _set_player_active(player: CharacterBody3D, active: bool) -> void:
	# Players are always active, just enable/disable their controls
	player.set_physics_process(active)
	player.set_process(active)
	
	var collision_shape := player.get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = not active
		
func _spawn_current_player() -> void:
	var player := get_current_player()
	
	# Simply teleport to the correct spawn point
	var spawn_point := spawn_p1 if current_player == 1 else spawn_p2
	player.global_transform = spawn_point.global_transform
	player.velocity = Vector3.ZERO




func _hide_game_labels() -> void:
	# Hide all game-related labels when Get Ready overlay is shown
	question_label.visible = false
	labelA.visible = false
	labelB.visible = false
	labelC.visible = false
	labelD.visible = false
	optionA.visible = false
	optionB.visible = false
	optionC.visible = false
	optionD.visible = false
	timer_value.visible = false

func _show_game_labels() -> void:
	# Show all game-related labels when Get Ready overlay disappears
	question_label.visible = true
	labelA.visible = true
	labelB.visible = true
	labelC.visible = true
	labelD.visible = true
	optionA.visible = true
	optionB.visible = true
	optionC.visible = true
	optionD.visible = true
	timer_value.visible = true


func _despawn_player(player: CharacterBody3D) -> void:
	# Disable controls
	player.set_physics_process(false)
	player.set_process(false)
	player.velocity = Vector3.ZERO
	
	var collider := player.get_node_or_null("CollisionShape3D")
	if collider:
		collider.disabled = true
	
	# Teleport to relocation point (off-camera)
	var relocate_point := relocate_spawn_p_1 if player == player1 else relocate_spawn_p_2
	player.global_transform = relocate_point.global_transform

func _input(event: InputEvent) -> void:
	# Toggle main menu on ESC (main_menu input)
	if event.is_action_pressed("main_menu"):
		_toggle_main_menu()
		return  # Avoid further input handling while menu toggled

	# Only allow gameplay input if main menu is not visible
	if main_menu.visible:
		return

	# Current logic for initial lobby
	if current_state != GameState.PREPARE:
		return

	if not initial_lobby_completed:
		if event.is_action_pressed("ui_accept") and not player1_ready:
			player1_ready = true
			_update_ready_overlay()
			_check_both_ready()
		elif event.is_action_pressed("ui_accept_p2") and not player2_ready:
			player2_ready = true
			_update_ready_overlay()
			_check_both_ready()
		return
	
	# Normal round input
	if current_player == 1 and event.is_action_pressed("ui_accept"):
		get_ready_overlay.visible = false
		start_round()
	elif current_player == 2 and event.is_action_pressed("ui_accept_p2"):
		get_ready_overlay.visible = false
		start_round()
		
func _update_ready_overlay() -> void:
	var p1_status := "Ready ✓" if player1_ready else "Not Ready"
	var p2_status := "Ready ✓" if player2_ready else "Not Ready"
	get_ready_overlay.text = "Player 1: " + p1_status + "\nPlayer 2: " + p2_status

func _check_both_ready() -> void:
	if player1_ready and player2_ready:
		print("[DEBUG] Both players ready at ", Time.get_ticks_msec() - debug_start_time, "ms")
		initial_lobby_completed = true
		get_ready_overlay.text = "Starting Game..."
		await get_tree().create_timer(1.0).timeout
		get_ready_overlay.visible = false
		
		# **Relocate Player 2, keep Player 1 at spawn**
		_despawn_player(player2)
		
		start_round()


func _toggle_main_menu() -> void:
	var is_visible := main_menu.visible
	main_menu.visible = not is_visible

	if main_menu.visible:
		# Pause game if needed
		# _set_state(GameState.PREPARE) # optionally pause game state
		_hide_game_labels()
		get_tree().paused = true
	else:
		# Resume game
		_show_game_labels()
		get_tree().paused = false

# === Main Menu Button Actions ===
func _on_return_to_game_pressed() -> void:
	main_menu.visible = false
	main_menu_screen.visible = true
	option_screen.visible = false

	# Resume game
	get_tree().paused = false
	_show_game_labels()
	_set_player_active(get_current_player(), true)

func _on_restart_pressed() -> void:
	print("Restart pressed")

	# Hide menu and ensure options screen is reset
	main_menu.visible = false
	main_menu_screen.visible = true
	option_screen.visible = false

	# Reset everything
	_reset_game_state()

	# Reconnect timer callback if somehow disconnected (safe to call)
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	# Bring focus back to the scene root so input works
	get_viewport().set_input_as_handled()

	# Ensure game not paused
	get_tree().paused = false

	# Show the ready overlay so players press their ready buttons again
	get_ready_overlay.visible = true
	_update_ready_overlay()

	# NOTE:
	# The current flow returns to the initial lobby so both players must press their ready keys again.
	# If you instead want the restart to skip lobby and immediately start the first round,
	# comment out the two lines above and uncomment the next two lines:
	# get_ready_overlay.visible = false
	# start_round()
	
func _on_return_to_main_menu_pressed() -> void:
	print("Return to Main Menu pressed")
	# Unpause and switch to main menu scene
	get_tree().paused = false
	FadeManager.fade_to_scene("res://scenes/main_menu.tscn")

func _on_option_pressed() -> void:
	# Show option screen, hide main menu screen
	main_menu_screen.visible = false
	option_screen.visible = true

func _on_back_pressed() -> void:
	# Go back to main menu from options
	main_menu_screen.visible = true
	option_screen.visible = false


func _reset_game_state() -> void:
	# Stop and reset timer
	if not timer.is_stopped():
		timer.stop()
	last_timer_value = -1
	timer_value.text = "15"
	timer_value.modulate = Color(1, 1, 0)

	# Reset scores & labels
	player1_score = 0
	player2_score = 0
	player1_score_label.text = str(player1_score)
	player2_score_label.text = str(player2_score)
	
	_update_background_progress()

	# Reset game flow flags
	current_player = 1
	current_question_index = 0
	chosen_answer = ""
	correct_answer = ""
	is_ready_for_input = false

	# Reset lobby / readiness
	player1_ready = false
	player2_ready = false
	initial_lobby_completed = false
	get_ready_overlay.visible = true
	get_ready_overlay.text = "Player 1: Not Ready\nPlayer 2: Not Ready"

	# Reset highlights & labels
	_hide_all_highlights()
	_hide_game_labels()

	# Reposition players to spawn points and ensure colliders + processing enabled
	player1.global_transform = spawn_p1.global_transform
	player2.global_transform = spawn_p2.global_transform

	# Ensure collision shapes are enabled and physics/process set correctly
	_set_player_active(player1, true)
	_set_player_active(player2, true)
	var col1 := player1.get_node_or_null("CollisionShape3D")
	if col1:
		col1.disabled = false
	var col2 := player2.get_node_or_null("CollisionShape3D")
	if col2:
		col2.disabled = false

	# Reset label scales
	question_label.scale = Vector3.ONE * QUESTION_BASE_SCALE
	labelA.scale = Vector3.ONE * OPTION_BASE_SCALE
	labelB.scale = Vector3.ONE * OPTION_BASE_SCALE
	labelC.scale = Vector3.ONE * OPTION_BASE_SCALE
	labelD.scale = Vector3.ONE * OPTION_BASE_SCALE
	optionA.scale = Vector3.ONE * OPTION_BASE_SCALE
	optionB.scale = Vector3.ONE * OPTION_BASE_SCALE
	optionC.scale = Vector3.ONE * OPTION_BASE_SCALE
	optionD.scale = Vector3.ONE * OPTION_BASE_SCALE

	# Ensure the scene isn't paused
	if get_tree().paused:
		get_tree().paused = false

	# Ensure state is prepare (waiting for lobby)
	_set_state(GameState.PREPARE)


func _update_background_progress() -> void:
	# Read scores (or use methods if players expose them)
	var p1_points := player1_score
	var p2_points := player2_score
	# If your player nodes have get_points(), prefer that:
	if player1 and player1.has_method("get_points"):
		p1_points = player1.get_points()
	if player2 and player2.has_method("get_points"):
		p2_points = player2.get_points()

	# Introduce baseline to prevent exaggerated initial lead
	var baseline := 2  # pseudo-points added to both players
	var adjusted_p1 := p1_points + baseline
	var adjusted_p2 := p2_points + baseline
	var total_points := adjusted_p1 + adjusted_p2

	# Avoid divide-by-zero (very defensive)
	if total_points <= 0:
		total_points = 1

	var orange_ratio := float(adjusted_p1) / total_points
	var yellow_ratio := float(adjusted_p2) / total_points

	# Optional: enforce a minimum ratio to keep bars visible
	var min_ratio := 0.05
	orange_ratio = max(orange_ratio, min_ratio)
	yellow_ratio = max(yellow_ratio, min_ratio)

	# Re-normalize after enforcing min ratio
	var sum_ratio := orange_ratio + yellow_ratio
	if sum_ratio == 0:
		sum_ratio = 1
	orange_ratio /= sum_ratio
	yellow_ratio /= sum_ratio

	var duration := 0.4

	# Stop previous tweens if they exist
	if is_instance_valid(orange_tween):
		orange_tween.kill() # safer: stop previous tween
	if is_instance_valid(yellow_tween):
		yellow_tween.kill()

	# Animate stretch ratios smoothly (Control property used by HBoxContainer children)
	if is_instance_valid(orange):
		orange_tween = orange.create_tween()
		orange_tween.tween_property(orange, "size_flags_stretch_ratio", orange_ratio, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if is_instance_valid(yellow):
		yellow_tween = yellow.create_tween()
		yellow_tween.tween_property(yellow, "size_flags_stretch_ratio", yellow_ratio, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _get_scale_for_length(text_len: int, base_scale: float, min_scale: float, max_scale: float, ideal_chars: int) -> float:
	if text_len <= ideal_chars or ideal_chars <= 0:
		return clamp(base_scale, min_scale, max_scale)
	# scale down proportionally to length
	var scale_value := base_scale * float(ideal_chars) / float(text_len)
	return clamp(scale_value, min_scale, max_scale)
	
	
func _adjust_label3d_scale(label: Label3D, base_scale: float, min_scale: float, max_scale: float, ideal_chars: int) -> void:
	if label == null:
		return
	
	var text := label.text
	var length := text.length()
	
	# Count words (split by spaces)
	var word_count := text.split(" ", false).size()
	
	# If more than 4 words, apply additional scaling
	var scale_value := base_scale
	if word_count > 4:
		# Calculate scale based on character length
		scale_value = _get_scale_for_length(length, base_scale, min_scale, max_scale, ideal_chars)
		
		# Apply additional word-based scaling (more aggressive for long text)
		var word_penalty := 1.0 - ((word_count - 4) * 0.08)  # Reduce by 8% per extra word
		word_penalty = clamp(word_penalty, 0.5, 1.0)  # Don't go below 50%
		scale_value *= word_penalty
		scale_value = clamp(scale_value, min_scale, max_scale)
	else:
		# For short text (4 words or less), use normal character-based scaling
		scale_value = _get_scale_for_length(length, base_scale, min_scale, max_scale, ideal_chars)
	
	label.scale = Vector3.ONE * scale_value
	
func _on_music_slider_changed(value: float):
	SFX.set_music_volume(value / 100.0)
	SFX.play_move()

func _on_sfx_slider_changed(value: float):
	SFX.set_sfx_volume(value / 100.0)
	SFX.play_move()
