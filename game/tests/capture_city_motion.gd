extends SceneTree

var game: Node3D
var timings: Array[float] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/toilet-motion-" + label + ".png")
	print("MOTION: ", label)

func _run() -> void:
	game = load("res://scenes/city_battle.tscn").instantiate()
	root.add_child(game)
	game.start_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_process_unhandled_input(false)
	game.human.set_process_unhandled_input(false)
	await frames(80)
	Input.action_press("city_up")
	Input.action_press("city_sprint")
	await frames(17)
	await snapshot("run-a")
	await frames(9)
	await snapshot("run-b")
	Input.action_press("city_jump")
	await frames(6)
	Input.action_release("city_jump")
	await snapshot("jump")
	Input.action_release("city_sprint")
	Input.action_release("city_up")
	await frames(70)
	game.grime.splat(game.human.position, 4, 1)
	Input.action_press("city_brush")
	await frames(4)
	await snapshot("clean")
	Input.action_release("city_brush")
	game.human.first_person = true
	await frames(40)
	await snapshot("fps")
	game.throw_poop(game.human, game.human.position + Vector3(0, 0, -8))
	await frames(9)
	await snapshot("throw")
	await frames(65)
	game.human.first_person = false
	await frames(40)
	# Measure warm rendering, excluding disk capture and initial shader compilation.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var previous := Time.get_ticks_usec()
	for index in 360:
		await process_frame
		var now := Time.get_ticks_usec()
		timings.append(float(now - previous) / 1000.0)
		previous = now
	timings.sort()
	print("RENDER median ms: ", timings[timings.size() / 2], " p95 ms: ", timings[int(timings.size() * 0.95)])
	print("DRAW calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	quit()
