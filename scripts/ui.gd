extends RefCounted
## Shared look for all UI: one serif font, gold-trimmed dark panels, ember buttons.

const BONE := Color("d9cfb8")
const EMBER := Color("e8892b")
const GOLD := Color("8a7a55")

static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Georgia", "Times New Roman", "serif"])
		f.font_weight = 700
		_font = f
	return _font


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 20
	return th


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, margin: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(margin)
	return s


static func panel_style() -> StyleBoxFlat:
	return box(Color(0.03, 0.025, 0.02, 0.96), GOLD, 2, 26)


static func button(text: String, cb: Callable, width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(BONE, 0.3))
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0.4), Color(BONE, 0.2), 1))
	b.add_theme_stylebox_override("hover", box(Color(EMBER, 0.16), EMBER, 1))
	b.add_theme_stylebox_override("pressed", box(Color(EMBER, 0.3), EMBER, 1))
	b.add_theme_stylebox_override("disabled", box(Color(0, 0, 0, 0.3), Color(BONE, 0.08), 1))
	b.pressed.connect(cb)
	return b


static func label(text: String, size: int = 20, col: Color = BONE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## Full-screen dim overlay with a centred panel. Returns {root, box}.
static func overlay(title: String) -> Dictionary:
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, 0.72)
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", panel_style())
	center.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	vb.add_child(label(title, 34, BONE, HORIZONTAL_ALIGNMENT_CENTER))
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	vb.add_child(rule)
	return {"root": root, "box": vb}
