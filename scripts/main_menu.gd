extends Control


# === PART ONE ===
@onready var part_1: ColorRect = $Part1
@onready var start_game: Button = $Part1/VBoxContainer/StartGame
@onready var options: Button = $Part1/VBoxContainer/Options
@onready var quit_game: Button = $Part1/VBoxContainer/QuitGame

# === PART TWO ===
@onready var part_2: ColorRect = $Part2
@onready var background_music_h_slider: HSlider = $Part2/MarginContainer/VBoxContainer/MarginContainer/HSlider
@onready var sfx_h_slider: HSlider = $Part2/MarginContainer/VBoxContainer/MarginContainer2/HSlider
@onready var main_menu: Button = $Part2/MarginContainer/VBoxContainer/MarginContainer4/MainMenu

# === PART THREE (Game Selection) ===
@onready var part_3: ColorRect = $Part3
@onready var game_1: Control = $"Part3/VBoxContainer/Selection/1/Game1"
@onready var game_1_text: Label = $"Part3/VBoxContainer/Selection/1/Game1Text"
@onready var game_1_texture: TextureRect = $"Part3/VBoxContainer/Selection/1/Game1/TextureRect"
@onready var game_2: Control = $"Part3/VBoxContainer/Selection/2/Game2"
@onready var game_2_text: Label = $"Part3/VBoxContainer/Selection/2/Game2Text"
@onready var game_2_texture: TextureRect = $"Part3/VBoxContainer/Selection/2/Game2/TextureRect"
@onready var main_menu2: Button = $Part3/VBoxContainer/MainMenu
@onready var animation_player: AnimationPlayer = $SubViewport/AnimationTree/AnimationPlayer

# === Game 1 Options ===
@onready var options_game_1: Panel = $"Part3/VBoxContainer/Selection/1/Game1/TextureRect/OptionsGame"
@onready var normal: Button = $"Part3/VBoxContainer/Selection/1/Game1/TextureRect/OptionsGame/MarginContainer/VBoxContainer/Normal"
@onready var hard: Button = $"Part3/VBoxContainer/Selection/1/Game1/TextureRect/OptionsGame/MarginContainer/VBoxContainer/Hard"

# === Game 2 Options ===
@onready var options_game: Panel = $"Part3/VBoxContainer/Selection/2/Game2/TextureRect/OptionsGame"
@onready var import_questionnaire: Button = $"Part3/VBoxContainer/Selection/2/Game2/TextureRect/OptionsGame/MarginContainer/VBoxContainer/ImportQuestionnaire"
@onready var start_game_as_is: Button = $"Part3/VBoxContainer/Selection/2/Game2/TextureRect/OptionsGame/MarginContainer/VBoxContainer/StartGameAsIs"

# === File Dialog ===
@onready var file_dialog: FileDialog = $"Part3/VBoxContainer/Selection/2/Game2/TextureRect/OptionsGame/FileDialog"
@onready var tutorial_for_import: ColorRect = $Part3/TutorialForImport
@onready var copy_prompt: Button = $Part3/TutorialForImport/MarginContainer/CopyPrompt
@onready var copied_label: Label = $Part3/TutorialForImport/MarginContainer/CopyPrompt/copied_label


# === CONSTANTS ===
const HIGHLIGHT_COLOR = Color(1, 1, 0, 1) # yellow
const NORMAL_COLOR = Color(1, 1, 1, 1)    # normal

func _ready() -> void:
	# --- Music ---
	SFX.play_bgm("main_menu")
	
	# --- Setup FileDialog ---
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.txt ; Text Files")
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(_on_file_dialog_canceled)

	# --- Button connections ---
	start_game.pressed.connect(_on_start_game_pressed)
	options.pressed.connect(_on_options_pressed)
	quit_game.pressed.connect(_on_quit_game_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	main_menu2.pressed.connect(_on_main_menu_pressed)
	import_questionnaire.pressed.connect(_on_import_questionnaire_pressed)
	start_game_as_is.pressed.connect(_on_start_game_as_is_pressed)
	copy_prompt.pressed.connect(_on_tutorial_for_import_clicked)
	normal.pressed.connect(_on_normal_pressed)
	hard.pressed.connect(_on_hard_pressed)

	# --- Sliders ---
	background_music_h_slider.value = SFX.music_volume * 100
	sfx_h_slider.value = SFX.sfx_volume * 100

	background_music_h_slider.value_changed.connect(_on_music_slider_changed)
	sfx_h_slider.value_changed.connect(_on_sfx_slider_changed)

	# --- Hover/Click for Game 1 ---
	if game_1:
		game_1.mouse_entered.connect(_on_game_hover.bind(game_1, true))
		game_1.mouse_exited.connect(_on_game_hover.bind(game_1, false))
		game_1_texture.gui_input.connect(_on_game_1_texture_clicked)
	else:
		push_warning("⚠️ Game 1 node not found!")

	# --- Hover/Click for Game 2 ---
	if game_2:
		game_2.mouse_entered.connect(_on_game_hover.bind(game_2, true))
		game_2.mouse_exited.connect(_on_game_hover.bind(game_2, false))
		game_2_texture.gui_input.connect(_on_game_2_texture_clicked)
	else:
		push_warning("⚠️ Game 2 node not found!")

	# --- Hide parts on start ---
	part_1.visible = true
	part_2.visible = false
	part_3.visible = false
	main_menu2.visible = false
	options_game.visible = false
	options_game_1.visible = false
	tutorial_for_import.visible = false

	# --- Play looping camera animation ---
	if animation_player.has_animation("MainMenuMovementCamera"):
		animation_player.play("MainMenuMovementCamera")
		animation_player.connect("animation_finished", Callable(self, "_on_camera_animation_finished"))
	else:
		push_warning("⚠️ Animation 'MainMenuMovementCamera' not found in AnimationPlayer!")


func _on_camera_animation_finished(anim_name: String) -> void:
	if anim_name == "MainMenuMovementCamera":
		animation_player.play("MainMenuMovementCamera") # ✅ Loop it manually


# === MAIN MENU BUTTONS ===
func _on_start_game_pressed():
	SFX.play_select()
	part_1.visible = false
	part_3.visible = true
	main_menu2.visible = true


func _on_options_pressed():
	SFX.play_select()
	part_1.visible = false
	part_2.visible = true
	main_menu2.visible = false


func _on_quit_game_pressed():
	SFX.play_wrong()
	get_tree().quit()


func _on_main_menu_pressed():
	SFX.play_select()
	part_2.visible = false
	part_3.visible = false
	main_menu2.visible = false
	part_1.visible = true


# === SLIDER HANDLERS ===
func _on_music_slider_changed(value: float):
	SFX.set_music_volume(value / 100.0)
	SFX.play_move()

func _on_sfx_slider_changed(value: float):
	SFX.set_sfx_volume(value / 100.0)
	SFX.play_move()



# === GAME HOVER EFFECTS ===
func _on_game_hover(control: Control, is_hovering: bool):
	control.modulate = HIGHLIGHT_COLOR if is_hovering else NORMAL_COLOR


# === GAME 1 TEXTURE CLICK HANDLER ===
func _on_game_1_texture_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SFX.play_select()
		options_game_1.visible = !options_game_1.visible


# === GAME 1 OPTIONS BUTTONS ===
func _on_normal_pressed():
	SFX.play_accept()
	options_game_1.visible = false
	GameData.minigame1_difficulty = "normal"
	_start_minigame("res://assets/minigames/minigame_1_ui.tscn", "minigame_1")


func _on_hard_pressed():
	SFX.play_accept()
	options_game_1.visible = false
	GameData.minigame1_difficulty = "hard"
	_start_minigame("res://assets/minigames/minigame_1_ui.tscn", "minigame_1")


# === LOAD MINIGAME ===
func _start_minigame(path: String, bgm_name: String):
	SFX.fade_out_bgm(0.5)
	await get_tree().create_timer(0.6).timeout
	SFX.play_bgm(bgm_name)
	FadeManager.fade_to_scene(path)


# === GAME 2 TEXTURE CLICK HANDLER ===
func _on_game_2_texture_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SFX.play_select()
		options_game.visible = !options_game.visible

		# Ensure tutorial_for_import is only visible if OptionsGame is visible
		tutorial_for_import.visible = options_game.visible
		if not options_game.visible:
			copied_label.visible = false  # hide copied label if options closed



# === GAME 2 OPTIONS BUTTONS ===
func _on_import_questionnaire_pressed():
	SFX.play_select()
	print("📂 Opening file dialog...")
	tutorial_for_import.visible = false
	file_dialog.popup_centered()



func _on_start_game_as_is_pressed():
	SFX.play_accept()
	options_game.visible = false
	tutorial_for_import.visible = false
	_start_minigame("res://partial_scripts/Minigame_2.tscn", "minigame_2")



# === FILE DIALOG HANDLERS ===
func _on_file_dialog_canceled():
	print("📂 File dialog cancelled, showing tutorial prompt again...")
	# Show the tutorial prompt again when user cancels file dialog
	tutorial_for_import.visible = true


func _on_file_selected(path: String):
	print("📄 File selected:", path)

	if not path.ends_with(".txt"):
		printerr("⚠ Please select a .txt file only.")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("❌ Failed to open file.")
		return

	var content = file.get_as_text()
	file.close()
	
	# ✅ FIX 1: Remove BOM and normalize line endings
	# Remove UTF-8 BOM if present (common in AI-generated files)
	if content.begins_with("\ufeff"):
		content = content.substr(1)
	# Normalize all line endings to \n (handles Windows CRLF)
	content = content.replace("\r\n", "\n").replace("\r", "\n")
	
	# ✅ FIX 1.5: Handle line-wrapped format from AI-generated files
	# AI-generated files often have hard line breaks mid-sentence
	# We need to join continuation lines and then properly split on markers
	print("📄 Preprocessing line-wrapped format...")
	
	# First, normalize the text by joining lines that are continuations
	# A continuation line is one that doesn't start with a marker (Q:, A:, B:, C:, D:, ANSWER:)
	var lines = content.split("\n")
	var joined_lines: Array = []
	var current_line = ""
	
	for line in lines:
		var trimmed = line.strip_edges()
		
		# Check if this line starts with a marker (case-insensitive)
		var is_marker_line = false
		var line_upper = trimmed.to_upper()
		for marker in ["Q:", "A:", "B:", "C:", "D:", "ANSWER:"]:
			if line_upper.begins_with(marker):
				is_marker_line = true
				break
		
		if trimmed == "":
			# Empty line - save current line and add blank line separator
			if current_line != "":
				joined_lines.append(current_line)
				current_line = ""
			joined_lines.append("")  # Preserve blank lines as separators
		elif is_marker_line:
			# New marker - save previous line and start new one
			if current_line != "":
				joined_lines.append(current_line)
			current_line = trimmed
		else:
			# Continuation line - append to current line with space
			if current_line == "":
				current_line = trimmed
			else:
				current_line += " " + trimmed
	
	# Don't forget the last line
	if current_line != "":
		joined_lines.append(current_line)
	
	# Rejoin with newlines
	content = "\n".join(joined_lines)
	
	# Now handle lines that have multiple markers on the same line
	# Split them by adding newlines before each marker (except the first)
	lines = content.split("\n")
	var final_lines: Array = []
	
	for line in lines:
		if line.strip_edges() == "":
			final_lines.append(line)
			continue
		
		# Check if line has multiple markers (split by spaces before markers)
		var result_line = line
		# Use regex-like approach: add newline before " A:", " B:", " C:", " D:", " ANSWER:"
		# But NOT if it's at the beginning of the line
		for marker in [" A:", " B:", " C:", " D:", " ANSWER:"]:
			result_line = result_line.replace(marker, "\n" + marker.strip_edges())
		
		# Split and add all resulting lines
		var split_lines = result_line.split("\n")
		for split_line in split_lines:
			if split_line.strip_edges() != "":
				final_lines.append(split_line.strip_edges())
	
	content = "\n".join(final_lines)
	
	# Finally, handle the case where everything is on one continuous line (no newlines at all)
	if not content.contains("\nQ:") and content.contains(" Q:"):
		print("📄 Detected single-line format, reformatting...")
		# Add line breaks before Q:, A:, B:, C:, D:, and ANSWER:
		content = content.replace(" Q:", "\n\nQ:")
		content = content.replace(" A:", "\nA:")
		content = content.replace(" B:", "\nB:")
		content = content.replace(" C:", "\nC:")
		content = content.replace(" D:", "\nD:")
		content = content.replace(" ANSWER:", "\nANSWER:")
	
	# Clean up
	content = content.strip_edges()
	
	print("📄 File content length:", content.length())
	print("📄 First 200 chars:", content.substr(0, 200))

	# Parse formatted text into structured question objects
	var parsed_questions = _parse_questions(content)

	if parsed_questions.size() == 0:
		printerr("⚠ No valid questions found in the file.")
		printerr("⚠ Check if the file follows the exact format from the prompt.")
		_show_import_error_popup()
		return

	# Store in global GameData singleton
	GameData.imported_questions = parsed_questions
	print("✅ Import successful! Questions stored in GameData.")
	print("Total questions:", parsed_questions.size())
	
	# ✅ Show success popup (visual feedback)
	_show_import_success_popup(parsed_questions.size())

	# Hide options panel and start the minigame
	options_game.visible = false
	await get_tree().process_frame
	SFX.fade_out_bgm(0.5)
	await get_tree().create_timer(0.6).timeout
	SFX.play_bgm("minigame_2")
	FadeManager.fade_to_scene("res://partial_scripts/Minigame_2.tscn")


# === PARSE QUESTIONS FROM TEXT FILE ===
func _parse_questions(text: String) -> Array:
	var questions: Array = []
	var lines = text.split("\n", false)
	var current_question = {}
	var line_num = 0

	for line in lines:
		line_num += 1
		line = line.strip_edges()
		
		# Skip empty lines
		if line == "":
			# Empty line means end of a question block
			if current_question.has("q") and current_question.has("A") and current_question.has("answer"):
				questions.append(current_question.duplicate(true))
				current_question = {}
			continue
		
		# ✅ FIX 2: Case-insensitive matching for robustness
		var line_upper = line.to_upper()
		
		if line_upper.begins_with("Q:"):
			# ✅ If we already have a complete question, save it before starting new one
			if current_question.has("q") and current_question.has("A") and current_question.has("answer"):
				questions.append(current_question.duplicate(true))
				current_question = {}
			current_question["q"] = line.substr(2).strip_edges()
		elif line_upper.begins_with("A:"):
			current_question["A"] = line.substr(2).strip_edges()
		elif line_upper.begins_with("B:"):
			current_question["B"] = line.substr(2).strip_edges()
		elif line_upper.begins_with("C:"):
			current_question["C"] = line.substr(2).strip_edges()
		elif line_upper.begins_with("D:"):
			current_question["D"] = line.substr(2).strip_edges()
		elif line_upper.begins_with("ANSWER:"):
			var answer_text = line.substr(7).strip_edges().to_upper()
			# Extract just the letter (A, B, C, or D)
			if answer_text.length() > 0:
				current_question["answer"] = answer_text[0]
		else:
			# ✅ Debug: Print unrecognized lines
			if line.length() > 0:
				print("⚠️ Line ", line_num, " unrecognized: ", line.substr(0, 50))

	# Add last block if no blank line at end
	if current_question.has("q") and current_question.has("A") and current_question.has("answer"):
		questions.append(current_question)
	
	print("📊 Total questions parsed:", questions.size())
	
	# ✅ FIX 3: Shuffle questions to avoid repetition
	questions.shuffle()

	return questions
	
	
func _on_tutorial_for_import_clicked():
	# Only allow copying if OptionsGame is visible
	if not options_game.visible:
		return

	var prompt_text := "TOPIC : Dinosaurs

	Generate a multiple-choice questionnaire based on the topic above and the provided material.

	Follow these rules STRICTLY:
	1. Output exactly 30 questions.
	2. Use ONLY the following format — do not add titles, introductions, or explanations.

	FORMAT:
	Q: [Question text]
	A: [Choice 1]
	B: [Choice 2]
	C: [Choice 3]
	D: [Choice 4]
	ANSWER: [Letter of the correct answer]

	3. There must be ONE blank line between each question.
	4. The ANSWER line must use the exact format: ANSWER: [A/B/C/D]
	5. Each question must have exactly four choices labeled A, B, C, and D.
	6. Do NOT use markdown, numbers, or bullet points.
	7. Do NOT include explanations, hints, or extra text — only the questions in the exact format above.
	8. Output a .txt file.
	9. If you cannot follow this exact format, output nothing."

	DisplayServer.clipboard_set(prompt_text)
	if SFX:
		SFX.play_select()

	# Show "Copied!" label only if OptionsGame is visible
	copied_label.visible = true
	_timer_hide_copied_label()
	print("📋 Prompt copied to clipboard!")

func _timer_hide_copied_label():
	var t = Timer.new()
	t.wait_time = 2.0
	t.one_shot = true
	add_child(t)
	t.start()
	t.timeout.connect(Callable(self, "_hide_copied_label"))


func _hide_copied_label():
	copied_label.visible = false

func _on_tutorial_for_import_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tutorial_for_import_clicked()


# ✅ Show visual feedback when questions are imported successfully
func _show_import_success_popup(question_count: int) -> void:
	# Create a temporary label to show success message
	var success_label = Label.new()
	success_label.text = "✅ Successfully imported " + str(question_count) + " questions!\nStarting game..."
	success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style the label
	var label_settings = LabelSettings.new()
	label_settings.font_size = 32
	label_settings.font_color = Color(0, 1, 0)  # Green
	label_settings.outline_size = 4
	label_settings.outline_color = Color(0, 0, 0)
	success_label.label_settings = label_settings
	
	# Position it in the center of the screen
	success_label.position = Vector2(0, 0)
	success_label.size = Vector2(get_viewport().size.x, get_viewport().size.y)
	success_label.z_index = 1000  # Make sure it's on top
	
	add_child(success_label)
	
	# Remove after 2 seconds
	await get_tree().create_timer(2.0).timeout
	success_label.queue_free()


# ❌ Show visual feedback when import fails
func _show_import_error_popup() -> void:
	var error_label = Label.new()
	error_label.text = "❌ Import Failed!\nNo valid questions found.\n\nCheck the console for details."
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style the label
	var label_settings = LabelSettings.new()
	label_settings.font_size = 28
	label_settings.font_color = Color(1, 0, 0)  # Red
	label_settings.outline_size = 4
	label_settings.outline_color = Color(0, 0, 0)
	error_label.label_settings = label_settings
	
	# Position it in the center of the screen
	error_label.position = Vector2(0, 0)
	error_label.size = Vector2(get_viewport().size.x, get_viewport().size.y)
	error_label.z_index = 1000
	
	add_child(error_label)
	
	# Remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	error_label.queue_free()
