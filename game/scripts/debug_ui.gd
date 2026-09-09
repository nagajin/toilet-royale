extends CanvasLayer

## デバッグUI。文言やタイミングの判断は main.gd 側に置き、ここは表示に徹する。

const MAX_LOG_LINES := 8

@onready var _phase_label: Label = $PhaseLabel
@onready var _center_label: Label = $CenterLabel
@onready var _log_label: Label = $LogLabel

var _log_lines: PackedStringArray = PackedStringArray()

func set_status(text: String, color: Color = Color.WHITE) -> void:
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", color)

func show_center(text: String, color: Color) -> void:
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_label.visible = true

func hide_center() -> void:
	_center_label.visible = false

func add_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)

func clear_log() -> void:
	_log_lines.clear()
	_log_label.text = ""
