extends RefCounted
## Boss fights.
##  demon    (quest 10): dome shield that must be broken first, rolling attack, slams.      1,000 HP
##  serpent  (quest 20): Medusa gaze (10 s cooldown), summons a stone spear army, venom.    2,000 HP
##  cyborg   (quest 30): colossal cyborg, only its upper half rises beyond the bridge.      3,500 HP
##  malakar  (quest 40): mimics all three bosses, with their skills and power.             30,000 HP

var g  # the game node

const WIND := {"slam": 0.95, "sweep": 0.7, "charge": 0.85, "volley": 0.9, "bolts": 1.0, "summon": 1.2, "roll": 1.1,
	"gaze": 1.4, "stone": 1.5, "bite": 0.55, "spit": 0.8, "tail": 0.8, "fist": 1.0, "laser": 1.5, "missiles": 1.0}
const FORMS := ["own", "demon", "serpent", "cyborg"]
const FORM_NAME := {"own": "HIS OWN DARKNESS", "demon": "THE ASYLUM DEMON", "serpent": "THE SERPENT QUEEN", "cyborg": "THE CYBORG TITAN"}
const FORM_ATK := {
	"own": {"near": ["sweep", "slam"], "far": ["charge", "bolts", "volley", "summon"]},
	"demon": {"near": ["slam", "sweep"], "far": ["roll", "roll", "charge"]},
	"serpent": {"near": ["tail", "sweep"], "far": ["gaze", "stone", "spit"]},
	"cyborg": {"near": ["slam"], "far": ["fist", "laser", "missiles", "bolts"]},
}
const BASE_ATK := {
	"demon": {"near": ["slam", "sweep"], "far": ["roll"]},
	"serpent": {"near": ["bite", "tail"], "far": ["spit", "bite"]},
	"cyborg": {"near": ["fist"], "far": ["fist", "laser", "missiles"]},
}
const FORM_COLOR := {"own": Color("ff2020"), "demon": Color("ff8a20"), "serpent": Color("50ff80"), "cyborg": Color("30e0ff")}

var _cone_mesh: ArrayMesh
var _dome_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D


func setup(game) -> void:
	g = game
	_dome_mat = StandardMaterial3D.new()
	_dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dome_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_dome_mat.albedo_color = Color(0.1, 0.4, 0.7)
	_dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.3, 0.25)
	_beam_mat.emission_enabled = true
	_beam_mat.emission = Color(1.0, 0.3, 0.2)
	_beam_mat.emission_energy_multiplier = 3.0
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stone_mat.albedo_color = Color(0.62, 0.62, 0.6, 0.7)
	_stone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mesh = _make_wedge()


func _make_wedge() -> ArrayMesh:
	# flat fan (unit length along -Z, half-angle 0.55) for the gaze telegraph
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in n:
		var a0 := lerpf(-0.55, 0.55, float(i) / n)
		var a1 := lerpf(-0.55, 0.55, float(i + 1) / n)
		st.add_vertex(Vector3(0, 0, 0))
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)))
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)))
	return st.commit()


# ------------------------------------------------------------------ setup

func attach(e: Dictionary) -> void:
	e.cds = {"gaze": 3.0, "stone": 9.0}
	e.stun = 0.0
	e.form = "own"
	e.form_t = 0.0
	e.shield = 0.0
	e.shield_max = 0.0
	e.dome = null
	e.dome_flash = 0.0
	e.rolling = false
	e.hit_cd = 0.0
	e.exposed = 0.0
	e.beam_a0 = 0.0
	e.beam_a1 = 0.0
	e.beam_tick = 0.0
	e.trail = []
	e.static = false
	e.sink = 0.0
	e.link = null
	e.fire_t = 0.0
	var tm = g._unshaded(Color(1.0, 0.2, 0.1, 0.3))
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	e.tele = g._mesh(g._cyl(1.0, 0.04), tm)
	e.tele.visible = false
	var bx := BoxMesh.new()
	bx.size = Vector3(1.0, 0.04, 1.0)
	e.tele2 = g._mesh(bx, tm)
	e.tele2.visible = false
	var gm = g._unshaded(Color(0.3, 1.0, 0.5, 0.35))
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	e.cone = g._mesh(_cone_mesh, gm)
	e.cone.visible = false
	e.beam = g._mesh(g.M.box(1.0, 1.0, 1.0), _beam_mat)
	e.beam.visible = false
	match e.type:
		"demon":
			raise_shield(e, 380.0)
		"cyborg":
			e.static = true
			e.sink = 3.0
		"serpent":
			for i in 40:
				e.trail.append(e.pos + Vector2(0, float(i) * 0.45))
		"malakar":
			e.form = "own"


func raise_shield(e: Dictionary, hp: float) -> void:
	e.shield = hp
	e.shield_max = hp
	if e.dome == null:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 28
		sm.rings = 14
		mi.mesh = sm
		mi.material_override = _dome_mat.duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
		e.dome = mi
	e.dome.visible = true


func drop_shield(e: Dictionary) -> void:
	e.shield = 0.0
	if e.dome != null:
		e.dome.visible = false


func free_nodes(e: Dictionary) -> void:
	for k in ["tele", "tele2", "cone", "beam", "dome"]:
		if e.get(k) != null:
			e[k].queue_free()
			e[k] = null


# ------------------------------------------------------------------ damage

## Damage that gets through the dome shield (and bonus while dizzy).
func absorb(e: Dictionary, dmg: float) -> float:
	if e.shield > 0.0:
		e.shield -= dmg
		e.dome_flash = 0.3
		g.sfx("hit", -3.0, 0.6)
		g._float(g._p3(e.pos, 4.6), "SHIELD", Color("7ad0ff"))
		if e.shield <= 0.0:
			_shield_break(e)
		return 0.0
	if e.stun > 0.0:
		dmg *= 1.5
	return dmg


func _shield_break(e: Dictionary) -> void:
	drop_shield(e)
	e.stun = 2.6
	e.rolling = false
	e.st = "recover"
	e.t = 0.0
	g.shake = 14.0
	g._burst(e.pos, 50, Color("7ad0ff"), 12.0, 2.0)
	g.fx.pulse(0.7, 0.4)
	g.sfx("bolt", -2.0, 1.4)
	g._show_banner("SHIELD BROKEN", 1.8)


# ---------------------------------------------------------------------- AI

func _atk_set(e: Dictionary) -> Dictionary:
	if e.type == "malakar":
		return FORM_ATK[e.form]
	return BASE_ATK[e.type]


func wind_time(e: Dictionary) -> float:
	return float(WIND[e.atk]) * (0.8 if e.phase > 1 else 1.0)


func phase_check(e: Dictionary) -> void:
	var th: Array = g.BOSS[e.type].phases
	var want := 1
	for t in th:
		if e.hp < e.max_hp * float(t):
			want += 1
	if want > e.phase:
		e.phase = want
		e.speed *= 1.12
		g.shake = 14.0
		g._show_banner("%s ENRAGES" % str(g.ENEMY[e.type].name), 2.4)
		g._burst(e.pos, 50, Color("ff5a2a"), 12.0, 1.0)
		g.fx.strike(g._p3(e.pos))
		g.fx.intensity += 0.5
		g.sfx("roar", -2.0, 0.9)
		g.talk.say(e, "phase", true)
		match e.type:
			"demon":
				raise_shield(e, 260.0)
				e.stun = 0.0
			"serpent":
				e.cds.stone = 0.5
				e.cds.gaze = minf(e.cds.gaze, 2.0)
			"malakar":
				_spawn_adds(e, 2)
			"cyborg":
				e.cds.stone = 0.0
		if e.type != "cyborg" and e.type != "serpent" and g._quest_enemy_count() < g.add_cap(8) and e.type != "malakar":
			g._spawn_enemy("skeleton", e.pos + Vector2(3, 0), true)
			g._spawn_enemy("hollow", e.pos + Vector2(-3, 0), true)


func _spawn_adds(e: Dictionary, n: int) -> void:
	for i in n:
		if g._quest_enemy_count() < g.add_cap(9):
			var kind: String = ["knight", "fiend", "skeleton", "ghoul"][randi() % 4]
			g._spawn_enemy(kind, e.pos + Vector2.from_angle(randf() * TAU) * 4.5, true)


func _switch_form(e: Dictionary, form: String) -> void:
	e.form = form
	e.form_t = 0.0
	e.fig.eye.albedo_color = FORM_COLOR[form]
	e.fig.eye.emission = FORM_COLOR[form]
	if form == "demon":
		raise_shield(e, 1800.0)
	else:
		drop_shield(e)
	e.cds.gaze = 1.0
	e.cds.stone = 4.0
	g._show_banner("MALAKAR MIMICS %s" % FORM_NAME[form], 2.6, "He takes their power")
	g._burst(e.pos, 60, FORM_COLOR[form], 12.0, 2.0)
	g.fx.strike(g._p3(e.pos))
	g.sfx("roar", -2.0, 0.7)
	g.shake = 12.0


func ai(e: Dictionary, dt: float, dist: float, ang: float) -> void:
	var cfg: Dictionary = g.ENEMY[e.type]
	phase_check(e)
	e.hit_cd = maxf(0.0, e.hit_cd - dt)
	e.dome_flash = maxf(0.0, e.dome_flash - dt)
	e.exposed = maxf(0.0, e.exposed - dt)
	for k in e.cds:
		e.cds[k] = maxf(0.0, e.cds[k] - dt)
	if e.type == "malakar":
		e.form_t += dt
		if e.form_t > 26.0 and e.st == "chase":
			_switch_form(e, FORMS[(FORMS.find(e.form) + 1) % FORMS.size()])
	if e.type == "serpent":
		_trail_record(e)
	# dizzy after the shield breaks / a roll
	if e.stun > 0.0:
		e.stun -= dt
		e.face = ang
		return
	var reach: float = cfg.reach
	var ranged_style: bool = e.type == "serpent" or e.type == "cyborg" or (e.type == "malakar" and e.form in ["serpent", "cyborg"])
	var kind: String = e.type if e.type != "malakar" else e.form
	match e.st:
		"chase":
			e.face = ang
			e.cd -= dt
			if not e.static:
				if kind == "serpent":
					if dist < 5.0:
						g._move_e(e, -Vector2.from_angle(ang) * e.speed * 0.7 * dt)
					elif dist > 9.0:
						g._move_e(e, Vector2.from_angle(ang) * e.speed * dt)
					else:
						g._move_e(e, Vector2.from_angle(ang + PI / 2.0) * e.side * e.speed * 0.5 * dt)
				elif kind == "cyborg":
					if dist > 12.0:
						g._move_e(e, Vector2.from_angle(ang) * e.speed * 0.8 * dt)
					elif dist < 7.0:
						g._move_e(e, -Vector2.from_angle(ang) * e.speed * 0.8 * dt)
				elif dist > reach:
					g._move_e(e, Vector2.from_angle(ang) * e.speed * dt)
			var sets := _atk_set(e)
			var choose := ""
			# special cooldown skills first
			if kind == "serpent" and e.cds.gaze <= 0.0 and dist > 3.5 and dist < 22.0:
				choose = "gaze"
			elif kind == "serpent" and e.cds.stone <= 0.0 and g._quest_enemy_count() < g.add_cap(7):
				choose = "stone"
			elif not e.static and dist <= reach + 1.0 and kind != "serpent" and kind != "cyborg":
				choose = sets.near[randi() % sets.near.size()]
			elif kind == "serpent" and dist < 4.5 and e.cd <= 0.0:
				choose = sets.near[randi() % sets.near.size()]
			elif e.cd <= 0.0:
				var pool: Array = sets.far if (dist > 6.0 or e.static or ranged_style) else sets.near
				choose = pool[randi() % pool.size()]
			if choose != "":
				e.atk = choose
				e.st = "wind"
				e.t = 0.0
				e.hit_done = false
				e.dash = Vector2.from_angle(ang)
				_begin_wind(e, ang)
		"wind":
			var wd := wind_time(e)
			var track: bool = e.t < wd * 0.5
			if e.atk == "charge" or e.atk == "roll" or e.atk == "bite":
				track = e.t < wd * 0.6
			if e.atk == "gaze":
				track = e.t < wd * 0.75
			if e.atk == "laser" or e.atk == "fist" or e.atk == "missiles":
				track = true
			if track:
				e.face = ang
				e.dash = Vector2.from_angle(ang)
			_wind_update(e, ang)
			if e.t > wd:
				e.st = "strike"
				e.t = 0.0
				e.hit_done = false
				_strike_start(e, dist, ang)
		"strike":
			_strike_update(e, dt, dist, ang)
		"recover":
			if e.t > float(cfg.rec) * (0.75 if e.phase > 1 else 1.0):
				e.st = "chase"
				e.t = 0.0
				e.cd = randf_range(1.8, 3.4) * (0.75 if e.phase > 1 else 1.0)
				if e.type == "cyborg":
					e.cd = randf_range(1.6, 2.8)


func _begin_wind(e: Dictionary, ang: float) -> void:
	match e.atk:
		"fist":
			# mark the ground right now; the fist drops when the telegraph runs out
			var count := 1 if e.phase == 1 else 2
			for i in count:
				var tgt: Vector2 = g.p_pos + (Vector2.from_angle(randf() * TAU) * randf_range(0.0, 4.0) if i > 0 else Vector2.ZERO)
				g._add_zone(tgt, 4.2, wind_time(e), e.dmg, "enemy", {"fist": e})
			g.sfx("roar", -8.0, 0.5)
		"stone":
			g._burst(e.pos, 24, Color("bfbfb0"), 8.0, 0.6)
			g.sfx("roar", -6.0, 0.6)
		"roll":
			g.sfx("roar", -6.0, 0.9)


func _wind_update(e: Dictionary, ang: float) -> void:
	var w := clampf(e.t / wind_time(e), 0.0, 1.0)
	var src: Vector2 = e.pos
	if e.atk == "gaze" and e.cone != null:
		e.cone.visible = true
		var len := 22.0
		e.cone.global_position = g._p3(src, 0.3)
		e.cone.rotation.y = g._face_rot(e.face)
		e.cone.scale = Vector3(len, 1, len)
	if e.atk == "laser" and e.beam != null:
		# telegraph: a thin line at the start of the sweep
		var a0 := ang - 0.5
		e.beam_a0 = a0
		e.beam_a1 = ang + 0.5
		_place_beam(e, a0, 0.12 + 0.1 * w)
	if e.atk == "roll":
		e.tele2.visible = true
		var fwd := Vector2.from_angle(e.face)
		e.tele2.global_position = g._p3(src + fwd * 9.0, 0.12)
		e.tele2.rotation.y = g._face_rot(e.face)
		e.tele2.scale = Vector3(3.2, 1, 18.0 * w)


func _place_beam(e: Dictionary, a: float, thick: float) -> void:
	var dir := Vector2.from_angle(a)
	var src: Vector2 = e.pos
	var h := 1.4
	if e.type == "cyborg":
		h = 5.0
	var length := 60.0
	var mid := src + dir * length * 0.5
	var p = g._p3(mid, h)
	e.beam.visible = true
	e.beam.global_position = p
	e.beam.rotation.y = g._face_rot(a)
	e.beam.scale = Vector3(thick, thick, length)


func _cone_hit(e: Dictionary, ang: float, dist: float, half: float, rng: float) -> bool:
	return dist < rng and absf(angle_difference(ang, e.face)) < half


func _strike_start(e: Dictionary, dist: float, ang: float) -> void:
	var bc: Dictionary = g.BOSS[e.type]
	match e.atk:
		"slam", "tail":
			var r: float = float(bc.slam_r) if e.atk == "slam" else float(bc.slam_r) * 0.85
			if dist < r + g.p_r:
				g._hurt_player(e.dmg, e.pos)
			g.shake = maxf(g.shake, 14.0)
			g._burst(e.pos, 36, Color("7a8aa5"), 11.0, 0.3)
			g.sfx("bolt", -8.0, 0.7)
			if e.phase > 1:
				g.fx.strike(g._p3(e.pos))
		"sweep":
			if dist < float(bc.sweep_len) + g.p_r and absf(angle_difference(ang, e.face)) < 1.2:
				g._hurt_player(e.dmg * 0.8, e.pos)
			g.shake = maxf(g.shake, 9.0)
			g.sfx("swing", 0.0, 0.5)
		"volley":
			var n := 5 if e.phase == 1 else 7
			for i in n:
				g._fire(e.pos, ang + lerpf(-0.55, 0.55, float(i) / (n - 1)), e.dmg * 0.55, 11.0, "orb")
			g.sfx("roar", -8.0, 1.4)
		"spit":
			for i in 3:
				g._fire(e.pos, ang + lerpf(-0.3, 0.3, float(i) / 2.0), e.dmg * 0.6, 12.0, "venom")
			g.sfx("roar", -8.0, 1.6)
		"bolts":
			var n2 := 4 if e.phase == 1 else 6
			g._add_zone(g.p_pos, 2.6, 1.0, e.dmg * 0.9, "enemy")
			for i in n2 - 1:
				g._add_zone(g.p_pos + Vector2.from_angle(randf() * TAU) * randf_range(2.5, 8.0), 2.6, randf_range(0.9, 1.6), e.dmg * 0.9, "enemy")
		"summon":
			_spawn_adds(e, 2)
			g._burst(e.pos, 30, Color("b070ff"), 9.0)
			g.sfx("roar", -6.0, 1.2)
		"stone":
			e.cds.stone = 18.0 if e.phase == 1 else 12.0
			var n3 := 4 if e.phase == 1 else 5
			for i in n3:
				if g._quest_enemy_count() >= g.add_cap(9):
					break
				var pp: Vector2 = g.p_pos + Vector2.from_angle(float(i) / n3 * TAU + randf()) * 8.0
				pp = g._spawn_near(pp, 0.0, 2.5)
				g._spawn_enemy("stonesoldier", pp, true)
				g._burst(pp, 20, Color("bfbfb0"), 8.0, 0.4)
			g.sfx("bolt", -4.0, 0.5)
			g.shake = 10.0
		"gaze":
			e.cds.gaze = 10.0 if e.phase == 1 else 8.0
			if e.cone != null:
				e.cone.visible = false
			if _cone_hit(e, ang, dist, 0.58, 23.0):
				g.petrify_player(2.4, e.dmg * 0.4)
			else:
				g._float(g._p3(g.p_pos, 2.4), "RESISTED", Color("a0ffb8"))
			g.fx.pulse(0.5, 0.35)
			g.sfx("roar", -2.0, 1.8)
		"roll":
			e.rolling = true
			e.hit_cd = 0.0
		"charge":
			pass
		"bite":
			pass
		"fist":
			pass
		"laser":
			e.beam_tick = 0.0
			g.sfx("roar", -2.0, 0.4)
		"missiles":
			var m := 6 if e.phase == 1 else 9
			for i in m:
				var side := 1.0 if i % 2 == 0 else -1.0
				var a2 := ang + side * (0.5 + 0.2 * float(i / 2))
				g._fire(e.pos, a2, e.dmg * 0.55, 8.0, "missile", 1.6, 6.0)
			g.sfx("roar", -6.0, 1.1)
			g.shake = 6.0


func _strike_update(e: Dictionary, dt: float, dist: float, ang: float) -> void:
	var cfg: Dictionary = g.ENEMY[e.type]
	var slen := 0.2
	match e.atk:
		"charge":
			slen = 0.55
			g._move_e(e, e.dash * 26.0 * dt)
			if not e.hit_done and dist < float(cfg.r) + g.p_r + 0.8:
				e.hit_done = true
				g._hurt_player(e.dmg * 0.9, e.pos)
			g.shake = maxf(g.shake, 4.0)
		"bite":
			slen = 0.3
			g._move_e(e, e.dash * 22.0 * dt)
			if not e.hit_done and dist < float(cfg.r) + g.p_r + 1.4:
				e.hit_done = true
				g._hurt_player(e.dmg, e.pos)
				g._burst(g.p_pos, 8, Color("60ff90"), 6.0)
		"roll":
			slen = 1.7
			e.tele2.visible = false
			var v: Vector2 = e.dash * 21.0 * dt
			g._move_e(e, v)
			if g.arena_active:
				var rel: Vector2 = e.pos - g.site
				if rel.length() > g.ARENA_R - 2.8:
					var nrm := (-rel).normalized()
					e.dash = e.dash.bounce(nrm)
					g.shake = maxf(g.shake, 8.0)
					g._burst(e.pos, 14, Color("9a8a70"), 8.0, 0.4)
			g.shake = maxf(g.shake, 3.0)
			if e.hit_cd <= 0.0 and dist < float(cfg.r) + g.p_r + 0.9:
				e.hit_cd = 0.7
				g._hurt_player(e.dmg * 0.9, e.pos)
				g.p_pos = g._contain(g._slide(g.p_pos, (g.p_pos - e.pos).normalized() * 2.5))
		"laser":
			slen = 2.8
			var k := clampf(e.t / slen, 0.0, 1.0)
			var a := lerpf(e.beam_a0, e.beam_a1, k)
			_place_beam(e, a, 0.7)
			e.beam_tick -= dt
			if e.beam_tick <= 0.0:
				e.beam_tick = 0.18
				var dir := Vector2.from_angle(a)
				var rel2: Vector2 = g.p_pos - e.pos
				var along := rel2.dot(dir)
				var off := absf(rel2.cross(dir))
				if along > 0.0 and along < 64.0 and off < 1.2:
					g._hurt_player(e.dmg * 0.35, e.pos, true)
			g.shake = maxf(g.shake, 3.0)
	if e.t > slen:
		if e.atk == "roll":
			e.rolling = false
			e.stun = 1.8
			g._float(g._p3(e.pos, 4.5), "DIZZY", Color("ffe070"))
		if e.atk == "laser":
			e.beam.visible = false
			e.exposed = 3.0
			g._float(g._p3(e.pos, 9.0), "CORE EXPOSED", Color("7ad0ff"))
		e.st = "recover"
		e.t = 0.0


# ------------------------------------------------------------------- fists

## The Titan's fist crashes down at `pos`; it stays for a few seconds and can be hit (damage goes to the Titan).
func spawn_fist(boss: Dictionary, pos: Vector2) -> void:
	var mesh := Node3D.new()
	g.add_child(mesh)
	var metal = g.M.grad_mat([Color("2a3038"), Color("6a7a8a"), Color("9aaaba")], 0.3, 0.7, 0.35, 0.8, 99, 1.0)
	var glow = g._mat(Color("30e0ff"), 0.3, 3.0)
	g._mesh(g.M.box(3.2, 2.6, 3.6), metal, Vector3(0, 1.3, 0), mesh)
	for k in 4:
		g._mesh(g.M.box(0.7, 0.9, 1.2), metal, Vector3(-1.2 + k * 0.8, 2.9, -1.6), mesh)
	g._mesh(g.M.box(1.6, 0.4, 0.4), glow, Vector3(0, 1.6, -1.85), mesh)
	g._mesh(g.M.cone(0.6, 1.2, 4.0, 10), metal, Vector3(0, 4.5, 1.8), mesh)
	mesh.global_position = g._p3(pos, 18.0)
	var e := {
		"type": "fist", "ai": "fist", "pos": pos, "r": 2.6, "hp": 1.0, "max_hp": 1.0, "speed": 0.0, "st": "chase", "t": 0.0,
		"face": 0.0, "dmg": 0.0, "hit_done": false, "kb": Vector2.ZERO, "flash": 0.0, "dead": false, "name": "TITAN FIST",
		"atk": "", "phase": 1, "cd": 0.0, "walk": 0.0, "mv": 0.0, "last": pos, "dash": Vector2.ZERO, "side": 1.0,
		"fig": {"root": mesh, "meshes": [], "flash_on": false}, "tele": null, "tele2": null, "boss": false, "elite": false,
		"souls": 0, "mode": "alert", "home": pos, "aggro": 0.0, "force": true, "quest": false, "wayside": false,
		"link": boss, "static": true, "life": 4.8, "drop": 0.0, "cone": null, "beam": null, "dome": null, "sink": 0.0,
	}
	g.enemies.append(e)
	g.shake = 16.0
	g._burst(pos, 40, Color("9aaaba"), 11.0, 0.4)
	g.fx.pulse(0.6, 0.3)
	g.sfx("bolt", 0.0, 0.6)
	if g.p_pos.distance_to(pos) < 4.2 + g.p_r:
		g._hurt_player(boss.dmg, pos, true)


# ------------------------------------------------------------------ visuals

func _trail_record(e: Dictionary) -> void:
	var tr: Array = e.trail
	if tr.is_empty() or e.pos.distance_to(tr[0]) > 0.4:
		tr.push_front(e.pos)
		if tr.size() > 90:
			tr.pop_back()


## Frame update for boss-specific visuals. Returns true when the generic humanoid pose must be skipped.
func visuals(e: Dictionary, dt: float) -> bool:
	var f: Dictionary = e.fig
	# dome
	if e.dome != null and e.dome.visible:
		var rr: float = 3.9 if e.type != "malakar" else 4.1
		e.dome.global_position = g._p3(e.pos, 2.3)
		e.dome.scale = Vector3(rr, rr * 1.12, rr)
		var m: StandardMaterial3D = e.dome.material_override
		m.albedo_color = Color(0.1, 0.4, 0.7).lerp(Color(0.5, 0.9, 1.0), clampf(e.dome_flash * 3.0, 0.0, 1.0)) * (0.8 + 0.2 * sin(g.t * 5.0))
	# telegraphs that depend on the boss (the generic code positions the slam/sweep ones)
	if e.atk != "gaze" and e.cone != null:
		e.cone.visible = false
	if e.beam != null and not (e.atk == "laser" and (e.st == "wind" or e.st == "strike")):
		e.beam.visible = false
	if e.type == "serpent":
		_serpent_visuals(e, dt)
		return true
	return false


func _serpent_visuals(e: Dictionary, dt: float) -> void:
	var f: Dictionary = e.fig
	var head: Node3D = f.head
	var segs: Array = f.segs
	var gp = g._p3(e.pos)
	var raised := 3.1
	head.global_position = Vector3(gp.x, gp.y + raised, gp.z)
	head.rotation = Vector3(0.18, g._face_rot(e.face), 0)
	var flare := 1.0
	if e.atk == "gaze" and e.st == "wind":
		flare = 1.0 + 0.35 * clampf(e.t / wind_time(e), 0.0, 1.0)
		f.eye.emission_energy_multiplier = 10.0
	else:
		f.eye.emission_energy_multiplier = 6.0
	f.hood.scale = Vector3(flare, flare, 1.0)
	# gorgon snakes writhe
	for i in f.snakes.size():
		var sn: Node3D = f.snakes[i]
		sn.rotation = Vector3(sin(g.t * 3.0 + i) * 0.5, 0, cos(g.t * 2.3 + i * 1.7) * 0.5)
	# body follows the head's path
	var tr: Array = e.trail
	var acc := 0.0
	var ti := 0
	var prev: Vector2 = tr[0] if not tr.is_empty() else e.pos
	for i in segs.size():
		var want := 1.3 + float(i) * 1.0
		while ti < tr.size() - 1 and acc < want:
			var nxt: Vector2 = tr[ti + 1]
			acc += prev.distance_to(nxt)
			prev = nxt
			ti += 1
		var seg: Node3D = segs[i]
		var p: Vector2 = prev
		var lift := maxf(0.0, raised * 0.85 * (1.0 - float(i) / 5.0))
		var wave := sin(g.t * 2.0 - float(i) * 0.7) * 0.25 * (float(i) / segs.size())
		var h = g._h(p)
		var r := lerpf(0.78, 0.1, pow(float(i) / (segs.size() - 1), 0.8))
		seg.global_position = Vector3(p.x + wave, h + r * 0.9 + lift, p.y)
		var ahead: Vector2 = tr[maxi(ti - 2, 0)] if not tr.is_empty() else e.pos
		var dir := (ahead - p)
		if dir.length() > 0.01:
			seg.rotation.y = g._face_rot(dir.angle())
	f.root.visible = true


## Extra pose overrides applied after the generic humanoid pose.
func post_pose(e: Dictionary) -> void:
	var f: Dictionary = e.fig
	if f.get("serpent", false) or f.get("quad", false):
		return
	var rolling: bool = e.rolling or (e.atk == "roll" and e.st == "wind")
	if rolling:
		var curl := 1.0 if e.rolling else clampf(e.t / wind_time(e), 0.0, 1.0)
		f.body.rotation.x = lerpf(f.body.rotation.x, g.t * 14.0, curl) if e.rolling else lerpf(f.body.rotation.x, 0.9, curl)
		f.arm.rotation = Vector3(1.8, 0, 0)
		f.larm.rotation = Vector3(1.8, 0, 0)
		f.elbow.rotation.x = 2.2
		f.lelbow.rotation.x = 2.2
		f.legs[0].rotation.x = 1.7
		f.legs[1].rotation.x = 1.7
		f.knees[0].rotation.x = -2.2
		f.knees[1].rotation.x = -2.2
		f.body.position.y = 0.55 + curl * 0.1
	if e.stun > 0.0:
		f.body.rotation.x = -0.35 + sin(g.t * 9.0) * 0.12
		f.body.rotation.z = sin(g.t * 6.0) * 0.12
	if e.type == "cyborg":
		_cyborg_pose(e)
	if e.type == "malakar":
		f.eye.emission_energy_multiplier = 6.0 + 3.0 * sin(g.t * 5.0)


func _cyborg_pose(e: Dictionary) -> void:
	var f: Dictionary = e.fig
	var w := clampf(e.t / maxf(wind_time(e) if e.atk != "" else 1.0, 0.01), 0.0, 1.0)
	f.body.rotation = Vector3(0.0, 0.0, 0.0)
	f.body.rotation.y = sin(g.t * 0.6) * 0.1
	if e.st == "wind" or e.st == "strike":
		match e.atk:
			"fist":
				f.arm.rotation = Vector3(lerpf(0.3, 3.0, w) if e.st == "wind" else 0.2, 0, 0)
				f.elbow.rotation.x = 0.4
				f.larm.rotation = Vector3(0.6, 0, 0)
			"laser":
				f.arm.rotation = Vector3(1.55, -0.2, 0)
				f.larm.rotation = Vector3(1.55, 0.2, 0)
				f.elbow.rotation.x = 0.1
				f.lelbow.rotation.x = 0.1
			"missiles":
				f.arm.rotation = Vector3(2.7, 0.3, 0)
				f.larm.rotation = Vector3(2.7, -0.3, 0)
				f.elbow.rotation.x = 0.3
				f.lelbow.rotation.x = 0.3
	if e.exposed > 0.0:
		f.eye.emission_energy_multiplier = 10.0
	else:
		f.eye.emission_energy_multiplier = 4.0
