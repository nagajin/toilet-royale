class_name LocalControls
extends RefCounted

## Separate actions keep the original water prototype's input map intact.
const KEYS := [
	[KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE],
	[KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER],
	[KEY_J, KEY_L, KEY_I, KEY_K, KEY_U],
	[KEY_F, KEY_H, KEY_T, KEY_G, KEY_Y],
]
const ACTIONS := ["left", "right", "up", "down", "jump"]
const HELP := ["P1  WASD + Space", "P2  矢印 + Enter", "P3  IJKL + U", "P4  TFGH + Y"]

static func configure() -> void:
	var pads := Input.get_connected_joypads()
	for player in 4:
		for index in ACTIONS.size():
			var action := "local_p%d_%s" % [player + 1, ACTIONS[index]]
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.25)
			Input.action_release(action)
			InputMap.action_erase_events(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[player][index]
			InputMap.action_add_event(action, key)
			if player >= pads.size():
				continue
			if index == 4:
				var button := InputEventJoypadButton.new()
				button.device = pads[player]
				button.button_index = JOY_BUTTON_A
				InputMap.action_add_event(action, button)
			else:
				var motion := InputEventJoypadMotion.new()
				motion.device = pads[player]
				motion.axis = JOY_AXIS_LEFT_X if index < 2 else JOY_AXIS_LEFT_Y
				motion.axis_value = -1.0 if index % 2 == 0 else 1.0
				InputMap.action_add_event(action, motion)
