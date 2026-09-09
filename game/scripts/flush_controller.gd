class_name FlushController
extends Node

## 水流の状態機械（純ロジック、演出は main.gd 側）。
## ノードグループ "flush_controller" に入れて使う。
## 吸引はプレイヤー側が毎物理フレーム get_suction_accel() を問い合わせる形にし、
## プレイヤー数に依存しない（2〜4人対戦でもそのまま動く）。
##
## 手触り調整: 以下のエクスポート変数は main.tscn の FlushController ノードを
## 選択するとインスペクタから変更できる（コードを触らなくてよい）。

signal phase_changed(phase: String)

@export_group("Cycle")
@export var idle_time := 6.0
@export var warn_time := 2.5
@export var flush_time := 3.5

@export_group("Suction")
## 基本吸引加速度 m/s^2
@export var suction := 26.0
## 距離減衰スケール（大きいほど遠くでも吸われる）
@export var falloff_dist := 14.0
## 外周でも最低これだけは吸う
@export var min_factor := 0.45
## 穴の直近での最大係数（吸い込みの「最後のひと引き」）
@export var max_factor := 1.6
## 空中では強く吸われる（ジャンプ＝リスク）
@export var air_multiplier := 1.8
## 水流開始から最大吸引に達するまでの立ち上がり時間
@export var ramp_time := 0.6

var phase := "idle"
var phase_timer := 6.0
var flush_count := 0
var drain_center := Vector3.ZERO

var _flush_elapsed := 0.0

func _ready() -> void:
	phase_timer = idle_time

func _physics_process(delta: float) -> void:
	if phase == "flushing":
		_flush_elapsed += delta
	phase_timer -= delta
	if phase_timer > 0.0:
		return
	match phase:
		"idle":
			_change_phase("warning", warn_time)
		"warning":
			flush_count += 1
			_flush_elapsed = 0.0
			_change_phase("flushing", flush_time)
		"flushing":
			_change_phase("idle", idle_time)

func _change_phase(next: String, duration: float) -> void:
	phase = next
	phase_timer += duration
	phase_changed.emit(next)

func is_flushing() -> bool:
	return phase == "flushing"

func time_left() -> float:
	return maxf(phase_timer, 0.0)

## 警告フェーズの進行度 0〜1（演出のエスカレーション用）。警告中以外は 0。
func warn_progress() -> float:
	if phase != "warning":
		return 0.0
	return clampf(1.0 - phase_timer / maxf(warn_time, 0.05), 0.0, 1.0)

## pos にいる物体が受ける吸引加速度（水平方向のみ）。
func get_suction_accel(pos: Vector3, airborne: bool) -> Vector3:
	if phase != "flushing":
		return Vector3.ZERO
	var to_drain := drain_center - pos
	to_drain.y = 0.0
	var dist := to_drain.length()
	if dist < 0.2:
		return Vector3.ZERO
	var factor := clampf(max_factor - dist / falloff_dist, min_factor, max_factor)
	# 水流の立ち上がり: 開始直後は弱く、ramp_time かけて最大へ
	var ramp := clampf(_flush_elapsed / maxf(ramp_time, 0.05), 0.2, 1.0)
	var accel := suction * factor * ramp * (air_multiplier if airborne else 1.0)
	return to_drain / dist * accel

func reset() -> void:
	phase = "idle"
	phase_timer = idle_time
	flush_count = 0
	_flush_elapsed = 0.0
