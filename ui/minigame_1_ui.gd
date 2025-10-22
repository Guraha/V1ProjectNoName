extends Control

# UI references
@onready var goal_label: Label = $Goal
@onready var player1: Control = $Player1
@onready var player2: Control = $Player2
@onready var orange_rect: ColorRect = $ColorRect/HBoxContainer/Orange
@onready var yellow_rect: ColorRect = $ColorRect/HBoxContainer/Yellow

# Shared game state
var goal_score := 80
var rounds_played := 0
var easy_rounds := 5
var input_cooldown := 0.5


# Button operation types
enum OperationType {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	NONE
}

# Color mappings
var operation_colors = {
	OperationType.ADD: Color(0.921569, 0.321569, 0.160784, 1),
	OperationType.SUBTRACT: Color(0.129412, 0.631373, 0.592157, 1),
	OperationType.MULTIPLY: Color(0.354402, 0.468501, 0.929882, 1),
	OperationType.DIVIDE: Color(0.666409, 0.33928, 0.838672, 1),
	OperationType.NONE: Color(0.776471, 0.721569, 0.639216, 1)
}

func _ready():
	_setup_input_actions()
	# Connect child signals if using the new player scripts
	if player1.has_method("connect") and player1.has_signal("request_new_round"):
		player1.request_new_round.connect(_on_player_request_new_round)
	if player2.has_method("connect") and player2.has_signal("request_new_round"):
		player2.request_new_round.connect(_on_player_request_new_round)
	# Listen to score updates to stretch background bars dynamically
	if player1.has_signal("score_changed"):
		player1.score_changed.connect(_on_player_score_changed)
	if player2.has_signal("score_changed"):
		player2.score_changed.connect(_on_player_score_changed)
	initialize_game()

func _on_player_request_new_round(_player_id):
	# Check for game end (first to 15 points)
	var p1_pts := 0
	var p2_pts := 0
	if player1 and player1.has_method("get_points"):
		p1_pts = player1.get_points()
	if player2 and player2.has_method("get_points"):
		p2_pts = player2.get_points()
	if p1_pts >= 15 or p2_pts >= 15:
		# Reset both players' points and restart the game fresh
		if player1 and player1.has_method("reset_points"):
			player1.reset_points()
		if player2 and player2.has_method("reset_points"):
			player2.reset_points()
		rounds_played = 0
		initialize_game()
		return
	# Otherwise continue with next round
	initialize_game()

func _on_clear_pressed(_player := 1):
	# Legacy hook no longer used; kept to avoid breaking external references
	pass

func initialize_game():
	var config = _generate_round_config()
	goal_label.text = "Goal: " + str(config.goal)
	# Dispatch to player nodes if they have expected methods (new scripts)
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
	rounds_played += 1
	_update_background_progress()

func update_ui():
	# Kept for backward compatibility; goal label is updated in initialize_game.
	goal_label.text = "Goal: " + str(goal_score)
	_update_background_progress()

func _on_player_score_changed(_player_id, _current_score):
	_update_background_progress()

func _update_background_progress():
	# Compute proximity to goal for each player and adjust stretch ratios
	var g: int = max(goal_score, 1)
	var p1_score: int = 0
	var p2_score: int = 0
	if player1 and player1.has_method("get_current_score"):
		p1_score = player1.get_current_score()
	if player2 and player2.has_method("get_current_score"):
		p2_score = player2.get_current_score()
	var p1_progress: float = clamp(1.0 - abs(goal_score - p1_score) / float(g), 0.0, 1.0)
	var p2_progress: float = clamp(1.0 - abs(goal_score - p2_score) / float(g), 0.0, 1.0)
	# Baseline 1 so both bars show at start; add progress as bonus width
	if is_instance_valid(orange_rect):
		orange_rect.size_flags_stretch_ratio = 1.0 + p1_progress
	if is_instance_valid(yellow_rect):
		yellow_rect.size_flags_stretch_ratio = 1.0 + p2_progress

func _generate_round_config() -> Dictionary:
	var btn_count := 9 # 3x3 grid, last index is Clear
	var config: Array = []

	# 1️⃣ Fill buttons randomly (except Clear)
	for i in range(btn_count):
		var op = OperationType.ADD
		var value = randi() % 10 + 1
		if i == btn_count - 1:
			# Clear button
			op = OperationType.NONE
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

	# 2️⃣ Compute reachable goals from 2-button permutations (only positive)
	var possible_goals := []
	for i in range(btn_count - 1):
		for j in range(btn_count - 1):
			if i == j:
				continue
			var b1 = config[i]
			var b2 = config[j]
			var res = apply_operation(b1["operation"], b1["value"], b2["operation"], b2["value"])
			# Only positive results
			if res > 0:
				possible_goals.append(res)

	# 3️⃣ Pick a random positive reachable goal
	if possible_goals.size() > 0:
		goal_score = possible_goals[randi() % possible_goals.size()]
	else:
		goal_score = randi() % 10 + 1 # fallback

	# 4️⃣ Start at zero by design
	var initial_score = 0

	# 5️⃣ Guarantee a one-press solution from zero: set one non-clear button to +goal
	var guaranteed_idx = randi() % (btn_count - 1) # 0..7
	config[guaranteed_idx] = {"operation": OperationType.ADD, "value": goal_score}

	return {"goal": goal_score, "initial_score": initial_score, "buttons": config}


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
	# Legacy no-op; per-player scripts handle their own setup now
	pass

func update_button_style(_button: Button, _color: Color, _show_outline := false):
	# Legacy no-op
	pass

func _input(_event):
	# Manager no longer handles movement; handled by per-player scripts
	pass





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
