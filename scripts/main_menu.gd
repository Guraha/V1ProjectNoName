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

	# --- Button connections ---
	start_game.pressed.connect(_on_start_game_pressed)
	options.pressed.connect(_on_options_pressed)
	quit_game.pressed.connect(_on_quit_game_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	main_menu2.pressed.connect(_on_main_menu_pressed)
	import_questionnaire.pressed.connect(_on_import_questionnaire_pressed)
	start_game_as_is.pressed.connect(_on_start_game_as_is_pressed)
	copy_prompt.pressed.connect(_on_tutorial_for_import_clicked)

	# --- Sliders ---
	background_music_h_slider.value = SFX.music_volume * 100
	sfx_h_slider.value = SFX.sfx_volume * 100

	background_music_h_slider.value_changed.connect(_on_music_slider_changed)
	sfx_h_slider.value_changed.connect(_on_sfx_slider_changed)

	# --- Hover/Click for Game 1 ---
	if game_1:
		game_1.mouse_entered.connect(_on_game_hover.bind(game_1, true))
		game_1.mouse_exited.connect(_on_game_hover.bind(game_1, false))
		game_1.gui_input.connect(_on_game_clicked.bind(game_1))
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


# === GAME CLICK HANDLER ===
func _on_game_clicked(event: InputEvent, control: Control):
	if event is InputEventMouseButton and event.pressed:
		if control == game_1:
			SFX.play_accept()
			_start_minigame("res://assets/minigames/minigame_1_ui.tscn", "minigame_1")
		elif control == game_2:
			SFX.play_accept()
			_start_minigame("res://partial_scripts/Minigame_2.tscn", "minigame_2")


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



# === FILE DIALOG HANDLER ===
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

	# Parse formatted text into structured question objects
	var parsed_questions = _parse_questions(content)

	if parsed_questions.size() == 0:
		printerr("⚠ No valid questions found in the file.")
		return

	# Store in global GameData singleton
	GameData.imported_questions = parsed_questions
	print("✅ Import successful! Questions stored in GameData.")
	print("Total questions:", parsed_questions.size())

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

	for line in lines:
		line = line.strip_edges()
		if line == "":
			# Empty line means end of a question block
			if current_question.has("q") and current_question.has("A") and current_question.has("answer"):
				questions.append(current_question.duplicate(true))
			current_question = {}
			continue

		if line.begins_with("Q:"):
			current_question["q"] = line.replace("Q:", "").strip_edges()
		elif line.begins_with("A:"):
			current_question["A"] = line.replace("A:", "").strip_edges()
		elif line.begins_with("B:"):
			current_question["B"] = line.replace("B:", "").strip_edges()
		elif line.begins_with("C:"):
			current_question["C"] = line.replace("C:", "").strip_edges()
		elif line.begins_with("D:"):
			current_question["D"] = line.replace("D:", "").strip_edges()
		elif line.begins_with("ANSWER:"):
			current_question["answer"] = line.replace("ANSWER:", "").strip_edges().to_upper()

	# Add last block if no blank line at end
	if current_question.has("q") and current_question.has("A") and current_question.has("answer"):
		questions.append(current_question)

	return questions
	
	
func _on_tutorial_for_import_clicked():
	# Only allow copying if OptionsGame is visible
	if not options_game.visible:
		return

	var prompt_text := "Generate a multiple-choice questionnaire based on the following topic and material: Topic: Dinosaurs Follow these rules STRICTLY: 1. Output exactly 20 questions. 2. Use ONLY the following format — do not add titles, introductions, or explanations. FORMAT: Q: [Question text] A: [Choice 1] B: [Choice 2] C: [Choice 3] D: [Choice 4] ANSWER: [Letter of the correct answer] 3. There must be ONE blank line between each question. 4. The correct answer line must use the exact format: ANSWER: [A/B/C/D] 5. Each question must have exactly four choices labeled A, B, C, and D. 6. Do NOT use markdown, numbering, or bullet points. 7. Do NOT include explanations, hints, or extra text — only the questions in the exact format above. 8. Output plain text only. 9. If you cannot follow this exact format, output nothing."

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
