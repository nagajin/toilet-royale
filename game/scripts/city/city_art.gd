class_name CityArt
extends RefCounted

const TEAMS := [Color("f58a45"), Color("36c8d8")]
const CREAM := Color("fff2d5")
static var _surfaces: Dictionary = {}
static var _materials: Dictionary = {}

static func clear_cache() -> void:
	_surfaces.clear()
	_materials.clear()

static func material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var key := "%s:%s" % [color, roughness]
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	_materials[key] = result
	return result

static func surface(color: Color, pattern: int = 0, roughness: float = 0.85) -> ShaderMaterial:
	var key := "%s:%s:%s" % [color, pattern, roughness]
	if _surfaces.has(key):
		return _surfaces[key]
	var result := ShaderMaterial.new()
	result.shader = load("res://shaders/city_surface.gdshader")
	result.set_shader_parameter("base_color", color)
	result.set_shader_parameter("pattern", pattern)
	result.set_shader_parameter("grain", 0.4 if pattern == 1 else 0.18)
	result.set_shader_parameter("surface_roughness", roughness)
	_surfaces[key] = result
	return result

static func metal(color: Color = Color("899393"), roughness: float = 0.28) -> StandardMaterial3D:
	var result := material(color, roughness).duplicate() as StandardMaterial3D
	result.metallic = 0.82
	return result

static func mesh(parent: Node3D, shape: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = position
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := mesh(parent, shape, position, color)
	if solid:
		var body := StaticBody3D.new()
		body.position = position
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		parent.add_child(body)
	return node

static func sphere(parent: Node3D, position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 24
	shape.rings = 12
	return mesh(parent, shape, position, color)

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 20
	return mesh(parent, shape, position, color)

static func label(parent: Node3D, text: String, position: Vector3, color: Color, size: int = 48) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = position
	node.modulate = color
	node.font_size = size
	node.pixel_size = 0.010
	node.outline_size = 8
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.visibility_range_begin = 4.0
	node.visibility_range_end = 52.0
	parent.add_child(node)
	return node

static func poop(parent: Node3D, color: Color = Color("714025")) -> Node3D:
	var visual := Node3D.new()
	parent.add_child(visual)
	for index in 3:
		var part := sphere(visual, Vector3(0, 0.14 + index * 0.18, 0), 0.3 - index * 0.07, color)
		part.scale.y = 0.6
		part.material_override = surface(color, 0, 0.34)
	var tip := sphere(visual, Vector3(0.07, 0.58, 0), 0.09, color)
	tip.scale = Vector3(0.8, 1.4, 0.8)
	tip.material_override = surface(color, 0, 0.34)
	return visual

static func capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 24
	shape.rings = 8
	return mesh(parent, shape, at, color)

static func collision_box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

# Revolve a radius/height profile. Inner and outer walls share a closed profile.
static func lathe(parent: Node3D, at: Vector3, profile: Array[Vector2], mat: Material, segments: int = 64) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(profile.size() - 1):
		for side in segments:
			for corner in [Vector2i(level, side), Vector2i(level, side + 1), Vector2i(level + 1, side), Vector2i(level + 1, side), Vector2i(level, side + 1), Vector2i(level + 1, side + 1)]:
				var angle := float(corner.y) / segments * TAU
				var item := profile[corner.x]
				var tangent := profile[mini(corner.x + 1, profile.size() - 1)] - profile[maxi(0, corner.x - 1)]
				surface_tool.set_normal(Vector3(tangent.y * cos(angle), -tangent.x, tangent.y * sin(angle)).normalized())
				surface_tool.set_uv(Vector2(float(corner.y) / segments, float(corner.x) / (profile.size() - 1)))
				surface_tool.add_vertex(Vector3(item.x * cos(angle), item.y, item.x * sin(angle)))
	var node := mesh(parent, surface_tool.commit(), at, Color.WHITE)
	node.material_override = mat
	return node

static func ring(parent: Node3D, at: Vector3, radius: float, thickness: float, mat: Material, flatten: float = 1.0) -> MeshInstance3D:
	var profile: Array[Vector2] = []
	for index in 17:
		var angle := float(index) / 16.0 * TAU
		profile.append(Vector2(radius + cos(angle) * thickness, sin(angle) * thickness * flatten))
	return lathe(parent, at, profile, mat)

static func rounded_box(parent: Node3D, at: Vector3, size: Vector3, bevel: float, mat: Material) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	bevel = minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.95)
	var inner := half - Vector3.ONE * bevel
	for axis in 3:
		for sign_axis in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var us := [-half[u], -inner[u], 0.0, inner[u], half[u]]
			var vs := [-half[v], -inner[v], 0.0, inner[v], half[v]]
			for row in 4:
				for col in 4:
					var corners := [Vector2i(col, row), Vector2i(col, row + 1), Vector2i(col + 1, row), Vector2i(col + 1, row), Vector2i(col, row + 1), Vector2i(col + 1, row + 1)]
					if sign_axis < 0:
						corners.reverse()
					for corner in corners:
						var point := Vector3.ZERO
						point[axis] = half[axis] * sign_axis
						point[u] = us[corner.x]
						point[v] = vs[corner.y]
						var clamped := point.clamp(-inner, inner)
						var normal := (point - clamped).normalized()
						surface_tool.set_normal(normal)
						surface_tool.set_uv(Vector2(point[u], point[v]))
						surface_tool.add_vertex(clamped + normal * bevel)
	var node := mesh(parent, surface_tool.commit(), at, Color.WHITE)
	node.material_override = mat
	return node
