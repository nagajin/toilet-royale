extends Node3D

## プレイヤーを追う固定角の見下ろしカメラ。
## - shake: 継続的な揺れ（フェーズ演出用、main.gd が毎フレーム設定）
## - kick(): 単発の強い揺れ（脱落の瞬間など）
## - zoom: 1.0 が通常。小さくすると寄る（吸い込まれの瞬間のクローズアップ用）
## 脱落演出中もプレイヤー位置を追うので、吸い込まれる瞬間がカメラに映る。

const FOLLOW_RATE := 6.0
const ZOOM_RATE := 4.0
const KICK_DECAY := 5.0

## カメラのリグ原点からのオフセット。デフォルトは v0.2 の追従カメラ用。
## v0.2.5 の固定全体視点など、シーンごとにインスペクタで変更できる。
@export var camera_offset := Vector3(0.0, 10.0, 14.0)

var target: Node3D
var shake := 0.0
var zoom := 1.0

var _kick := 0.0
var _zoom_now := 1.0

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_camera.position = camera_offset
	_camera.look_at(global_position, Vector3.UP)

## 単発の揺れを加える。amount は shake と同じスケール。
func kick(amount: float) -> void:
	_kick = maxf(_kick, amount)

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(
			target.global_position, minf(1.0, FOLLOW_RATE * delta)
		)
	_zoom_now = lerpf(_zoom_now, zoom, minf(1.0, ZOOM_RATE * delta))
	_kick = lerpf(_kick, 0.0, minf(1.0, KICK_DECAY * delta))
	var s := shake + _kick
	var offset := camera_offset * _zoom_now
	if s > 0.001:
		offset += Vector3(randf_range(-s, s), randf_range(-s, s), 0.0)
	_camera.position = offset
