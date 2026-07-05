class_name FlushController
extends Node

## 水流の状態機械（純ロジック、演出は main.gd 側）。
## ノードグループ "flush_controller" に入れて使う。
## 吸引はプレイヤー側が毎物理フレーム get_suction_accel() を問い合わせる形にし、
## プレイヤー数に依存しない（2〜4人対戦でもそのまま動く）。

signal phase_changed(phase: String)

const IDLE_TIME := 6.0
const WARN_TIME := 2.5
const FLUSH_TIME := 3.5

const SUCTION := 26.0        # 基本吸引加速度 m/s^2
const FALLOFF_DIST := 14.0   # 距離減衰スケール
const MIN_FACTOR := 0.45     # 外周でも最低これだけは吸う
const MAX_FACTOR := 1.4      # 穴の直近での最大係数
const AIR_MULTIPLIER := 1.8  # 空中では強く吸われる（ジャンプ＝リスク）

var phase := "idle"
var phase_timer := IDLE_TIME
var flush_count := 0
var drain_center := Vector3.ZERO

func _physics_process(delta: float) -> void:
	phase_timer -= delta
	if phase_timer > 0.0:
		return
	match phase:
		"idle":
			_change_phase("warning", WARN_TIME)
		"warning":
			flush_count += 1
			_change_phase("flushing", FLUSH_TIME)
		"flushing":
			_change_phase("idle", IDLE_TIME)

func _change_phase(next: String, duration: float) -> void:
	phase = next
	phase_timer += duration
	phase_changed.emit(next)

func is_flushing() -> bool:
	return phase == "flushing"

func time_left() -> float:
	return maxf(phase_timer, 0.0)

## pos にいる物体が受ける吸引加速度（水平方向のみ）。
func get_suction_accel(pos: Vector3, airborne: bool) -> Vector3:
	if phase != "flushing":
		return Vector3.ZERO
	var to_drain := drain_center - pos
	to_drain.y = 0.0
	var dist := to_drain.length()
	if dist < 0.2:
		return Vector3.ZERO
	var factor := clampf(MAX_FACTOR - dist / FALLOFF_DIST, MIN_FACTOR, MAX_FACTOR)
	var accel := SUCTION * factor * (AIR_MULTIPLIER if airborne else 1.0)
	return to_drain / dist * accel

func reset() -> void:
	phase = "idle"
	phase_timer = IDLE_TIME
	flush_count = 0
