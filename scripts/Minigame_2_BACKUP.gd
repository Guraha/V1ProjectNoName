extends Node3D

# --- nodes (expected in scene) ---
@onready var area_a: Area3D = $ALabel/Area3D
@onready var area_b: Area3D = $BLabel/Area3D
@onready var area_c: Area3D = $CLabel/Area3D
@onready var area_d: Area3D = $DLabel/Area3D
@onready var timer: Timer = $Timer
@onready var timer_value: Label3D = $TimerValue
@onready var question_label: Label3D = $QuestionLabel
@onready var labelA: Label3D = $ALabel/Area3D/ValueLabel
@onready var labelB: Label3D = $BLabel/Area3D/ValueLabel
@onready var labelC: Label3D = $CLabel/Area3D/ValueLabel
@onready var labelD: Label3D = $DLabel/Area3D/ValueLabel
@onready var player1: CharacterBody3D = $Player1
@onready var player2: CharacterBody3D = $Player2
@onready var player1_score_label: Label3D = $Player1/Score
@onready var player2_score_label: Label3D = $Player2/Score
@onready var highlight_a: MeshInstance3D = $ALabel/Area3D/Highlight
@onready var highlight_b: MeshInstance3D = $BLabel/Area3D/Highlight
@onready var highlight_c: MeshInstance3D = $CLabel/Area3D/Highlight
@onready var highlight_d: MeshInstance3D = $DLabel/Area3D/Highlight

# Optional spawn points (safe to be missing)
@onready var spawn_p1: Node3D = get_node_or_null("SpawnPointP1")
@onready var spawn_p2: Node3D = get_node_or_null("SpawnPointP2")

# --- particle systems (created dynamically) ---
var particle_correct: GPUParticles3D
var particle_wrong: GPUParticles3D
var particle_selection: GPUParticles3D

# --- game state ---
var player1_score: int = 0
var player2_score: int = 0
var current_player: int = 1
var chosen_answer: String = ""
var correct_answer: String = ""  # set per question
var current_question_index: int = 0
var is_round_active: bool = false

# --- question bank (sample). Replace/populate as you like ---
var question_data: Array = [
	{"q":"What is the capital of France?", "A":"Berlin", "B":"Paris", "C":"Rome", "D":"Madrid", "answer":"B"},
	{"q":"Largest planet in the Solar System?", "A":"Earth", "B":"Mars", "C":"Jupiter", "D":"Venus", "answer":"C"},
	{"q":"What color do you get by mixing red and blue?", "A":"Green", "B":"Purple", "C":"Orange", "D":"Brown", "answer":"B"}
]

# --- reusable materials (avoid creating each frame) ---
var mat_green: StandardMaterial3D
var mat_red: StandardMaterial3D
var mat_yellow: StandardMaterial3D
var mat_glow_green: StandardMaterial3D
var mat_glow_red: StandardMaterial3D

# --- tweens for animations ---
var active_tweens: Array[Tween] = []

func _ready() -> void:
	# create & cache materials with emission for glow effects
	mat_green = _create_material(Color(0, 1, 0), Color(0, 0.5, 0))
	mat_red = _create_material(Color(1, 0, 0), Color(0.5, 0, 0))
	mat_yellow = _create_material(Color(1, 1, 0), Color(0.5, 0.5, 0))
	mat_glow_green = _create_material(Color(0, 1, 0), Color(0, 2, 0))
	mat_glow_red = _create_material(Color(1, 0, 0), Color(2, 0, 0))
	
	# setup particle systems
	_setup_particles()

	# connect timer safely (avoid double connect)
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	# connect area signals (entered + exited)
	_connect_area_signals()

	# initial visual state
	_hide_all_highlights()
	_set_player_active(player1, true)
	_set_player_active(player2, false)
	
	# animate score labels in
	_animate_label_fade_scale(player1_score_label, 0.0, 1.0, 0.5)
	_animate_label_fade_scale(player2_score_label, 0.0, 1.0, 0.5)
	player1_score_label.text = str(player1_score)
	player2_score_label.text = str(player2_score)

	# start with delay
	await get_tree().create_timer(0.5).timeout
	start_round()

func _create_material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 1.0
	return mat

func _setup_particles() -> void:
	# Correct answer particles (green sparkles)
	particle_correct = _create_particle_system(Color(0, 1, 0, 1))
	add_child(particle_correct)
	
	# Wrong answer particles (red poof)
	particle_wrong = _create_particle_system(Color(1, 0, 0, 1))
	add_child(particle_wrong)
	
	# Selection particles (yellow glow)
	particle_selection = _create_particle_system(Color(1, 1, 0, 1))
	add_child(particle_selection)

func _create_particle_system(color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 32
	particles.lifetime = 1.0
	particles.explosiveness = 0.8
	
	# Create process material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = color
	particles.process_material = mat
	
	# Create simple sphere mesh for particles
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	return particles

func _connect_area_signals() -> void:
	# disconnect existing connections for safety
	for area_pair in [{"area":area_a, "id":"A"}, {"area":area_b, "id":"B"}, {"area":area_c, "id":"C"}, {"area":area_d, "id":"D"}]:
		var a: Area3D = area_pair["area"]
		var id: String = area_pair["id"]
		# disconnect any previous bound callables from these signals to avoid duplicate calls
		for conn in a.body_entered.get_connections():
			a.body_entered.disconnect(conn["callable"])
		for conn in a.body_exited.get_connections():
			a.body_exited.disconnect(conn["callable"])
		# connect new
		a.body_entered.connect(_on_area_entered.bind(id))
		a.body_exited.connect(_on_area_exited.bind(id))

func start_round() -> void:
	# guard: if no questions, stop
	if question_data.size() == 0:
		print("No questions available.")
		return

	# prepare round
	is_round_active = true
	chosen_answer = ""
	_hide_all_highlights()
	_kill_active_tweens()
	timer.stop()
	timer_value.text = "10"
	
	# ensure current question index wraps
	if current_question_index >= question_data.size():
		current_question_index = 0

	var data = question_data[current_question_index]
	correct_answer = data.get("answer", "A")

	# reposition current player to spawn (if provided) to avoid stacking
	_spawn_current_player()
	
	# animate question label with fade-in scale
	_animate_label_fade_scale(question_label, 0.0, 1.0, 0.3)

	# typewriter sequence — only continue if round still active
	await _typewriter_text(question_label, data["q"])
	if not is_round_active:
		return
	
	# animate answer labels appearing with stagger
	_animate_label_fade_scale(labelA, 0.0, 1.0, 0.3)
	await _typewriter_text(labelA, "A: " + data["A"])
	if not is_round_active:
		return
	
	_animate_label_fade_scale(labelB, 0.0, 1.0, 0.3)
	await _typewriter_text(labelB, "B: " + data["B"])
	if not is_round_active:
		return
	
	_animate_label_fade_scale(labelC, 0.0, 1.0, 0.3)
	await _typewriter_text(labelC, "C: " + data["C"])
	if not is_round_active:
		return
	
	_animate_label_fade_scale(labelD, 0.0, 1.0, 0.3)
	await _typewriter_text(labelD, "D: " + data["D"])
	if not is_round_active:
		return

	# start countdown with pulse animation
	_animate_timer_pulse()
	timer.start(10.0)

func _process(_delta: float) -> void:
	# only update display when timer running
	if timer.is_stopped():
		return
	var time_left := int(ceil(timer.time_left))
	timer_value.text = str(time_left)
	
	# pulse timer when time is running low
	if time_left <= 3 and not timer_value.modulate.is_equal_approx(Color.RED):
		_animate_timer_urgent()

func _on_area_entered(body: Node, answer: String) -> void:
	# only allow current player to select
	if not is_round_active:
		return
	if body == get_current_player():
		chosen_answer = answer
		_highlight_selected(answer)
		# play selection particle effect
		var highlight_pos: Vector3 = _get_highlight_position(answer)
		if highlight_pos != Vector3.ZERO:
			_spawn_particles(particle_selection, highlight_pos)

func _on_area_exited(body: Node, answer: String) -> void:
	# deselect if current player leaves the area they had chosen
	if not is_round_active:
		return
	if body == get_current_player() and chosen_answer == answer:
		chosen_answer = ""
		_hide_all_highlights()

func _on_timer_timeout() -> void:
	# guard against multiple timeouts by disabling round early
	if not is_round_active:
		return
	_check_answer()

func _check_answer() -> void:
	# stop round interactions and physics while checking
	is_round_active = false
	timer.stop()
	# temporarily disable current player's physics so they can't move while feedback shows
	_set_player_active(get_current_player(), false)

	if chosen_answer == "":
		print("⏰ Time's up — no answer chosen.")
	elif chosen_answer == correct_answer:
		_add_score()
		_show_feedback(true)
	else:
		_show_feedback(false)

	# reveal correct and wrong highlights, wait, then continue
	await _highlight_correct_answer() # uses the function's await pattern

	# small pacing delay
	await get_tree().create_timer(0.5).timeout

	# check for winner
	if player1_score >= 15 or player2_score >= 15:
		_end_game()
	else:
		# advance question index only after both players had their turn
		# we increment here so next round uses next question
		current_question_index += 1
		_next_turn()

func _add_score() -> void:
	var score_label := player1_score_label if current_player == 1 else player2_score_label
	
	if current_player == 1:
		player1_score += 1
		player1_score_label.text = str(player1_score)
	else:
		player2_score += 1
		player2_score_label.text = str(player2_score)
	
	# animate score with bounce effect
	_animate_score_bounce(score_label)

func _show_feedback(is_correct: bool) -> void:
	var player := get_current_player()
	var feedback_pos: Vector3 = player.global_position + Vector3(0, 2, 0)
	
	if is_correct:
		print("✅ Correct!")
		_spawn_particles(particle_correct, feedback_pos)
		# flash player green
		_flash_player(player, Color.GREEN)
	else:
		print("❌ Wrong!")
		_spawn_particles(particle_wrong, feedback_pos)
		# flash player red
		_flash_player(player, Color.RED)

func _next_turn() -> void:
	# switch active player and re-enable them
	if current_player == 1:
		_set_player_active(player1, false)
		_set_player_active(player2, true)
		current_player = 2
	else:
		_set_player_active(player2, false)
		_set_player_active(player1, true)
		current_player = 1

	# animate player transition
	var active_player := get_current_player()
	_bounce_player(active_player)
	
	# slight delay to give player a moment
	await get_tree().create_timer(0.8).timeout
	start_round()

func _end_game() -> void:
	timer.stop()
	_kill_active_tweens()
	
	# disable both players
	_set_player_active(player1, false)
	_set_player_active(player2, false)

	print("🎮 Game Over!")
	
	var winner_label: Label3D
	var winner_pos: Vector3
	
	if player1_score > player2_score:
		print("🏆 Player 1 Wins!")
		winner_label = player1_score_label
		winner_pos = player1.global_position + Vector3(0, 3, 0)
		_spawn_particles(particle_correct, winner_pos)
	elif player2_score > player1_score:
		print("🏆 Player 2 Wins!")
		winner_label = player2_score_label
		winner_pos = player2.global_position + Vector3(0, 3, 0)
		_spawn_particles(particle_correct, winner_pos)
	else:
		print("🤝 It's a tie!")
		return
	
	# animate winner celebration
	_celebrate_winner(winner_label)

func get_current_player() -> Node:
	return player1 if current_player == 1 else player2

# --- utility: typewriter with round-safety ---
func _typewriter_text(label: Label3D, full_text: String, speed := 0.03) -> void:
	label.text = ""
	for c in full_text:
		# if round was canceled, break early
		if not is_round_active:
			return
		label.text += c
		await get_tree().create_timer(speed).timeout

# --- highlights ---
func _highlight_correct_answer() -> void:
	var highlights := {"A": highlight_a, "B": highlight_b, "C": highlight_c, "D": highlight_d}
	
	# show all with animation; correct = green glow, others = red
	for key in highlights.keys():
		var h: MeshInstance3D = highlights[key]
		h.visible = true
		h.scale = Vector3.ZERO
		
		var is_correct: bool = (key == correct_answer)
		h.set_surface_override_material(0, mat_glow_green if is_correct else mat_glow_red)
		
		# animate scale pop-in
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(h, "scale", Vector3.ONE * 1.2, 0.3)
		active_tweens.append(tween)
		
		# spawn particles on correct answer
		if is_correct:
			_spawn_particles(particle_correct, h.global_position)
	
	# wait while visible
	await get_tree().create_timer(2.5).timeout
	
	# fade out highlights
	for key in highlights.keys():
		var h: MeshInstance3D = highlights[key]
		var tween := create_tween()
		tween.tween_property(h, "scale", Vector3.ZERO, 0.2)
		active_tweens.append(tween)
	
	await get_tree().create_timer(0.3).timeout
	_hide_all_highlights()

func _highlight_selected(answer: String) -> void:
	var highlights := {"A": highlight_a, "B": highlight_b, "C": highlight_c, "D": highlight_d}
	
	for k in highlights.keys():
		var h: MeshInstance3D = highlights[k]
		var is_selected: bool = (k == answer)
		h.visible = is_selected
		
		if is_selected:
			h.set_surface_override_material(0, mat_yellow)
			h.scale = Vector3.ZERO
			
			# pulse animation
			var tween := create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(h, "scale", Vector3.ONE, 0.5)
			active_tweens.append(tween)
			
			# continuous gentle bobbing
			var bob_tween := create_tween()
			bob_tween.set_loops()
			bob_tween.tween_property(h, "position:y", h.position.y + 0.2, 0.8).set_ease(Tween.EASE_IN_OUT)
			bob_tween.tween_property(h, "position:y", h.position.y, 0.8).set_ease(Tween.EASE_IN_OUT)
			active_tweens.append(bob_tween)

func _hide_all_highlights() -> void:
	for h in [highlight_a, highlight_b, highlight_c, highlight_d]:
		h.visible = false
		h.scale = Vector3.ONE

# --- animation helpers ---
func _kill_active_tweens() -> void:
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()

func _animate_label_fade_scale(label: Label3D, from_alpha: float, to_alpha: float, duration: float) -> void:
	label.modulate.a = from_alpha
	label.scale = Vector3.ONE * 0.5
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", to_alpha, duration)
	tween.tween_property(label, "scale", Vector3.ONE, duration)
	active_tweens.append(tween)

func _animate_timer_pulse() -> void:
	timer_value.modulate = Color.WHITE
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(timer_value, "scale", Vector3.ONE * 1.1, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(timer_value, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_IN_OUT)
	active_tweens.append(tween)

func _animate_timer_urgent() -> void:
	_kill_active_tweens()
	timer_value.modulate = Color.RED
	
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(timer_value, "scale", Vector3.ONE * 1.3, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(timer_value, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_IN)
	active_tweens.append(tween)

func _animate_score_bounce(label: Label3D) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(label, "scale", Vector3.ONE * 1.5, 0.3)
	tween.tween_property(label, "scale", Vector3.ONE, 0.3)
	active_tweens.append(tween)
	
	# flash color
	var original_modulate := label.modulate
	var flash_tween := create_tween()
	flash_tween.tween_property(label, "modulate", Color.YELLOW, 0.1)
	flash_tween.tween_property(label, "modulate", original_modulate, 0.3)
	active_tweens.append(flash_tween)

func _flash_player(player: CharacterBody3D, color: Color) -> void:
	var mesh_instance := player.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	
	var original_modulate: Color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(mesh_instance, "modulate", color, 0.15)
	tween.tween_property(mesh_instance, "modulate", original_modulate, 0.3)
	active_tweens.append(tween)

func _bounce_player(player: CharacterBody3D) -> void:
	var original_pos := player.position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(player, "position:y", original_pos.y + 1.5, 0.4)
	tween.tween_property(player, "position:y", original_pos.y, 0.4)
	active_tweens.append(tween)

func _celebrate_winner(label: Label3D) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * 2.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "rotation:y", TAU, 1.0)
	
	var color_tween := create_tween()
	color_tween.set_loops()
	color_tween.tween_property(label, "modulate", Color.YELLOW, 0.3)
	color_tween.tween_property(label, "modulate", Color.GREEN, 0.3)
	color_tween.tween_property(label, "modulate", Color.CYAN, 0.3)
	
	active_tweens.append(tween)
	active_tweens.append(color_tween)

# --- particle helpers ---
func _spawn_particles(particles: GPUParticles3D, pos: Vector3) -> void:
	if not particles:
		return
	particles.global_position = pos
	particles.emitting = true
	particles.restart()

func _get_highlight_position(answer: String) -> Vector3:
	var highlights := {"A": highlight_a, "B": highlight_b, "C": highlight_c, "D": highlight_d}
	if answer in highlights:
		return highlights[answer].global_position
	return Vector3.ZERO

# --- players & collisions ---
func _set_player_active(player: CharacterBody3D, active: bool) -> void:
	# toggle visible + processing
	player.visible = active
	player.set_physics_process(active)
	player.set_process(active)
	# disable/enable collision shape if present
	var collision_shape := player.get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = not active

func _spawn_current_player() -> void:
	# if spawn point for current player exists, move them there
	if current_player == 1 and spawn_p1:
		player1.global_transform = spawn_p1.global_transform
	elif current_player == 2 and spawn_p2:
		player2.global_transform = spawn_p2.global_transform
