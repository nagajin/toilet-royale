class_name CityWorld
extends Node3D

var toilets: Array[CityToilet] = []
var cafeterias: Array[Vector3] = []
var layout_seed := 0
var building_bounds: Array[AABB] = []

func generate(seed_value: int) -> void:
	layout_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	CityArt.box(self, Vector3(0, -0.5, 0), Vector3(76, 1, 72), Color("91938b"), true).material_override = CityArt.surface(Color("91938b"), 2)
	CityArt.box(self, Vector3(0, 0.007, 0), Vector3(14, 0.01, 70), Color.WHITE).material_override = CityArt.surface(Color("343e42"), 1)
	for z in [-18.0, 0.0, 18.0]:
		CityArt.box(self, Vector3(0, 0.01, z), Vector3(74, 0.015, 12), Color.WHITE).material_override = CityArt.surface(Color("343e42"), 1)
	for z in range(-32, 34, 5):
		CityArt.box(self, Vector3(0, 0.021, z), Vector3(0.13, 0.01, 2), CityArt.CREAM)
	for z in [-18.0, 18.0]:
		for index in range(-4, 5):
			CityArt.box(self, Vector3(index * 1.2, 0.025, z + 4.7), Vector3(0.65, 0.01, 2), CityArt.CREAM)
	for x in [-37.8, 37.8]:
		CityArt.box(self, Vector3(x, 1.1, 0), Vector3(0.4, 2.2, 72), Color("779393"), true)
	for z in [-35.8, 35.8]:
		CityArt.box(self, Vector3(0, 1.1, z), Vector3(76, 2.2, 0.4), Color("779393"), true)
	var palette := [Color("ae8570"), Color("8eaaa0"), Color("c5b798"), Color("99a6ab")]
	for x in [-27.0, -15.0, 15.0, 27.0]:
		for z in [-29.0, -9.0, 9.0, 29.0]:
			_building(Vector3(x, 0, z), rng.randf_range(4.8, 9.0), palette[rng.randi_range(0, 3)], rng.randi_range(0, 3))
	# Both teams get mirrored, open street plazas. A seed changes the locations.
	var offset := rng.randf_range(10.0, 18.0)
	var depth := rng.randf_range(16.5, 19.5)
	for team in 2:
		var sign_z := 1.0 if team == 0 else -1.0
		for side in 2:
			var toilet := CityToilet.new()
			toilet.team = team
			toilet.station_index = side
			toilet.position = Vector3(offset * (-1.0 if side == 0 else 1.0), 0, depth * sign_z)
			toilet.rotation.y = 0.0 if team == 0 else PI
			add_child(toilet)
			toilets.append(toilet)
		var cafe := Vector3(0, 0, sign_z * 30.0)
		cafeterias.append(Vector3(0, 0, sign_z * 26.0))
		_cafeteria(cafe, team)
	_street_details()
	_skyline()

func _building(at: Vector3, height: float, color: Color, sign_index: int) -> void:
	var size := Vector3(8.2, height, 6.2)
	building_bounds.append(AABB(at + Vector3(-4.1, 0, -3.1), size))
	CityArt.box(self, at + Vector3(0, height / 2, 0), size, color, true).material_override = CityArt.surface(color, 3 if sign_index == 1 else 0)
	CityArt.box(self, at + Vector3(0, 0.28, 0), Vector3(8.3, 0.55, 6.3), Color("747e7a")).material_override = CityArt.surface(Color("747e7a"), 2)
	CityArt.box(self, at + Vector3(0, height + 0.05, 0), Vector3(8.4, 0.14, 6.4), Color("616969"))
	for x in [-4.1, 4.1]:
		CityArt.box(self, at + Vector3(x, height + 0.3, 0), Vector3(0.15, 0.5, 6.4), color.lightened(0.12))
	for z in [-3.1, 3.1]:
		CityArt.box(self, at + Vector3(0, height + 0.3, z), Vector3(8.2, 0.5, 0.15), color.lightened(0.12))
	CityArt.rounded_box(self, at + Vector3(-2, height + 0.35, 0.5), Vector3(1.4, 0.55, 1), 0.06, CityArt.metal(Color("a1aaa5"), 0.55))
	CityArt.cylinder(self, at + Vector3(-2, height + 0.65, 0.5), 0.38, 0.08, Color("424e51"))
	for side in [-1.0, 1.0]:
		for floor_index in range(1, int((height - 0.9) / 2.25)):
			for z in [-1.6, 1.6]:
				var centre := at + Vector3(side * 4.15, floor_index * 2.25 + 1.65, z)
				CityArt.box(self, centre, Vector3(0.1, 1.5, 1.65), Color("536361"))
				CityArt.box(self, centre + Vector3(side * 0.065, 0, 0), Vector3(0.035, 1.32, 1.45), Color.WHITE).material_override = CityArt.metal(Color("56747c"), 0.2)
				CityArt.box(self, centre + Vector3(side * 0.1, 0, 0), Vector3(0.04, 1.34, 0.05), Color("c3c5b8"))
				CityArt.box(self, centre + Vector3(side * 0.14, -0.7, 0), Vector3(0.35, 0.09, 1.8), Color("c0bcab"))
	for direction in [-1.0, 1.0]:
		for floor_index in range(1, int((height - 0.9) / 2.25)):
			for x in [-2.5, 0.0, 2.5]:
				_window(at + Vector3(x, floor_index * 2.25 + 1.65, direction * 3.14), direction, Vector2(1.45, 1.35))
		var front := Node3D.new()
		front.position = at
		front.rotation.y = 0 if direction > 0 else PI
		add_child(front)
		CityArt.box(front, Vector3(0, 1.36, 3.14), Vector3(6.6, 2.6, 0.06), Color("263739"))
		for x in [-2.0, 0.0, 2.0]:
			CityArt.box(front, Vector3(x, 1.3, 3.19), Vector3(1.8, 2.35, 0.045), Color("354e52")).material_override = CityArt.metal(Color("405557"), 0.22)
			CityArt.box(front, Vector3(x - 0.92, 1.3, 3.23), Vector3(0.07, 2.6, 0.1), Color("c3bda8"))
			CityArt.box(front, Vector3(x, 0.75, 3.25), Vector3(1.8, 0.07, 0.08), Color("c3bda8"))
		CityArt.box(front, Vector3(0.6, 1.15, 3.31), Vector3(0.05, 0.38, 0.09), Color.WHITE).material_override = CityArt.metal()
		var awning_color: Color = [Color("48675d"), Color("965f49"), Color("536c46"), Color("526a7d")][sign_index]
		for stripe in 14:
			var awning := CityArt.box(front, Vector3(-3.25 + stripe * 0.5, 2.95, 3.66), Vector3(0.5, 0.09, 1.35), awning_color if stripe % 2 == 0 else Color("d5cbb4"))
			awning.rotation.x = 0.18
			CityArt.box(front, Vector3(-3.25 + stripe * 0.5, 2.69, 4.3), Vector3(0.5, 0.28, 0.06), awning_color if stripe % 2 == 0 else Color("d5cbb4"))
		CityArt.box(front, Vector3(0, 3.42, 3.2), Vector3(6.9, 0.6, 0.12), Color("303e3c"))
		var sign_node := CityArt.label(self, ["喫茶  KOMOREBI", "BAKERY  こむぎ", "八百屋  あおば", "LAUNDRY  24"][sign_index], at + Vector3(0, 3.43, direction * 3.29), CityArt.CREAM, 27)
		sign_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sign_node.rotation.y = 0 if direction > 0 else PI
		sign_node.outline_size = 0
		CityArt.cylinder(front, Vector3(3.82, height * 0.5, 3.25), 0.065, height, Color("586767")).material_override = CityArt.metal(Color("667773"), 0.6)
		CityArt.rounded_box(front, Vector3(-3.85, 0.37, 3.65), Vector3(0.48, 0.72, 0.65), 0.05, CityArt.surface(Color("986f53")))
		for leaf in 4:
			var plant := CityArt.sphere(front, Vector3(-3.85 + sin(leaf * 2) * 0.15, 0.9, 3.65 + cos(leaf * 2) * 0.15), 0.23, Color("456c40"))
			plant.scale.y = 1.7
		CityArt.box(front, Vector3(3.72, 1.1, 3.61), Vector3(0.64, 1.9, 0.72), Color("b6c2bc"))
		CityArt.box(front, Vector3(3.72, 1.4, 3.99), Vector3(0.5, 0.72, 0.025), Color("283e43"))
		for drink in 3:
			CityArt.cylinder(front, Vector3(3.56 + drink * 0.16, 1.38, 4.02), 0.045, 0.22, CityArt.TEAMS[drink % 2])

func _window(at: Vector3, direction: float, size: Vector2) -> void:
	CityArt.box(self, at, Vector3(size.x + 0.2, size.y + 0.2, 0.12), Color("536361"))
	CityArt.box(self, at + Vector3(0, 0, direction * 0.075), Vector3(size.x, size.y, 0.03), Color.WHITE).material_override = CityArt.metal(Color("56747c"), 0.19)
	CityArt.box(self, at + Vector3(0, 0, direction * 0.105), Vector3(0.045, size.y, 0.06), Color("c3c5b8"))
	CityArt.box(self, at + Vector3(0, -size.y * 0.5, direction * 0.13), Vector3(size.x + 0.3, 0.09, 0.35), Color("c0bcab"))

func _cafeteria(at: Vector3, team: int) -> void:
	var sign_z := 1.0 if team == 0 else -1.0
	var color: Color = CityArt.TEAMS[team]
	CityArt.box(self, at + Vector3(0, 1.8, sign_z * 1.7), Vector3(9, 3.6, 0.5), color, true).material_override = CityArt.surface(Color("d1c4a6"), 2)
	CityArt.box(self, at + Vector3(0, 3.7, 0), Vector3(10, 0.3, 5), Color("425555"))
	CityArt.box(self, at + Vector3(0, 3.4, -sign_z * 2.45), Vector3(10, 0.42, 0.16), color)
	for x in [-4.3, 4.3]:
		CityArt.box(self, at + Vector3(x, 1.8, 0), Vector3(0.22, 3.6, 4.4), color, true)
	CityArt.box(self, at + Vector3(0, 0.65, -sign_z * 0.9), Vector3(7, 1.3, 1.1), Color("765339"), true).material_override = CityArt.surface(Color("765339"), 3)
	CityArt.rounded_box(self, at + Vector3(0, 1.32, -sign_z * 0.9), Vector3(7.2, 0.12, 1.25), 0.045, CityArt.metal(Color("bbc5bd"), 0.38))
	for x in [-2.0, 0.0, 2.0]:
		CityArt.cylinder(self, at + Vector3(x, 1.33, -sign_z * 0.9), 0.4, 0.08, CityArt.CREAM)
		CityArt.sphere(self, at + Vector3(x, 1.46, -sign_z * 0.9), 0.23, Color("fff3df"))
		CityArt.sphere(self, at + Vector3(x + 0.24, 1.45, -sign_z * 0.96), 0.1, Color("567839"))
		CityArt.cylinder(self, at + Vector3(x + 0.64, 1.5, -sign_z * 0.9), 0.11, 0.32, CityArt.CREAM)
		CityArt.cylinder(self, at + Vector3(x, 2.95, 0), 0.3, 0.1, Color("374e4b"))
		CityArt.cylinder(self, at + Vector3(x, 2.9, 0), 0.24, 0.035, Color("ffe2a2"))
	var menu_at := at + Vector3(0, 2.45, sign_z * 1.4)
	CityArt.box(self, menu_at, Vector3(4.7, 1.3, 0.08), Color("304b42"))
	var food_sign := CityArt.label(self, "本日の定食     からあげ・カレー\nたべて，元気に！", menu_at - Vector3(0, 0, sign_z * 0.06), CityArt.CREAM, 23)
	food_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	food_sign.rotation.y = PI if team == 0 else 0
	food_sign.outline_size = 0
	CityArt.label(self, "オレンジ食堂" if team == 0 else "ミント食堂", at + Vector3(0, 4.55, 0), color, 52)
	CityArt.ring(self, cafeterias[team] + Vector3.UP * 0.025, 2.7, 0.045, CityArt.material(color), 0.3)

func _street_details() -> void:
	for x in [-7.15, 7.15]:
		for z in [-29.0, -9.0, 9.0, 29.0]:
			CityArt.box(self, Vector3(x, 0.075, z), Vector3(0.25, 0.15, 7.8), Color("aaa99b"))
			CityArt.box(self, Vector3(x + signf(x) * 0.35, 0.023, z), Vector3(0.45, 0.015, 7.8), Color("b9a75a"))
	for z in [-18.0, 0.0, 18.0]:
		for x in [-5.8, 5.8]:
			var grate := Vector3(x, 0.027, z + 5.2)
			CityArt.box(self, grate, Vector3(0.6, 0.015, 1.3), Color("252e30"))
			for bar in 9:
				CityArt.box(self, grate + Vector3(0, 0.006, -0.55 + bar * 0.14), Vector3(0.58, 0.01, 0.045), Color("6d7976"))
		CityArt.cylinder(self, Vector3(1.8, 0.028, z), 0.53, 0.012, Color("535c5b"))
		CityArt.ring(self, Vector3(1.8, 0.037, z), 0.45, 0.012, CityArt.metal(Color("727d77")), 0.3)
	for x in [-8.5, 8.5]:
		for z in [-28.0, -8.0, 8.0, 28.0]:
			_lamp(Vector3(x, 0, z))
	for x in [-33.0, 33.0]:
		for z in [-18.0, 0.0, 18.0]:
			_tree(Vector3(x, 0, z))
			_bench(Vector3(x, 0, z + 3))
	# Low railings define the blocks without closing the central routes.
	for x in [-9.0, 9.0]:
		for z in [-8.0, 8.0]:
			for offset in [-2.0, 0.0, 2.0]:
				CityArt.cylinder(self, Vector3(x, 0.55, z + offset), 0.045, 1.1, Color("465c58"))
			CityArt.box(self, Vector3(x, 0.95, z), Vector3(0.07, 0.08, 4.1), Color("465c58"))
			CityArt.box(self, Vector3(x, 0.4, z), Vector3(0.05, 0.06, 4.1), Color("465c58"))

func _lamp(at: Vector3) -> void:
	CityArt.cylinder(self, at + Vector3.UP * 2.7, 0.065, 5.4, Color("384b4a"))
	CityArt.cylinder(self, at + Vector3.UP * 0.24, 0.16, 0.48, Color("384b4a"))
	CityArt.box(self, at + Vector3(-signf(at.x) * 0.45, 5.35, 0), Vector3(1.0, 0.08, 0.1), Color("384b4a"))
	CityArt.rounded_box(self, at + Vector3(-signf(at.x) * 0.85, 5.3, 0), Vector3(0.65, 0.16, 0.35), 0.07, CityArt.metal(Color("65716c")))
	var light_mat := CityArt.material(Color("fff0c8")).duplicate() as StandardMaterial3D
	light_mat.emission_enabled = true
	light_mat.emission = Color("ffdda3")
	CityArt.box(self, at + Vector3(-signf(at.x) * 0.85, 5.2, 0), Vector3(0.5, 0.025, 0.25), Color.WHITE).material_override = light_mat
	CityArt.box(self, at + Vector3(0, 3.65, 0.12), Vector3(0.62, 1.15, 0.035), CityArt.TEAMS[0 if at.z > 0 else 1])
	var banner := CityArt.label(self, "商\n店\n街", at + Vector3(0, 3.65, 0.15), CityArt.CREAM, 20)
	banner.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	banner.outline_size = 0

func _tree(at: Vector3) -> void:
	CityArt.cylinder(self, at + Vector3.UP * 0.25, 1.1, 0.5, Color("797e6e"))
	CityArt.cylinder(self, at + Vector3.UP * 0.51, 0.99, 0.03, Color("473f2f"))
	CityArt.cylinder(self, at + Vector3.UP * 1.8, 0.14, 3.3, Color("655444")).material_override = CityArt.surface(Color("655444"))
	for index in 9:
		var angle := index * 2.4
		var location := at + Vector3(cos(angle) * 0.9, 3.5 + sin(index * 1.4) * 0.65, sin(angle) * 0.9)
		var crown := CityArt.sphere(self, location, 1.0, Color("456645").lightened(float(index % 3) * 0.05))
		crown.scale = Vector3(1, 0.8, 1)
		crown.material_override = CityArt.surface(Color("456645").lightened(float(index % 3) * 0.05))

func _bench(at: Vector3) -> void:
	for x in [-0.75, 0.75]:
		CityArt.box(self, at + Vector3(x, 0.3, 0), Vector3(0.1, 0.6, 0.6), Color("354d47"))
	for index in 4:
		CityArt.box(self, at + Vector3(0, 0.61, -0.25 + index * 0.16), Vector3(2.1, 0.08, 0.13), Color("997451"))
	for index in 3:
		CityArt.box(self, at + Vector3(0, 0.86 + index * 0.15, 0.28), Vector3(2.1, 0.11, 0.08), Color("997451"))

func _skyline() -> void:
	# Scenery uses its own seed so decorative changes cannot move scoring objectives.
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 9201
	for index in 32:
		var angle := float(index) / 32 * TAU
		var at := Vector3(sin(angle) * 66, 0, cos(angle) * 64)
		var height := rng.randf_range(9, 23)
		CityArt.box(self, at + Vector3.UP * height * 0.5, Vector3(8, height, 8), Color("9ca9a8").darkened(rng.randf_range(0, 0.15)))
		for floor_index in range(2, int(height / 2.8)):
			CityArt.box(self, at + Vector3(0, floor_index * 2.8, -4.02 * signf(at.z)), Vector3(6.8, 0.9, 0.035), Color("657f84"))
