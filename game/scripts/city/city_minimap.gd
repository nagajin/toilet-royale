extends Control
var game: Node3D

func _process(_delta: float) -> void:
	queue_redraw()

func _point(position: Vector3) -> Vector2:
	return Vector2(size.x / 2 + position.x * (size.x - 16) / 76, size.y / 2 + position.z * (size.y - 16) / 72)

func _draw() -> void:
	if not is_instance_valid(game.world):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("16343e"))
	draw_rect(Rect2(8, size.y / 2, size.x - 16, size.y / 2 - 8), Color("473b33"))
	draw_line(_point(Vector3(0, 0, -34)), _point(Vector3(0, 0, 34)), Color("789393"), 12)
	for z in [-18.0, 0.0, 18.0]:
		draw_line(_point(Vector3(-35, 0, z)), _point(Vector3(35, 0, z)), Color("789393"), 8)
	for toilet: CityToilet in game.world.toilets:
		draw_arc(_point(toilet.position), 5, 0, TAU, 16, CityArt.TEAMS[toilet.team], 3)
	for team in 2:
		var point := _point(game.world.cafeterias[team])
		draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), CityArt.TEAMS[team])
	for actor: CityActor in game.actors:
		if actor.respawn_left > 0:
			continue
		draw_circle(_point(actor.position), 3, Color.WHITE if actor.human else CityArt.TEAMS[actor.team])
	var player: CityActor = game.human
	var direction := Vector2(-sin(player.yaw), -cos(player.yaw))
	draw_line(_point(player.position), _point(player.position) + direction * 12, Color.WHITE, 2)
