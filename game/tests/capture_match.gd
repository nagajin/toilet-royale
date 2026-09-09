extends SceneTree

## Visual smoke check: run without --headless. Images are written to /tmp.
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	for index in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/toilet-royale-" + label + ".png")
	print("Captured: ", label)

func _run() -> void:
	game = load("res://scenes/toilet_goal_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await capture("lobby")
	game.selected_count = 4
	game.start_match()
	await capture("countdown")
	game.match_state.tick(3.0)
	game._enter_phase()
	game.get_node("MatchHUD").update_match(game.match_state)
	for index in 30:
		await physics_frame
	await capture("match")
	game._on_goal(game.get_node("GoalRight"))
	for index in 20:
		await process_frame
	await capture("goal")
	game.start_match()
	game.match_state.phase = LocalMatch.Phase.FINISHED
	game.match_state.scores.assign([5, 2])
	game._enter_phase()
	game.get_node("MatchHUD").update_match(game.match_state)
	await capture("result")
	root.size = Vector2i(960, 540)
	game.show_lobby()
	await capture("lobby-small")
	game.start_match()
	game.match_state.tick(3.0)
	game._enter_phase()
	game.get_node("MatchHUD").update_match(game.match_state)
	await capture("match-small")
	game.queue_free()
	await process_frame
	quit()
