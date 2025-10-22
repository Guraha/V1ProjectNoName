extends Control

signal request_new_round(player_id)
signal score_changed(player_id, current_score)

# UI references (relative to this player node)
@onready var score_label: Label = $Text/Score
@onready var points_label: Label = $Text/MarginContainer/Panel/Points
@onready var grid_container: GridContainer = $ColorRect3/MarginContainer/GridContainer
@onready var clear_btn: Button = $ColorRect3/MarginContainer/GridContainer/Clear

# State
var player_id := 1
var goal_score := 0
var current_score := 0
var initial_score := 0
var selected_index := 0
var buttons: Array[Button] = []
var button_states := {} # by button name: {operation, value}
var points := 0

# Mirror OperationType from manager
enum OperationType { ADD, SUBTRACT, MULTIPLY, DIVIDE, NONE }

var operation_colors = {
	OperationType.ADD: Color(0.921569, 0.321569, 0.160784, 1),
	OperationType.SUBTRACT: Color(0.129412, 0.631373, 0.592157, 1),
	OperationType.MULTIPLY: Color(0.354402, 0.468501, 0.929882, 1),
	OperationType.DIVIDE: Color(0.666409, 0.33928, 0.838672, 1),
	OperationType.NONE: Color(0.776471, 0.721569, 0.639216, 1),
}

func _ready():
	_collect_buttons()
	# Connect presses within this grid
	for b in buttons:
		if not b.pressed.is_connected(_on_button_pressed):
			b.pressed.connect(_on_button_pressed.bind(b))
	_update_ui()
	_update_focus()

func _collect_buttons():
	buttons.clear()
	for child in grid_container.get_children():
		if child is Button:
			buttons.append(child)
	# Deterministic navigation order
	buttons.sort_custom(func(a, b): return a.get_index() < b.get_index())

func set_goal(goal: int):
	goal_score = goal

func set_initial_score(initial: int):
	initial_score = initial
	current_score = initial_score
	_update_ui()
	emit_signal("score_changed", player_id, current_score)

func apply_config(config: Array):
	# config is an array of dictionaries per index: {operation, value}
	button_states.clear()
	for i in range(min(config.size(), buttons.size())):
		var b := buttons[i]
		var st: Dictionary = config[i]
		# Keep Clear button as Clear regardless
		if b == clear_btn:
			b.text = "Clear"
			b.disabled = false
			_update_button_style(b, Color(1, 0.2, 0.2, 1), i == selected_index)
			b.set_meta("operation", OperationType.NONE)
			b.set_meta("value", 0)
			b.set_meta("is_clear", true)
			button_states[b.name] = {"operation": OperationType.NONE, "value": 0}
			continue
		_setup_button(b, st["operation"], st["value"]) 
		b.set_meta("is_clear", false)
		button_states[b.name] = {"operation": st["operation"], "value": st["value"]}
	# reset round state for this player
	current_score = initial_score
	selected_index = 0
	_update_ui()
	emit_signal("score_changed", player_id, current_score)
	_update_focus()

func _input(event):
	if event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_navigate(1, 0)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_navigate(-1, 0)
	elif event.is_action_pressed("move_backward"):
		get_viewport().set_input_as_handled()
		_navigate(0, 1)
	elif event.is_action_pressed("move_forward"):
		get_viewport().set_input_as_handled()
		_navigate(0, -1)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_activate_selected()

func _on_button_pressed(button: Button):
	var idx = buttons.find(button)
	if idx >= 0:
		selected_index = idx
		if button == clear_btn:
			_on_clear_pressed()
		else:
			_activate_selected()

func _on_clear_pressed():
	current_score = initial_score
	# Restore all buttons (except Clear) to their stored states
	for b in buttons:
		if b == clear_btn:
			continue
		var st = button_states.get(b.name, null)
		if st:
			b.disabled = false
			_setup_button(b, st.operation if st.has("operation") else st["operation"], st.value if st.has("value") else st["value"])
	selected_index = buttons.find(clear_btn)
	_update_ui()
	emit_signal("score_changed", player_id, current_score)
	_update_focus()

func _navigate(dx: int, dy: int):
	var columns = 3
	var row = floori(float(selected_index) / float(columns))
	var col = selected_index % columns

	var nearest_index := -1
	var nearest_dist := 1000 # arbitrarily large

	for i in range(buttons.size()):
		if buttons[i].disabled:
			continue
		var target_row = floori(float(i) / float(columns))
		var target_col = i % columns

		# Determine if this button is in the pressed direction
		var in_direction := false
		if dx != 0:
			in_direction = (dx > 0 and target_col > col) or (dx < 0 and target_col < col)
		elif dy != 0:
			in_direction = (dy > 0 and target_row > row) or (dy < 0 and target_row < row)
		if not in_direction:
			continue

		# Compute distance (Manhattan distance)
		var dist = abs(target_row - row) + abs(target_col - col)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_index = i

	if nearest_index != -1:
		selected_index = nearest_index
	_update_focus()

func _activate_selected():
	if selected_index >= buttons.size():
		return
	var b = buttons[selected_index]
	if b.disabled:
		return
	if b.get_meta("is_clear", false):
		_on_clear_pressed()
		return
	if b == clear_btn:
		_on_clear_pressed()
		return
	var operation = b.get_meta("operation", OperationType.NONE)
	var value = b.get_meta("value", 0)
	match operation:
		OperationType.ADD:
			current_score += value
		OperationType.SUBTRACT:
			current_score -= value
		OperationType.MULTIPLY:
			current_score *= value
		OperationType.DIVIDE:
			if value != 0:
				current_score = int(float(current_score) / float(value))
	_update_ui()
	emit_signal("score_changed", player_id, current_score)
	# disable used button
	button_states[b.name] = {"operation": operation, "value": value}
	_setup_button(b, OperationType.NONE, 0)
	# check goal
	if current_score == goal_score:
		points += 1
		_update_ui()
		emit_signal("request_new_round", player_id)
		return
	# advance selection if needed
	while selected_index < buttons.size() and buttons[selected_index].disabled:
		selected_index = (selected_index + 1) % buttons.size()
	_update_focus()

func _update_ui():
	score_label.text = str(current_score)
	points_label.text = str(points) + " POINTS"

func get_points() -> int:
	return points

func reset_points():
	points = 0
	_update_ui()

func get_current_score() -> int:
	return current_score

func _setup_button(button: Button, operation: OperationType, value := 0):
	var text = ""
	match operation:
		OperationType.ADD:
			text = "+" + str(value)
		OperationType.SUBTRACT:
			text = "-" + str(value)
		OperationType.MULTIPLY:
			text = "x" + str(value)
		OperationType.DIVIDE:
			text = "/" + str(value)
		OperationType.NONE:
			text = ""
			button.disabled = true
	button.text = text
	button.set_meta("operation", operation)
	button.set_meta("value", value)
	button.set_meta("is_clear", false)
	# style by operation color
	var col = operation_colors[operation] if operation in operation_colors else operation_colors[OperationType.NONE]
	_update_button_style(button, col, buttons.find(button) == selected_index)
	if operation != OperationType.NONE:
		button.disabled = false

func _update_focus():
	for i in range(buttons.size()):
		var b = buttons[i]
		var op = b.get_meta("operation", OperationType.NONE)
		var col = operation_colors[op] if op in operation_colors else operation_colors[OperationType.NONE]
		var show_outline = (i == selected_index)
		_update_button_style(b, col, show_outline)

func _update_button_style(button: Button, color: Color, show_outline := false):
	var border_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	var outline_w = 4 if show_outline else 0
	# Normal
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_border_width_all(outline_w)
	style_normal.border_color = Color(1,1,0,1) if show_outline else border_color
	style_normal.corner_radius_top_left = 5
	style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_right = 5
	style_normal.corner_radius_bottom_left = 5
	# Hover
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color
	style_hover.set_border_width_all(outline_w)
	style_hover.border_color = Color(1,1,0,1) if show_outline else border_color
	style_hover.corner_radius_top_left = 5
	style_hover.corner_radius_top_right = 5
	style_hover.corner_radius_bottom_right = 5
	style_hover.corner_radius_bottom_left = 5
	# Pressed
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color
	style_pressed.set_border_width_all(outline_w)
	style_pressed.border_color = Color(1,1,0,0.0)
	style_pressed.corner_radius_top_left = 5
	style_pressed.corner_radius_top_right = 5
	style_pressed.corner_radius_bottom_right = 5
	style_pressed.corner_radius_bottom_left = 5
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
