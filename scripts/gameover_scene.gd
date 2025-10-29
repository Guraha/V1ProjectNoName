extends Node3D
@export var winner_id: int = 1
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

var showing_minimap_1: bool = true


func _ready() -> void:
	_play_game_over_sequence()
	SFX.play_game_over()
	minigame_1.visible = true
	minigame_2.visible = false


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
