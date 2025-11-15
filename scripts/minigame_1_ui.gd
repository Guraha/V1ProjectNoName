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
@onready var background_music: HSlider = $MainMenu/OptionScreen/VBoxContainer/MarginContainer/VBoxContainer/HSlider
@onready var sfx_music: HSlider = $MainMenu/OptionScreen/VBoxContainer/MarginContainer2/VBoxContainer/HSlider


@onready var back: Button = $MainMenu/OptionScreen/VBoxContainer/MarginContainer4/Back
@onready var main_menu_Screen: MarginContainer = $MainMenu/MainMenu
@onready var normal_mode: MarginContainer = $ReadyScreen/NormalMode
@onready var hardmode: MarginContainer = $ReadyScreen/Hardmode
@onready var bg_value: Label = $MainMenu/OptionScreen/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/BGValue
@onready var sfx_value: Label = $MainMenu/OptionScreen/VBoxContainer/MarginContainer2/VBoxContainer/HBoxContainer/SFXValue


@onready var menu_how_to_play: RichTextLabel = $MainMenu/Panel/MarginContainer/MenuHowToPlay
@onready var normalmode_ready_how_to_play: RichTextLabel = $ReadyScreen/NormalMode/Panel/MarginContainer/ReadyHowToPlay
@onready var hardmode_ready_how_to_play: RichTextLabel = $ReadyScreen/Hardmode/Panel/MarginContainer/ReadyHowToPlay




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
	# Allow input to work even when game is paused (for menu toggle)
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[DEBUG MINIGAME1] process_mode set to PROCESS_MODE_ALWAYS")
	
	# Set pause mode for game elements to pause when tree is paused
	if timer:
		timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player1:
		player1.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player2:
		player2.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Keep UI elements always processing so menu works when paused
	if main_menu:
		main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if ready_screen:
		ready_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	
	# Initialize value labels
	bg_value.text = str(int(background_music.value))
	sfx_value.text = str(int(sfx_music.value))
	
	background_music.value_changed.connect(_on_music_slider_changed)
	sfx_music.value_changed.connect(_on_sfx_slider_changed)
	
	main_menu.visible = false
	option_screen.visible = false
	
	# Update "How to Play" text with dynamic points
	_update_how_to_play_text()
	
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

	if p1_pts >= GameData.points_required or p2_pts >= GameData.points_required:
		var winner_id = 1 if p1_pts >= GameData.points_required else 2

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
	var initial_score = 1
	
	# Check difficulty mode
	var is_hard_mode := GameData.minigame1_difficulty == "hard"
	
	# 🎯 STEP 1: Pick a random goal first
	if is_hard_mode:
		# Hard mode: Much wider range due to multiply/divide operations
		# Can go very low or very high
		var goal_type = randi() % 3
		if goal_type == 0:
			goal_score = randi_range(1, 10)    # Low range: 1-10
		elif goal_type == 1:
			goal_score = randi_range(50, 150)  # High range: 50-150
		else:
			goal_score = randi_range(15, 40)   # Medium range: 15-40
	else:
		goal_score = randi_range(10, 25)  # Normal mode: 10-25
	
	# 🔨 STEP 2: Work backwards to create a guaranteed solution
	var solution_buttons: Array = []
	
	if is_hard_mode:
		# Hard mode: 3-button solution
		solution_buttons = _create_solution_path(goal_score, initial_score, 3)
	else:
		# Normal mode: 2-button solution
		solution_buttons = _create_solution_path(goal_score, initial_score, 2)
	
	# 🎲 STEP 3: Initialize all button slots with random operations
	for i in range(btn_count):
		if i == btn_count - 1:
			# Last button is always Clear
			config.append({"operation": OperationType.CLEAR, "value": 0})
		else:
			# Fill with random operation (will be overwritten for solution buttons)
			var random_btn = _generate_random_button(is_hard_mode)
			config.append(random_btn)
	
	# 📍 STEP 4: Place solution buttons at random positions
	var available_positions = range(btn_count - 1)  # Exclude Clear button
	available_positions.shuffle()
	
	var solution_indices: Array = []
	for i in range(solution_buttons.size()):
		var pos = available_positions[i]
		config[pos] = solution_buttons[i]
		solution_indices.append(pos)
	
	# 📝 STEP 5: Build solution text with complete path showing intermediate results
	if solution_buttons.size() == 3:
		# Calculate intermediate results step by step
		var step1_result = initial_score
		match solution_buttons[0].operation:
			OperationType.ADD: step1_result += solution_buttons[0].value
			OperationType.SUBTRACT: step1_result -= solution_buttons[0].value
			OperationType.MULTIPLY: step1_result *= solution_buttons[0].value
			OperationType.DIVIDE: 
				if solution_buttons[0].value != 0:
					step1_result = int(float(step1_result) / float(solution_buttons[0].value))
		
		var step2_result = step1_result
		match solution_buttons[1].operation:
			OperationType.ADD: step2_result += solution_buttons[1].value
			OperationType.SUBTRACT: step2_result -= solution_buttons[1].value
			OperationType.MULTIPLY: step2_result *= solution_buttons[1].value
			OperationType.DIVIDE: 
				if solution_buttons[1].value != 0:
					step2_result = int(float(step2_result) / float(solution_buttons[1].value))
		
		var step3_result = step2_result
		match solution_buttons[2].operation:
			OperationType.ADD: step3_result += solution_buttons[2].value
			OperationType.SUBTRACT: step3_result -= solution_buttons[2].value
			OperationType.MULTIPLY: step3_result *= solution_buttons[2].value
			OperationType.DIVIDE: 
				if solution_buttons[2].value != 0:
					step3_result = int(float(step3_result) / float(solution_buttons[2].value))
		
		# Single-line format: 1 +3 +4 +4 -2 = 10
		solution.text = "HINT: %d %s%d %s%d %s%d = %d" % [
			initial_score,
			_operation_to_str(solution_buttons[0].operation), solution_buttons[0].value,
			_operation_to_str(solution_buttons[1].operation), solution_buttons[1].value,
			_operation_to_str(solution_buttons[2].operation), solution_buttons[2].value,
			step3_result
		]
	else:
		# Calculate intermediate results for 2-button solution
		var step1_result = initial_score
		match solution_buttons[0].operation:
			OperationType.ADD: step1_result += solution_buttons[0].value
			OperationType.SUBTRACT: step1_result -= solution_buttons[0].value
			OperationType.MULTIPLY: step1_result *= solution_buttons[0].value
			OperationType.DIVIDE: 
				if solution_buttons[0].value != 0:
					step1_result = int(float(step1_result) / float(solution_buttons[0].value))
		
		var step2_result = step1_result
		match solution_buttons[1].operation:
			OperationType.ADD: step2_result += solution_buttons[1].value
			OperationType.SUBTRACT: step2_result -= solution_buttons[1].value
			OperationType.MULTIPLY: step2_result *= solution_buttons[1].value
			OperationType.DIVIDE: 
				if solution_buttons[1].value != 0:
					step2_result = int(float(step2_result) / float(solution_buttons[1].value))
		
		# Single-line format: 1 +3 +4 = 8
		solution.text = "HINT: %d %s%d %s%d = %d" % [
			initial_score,
			_operation_to_str(solution_buttons[0].operation), solution_buttons[0].value,
			_operation_to_str(solution_buttons[1].operation), solution_buttons[1].value,
			step2_result
		]
	
	return {"goal": goal_score, "initial_score": initial_score, "buttons": config}


# Creates a guaranteed solution path from initial_score to target
func _create_solution_path(target: int, start: int, num_buttons: int) -> Array:
	var buttons: Array = []
	var current = start
	
	if num_buttons == 2:
		# 2-button solution for normal mode
		# Strategy: Try to reach target with reasonable operations
		
		# Calculate what we need
		var diff = target - current
		
		# Try different strategies
		var strategy = randi() % 3
		
		if strategy == 0 and diff > 0:
			# Strategy: Add then multiply
			var add_val = randi_range(2, 6)
			var temp = current + add_val
			var mult_val = max(2, int(float(target) / float(temp)))
			
			buttons.append({"operation": OperationType.ADD, "value": add_val})
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult_val})
			
		elif strategy == 1:
			# Strategy: Multiply then add
			var mult_val = randi_range(2, 4)
			var temp = current * mult_val
			var add_val = target - temp
			
			if add_val >= 0:
				buttons.append({"operation": OperationType.MULTIPLY, "value": mult_val})
				buttons.append({"operation": OperationType.ADD, "value": add_val})
			else:
				# Fallback: just add in two steps
				var half = int(float(diff) / 2.0)
				buttons.append({"operation": OperationType.ADD, "value": half})
				buttons.append({"operation": OperationType.ADD, "value": diff - half})
		else:
			# Strategy: Simple additions
			var half = int(float(diff) / 2.0)
			buttons.append({"operation": OperationType.ADD, "value": half})
			buttons.append({"operation": OperationType.ADD, "value": diff - half})
	
	else:
		# 3-button solution for hard mode
		# Use more aggressive multiply/divide operations
		var strategy = randi() % 4
		
		if strategy == 0 and target > 50:
			# Strategy: Multiply early to reach high numbers
			var mult1 = randi_range(3, 8)
			var temp1 = current * mult1
			var mult2 = randi_range(2, 5)
			var temp2 = temp1 * mult2
			var final_op = target - temp2
			
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult1})
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult2})
			buttons.append({"operation": OperationType.ADD, "value": final_op})
			
		elif strategy == 1 and target < 10:
			# Strategy: Divide to reach low numbers
			var mult = randi_range(20, 40)  # Multiply high first
			var temp1 = current * mult
			var div1 = randi_range(3, 6)
			var temp2 = int(float(temp1) / float(div1))
			var div2 = max(2, int(float(temp2) / float(target)))
			
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult})
			buttons.append({"operation": OperationType.DIVIDE, "value": div1})
			buttons.append({"operation": OperationType.DIVIDE, "value": div2})
			
		elif strategy == 2:
			# Strategy: Multiply, divide, adjust with add/subtract
			var mult = randi_range(10, 25)
			var temp1 = current * mult
			var div = randi_range(2, 5)
			var temp2 = int(float(temp1) / float(div))
			var final_adjust = target - temp2
			
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult})
			buttons.append({"operation": OperationType.DIVIDE, "value": div})
			
			if final_adjust >= 0:
				buttons.append({"operation": OperationType.ADD, "value": final_adjust})
			else:
				buttons.append({"operation": OperationType.SUBTRACT, "value": abs(final_adjust)})
		else:
			# Strategy: Add, multiply large, divide
			var add1 = randi_range(2, 8)
			var temp1 = current + add1
			var mult = randi_range(5, 15)
			var temp2 = temp1 * mult
			var div = max(2, int(float(temp2) / float(target)))
			
			buttons.append({"operation": OperationType.ADD, "value": add1})
			buttons.append({"operation": OperationType.MULTIPLY, "value": mult})
			buttons.append({"operation": OperationType.DIVIDE, "value": div})
	
	# ✅ FINAL VERIFICATION: Calculate actual result and verify it matches target
	var verification_result = start
	for btn in buttons:
		match btn.operation:
			OperationType.ADD:
				verification_result += btn.value
			OperationType.SUBTRACT:
				verification_result -= btn.value
			OperationType.MULTIPLY:
				verification_result *= btn.value
			OperationType.DIVIDE:
				if btn.value != 0:
					verification_result = int(float(verification_result) / float(btn.value))
	
	# If verification fails, fix the last button to make it exact
	if verification_result != target and buttons.size() > 0:
		print("Solution mismatch detected. Expected: ", target, ", Got: ", verification_result)
		
		# Calculate what the result was before the last button
		var result_before_last = start
		for i in range(buttons.size() - 1):
			var btn = buttons[i]
			match btn.operation:
				OperationType.ADD:
					result_before_last += btn.value
				OperationType.SUBTRACT:
					result_before_last -= btn.value
				OperationType.MULTIPLY:
					result_before_last *= btn.value
				OperationType.DIVIDE:
					if btn.value != 0:
						result_before_last = int(float(result_before_last) / float(btn.value))
		
		# Replace last button with exact adjustment
		var needed_adjustment = target - result_before_last
		if needed_adjustment >= 0:
			buttons[buttons.size() - 1] = {"operation": OperationType.ADD, "value": needed_adjustment}
		else:
			buttons[buttons.size() - 1] = {"operation": OperationType.SUBTRACT, "value": abs(needed_adjustment)}
		
		print("Fixed last button to reach exact target: ", target)
	
	return buttons


# Generate a random button operation (for non-solution buttons)
func _generate_random_button(is_hard_mode: bool) -> Dictionary:
	var op = OperationType.ADD
	var value = randi() % 10 + 1
	var rr = randi() % 100
	
	if is_hard_mode:
		# Hard mode: More variety with larger multipliers and divisors
		if rr < 35:
			op = OperationType.MULTIPLY
			value = randi_range(2, 12)  # Larger multipliers for reaching 100+
		elif rr < 70:
			op = OperationType.DIVIDE
			value = randi_range(2, 8)   # More divisors for reaching low numbers
		elif rr < 85:
			op = OperationType.ADD
			value = randi_range(1, 20)  # Larger additions
		else:
			op = OperationType.SUBTRACT
			value = randi_range(1, 15)  # Larger subtractions
	else:
		# Normal mode: Simpler operations
		if rr < 50:
			op = OperationType.ADD
			value = randi_range(1, 10)
		elif rr < 90:
			op = OperationType.SUBTRACT
			value = randi_range(1, 10)
		else:
			op = OperationType.MULTIPLY
			value = randi_range(2, 4)
	
	return {"operation": op, "value": value}

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
		print("[DEBUG MINIGAME1] ESC pressed! Current paused state: ", get_tree().paused)
		print("[DEBUG MINIGAME1] Current is_game_paused: ", is_game_paused)
		print("[DEBUG MINIGAME1] Current main_menu.visible: ", main_menu.visible)
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		print("[DEBUG MINIGAME1] After toggle - paused: ", get_tree().paused, " menu visible: ", main_menu.visible)
		return





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


# Compute result for 3-button sequence (used in hard mode)
func compute_3button_sequence(b1: Dictionary, b2: Dictionary, b3: Dictionary, initial_score := 0) -> int:
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
	# Apply third button
	match b3.operation:
		OperationType.ADD:
			result += b3.value
		OperationType.SUBTRACT:
			result -= b3.value
		OperationType.MULTIPLY:
			result *= b3.value
		OperationType.DIVIDE:
			if b3.value != 0:
				result = int(float(result) / float(b3.value))
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
	
	# Show/hide difficulty mode indicators based on GameData
	if GameData.minigame1_difficulty == "normal":
		normal_mode.visible = true
		hardmode.visible = false
	else:
		normal_mode.visible = false
		hardmode.visible = true

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
			SFX.play_accept()

	# ✅ Start countdown only when both are ready
	if player1_ready and player2_ready and not ready_countdown_active:
		_start_ready_countdown()
	# Cancel countdown if anyone is not ready
	if (not player1_ready or not player2_ready) and ready_countdown_active:
		_cancel_ready_countdown()


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
	SFX.stop_round_start_sfx_player()



func _toggle_pause_menu():
	print("[DEBUG MINIGAME1] _toggle_pause_menu called")
	print("[DEBUG MINIGAME1] BEFORE - is_game_paused: ", is_game_paused, " tree.paused: ", get_tree().paused, " menu.visible: ", main_menu.visible)
	
	is_game_paused = !is_game_paused

	if is_game_paused:
		# Pause the game
		get_tree().paused = true
		main_menu.visible = true
		print("[DEBUG MINIGAME1] PAUSING game - menu should be visible")
	else:
		# Unpause the game
		get_tree().paused = false
		main_menu.visible = false
		print("[DEBUG MINIGAME1] UNPAUSING game - menu should be hidden")
	
	print("[DEBUG MINIGAME1] AFTER - is_game_paused: ", is_game_paused, " tree.paused: ", get_tree().paused, " menu.visible: ", main_menu.visible)


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
	bg_value.text = str(int(value))
	SFX.play_move()

func _on_sfx_slider_changed(value: float):
	SFX.set_sfx_volume(value / 100.0)
	sfx_value.text = str(int(value))
	SFX.play_move()


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE HOW TO PLAY TEXT WITH DYNAMIC POINTS
# ═══════════════════════════════════════════════════════════════════════════════
func _update_how_to_play_text() -> void:
	var points := GameData.points_required
	
	# Update main menu "How to Play" text
	if menu_how_to_play:
		menu_how_to_play.text = "[b][color=orange]How to Play:[/color][/b]\nUse the [b]grid of math operations[/b] to reach the [b]goal number[/b].\nTake turns selecting buttons to adjust your score — [color=yellow]first to " + str(points) + " points wins[/color]!\nUse the [i]clear button[/i] if you make a mistake."
	
	# Update normal mode ready screen text
	if normalmode_ready_how_to_play:
		normalmode_ready_how_to_play.text = "[b][color=orange]How to Play (Normal Mode):[/color] [color=yellow]First to " + str(points) + " points wins![/color] [/b]\nTap numbers in the [b]math grid and combine them[/b] to reach the [b]goal[/b].\nYou'll use [color=yellow]addition[/color], [color=yellow]subtraction[/color], and occasional [color=yellow]multiplication[/color]."
	
	# Update hard mode ready screen text
	if hardmode_ready_how_to_play:
		hardmode_ready_how_to_play.text = "[b][color=orange]How to Play (Hard Mode):[/color] [color=yellow]First to " + str(points) + " points wins![/color][/b]\nTap numbers in the [b]math grid and combine them[/b] to reach the [b]goal[/b].\nYou'll use [color=yellow]multiplication[/color] and [color=yellow]division[/color] more often, with [color=yellow]addition[/color] and [color=yellow]subtraction[/color] appearing less frequently."
