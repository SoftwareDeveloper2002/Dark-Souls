extends Node
## The epilogue: after the princess is rescued the story continues as a comic book. Every panel is a little 3D scene (comic_art.gd) rendered once and
## inked by a shader (halftone, outlines, flat colour bands), with caption boxes, speech bubbles and sound-effect lettering on top. Tap to turn the page.

const Art := preload("res://scripts/comic_art.gd")
const UI := preload("res://scripts/ui.gd")
const SHADER := preload("res://assets/shaders/comic.gdshader")

const PAPER := Color("efe5cc")
const INK := Color("120e14")
const CAPTION := Color("f4d884")
const POP := Color("ffd23a")

var g
var _art
var _layer: CanvasLayer
var _page_root: Control
var _paper: ColorRect
var _hint: Label
var _on_done: Callable
var _page := -1
var _shown := 0
var _panels: Array = []   # current page: {holder, ov, vp, data}
var _busy := true
var _credits_t := -1.0
var _credits_ctrl: Control = null
var _t := 0.0
var _done := false


func play(game: Node3D, on_done: Callable) -> void:
	g = game
	_on_done = on_done
	_art = Art.new(g)
	g.add_child(self)
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_paper = ColorRect.new()
	_paper.color = Color.BLACK
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_paper)
	_page_root = Control.new()
	_page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_page_root)
	_hint = Label.new()
	_hint.theme = UI.theme()
	_hint.text = "TAP  >"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", INK)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -120
	_hint.offset_top = -34
	_hint.offset_right = -14
	_hint.offset_bottom = -8
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	_layer.add_child(_hint)
	var skip := UI.button("SKIP", _finish, 110.0)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -126
	skip.offset_top = 10
	skip.offset_right = -12
	skip.offset_bottom = 52
	_layer.add_child(skip)
	Music.play("title")
	_next_page()


func _process(delta: float) -> void:
	_t += delta
	if _hint != null:
		_hint.visible = not _busy and _credits_t < 0.0
		_hint.modulate.a = 0.45 + 0.4 * sin(_t * 4.0)
	if _credits_t >= 0.0 and _credits_ctrl != null:
		_credits_t += delta
		_credits_ctrl.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done or _layer == null:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_J, KEY_RIGHT]:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_advance()


# ------------------------------------------------------------------ the story

func _pages() -> Array:
	return [
		{"num": "PAGE ONE", "title": "THE FALL OF THE CITADEL", "panels": [
			{"scene": "fall", "rect": Rect2(0.0, 0.0, 1.0, 0.52),
				"caps": [["The Dark Citadel fell silent. For the first time in a hundred nights, the storm broke.", "tl", 0.5]],
				"sfx": {"t": "KRAA-BOOOM!", "p": Vector2(0.74, 0.3), "rot": -8.0, "size": 0.2}},
			{"scene": "kneel", "rect": Rect2(0.0, 0.53, 0.37, 0.47),
				"caps": [["The Ashen Knight had lost his name, his order, his king. Only a vow remained.", "bl", 0.95]]},
			{"scene": "face", "rect": Rect2(0.38, 0.53, 0.27, 0.47),
				"bubbles": [{"t": "...You came.", "p": Vector2(0.5, 0.14), "tail": Vector2(0.5, 0.5)}]},
			{"scene": "two", "rect": Rect2(0.66, 0.53, 0.34, 0.47),
				"bubbles": [{"t": "Through fire and ash... for me?", "p": Vector2(0.5, 0.16), "tail": Vector2(0.64, 0.5)}],
				"caps": [["The knight said nothing. Knights of the Order seldom did.", "bl", 0.95]]},
		]},
		{"num": "PAGE TWO", "title": "THE ASHEN THRONE", "panels": [
			{"scene": "crown", "rect": Rect2(0.0, 0.0, 0.56, 0.64),
				"caps": [["But as Elara lifted the Dark Lord's fallen crown, the embers whispered...", "tl", 0.85]],
				"bubbles": [{"t": "EVERY FLAME MUST BE FED.", "p": Vector2(0.74, 0.7), "tail": Vector2(0.55, 0.5), "kind": "ghost"}]},
			{"scene": "cycle", "rect": Rect2(0.57, 0.0, 0.43, 0.31),
				"bubbles": [{"t": "Malakar was a warden once. Like you.", "p": Vector2(0.52, 0.24), "tail": Vector2(0.3, 0.72)}]},
			{"scene": "look", "rect": Rect2(0.57, 0.32, 0.43, 0.32),
				"bubbles": [{"t": "The Throne burns its guardians. And it will choose again.", "p": Vector2(0.5, 0.24), "tail": Vector2(0.3, 0.72)}]},
			{"scene": "vow", "rect": Rect2(0.0, 0.65, 1.0, 0.35),
				"caps": [["The knight did not look away.", "tl", 0.4]],
				"bubbles": [{"t": "Then we end it. Together.", "p": Vector2(0.28, 0.42), "tail": Vector2(0.4, 0.8)}]},
		]},
		{"num": "PAGE THREE", "title": "DAWN OVER ELDORIA", "panels": [
			{"scene": "walk", "rect": Rect2(0.0, 0.0, 1.0, 0.42),
				"caps": [["They took the ash road home, and the forest, once full of hungry eyes, was quiet.", "bl", 0.5]]},
			{"scene": "gate", "rect": Rect2(0.0, 0.43, 0.56, 0.57),
				"caps": [["Eldoria wept, and cheered, and wept again.", "tl", 0.6]],
				"sfx": {"t": "HUZZAH!", "p": Vector2(0.72, 0.22), "rot": 7.0, "size": 0.14}},
			{"scene": "coronation", "rect": Rect2(0.57, 0.43, 0.43, 0.57),
				"bubbles": [{"t": "Arise, Warden of Eldoria.", "p": Vector2(0.5, 0.13), "tail": Vector2(0.68, 0.5)}],
				"caps": [["The kingdom had its protector at last.", "bl", 0.95]]},
		]},
		{"num": "", "title": "", "panels": [
			{"scene": "ember", "rect": Rect2(0.0, 0.0, 1.0, 1.0),
				"caps": [["But embers do not die.", "bl", 0.34], ["They wait.", "br", 0.2]],
				"sfx": {"t": "THE END?", "p": Vector2(0.5, 0.2), "rot": 0.0, "size": 0.14}},
		]},
		{"credits": true},
	]


const CREDITS := [
	["THE ASH ROAD", 44, true],
	["A knight, a princess, and a very long night.", 18, false],
	["", 18, false],
	["MADE WITH FREE ASSETS", 24, true],
	["", 10, false],
	["Characters, wolf, imp and monsters", 16, true],
	["Quaternius - Universal Base Characters, Bestiary, Animated Animals (CC0)", 15, false],
	["", 10, false],
	["Weapons, shields, props, trees and textures", 16, true],
	["Poly Haven artists (CC0)   -   Kenney (CC0)   -   KayKit (CC0)", 15, false],
	["", 10, false],
	["Voices, monsters and ambience", 16, true],
	["EZduzziteh, HaelDB, rubberduck, Darsycho, Wolfgang_, Ecrivain, SketchMan3 (CC0)", 15, false],
	["", 10, false],
	["The anatomical heart", 16, true],
	["Scribe, OpenGameArt (CC0)", 15, false],
	["", 10, false],
	["Terrain", 16, true],
	["Terrain3D by Tokisan Games", 15, false],
	["", 10, false],
	["Made with Godot Engine", 16, true],
	["", 24, false],
	["THANK YOU FOR PLAYING", 30, true],
	["", 18, false],
	["tap to return", 14, false],
]


# ------------------------------------------------------------------ flow

func _advance() -> void:
	if _busy:
		return
	if _credits_t >= 0.0:
		if _credits_t > 2.0:
			_finish()
		return
	if _shown < _panels.size():
		_reveal_next()
	else:
		_next_page()


func _finish() -> void:
	if _done:
		return
	_done = true
	g.get_viewport().disable_3d = false
	_layer.queue_free()
	_layer = null
	if _on_done.is_valid():
		_on_done.call()
	queue_free()


func _next_page() -> void:
	_busy = true
	_page += 1
	var pages := _pages()
	if _page >= pages.size():
		_finish()
		return
	for p in _panels:
		(p.holder as Node).queue_free()
	_panels.clear()
	_shown = 0
	for c in _page_root.get_children():
		c.queue_free()
	var pd: Dictionary = pages[_page]
	if pd.get("credits", false):
		_start_credits()
		return
	_paper.color = PAPER
	# page title card while the panels are built
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(card)
	card.draw.connect(_draw_card.bind(card, str(pd.num), str(pd.title)))
	if _page == 0:
		await get_tree().create_timer(0.1).timeout
	var area := _page_area()
	var gut := get_viewport().get_visible_rect().size.y * 0.012
	var idx := 0
	for panel in pd.panels:
		var r: Rect2 = panel.rect
		var rect := Rect2(area.position + Vector2(r.position.x * area.size.x, r.position.y * area.size.y), Vector2(r.size.x * area.size.x, r.size.y * area.size.y)).grow(-gut)
		_panels.append(_make_panel(panel, rect))
		idx += 1
	await get_tree().create_timer(0.7).timeout
	for p in _panels:
		(p.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if _page == 0 and g != null:
		g.get_viewport().disable_3d = true
	card.queue_free()
	_busy = false
	_reveal_next()


func _page_area() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	var m := s.y * 0.03
	return Rect2(Vector2(m, m), s - Vector2(m, m) * 2.0)


func _make_panel(pd: Dictionary, rect: Rect2) -> Dictionary:
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.pivot_offset = rect.size / 2.0
	holder.visible = false
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(holder)
	var vp := SubViewport.new()
	var vs := (rect.size * 0.85).floor()
	vp.size = Vector2i(maxi(int(vs.x), 64), maxi(int(vs.y), 64))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(vp)
	_art.build(str(pd.scene), vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	tr.material = sm
	holder.add_child(tr)
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.set_meta("reveal", 0.0)
	holder.add_child(ov)
	ov.draw.connect(_draw_overlay.bind(ov, pd))
	return {"holder": holder, "ov": ov, "vp": vp, "data": pd}


func _reveal_next() -> void:
	if _shown >= _panels.size():
		return
	var p: Dictionary = _panels[_shown]
	_shown += 1
	var holder: Control = p.holder
	holder.visible = true
	holder.modulate.a = 0.0
	holder.scale = Vector2.ONE * 1.14
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	g.sfx("swing", -8.0, 1.5)
	var pd: Dictionary = p.data
	if pd.has("sfx"):
		g.sfx("boom", -4.0, 1.1)
		# the page shudders with the impact
		var base: Vector2 = _page_root.position
		var sh := create_tween()
		for i in 6:
			sh.tween_property(_page_root, "position", base + Vector2(randf_range(-9, 9), randf_range(-9, 9)), 0.03)
		sh.tween_property(_page_root, "position", base, 0.04)
	var ov: Control = p.ov
	var rt := create_tween()
	rt.bind_node(ov)
	rt.tween_interval(0.35)
	rt.tween_method(_set_reveal.bind(ov), 0.0, 1.0, 0.3)


func _set_reveal(v: float, ov: Control) -> void:
	if is_instance_valid(ov):
		ov.set_meta("reveal", v)
		ov.queue_redraw()


# ------------------------------------------------------------------ drawing

func _fs() -> int:
	return int(clampf(get_viewport().get_visible_rect().size.y / 33.0, 13.0, 26.0))


func _draw_card(c: Control, num: String, title: String) -> void:
	var font := UI.font()
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), PAPER)
	if num != "":
		c.draw_string(font, Vector2(0, s.y * 0.44), num, HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(INK, 0.6))
		c.draw_string_outline(font, Vector2(0, s.y * 0.54), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, int(s.y * 0.07), 8, INK)
		c.draw_string(font, Vector2(0, s.y * 0.54), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, int(s.y * 0.07), POP)
	else:
		c.draw_string(font, Vector2(0, s.y * 0.5), "EPILOGUE", HORIZONTAL_ALIGNMENT_CENTER, s.x, int(s.y * 0.06), INK)


func _draw_overlay(ov: Control, pd: Dictionary) -> void:
	var reveal: float = float(ov.get_meta("reveal", 0.0))
	var fs := _fs()
	# thick ink border
	ov.draw_rect(Rect2(Vector2.ZERO, ov.size), INK, false, 8.0)
	if reveal <= 0.01:
		return
	var pop := 0.82 + 0.18 * ease(reveal, 0.4) + (0.0 if reveal < 1.0 else 0.0)
	var a := clampf(reveal * 1.4, 0.0, 1.0)
	if pd.has("sfx"):
		_draw_sfx(ov, pd.sfx, a, pop)
	for c in pd.get("caps", []):
		_draw_caption(ov, str(c[0]), str(c[1]), float(c[2]), a, fs)
	for b in pd.get("bubbles", []):
		_draw_bubble(ov, b, a, fs, pop)


func _draw_caption(ov: Control, text: String, anchor: String, wfrac: float, a: float, fs: int) -> void:
	var font := UI.font()
	var maxw := ov.size.x * wfrac - 28.0
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs)
	var box := Vector2(sz.x + 24.0, sz.y + 16.0)
	var pos := Vector2(10, 10)
	if anchor.contains("r"):
		pos.x = ov.size.x - box.x - 10.0
	if anchor.begins_with("b"):
		pos.y = ov.size.y - box.y - 10.0
	ov.draw_rect(Rect2(pos + Vector2(5, 5), box), Color(0, 0, 0, 0.5 * a))
	ov.draw_rect(Rect2(pos, box), Color(CAPTION, a))
	ov.draw_rect(Rect2(pos, box), Color(INK, a), false, 3.0)
	ov.draw_multiline_string(font, pos + Vector2(12, 8 + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, -1, Color(INK, a))


func _draw_bubble(ov: Control, b: Dictionary, a: float, fs: int, pop: float) -> void:
	var font := UI.font()
	var text := str(b.t)
	var ghost: bool = str(b.get("kind", "say")) == "ghost"
	var maxw := ov.size.x * 0.44
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs)
	var box := sz + Vector2(34.0, 24.0)
	var center := Vector2(float(b.p.x) * ov.size.x, float(b.p.y) * ov.size.y)
	center.x = clampf(center.x, box.x * 0.5 + 8.0, ov.size.x - box.x * 0.5 - 8.0)
	center.y = clampf(center.y, box.y * 0.5 + 8.0, ov.size.y - box.y * 0.5 - 8.0)
	var tip := Vector2(float(b.tail.x) * ov.size.x, float(b.tail.y) * ov.size.y)
	var fill := Color(1, 1, 1, a) if not ghost else Color(0.16, 0.04, 0.06, a)
	var txt := Color(INK, a) if not ghost else Color(1.0, 0.45, 0.3, a)
	var line := Color(INK, a) if not ghost else Color(0.9, 0.2, 0.12, a)
	ov.draw_set_transform(center * (1.0 - pop), 0.0, Vector2.ONE * pop)
	# tail first, so the bubble covers its base
	var dir := (tip - center).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var base := center + dir * minf(box.x, box.y) * 0.42
	var tail := PackedVector2Array([base + perp * 15.0, tip, base - perp * 15.0])
	ov.draw_colored_polygon(tail, fill)
	ov.draw_polyline(PackedVector2Array([base + perp * 15.0, tip, base - perp * 15.0]), line, 3.5, true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(box.y * 0.5) if not ghost else 6)
	ov.draw_style_box(sb, Rect2(center - box * 0.5, box))
	var p := center - Vector2(maxw * 0.5, sz.y * 0.5) + Vector2(0, font.get_ascent(fs))
	ov.draw_multiline_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, maxw, fs, -1, txt)
	ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sfx(ov: Control, sfx: Dictionary, a: float, pop: float) -> void:
	var font := UI.font()
	var size := int(float(sfx.get("size", 0.15)) * ov.size.y)
	var pos := Vector2(float(sfx.p.x) * ov.size.x, float(sfx.p.y) * ov.size.y)
	ov.draw_set_transform(pos, deg_to_rad(float(sfx.get("rot", 0.0))), Vector2.ONE * pop)
	var w := ov.size.x
	var text := str(sfx.t)
	ov.draw_string_outline(font, Vector2(-w * 0.5 + 6, 8), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 14, Color(0.7, 0.05, 0.05, a))
	ov.draw_string_outline(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 12, Color(INK, a))
	ov.draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(POP, a))
	ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ credits

func _start_credits() -> void:
	_paper.color = Color.BLACK
	g.get_viewport().disable_3d = true
	_credits_ctrl = Control.new()
	_credits_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(_credits_ctrl)
	_credits_ctrl.draw.connect(_draw_credits)
	_credits_t = 0.0
	_busy = false


func _draw_credits() -> void:
	var c := _credits_ctrl
	var font := UI.font()
	var s := c.size
	var y := s.y - _credits_t * 46.0
	for line in CREDITS:
		var sz := int(line[1])
		if y > -40.0 and y < s.y + 40.0:
			var fade := clampf(minf(y / 120.0, (s.y - y) / 80.0), 0.0, 1.0)
			var col := Color(POP, fade) if line[2] else Color(PAPER, fade * 0.85)
			c.draw_string(font, Vector2(0, y), str(line[0]), HORIZONTAL_ALIGNMENT_CENTER, s.x, sz, col)
		y += float(sz) * 1.7
	if y < -20.0 and _credits_t > 2.0:
		_finish()
