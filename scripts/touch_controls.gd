extends Control
## On-screen mobile controls: floating joystick (left) + Attack / Roll / Block / Estus buttons (right).
## Mouse clicks work too because project.godot has emulate_touch_from_mouse enabled.

const UI := preload("res://scripts/ui.gd")

signal attack_pressed
signal roll_pressed
signal estus_pressed
signal pause_pressed
signal skill1_pressed
signal torch_pressed
signal cmd_pressed
signal look_dragged(dx: float)
signal skill2_pressed
signal swap_pressed
signal map_pressed

const STICK_MAX := 70.0
const BONE := Color("d9cfb8")
const EMBER := Color("e8892b")
const GOLD := Color("8a7a55")

var move_vec := Vector2.ZERO
var block_held := false
var flasks := 3
var max_flasks := 3
var paused := false
var atk_ok := true
var skill_unlocked := [false, false]
var skill_ids := ["whirl", "thunder"]
var torch_visible := false
var cmd_visible := false
var cmd_enabled := false
var cmd_label := "STAY"
var torch_label := "TORCH"
var _look_id := -1
var _look_last := Vector2.ZERO
var skill_labels := ["WHIRL", "THUNDER"]
var skill_cd := [0.0, 0.0]  # remaining cooldown, 0..1
var skill_ok := [true, true]
var weapon_icon := "sword"
var ammo := 0
var can_swap := false
var roll_ok := true
var attack_label := "ATTACK":
	set(v):
		if v != attack_label:
			attack_label = v
			queue_redraw()

var _t := 0.0
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _touches := {}  # touch index -> button name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	_stick_id = -1
	_look_id = -1
	move_vec = Vector2.ZERO
	block_held = false
	_touches.clear()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _special():
		queue_redraw()


func _special() -> bool:
	return attack_label == "TAKE" or attack_label == "GRAB"


func _buttons() -> Dictionary:
	var s := size
	return {
		"attack": {"c": Vector2(s.x - 112, s.y - 112), "r": 60.0, "label": attack_label},
		"roll": {"c": Vector2(s.x - 242, s.y - 82), "r": 44.0, "label": "ROLL"},
		"block": {"c": Vector2(s.x - 212, s.y - 192), "r": 44.0, "label": "BLOCK"},
		"estus": {"c": Vector2(s.x - 92, s.y - 240), "r": 38.0, "label": ""},
		"skill1": {"c": Vector2(s.x - 352, s.y - 112), "r": 38.0, "label": skill_labels[0]},
		"skill2": {"c": Vector2(s.x - 332, s.y - 214), "r": 38.0, "label": skill_labels[1]},
		"swap": {"c": Vector2(s.x - 196, s.y - 296), "r": 34.0, "label": ""},
		"torch": {"c": Vector2(s.x - 322, s.y - 322), "r": 38.0, "label": torch_label},
		"cmd": {"c": Vector2(s.x - 436, s.y - 214), "r": 42.0, "label": cmd_label},
		"pause": {"c": Vector2(s.x * 0.5, 34), "r": 22.0, "label": ""},
		"map": {"c": Vector2(116, 250), "r": 68.0, "label": ""},  # the minimap: tap to open the world map
	}


func _hit(pos: Vector2) -> String:
	var b := _buttons()
	for name in b:
		if (name == "torch" and not torch_visible) or (name == "cmd" and not cmd_visible):
			continue
		if pos.distance_to(b[name].c) <= b[name].r * 1.2:
			return name
	return ""


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _hit(event.position)
			if hit != "":
				_touches[event.index] = hit
				match hit:
					"attack": attack_pressed.emit()
					"roll": roll_pressed.emit()
					"estus": estus_pressed.emit()
					"pause": pause_pressed.emit()
					"skill1": skill1_pressed.emit()
					"skill2": skill2_pressed.emit()
					"swap": swap_pressed.emit()
					"torch": torch_pressed.emit()
					"cmd": cmd_pressed.emit()
					"map": map_pressed.emit()
					"block": block_held = true
				if hit != "pause" and OS.has_feature("mobile"):
					Input.vibrate_handheld(10)
			elif event.position.x < size.x * 0.5 and _stick_id == -1:
				_stick_id = event.index
				_stick_origin = event.position
				_stick_pos = event.position
				move_vec = Vector2.ZERO
			elif event.position.x >= size.x * 0.5 and _look_id == -1:
				_look_id = event.index  # dragging an empty part of the right side turns the camera (labyrinth)
				_look_last = event.position
		else:
			if event.index == _look_id:
				_look_id = -1
			if event.index == _stick_id:
				_stick_id = -1
				move_vec = Vector2.ZERO
			if _touches.has(event.index):
				if _touches[event.index] == "block":
					block_held = false
				_touches.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _look_id:
		look_dragged.emit(event.position.x - _look_last.x)
		_look_last = event.position
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_stick_pos = event.position
		var d := _stick_pos - _stick_origin
		if d.length() > STICK_MAX:
			d = d.normalized() * STICK_MAX
			_stick_pos = _stick_origin + d
		move_vec = d / STICK_MAX if d.length() > 8.0 else Vector2.ZERO
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _txt(text: String, pos: Vector2, fs: int, col: Color, w: float = -1.0) -> void:
	var f := UI.font()
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


func _ring(c: Vector2, r: float, pressed: bool, accent: Color) -> void:
	draw_circle(c, r + 3, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color(EMBER, 0.32) if pressed else Color(0.05, 0.04, 0.035, 0.72))
	draw_arc(c, r, 0, TAU, 48, accent if pressed else GOLD, 3.0, true)
	draw_arc(c, r - 6, 0, TAU, 48, Color(BONE, 0.12), 1.5, true)


func _draw() -> void:
	var s := size

	# joystick
	if _stick_id != -1:
		draw_circle(_stick_origin, 70, Color(0, 0, 0, 0.28))
		draw_arc(_stick_origin, 70, 0, TAU, 56, Color(GOLD, 0.8), 3.0, true)
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0)
			draw_line(_stick_origin + d * 54, _stick_origin + d * 66, Color(BONE, 0.35), 2.0)
		draw_circle(_stick_pos, 30, Color(0.1, 0.08, 0.06, 0.9))
		draw_circle(_stick_pos, 24, Color(BONE, 0.28))
		draw_arc(_stick_pos, 30, 0, TAU, 32, BONE, 2.5, true)
	else:
		var hc := Vector2(s.x * 0.16, s.y - 120)
		draw_arc(hc, 62, 0, TAU, 48, Color(BONE, 0.16), 2.0, true)
		draw_arc(hc, 24, 0, TAU, 24, Color(BONE, 0.12), 2.0, true)
		_txt("MOVE", hc + Vector2(-40, 90), 12, Color(BONE, 0.35), 80)

	var down := _touches.values()
	var b := _buttons()
	for name in b:
		if name == "map" or (name == "torch" and not torch_visible) or (name == "cmd" and not cmd_visible):
			continue
		var c: Vector2 = b[name].c
		var r: float = b[name].r
		var pressed: bool = name in down
		var enabled := true
		if name == "cmd": enabled = cmd_enabled
		if name == "attack": enabled = atk_ok
		if name == "roll": enabled = roll_ok
		var locked := false
		if name == "skill1": locked = not skill_unlocked[0]
		if name == "skill2": locked = not skill_unlocked[1]
		if name == "swap" and not can_swap:
			locked = true
			enabled = false
		if locked:
			enabled = false
		var rr := r * (0.94 if pressed else 1.0)
		var accent := Color("ffd98a") if (name == "attack" and _special()) else EMBER
		_ring(c, rr, pressed, accent)
		if name == "attack" and _special():
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(c, rr + 6 + pulse * 4, 0, TAU, 48, Color("ffd98a", 0.8 - pulse * 0.5), 3.0, true)
		var col := Color.WHITE if pressed else BONE
		if not enabled:
			col = Color(BONE, 0.3)
		match name:
			"attack":
				if _special():
					_txt(attack_label, c + Vector2(-40, 8), 24, Color("ffd98a"), 80)
				else:
					draw_line(c + Vector2(-17, 17), c + Vector2(19, -19), col, 5.0, true)
					draw_line(c + Vector2(-13, -1), c + Vector2(1, 13), col, 4.0, true)
					draw_circle(c + Vector2(-20, 20), 3.5, col)
			"roll":
				draw_arc(c, 15, 0.6, TAU - 0.9, 24, col, 3.5, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(9, -19), c + Vector2(22, -6), c + Vector2(5, -3)]), col)
			"block":
				var pts := PackedVector2Array([
					c + Vector2(0, -20), c + Vector2(17, -12), c + Vector2(15, 7), c + Vector2(0, 21),
					c + Vector2(-15, 7), c + Vector2(-17, -12)])
				draw_colored_polygon(pts, Color(col, 0.28))
				pts.append(pts[0])
				draw_polyline(pts, col, 3.0, true)
				draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color(col, 0.6), 2.0)
			"estus":
				var fill: float = clampf(float(flasks) / 5.0, 0.0, 1.0)
				var outline := PackedVector2Array([
					c + Vector2(-5, -18), c + Vector2(5, -18), c + Vector2(5, -8), c + Vector2(15, 14),
					c + Vector2(-15, 14), c + Vector2(-5, -8), c + Vector2(-5, -18)])
				if flasks > 0:
					var top := lerpf(14.0, -6.0, fill)
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(-12 - (top - 14) * 0.0, 12), c + Vector2(12, 12), c + Vector2(6 + (14 - top) * 0.0, top + 2), c + Vector2(-6, top + 2)]),
						Color(1.0, 0.62, 0.2, 0.85))
				draw_polyline(outline, col if flasks > 0 else Color(BONE, 0.3), 3.0, true)
				draw_circle(c + Vector2(22, 22), 11, Color(0.04, 0.03, 0.02, 0.95))
				draw_arc(c + Vector2(22, 22), 11, 0, TAU, 20, GOLD, 2.0, true)
				_txt(str(flasks), c + Vector2(12, 28), 15, BONE, 20)
			"skill1":
				_skill_icon(skill_ids[0], c, col, enabled)
			"skill2":
				_skill_icon(skill_ids[1], c, col, enabled)
			"cmd":
				# a raised hand: stop / go
				if cmd_label != "FOLLOW":
					draw_rect(Rect2(c + Vector2(-9, -12), Vector2(18, 22)), col, false, 3.0)
					draw_line(c + Vector2(-9, 10), c + Vector2(9, 10), col, 3.0, true)
				else:
					draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -12), c + Vector2(14, 0), c + Vector2(-12, 12)]), col)
			"torch":
				# a stick with a flame
				draw_line(c + Vector2(-9, 18), c + Vector2(5, -6), col, 3.5, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(5, -22), c + Vector2(13, -9), c + Vector2(9, 0), c + Vector2(1, 0), c + Vector2(-2, -10)]), Color("ffa040") if enabled else Color(col, 0.5))
				draw_colored_polygon(PackedVector2Array([c + Vector2(5, -12), c + Vector2(8, -4), c + Vector2(2, -4)]), Color("ffe39a") if enabled else Color(col, 0.4))
			"swap":
				match weapon_icon:
					"axe":
						draw_line(c + Vector2(-9, 16), c + Vector2(8, -14), col, 3.5, true)
						draw_colored_polygon(PackedVector2Array([c + Vector2(4, -16), c + Vector2(17, -10), c + Vector2(15, 3), c + Vector2(5, -3)]), col)
					"spear":
						draw_line(c + Vector2(-12, 16), c + Vector2(10, -12), col, 3.0, true)
						draw_colored_polygon(PackedVector2Array([c + Vector2(8, -20), c + Vector2(15, -10), c + Vector2(6, -11)]), col)
					"gun":
						draw_rect(Rect2(c + Vector2(-14, -8), Vector2(26, 7)), col)
						draw_rect(Rect2(c + Vector2(-12, -2), Vector2(8, 15)), col)
						draw_circle(c + Vector2(2, -4), 5, Color(0, 0, 0, 0.5))
					_:
						draw_line(c + Vector2(-12, 12), c + Vector2(12, -12), col, 3.5, true)
						draw_line(c + Vector2(-8, -1), c + Vector2(1, 8), col, 3.0)
				draw_arc(c, rr + 5, -0.5, 0.5, 8, Color(col, 0.0), 1.0)
				if weapon_icon == "gun":
					_txt("INF" if ammo < 0 else str(ammo), c + Vector2(-20, r + 16), 14, Color("ffd070") if ammo != 0 else Color("ff6a5a"), 40)
			"pause":
				if paused:
					draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -9), c + Vector2(9, 0), c + Vector2(-6, 9)]), col)
				else:
					draw_rect(Rect2(c + Vector2(-7, -9), Vector2(5, 18)), col)
					draw_rect(Rect2(c + Vector2(2, -9), Vector2(5, 18)), col)
		if name == "skill1" or name == "skill2":
			var si: int = 0 if name == "skill1" else 1
			if skill_cd[si] > 0.0 and skill_unlocked[si]:
				draw_arc(c, rr - 4, -PI / 2, -PI / 2 + TAU * skill_cd[si], 32, Color(0, 0, 0, 0.7), 8.0, true)
			if locked:
				draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 12)), Color(BONE, 0.5))
				draw_arc(c + Vector2(0, -3), 6, PI, TAU, 10, Color(BONE, 0.5), 2.5, true)
			_txt(b[name].label, c + Vector2(-50, r + 17), 11, Color(BONE, 0.55), 100)
		if name == "cmd":
			_txt(cmd_label, c + Vector2(-50, r + 17), 11, Color(BONE, 0.6), 100)
		if name == "torch":
			_txt(torch_label, c + Vector2(-50, r + 17), 11, Color(BONE, 0.6), 100)
		if name == "attack" or name == "roll" or name == "block":
			if not (name == "attack" and _special()):
				_txt(b[name].label, c + Vector2(-50, r + 18), 12, Color(BONE, 0.6), 100)


## One icon per skill (all drawn with lines and polygons, no textures).
func _skill_icon(id: String, c: Vector2, col: Color, enabled: bool) -> void:
	match id:
		"whirl":
			draw_arc(c, 14, 0.4, TAU - 0.5, 20, col, 3.0, true)
			draw_arc(c, 7, 2.0, TAU + 1.2, 16, col, 2.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(10, -19), c + Vector2(21, -8), c + Vector2(6, -6)]), col)
		"thunder":
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -20), c + Vector2(-10, 2), c + Vector2(-1, 2), c + Vector2(-5, 20), c + Vector2(11, -4), c + Vector2(2, -4)]), Color("bcd4ff") if enabled else Color(col, 0.5))
		"quake":
			# a fist-sized crack in the ground with flying rock
			draw_polyline(PackedVector2Array([c + Vector2(-18, 8), c + Vector2(-8, 2), c + Vector2(-2, 12), c + Vector2(6, 0), c + Vector2(18, 10)]), col, 3.0, true)
			draw_line(c + Vector2(-2, 12), c + Vector2(-4, 20), col, 2.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -6), c + Vector2(-5, -14), c + Vector2(0, -6)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, -10), c + Vector2(11, -18), c + Vector2(15, -9)]), col)
		"rage":
			# a flame / bared fangs
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(10, -4), c + Vector2(14, 6), c + Vector2(6, 16), c + Vector2(-6, 16), c + Vector2(-14, 6), c + Vector2(-10, -6), c + Vector2(-4, -2)]), Color("ff6a4a") if enabled else Color(col, 0.5))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(6, 8), c + Vector2(0, 14), c + Vector2(-6, 8)]), Color("ffd070") if enabled else Color(col, 0.4))
		"dash":
			draw_line(c + Vector2(-20, -8), c + Vector2(-4, -8), col, 2.5, true)
			draw_line(c + Vector2(-20, 0), c + Vector2(2, 0), col, 3.0, true)
			draw_line(c + Vector2(-20, 8), c + Vector2(-4, 8), col, 2.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -12), c + Vector2(20, 0), c + Vector2(4, 12)]), col)
		"flurry":
			for i in 4:
				var o := Vector2(-12 + i * 8, 0)
				draw_line(c + o + Vector2(-5, 14), c + o + Vector2(7, -14), col, 2.5, true)
		"fan":
			for i in 3:
				var a := -0.55 + i * 0.55
				var d := Vector2(sin(a), -cos(a))
				draw_line(c + d * 5.0 + Vector2(0, 14), c + d * 22.0 + Vector2(0, 14), col, 3.5, true)
			draw_circle(c + Vector2(0, 14), 4.0, col)
		"blast":
			var pts := PackedVector2Array()
			for i in 12:
				var ang := float(i) / 12.0 * TAU
				var rad := 20.0 if i % 2 == 0 else 9.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(pts, Color("ffb050") if enabled else Color(col, 0.5))
			draw_circle(c, 6.0, Color("fff0c0") if enabled else Color(col, 0.4))
