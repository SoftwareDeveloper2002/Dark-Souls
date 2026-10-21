extends Control
## Full-screen world map, opened by tapping the minimap (or pressing M): forest-and-mountain relief sampled from the terrain, the road
## with how far you have travelled, every quest site (done / current / ahead), the hero, and the current objective with its distance.
## Drag to look around, +/- to zoom, the target button recentres on the hero.

const World := preload("res://scripts/world.gd")
const UI := preload("res://scripts/ui.gd")
const BONE := Color("d9cfb8")
const GOLD := Color("8a7a55")
const EMBER := Color("e8892b")
const STEP := 8.0

var g  # the game node
var _tex: ImageTexture
var _origin := Vector2.ZERO        # world position of the relief image's top-left corner
var _img_size := Vector2.ZERO      # in metres
var _centre := Vector2.ZERO        # world position at the middle of the screen
var _ms := 0.5                     # pixels per metre
var _drag := -1
var _t := 0.0
var _closing := false


func setup(game: Node3D) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Samples the terrain once into a shaded relief image (done behind the loading screen).
func build_relief() -> void:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in World.ROUTE:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	mn -= Vector2(180, 180)
	mx += Vector2(180, 180)
	_origin = mn
	_img_size = mx - mn
	var w := int(_img_size.x / STEP)
	var h := int(_img_size.y / STEP)
	var hs := PackedFloat32Array()
	hs.resize((w + 2) * (h + 2))
	var ok := PackedByteArray()
	ok.resize((w + 2) * (h + 2))
	for z in h + 2:
		for x in w + 2:
			var p := _origin + Vector2(x, z) * STEP
			var v: float = g.terrain.data.get_height(Vector3(p.x, 0, p.y))
			var good := not is_nan(v) and absf(v) > 0.0001
			hs[z * (w + 2) + x] = v if good else 0.0
			ok[z * (w + 2) + x] = 1 if good else 0
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for z in h:
		for x in w:
			var i := (z + 1) * (w + 2) + (x + 1)
			if ok[i] == 0:
				img.set_pixel(x, z, Color(0.02, 0.03, 0.04))
				continue
			var hh := hs[i]
			var dx := hs[i + 1] - hs[i - 1]
			var dz := hs[i + w + 2] - hs[i - w - 2]
			var slope := Vector2(dx, dz).length() / (2.0 * STEP)
			var shade := clampf(0.55 - dx * 0.012 - dz * 0.01, 0.2, 1.0)
			var forest := Color(0.1, 0.24, 0.13).lerp(Color(0.2, 0.28, 0.14), clampf((hh - 40.0) / 160.0, 0.0, 1.0))
			var rock := Color(0.42, 0.42, 0.4)
			var col := forest.lerp(rock, clampf((slope - 0.45) * 2.2, 0.0, 1.0))
			img.set_pixel(x, z, Color(col.r * shade * 1.6, col.g * shade * 1.6, col.b * shade * 1.6))
	_tex = ImageTexture.create_from_image(img)


func open() -> void:
	_centre = g.p_pos
	_ms = 0.45
	visible = true
	_closing = false
	queue_redraw()


func close() -> void:
	visible = false


func _process(dt: float) -> void:
	if visible:
		_t += dt
		queue_redraw()


func _s(world: Vector2) -> Vector2:
	return size * 0.5 + (world - _centre) * _ms


func _buttons() -> Dictionary:
	var s := size
	return {
		"close": Rect2(s.x - 74, 18, 56, 56),
		"zoom_in": Rect2(s.x - 74, s.y - 230, 56, 56),
		"zoom_out": Rect2(s.x - 74, s.y - 164, 56, 56),
		"centre": Rect2(s.x - 74, s.y - 98, 56, 56),
	}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos: Vector2 = event.position
		var pressed: bool = event.pressed
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and pressed:
				_ms = clampf(_ms * 1.15, 0.12, 2.0)
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and pressed:
				_ms = clampf(_ms / 1.15, 0.12, 2.0)
				return
			if event.button_index != MOUSE_BUTTON_LEFT:
				return
		if pressed:
			var b := _buttons()
			for k in b:
				if (b[k] as Rect2).grow(6.0).has_point(pos):
					match k:
						"close": g._toggle_map()
						"zoom_in": _ms = clampf(_ms * 1.35, 0.12, 2.0)
						"zoom_out": _ms = clampf(_ms / 1.35, 0.12, 2.0)
						"centre": _centre = g.p_pos
					accept_event()
					return
			_drag = event.index if event is InputEventScreenTouch else 0
		else:
			_drag = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == _drag:
		_centre -= event.relative / _ms
		accept_event()
	elif event is InputEventMouseMotion and _drag == 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_centre -= event.relative / _ms
		accept_event()


func _text(txt: String, pos: Vector2, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	var f := UI.font()
	draw_string_outline(f, pos, txt, align, w, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(f, pos, txt, align, w, fs, col)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.025, 0.03, 1.0))
	if _tex != null:
		draw_texture_rect(_tex, Rect2(_s(_origin), _img_size * _ms), false, Color(0.9, 0.95, 0.9))
	# the road: travelled part bright, the rest dim
	var near := 0
	var best := 1e18
	for i in World.ROUTE.size():
		var d: float = g.p_pos.distance_squared_to(World.ROUTE[i])
		if d < best:
			best = d
			near = i
	var prev := Vector2.ZERO
	for i in World.ROUTE.size():
		var cur := _s(World.ROUTE[i])
		if i > 0:
			var done := i <= near
			draw_line(prev, cur, Color(0.95, 0.85, 0.5, 0.95) if done else Color(0.7, 0.62, 0.45, 0.55), 5.0 if done else 3.0, true)
		prev = cur
	for tp in g.structures.tunnel_pts:
		draw_circle(_s(tp), maxf(2.0, 3.0 * _ms * 2.0), Color(0.3, 0.7, 0.75, 0.9))
	# quest sites
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	for n in range(1, 41):
		var p := _s(World.site(n))
		if p.x < -40 or p.y < -40 or p.x > s.x + 40 or p.y > s.y + 40:
			continue
		var boss := n % 10 == 0
		var r := 9.0 if not boss else 13.0
		if n < g.quest_n:
			draw_circle(p, r, Color(0.2, 0.35, 0.2, 0.9))
			draw_arc(p, r, 0, TAU, 20, Color(0.55, 0.85, 0.5), 2.0, true)
			draw_polyline(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(-1, 4), p + Vector2(5, -4)]), Color(0.85, 1.0, 0.8), 2.5, true)
		elif n == g.quest_n:
			draw_circle(p, r + 8.0 + pulse * 6.0, Color(0.95, 0.8, 0.3, 0.22))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r - 4), p + Vector2(r + 4, 0), p + Vector2(0, r + 4), p + Vector2(-r - 4, 0)]), Color("f2d27a"))
			_text("QUEST %d" % n, p + Vector2(-40, -r - 14), 15, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, 80)
		else:
			var col := Color(0.8, 0.3, 0.25, 0.85) if boss else Color(0.7, 0.62, 0.45, 0.8)
			draw_arc(p, r, 0, TAU, 20, col, 2.5, true)
			if boss:
				draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), col, 2.5, true)
				draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), col, 2.5, true)
		if _ms > 0.3 or boss:
			_text(str(n), p + Vector2(-12, r + 16), 12, Color(BONE, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 24)
	# found secret emblems stay marked
	for ep in g.emblems.found_positions():
		var e := _s(ep)
		draw_circle(e, 6.0, Color("e8c25a"))
		draw_arc(e, 8.0, 0, TAU, 16, Color(1, 1, 0.8, 0.9), 1.5, true)
	# the hero
	var hp := _s(g.p_pos)
	draw_circle(hp, 14.0 + pulse * 5.0, Color(0.5, 0.75, 1.0, 0.22))
	var fa: float = g.p_face
	var tip := hp + Vector2(cos(fa), sin(fa)) * 13.0
	var l := hp + Vector2(cos(fa + 2.5), sin(fa + 2.5)) * 10.0
	var r2 := hp + Vector2(cos(fa - 2.5), sin(fa - 2.5)) * 10.0
	draw_colored_polygon(PackedVector2Array([tip, l, r2]), Color("e8f0ff"))
	draw_polyline(PackedVector2Array([tip, l, r2, tip]), Color(0.1, 0.2, 0.4), 2.0, true)
	_text("YOU", hp + Vector2(-30, 30), 13, Color("bcd4ff"), HORIZONTAL_ALIGNMENT_CENTER, 60)
	# objective panel
	var px := 22.0
	var py := 18.0
	draw_rect(Rect2(px, py, 440, 118), Color(0, 0, 0, 0.78))
	draw_rect(Rect2(px, py, 440, 118), GOLD, false, 2.0)
	_text("WORLD MAP", Vector2(px + 16, py + 28), 18, Color("f2d27a"))
	if not g.q.is_empty() and g.has_weapon:
		_text("QUEST %d / 40   %s" % [g.quest_n, str(g.q.title).to_upper()], Vector2(px + 16, py + 54), 15, BONE)
		var ql: String = g._quest_line()
		if ql != "":
			_text(ql, Vector2(px + 16, py + 76), 14, Color(BONE, 0.85))
		var dist := int(g.p_pos.distance_to(g.site))
		var dir: Vector2 = g.site - g.p_pos
		var compass: String = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][int(round(dir.angle() / (TAU / 8.0))) & 7]
		_text("Objective: %d m  %s" % [dist, compass], Vector2(px + 16, py + 98), 14, Color("ffd98a"))
	else:
		_text("Find the ancient blade near the road.", Vector2(px + 16, py + 54), 15, BONE)
	if g.emblems.found.size() > 0:
		_text("SECRET   ASHEN EMBLEMS  %d / %d%s" % [g.emblems.found.size(), g.emblems.COUNT, "   -  UNLIMITED AMMO" if g.unlimited_ammo else ""], Vector2(px + 16, py + 114), 13, Color("e8c25a"))
	# buttons
	var b := _buttons()
	for k in b:
		var rc: Rect2 = b[k]
		draw_rect(rc, Color(0.04, 0.035, 0.03, 0.85))
		draw_rect(rc, GOLD, false, 2.0)
		var c := rc.get_center()
		match k:
			"close":
				draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), BONE, 3.5, true)
				draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), BONE, 3.5, true)
			"zoom_in":
				draw_line(c + Vector2(-11, 0), c + Vector2(11, 0), BONE, 3.5, true)
				draw_line(c + Vector2(0, -11), c + Vector2(0, 11), BONE, 3.5, true)
			"zoom_out":
				draw_line(c + Vector2(-11, 0), c + Vector2(11, 0), BONE, 3.5, true)
			"centre":
				draw_arc(c, 11, 0, TAU, 20, BONE, 3.0, true)
				draw_circle(c, 3.5, BONE)
	_text("drag to look around", Vector2(s.x * 0.5 - 90, s.y - 18), 13, Color(BONE, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 180)
