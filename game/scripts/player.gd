class_name Player
extends CharacterBody3D

## 1人分のプレイヤー。入力アクション名は "p%d_*" % (player_index + 1) を参照する。
## 2〜4人対戦にするときは、player_index を変えたインスタンスを追加し、
## project.godot に p2_* 以降の入力アクションを足すだけでよい。
##
## 手触り調整: Movement のエクスポート変数はインスペクタから変更できる。

signal flushed(player_index: int)
signal submerged(player_index: int)
signal fell_off(player_index: int)
signal respawned(player_index: int)

@export var player_index := 0

@export_group("Movement")
@export var run_speed := 6.0
## 地上での速度追従の強さ /s
@export var ground_lerp := 12.0
## 空中は入力が効きにくく、吸引にも流されやすい
@export var air_lerp := 4.0
@export var jump_velocity := 6.5
@export var gravity := 14.0

const FLUSH_SPIN_TIME := 1.6  # 螺旋吸い込み演出の長さ
const RESPAWN_DELAY := 0.9

enum State { ALIVE, FLUSHED, RESPAWNING }

var state := State.ALIVE
var fall_count := 0

var _state_timer := 0.0
var _spawn_point := Vector3.ZERO
var _flush_controller: FlushController
var _drain_center := Vector3.ZERO
var _spiral_angle := 0.0
var _spiral_radius := 0.0
var _spiral_y := 0.0

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _scream: Label3D = $Scream

func _ready() -> void:
	_spawn_point = global_position
	_flush_controller = get_tree().get_first_node_in_group("flush_controller") as FlushController

func _physics_process(delta: float) -> void:
	match state:
		State.ALIVE:
			_step_alive(delta)
		State.FLUSHED:
			_step_flush_spiral(delta)
		State.RESPAWNING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_respawn()

func _step_alive(delta: float) -> void:
	var prefix := "p%d" % [player_index + 1]
	var input := Input.get_vector(
		prefix + "_left", prefix + "_right", prefix + "_up", prefix + "_down"
	)
	var target := Vector3(input.x, 0.0, input.y) * run_speed
	var lerp_rate := ground_lerp if is_on_floor() else air_lerp
	var k := minf(1.0, lerp_rate * delta)
	velocity.x += (target.x - velocity.x) * k
	velocity.z += (target.z - velocity.z) * k

	if _flush_controller:
		var suction := _flush_controller.get_suction_accel(global_position, not is_on_floor())
		velocity.x += suction.x * delta
		velocity.z += suction.z * delta

	if is_on_floor():
		if Input.is_action_just_pressed(prefix + "_jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_update_visual(delta)

func _update_visual(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.8:
		var yaw := atan2(-velocity.x, -velocity.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, minf(1.0, 10.0 * delta))
	if is_on_floor():
		_visual.rotation.x = lerp_angle(_visual.rotation.x, 0.0, minf(1.0, 12.0 * delta))
	else:
		# 空中ではコロコロ回る（物理的なバカっぽさ担当）
		_visual.rotation.x += hspeed * 0.35 * delta

## 便器穴に落ちたとき（DrainZone から呼ばれる）。螺旋で吸い込まれる演出に入る。
func start_flush(drain_center: Vector3) -> void:
	if state != State.ALIVE:
		return
	state = State.FLUSHED
	_state_timer = FLUSH_SPIN_TIME
	fall_count += 1
	_drain_center = drain_center
	var offset := global_position - drain_center
	_spiral_radius = maxf(Vector2(offset.x, offset.z).length(), 1.2)
	_spiral_angle = atan2(offset.z, offset.x)
	_spiral_y = global_position.y
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_scream.visible = true
	flushed.emit(player_index)

func _step_flush_spiral(delta: float) -> void:
	_state_timer -= delta
	var t := clampf(1.0 - _state_timer / FLUSH_SPIN_TIME, 0.0, 1.0)
	# 回転は終盤ほど速く、半径は縮み、沈む速度も加速する
	_spiral_angle += (6.0 + 11.0 * t) * delta
	_spiral_radius = maxf(0.3, _spiral_radius - 2.2 * delta)
	_spiral_y -= (0.7 + 2.6 * t) * delta
	global_position = Vector3(
		_drain_center.x + cos(_spiral_angle) * _spiral_radius,
		_spiral_y,
		_drain_center.z + sin(_spiral_angle) * _spiral_radius
	)
	_visual.rotate_y(16.0 * delta)
	# 縮みながら縦に伸びる（麺のように吸われるバカっぽさ担当）
	var shrink := clampf(1.0 - 0.7 * t, 0.3, 1.0)
	var stretch := 1.0 + 1.1 * sin(t * PI)
	_visual.scale = Vector3(shrink, shrink * stretch, shrink)
	if _state_timer <= 0.0:
		_scream.visible = false
		submerged.emit(player_index)
		hide()
		state = State.RESPAWNING
		_state_timer = RESPAWN_DELAY

## 外周から転落したとき（OuterKillZone から呼ばれる）。
func fall_off() -> void:
	if state != State.ALIVE:
		return
	state = State.RESPAWNING
	_state_timer = RESPAWN_DELAY
	fall_count += 1
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	hide()
	fell_off.emit(player_index)

func reset_for_round() -> void:
	fall_count = 0
	_respawn()

func _respawn() -> void:
	global_position = _spawn_point
	velocity = Vector3.ZERO
	_visual.scale = Vector3.ONE
	_visual.rotation = Vector3.ZERO
	_scream.visible = false
	_collision.set_deferred("disabled", false)
	state = State.ALIVE
	show()
	respawned.emit(player_index)
