class_name CityActor
extends CharacterBody3D

const MAX_AMMO := 6
var game: Node3D
var team := 0
var actor_index := 0
var human := false
var ammo := MAX_AMMO
var eat_progress := 0.0
var cooldown := 0.0
var brush_cooldown := 0.0
var slippery := false
var cleaning := false
var spawn_point := Vector3.ZERO
var respawn_left := 0.0
var invulnerable := 0.0
var _flush_origin := Vector3.ZERO
var _flush_target := Vector3.ZERO
var _motion := Vector3.ZERO
var _knock := Vector3.ZERO
var _walk_phase := 0.0
var _brush_phase := 0.0
var _bot_goal := 0
var _visual: Node3D
var _brush: Node3D
var _held: Node3D
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _throw_left := 0.0
var _landing := 0.0
var _step_left := 0.0
var _was_grounded := false
var _sprinting := false
var _view_hands: Node3D
var _view_poop: Node3D
var _view_brush: Node3D
var yaw := 0.0
var pitch := -0.17
var first_person := false
var camera: Camera3D
var _pivot: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)
	spawn_point = position
	_bot_goal = actor_index % 2
	_build_visual()
	if human:
		_build_camera()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var color: Color = CityArt.TEAMS[team].darkened(0.12)
	var cloth := CityArt.surface(color, 4, 0.94)
	var trousers := CityArt.surface(Color("344c4c"), 4, 0.92)
	var skin: Color = [Color("c99671"), Color("a77958"), Color("d2a07b"), Color("9f7054")][actor_index]
	var torso := CityArt.capsule(_visual, Vector3(0, 1.1, 0), 0.245, 0.63, color)
	torso.scale.z = 0.76
	torso.material_override = cloth
	CityArt.capsule(_visual, Vector3(0, 0.84, 0), 0.21, 0.3, Color("344c4c")).scale = Vector3(1.14, 1, 0.8)
	CityArt.cylinder(_visual, Vector3(0, 1.43, 0), 0.08, 0.16, skin)
	var head := CityArt.sphere(_visual, Vector3(0, 1.63, 0), 0.19, skin)
	head.scale = Vector3(0.91, 1.18, 0.91)
	CityArt.sphere(_visual, Vector3(0, 1.61, -0.17), 0.048, skin)
	for x in [-0.18, 0.18]:
		CityArt.sphere(_visual, Vector3(x, 1.63, 0), 0.047, skin)
	var hair := CityArt.sphere(_visual, Vector3(0, 1.69, 0.01), 0.192, Color("423c33"))
	hair.scale = Vector3(0.98, 0.65, 0.97)
	var cap := CityArt.sphere(_visual, Vector3(0, 1.79, -0.01), 0.203, color)
	cap.scale.y = 0.4
	cap.material_override = cloth
	CityArt.rounded_box(_visual, Vector3(0, 1.77, -0.16), Vector3(0.39, 0.035, 0.3), 0.017, cloth)
	for x in [-0.065, 0.065]:
		CityArt.box(_visual, Vector3(x, 1.66, -0.166), Vector3(0.055, 0.022, 0.025), Color("32332c"))
		CityArt.box(_visual, Vector3(x, 1.7, -0.164), Vector3(0.068, 0.016, 0.02), Color("433b31"))
	CityArt.box(_visual, Vector3(0, 1.53, -0.151), Vector3(0.065, 0.012, 0.016), Color("835847"))
	CityArt.box(_visual, Vector3(0, 1.13, -0.186), Vector3(0.02, 0.41, 0.02), Color("d0c6ae"))
	CityArt.box(_visual, Vector3(0.11, 1.23, -0.181), Vector3(0.13, 0.1, 0.02), CityArt.CREAM)
	CityArt.rounded_box(_visual, Vector3(0, 1.12, 0.205), Vector3(0.35, 0.43, 0.18), 0.07, trousers)
	CityArt.box(_visual, Vector3(0, 1.15, 0.301), Vector3(0.25, 0.045, 0.012), CityArt.CREAM)
	for side in 2:
		var x := -0.14 if side == 0 else 0.14
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.84, 0)
		_visual.add_child(hip)
		_legs.append(hip)
		CityArt.capsule(hip, Vector3(0, -0.2, 0), 0.107, 0.43, Color.WHITE).material_override = trousers
		var knee := Node3D.new()
		knee.position.y = -0.39
		hip.add_child(knee)
		_knees.append(knee)
		CityArt.capsule(knee, Vector3(0, -0.15, 0), 0.087, 0.35, Color.WHITE).material_override = trousers
		CityArt.rounded_box(knee, Vector3(0, -0.35, -0.064), Vector3(0.19, 0.17, 0.33), 0.05, CityArt.material(Color("304240"), 0.7))
		CityArt.rounded_box(knee, Vector3(0, -0.41, -0.07), Vector3(0.195, 0.045, 0.34), 0.018, CityArt.material(Color("b8b7a5")))
		var shoulder := Node3D.new()
		shoulder.position = Vector3(-0.285 if side == 0 else 0.285, 1.31, 0)
		_visual.add_child(shoulder)
		_arms.append(shoulder)
		CityArt.capsule(shoulder, Vector3(0, -0.12, 0), 0.094, 0.32, Color.WHITE).material_override = cloth
		var elbow := Node3D.new()
		elbow.position.y = -0.27
		shoulder.add_child(elbow)
		_elbows.append(elbow)
		CityArt.capsule(elbow, Vector3(0, -0.115, 0), 0.073, 0.27, Color.WHITE).material_override = cloth
		CityArt.sphere(elbow, Vector3(0, -0.26, 0), 0.078, CityArt.CREAM).scale = Vector3(0.8, 1.1, 1)
	_brush = _make_brush(_elbows[1], color)
	_brush.position = Vector3(0, -0.28, 0)
	_held = CityArt.poop(_elbows[0])
	_held.position = Vector3(0, -0.27, -0.02)
	_held.scale = Vector3.ONE * 0.52
	if not human:
		CityArt.label(self, "味方" if team == 0 else "敵", Vector3(0, 2.15, 0), CityArt.TEAMS[team], 22)
	_animate(0)

func _make_brush(parent: Node3D, color: Color) -> Node3D:
	var brush := Node3D.new()
	parent.add_child(brush)
	CityArt.cylinder(brush, Vector3(0, 0.04, 0), 0.025, 0.82, Color.WHITE).material_override = CityArt.metal(Color("a7bab5"), 0.3)
	CityArt.capsule(brush, Vector3(0, 0.32, 0), 0.042, 0.22, color)
	CityArt.sphere(brush, Vector3(0, -0.36, 0), 0.10, color)
	for index in 12:
		var angle := index * TAU / 12
		CityArt.capsule(brush, Vector3(cos(angle) * 0.083, -0.4, sin(angle) * 0.083), 0.023, 0.15, Color("d9d5bd"))
	return brush

func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = 1.5
	add_child(_pivot)
	_pitch_node = Node3D.new()
	_pivot.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.spring_length = 4.0
	_arm.position = Vector3(0.65, 0.35, 0)
	_arm.collision_mask = 1
	_arm.margin = 0.18
	_pitch_node.add_child(_arm)
	_arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 76
	camera.near = 0.08
	_arm.add_child(camera)
	_view_hands = Node3D.new()
	camera.add_child(_view_hands)
	var glove := CityArt.capsule(_view_hands, Vector3(-0.25, -0.31, -0.48), 0.065, 0.3, CityArt.TEAMS[team])
	glove.rotation.x = 1.2
	CityArt.sphere(_view_hands, Vector3(-0.25, -0.27, -0.58), 0.07, CityArt.CREAM)
	_view_poop = CityArt.poop(_view_hands)
	_view_poop.position = Vector3(-0.26, -0.29, -0.62)
	_view_poop.scale = Vector3.ONE * 0.33
	var right := CityArt.capsule(_view_hands, Vector3(0.31, -0.31, -0.44), 0.065, 0.3, CityArt.TEAMS[team])
	right.rotation.x = 1.0
	CityArt.sphere(_view_hands, Vector3(0.31, -0.26, -0.53), 0.07, CityArt.CREAM)
	_view_brush = _make_brush(_view_hands, CityArt.TEAMS[team])
	_view_brush.position = Vector3(0.31, -0.25, -0.57)
	_view_brush.rotation.z = -0.25
	for item in _view_hands.find_children("*", "GeometryInstance3D", true, false):
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_hands.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not human or not game.active or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.15, 0.9)
	if event.is_action_pressed("city_view") and not event.is_echo():
		first_person = not first_person

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	brush_cooldown = maxf(0, brush_cooldown - delta)
	invulnerable = maxf(0, invulnerable - delta)
	if not game.active:
		return
	if respawn_left > 0:
		_animate_flush(delta)
		return
	var input := Vector2.ZERO
	cleaning = false
	var eating := false
	var jump := false
	var speed := 7.0
	_sprinting = false
	if human:
		input = Input.get_vector("city_left", "city_right", "city_up", "city_down")
		input = input.rotated(-yaw)
		jump = Input.is_action_just_pressed("city_jump")
		cleaning = Input.is_action_pressed("city_brush")
		eating = Input.is_action_pressed("city_eat") and game.can_eat(self)
		if Input.is_action_pressed("city_sprint"):
			speed = 10.0
			_sprinting = true
		if Input.is_action_pressed("city_throw") and not cleaning and not eating:
			game.throw_poop(self)
		if Input.is_action_just_pressed("city_flush"):
			game.activate_flush(self)
	else:
		var target := _bot_destination()
		var direction := _navigate(target) - global_position
		input = Vector2(direction.x, direction.z).normalized() if direction.length() > 0.8 else Vector2.ZERO
		eating = ammo < MAX_AMMO and game.can_eat(self) and ammo <= 1
		cleaning = game.grime.is_slippery(global_position) and _bot_goal == 0
		_bot_actions()
	if eating:
		input = Vector2.ZERO
		feed(delta)
	else:
		eat_progress = 0
	if cleaning:
		speed *= 0.7
		game.brush(self)
	slippery = game.grime.is_slippery(global_position) and is_on_floor()
	var acceleration := 1.35 if slippery else 13.0
	_motion = _motion.lerp(Vector3(input.x, 0, input.y) * speed, minf(1, acceleration * delta))
	_knock = _knock.move_toward(Vector3.ZERO, delta * (1.2 if slippery else 8.0))
	velocity.x = _motion.x + _knock.x
	velocity.z = _motion.z + _knock.z
	if is_on_floor():
		velocity.y = 6.0 if jump else -0.2
	else:
		velocity.y -= 18.0 * delta
	var falling_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_grounded and falling_speed < -3.0:
		_landing = clampf(-falling_speed * 0.012, 0.035, 0.13)
	_was_grounded = is_on_floor()
	_step_left = maxf(0, _step_left - delta)
	if is_on_floor() and _motion.length() > 2.5 and _step_left <= 0 and not slippery:
		_step_left = 0.28 if _sprinting else 0.38
		CityFeedback.sound(game.effects, global_position, "step", -25 if human else -30)
	if global_position.y < -5:
		respawn()
	_animate(delta)

func _process(delta: float) -> void:
	if not human:
		return
	_pivot.rotation.y = yaw
	_pitch_node.rotation.x = pitch
	var aiming: bool = Input.is_action_pressed("city_aim") and game.active
	var length := 0.0 if first_person else (2.1 if aiming else 4.0)
	_arm.spring_length = lerpf(_arm.spring_length, length, minf(1, delta * 12))
	_arm.position.x = 0.0 if first_person else 0.65
	_arm.position.y = 0.05 if first_person else 0.35
	var fov_target := 60.0 if aiming else (80.0 if _sprinting and _motion.length() > 5 else 76.0)
	camera.fov = lerpf(camera.fov, fov_target, minf(1, delta * 8))
	var walking := minf(_motion.length() / 7.0, 1.0) if is_on_floor() and respawn_left <= 0 else 0.0
	_landing = move_toward(_landing, 0, delta * 0.55)
	camera.position.y = lerpf(camera.position.y, sin(_walk_phase * 2) * 0.018 * walking - _landing, minf(1, delta * 14))
	camera.rotation.z = lerpf(camera.rotation.z, -sin(_walk_phase) * 0.008 * walking if slippery else 0.0, minf(1, delta * 7))
	_view_hands.visible = first_person and respawn_left <= 0 and game.active
	_view_hands.position.y = sin(_walk_phase) * walking * 0.015 - sin(_throw_left / 0.42 * PI) * 0.14
	_view_poop.visible = ammo > 0 and _throw_left < 0.12
	_view_brush.rotation.x = sin(_brush_phase) * 0.7 if cleaning else 0.0
	_visual.visible = not first_person and (respawn_left <= 0 or respawn_left > 2.1)

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw)) if human else -_visual.global_basis.z

func shot_origin() -> Vector3:
	return global_position + Vector3.UP * 1.25

func feed(delta: float) -> void:
	if not game.can_eat(self) or ammo >= MAX_AMMO:
		eat_progress = 0
		return
	eat_progress += delta
	if eat_progress >= 1.5:
		ammo = MAX_AMMO
		eat_progress = 0
		CityFeedback.sound(game.effects, shot_origin(), "eat", -20)
		if human:
			game.toast("ごちそうさま！ うんこを6個補給", CityArt.CREAM)

func receive_knock(force: Vector3) -> void:
	if respawn_left > 0 or invulnerable > 0:
		return
	_knock = (_knock + Vector3(force.x, 0, force.z)).limit_length(15.0)
	velocity.y = maxf(velocity.y, force.y)
	eat_progress = 0

func begin_flush(toilet: CityToilet) -> bool:
	if respawn_left > 0 or invulnerable > 0 or team == toilet.team:
		return false
	respawn_left = 3.0
	_flush_origin = global_position
	_flush_target = toilet.global_position + Vector3.UP * 1.1
	_motion = Vector3.ZERO
	_knock = Vector3.ZERO
	velocity = Vector3.ZERO
	set_collision_layer_value(2, false)
	return true

func _animate_flush(delta: float) -> void:
	respawn_left = maxf(0, respawn_left - delta)
	var t := clampf((3.0 - respawn_left) / 0.9, 0, 1)
	var pull := t * t * (3.0 - 2.0 * t)
	var radial := _flush_origin - _flush_target
	radial.y = 0
	global_position = _flush_target + radial.rotated(Vector3.UP, pull * TAU) * (1.0 - pull)
	global_position.y = lerpf(_flush_origin.y, _flush_target.y, pull) + sin(t * PI) * 0.75
	_visual.scale = Vector3.ONE * maxf(0.03, 1.0 - t)
	_visual.rotation.y += delta * 16
	_visual.rotation.x += delta * 5
	if respawn_left <= 0:
		respawn()

func respawn() -> void:
	global_position = spawn_point
	respawn_left = 0
	invulnerable = 2.0
	ammo = MAX_AMMO
	_motion = Vector3.ZERO
	_knock = Vector3.ZERO
	velocity = Vector3.ZERO
	_visual.scale = Vector3.ONE
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3(0, yaw, 0)
	_throw_left = 0
	_landing = 0
	set_collision_layer_value(2, true)

func animate_throw() -> void:
	_throw_left = 0.42

func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += delta * speed * 1.6
	_throw_left = maxf(0, _throw_left - delta)
	var stride := minf(speed / 9.0, 0.7)
	for index in 2:
		var wave := sin(_walk_phase + index * PI)
		_legs[index].rotation.x = wave * stride
		_knees[index].rotation.x = -maxf(0, -wave) * stride * 1.2
		_arms[index].rotation.x = -wave * stride * 0.4 + 0.25
		_elbows[index].rotation.x = 0.6
		if not is_on_floor() and speed > 1:
			_legs[index].rotation.x = 0.25 if index == 0 else -0.35
			_knees[index].rotation.x = -0.5
	if _throw_left > 0:
		var t := 1.0 - _throw_left / 0.42
		_arms[0].rotation.x = lerpf(-0.65, 2.0, sin(t * PI * 0.5))
		_elbows[0].rotation.x = 0.3
	if human:
		_visual.rotation.y = yaw
	elif speed > 0.4:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-velocity.x, -velocity.z), minf(1, delta * 8))
	_visual.position.y = absf(sin(_walk_phase)) * stride * 0.035
	_visual.rotation.x = lerpf(_visual.rotation.x, 0.06 if speed > 7 else 0.0, minf(1, delta * 8))
	_visual.rotation.z = sin(_walk_phase * 0.45) * (0.14 if slippery else 0.018)
	_brush_phase += delta * 18.0
	_brush.rotation.x = -0.8
	if cleaning:
		_arms[1].rotation.x = 0.45
		_arms[1].rotation.z = sin(_brush_phase) * 0.45
		_elbows[1].rotation.x = 0.15
		_brush.rotation.x = 0.2
		_visual.rotation.x = 0.15
	else:
		_arms[1].rotation.z = -0.1
	if eat_progress > 0:
		_arms[0].rotation.x = 0.5
		_elbows[0].rotation.x = 2.0 + sin(eat_progress * 16) * 0.12
	_held.visible = ammo > 0 and _throw_left < 0.12 and eat_progress <= 0

func _bot_destination() -> Vector3:
	if ammo <= 1:
		return game.world.cafeterias[team]
	var toilet: CityToilet = game.world.toilets[(1 - team) * 2 + _bot_goal]
	return toilet.global_position + Vector3(-signf(toilet.position.x) * 7.0, 0, 0)

func _navigate(target: Vector3) -> Vector3:
	# Buildings occupy blocks; use the central avenue and transverse streets.
	var lane := -2.0 if actor_index % 2 else 2.0
	if absf(global_position.z - target.z) > 2.0:
		if absf(global_position.x) > 4.0:
			return Vector3(lane, 0, global_position.z)
		return Vector3(lane, 0, target.z)
	return target

func _bot_actions() -> void:
	game.activate_flush(self, true)
	if ammo <= 1:
		return
	var toilet: CityToilet = game.world.toilets[(1 - team) * 2 + _bot_goal]
	if global_position.distance_to(_bot_destination()) < 2.5:
		var aim := toilet.global_position + Vector3.UP * CityToilet.WATER_Y
		game.throw_poop(self, aim)
	for actor: CityActor in game.actors:
		if actor.team != team and actor.respawn_left <= 0 and global_position.distance_to(actor.global_position) < 6:
			game.throw_poop(self, actor.global_position + Vector3.UP * 0.6)
			if global_position.distance_to(actor.global_position) < 2.3:
				game.brush(self)
