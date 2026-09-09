class_name CityGrime
extends Node3D

const CELL := 1.2
const WIDTH := 64
var cells: Dictionary = {}
var _layers: Array[MultiMesh] = []
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

func _ready() -> void:
	for team in 2:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var patch := PlaneMesh.new()
		patch.size = Vector2(1.9, 1.9)
		multi.mesh = patch
		multi.instance_count = WIDTH * WIDTH
		for index in multi.instance_count:
			multi.set_instance_transform(index, HIDDEN)
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/city_grime.gdshader")
		mat.set_shader_parameter("base_color", Color("654228") if team == 0 else Color("4b4c32"))
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_layers.append(multi)

func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))

func is_slippery(point: Vector3) -> bool:
	return cells.has(cell_at(point))

func _index(cell: Vector2i) -> int:
	return (cell.x + WIDTH / 2) + (cell.y + WIDTH / 2) * WIDTH

func splat(point: Vector3, radius: float, team: int) -> int:
	var changed := 0
	var centre := cell_at(point)
	var spread := ceili(radius / CELL)
	for x in range(centre.x - spread, centre.x + spread + 1):
		for z in range(centre.y - spread, centre.y + spread + 1):
			var cell := Vector2i(x, z)
			if absi(x) >= 31 or absi(z) >= 29:
				continue
			var location := Vector3(x * CELL, 0.035, z * CELL)
			if Vector2(location.x - point.x, location.z - point.z).length() > radius:
				continue
			# Do not paint under buildings, or on their far side through a wall.
			var from := point + Vector3.UP * 0.15
			var to := location + Vector3.UP * 0.15
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			if not hit.is_empty():
				continue
			if cells.has(cell):
				_layers[cells[cell]].set_instance_transform(_index(cell), HIDDEN)
			else:
				changed += 1
			cells[cell] = team
			var yaw := float(posmod(x * 31 + z * 17, 10)) * 0.6
			_layers[team].set_instance_transform(_index(cell), Transform3D(Basis(Vector3.UP, yaw), location))
	return changed

func clean(point: Vector3, radius: float) -> int:
	var cleaned := 0
	for cell: Vector2i in cells.keys():
		var location := Vector3(cell.x * CELL, 0.2, cell.y * CELL)
		if Vector2(location.x - point.x, location.z - point.z).length() <= radius:
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, location, 1))
			if not hit.is_empty():
				continue
			_layers[cells[cell]].set_instance_transform(_index(cell), HIDDEN)
			cells.erase(cell)
			cleaned += 1
	return cleaned

func clear_all() -> void:
	for cell: Vector2i in cells:
		_layers[cells[cell]].set_instance_transform(_index(cell), HIDDEN)
	cells.clear()

func territory_counts() -> Array[int]:
	var counts: Array[int] = [0, 0]
	for cell: Vector2i in cells:
		if cell.y > 0:
			counts[0] += 1
		elif cell.y < 0:
			counts[1] += 1
	return counts
