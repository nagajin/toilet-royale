extends CanvasLayer

signal start_requested
signal count_changed(count: int)
signal resume_requested
signal lobby_requested

const INK := Color("102c3a")
const CREAM := Color("f4f5df")
const RED := Color("ff675e")
const BLUE := Color("61baff")
var _root: Control
var _red_score: Label
var _blue_score: Label
var _clock: Label
var _center: Label
var _help: Label
var _menu: ColorRect
var _menu_content: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var color := Color("214858") if state == "normal" else Color("326c7b")
		theme.set_stylebox(state, "Button", _panel(color, 12, 2 if state == "focus" else 0))
	_root.theme = theme
	var score_panel := PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", _panel(INK, 20))
	_root.add_child(score_panel)
	score_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	score_panel.offset_left = -315
	score_panel.offset_right = 315
	score_panel.offset_top = 20
	score_panel.offset_bottom = 110
	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation", 30)
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	score_panel.add_child(scores)
	_red_score = _label("あか  0", 34, RED)
	_red_score.custom_minimum_size.x = 190
	scores.add_child(_red_score)
	_clock = _label("01:30", 26)
	_clock.custom_minimum_size.x = 100
	scores.add_child(_clock)
	_blue_score = _label("0  あお", 34, BLUE)
	_blue_score.custom_minimum_size.x = 190
	scores.add_child(_blue_score)
	_center = _label("", 64)
	_center.add_theme_color_override("font_shadow_color", INK)
	_center.add_theme_constant_override("shadow_offset_y", 4)
	_root.add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.offset_left = -520
	_center.offset_right = 520
	_center.offset_top = -60
	_center.offset_bottom = 70
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", _panel(INK, 12))
	_root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -62
	footer.offset_bottom = -16
	_help = _label("", 17)
	footer.add_child(_help)
	_menu = ColorRect.new()
	_menu.color = Color(0.025, 0.08, 0.12, 0.80)
	_root.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	_menu.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_content = VBoxContainer.new()
	_menu_content.custom_minimum_size.x = 660
	_menu_content.add_theme_constant_override("separation", 16)
	centre.add_child(_menu_content)

func _panel(color: Color, radius: int, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = CREAM
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

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
	button.custom_minimum_size.y = 50
	button.pressed.connect(action)
	return button

func _clear_menu() -> void:
	for child in _menu_content.get_children():
		_menu_content.remove_child(child)
		child.queue_free()
	_menu.show()

func show_lobby(count: int) -> void:
	_clear_menu()
	_menu_content.add_child(_label("LOCAL PARTY  /  v0.3", 18, BLUE))
	_menu_content.add_child(_label("TOILET ROYALE", 58))
	_menu_content.add_child(_label("流すか，流されるか．", 25))
	_menu_content.add_child(_label("ボールを押して，相手色の便器へ流し込め！\n90秒勝負 · 5点先取", 21))
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	_menu_content.add_child(choices)
	for index in 4:
		var caption: String = ["1人 練習", "2人 1対1", "3人 2対1", "4人 2対2"][index]
		var button := _button(caption, func(): count_changed.emit(index + 1))
		if index + 1 == count:
			button.add_theme_stylebox_override("normal", _panel(Color("326c7b"), 12, 2))
		choices.add_child(button)
	var controls := ""
	for index in count:
		if index > 0:
			controls += "\n" if index == 2 else "      "
		controls += LocalControls.HELP[index]
	_menu_content.add_child(_label(controls, 20))
	var teams := "P1 → あお便器を狙おう！" if count == 1 else "あか P1%s  →   ←  あお P2%s" % ["・P3" if count >= 3 else "", "・P4" if count == 4 else ""]
	_menu_content.add_child(_label(teams, 20))
	var pads := Input.get_connected_joypads().size()
	_menu_content.add_child(_label("ゲームパッド %d台接続 · 接続順にP1〜P4 · 左スティック + A / ×" % pads, 16, BLUE))
	var start := _button("練習スタート" if count == 1 else "キックオフ！", func(): start_requested.emit())
	_menu_content.add_child(start)
	start.grab_focus()

func hide_menu() -> void:
	_menu.hide()
	if _root.get_viewport().gui_get_focus_owner():
		_root.get_viewport().gui_get_focus_owner().release_focus()

func update_match(state: LocalMatch) -> void:
	_red_score.text = "あか  %d" % state.scores[0]
	_blue_score.text = "%d  あお" % state.scores[1]
	var seconds := ceili(state.time_left)
	_clock.text = "練習" if state.player_count == 1 else "%02d:%02d" % [seconds / 60, seconds % 60]
	_clock.add_theme_color_override("font_color", RED if seconds <= 10 else CREAM)
	var controls := PackedStringArray()
	for index in state.player_count:
		controls.append(LocalControls.HELP[index])
	_help.text = "    ·    ".join(controls) + "    |    Esc 一時停止   R 再試合"
	if state.phase == LocalMatch.Phase.COUNTDOWN:
		_center.text = "%d\nキックオフ！" % maxi(1, ceili(state.phase_left))
		_center.add_theme_font_size_override("font_size", 52)
		_center.add_theme_color_override("font_color", CREAM)
		_center.show()
	elif state.phase != LocalMatch.Phase.GOAL:
		_center.hide()

func show_goal(team: String, color: Color) -> void:
	_center.text = "%s ゴーーール！\nジャーーッ！！" % team
	_center.add_theme_font_size_override("font_size", 52)
	_center.add_theme_color_override("font_color", color)
	_center.show()

func show_pause() -> void:
	_clear_menu()
	_menu_content.add_child(_label("ひと休み", 56))
	_menu_content.add_child(_label("Esc / Start で試合に戻る", 22))
	var resume := _button("試合を続ける", func(): resume_requested.emit())
	_menu_content.add_child(resume)
	_menu_content.add_child(_button("人数選択に戻る", func(): lobby_requested.emit()))
	resume.grab_focus()

func show_result(state: LocalMatch) -> void:
	_clear_menu()
	var winner := state.winner()
	var title := "引き分け！" if winner == -1 else ("あかの勝ち！" if winner == 0 else "あおの勝ち！")
	var color := CREAM if winner == -1 else (RED if winner == 0 else BLUE)
	_menu_content.add_child(_label("FULL TIME", 20, BLUE))
	_menu_content.add_child(_label(title, 58, color))
	_menu_content.add_child(_label("%d   —   %d" % [state.scores[0], state.scores[1]], 64))
	_menu_content.add_child(_label("5点先取！" if state.scores.max() >= LocalMatch.WIN_SCORE else "90秒の勝負，終了！", 22))
	var replay := _button("もう一試合！", func(): start_requested.emit())
	_menu_content.add_child(replay)
	_menu_content.add_child(_button("人数選択に戻る", func(): lobby_requested.emit()))
	replay.grab_focus()
