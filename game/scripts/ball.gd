class_name Ball
extends RigidBody3D

var _spawn_transform := Transform3D.IDENTITY
var _locked := false
var _flush_tween: Tween
@onready var _visual: Node3D = $Visual

func _ready() -> void:
	_spawn_transform = global_transform
	continuous_cd = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(24.0)

func set_locked(value: bool) -> void:
	_locked = value
	_sync_freeze.call_deferred()

func _sync_freeze() -> void:
	freeze = _locked
	if _locked:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		sleeping = false

func reset_to_spawn() -> void:
	if _flush_tween:
		_flush_tween.kill()
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn_transform
	_visual.transform = Transform3D.IDENTITY
	# Read the current lock when deferred work executes, not an obsolete reset value.
	_sync_freeze.call_deferred()

func play_flush(destination: Vector3) -> void:
	if _flush_tween:
		_flush_tween.kill()
	set_locked(true)
	_flush_tween = create_tween().set_parallel(true)
	_flush_tween.tween_property(_visual, "position", to_local(destination), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flush_tween.tween_property(_visual, "scale", Vector3.ONE * 0.04, 1.2)
	_flush_tween.tween_property(_visual, "rotation:y", TAU * 2.0, 1.2)
