extends Node3D

## v0.2 3D graybox のシーン統括。
## 演出（タンク振動・渦・水位・カメラ揺れ・UI文言）をここに集約し、
## FlushController は純ロジック、Player は自機の挙動だけを持つ。

const DRAIN_CENTER := Vector3(0.0, -3.6, 0.0)

@onready var _flush: FlushController = $FlushController
@onready var _player: Player = $Player
@onready var _ui = $DebugUI
@onready var _rig = $CameraRig
@onready var _tank: Node3D = $Stage/Tank
@onready var _swirl: Node3D = $Stage/Swirl
@onready var _water: Node3D = $Stage/Water

var _elapsed := 0.0
var _tank_home := Vector3.ZERO
var _water_home := Vector3.ZERO

func _ready() -> void:
	_tank_home = _tank.position
	_water_home = _water.position
	_flush.drain_center = DRAIN_CENTER
	_rig.target = _player
	$Sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)

	_flush.phase_changed.connect(_on_phase_changed)
	_player.flushed.connect(func(i: int) -> void: _log("P%d が流された！ 南無…" % (i + 1)))
	_player.fell_off.connect(func(i: int) -> void: _log("P%d は外周から転落した" % (i + 1)))
	_player.respawned.connect(func(i: int) -> void: _log("P%d リスポーン" % (i + 1)))
	$DrainZone.body_entered.connect(_on_drain_zone_entered)
	$OuterKillZone.body_entered.connect(_on_outer_kill_zone_entered)

	_log("トイレロワイヤル v0.2 (3D graybox) 起動。水流に気をつけろ！")

func _process(delta: float) -> void:
	_elapsed += delta
	_update_status_ui()
	_update_effects(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_game"):
		_reset()

func _update_status_ui() -> void:
	var status := ""
	match _flush.phase:
		"idle":
			status = "水流まで %.1fs" % _flush.time_left()
		"warning":
			status = "!! まもなく水流 !! %.1fs" % _flush.time_left()
		"flushing":
			status = "水流中！！ 残り %.1fs" % _flush.time_left()
	status += "\n水流回数: %d   流された回数: %d" % [_flush.flush_count, _player.fall_count]
	_ui.set_status(status)

	match _flush.phase:
		"warning":
			# 点滅させて「まずい」感を出す
			if fmod(_elapsed, 0.4) < 0.25:
				_ui.show_center("!! ゴゴゴゴ… !!", Color(0.95, 0.25, 0.25))
			else:
				_ui.hide_center()
		"flushing":
			_ui.show_center("水流中！！", Color(0.25, 0.55, 0.95))
		_:
			_ui.hide_center()

func _update_effects(delta: float) -> void:
	match _flush.phase:
		"warning":
			_tank.position = _tank_home + Vector3(sin(_elapsed * 45.0) * 0.06, 0.0, 0.0)
			_rig.shake = 0.05
		"flushing":
			_tank.position = _tank_home + Vector3(sin(_elapsed * 60.0) * 0.1, 0.0, 0.0)
			_rig.shake = 0.18
		_:
			_tank.position = _tank_home
			_rig.shake = 0.0

	_swirl.visible = _flush.is_flushing()
	if _swirl.visible:
		_swirl.rotate_y(9.0 * delta)

	# 警告中は水位が上がり（あふれる予感）、水流中は下がる（吸い込み中）
	var water_target_y := _water_home.y
	if _flush.phase == "warning":
		water_target_y += 0.4
	elif _flush.phase == "flushing":
		water_target_y -= 0.7
	_water.position.y = lerpf(_water.position.y, water_target_y, minf(1.0, 4.0 * delta))

func _on_phase_changed(phase: String) -> void:
	match phase:
		"warning":
			_log("ゴゴゴゴ… まもなく水流！")
		"flushing":
			_log("水流発生！！（%d回目）" % _flush.flush_count)
		"idle":
			_log("水流が収まった…")

func _on_drain_zone_entered(body: Node3D) -> void:
	if body is Player:
		body.start_flush(DRAIN_CENTER)

func _on_outer_kill_zone_entered(body: Node3D) -> void:
	if body is Player:
		body.fall_off()

func _reset() -> void:
	_flush.reset()
	_player.reset_for_round()
	_ui.clear_log()
	_log("リセットしました")

func _log(line: String) -> void:
	_ui.add_log("[%6.1fs] %s" % [_elapsed, line])
