extends Control
## Title screen: ember background, NEW GAME / CONTROLS menu.

const UI := preload("res://scripts/ui.gd")
const Save := preload("res://scripts/save.gd")
const BONE := Color("d9cfb8")
const EMBER := Color("e8892b")

var t := 0.0
var embers: Array = []
var stars: Array = []
var help_panel: Control
var settings_panel: Control
var _starting := false
var hint: Label


func _ready() -> void:
	Music.play("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var vs := get_viewport_rect().size
	for i in 70:
		stars.append({"pos": Vector2(randf() * vs.x, randf() * vs.y * 0.7), "sz": randf_range(0.8, 2.0), "ph": randf() * TAU})
	for i in 90:
		embers.append({
			"pos": Vector2(randf() * vs.x, randf() * vs.y),
			"vel": Vector2(randf_range(-10, 10), randf_range(-50, -15)),
			"sz": randf_range(1.0, 2.8),
			"ph": randf() * TAU,
		})

	# --- main menu ---
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 10)
	center.add_child(menu)

	var title := Label.new()
	title.text = "DARK\nSOULS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", BONE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_constant_override("line_spacing", -8)
	menu.add_child(title)

	var sub := Label.new()
	sub.text = "P R E P A R E   T O   D I E"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(BONE, 0.55))
	menu.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	menu.add_child(gap)

	if Save.has_save():
		var d := Save.read()
		menu.add_child(_make_button("CONTINUE  -  QUEST %d" % int(d.get("quest", 1)), _on_continue))
	menu.add_child(_make_button("NEW GAME", _on_start))
	menu.add_child(_make_button("SETTINGS", func(): settings_panel.visible = true))
	menu.add_child(_make_button("CONTROLS", func(): help_panel.visible = true))

	hint = Label.new()
	hint.text = "TOUCH TO BEGIN YOUR JOURNEY"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(BONE, 0.5))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -14
	add_child(hint)

	_build_help()
	settings_panel = Settings.build_panel(func(): pass)
	add_child(settings_panel)


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.35)))
	b.add_theme_stylebox_override("hover", _style(Color(EMBER, 0.15)))
	b.add_theme_stylebox_override("pressed", _style(Color(EMBER, 0.28)))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0.35)))
	b.pressed.connect(cb)
	return b


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(BONE, 0.18)
	return s


func _build_help() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	help_panel = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var h := Label.new()
	h.text = "CONTROLS"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 34)
	h.add_theme_color_override("font_color", BONE)
	box.add_child(h)

	var lines := [
		["MOVE", "Drag anywhere on the left side"],
		["MAP", "Follow the gold arrow and minimap along the road"],
		["ATTACK", "Tap the sword - auto-aims at nearby foes"],
		["ROLL", "Tap to dodge. Brief invulnerability"],
		["BLOCK", "Hold the shield. Drains stamina"],
		["POTION", "Tap the flask to heal (buy more at the bonfire)"],
		["MAP", "Tap the minimap to open the world map and see your next objective"],
		["GRAB", "When a foe is dazed the attack button turns to GRAB: finish it with an execution"],
		["SKILLS", "Every weapon has its own two skills - unlock them in the shop while holding the weapon"],
		["SWAP", "Tap the weapon icon to switch weapons (sword, cleaver, spear, revolver)"],
		["REVOLVER", "Found in the labyrinth. Uses ammo - buy it at the bonfire or loot it"],
		["KEYBOARD", "WASD  J attack  K roll  L block  E potion  1/2 skills  Q swap  T torch  F command  Z/C look"],
	]
	for l in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var k := Label.new()
		k.text = l[0]
		k.custom_minimum_size = Vector2(130, 0)
		k.add_theme_font_size_override("font_size", 18)
		k.add_theme_color_override("font_color", EMBER)
		var v := Label.new()
		v.text = l[1]
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", BONE)
		row.add_child(k)
		row.add_child(v)
		box.add_child(row)

	var back := _make_button("BACK", func(): help_panel.visible = false)
	box.add_child(back)


func _on_continue() -> void:
	Save.continue_game = true
	_go_to_game()


func _on_start() -> void:
	Save.continue_game = false
	_go_to_game()


## Shows a loading screen for two frames before the (slow) scene switch, so the tap visibly registers instead of hanging.
func _go_to_game() -> void:
	if _starting:
		return
	_starting = true
	var bg := ColorRect.new()
	bg.color = Color("050403")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lbl := Label.new()
	lbl.text = "L O A D I N G"
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", BONE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(lbl)
	add_child(bg)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(delta: float) -> void:
	t += delta
	var vs := get_viewport_rect().size
	for p in embers:
		p.pos += (p.vel + Vector2(sin(t * 1.5 + p.ph) * 14.0, 0)) * delta
		if p.pos.y < -10:
			p.pos = Vector2(randf() * vs.x, vs.y + 10)
	hint.modulate.a = 0.45 + 0.45 * sin(t * 2.0) * sin(t * 2.0)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color("04060f"))
	# night sky: stars + moon
	for st in stars:
		draw_rect(Rect2(st.pos, Vector2(st.sz, st.sz)), Color(0.8, 0.85, 1.0, 0.35 + 0.4 * pow(sin(t * 1.5 + st.ph), 2.0)))
	var moon := Vector2(vs.x * 0.82, vs.y * 0.2)
	for i in 8:
		draw_circle(moon, 150.0 * (1.0 - float(i) / 8.0), Color(0.5, 0.6, 1.0, 0.025))
	draw_circle(moon, 46.0, Color("dfe6ff"))
	draw_circle(moon + Vector2(12, -8), 40.0, Color("04060f", 0.0))
	draw_circle(moon + Vector2(-14, 10), 8.0, Color("b9c3e6"))
	draw_circle(moon + Vector2(16, 16), 5.0, Color("b9c3e6"))

	# firelight glow rising from the bottom
	var flick := 0.92 + sin(t * 8.0) * 0.05 + randf() * 0.03
	for i in 12:
		var k := float(i) / 12.0
		var r := vs.x * 0.7 * (1.0 - k) * flick
		draw_circle(Vector2(vs.x * 0.5, vs.y * 1.05), r, Color(0.5, 0.2, 0.05, 0.035))

	# ruined spires
	var n := 9
	for i in n:
		var x := (i + 0.5) / n * vs.x
		var h := vs.y * (0.25 + 0.3 * absf(sin(i * 12.9898)))
		var w := vs.x / 14.0
		draw_rect(Rect2(x - w / 2.0, vs.y - h, w, h), Color("0a0705"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w / 2.0, vs.y - h), Vector2(x, vs.y - h - w * 1.1), Vector2(x + w / 2.0, vs.y - h)
		]), Color("0a0705"))

	# embers
	for p in embers:
		var a := 0.4 + 0.5 * pow(sin(t * 3.0 + p.ph), 2.0)
		draw_rect(Rect2(p.pos, Vector2(p.sz, p.sz)), Color(EMBER, a))
