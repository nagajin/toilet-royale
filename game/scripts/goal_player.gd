class_name GoalPlayer
extends CharacterBody3D

@export var player_index := 0
@export var team_index := 0
@export var team_color := Color("ff675e")
@export_group("Movement")
@export var run_speed := 7.0
@export var ground_lerp := 12.0
@export var air_lerp := 5.0
@export var jump_velocity := 6.0
@export var gravity := 16.0
@export var ball_push_accel := 42.0
@export var player_push_accel := 38.0
@export var push_drag := 4.0

var enabled := true
var _spawn_transform := Transform3D.IDENTITY
var _run_phase := 0.0
var _drive := Vector3.ZERO
var _push_velocity := Vector3.ZERO
var _wish := Vector3.ZERO

@onready var _visual: Node3D = $Visual
@onready var _arm_l: Node3D = $Visual/ArmL
@onready var _arm_r: Node3D = $Visual/ArmR
@onready var _leg_l: Node3D = $Visual/LegL
@onready var _leg_r: Node3D = $Visual/LegR

func _ready() -> void:
	_spawn_transform = global_transform
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.roughness = 0.65
	for part in [_visual.get_node("Head"), _visual.get_node("Body"), _arm_l, _arm_r, _leg_l, _leg_r]:
		part.material_override = material
	var label := Label3D.new()
	label.text = "P%d" % [player_index + 1]
	label.position.y = 1.5
	label.font_size = 64
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = team_color
	label.no_depth_test = true
	add_child(label)
	reset_to_spawn()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var prefix := "local_p%d" % [player_index + 1]
	var input := Input.get_vector(prefix + "_left", prefix + "_right", prefix + "_up", prefix + "_down")
	_wish = Vector3(input.x, 0, input.y)
	var rate := ground_lerp if is_on_floor() else air_lerp
	_drive = _drive.lerp(_wish * run_speed, minf(1.0, rate * delta))
	_push_velocity = _push_velocity.move_toward(Vector3.ZERO, push_drag * delta)
	velocity.x = _drive.x + _push_velocity.x
	velocity.z = _drive.z + _push_velocity.z
	if is_on_floor():
		if Input.is_action_just_pressed(prefix + "_jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_push_contacts(delta)
	_update_visual(delta)
	if global_position.y < -5.0 or absf(global_position.x) > 26.0 or absf(global_position.z) > 16.0:
		reset_to_spawn()

func receive_push(impulse: Vector3) -> void:
	if enabled:
		_push_velocity = (_push_velocity + impulse).limit_length(9.0)

func _push_contacts(delta: float) -> void:
	var touched: Array[Node] = []
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if not (body is RigidBody3D or body is GoalPlayer) or body in touched:
			continue
		touched.append(body)
		var direction := -col.get_normal()
		direction.y = 0.0
		if direction.length() < 0.1:
			continue
		direction = direction.normalized()
		var pressure := clampf(maxf(_wish.dot(direction), _push_velocity.dot(direction) / run_speed), 0.0, 1.0)
		if body is RigidBody3D and not body.freeze:
			body.apply_central_impulse(direction * ball_push_accel * body.mass * pressure * delta)
		elif body is GoalPlayer:
			var impulse := direction * player_push_accel * pressure * delta
			body.receive_push(impulse)
			receive_push(-impulse * 0.3)

func _update_visual(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var ratio := clampf(hspeed / run_speed, 0.0, 1.0)
	_run_phase += delta * (2.0 + hspeed * 1.6)
	if hspeed > 0.8:
		var yaw := atan2(-velocity.x, -velocity.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, minf(1.0, 10.0 * delta))
	var swing := sin(_run_phase) * ratio
	_leg_l.rotation.x = swing * 0.9
	_leg_r.rotation.x = -swing * 0.9
	_arm_l.rotation.x = -swing * 0.7
	_arm_r.rotation.x = swing * 0.7
	var lean := ratio * 0.18 if is_on_floor() else -0.18
	_visual.rotation.x = lerpf(_visual.rotation.x, lean, minf(1.0, 8.0 * delta))

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		velocity = Vector3.ZERO
		_drive = Vector3.ZERO
		_push_velocity = Vector3.ZERO

func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_drive = Vector3.ZERO
	_push_velocity = Vector3.ZERO
	_wish = Vector3.ZERO
	_visual.rotation = Vector3(0, -PI / 2.0 if team_index == 0 else PI / 2.0, 0)
	for limb in [_arm_l, _arm_r, _leg_l, _leg_r]:
		limb.rotation.x = 0.0
	_run_phase = 0.0
