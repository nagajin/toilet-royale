extends SceneTree
var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _quiet() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	for actor: CityActor in game.actors:
		actor.set_physics_process(false)

func _run() -> void:
	game = load("res://scenes/city_battle.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	check(not game.active, "starts in instruction menu")
	game.start_match()
	_quiet()
	await frames(3)
	check(game.world.toilets.size() == 4, "generates four toilets")
	check(game.world.toilets[0].team == 0 and game.world.toilets[1].team == 0 and game.world.toilets[2].team == 1 and game.world.toilets[3].team == 1, "two toilets belong to each team")
	var positions: Array[Vector3] = []
	for toilet: CityToilet in game.world.toilets:
		positions.append(toilet.position)
		var clear := true
		for bounds: AABB in game.world.building_bounds:
			if bounds.grow(2.5).has_point(toilet.position + Vector3.UP):
				clear = false
		check(clear, "toilet plaza clear of buildings")
	check(game.world.cafeterias.size() == 2, "each team has a cafeteria")
	check(game.actors.size() == 4 and game.human.human, "human and three CPU actors spawn")
	game.start_match()
	_quiet()
	for index in 4:
		check(game.world.toilets[index].position.is_equal_approx(positions[index]), "same seed retains toilet layout")
	game.start_match(true)
	_quiet()
	check(not game.world.toilets[0].position.is_equal_approx(positions[0]), "new seed regenerates toilet locations")
	await frames(3)
	var player: CityActor = game.human
	check(player.camera.current and player.camera.get_parent() is SpringArm3D, "player has collision-aware perspective camera")
	player.first_person = true
	player._process(1.0)
	check(not player._visual.visible and is_zero_approx(player._arm.spring_length), "first-person hides body and removes camera distance")
	player.first_person = false
	player._process(1.0)
	check(player._visual.visible and player._arm.spring_length > 3, "third-person restores shoulder camera")
	player.position = Vector3(0, 0, 0)
	game.grime.splat(Vector3.ZERO, 3, 1)
	check(game.grime.is_slippery(Vector3.ZERO), "impact paints slippery ground")
	var dirt_count: int = game.grime.cells.size()
	game.grime.splat(Vector3.ZERO, 3, 0)
	check(game.grime.cells.size() == dirt_count, "overlapping splats reuse cells")
	check(game.brush(player) > 0 and not game.grime.is_slippery(player.position), "brush removes nearby dirt")
	game.grime.clear_all()
	check(game.grime.cells.is_empty(), "restart can clear all dirt")
	await _test_sliding()
	player.set_physics_process(false)
	player.ammo = 0
	player.position = game.world.cafeterias[1]
	player.feed(2.0)
	check(player.ammo == 0, "enemy cafeteria cannot refill")
	player.position = Vector3.ZERO
	player.feed(2.0)
	check(player.ammo == 0, "food cannot refill outside cafeteria")
	player.position = game.world.cafeterias[0]
	player.feed(0.7)
	check(player.ammo == 0 and player.eat_progress > 0, "eating takes time")
	player.feed(0.8)
	check(player.ammo == 6, "own cafeteria refills six shots")
	player.ammo = 0
	check(not game.throw_poop(player, Vector3.ZERO), "cannot throw with empty inventory")
	player.ammo = 6
	await _test_projectiles()
	await _test_flush()
	game.start_match()
	_quiet()
	check(game.grime.cells.is_empty() and game.projectiles.get_child_count() == 0 and game.scores == [0, 0], "restart clears dirt, projectiles and scores")
	game.pause_match()
	var remaining: float = game.seconds_left
	game._process(5)
	check(game.seconds_left == remaining and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause stops clock and releases mouse")
	game.resume_match()
	game.seconds_left = 0.1
	game._process(0.2)
	check(not game.active and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "full time shows results and releases mouse")
	paused = false
	game.start_match()
	game.set_process(false)
	game.set_physics_process(false)
	game.human.set_physics_process(false)
	game.set_process(true)
	await frames(10840)
	print("CPU scores: ", game.scores, " dirt cells: ", game.grime.cells.size())
	check(game.scores[0] + game.scores[1] > 0, "CPU navigates city and scores real projectiles")
	check(game.grime.cells.size() > 0, "CPU fight creates dirt")
	check(not game.active and paused and game.seconds_left <= 0, "full three-minute CPU round reaches results")
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_sliding() -> void:
	var player: CityActor = game.human
	player.position = Vector3(0, 0.1, 0)
	player.set_physics_process(true)
	await frames(5)
	Input.action_press("city_right")
	await frames(30)
	Input.action_release("city_right")
	await frames(12)
	var clean_speed := absf(player.velocity.x)
	player.respawn()
	player.position = Vector3(0, 0.1, 0)
	game.grime.splat(Vector3.ZERO, 6, 1)
	Input.action_press("city_right")
	await frames(30)
	Input.action_release("city_right")
	await frames(12)
	print("Coasting speed clean=", clean_speed, " dirty=", absf(player.velocity.x))
	check(absf(player.velocity.x) > clean_speed + 1, "dirt preserves momentum after input release")
	game.grime.clear_all()
	player.respawn()

func _test_projectiles() -> void:
	var player: CityActor = game.human
	for defending in 2:
		var toilet: CityToilet = game.world.toilets[defending * 2]
		player.position = toilet.position + Vector3(6, 0, 0)
		player.team = 1 - defending
		player.cooldown = 0
		var before: int = game.scores[player.team]
		check(game.throw_poop(player, toilet.position + Vector3.UP * CityToilet.WATER_Y), "throw launches a physical projectile")
		var inventory: int = player.ammo
		check(not game.throw_poop(player, toilet.position) and player.ammo == inventory, "throw cooldown prevents duplicate inventory spending")
		await frames(90)
		check(game.scores[player.team] == before + 1, "enemy toilet scores exactly one point")
	player.team = 0
	var own: CityToilet = game.world.toilets[0]
	player.position = own.position + Vector3(6, 0, 0)
	player.cooldown = 0
	var before: Array = game.scores.duplicate()
	game.throw_poop(player, own.position + Vector3.UP * CityToilet.WATER_Y)
	await frames(90)
	check(game.scores == before, "own toilet gives no points")
	player.position = Vector3(0, 0, 8)
	player.cooldown = 0
	game.throw_poop(player, Vector3(0, 0, 0))
	await frames(90)
	check(game.grime.is_slippery(Vector3.ZERO), "real ground impact makes dirt")
	var wall_hit: Dictionary = game.trace_shot(Vector3(15, 1, 14), Vector3(15, 1, 4), player)
	check(not wall_hit.is_empty() and not wall_hit.has("toilet"), "projectile sweep hits a building instead of passing through")
	var goal: CityToilet = game.world.toilets[2]
	check(goal.crossing_fraction(goal.position + Vector3(0, 0.5, 0), goal.position + Vector3(0, 3, 0)) < 0, "upward crossing cannot score")
	check(goal.crossing_fraction(goal.position + Vector3(3, 3, 0), goal.position + Vector3(3, 0, 0)) < 0, "outside-bowl crossing cannot score")

func _test_flush() -> void:
	var player: CityActor = game.human
	var enemy: CityActor = game.actors[2]
	var friendly: CityActor = game.actors[1]
	var toilet: CityToilet = game.world.toilets[0]
	player.position = toilet.position + Vector3(3, 0, 0)
	enemy.position = toilet.position + Vector3(-3, 0, 0)
	friendly.position = toilet.position + Vector3(0, 0, -3)
	enemy.invulnerable = 0
	var before: Array = game.scores.duplicate()
	check(game.activate_flush(player), "own toilet can activate a flush")
	check(enemy.respawn_left > 0 and friendly.respawn_left == 0, "water captures enemies and spares teammates")
	check(game.scores == before, "flushing players does not invent extra points")
	check(not game.activate_flush(player), "water has a cooldown")
	enemy._animate_flush(3.1)
	check(enemy.position.is_equal_approx(enemy.spawn_point) and enemy.invulnerable > 0, "flushed enemy respawns at own base with brief protection")
	check(not enemy.begin_flush(toilet), "respawn protection blocks immediate repeat flush")
