class_name CityToilet
extends Node3D

var team := 0
var station_index := 0
var flush_time := 0.0
var cooldown := 0.0
var water: MeshInstance3D
var swirl: Node3D
const WATER_Y := 1.25
const MOUTH_RADIUS := 1.22

func _ready() -> void:
	var color: Color = CityArt.TEAMS[team]
	var ceramic := CityArt.material(Color("eeeade"), 0.16)
	var seat_mat := CityArt.material(color.darkened(0.1), 0.23)
	CityArt.cylinder(self, Vector3(0, 0.055, 0), 2.35, 0.1, Color("9baaa2")).material_override = CityArt.surface(Color("9baaa2"), 2)
	CityArt.ring(self, Vector3(0, 0.11, 0), 2.25, 0.035, CityArt.material(color), 0.5)
	# The bowl is hollow, including collision: score rays reach the water through the opening.
	var profile: Array[Vector2] = [Vector2(0.02, 0.12), Vector2(0.75, 0.12), Vector2(0.91, 0.19), Vector2(0.84, 0.35), Vector2(0.7, 0.65), Vector2(1.12, 0.8), Vector2(1.43, 1.08), Vector2(1.62, 1.35), Vector2(1.64, 1.45), Vector2(1.56, 1.49), Vector2(1.34, 1.49), Vector2(1.27, 1.4), Vector2(1.22, 1.23), Vector2(0.92, 0.98), Vector2(0.55, 0.83), Vector2(0.14, 0.77), Vector2(0.02, 0.77)]
	var bowl := CityArt.lathe(self, Vector3.ZERO, profile, ceramic)
	bowl.create_trimesh_collision()
	CityArt.ring(self, Vector3(0, 1.54, 0), 1.47, 0.18, seat_mat, 0.45)
	CityArt.rounded_box(self, Vector3(0, 2.0, 1.93), Vector3(3.1, 2.9, 0.92), 0.18, ceramic)
	CityArt.collision_box(self, Vector3(0, 2, 1.93), Vector3(3.1, 2.9, 0.92))
	CityArt.rounded_box(self, Vector3(0, 3.48, 1.93), Vector3(3.25, 0.16, 1.02), 0.065, ceramic)
	CityArt.rounded_box(self, Vector3(0, 2.3, 1.44), Vector3(1.3, 0.62, 0.04), 0.04, seat_mat)
	var badge := CityArt.label(self, "A" if station_index == 0 else "B", Vector3(0, 2.3, 1.4), Color.WHITE, 43)
	badge.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	badge.rotation.y = PI
	badge.visibility_range_begin = 0
	badge.outline_size = 0
	CityArt.rounded_box(self, Vector3(1.02, 2.96, 1.4), Vector3(0.42, 0.12, 0.2), 0.04, CityArt.metal())
	for x in [-0.85, 0.85]:
		CityArt.cylinder(self, Vector3(x, 1.61, 1.25), 0.08, 0.14, Color.WHITE).material_override = CityArt.metal()
	water = CityArt.cylinder(self, Vector3(0, WATER_Y, 0), MOUTH_RADIUS, 0.025, Color.WHITE)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/city_water.gdshader")
	water.material_override = water_mat
	swirl = Node3D.new()
	swirl.position.y = WATER_Y + 0.04
	add_child(swirl)
	for index in 18:
		var angle := float(index) / 18 * TAU
		var droplet := CityArt.sphere(swirl, Vector3(cos(angle), 0.13 + sin(index * 2) * 0.12, sin(angle)), 0.045, Color("d4efeb"))
		droplet.scale = Vector3(1, 1.8, 1)
	swirl.hide()
	CityArt.label(self, "%s便器 %s" % ["オレンジ" if team == 0 else "ミント", "A" if station_index == 0 else "B"], Vector3(0, 4.05, 1.0), color, 35)

func crossing_fraction(from: Vector3, to: Vector3) -> float:
	var a := to_local(from)
	var b := to_local(to)
	if a.y <= WATER_Y or b.y > WATER_Y or a.y <= b.y:
		return -1.0
	var fraction := (a.y - WATER_Y) / (a.y - b.y)
	var crossing := a.lerp(b, fraction)
	return fraction if Vector2(crossing.x, crossing.z).length() < MOUTH_RADIUS else -1.0

func celebrate() -> void:
	flush_time = 1.6
	swirl.show()

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	flush_time = maxf(0.0, flush_time - delta)
	water.position.y = WATER_Y - sin(flush_time / 1.6 * PI) * 0.18
	water.material_override.set_shader_parameter("flush", minf(flush_time * 3, 1))
	swirl.position.y = water.position.y + 0.05
	if flush_time > 0:
		swirl.rotate_y(delta * 12.0)
	else:
		swirl.hide()
