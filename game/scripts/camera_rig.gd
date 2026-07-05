extends Node3D

## プレイヤーを追う固定角の見下ろしカメラ。shake を上げると揺れる。
## 脱落演出中もプレイヤー位置を追うので、吸い込まれる瞬間がカメラに映る。

const FOLLOW_RATE := 6.0
const CAMERA_OFFSET := Vector3(0.0, 10.0, 14.0)

var target: Node3D
var shake := 0.0

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_camera.position = CAMERA_OFFSET
	_camera.look_at(global_position, Vector3.UP)

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(
			target.global_position, minf(1.0, FOLLOW_RATE * delta)
		)
	if shake > 0.0:
		_camera.position = CAMERA_OFFSET + Vector3(
			randf_range(-shake, shake), randf_range(-shake, shake), 0.0
		)
	else:
		_camera.position = CAMERA_OFFSET
