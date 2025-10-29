extends Control

signal request_new_round(player_id)
signal score_changed(player_id, current_score)

@export var player_id: int = 1

# UI references
@onready var score_label: Label = $Text/Score
@onready var points_label: Label = $Text/MarginContainer/Panel/Points
@onready var grid_container: GridContainer = $ColorRect3/MarginContainer/GridContainer
@onready var clear_btn: Button = $ColorRect3/MarginContainer/GridContainer/Clear

#Navigation UI for Player1
@onready var keyboard_d_outline: Sprite2D = $"../Player1_controls/KeyboardDOutline" #Base
@onready var keyboard_w_outline: Sprite2D = $"../Player1_controls/KeyboardWOutline" #Base
@onready var keyboard_s_outline: Sprite2D = $"../Player1_controls/KeyboardSOutline" #Base
@onready var keyboard_a_outline: Sprite2D = $"../Player1_controls/KeyboardAOutline" #Base
@onready var keyboard_space_icon: Sprite2D = $"../Player1_controls/KeyboardSpaceIcon" 
@onready var keyboard_space_icon_outline: Sprite2D = $"../Player1_controls/KeyboardSpaceIconOutline" #Base For Interact
@onready var keyboard_w: Sprite2D = $"../Player1_controls/KeyboardW"
@onready var keyboard_s: Sprite2D = $"../Player1_controls/KeyboardS" 
@onready var keyboard_d: Sprite2D = $"../Player1_controls/KeyboardD" 
@onready var keyboard_a: Sprite2D = $"../Player1_controls/KeyboardA" 


#Navigation UI for Player2
@onready var keyboard_enter: Sprite2D = $"../Player2_controls/KeyboardEnter"
@onready var keyboard_enter_outline: Sprite2D = $"../Player2_controls/KeyboardEnterOutline" #Base For Interact
@onready var keyboard_arrow_left_outline: Sprite2D = $"../Player2_controls/KeyboardArrowLeftOutline" #Base
@onready var keyboard_arrow_right_outline: Sprite2D = $"../Player2_controls/KeyboardArrowRightOutline" #Base
@onready var keyboard_arrow_up_outline: Sprite2D = $"../Player2_controls/KeyboardArrowUpOutline" #Base
@onready var keyboard_arrow_down_outline: Sprite2D = $"../Player2_controls/KeyboardArrowDownOutline" #Base
@onready var keyboard_arrow_down: Sprite2D = $"../Player2_controls/KeyboardArrowDown"
@onready var keyboard_arrow_left: Sprite2D = $"../Player2_controls/KeyboardArrowLeft"
@onready var keyboard_arrow_right: Sprite2D = $"../Player2_controls/KeyboardArrowRight"
@onready var keyboard_arrow_up: Sprite2D = $"../Player2_controls/KeyboardArrowUp" 



# State
var goal_score := 0
var current_score := 0
var initial_score := 0
var selected_index := 0
var buttons: Array[Button] = []
var button_states := {} # by button name: {operation, value}
var points := 0
var _was_disabled_states := {} # temporary store if you want to preserve per-button disabled states (optional)

# Operations
enum OperationType { ADD, SUBTRACT, MULTIPLY, DIVIDE, NONE, CLEAR }

var operation_colors = {
	OperationType.ADD: Color(0.921569, 0.321569, 0.160784, 1),
	OperationType.SUBTRACT: Color(0.129412, 0.631373, 0.592157, 1),
	OperationType.MULTIPLY: Color(0.354402, 0.468501, 0.929882, 1),
	OperationType.DIVIDE: Color(0.666409, 0.33928, 0.838672, 1),
	OperationType.NONE: Color(0.776471, 0.721569, 0.639216, 1),
	OperationType.CLEAR: Color(1, 0.2, 0.2, 1)
}

var operation_shadow_colors = {
	OperationType.ADD: Color8(172, 25, 57),       # shadow for red (#df2c4f)
	OperationType.SUBTRACT: Color8(0, 138, 151),  # shadow for teal
	OperationType.MULTIPLY: Color8(54, 61, 166),  # shadow for blue
	OperationType.DIVIDE: Color8(136, 69, 171),   # shadow for purple
	OperationType.NONE: Color8(198, 183, 164),    # shadow for beige
	OperationType.CLEAR: Color8(204, 32, 32)      # shadow for bright red
}

# === READY ===
func _ready():
	_collect_buttons()
	for b in buttons:
		if not b.pressed.is_connected(_on_button_pressed):
			b.pressed.connect(_on_button_pressed.bind(b))
	_update_ui()
	_update_focus()
	_init_navigation_ui()
	# ensure input processing normally enabled on start (unless Game immediately disables it)
	set_process_input(true)

func _collect_buttons():
	buttons.clear()
	for child in grid_container.get_children():
		if child is Button:
			buttons.append(child)
	buttons.sort_custom(func(a, b): return a.get_index() < b.get_index())

# === SETUP ===
func set_goal(goal: int):
	goal_score = goal

func set_initial_score(initial: int):
	initial_score = initial
	current_score = initial_score
	_update_ui()
	emit_signal("score_changed", player_id, current_score)

func apply_config(config: Array):
	button_states.clear()
	for i in range(min(config.size(), buttons.size())):
		var b := buttons[i]
		var st: Dictionary = config[i]
		if b == clear_btn:
			b.text = "Clear"
			b.disabled = false
			b.set_meta("operation", OperationType.CLEAR)
			b.set_meta("value", 0)
			b.set_meta("is_clear", true)
			button_states[b.name] = {"operation": OperationType.CLEAR, "value": 0}
			_update_button_style(b, operation_colors[OperationType.CLEAR], i == selected_index)
			continue
		_setup_button(b, st["operation"], st["value"])
		b.set_meta("is_clear", false)
		button_states[b.name] = {"operation": st["operation"], "value": st["value"]}
	current_score = initial_score
	selected_index = 0
	_update_ui()
	emit_signal("score_changed", player_id, current_score)
	_update_focus()

# === INPUT ===
func _input(event):
	var player = player_id
	var suffix = "" if player == 1 else "_p2"

	# RIGHT
	if event.is_action_pressed("move_right" + suffix):
		get_viewport().set_input_as_handled()
		_navigate(1, 0)
		_update_navigation_ui(player, "move_right", true)
	elif event.is_action_released("move_right" + suffix):
		_update_navigation_ui(player, "move_right", false)

	# LEFT
	if event.is_action_pressed("move_left" + suffix):
		get_viewport().set_input_as_handled()
		_navigate(-1, 0)
		_update_navigation_ui(player, "move_left", true)
	elif event.is_action_released("move_left" + suffix):
		_update_navigation_ui(player, "move_left", false)

	# BACKWARD
	if event.is_action_pressed("move_backward" + suffix):
		get_viewport().set_input_as_handled()
		_navigate(0, 1)
		_update_navigation_ui(player, "move_backward", true)
	elif event.is_action_released("move_backward" + suffix):
		_update_navigation_ui(player, "move_backward", false)

	# FORWARD
	if event.is_action_pressed("move_forward" + suffix):
		get_viewport().set_input_as_handled()
		_navigate(0, -1)
		_update_navigation_ui(player, "move_forward", true)
	elif event.is_action_released("move_forward" + suffix):
		_update_navigation_ui(player, "move_forward", false)

	# ACCEPT
	if event.is_action_pressed("ui_accept" + suffix) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_activate_selected()
		_update_navigation_ui(player, "ui_accept", true)
	elif event.is_action_released("ui_accept" + suffix):
		_update_navigation_ui(player, "ui_accept", false)

func _on_button_pressed(button: Button):
	var idx = buttons.find(button)
	if idx >= 0:
		selected_index = idx

		# ✅ Light select sound (any button press)
		SFX.play_select()
		

		if button == clear_btn:
			_on_clear_pressed()
		else:
			_activate_selected()
			
func _on_clear_pressed():
	current_score = initial_score
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

# === NAVIGATION ===
func _navigate(dx: int, dy: int):
	var columns: int = 3
	var rows: int = int(ceil(float(buttons.size()) / float(columns)))  # ensure integer

	var row: int = selected_index / columns
	var col: int = selected_index % columns

	# 1) Prefer same-column (vertical) or same-row (horizontal) first
	if dy != 0:
		for step in range(1, rows):
			var target_row: int = row + dy * step
			target_row = int((target_row % rows + rows) % rows)
			var test_index: int = target_row * columns + col
			if test_index >= 0 and test_index < buttons.size() and not buttons[test_index].disabled:
				selected_index = test_index
				_update_focus()
				SFX.play_move()
				return
	elif dx != 0:
		for step in range(1, columns):
			var target_col: int = col + dx * step
			target_col = int((target_col % columns + columns) % columns)
			var test_index: int = row * columns + target_col
			if test_index >= 0 and test_index < buttons.size() and not buttons[test_index].disabled:
				selected_index = test_index
				_update_focus()
				SFX.play_move()
				return

	# 2) Broader search if no candidate in same row/col
	var best_index: int = selected_index
	var best_score: float = INF

	for i in range(buttons.size()):
		var b = buttons[i]
		if b.disabled:
			continue
		var r: int = i / columns
		var c: int = i % columns
		var delta_row: int = r - row
		var delta_col: int = c - col

		if dx > 0 and delta_col <= 0: continue
		if dx < 0 and delta_col >= 0: continue
		if dy > 0 and delta_row <= 0: continue
		if dy < 0 and delta_row >= 0: continue

		var score: float = abs(delta_row) + abs(delta_col)
		if dx != 0 and delta_row == 0: score -= 0.5
		if dy != 0 and delta_col == 0: score -= 0.5

		if score < best_score:
			best_score = score
			best_index = i

	if best_index != selected_index:
		selected_index = best_index
		_update_focus()
		SFX.play_move()
		return

	# 3) Fallback wrap navigation
	for step in range(1, columns * rows):
		if dx != 0:
			var test_col: int = int((col + dx * step + columns) % columns)
			var test_row: int = int((row + ((col + dx * step) / columns)) % rows)
			var test_index: int = test_row * columns + test_col
			if test_index >= 0 and test_index < buttons.size() and not buttons[test_index].disabled:
				selected_index = test_index
				_update_focus()
				SFX.play_move()

				return
		elif dy != 0:
			var test_row: int = int((row + dy * step + rows) % rows)
			var test_index: int = test_row * columns + col
			if test_index >= 0 and test_index < buttons.size() and not buttons[test_index].disabled:
				selected_index = test_index
				_update_focus()
				SFX.play_move()
				return
	
	_update_focus()

# === ACTIVATE BUTTON ===
func _activate_selected():
	if selected_index >= buttons.size():
		return
	var b = buttons[selected_index]
	if b.disabled:
		return

	# ✅ Confirm sound whenever player activates a button
	SFX.play_accept()

	# Handle "Clear" buttons separately
	if b.get_meta("is_clear", false) or b == clear_btn:
		_on_clear_pressed()
		return

	# Apply math operation
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
	button_states[b.name] = {"operation": operation, "value": value}
	_setup_button(b, OperationType.NONE, 0)

	# ✅ Check result
	if current_score == goal_score:
		# Player hit the goal — celebrate!
		SFX.play_correct()
		SFX.play_score()

		points += 5
		_update_ui()
		emit_signal("request_new_round", player_id)
		return
	elif current_score > goal_score:
		# Optional: Overshot the goal — "wrong" feedback
		SFX.play_wrong()

	# Skip disabled buttons and keep focus moving
	while selected_index < buttons.size() and buttons[selected_index].disabled:
		selected_index = (selected_index + 1) % buttons.size()

	_update_focus()

# === UI UPDATE ===
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

# === BUTTON SETUP ===
func _setup_button(button: Button, operation: OperationType, value := 0):
	var text = ""
	match operation:
		OperationType.ADD: text = "+" + str(value)
		OperationType.SUBTRACT: text = "-" + str(value)
		OperationType.MULTIPLY: text = "x" + str(value)
		OperationType.DIVIDE: text = "/" + str(value)
		OperationType.CLEAR: text = "Clear"
		OperationType.NONE:
			text = ""
			button.disabled = true
	button.text = text
	button.set_meta("operation", operation)
	button.set_meta("value", value)
	button.set_meta("is_clear", operation == OperationType.CLEAR)
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
	var outline_color = Color(1,1,0,1) if show_outline else Color(0,0,0,0)
	var outline_w = 4 if show_outline else 0
	var shadow_depth = 2

	# get shadow color from predefined map
	var op = button.get_meta("operation", OperationType.NONE)
	var shadow_color = operation_shadow_colors.get(op, Color(0,0,0,0.25))

	# NORMAL: raised
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.shadow_color = shadow_color
	style_normal.shadow_offset = Vector2(0, shadow_depth)
	style_normal.shadow_size = shadow_depth
	style_normal.set_border_width_all(outline_w)
	style_normal.border_color = outline_color
	style_normal.corner_radius_top_left = 5
	style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_right = 5
	style_normal.corner_radius_bottom_left = 5

	# HOVER: slightly brighter
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = color.lightened(0.1)

	# PRESSED: shadow disappears, invisible “shadow” at top
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = color.darkened(0.15)
	style_pressed.shadow_offset = Vector2(0, -shadow_depth) # top
	style_pressed.shadow_color = Color(0,0,0,0)  # invisible

	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	
func _update_navigation_ui(player: int, action: String, pressed: bool):
	if player == 1:
		# Outline shows by default, base shows only while pressed
		match action:
			"move_right":
				keyboard_d_outline.visible = not pressed
				keyboard_d.visible = pressed
			"move_left":
				keyboard_a_outline.visible = not pressed
				keyboard_a.visible = pressed
			"move_forward":
				keyboard_w_outline.visible = not pressed
				keyboard_w.visible = pressed
			"move_backward":
				keyboard_s_outline.visible = not pressed
				keyboard_s.visible = pressed
			"ui_accept":
				keyboard_space_icon_outline.visible = not pressed
				keyboard_space_icon.visible = pressed
	elif player == 2:
		# Outline shows by default, base shows only while pressed (same as Player 1)
		match action:
			"move_right":
				keyboard_arrow_right_outline.visible = not pressed
				keyboard_arrow_right.visible = pressed
			"move_left":
				keyboard_arrow_left_outline.visible = not pressed
				keyboard_arrow_left.visible = pressed
			"move_forward":
				keyboard_arrow_up_outline.visible = not pressed
				keyboard_arrow_up.visible = pressed
			"move_backward":
				keyboard_arrow_down_outline.visible = not pressed
				keyboard_arrow_down.visible = pressed
			"ui_accept":
				keyboard_enter_outline.visible = not pressed
				keyboard_enter.visible = pressed

func _init_navigation_ui():
	# Player 1: outline visible, base hidden
	keyboard_w_outline.visible = true
	keyboard_a_outline.visible = true
	keyboard_s_outline.visible = true
	keyboard_d_outline.visible = true
	keyboard_space_icon_outline.visible = true

	keyboard_w.visible = false
	keyboard_a.visible = false
	keyboard_s.visible = false
	keyboard_d.visible = false
	keyboard_space_icon.visible = false

	# Player 2: base visible, outline hidden
	keyboard_arrow_down_outline.visible = true
	keyboard_arrow_up_outline.visible = true
	keyboard_arrow_left_outline.visible = true
	keyboard_arrow_right_outline.visible = true
	keyboard_enter_outline.visible = true

	keyboard_arrow_down.visible = false
	keyboard_arrow_up.visible = false
	keyboard_arrow_left.visible = false
	keyboard_arrow_right.visible = false
	keyboard_enter.visible = false


func set_input_enabled(enabled: bool) -> void:
	# Enable/disable the _input processing
	set_process_input(enabled)

	# When disabled: force all buttons to disabled so mouse/click won't trigger them.
	# When enabled: restore normal enabled/disabled based on operation state.
	for b in buttons:
		if not enabled:
			# store previous value optionally
			_was_disabled_states[b.name] = b.disabled
			b.disabled = true
		else:
			# restore according to meta (NONE should remain disabled)
			var op = b.get_meta("operation", OperationType.NONE)
			if op == OperationType.NONE:
				b.disabled = true
			else:
				b.disabled = false

	# Update focus/UI visuals accordingly
	if enabled:
		_update_focus()
	else:
		# hide outlines so it looks visually disabled
		# choose a safe focus index (do not change selected_index) but update visuals
		for i in range(buttons.size()):
			var b = buttons[i]
			_update_button_style(b, operation_colors[b.get_meta("operation", OperationType.NONE)] if b.get_meta("operation", OperationType.NONE) in operation_colors else operation_colors[OperationType.NONE], false)
