extends Control

# UI references
@onready var goal_label: Label = $Goal
@onready var player1: Control = $Player1
@onready var player2: Control = $Player2
@onready var orange_rect: ColorRect = $ColorRect/HBoxContainer/Orange
@onready var yellow_rect: ColorRect = $ColorRect/HBoxContainer/Yellow
@onready var timer: Timer = $MarginContainer3/VBoxContainer/Timer
@onready var timer_label: Label = $MarginContainer3/VBoxContainer/TimerLabel
@onready var solution: Label = $MarginContainer/Solution


#Ready Screen
@onready var ready_screen: ColorRect = $ReadyScreen
@onready var timer_value: Label = $ReadyScreen/TimerValue
@onready var press_space_to_continue: RichTextLabel = $ReadyScreen/HBoxContainer/Player1ReadyScreen/VBoxContainer/PressSpaceToContinue
@onready var ready_not_ready: Label = $ReadyScreen/HBoxContainer/Player1ReadyScreen/VBoxContainer/ReadyNotReady
@onready var press_enter_to_continue: RichTextLabel = $ReadyScreen/HBoxContainer/Player2ReadyScreen/VBoxContainer/PressEnterToContinue
@onready var ready_not_ready_p2: Label = $ReadyScreen/HBoxContainer/Player2ReadyScreen/VBoxContainer/ReadyNotReady

#Main Menu Screen
@onready var main_menu: ColorRect = $MainMenu
@onready var return_to_game: Button = $MainMenu/MainMenu/VBoxContainer/ReturnToGame
@onready var restart: Button = $MainMenu/MainMenu/VBoxContainer/Restart
@onready var return_to_main_menu: Button = $MainMenu/MainMenu/VBoxContainer/ReturnToMainMenu
@onready var option: Button = $MainMenu/MainMenu/VBoxContainer/Option
@onready var option_screen: MarginContainer = $MainMenu/OptionScreen
@onready var background_music: HSlider = $MainMenu/OptionScreen/VBoxContainer/MarginContainer/HSlider
@onready var sfx_music: HSlider = $MainMenu/OptionScreen/VBoxContainer/MarginContainer2/HSlider
@onready var back: Button = $MainMenu/OptionScreen/VBoxContainer/MarginContainer4/Back
@onready var main_menu_Screen: MarginContainer = $MainMenu/MainMenu


# Shared game state
var goal_score := 80
var rounds_played := 0
var easy_rounds := 5
var input_cooldown := 0.5
var countdown_time := 10  # total countdown in seconds
var current_time := countdown_time
var countdown_running := false

# Ready-up state
var player1_ready := false
var player2_ready := false
var ready_countdown := 5
var ready_timer: Timer = null
var ready_countdown_active := false
var is_game_paused := false


# Button operation types
enum OperationType {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	NONE,
	CLEAR
}

# Color mappings
var operation_colors = {
	OperationType.ADD: Color(0.921569, 0.321569, 0.160784, 1),
	OperationType.SUBTRACT: Color(0.129412, 0.631373, 0.592157, 1),
	OperationType.MULTIPLY: Color(0.354402, 0.468501, 0.929882, 1),
	OperationType.DIVIDE: Color(0.666409, 0.33928, 0.838672, 1),
	OperationType.NONE: Color(0.776471, 0.721569, 0.639216, 1),
	OperationType.CLEAR: Color(0.87451, 0.17255, 0.31, 1)

}

func _ready():
	set_process_input(true)
	_setup_input_actions()
	
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
	
	main_menu.visible = false
	option_screen.visible = false
	
	SFX.play_bgm("minigame_1")
	
	# Connect child signals if using the new player scripts
	if player1.has_method("connect") and player1.has_signal("request_new_round"):
		player1.request_new_round.connect(_on_player_request_new_round)
	if player2.has_method("connect") and player2.has_signal("request_new_round"):
		player2.request_new_round.connect(_on_player_request_new_round)
	if player1.has_signal("score_changed"):
		player1.score_changed.connect(_on_player_score_changed)
	if player2.has_signal("score_changed"):
		player2.score_changed.connect(_on_player_score_changed)

	# Hide gameplay UI, show ready screen
	_show_ready_screen()

func _on_player_request_new_round(_player_id):
	var p1_pts := 0
	var p2_pts := 0
	
	if player1 and player1.has_method("get_points"):
		p1_pts = player1.get_points()
	if player2 and player2.has_method("get_points"):
		p2_pts = player2.get_points()

	if p1_pts >= 15 or p2_pts >= 15:
		var winner_id = 1 if p1_pts >= 15 else 2

		# Store which minimap was active
		GameData.current_minimap = 1

		# Reset points
		if player1 and player1.has_method("reset_points"):
			player1.reset_points()
		if player2 and player2.has_method("reset_points"):
			player2.reset_points()

		# Unpause and show mouse
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		# Store winner in GameData
		GameData.winner_id = winner_id
		GameData.current_minimap = 1
		
		# Use FadeManager for smooth transition
		FadeManager.fade_to_scene("res://scenes/GameoverScene.tscn")
		return

	# Otherwise continue with next round
	initialize_game()

func _on_clear_pressed(_player := 1):
	# Legacy hook no longer used; kept to avoid breaking external references
	pass

func initialize_game():
	# Generate the round
	var config = _generate_round_config()
	goal_label.text = "Goal: " + str(config.goal)
	solution.visible = false  # hide solution initially

	# Dispatch to players
	if player1 and player1.has_method("set_goal"):
		player1.set_goal(config.goal)
		if player1.has_method("set_initial_score"):
			player1.set_initial_score(config.initial_score)
		player1.apply_config(config.buttons)
	if player2 and player2.has_method("set_goal"):
		player2.set_goal(config.goal)
		if player2.has_method("set_initial_score"):
			player2.set_initial_score(config.initial_score)
		player2.apply_config(config.buttons)

	# Reset and start timer
	_reset_timer()
	timer_label.text = str(current_time)  # restore countdown text when a new goal starts

	rounds_played += 1
	_update_background_progress()
	
func update_ui():
	# Kept for backward compatibility; goal label is updated in initialize_game.
	goal_label.text = "Goal: " + str(goal_score)
	_update_background_progress()

func _on_player_score_changed(_player_id, _current_score):
	SFX.play_score()
	_update_background_progress()



var orange_tween: Tween
var yellow_tween: Tween

func _update_background_progress():
	var p1_points = 0
	var p2_points = 0
	if player1 and player1.has_method("get_points"):
		p1_points = player1.get_points()
	if player2 and player2.has_method("get_points"):
		p2_points = player2.get_points()

	# Introduce baseline to prevent exaggerated initial lead
	var baseline = 2  # pseudo-points added to both players
	var adjusted_p1 = p1_points + baseline
	var adjusted_p2 = p2_points + baseline
	var total_points = adjusted_p1 + adjusted_p2

	var orange_ratio = float(adjusted_p1) / total_points
	var yellow_ratio = float(adjusted_p2) / total_points

	# Optional: enforce a minimum ratio to keep bars visible
	var min_ratio = 0.05
	orange_ratio = max(orange_ratio, min_ratio)
	yellow_ratio = max(yellow_ratio, min_ratio)

	# Re-normalize after enforcing min ratio
	var sum_ratio = orange_ratio + yellow_ratio
	orange_ratio /= sum_ratio
	yellow_ratio /= sum_ratio

	var duration = 0.4

	# Stop previous tweens if they exist
	if is_instance_valid(orange_tween):
		orange_tween.stop()
	if is_instance_valid(yellow_tween):
		yellow_tween.stop()

	# Animate stretch ratios smoothly
	if is_instance_valid(orange_rect):
		orange_tween = orange_rect.create_tween()
		orange_tween.tween_property(orange_rect, "size_flags_stretch_ratio", orange_ratio, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if is_instance_valid(yellow_rect):
		yellow_tween = yellow_rect.create_tween()
		yellow_tween.tween_property(yellow_rect, "size_flags_stretch_ratio", yellow_ratio, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _generate_round_config() -> Dictionary:
	var btn_count := 9 # 3x3 grid, last index is Clear
	var config: Array = []

	# 1️⃣ Fill buttons randomly (except Clear)
	for i in range(btn_count):
		var op = OperationType.ADD
		var value = randi() % 10 + 1
		if i == btn_count - 1:
			op = OperationType.CLEAR
			value = 0
		else:
			var rr = randi() % 100
			if rr < 60:
				op = OperationType.ADD
			elif rr < 90:
				op = OperationType.SUBTRACT
			else:
				op = OperationType.MULTIPLY
		config.append({"operation": op, "value": value})

	# 2️⃣ Generate all 2-button sequence results (avoid trivial or negative results)
	var valid_pairs: Array = []
	for i in range(btn_count - 1):
		for j in range(btn_count - 1):
			if i == j:
				continue
			var b1 = config[i]
			var b2 = config[j]
			var res = compute_sequence_result(b1, b2)
			# Only positive, non-trivial results
			if res > 1:
				valid_pairs.append({"a": i, "b": j, "result": res})

	# 3️⃣ Pick goal intelligently
	if valid_pairs.size() == 0:
		# fallback: sum of two random buttons
		var fallback = config[randi() % (btn_count - 1)].value + config[randi() % (btn_count - 1)].value
		goal_score = max(fallback, 2)
		solution.text = "Solution: TBD"
	else:
		# Sort by closeness to a medium target, avoid trivial combos like x + (-x)
		valid_pairs.sort_custom(Callable(self, "_compare_goal_pairs"))
		var chosen = valid_pairs[randi() % min(5, valid_pairs.size())] # top 5 options
		goal_score = chosen.result

		# Store the exact solution
		var b1 = config[chosen.a]
		var b2 = config[chosen.b]
		solution.text = "Solution: %s %d → %s %d" % [
			_operation_to_str(b1.operation), b1.value,
			_operation_to_str(b2.operation), b2.value
		]

	var initial_score = 0
	return {"goal": goal_score, "initial_score": initial_score, "buttons": config}

# Comparison function for sort_custom
func _compare_goal_pairs(a: Dictionary, b: Dictionary) -> bool:
	var target = 15
	var diff_a = abs(a.get("result", 0) - target)
	var diff_b = abs(b.get("result", 0) - target)
	return diff_a < diff_b


func _operation_to_str(op: int) -> String:
	match op:
		OperationType.ADD:
			return "+"
		OperationType.SUBTRACT:
			return "−"
		OperationType.MULTIPLY:
			return "×"
		OperationType.DIVIDE:
			return "÷"
		OperationType.CLEAR:
			return "Clear"
		OperationType.NONE:
			return ""  # Keep NONE empty
	return "?"

# Apply operation and prevent zero result
func apply_operation(op1: int, val1: int, _op2: int, val2: int) -> int:
	var result = val1
	match op1:
		OperationType.ADD:
			result += val2
		OperationType.SUBTRACT:
			result -= val2
		OperationType.MULTIPLY:
			result *= val2
		OperationType.DIVIDE:
			if val2 != 0:
				result = int(float(result) / float(val2))
	# Ensure result is never zero
	if result == 0:
		result = 1
	return result





func setup_button(_button: Button, _operation: OperationType, _value := 0):
	# Debug print
	print("setup_button:", _button.name, "Operation:", _operation, "Value:", _value)

	# Set text
	if _operation == OperationType.CLEAR:
		_button.text = "Clear"
	elif _operation == OperationType.NONE:
		_button.text = ""
	else:
		_button.text = str(_value)

	# Set color
	var color = operation_colors.get(_operation, Color(0.8, 0.8, 0.8))
	print("Assigned color:", color)

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color

	_button.add_theme_stylebox_override("normal", stylebox.duplicate())
	_button.add_theme_stylebox_override("hover", stylebox.duplicate())
	_button.add_theme_stylebox_override("pressed", stylebox.duplicate())
	_button.add_theme_stylebox_override("disabled", stylebox.duplicate())

	_button.modulate = Color(1, 1, 1, 1)

func update_button_style(_button: Button, _color: Color, _show_outline := false):
	# Legacy no-op
	pass

func _input(event):
	# Handle ready screen input first
	if ready_screen.visible:
		_handle_ready_input()
		return

	# Handle Escape key for pause menu toggle
	if event.is_action_pressed("ui_cancel"): # usually ESC
		_toggle_pause_menu()





func navigate_button(_dx: int, _dy: int, _player := 1):
	pass
	
func update_button_focus(_player := 1):
	pass

func activate_selected_button(_player := 1):
	pass

func game_won():
	print("You won! Round complete")
	# You can add more win logic here (show popup, return to menu, etc.)
	# For now, let's reset the game
	await get_tree().create_timer(1.0).timeout
	initialize_game()

# Helper function to check if WASD keys work (you may need to add these to Input Map)
func _notification(what):
	if what == NOTIFICATION_READY:
		pass


func start_input_cooldown():
	await get_tree().create_timer(input_cooldown).timeout

# Ensure the input actions exist and have the requested keys
func _setup_input_actions():
	_ensure_action("move_forward", [KEY_W])
	_ensure_action("move_backward", [KEY_S])
	_ensure_action("move_left", [KEY_A])
	_ensure_action("move_right", [KEY_D])

	_ensure_action("move_forward_p2", [KEY_UP])
	_ensure_action("move_backward_p2", [KEY_DOWN])
	_ensure_action("move_left_p2", [KEY_LEFT])
	_ensure_action("move_right_p2", [KEY_RIGHT])
	_ensure_action("ui_accept_p2", [KEY_ENTER])
	_ensure_action("ui_accept", [KEY_SPACE])

func _ensure_action(action_name: String, keys: Array):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keys:
		if not _action_has_key(action_name, keycode):
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)

func _action_has_key(action_name: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return true
	return false


# Compute result as if buttons are pressed in order
func compute_sequence_result(b1: Dictionary, b2: Dictionary, initial_score := 0) -> int:
	var result = initial_score
	# Apply first button
	match b1.operation:
		OperationType.ADD:
			result += b1.value
		OperationType.SUBTRACT:
			result -= b1.value
		OperationType.MULTIPLY:
			result *= b1.value
		OperationType.DIVIDE:
			if b1.value != 0:
				result = int(float(result) / float(b1.value))
	# Apply second button
	match b2.operation:
		OperationType.ADD:
			result += b2.value
		OperationType.SUBTRACT:
			result -= b2.value
		OperationType.MULTIPLY:
			result *= b2.value
		OperationType.DIVIDE:
			if b2.value != 0:
				result = int(float(result) / float(b2.value))
	# Never zero
	if result == 0:
		result = 1
	return result


func _reset_timer():
	current_time = countdown_time
	countdown_running = true
	solution.visible = false

	# Make sure timer is set to 1 second intervals and repeating
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.start()

	# Update label immediately
	if timer_label:
		timer_label.text = str(current_time)

	# Connect timeout signal safely
	var cb := Callable(self, "_on_timer_tick")
	if not timer.is_connected("timeout", cb):
		timer.timeout.connect(cb)


func _on_timer_tick():
	if not countdown_running:
		SFX.stop_timer_warning_sfx()
		return
	
	current_time -= 1
	if current_time == 10:
		SFX.play_timer_warning()
	if current_time > 0:
		# Keep counting down
		timer_label.text = str(current_time)
	else:
		# Timer reached zero
		countdown_running = false
		timer.stop()

		# Hide timer text and show solution instead
		timer_label.text = ""
		solution.visible = true

func _on_timer_timeout() -> void:
	pass # Replace with function body.
	
	
	
func _show_ready_screen():
	ready_screen.visible = true
	timer.stop()
	countdown_running = false
	# Ensure any timer warning SFX is stopped when entering the ready screen
	SFX.stop_timer_warning_sfx()
	timer_label.text = ""
	solution.visible = false

	# Reset ready state
	player1_ready = false
	player2_ready = false
	ready_countdown_active = false
	timer_value.text = ""

	# Update labels
	ready_not_ready.text = "Not Ready"
	ready_not_ready_p2.text = "Not Ready"
	press_space_to_continue.visible = true
	press_enter_to_continue.visible = true

	# IMPORTANT: disable player inputs & interactions while ready screen is visible
	if player1 and player1.has_method("set_input_enabled"):
		player1.set_input_enabled(false)
	if player2 and player2.has_method("set_input_enabled"):
		player2.set_input_enabled(false)


func _handle_ready_input():
	# --- Player 1 ---
	if Input.is_action_just_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		player1_ready = !player1_ready  # ✅ toggle

		if player1_ready:
			ready_not_ready.text = "Ready"
			press_space_to_continue.visible = false
			SFX.play_accept()
		else:
			ready_not_ready.text = "Not Ready"
			press_space_to_continue.visible = true
			# Stop any running timer warning when a player unreadies
			SFX.stop_timer_warning_sfx()
			SFX.stop_5timer_warning_sfx()
			SFX.play_accept()

	# --- Player 2 ---
	if Input.is_action_just_pressed("ui_accept_p2"):
		get_viewport().set_input_as_handled()
		player2_ready = !player2_ready  # ✅ toggle

		if player2_ready:
			ready_not_ready_p2.text = "Ready"
			press_enter_to_continue.visible = false
			SFX.play_accept()
		else:
			ready_not_ready_p2.text = "Not Ready"
			press_enter_to_continue.visible = true
			# Stop any running timer warning when a player unreadies
			SFX.stop_timer_warning_sfx()
			SFX.stop_5timer_warning_sfx()
			SFX.play_accept()

	# ✅ Start countdown only when both are ready
	if player1_ready and player2_ready and not ready_countdown_active:
		_start_ready_countdown()


func _ready_countdown_finished():
	# hide ready overlay
	ready_screen.visible = false

	# re-enable player input & interactions now that game will start
	if player1 and player1.has_method("set_input_enabled"):
		player1.set_input_enabled(true)
	if player2 and player2.has_method("set_input_enabled"):
		player2.set_input_enabled(true)
	
	initialize_game()
	
func _start_ready_countdown():
	ready_countdown_active = true
	ready_countdown = 5
	timer_value.text = str(ready_countdown)

	if ready_timer == null:
		ready_timer = Timer.new()
		add_child(ready_timer)

	ready_timer.wait_time = 1.0
	ready_timer.one_shot = false

	var cb = Callable(self, "_on_ready_timer_tick")
	if not ready_timer.timeout.is_connected(cb):
		ready_timer.timeout.connect(cb)
		
	ready_timer.start()
	SFX.play_round_start()


func _on_ready_timer_tick():
	# If either player unreadies during countdown → cancel it
	if not (player1_ready and player2_ready):
		_cancel_ready_countdown()
		return

	ready_countdown -= 1
	if ready_countdown > 0:
		timer_value.text = str(ready_countdown)
	else:
		ready_timer.stop()
		_ready_countdown_finished()


func _cancel_ready_countdown():
	if ready_timer:
		ready_timer.stop()
	ready_countdown_active = false
	timer_value.text = ""
	ready_countdown = 5
	# Also stop any timer warning SFX if countdown was cancelled by a player
	SFX.stop_timer_warning_sfx()
	SFX.stop_5timer_warning_sfx()



func _toggle_pause_menu():
	is_game_paused = !is_game_paused

	if is_game_paused:
		# Pause the game
		get_tree().paused = true
		main_menu.visible = true
	else:
		# Unpause the game
		get_tree().paused = false
		main_menu.visible = false


func _on_return_to_game_pressed():
	# Hide main menu and unpause
	is_game_paused = false
	main_menu.visible = false
	get_tree().paused = false


func _on_restart_pressed():
	# Hide main menu and unpause
	is_game_paused = false
	main_menu.visible = false
	get_tree().paused = false

	# Reset player points
	if player1 and player1.has_method("reset_points"):
		player1.reset_points()
	if player2 and player2.has_method("reset_points"):
		player2.reset_points()

	# Return to the ready screen
	_show_ready_screen()


func _on_return_to_main_menu_pressed():
	print("Return to main menu pressed")
	get_tree().paused = false
	FadeManager.fade_to_scene("res://scenes/main_menu.tscn")
	
func _on_option_pressed():
	SFX.play_move()
	main_menu_Screen.visible = false  # hide the main menu part
	option_screen.visible = true       # show the options


func _on_back_pressed():
	SFX.play_move()
	option_screen.visible = false      # hide options
	main_menu_Screen.visible = true    # show the main menu part agai

func _on_music_slider_changed(value: float):
	SFX.set_music_volume(value / 100.0)
	SFX.play_move()

func _on_sfx_slider_changed(value: float):
	SFX.set_sfx_volume(value / 100.0)
	SFX.play_move()
