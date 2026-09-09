class_name CityProjectile
extends Node3D

const GRAVITY := 14.0
var team := 0
var shooter: CharacterBody3D
var velocity := Vector3.ZERO
var game: Node3D
var life := 5.0
var consumed := false
var visual: Node3D

func _ready() -> void:
	visual = CityArt.poop(self)
	visual.position.y = -0.25

func _physics_process(delta: float) -> void:
	if consumed:
		return
	life -= delta
	var next := global_position + velocity * delta + Vector3.DOWN * GRAVITY * delta * delta * 0.5
	var hit: Dictionary = game.trace_shot(global_position, next, shooter)
	if not hit.is_empty():
		consumed = true
		global_position = hit.position
		game.resolve_shot(self, hit)
		queue_free()
		return
	global_position = next
	velocity.y -= GRAVITY * delta
	visual.rotate_y(delta * 8)
	if life <= 0 or global_position.y < -5:
		queue_free()
