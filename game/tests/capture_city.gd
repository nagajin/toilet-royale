extends SceneTree
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	for index in 32:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/toilet-city-" + label + ".png")
	print("Captured: ", label)

func _run() -> void:
	game = load("res://scenes/city_battle.tscn").instantiate()
	root.add_child(game)
	await capture("menu")
	game.start_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_process_unhandled_input(false)
	game.set_process(false)
	for actor: CityActor in game.actors:
		actor.set_physics_process(false)
		actor.set_process_unhandled_input(false)
	await capture("street")
	var player: CityActor = game.human
	var toilet: CityToilet = game.world.toilets[2]
	player.position = toilet.position + Vector3(6, 0, 6)
	var direction := toilet.position - player.position
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = -0.2
	player._animate(0.0)
	game.grime.splat(player.position, 3.8, 1)
	player.set_physics_process(true)
	for index in 4:
		await physics_frame
	player.set_physics_process(false)
	game.hud.update_hud()
	await capture("dirty")
	player.position = game.world.cafeterias[0] + Vector3(0, 0, -0.6)
	player.yaw = PI
	player.pitch = -0.05
	player._animate(0.0)
	player.ammo = 1
	player.eat_progress = 0.8
	player.slippery = false
	game.hud.update_hud()
	await capture("cafeteria")
	player.first_person = true
	await capture("first-person")
	player.first_person = false
	player.position = toilet.position + Vector3(6, 0, 0)
	player.yaw = PI / 2
	player.pitch = -0.15
	player._animate(0.0)
	player.ammo = 6
	player.eat_progress = 0
	player.cooldown = 0
	game.throw_poop(player, toilet.position + Vector3.UP * CityToilet.WATER_Y)
	for index in 42:
		await physics_frame
	game.hud.update_hud()
	await capture("score")
	var home: CityToilet = game.world.toilets[0]
	player.position = home.position + Vector3(3, 0, -2)
	player.yaw = 2.0
	player._animate(0.0)
	var enemy: CityActor = game.actors[2]
	enemy.position = home.position + Vector3(-3, 0, -1)
	enemy.invulnerable = 0
	game.activate_flush(player)
	enemy._animate_flush(0.35)
	game.hud.update_hud()
	await capture("flush")
	root.size = Vector2i(960, 540)
	game.hud.show_menu("start")
	await capture("menu-small")
	game.hud.hide_menu()
	game.hud.update_hud()
	await capture("game-small")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	quit()
