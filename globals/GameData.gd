extends Node

var imported_questions: Array = []

# Add this to track which minimap should be shown
var current_minimap: int = 1 # 1 = minigame_1, 2 = minigame_2

# Track winner for game over scene
var winner_id: int = 1

# Track difficulty mode for minigame 1
var minigame1_difficulty: String = "normal" # "normal" or "hard"

# Points required to win (configurable from main menu)
var points_required: int = 10

func reset():
	imported_questions.clear()
	current_minimap = 1
	winner_id = 1
	minigame1_difficulty = "normal"
	points_required = 10
