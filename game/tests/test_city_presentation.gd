extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _run() -> void:
	game = load("res://scenes/city_battle.tscn").instantiate()
	root.add_child(game)
	game.start_match()
	game.set_process(false)
	game.set_physics_process(false)
	for actor: CityActor in game.actors:
		actor.set_physics_process(false)
	var player: CityActor = game.human
	player.first_person = true
	player._process(1)
	check(player._view_hands.visible and not player._visual.visible, "FPS shows hands without the full body")
	game.throw_poop(player, player.position + Vector3(0, 0, -8))
	player._process(0.01)
	check(not player._view_poop.visible, "released item disappears from the first-person hand")
	player._animate(0.5)
	player._process(0.01)
	check(player._view_poop.visible and player.ammo == 5, "next held item returns without spending extra ammo")
	var enemy_toilet: CityToilet = game.world.toilets[2]
	player.invulnerable = 0
	player.begin_flush(enemy_toilet)
	player._process(0.01)
	check(not player._view_hands.visible, "flushed player does not keep floating hands in view")
	player._animate_flush(3.1)
	player._process(0.01)
	check(player._view_hands.visible and player._visual.rotation.x == 0, "respawn restores hands and upright body")
	for kind in ["step", "throw", "splat", "brush", "flush", "eat"]:
		var sound := CityFeedback._synthesize(kind)
		check(sound.data.size() > 4000 and sound.mix_rate == 22050 and sound.format == AudioStreamWAV.FORMAT_16_BITS, "valid PCM effect: " + kind)
	CityFeedback.sound(game.effects, player.position, "flush")
	game.toggle_sound()
	await process_frame
	var audio_count := 0
	for node in game.effects.get_children():
		if node is AudioStreamPlayer3D:
			audio_count += 1
	check(audio_count == 0, "muting also removes sounds already playing")
	var before: int = game.effects.get_child_count()
	CityFeedback.sound(game.effects, player.position, "flush")
	check(game.effects.get_child_count() == before, "muted events create no audio players")
	for index in 100:
		CityFeedback.burst(game.effects, player.position, Color.WHITE)
	check(game.effects.get_child_count() <= 42, "burst effects have a hard instance cap")
	await frames(140)
	check(game.effects.get_child_count() == 2, "transient effects expire and leave only aim markers")
	CityFeedback.burst(game.effects, player.position, Color.WHITE)
	game.start_match()
	check(game.effects.get_child_count() == 2, "restart removes effects from the previous match")
	CityFeedback.muted = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	print("PRESENTATION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
