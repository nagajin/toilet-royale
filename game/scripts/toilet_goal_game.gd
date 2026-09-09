extends Node3D

const PLAYER_SCENE := preload("res://scenes/goal_player.tscn")
const TEAM_COLORS := [Color("ff675e"), Color("61baff")]
const TEAM_NAMES := ["あか", "あお"]
const SPAWNS := [Vector3(-7, 1, 0), Vector3(7, 1, 0), Vector3(-7, 1, 6), Vector3(7, 1, -6)]

var match_state := LocalMatch.new()
var players: Array[GoalPlayer] = []
var selected_count := 2

@onready var _goals: Array[ToiletGoal] = [$GoalLeft, $GoalRight]
@onready var _ball: Ball = $Ball
@onready var _ui = $MatchHUD
@onready var _rig = $CameraRig

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		if child is Node3D:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	LocalControls.configure()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for goal in _goals:
		goal.watch_ball(_ball)
		goal.ball_entered.connect(_on_goal)
	_ui.start_requested.connect(start_match)
	_ui.count_changed.connect(_select_count)
	_ui.resume_requested.connect(_resume)
	_ui.lobby_requested.connect(show_lobby)
	show_lobby()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var previous := match_state.phase
	match_state.tick(delta)
	if previous != match_state.phase:
		_enter_phase()
	if match_state.phase == LocalMatch.Phase.PLAYING:
		var pos := _ball.global_position
		if pos.y < -5.0 or absf(pos.x) > 26.0 or absf(pos.z) > 16.0:
			match_state.phase = LocalMatch.Phase.COUNTDOWN
			match_state.phase_left = LocalMatch.COUNTDOWN_SECONDS
			_enter_phase()
	_ui.update_match(match_state)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		if get_tree().paused:
			_resume()
		elif match_state.phase in [LocalMatch.Phase.COUNTDOWN, LocalMatch.Phase.PLAYING, LocalMatch.Phase.GOAL]:
			_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_game") and match_state.phase != LocalMatch.Phase.LOBBY:
		start_match()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if match_state.phase in [LocalMatch.Phase.COUNTDOWN, LocalMatch.Phase.PLAYING, LocalMatch.Phase.GOAL]:
			_pause()

func _select_count(count: int) -> void:
	selected_count = count
	_spawn_players(count)
	_ui.show_lobby(count)

func show_lobby() -> void:
	get_tree().paused = false
	match_state = LocalMatch.new()
	match_state.player_count = selected_count
	_spawn_players(selected_count)
	_reset_pitch()
	_set_playing(false)
	_ui.update_match(match_state)
	_ui.show_lobby(selected_count)

func start_match() -> void:
	get_tree().paused = false
	_spawn_players(selected_count)
	match_state.start(selected_count)
	_ui.hide_menu()
	_enter_phase()
	_ui.update_match(match_state)

func _spawn_players(count: int) -> void:
	for player in players:
		remove_child(player)
		player.queue_free()
	players.clear()
	for index in count:
		var player: GoalPlayer = PLAYER_SCENE.instantiate()
		player.player_index = index
		player.team_index = index % 2
		player.team_color = TEAM_COLORS[player.team_index]
		player.position = SPAWNS[index]
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		player.set_enabled(false)
		players.append(player)

func _enter_phase() -> void:
	match match_state.phase:
		LocalMatch.Phase.COUNTDOWN:
			_set_playing(false)
			_reset_pitch()
		LocalMatch.Phase.PLAYING:
			_set_playing(true)
		LocalMatch.Phase.FINISHED:
			_set_playing(false)
			_ui.show_result(match_state)

func _set_playing(enabled: bool) -> void:
	for player in players:
		player.set_enabled(enabled)
	_ball.set_locked(not enabled)
	for goal in _goals:
		goal.set_scoring_enabled(enabled)

func _reset_pitch() -> void:
	_ball.reset_to_spawn()
	for player in players:
		player.reset_to_spawn()
	for goal in _goals:
		goal.reset_effects()

func _on_goal(goal: ToiletGoal) -> void:
	var defending_team := _goals.find(goal)
	if not match_state.award_goal(defending_team):
		return
	_set_playing(false)
	goal.celebrate()
	_ball.play_flush(goal.global_position + goal.global_basis * Vector3(-2.5, 0.1, 0))
	_rig.kick(0.4)
	_ui.show_goal(TEAM_NAMES[1 - defending_team], TEAM_COLORS[1 - defending_team])
	_ui.update_match(match_state)

func _pause() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	_ui.show_pause()

func _resume() -> void:
	get_tree().paused = false
	_ui.hide_menu()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	LocalControls.configure()
	if match_state.phase in [LocalMatch.Phase.COUNTDOWN, LocalMatch.Phase.PLAYING, LocalMatch.Phase.GOAL]:
		_pause()
	elif match_state.phase == LocalMatch.Phase.LOBBY:
		_ui.show_lobby(selected_count)
