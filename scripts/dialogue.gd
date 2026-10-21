extends RefCounted
## Story dialogue box: typewriter text, tap to continue.

const UI := preload("res://scripts/ui.gd")

var root: Control
var active := false
var _name: Label
var _text: Label
var _prompt: Label
var _lines: Array = []
var _idx := 0
var _shown := 0.0
var _cb: Callable
var _t := 0.0
var portrait_for: Callable  # (speaker: String) -> Texture2D or null
var _portrait: TextureRect
var _frame: PanelContainer


func build(layer: CanvasLayer) -> void:
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.018, 0.015, 0.94), UI.GOLD, 2, 22))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 70
	panel.offset_right = -70
	panel.offset_top = -200
	panel.offset_bottom = -24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hb)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.03, 0.06, 0.95), UI.GOLD, 2, 4))
	_frame.custom_minimum_size = Vector2(128, 128)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	_name = UI.label("", 22, Color("f2d27a"))
	vb.add_child(_name)
	_text = UI.label("", 20, UI.BONE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 70)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text)
	_prompt = UI.label("TAP TO CONTINUE", 13, Color(UI.BONE, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_prompt)

	# a transparent full-screen button catches the taps
	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		catcher.add_theme_stylebox_override(s, empty)
	catcher.pressed.connect(advance)
	root.add_child(catcher)


func say(lines: Array, on_done: Callable) -> void:
	_lines = lines
	_idx = 0
	_cb = on_done
	active = true
	root.visible = true
	_show_line()


func _show_line() -> void:
	var l: Array = _lines[_idx]
	_name.text = l[0]
	_name.visible = l[0] != ""
	var tex: Texture2D = null
	if portrait_for.is_valid() and l[0] != "":
		tex = portrait_for.call(l[0])
	_portrait.texture = tex
	_frame.visible = tex != null
	_text.text = l[1]
	_text.visible_characters = 0
	_shown = 0.0


func advance() -> void:
	if not active:
		return
	if _text.visible_characters < _text.text.length():
		_text.visible_characters = _text.text.length()
		return
	_idx += 1
	if _idx >= _lines.size():
		active = false
		root.visible = false
		if _cb.is_valid():
			_cb.call()
	else:
		_show_line()


func process(dt: float) -> void:
	if not active:
		return
	_t += dt
	_shown += dt * 45.0
	if _text.visible_characters < _text.text.length():
		_text.visible_characters = int(_shown)
	_prompt.modulate.a = 0.5 + 0.5 * sin(_t * 4.0) if _text.visible_characters >= _text.text.length() else 0.0
