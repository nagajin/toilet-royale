extends CanvasLayer

var game: Node3D
var root: Control
var score_label: Label
var timer_label: Label
var ammo_label: Label
var status_label: Label
var prompt: Label
var notice: Label
var notice_panel: PanelContainer
var objectives: Label
var dirt_label: Label
var crosshair: Label
var menu: ColorRect
var menu_box: VBoxContainer
var minimap: Control
var heading: PanelContainer
const INK := Color("142f3b")
const CREAM := Color("fff2d5")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		theme.set_stylebox(state, "Button", _style(INK if state == "normal" else Color("326474"), 12, 2 if state == "focus" else 0))
	root.theme = theme
	heading = _panel(Vector2(24, 20), Vector2(260, 66))
	heading.add_child(_label("TOILET ROYALE\n街を汚せ，敵を流せ！", 19))
	var scoreboard := _panel(Vector2(-220, 20), Vector2(440, 66), Control.PRESET_CENTER_TOP)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	scoreboard.add_child(row)
	score_label = _label("", 25)
	row.add_child(score_label)
	timer_label = _label("03:00", 25)
	row.add_child(timer_label)
	objectives = _label("", 19)
	root.add_child(objectives)
	_place(objectives, Control.PRESET_CENTER_TOP, Vector2(-350, 94), Vector2(700, 34))
	objectives.add_theme_color_override("font_shadow_color", INK)
	objectives.add_theme_constant_override("shadow_offset_y", 2)
	var inventory := _panel(Vector2(24, -141), Vector2(375, 78), Control.PRESET_BOTTOM_LEFT)
	var items := VBoxContainer.new()
	inventory.add_child(items)
	ammo_label = _label("", 24)
	items.add_child(ammo_label)
	status_label = _label("", 15)
	items.add_child(status_label)
	var map_panel := _panel(Vector2(-209, 20), Vector2(185, 218), Control.PRESET_TOP_RIGHT)
	var map_box := VBoxContainer.new()
	map_panel.add_child(map_box)
	map_box.add_child(_label("○ 便器   ■ 食堂", 16))
	minimap = load("res://scripts/city/city_minimap.gd").new()
	minimap.game = game
	minimap.custom_minimum_size = Vector2(159, 148)
	map_box.add_child(minimap)
	dirt_label = _label("", 14)
	map_box.add_child(dirt_label)
	var footer := _panel(Vector2(24, -56), Vector2(-48, 40), Control.PRESET_BOTTOM_WIDE)
	footer.add_child(_label("WASD 移動   マウス 視点   左 投げる / 右 狙う   Q ブラシ   E 食事   F 水流   V 視点   Esc 休憩", 14))
	crosshair = _label("+", 32)
	root.add_child(crosshair)
	_place(crosshair, Control.PRESET_CENTER, Vector2(-20, -20), Vector2(40, 40))
	crosshair.add_theme_color_override("font_shadow_color", INK)
	crosshair.add_theme_constant_override("shadow_offset_y", 2)
	prompt = _label("", 26)
	root.add_child(prompt)
	_place(prompt, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -170), Vector2(800, 80))
	prompt.add_theme_color_override("font_shadow_color", INK)
	prompt.add_theme_constant_override("shadow_offset_y", 3)
	notice_panel = _panel(Vector2(-350, 138), Vector2(700, 40), Control.PRESET_CENTER_TOP)
	notice = _label("", 19)
	notice_panel.add_child(notice)
	notice.add_theme_color_override("font_shadow_color", INK)
	notice.add_theme_constant_override("shadow_offset_y", 3)
	menu = ColorRect.new()
	menu.color = Color(0.025, 0.07, 0.1, 0.88)
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	menu.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box = VBoxContainer.new()
	menu_box.custom_minimum_size.x = 670
	menu_box.add_theme_constant_override("separation", 16)
	centre.add_child(menu_box)

func _style(color: Color, radius: int, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = CREAM
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _place(node: Control, preset: int, offset: Vector2, extent: Vector2) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = offset.x
	node.offset_top = offset.y
	node.offset_right = offset.x + extent.x
	node.offset_bottom = offset.y + extent.y

func _panel(offset: Vector2, extent: Vector2, preset: int = Control.PRESET_TOP_LEFT) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	_place(panel, preset, offset, extent)
	panel.add_theme_stylebox_override("panel", _style(INK, 12))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _label(text: String, size: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	menu_box.add_child(button)
	return button

func show_menu(mode: String) -> void:
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	menu.show()
	var primary: Button
	if mode == "pause":
		menu_box.add_child(_label("ひと休み", 52))
		menu_box.add_child(_label("Escでも試合に戻れます", 22))
		primary = _button("街に戻る", game.resume_match)
		_button("同じ街でやり直す", func(): game.start_match())
		_button("新しい街を生成する", func(): game.start_match(true))
		_button("効果音：%s" % ("オフ" if CityFeedback.muted else "オン"), func(): game.toggle_sound(); show_menu("pause"))
	elif mode == "result":
		menu_box.add_child(_label("試合終了！", 50))
		var result := "引き分け！" if game.scores[0] == game.scores[1] else ("オレンジの勝ち！" if game.scores[0] > game.scores[1] else "ミントの勝ち！")
		menu_box.add_child(_label(result, 35))
		menu_box.add_child(_label("%d   —   %d" % [game.scores[0], game.scores[1]], 62))
		primary = _button("もう一試合！", func(): game.start_match())
		_button("新しい街で遊ぶ", func(): game.start_match(true))
	else:
		menu_box.add_child(_label("TOILET ROYALE", 58))
		menu_box.add_child(_label("街を汚せ，敵を流せ！", 29, CityArt.TEAMS[0]))
		menu_box.add_child(_label("敵の便器にうんこを流して，1ポイント．", 25))
		menu_box.add_child(_label("投げて道を汚す → 滑る道はブラシで清掃\n弾切れなら自陣の食堂へ．便器の水流で敵を撃退！", 22))
		menu_box.add_child(_label("WASD 移動 · マウス 視点 · 左クリック 投げる\n右クリック 狙う · Q ブラシ · E 食事 · F 水流\nSpace ジャンプ · Shift 走る · V 一人称 / 三人称", 19))
		menu_box.add_child(_label("自分＋味方CPU vs 敵CPU 2体 / 3分間", 19, CityArt.TEAMS[1]))
		primary = _button("街へ出る！", func(): game.start_match())
		_button("新しい街で始める", func(): game.start_match(true))
	primary.grab_focus()

func hide_menu() -> void:
	menu.hide()
	if root.get_viewport().gui_get_focus_owner():
		root.get_viewport().gui_get_focus_owner().release_focus()

func update_hud() -> void:
	heading.visible = root.get_viewport_rect().size.x >= 1100
	var player: CityActor = game.human
	var remaining := ceili(game.seconds_left)
	score_label.text = "橙 %d   —   %d ミント" % [game.scores[0], game.scores[1]]
	timer_label.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	ammo_label.text = "うんこ  %s  %d / 6" % ["●".repeat(player.ammo) + "○".repeat(6 - player.ammo), player.ammo]
	status_label.text = "滑る！ Qのブラシで足元を清掃" if player.slippery else "左クリックで投げる · 右クリックで着地点を確認"
	if player.cleaning:
		status_label.text = "ブラシで清掃中！ 近くの敵も押し出せる"
	status_label.add_theme_color_override("font_color", CityArt.TEAMS[0] if player.slippery else CREAM)
	var enemy_distance := INF
	for toilet: CityToilet in game.world.toilets:
		if toilet.team != player.team:
			enemy_distance = minf(enemy_distance, player.position.distance_to(toilet.position))
	objectives.text = "ミント色の敵便器へ流し込め！  最寄り %dm" % roundi(enemy_distance)
	var counts: Array[int] = game.grime.territory_counts()
	dirt_label.text = "汚れ  自陣 %d / 敵陣 %d" % [counts[0], counts[1]]
	prompt.text = ""
	if player.respawn_left > 0:
		prompt.text = "流された！  %d秒で自陣へ復帰" % ceili(player.respawn_left)
	elif game.can_eat(player):
		prompt.text = "E 長押しで食事・うんこ補給" if player.ammo < 6 else "自陣の食堂 · おなかいっぱい！"
		if player.eat_progress > 0:
			prompt.text = "もぐもぐ…  %d%%" % int(player.eat_progress / 1.5 * 100)
	else:
		var toilet: CityToilet = game.nearby_toilet(player)
		if toilet:
			prompt.text = "F 水流で近くの敵を流す" if toilet.cooldown <= 0 else "水流の準備中… %d秒" % ceili(toilet.cooldown)
		elif player.ammo == 0:
			prompt.text = "うんこ切れ！ 自陣の食堂へ戻ろう"
	crosshair.visible = game.active and player.respawn_left <= 0
	notice_panel.visible = game._toast_left > 0
	notice.text = game._toast_text if game._toast_left > 0 else ""
	notice.add_theme_color_override("font_color", game._toast_color)
