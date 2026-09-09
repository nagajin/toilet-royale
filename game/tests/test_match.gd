extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _run() -> void:
	_test_rules()
	game = load("res://scenes/toilet_goal_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await frames(3)
	check(game.match_state.phase == LocalMatch.Phase.LOBBY, "opens in lobby")
	check(game.players.size() == 2, "two players previewed")
	var hud := game.get_node("MatchHUD")
	for count in [1, 2, 3, 4]:
		var choice := _find_button(hud, ["1人 練習", "2人 1対1", "3人 2対1", "4人 2対2"][count - 1])
		choice.pressed.emit()
		await frames(2)
		check(game.selected_count == count and game.players.size() == count, "lobby button selects %d players" % count)
	_find_button(hud, "キックオフ！").pressed.emit()
	check(game.match_state.phase == LocalMatch.Phase.COUNTDOWN, "kickoff button starts match")
	for count in [1, 2, 3, 4]:
		game.selected_count = count
		game.start_match()
		await frames(3)
		check(game.players.size() == count and get_nodes_in_group("players").size() == count, "%d players without stale instances" % count)
	check(game.get_node("Ball").freeze, "ball frozen during countdown")
	var before: Vector3 = game.players[0].position
	Input.action_press("local_p1_right")
	await frames(15)
	Input.action_release("local_p1_right")
	check(game.players[0].position.is_equal_approx(before), "countdown blocks movement")
	_activate()
	await frames(10)
	var first_x: float = game.players[0].position.x
	var second_x: float = game.players[1].position.x
	var third_x: float = game.players[2].position.x
	Input.action_press("local_p1_right")
	Input.action_press("local_p2_left")
	await frames(20)
	Input.action_release("local_p1_right")
	Input.action_release("local_p2_left")
	check(game.players[0].position.x > first_x + 1.0, "P1 moves independently")
	check(game.players[1].position.x < second_x - 1.0, "P2 moves independently")
	check(is_equal_approx(game.players[2].position.x, third_x), "P3 receives no P1/P2 input")
	var fourth_y: float = game.players[3].position.y
	Input.action_press("local_p4_jump")
	await frames(3)
	Input.action_release("local_p4_jump")
	check(game.players[3].position.y > fourth_y + 0.1, "P4 jump works")
	var arrow := InputEventKey.new()
	arrow.physical_keycode = KEY_LEFT
	check(InputMap.event_is_action(arrow, "local_p2_left") and not InputMap.event_is_action(arrow, "local_p1_left"), "arrow key belongs only to P2")
	await _test_push(0)
	await _test_push(1)
	await _test_ball_and_goals()
	game.start_match()
	game._pause()
	var saved_time: float = game.match_state.phase_left
	game._physics_process(10.0)
	check(game.match_state.phase_left == saved_time, "pause stops countdown")
	game._resume()
	check(not paused, "resume restores simulation")
	_activate()
	game.match_state.time_left = 0.01
	game._physics_process(0.02)
	check(game.match_state.phase == LocalMatch.Phase.FINISHED, "timeout reaches result screen")
	await frames(2)
	check(game.get_node("Ball").freeze and not game.players[0].enabled, "finished match freezes players and ball")
	_find_button(hud, "もう一試合！").pressed.emit()
	check(game.match_state.phase == LocalMatch.Phase.COUNTDOWN, "result button starts rematch")
	_activate()
	await frames(3)
	var ball: Ball = game.get_node("Ball")
	game.match_state.scores[0] = 2
	ball.freeze = true
	ball.position = Vector3(0, -6, 0)
	game._physics_process(0.016)
	await frames(3)
	check(game.match_state.phase == LocalMatch.Phase.COUNTDOWN and game.match_state.scores == [2, 0], "out-of-bounds ball restarts without changing score")
	check(ball.position.is_equal_approx(Vector3(0, 1.2, 0)) and ball.freeze, "out-of-bounds reset returns and locks ball")
	game._pause()
	_find_button(hud, "人数選択に戻る").pressed.emit()
	check(not paused and game.match_state.phase == LocalMatch.Phase.LOBBY, "pause menu returns to lobby")
	game.show_lobby()
	check(not paused and game.match_state.scores == [0, 0], "return to lobby clears match")
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _activate() -> void:
	game.match_state.tick(3.1)
	game._enter_phase()

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _find_button(child, caption)
		if found:
			return found
	return null

func _test_rules() -> void:
	var state := LocalMatch.new()
	state.start(4)
	check(not state.award_goal(0), "cannot score before kickoff")
	state.tick(3.0)
	check(state.phase == LocalMatch.Phase.PLAYING and state.time_left == 90.0, "countdown preserves match clock")
	state.tick(2.0)
	check(state.time_left == 88.0, "live play consumes clock")
	check(state.award_goal(0) and state.scores == [0, 1], "red goal awards blue team")
	check(not state.award_goal(0) and not state.award_goal(1), "goal lock rejects repeated scoring")
	state.tick(1.8)
	check(state.phase == LocalMatch.Phase.COUNTDOWN and state.time_left == 88.0, "celebration preserves clock and restarts countdown")
	state.tick(3.0)
	check(state.award_goal(1) and state.scores == [1, 1], "blue goal awards red team")
	state.start(2)
	for index in 5:
		state.tick(3.0)
		state.award_goal(1)
		state.tick(1.8)
	check(state.phase == LocalMatch.Phase.FINISHED and state.winner() == 0, "five goals wins after celebration")
	check(not state.award_goal(1), "no scoring after full time")
	state.start(2)
	state.tick(3.0)
	state.tick(90.0)
	check(state.phase == LocalMatch.Phase.FINISHED and state.winner() == -1, "zero-zero timeout is a draw")
	state.start(1)
	state.tick(3.0)
	state.tick(900.0)
	check(state.phase == LocalMatch.Phase.PLAYING and state.time_left == 90.0, "solo practice has no time limit")
	for index in 6:
		state.award_goal(1)
		state.tick(1.8)
		state.tick(3.0)
	check(state.phase == LocalMatch.Phase.PLAYING and state.scores == [6, 0], "practice continues past five goals")
	state.start(3)
	check(state.scores == [0, 0] and state.time_left == 90.0, "restart resets scores and timer")

func _test_push(driver: int) -> void:
	game.start_match()
	_activate()
	await frames(3)
	game.players[0].position = Vector3(-0.55, 1, 5)
	game.players[1].position = Vector3(0.55, 1, 5)
	await frames(10)
	var target := 1 - driver
	var initial_x: float = game.players[target].position.x
	var action := "local_p1_right" if driver == 0 else "local_p2_left"
	Input.action_press(action)
	await frames(90)
	Input.action_release(action)
	var displacement: float = game.players[target].position.x - initial_x
	print("Push displacement: ", displacement)
	check(displacement > 1.0 if driver == 0 else displacement < -1.0, "P%d can push the other player" % (driver + 1))

func _test_ball_and_goals() -> void:
	game.start_match()
	_activate()
	await frames(10)
	var ball: Ball = game.get_node("Ball")
	game.players[0].position = Vector3(-1.5, 1, 0)
	Input.action_press("local_p1_right")
	await frames(60)
	Input.action_release("local_p1_right")
	check(ball.position.x > 1.0, "player pushes real rigid ball")
	for defending in 2:
		game.start_match()
		_activate()
		await frames(3)
		var direction := -1.0 if defending == 0 else 1.0
		ball.freeze = true
		ball.position = Vector3(direction * 14.0, 0.85, 0)
		ball.linear_velocity = Vector3.ZERO
		await frames(2)
		ball.freeze = false
		ball.sleeping = false
		ball.linear_velocity = Vector3(direction * 12.0, 0, 0)
		await frames(90)
		print("Goal trial: ", ball.position, " scores=", game.match_state.scores)
		check(game.match_state.scores[1 - defending] == 1, "physical ball crosses goal %d and scores for opponent" % defending)
		check(game.match_state.scores[defending] == 0, "goal credited to correct side")
		game.start_match()
		await frames(3)
		check(ball.freeze and ball.get_node("Visual").scale.is_equal_approx(Vector3.ONE), "restart during flush clears tween and retains countdown lock")
		check(not game.get_node("GoalLeft")._celebrating and not game.get_node("GoalRight")._celebrating, "restart clears both goal effects")
	# Exercise crossing geometry directly with a frozen ball, without a scene signal shortcut.
	_activate()
	await frames(3)
	ball.set_locked(true)
	await frames(2)
	var goal: ToiletGoal = game.get_node("GoalLeft")
	ball.position = goal.to_global(Vector3(-2.0, 1, 0))
	goal.set_scoring_enabled(true)
	ball.position = goal.to_global(Vector3(0.0, 1, 0))
	goal._physics_process(0.016)
	check(game.match_state.scores == [0, 0], "crossing from behind cannot score")
	ball.position = goal.to_global(Vector3(0.0, 1, 3.0))
	goal.set_scoring_enabled(true)
	ball.position = goal.to_global(Vector3(-2.0, 1, 3.0))
	goal._physics_process(0.016)
	check(game.match_state.scores == [0, 0], "crossing outside opening cannot score")
	ball.position = goal.to_global(Vector3(0.0, 5, 0))
	goal.set_scoring_enabled(true)
	ball.position = goal.to_global(Vector3(-2.0, 5, 0))
	goal._physics_process(0.016)
	check(game.match_state.scores == [0, 0], "crossing above opening cannot score")
