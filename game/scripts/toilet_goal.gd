class_name ToiletGoal
extends Node3D

## 便器ゴール1基。ボールがフィールド側から入口を横切ると ball_entered を発火し、
## celebrate() でゴール水流演出（渦・水位低下・スプラッシュ）を再生する。
## 得点計算やボールのリセットはゲーム側（toilet_goal_game.gd）の責務。

signal ball_entered(goal: ToiletGoal)

@export var team_name := "あか"
@export var team_color := Color(0.9, 0.35, 0.3)

const CELEBRATE_TIME := 1.6

var _celebrating := false
var _celebrate_timer := 0.0
var _water_home := Vector3.ZERO
var _ball: Ball
var _previous_ball_position := Vector3.ZERO
var scoring_enabled := false
var _splashes: Array[MeshInstance3D] = []
var _splash_tweens: Array[Tween] = []

const GOAL_PLANE_X := -0.9

@onready var _water: Node3D = $Water
@onready var _swirl: Node3D = $Swirl
@onready var _label: Label3D = $NameLabel

func _ready() -> void:
	_water_home = _water.position
	# 便座をチームカラーに（インスタンスごとの色分け）
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = team_color
	$Seat.material = seat_mat
	_label.text = team_name + "便器"
	_label.modulate = team_color

func watch_ball(ball: Ball) -> void:
	_ball = ball
	_previous_ball_position = to_local(ball.global_position)

func set_scoring_enabled(value: bool) -> void:
	scoring_enabled = value
	if is_instance_valid(_ball):
		_previous_ball_position = to_local(_ball.global_position)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_ball):
		return
	var current := to_local(_ball.global_position)
	# Only a full crossing from the pitch into the bowl counts. An Area alone
	# also scores entry from behind or over the side wall.
	if scoring_enabled and _previous_ball_position.x > GOAL_PLANE_X and current.x <= GOAL_PLANE_X:
		var fraction := (GOAL_PLANE_X - _previous_ball_position.x) / (current.x - _previous_ball_position.x)
		var crossing := _previous_ball_position.lerp(current, fraction)
		if absf(crossing.z) <= 1.7 and crossing.y >= 0.65 and crossing.y <= 3.65:
			ball_entered.emit(self)
	_previous_ball_position = current

func _process(delta: float) -> void:
	var water_target_y := _water_home.y
	if _celebrating:
		_celebrate_timer -= delta
		_swirl.rotate_y(10.0 * delta)
		water_target_y -= 0.5
		if _celebrate_timer <= 0.0:
			_celebrating = false
			_swirl.visible = false
	_water.position.y = lerpf(_water.position.y, water_target_y, minf(1.0, 5.0 * delta))

func reset_effects() -> void:
	_celebrating = false
	_celebrate_timer = 0.0
	_water.position = _water_home
	_swirl.rotation = Vector3.ZERO
	_swirl.hide()
	for tween in _splash_tweens:
		if tween.is_valid():
			tween.kill()
	_splash_tweens.clear()
	for splash in _splashes:
		if is_instance_valid(splash):
			splash.queue_free()
	_splashes.clear()

## ゴール水流演出を再生する
func celebrate() -> void:
	_celebrating = true
	_celebrate_timer = CELEBRATE_TIME
	_swirl.visible = true
	_spawn_splash()

## 水面で広がる水しぶき（使い捨てノード）
func _spawn_splash() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	var splash := MeshInstance3D.new()
	splash.mesh = mesh
	splash.material_override = mat
	splash.position = _water.position + Vector3(0.0, 0.4, 0.0)
	add_child(splash)
	_splashes.append(splash)
	var tween := create_tween()
	_splash_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(splash, "scale", Vector3(3.2, 1.6, 3.2), 0.45).from(Vector3(0.5, 0.5, 0.5))
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(splash.queue_free)
