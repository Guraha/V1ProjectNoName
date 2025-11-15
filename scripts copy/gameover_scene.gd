extends Node3D
@onready var animation_player: AnimationPlayer = $SubViewport2/Path3D/AnimationTree/AnimationPlayer

@onready var player_1_won: Node3D = $SubViewport2/Player1_Won
@onready var player_1_lost: Node3D = $SubViewport2/Player1_Lost
@onready var player_2_won: Node3D = $SubViewport2/Player2_Won
@onready var player_2_lost: Node3D = $SubViewport2/Player2_Lost

@onready var player_1_lost_animation_player: AnimationPlayer = $SubViewport2/Player1_Lost/AnimationPlayer
@onready var player_1_won_animation_player: AnimationPlayer = $SubViewport2/Player1_Won/AnimationPlayer
@onready var player_2_won_animation_player: AnimationPlayer = $SubViewport2/Player2_Won/AnimationPlayer
@onready var player_2_lost_animation_player: AnimationPlayer = $SubViewport2/Player2_Lost/AnimationPlayer

@onready var minigame_1: Node3D = $SubViewport/Minigame_1
@onready var minigame_2: Node3D = $SubViewport/Minigame_2

@onready var restart: Button = $Sprite2D/VBoxContainer/Restart
@onready var main_menu: Button = $Sprite2D/VBoxContainer/MainMenu


var showing_minimap_1: bool = true
var winner_id: int = 1  # Will be set from GameData in _ready()


func _ready() -> void:
	# ✅ Get winner_id from GameData
	winner_id = GameData.winner_id
	
	# ✅ Make sure mouse is visible and not captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	
	# ✅ Show minimap based on GameData (do this BEFORE playing animations)
	if GameData.current_minimap == 1:
		minigame_1.visible = true
		minigame_2.visible = false
		# Keep local toggle in sync with global setting so restart uses the correct scene
		showing_minimap_1 = true
	else:
		minigame_1.visible = false
		minigame_2.visible = true
		# Keep local toggle in sync with global setting so restart uses the correct scene
		showing_minimap_1 = false

	# Connect buttons
	restart.pressed.connect(_on_restart_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	
	# Wait for SubViewports to fully render before playing animations
	await get_tree().process_frame
	
	_play_game_over_sequence()
	SFX.play_game_over()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_play_game_over_sequence() # 🌀 Replay everything

	# 🎯 Toggle minimap visibility using the input map action
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_minimap()


func _toggle_minimap() -> void:
	showing_minimap_1 = !showing_minimap_1
	minigame_1.visible = showing_minimap_1
	minigame_2.visible = !showing_minimap_1

	# Update global minimap setting
	GameData.current_minimap = 1 if showing_minimap_1 else 2


func _play_game_over_sequence() -> void:
	# 🫥 Hide all player variants first
	player_1_won.visible = false
	player_2_won.visible = false
	player_1_lost.visible = false
	player_2_lost.visible = false

	# ⏹ Stop any active animations
	animation_player.stop()
	player_1_won_animation_player.stop()
	player_2_lost_animation_player.stop()

	# 🎥 Play the camera/game over animation
	animation_player.play("GameOver")

	# 🎭 Trigger winner/loser animations
	_play_victory_defeat_sequence()

func _play_victory_defeat_sequence() -> void:
	if winner_id == 1:
		player_1_won.visible = true
		player_2_lost.visible = true
		player_1_won_animation_player.play("Wave")
		player_2_lost_animation_player.play("Death")
	else:
		player_2_won.visible = true
		player_1_lost.visible = true
		player_2_won_animation_player.play("Wave")
		player_1_lost_animation_player.play("Death")


# --- CALLBACKS ---

func _on_player1_animation_finished(anim_name: String) -> void:
	if anim_name.to_lower() == "wave":
		player_1_won_animation_player.play("Wave_Perm")


func _on_player2_animation_finished(anim_name: String) -> void:
	if anim_name.to_lower() == "death":
		player_2_lost_animation_player.play("Death_Perm")

func _on_restart_pressed() -> void:
	var scene_path: String

	# Read directly from the authoritative global setting to avoid local desync
	if GameData.current_minimap == 1:
		scene_path = "res://assets/minigames/minigame_1_ui.tscn"
	else:
		scene_path = "res://partial_scripts/Minigame_2.tscn"
	
	# Use FadeManager for smooth transition
	FadeManager.fade_to_scene(scene_path)

func _on_main_menu_pressed() -> void:
	# Use FadeManager for smooth transition
	FadeManager.fade_to_scene("res://scenes/main_menu.tscn")
