extends Node3D

## v0.2 3D graybox のシーン統括。
## 演出（タンク振動・渦・水位・カメラ揺れ・ズーム・スプラッシュ・UI文言）を
## ここに集約し、FlushController は純ロジック、Player は自機の挙動だけを持つ。

const DRAIN_CENTER := Vector3(0.0, -3.6, 0.0)
const FLUSH_ZOOM := 0.6  # 吸い込まれ演出中のクローズアップ倍率

const COLOR_IDLE := Color(1.0, 1.0, 1.0)
const COLOR_WARN := Color(1.0, 0.55, 0.3)
const COLOR_FLUSH := Color(0.45, 0.75, 1.0)

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
	_player.flushed.connect(_on_player_flushed)
	_player.submerged.connect(_on_player_submerged)
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
	if event.is_action_pressed("reset_game") and not event.is_echo():
		_reset()

func _update_status_ui() -> void:
	var status := ""
	var color := COLOR_IDLE
	match _flush.phase:
		"idle":
			status = "水流まで %.1fs" % _flush.time_left()
		"warning":
			status = "!! まもなく水流 !! %.1fs" % _flush.time_left()
			color = COLOR_WARN
		"flushing":
			status = "水流中！！ 残り %.1fs" % _flush.time_left()
			color = COLOR_FLUSH
	status += "\n水流回数: %d   流された回数: %d" % [_flush.flush_count, _player.fall_count]
	_ui.set_status(status, color)

	match _flush.phase:
		"warning":
			# 水流が近づくほど点滅が速くなる
			var prog: float = _flush.warn_progress()
			var period := lerpf(0.5, 0.22, prog)
			if fmod(_elapsed, period) < period * 0.6:
				_ui.show_center("!! ゴゴゴゴ… %.1f !!" % _flush.time_left(), Color(0.95, 0.3, 0.25))
			else:
				_ui.hide_center()
		"flushing":
			_ui.show_center("水流中！！", COLOR_FLUSH)
		_:
			_ui.hide_center()

func _update_effects(delta: float) -> void:
	var water_target_y := _water_home.y
	match _flush.phase:
		"warning":
			# 水流が近づくほどタンクの震えと画面の揺れが強くなる
			var prog: float = _flush.warn_progress()
			var amp := lerpf(0.03, 0.14, prog)
			_tank.position = _tank_home + Vector3(sin(_elapsed * 45.0) * amp, 0.0, 0.0)
			_rig.shake = lerpf(0.02, 0.1, prog)
			# 水位が上がり、波打つ（あふれる予感）
			water_target_y += 0.45 + sin(_elapsed * 18.0) * 0.08
		"flushing":
			_tank.position = _tank_home + Vector3(sin(_elapsed * 60.0) * 0.1, 0.0, 0.0)
			_rig.shake = 0.18
			water_target_y -= 0.7
		_:
			_tank.position = _tank_home
			_rig.shake = 0.0

	_swirl.visible = _flush.is_flushing()
	if _swirl.visible:
		_swirl.rotate_y(9.0 * delta)

	_water.position.y = lerpf(_water.position.y, water_target_y, minf(1.0, 4.0 * delta))

	# 吸い込まれ演出中はカメラが寄る（動画映え担当）
	_rig.zoom = FLUSH_ZOOM if _player.state == Player.State.FLUSHED else 1.0

func _on_phase_changed(phase: String) -> void:
	match phase:
		"warning":
			_log("ゴゴゴゴ… まもなく水流！")
		"flushing":
			_log("水流発生！！（%d回目）" % _flush.flush_count)
		"idle":
			_log("水流が収まった…")

func _on_player_flushed(i: int) -> void:
	_rig.kick(0.4)
	_log("P%d が流された！ 南無…" % (i + 1))

func _on_player_submerged(i: int) -> void:
	_spawn_splash()
	_log("ジャーッ！ P%d 水没" % (i + 1))

## 水没の瞬間に水面で広がる水しぶきリングを出す（使い捨てノード）
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
	splash.position = Vector3(0.0, _water.position.y + 0.3, 0.0)
	add_child(splash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(splash, "scale", Vector3(4.0, 1.8, 4.0), 0.45).from(Vector3(0.6, 0.6, 0.6))
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(splash.queue_free)

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
