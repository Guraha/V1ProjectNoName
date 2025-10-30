extends Node
class_name SFXManager

# === Node references ===
@onready var ui_accept_player: AudioStreamPlayer2D = $UIAcceptPlayer
@onready var move_player: AudioStreamPlayer2D = $MovePlayer
@onready var select_player: AudioStreamPlayer2D = $SelectPlayer
@onready var correct_sfx: AudioStreamPlayer2D = $CorrectSFX
@onready var wrong_sfx: AudioStreamPlayer2D = $WrongSFX
@onready var score_sfx: AudioStreamPlayer2D = $ScoreSFX
@onready var round_start_sfx: AudioStreamPlayer2D = $RoundStartSFX
@onready var game_over_sfx: AudioStreamPlayer2D = $GameOverSFX
@onready var timer_warning_sfx: AudioStreamPlayer2D = $TimerWarningSFX
@onready var _5_seconds_timer_warning_sfx: AudioStreamPlayer2D = $"5SecondsTimerWarningSFX"
@onready var footsteps: AudioStreamPlayer2D = $Footsteps
@onready var running: AudioStreamPlayer2D = $Running



# === Background music players ===
@onready var bgm_player_main_menu: AudioStreamPlayer2D = $BGMPlayer_MainMenu
@onready var bgm_player_minigame_1: AudioStreamPlayer2D = $BGMPlayer_Minigame1
@onready var bgm_player_minigame_2: AudioStreamPlayer2D = $BGMPlayer_Minigame2

# === Volume levels ===
@export var music_volume: float = 0.5
@export var sfx_volume: float = 0.5

# Keep track of current BGM
var current_bgm: AudioStreamPlayer2D = null


func _ready():
	# Ensure sane defaults (prevents NaN issues)
	if music_volume == null or is_nan(music_volume):
		music_volume = 0.5
	if sfx_volume == null or is_nan(sfx_volume):
		sfx_volume = 0.5
	
	# Make BGM players continue playing even when game is paused
	bgm_player_main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player_minigame_1.process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player_minigame_2.process_mode = Node.PROCESS_MODE_ALWAYS
	
	_update_volumes()


# === BGM CONTROL ===
func play_bgm(which: String):
	# Stop current BGM if another is playing
	if current_bgm and current_bgm.playing:
		current_bgm.stop()

	match which:
		"main_menu":
			current_bgm = bgm_player_main_menu
		"minigame_1":
			current_bgm = bgm_player_minigame_1
		"minigame_2":
			current_bgm = bgm_player_minigame_2
		_:
			push_warning("Unknown BGM name: %s" % which)
			return

	current_bgm.volume_db = linear_to_db(music_volume)
	current_bgm.play()


func stop_bgm():
	if current_bgm and current_bgm.playing:
		current_bgm.stop()


func fade_out_bgm(duration := 1.0):
	if not current_bgm:
		return
	var tween = get_tree().create_tween()
	tween.tween_property(current_bgm, "volume_db", -80, duration)
	tween.tween_callback(Callable(current_bgm, "stop"))
	tween.tween_property(current_bgm, "volume_db", linear_to_db(music_volume), 0.1)


# === SFX PLAYERS ===
func play_move(): move_player.play()
func play_select(): select_player.play()
func play_accept(): ui_accept_player.play()

func play_correct():
	if correct_sfx and correct_sfx.stream:
		print("[SFX] ✅ Playing correct answer sound")
		SFX.play_correct()
	else:
		push_warning("[SFX] ⚠️ Correct SFX not configured or missing audio stream!")

func play_wrong():
	if wrong_sfx and wrong_sfx.stream:
		print("[SFX] ❌ Playing wrong answer sound")
		SFX.play_wrong()
	else:
		push_warning("[SFX] ⚠️ Wrong SFX not configured or missing audio stream!")

func play_score(): score_sfx.play()
func play_round_start(): round_start_sfx.play()
func play_game_over(): game_over_sfx.play()
func play_timer_warning(): timer_warning_sfx.play()
func play_5timer_warning(): _5_seconds_timer_warning_sfx.play()
func play_footsteps(): footsteps.play()
func play_running(): running.play()
func stop_movement_sounds():
	footsteps.stop()
	running.stop()

# === VOLUME MANAGEMENT ===
func set_music_volume(value: float):
	if is_nan(value):
		value = 0.5
	music_volume = clamp(value, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(value: float):
	if is_nan(value):
		value = 0.5
	sfx_volume = clamp(value, 0.0, 1.0)
	_update_volumes()

func _update_volumes():
	# Apply linear volume (0.0–1.0) to decibels
	for bgm in [bgm_player_main_menu, bgm_player_minigame_1, bgm_player_minigame_2]:
		bgm.volume_db = linear_to_db(music_volume)

	var sfx_players = [
		ui_accept_player, move_player, select_player, correct_sfx,
		wrong_sfx, score_sfx, round_start_sfx, game_over_sfx, timer_warning_sfx,_5_seconds_timer_warning_sfx
	]
	for p in sfx_players:
		if p:
			p.volume_db = linear_to_db(sfx_volume)


# === Utility ===
func linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
