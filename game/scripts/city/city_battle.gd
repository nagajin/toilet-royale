extends Node3D

const ROUND_SECONDS := 180.0
var world: CityWorld
var grime: CityGrime
var actors: Array[CityActor] = []
var human: CityActor
var hud: CanvasLayer
var projectiles: Node3D
var effects: Node3D
var marker: CSGTorus3D
var trajectory: MeshInstance3D
var scores: Array[int] = [0, 0]
var active := false
var seconds_left := ROUND_SECONDS
var layout_seed := 4107
var elapsed := 0.0
var _toast_left := 0.0
var _toast_text := ""
var _toast_color := Color.WHITE

func _exit_tree() -> void:
	CityFeedback.clear_cache()
	CityArt.clear_cache()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("477faf")
	sky_material.sky_horizon_color = Color("c7d9dd")
	sky_material.ground_bottom_color = Color("414e4b")
	sky_material.ground_horizon_color = Color("b3c5c6")
	sky_material.sky_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_energy = 0.52
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure = 0.95
	settings.ssao_enabled = true
	settings.ssao_radius = 1.4
	settings.ssao_intensity = 1.8
	settings.ssao_light_affect = 0.28
	settings.ssil_enabled = true
	settings.ssil_intensity = 0.35
	settings.ssil_radius = 3.0
	settings.fog_enabled = true
	settings.fog_density = 0.0018
	settings.fog_light_color = Color("bacfd0")
	settings.fog_sky_affect = 0.12
	settings.glow_enabled = true
	settings.glow_intensity = 0.18
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color("ffebd0")
	sun.light_energy = 1.25
	sun.light_angular_distance = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().use_taa = true
	hud = load("res://scripts/city/city_hud.gd").new()
	hud.game = self
	add_child(hud)
	_build_world()
	hud.show_menu("start")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _configure_input() -> void:
	var keys := {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "brush": KEY_Q, "eat": KEY_E, "flush": KEY_F, "view": KEY_V}
	for key: String in keys:
		var action := "city_" + key
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[key]
		InputMap.action_add_event(action, event)
	for key: String in ["throw", "aim"]:
		var action := "city_" + key
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if key == "throw" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)

func _build_world() -> void:
	for node in [world, grime, projectiles, effects]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	for actor in actors:
		remove_child(actor)
		actor.queue_free()
	actors.clear()
	world = CityWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.generate(layout_seed)
	grime = CityGrime.new()
	grime.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(grime)
	projectiles = Node3D.new()
	projectiles.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectiles)
	effects = Node3D.new()
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	for index in 4:
		var actor := CityActor.new()
		actor.game = self
		actor.team = 0 if index < 2 else 1
		actor.actor_index = index
		actor.human = index == 0
		actor.position = Vector3(-2 if index % 2 == 0 else 2, 0.1, 24 if actor.team == 0 else -24)
		actor.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(actor)
		actors.append(actor)
	human = actors[0]
	marker = CSGTorus3D.new()
	marker.inner_radius = 0.4
	marker.outer_radius = 0.48
	marker.sides = 32
	marker.ring_sides = 6
	marker.material = CityArt.material(CityArt.CREAM)
	effects.add_child(marker)
	trajectory = MeshInstance3D.new()
	var mat := CityArt.material(Color("fff3d4"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trajectory.material_override = mat
	effects.add_child(trajectory)

func start_match(regenerate: bool = false) -> void:
	get_tree().paused = false
	active = false
	if regenerate:
		layout_seed += 1
	_build_world()
	scores.assign([0, 0])
	seconds_left = ROUND_SECONDS
	elapsed = 0
	active = true
	hud.hide_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toast("敵の便器へ投げ入れよう！ 弾切れなら自陣の食堂へ", CityArt.CREAM)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") and active:
		if get_tree().paused:
			resume_match()
		else:
			pause_match()
	elif event.is_action_pressed("reset_game") and active:
		start_match()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and active:
		pause_match()

func pause_match() -> void:
	if get_tree().paused or not active:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu("pause")

func resume_match() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.hide_menu()

func toggle_sound() -> void:
	CityFeedback.muted = not CityFeedback.muted
	if CityFeedback.muted:
		for node in effects.get_children():
			if node is AudioStreamPlayer3D:
				node.queue_free()

func _process(delta: float) -> void:
	if not is_instance_valid(human):
		return
	if active and not get_tree().paused:
		seconds_left = maxf(0, seconds_left - delta)
		elapsed += delta
		_toast_left = maxf(0, _toast_left - delta)
		if seconds_left <= 0:
			active = false
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			hud.show_menu("result")
	hud.update_hud()

func _physics_process(_delta: float) -> void:
	if not active or get_tree().paused or human.respawn_left > 0:
		if marker:
			marker.hide()
		if trajectory:
			trajectory.hide()
		return
	_update_aim()

func can_eat(actor: CityActor) -> bool:
	return actor.respawn_left <= 0 and actor.position.y < 1.0 and actor.global_position.distance_to(world.cafeterias[actor.team]) < 2.8

func shot_solution(actor: CityActor, target: Vector3 = Vector3.INF) -> Dictionary:
	var origin := actor.shot_origin()
	if target == Vector3.INF:
		var centre := get_viewport().get_visible_rect().size / 2
		var from := actor.camera.project_ray_origin(centre)
		var ray := actor.camera.project_ray_normal(centre)
		var query := PhysicsRayQueryParameters3D.create(from, from + ray * 70, 3, [actor.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		target = hit.position if not hit.is_empty() else from + ray * 25
	var displacement := target - origin
	if displacement.length() > 25:
		target = origin + displacement.normalized() * 25
	var horizontal := Vector2(target.x - origin.x, target.z - origin.z).length()
	var flight := clampf(horizontal / 15.0, 0.65, 1.6)
	var launch := (target - origin) / flight + Vector3.UP * CityProjectile.GRAVITY * flight * 0.5
	return {"origin": origin, "velocity": launch}

func throw_poop(actor: CityActor, target: Vector3 = Vector3.INF) -> bool:
	if not active or get_tree().paused or actor.ammo <= 0 or actor.cooldown > 0 or actor.respawn_left > 0:
		return false
	actor.animate_throw()
	actor.ammo -= 1
	actor.cooldown = 0.5 if actor.human else 1.25
	var solution := shot_solution(actor, target)
	var poop := CityProjectile.new()
	poop.game = self
	poop.team = actor.team
	poop.shooter = actor
	poop.position = solution.origin
	poop.velocity = solution.velocity
	projectiles.add_child(poop)
	CityFeedback.sound(effects, actor.shot_origin(), "throw")
	return true

func trace_shot(from: Vector3, to: Vector3, shooter: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [shooter.get_rid()])
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var length := from.distance_to(to)
	var best: float = from.distance_to(result.position) / maxf(length, 0.0001) if not result.is_empty() else 2.0
	for toilet in world.toilets:
		var fraction := toilet.crossing_fraction(from, to)
		if fraction >= 0 and fraction < best:
			best = fraction
			result = {"position": from.lerp(to, fraction), "toilet": toilet, "normal": Vector3.UP}
	return result

func resolve_shot(poop: CityProjectile, hit: Dictionary) -> void:
	if not active:
		return
	if hit.has("toilet"):
		var toilet: CityToilet = hit.toilet
		toilet.celebrate()
		CityFeedback.burst(effects, hit.position, Color("b8dedb"), true)
		CityFeedback.sound(effects, hit.position, "flush", -12)
		if toilet.team != poop.team:
			scores[poop.team] += 1
			toast("%s +1   ジャーーッ！" % ("オレンジ" if poop.team == 0 else "ミント"), CityArt.TEAMS[poop.team])
		elif poop.shooter.human:
			toast("ここは自陣の便器！ 敵の便器を狙おう", CityArt.CREAM)
		return
	var point: Vector3 = hit.position
	CityFeedback.burst(effects, point, Color("71513a"))
	CityFeedback.sound(effects, point, "splat", -13)
	var collider: Object = hit.get("collider")
	if collider is CityActor:
		var victim: CityActor = collider
		if victim.team != poop.team:
			victim.receive_knock(Vector3(poop.velocity.x, 2.2, poop.velocity.z).normalized() * 8)
		point = Vector3(victim.position.x, 0, victim.position.z)
	elif hit.normal.y < 0.65:
		# Wall impacts stay on the near side; they do not paint through buildings.
		point += hit.normal * 0.4
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, Vector3(point.x, -1, point.z), 1))
		if floor_hit.is_empty() or floor_hit.position.y > 0.15:
			return
		point = floor_hit.position
	if point.y < 0.2:
		grime.splat(point, 2.5, poop.team)

func brush(actor: CityActor) -> int:
	if not active or actor.respawn_left > 0 or actor.brush_cooldown > 0:
		return 0
	actor.brush_cooldown = 0.15
	actor.cleaning = true
	var cleaned := grime.clean(actor.position + actor.forward() * 0.5, 2.5)
	if cleaned > 0:
		CityFeedback.burst(effects, actor.position + actor.forward() * 0.65, Color("d8e4df"), true, true)
		CityFeedback.sound(effects, actor.position, "brush", -22)
	for opponent in actors:
		if opponent.team == actor.team or opponent.respawn_left > 0:
			continue
		var toward := opponent.position - actor.position
		if toward.length() < 2.4 and toward.normalized().dot(actor.forward()) > 0.1:
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.shot_origin(), opponent.shot_origin(), 1))
			if hit.is_empty():
				opponent.receive_knock(toward.normalized() * 7 + Vector3.UP * 2)
	return cleaned

func nearby_toilet(actor: CityActor) -> CityToilet:
	var nearest: CityToilet
	var distance := 4.8
	for toilet in world.toilets:
		var d := actor.position.distance_to(toilet.position)
		if toilet.team == actor.team and d < distance:
			nearest = toilet
			distance = d
	return nearest

func activate_flush(actor: CityActor, automatic: bool = false) -> bool:
	if not active or actor.respawn_left > 0:
		return false
	var toilet := nearby_toilet(actor)
	if not toilet or toilet.cooldown > 0:
		return false
	var victims: Array[CityActor] = []
	for opponent in actors:
		if opponent.team == toilet.team or opponent.position.distance_to(toilet.position) > 6.0 or opponent.respawn_left > 0 or opponent.invulnerable > 0:
			continue
		var origin := toilet.global_position + Vector3.UP * 2.1
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, opponent.shot_origin(), 1))
		if hit.is_empty():
			victims.append(opponent)
	if automatic and victims.is_empty():
		return false
	toilet.cooldown = 7.0
	toilet.celebrate()
	CityFeedback.burst(effects, toilet.global_position + Vector3.UP * CityToilet.WATER_Y, Color("c8e5e0"), true)
	CityFeedback.sound(effects, toilet.global_position, "flush", -12)
	for victim in victims:
		victim.begin_flush(toilet)
	if not victims.is_empty():
		toast("水流で敵を流した！" if actor.team == 0 else "敵の水流が作動！", CityArt.TEAMS[actor.team])
	elif actor.human:
		toast("水流作動！ 便器の近くに敵を誘い込もう", CityArt.CREAM)
	return true

func _update_aim() -> void:
	var show_path := human.ammo > 0 and not human.cleaning
	marker.visible = show_path
	trajectory.visible = show_path and Input.is_action_pressed("city_aim")
	if not show_path:
		return
	var solution := shot_solution(human)
	var point: Vector3 = solution.origin
	var velocity: Vector3 = solution.velocity
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	line.surface_add_vertex(point)
	var found := false
	for index in 45:
		var next := point + velocity * 0.07 + Vector3.DOWN * CityProjectile.GRAVITY * 0.07 * 0.07 * 0.5
		var hit := trace_shot(point, next, human)
		if not hit.is_empty():
			marker.position = hit.position + Vector3.UP * 0.06
			line.surface_add_vertex(marker.position)
			found = true
			break
		point = next
		velocity.y -= CityProjectile.GRAVITY * 0.07
		line.surface_add_vertex(point)
	line.surface_end()
	trajectory.mesh = line
	marker.visible = found

func toast(text: String, color: Color) -> void:
	_toast_text = text
	_toast_color = color
	_toast_left = 2.5
