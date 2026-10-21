extends RefCounted
## God of War / Mortal Kombat-style grabs and executions. A badly hurt enemy is left dazed (it glows, shows a GRAB prompt and stops fighting): press GRAB and
## the hero seizes it for a cinematic finisher chosen by the equipped weapon. Every regular finisher opens with the same grab (lunge, throat clamp,
## hoist, headbutt, jab / hook / knee) and then plays its own move; every boss has its own finisher when its health is nearly gone.
##
## Time: `t` runs from -_pre (the grab) to 0 (the finisher starts) up to `dur`.

const HEART_PATH := "res://assets/models/enemies/heart.glb"
## Where the hero stands (distance from the victim's centre); anything not listed uses the victim's radius + 0.85.
const STANDS := {"rip": 0.72, "snap": 0.9, "decap": 0.95, "shoot": 0.95, "impale": 1.05, "blast": 1.0}
## How high the victim is hoisted during the grab.
const HOIST := {"rip": 0.3, "decap": 0.5, "snap": 0.6, "shoot": 0.3, "impale": 0.8, "stab": 0.6, "uppercut": 1.3, "slam": 1.3, "blast": 0.9}
const DURS := {"rip": 3.5, "decap": 3.0, "uppercut": 2.6, "snap": 2.7, "slam": 2.9, "impale": 3.0, "shoot": 2.7, "stab": 2.9, "blast": 2.8}
const NAMES := {"rip": "HEART RIPPED OUT", "decap": "DECAPITATION", "uppercut": "UPPERCUT", "snap": "NECK SNAP", "slam": "GROUND POUND",
	"impale": "SKEWERED", "shoot": "POINT BLANK", "stab": "STABBED TO RIBBONS", "blast": "BLOWN APART"}
const RED := Color("a01018")

var g  # the game node
var active := false
var target: Dictionary = {}
var kind := ""
var t := 0.0
var dur := 3.0
var lift := 0.0                      # hero height above the ground during leaps
var cam := {"zoom": 1.0, "yaw": 0.0, "pitch": 1.0, "focus": Vector3.ZERO}
var _fired := {}
var _dir := Vector2.RIGHT
var _from := Vector2.ZERO
var _yaw0 := 0.0
var _orbit := 0.9
var _stand := 1.0
var _pre := 0.0
var _hoist_h := 0.6
var _focus_up := 0.0
var _look_head := 0.0                # camera weight on the flying head
var _fat_t := 0.0
var _fat_name := ""
var _fat_done := false
var _flash_a := 0.0
var _gibs: Array = []                # flying bits: {n, v, w, age}
var _decor: Array = []               # nodes parented to the victim or the world that live only for the finisher
var _heart: Node3D = null
var _vein: MeshInstance3D = null
var _heart_scene: PackedScene = null
var _trail: MeshInstance3D = null
var _trail_t := -1.0
var _trail_base := 0.0
var _stump: Node3D = null
var _fountain := 0.0
var _acc := 0.0
var _spurt := 0.0
var _head_gib: Node3D = null
var _warm: Array = []
var _trail_mesh: ArrayMesh = null
var _trail_mat: StandardMaterial3D = null


func setup(game: Node3D) -> void:
	g = game
	if ResourceLoader.exists(HEART_PATH):
		_heart_scene = load(HEART_PATH) as PackedScene


## Puts one of every finisher prop on screen for a few frames behind the loading screen, so no shader compiles in the middle of a fight.
func warm_up() -> void:
	var at: Vector3 = g._p3(g.p_pos + Vector2(0, 1.5), 1.0)
	_spawn_heart(at)
	_warm.append(_heart)
	_warm.append(_vein)
	_heart = null
	_vein = null
	var tr := _make_trail()
	tr.global_position = at
	_warm.append(tr)
	_spawn_chunk(at, Vector3.ZERO, 0.05)
	_warm.append(_gibs[_gibs.size() - 1].n)
	_gibs.pop_back()
	var w := MeshInstance3D.new()
	var sm := SphereMesh.new()
	w.mesh = sm
	w.material_override = _flesh_mat(Color("3a0408"))
	g.add_child(w)
	w.global_position = at
	_warm.append(w)


func warm_done() -> void:
	for n in _warm:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_warm.clear()


func can_exec(e: Dictionary) -> bool:
	if e.dead or e.type == "fist" or e.link != null or e.exec != null or e.mode == "idle":
		return false
	if g.p_pos.distance_to(e.pos) > float(e.r) + (2.5 if e.type != "cyborg" else 16.0):
		return false
	if e.boss:
		return float(e.get("stun", 0.0)) > 0.0 and e.hp < e.max_hp * 0.1
	return float(e.daze) > 0.0


func find() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for e in g.enemies:
		if can_exec(e):
			var d: float = g.p_pos.distance_to(e.pos)
			if d < bd:
				bd = d
				best = e
	return best


# ------------------------------------------------------------------ the sequence

func start(e: Dictionary) -> void:
	active = true
	target = e
	t = 0.0
	_fired = {}
	lift = 0.0
	_from = g.p_pos
	_dir = (e.pos - g.p_pos).normalized()
	g.p_face = _dir.angle()
	_stand = float(e.r) + 0.85
	_pre = 0.0
	_cleanup()
	if e.boss:
		kind = "titan" if e.type == "cyborg" else "boss"
		dur = 6.2 if kind == "titan" else 5.4
		_orbit = 1.5
		cam.zoom = 0.85 if kind == "boss" else 1.05
		cam.pitch = 0.72
	else:
		# every weapon has its own signature finishers
		var pools := {
			"sword": ["decap", "stab", "impale"],
			"cleaver": ["slam", "uppercut", "rip"],
			"spear": ["impale", "snap", "stab"],
			"gun": ["shoot", "blast"],
		}
		var pool: Array = pools.get(g.equipped, ["decap", "stab"]).duplicate()
		if e.fig.get("quad", false):
			pool = pool.filter(func(k): return k in ["stab", "impale", "slam", "shoot", "blast"])
			if pool.is_empty():
				pool = ["stab"]
		kind = pool[randi() % pool.size()]
		_pre = 1.5
		dur = float(DURS[kind])
		_hoist_h = float(HOIST[kind])
		_stand = float(STANDS.get(kind, float(e.r) + 0.85))
		_orbit = randf_range(0.8, 1.2) * (1.0 if randf() < 0.5 else -1.0)
		cam.zoom = 0.34
		cam.pitch = 0.7
	t = -_pre
	_yaw0 = g.cam_yaw
	cam.yaw = _yaw0
	cam.focus = g.cam_focus
	e.exec = {"t": -_pre, "kind": kind, "boss": e.boss, "limp": 2.1 if kind == "boss" else 2.9, "dir": _dir, "pre": _pre}
	e.st = "held"
	e.vcd = 0.0
	g.p_act = "exec"
	g.p_act_t = 0.0
	g.p_stun = 0.0
	g.buf_atk = 0.0
	g.buf_roll = 0.0
	g.buf_sk1 = 0.0
	g.buf_sk2 = 0.0
	_fat_done = false
	_fat_name = ""
	_focus_up = 0.0
	_look_head = 0.0
	g.vox.hero_effort(true)
	g.sfx("swing", -4.0, 0.6)
	g._enemy_voice(e, "hit")
	if not e.boss:
		g.vox.play("mk_finish_him", 0.0, 1.0)


func _at(name: String, when: float) -> bool:
	if t >= when and not _fired.has(name):
		_fired[name] = true
		return true
	return false


## An event on the grab's own clock (0 = start of the lunge).
func _atp(name: String, when: float) -> bool:
	return _at(name, when - _pre)


func _slowmo(real_secs: float, scale: float = 0.3) -> void:
	Engine.time_scale = scale
	g.get_tree().create_timer(real_secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _hitstop(secs: float = 0.07) -> void:
	_slowmo(secs, 0.03)


func _flash(a: float) -> void:
	_flash_a = maxf(_flash_a, a)


## Linear 0..1 ramp on the finisher clock.
func _k(a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 0.001), 0.0, 1.0)


func _ss(a: float, b: float) -> float:
	return smoothstep(a, b, t)


## Rises between a and b, falls between c and d.
func _win(a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(c, d, t))


## Pulse centred on grab-clock time c.
func _pulse(c: float, w: float) -> float:
	return maxf(0.0, 1.0 - absf((t + _pre) - c) / w)


## Pulse centred on finisher-clock time c.
func _pf(c: float, w: float) -> float:
	return maxf(0.0, 1.0 - absf(t - c) / w)


## Called every frame by the game while p_act == "exec".
func update(dt: float) -> void:
	if not active or target.is_empty() or target.dead:
		abort()
		return
	t += dt
	var e: Dictionary = target
	e.exec.t = t
	g.p_inv = 5.0
	# stand in front of the victim (it turns to face us)
	var stand_pos: Vector2 = e.pos - _dir * _stand
	if kind == "titan":
		stand_pos = _from.lerp(_from + _dir * minf(maxf(g.p_pos.distance_to(e.pos) - float(e.r) - 1.0, 0.0), 6.0), smoothstep(0.9, 1.9, t))
	var run := (0.3 if _pre > 0.0 else 0.45) if kind != "boss" else 1.0
	g.p_pos = g.p_pos.lerp(stand_pos, clampf((t + _pre) / run, 0.0, 1.0) if kind != "titan" else 1.0)
	g.p_face = _dir.angle()
	e.face = (g.p_pos - e.pos).angle()
	e.mv = 0.0
	var mid: Vector2 = g.p_pos.lerp(e.pos, 0.5)
	cam.focus = g._p3(mid, (1.1 if not e.boss else 2.0) + _focus_up)
	if _look_head > 0.01 and _head_gib != null and is_instance_valid(_head_gib):
		cam.focus = cam.focus.lerp(_head_gib.global_position, _look_head)
	if _pre > 0.0 and t < 0.05:
		_ev_pre(e)
	_camera(smoothstep(0.0, dur, t), dt)
	match kind:
		"rip": _ev_rip(e)
		"decap": _ev_decap(e)
		"uppercut": _ev_uppercut(e)
		"snap": _ev_snap(e)
		"slam": _ev_slam(e)
		"impale": _ev_impale(e)
		"shoot": _ev_shoot(e)
		"blast": _ev_blast(e)
		"stab": _ev_stab(e)
		"boss": _ev_boss(e)
		"titan": _ev_titan(e)
	if t >= dur:
		_finish()


# ------------------------------------------------------------------ anchors on the bodies

func _hand(left: bool) -> Vector3:
	var n: Node3D = g.pfig.lelbow if left else g.pfig.elbow
	return n.to_global(Vector3(0, -0.34, 0))


func _chest(e: Dictionary) -> Vector3:
	return (e.fig.rig as Node3D).to_global(Vector3(0, 1.22, -0.08))


func _neck(e: Dictionary) -> Vector3:
	return (e.fig.rig as Node3D).to_global(Vector3(0, 1.52, 0))


func _fwd() -> Vector3:
	return Vector3(_dir.x, 0, _dir.y)


func _blood(e: Dictionary, n: int, amt: float) -> void:
	g._blood(e.pos, _dir.angle() + PI + randf_range(-0.4, 0.4), n, amt)


func _spurt_at(p: Vector3, n: int, spd: float = 4.0) -> void:
	g._burst(Vector2(p.x, p.z), n, RED, spd, p.y)


## The Mortal Kombat moment: red splash, deep announcer, shock.
func _fatality() -> void:
	if _fat_done:
		return
	_fat_done = true
	_fat_name = str(NAMES.get(kind, "FATALITY"))
	_fat_t = 2.8
	g.vox.play("mk_fatality", 3.0, 1.0)
	g.fx.pulse(0.9, 0.5)
	g.shake = maxf(g.shake, 14.0)


# ------------------------------------------------------------------ props and gore

func _flesh_mat(col: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.4
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


## Dark wound on the victim's chest or neck that stays on the body.
func _wound(e: Dictionary, local_pos: Vector3, radius: float, flat: float = 0.4) -> Node3D:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	n.mesh = sm
	n.material_override = _flesh_mat(Color("3a0408"))
	n.scale = Vector3(1.0, 1.0, flat)
	n.position = local_pos
	(e.fig.rig as Node3D).add_child(n)
	_decor.append(n)
	return n


func _spawn_heart(at: Vector3) -> void:
	if _heart != null and is_instance_valid(_heart):
		_heart.queue_free()
	if _heart_scene == null and ResourceLoader.exists(HEART_PATH):
		_heart_scene = load(HEART_PATH) as PackedScene
	if _heart_scene != null:
		_heart = _heart_scene.instantiate()
		for mi in _heart.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mi as MeshInstance3D).material_override = _flesh_mat(Color("8e1218"), 0.5)
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.17
		mi.mesh = sm
		mi.material_override = _flesh_mat(Color("8e1218"), 0.5)
		_heart = mi
	_heart.scale = Vector3.ONE * 1.6
	g.add_child(_heart)
	_heart.global_position = at
	# the strands that still tie it to the chest
	if _vein != null and is_instance_valid(_vein):
		_vein.queue_free()
	_vein = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.02
	cm.height = 1.0
	cm.radial_segments = 6
	_vein.mesh = cm
	_vein.material_override = _flesh_mat(Color("6a0a10"))
	g.add_child(_vein)


func _drop_heart(burst: bool = true) -> void:
	if _heart != null and is_instance_valid(_heart):
		if burst:
			var p := _heart.global_position
			_spurt_at(p, 36, 8.0)
			for i in 7:
				_spawn_chunk(p, Vector3(randf_range(-4, 4), randf_range(3, 8), randf_range(-4, 4)), 0.035 + randf() * 0.03)
		_heart.queue_free()
	_heart = null
	_drop_vein()


func _drop_vein() -> void:
	if _vein != null and is_instance_valid(_vein):
		_vein.queue_free()
	_vein = null


func _spawn_chunk(at: Vector3, vel: Vector3, r: float) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	n.mesh = sm
	n.material_override = _flesh_mat(Color("7a0c12"))
	g.add_child(n)
	n.global_position = at
	_gibs.append({"n": n, "v": vel, "w": Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), "age": 4.0})


## Cuts the victim's head off: it vanishes from the body, a red stump shows and the head flies away as its own tumbling object.
func _sever_head(e: Dictionary) -> void:
	var f: Dictionary = e.fig
	if f.get("headless", false) or not f.has("head"):
		return
	var head: Node3D = f.head
	var from: Vector3 = head.global_position + Vector3(0, 0.08, 0)
	f["headless"] = true
	head.scale = Vector3.ONE * 0.001
	if f.get("sk") != null:
		var sk: Skeleton3D = f.sk
		var bi := sk.find_bone("Head")
		if bi >= 0:
			sk.set_bone_pose_scale(bi, Vector3.ONE * 0.001)
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.27
	sm.radial_segments = 14
	sm.rings = 8
	n.mesh = sm
	var armored: bool = e.type in ["knight", "stonesoldier", "captain", "malakar"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("5a5e6a") if armored else (Color("8aa07a") if e.type == "zombie" else Color("c9a68c"))
	m.metallic = 0.7 if armored else 0.0
	m.roughness = 0.5
	n.material_override = m
	n.scale = Vector3(0.9, 1.05, 1.0)
	g.add_child(n)
	n.global_position = from
	var side := Vector3(-_dir.y, 0, _dir.x) * 2.5
	_gibs.append({"n": n, "v": _fwd() * 2.0 + side + Vector3(0, 6.5, 0), "w": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), "age": 0.0})
	_head_gib = n
	# the neck stump and the fountain out of it
	_stump = _wound(e, Vector3(0, 1.5, 0), 0.075, 0.5)
	_fountain = 1.7
	_spurt_at(from, 30, 8.0)


## One crescent for the slash trail, built once and reused.
func _make_trail() -> MeshInstance3D:
	if _trail_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 16
		for i in n:
			var a0 := lerpf(-1.0, 0.0, float(i) / n)
			var a1 := lerpf(-1.0, 0.0, float(i + 1) / n)
			var c0 := Color(1, 0.9, 0.85, pow(float(i) / n, 1.6))
			var c1 := Color(1, 0.9, 0.85, pow(float(i + 1) / n, 1.6))
			var p00 := Vector3(cos(a0) * 0.6, 0, sin(a0) * 0.6)
			var p01 := Vector3(cos(a0) * 1.75, 0, sin(a0) * 1.75)
			var p10 := Vector3(cos(a1) * 0.6, 0, sin(a1) * 0.6)
			var p11 := Vector3(cos(a1) * 1.75, 0, sin(a1) * 1.75)
			for v in [[p00, c0], [p01, c0], [p11, c1], [p00, c0], [p11, c1], [p10, c1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
		_trail_mesh = st.commit()
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var n3 := MeshInstance3D.new()
	n3.mesh = _trail_mesh
	n3.material_override = _trail_mat
	n3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(n3)
	return n3


## The glowing slash through the air (a crescent that sweeps round the hero at neck height).
func _start_trail(e: Dictionary) -> void:
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()
	_trail = _make_trail()
	_trail_t = 0.0
	_trail_base = -atan2(_dir.y, _dir.x)
	_trail.global_position = Vector3(g.p_pos.x, _neck(e).y, g.p_pos.y)


func _cleanup() -> void:
	for n in _decor:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_decor.clear()
	_stump = null
	_fountain = 0.0
	_head_gib = null
	_drop_heart(false)
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_trail_t = -1.0


## Always running (real time): flying gibs, the FATALITY splash, the heart in the hero's hand, the head fountain, the slash trail.
func tick(dt: float) -> void:
	_fat_t = maxf(0.0, _fat_t - dt)
	_flash_a = maxf(0.0, _flash_a - dt * 3.5)
	for gb in _gibs:
		var n: MeshInstance3D = gb.n
		gb.age += dt
		var v: Vector3 = gb.v
		v.y -= 22.0 * dt
		var pos := n.global_position + v * dt
		var ground: float = g._h(Vector2(pos.x, pos.z)) + 0.13
		if pos.y < ground:
			pos.y = ground
			if absf(v.y) > 2.0:
				g.sfx("hit", -6.0, 1.6)
				g._burst(Vector2(pos.x, pos.z), 10, RED, 4.0, 0.3)
			v.y = -v.y * 0.35
			v.x *= 0.55
			v.z *= 0.55
			gb.w = (gb.w as Vector3) * 0.5
		gb.v = v
		n.global_position = pos
		n.rotate_x((gb.w as Vector3).x * dt)
		n.rotate_z((gb.w as Vector3).z * dt)
		if gb.age < 1.6 and randf() < 0.5:
			g._burst(Vector2(pos.x, pos.z), 1, RED, 2.0, pos.y)
	for i in range(_gibs.size() - 1, -1, -1):
		if _gibs[i].age > 9.0:
			(_gibs[i].n as Node).queue_free()
			_gibs.remove_at(i)
	if active and _heart != null and is_instance_valid(_heart) and kind == "rip":
		var hp := _hand(true)
		var beat := maxf(0.0, sin(t * 17.0))
		if t > 1.05:
			_heart.global_position = hp
		else:
			_heart.global_position = _chest(target)
		_heart.scale = Vector3.ONE * (1.6 + 0.35 * beat)
		_heart.rotation.y += dt * 2.5
		_acc += dt
		if _acc > 0.08 and t > 0.62:
			_acc = 0.0
			_spurt_at(hp, 2, 2.5)
		if _vein != null and is_instance_valid(_vein):
			var a: Vector3 = _chest(target)
			var d := hp - a
			var l := maxf(d.length(), 0.05)
			var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.FORWARD
			var bas := Basis.looking_at(d.normalized() if l > 0.01 else Vector3.FORWARD, up) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(1.0, l, 1.0))
			_vein.global_transform = Transform3D(bas, a + d * 0.5)
	if _fountain > 0.0 and _stump != null and is_instance_valid(_stump):
		_fountain -= dt
		_spurt += dt
		if _spurt > 0.04:
			_spurt = 0.0
			_spurt_at(_stump.global_position, 3, 5.0)
	if _trail_t >= 0.0 and _trail != null and is_instance_valid(_trail):
		_trail_t += dt
		var k := clampf(_trail_t / 0.18, 0.0, 1.0)
		_trail.rotation.y = _trail_base + lerpf(1.7, -0.2, k)
		(_trail.material_override as StandardMaterial3D).albedo_color.a = 0.55 * clampf(1.0 - maxf(0.0, _trail_t - 0.12) / 0.25, 0.0, 1.0)
		if _trail_t > 0.4:
			_trail.queue_free()
			_trail = null
			_trail_t = -1.0


## Hands a pooled figure back its head (called when the figure is reused).
func restore_fig(fig: Dictionary) -> void:
	if fig.has("head"):
		(fig.head as Node3D).rotation = Vector3.ZERO
	if not fig.get("headless", false):
		return
	fig["headless"] = false
	if fig.has("head"):
		(fig.head as Node3D).scale = Vector3.ONE
	if fig.get("sk") != null and str(fig.get("kind", "")) != "skeleton":
		var sk: Skeleton3D = fig.sk
		var bi := sk.find_bone("Head")
		if bi >= 0:
			sk.set_bone_pose_scale(bi, Vector3.ONE)


# ------------------------------------------------------------------ camera director

func _cam_ease(zt: float, pt: float, yt: float, dt: float) -> void:
	var a := 1.0 - exp(-7.0 * maxf(dt, 0.001))
	cam.zoom = lerpf(cam.zoom, zt, a)
	cam.pitch = lerpf(cam.pitch, pt, a)
	cam.yaw = lerp_angle(cam.yaw, yt, a)


## Camera yaw (game convention) that puts the camera square on the side of the fight, in front of the victim, or behind the hero.
func _yaw_side(s: float) -> float:
	return atan2(s * _dir.y, -s * _dir.x)


func _yaw_front() -> float:
	return atan2(_dir.x, _dir.y)


func _yaw_back() -> float:
	return atan2(-_dir.x, -_dir.y)


## A shot built for every beat of the grab and of each finisher.
func _camera(u: float, dt: float) -> void:
	if target.boss:
		cam.yaw = _yaw0 + _orbit * u
		return
	var sgn := signf(_orbit)
	var side := _yaw_side(sgn)
	var base := lerp_angle(side, _yaw_front(), 0.4)
	var zt := 0.3
	var pt := 0.75
	var yt := base
	if t < 0.0:
		var p := t + _pre
		zt = lerpf(0.38, 0.27, smoothstep(0.0, 0.3, p))
		pt = lerpf(0.8, 0.6, smoothstep(0.0, 0.3, p))
		var seize := smoothstep(0.28, 0.38, p) * (1.0 - smoothstep(0.5, 0.7, p))
		var hoist := smoothstep(0.35, 0.6, p) * (1.0 - smoothstep(0.8, 0.95, p)) * (_hoist_h / 1.3)
		var butt := _pulse(0.84, 0.14)
		zt = zt - 0.09 * seize + 0.07 * hoist - 0.07 * butt
		pt = pt - 0.25 * hoist
		yt = lerp_angle(_yaw0, base, smoothstep(0.0, 0.5, p))
		_focus_up = 0.6 * hoist
	else:
		match kind:
			"rip":
				# three-quarter view, then dead side-on so the arm bursting in is clear, then the front, low, up at the heart
				var sd := _win(0.3, 0.55, 1.0, 1.2)
				var heart := _win(1.1, 1.5, 2.3, 2.7)
				zt = lerpf(0.23, 0.17, sd) + 0.03 * heart + 0.1 * _ss(2.5, 3.2)
				pt = lerpf(0.55, 0.3, sd) - 0.25 * heart + 0.4 * _ss(2.5, 3.2)
				yt = lerp_angle(lerp_angle(base, side, sd), _yaw_front(), heart * 0.75)
				_focus_up = 0.35 * sd + 0.55 * heart
			"decap":
				var close := _win(0.0, 0.3, 1.5, 2.1)
				zt = lerpf(0.26, 0.23, close) + 0.14 * _ss(1.7, 2.6)
				pt = lerpf(0.55, 0.34, close) + 0.3 * _ss(1.7, 2.6)
				yt = lerp_angle(base, side, _win(0.05, 0.45, 1.5, 2.3))
				_focus_up = 0.4 * close
				_look_head = 0.75 * _win(0.58, 0.72, 0.95, 1.3)
			"uppercut":
				var rise := _win(0.1, 0.7, 1.0, 1.3)
				var land := _win(1.25, 1.4, 1.6, 2.1)
				zt = lerpf(0.24, 0.58, rise) - 0.34 * land
				pt = lerpf(0.55, 1.05, rise) - 0.4 * land
				yt = lerp_angle(base, side, _win(0.05, 0.4, 1.9, 2.5))
				_focus_up = _up_h(t) * 0.5
			"snap":
				var close := _win(0.0, 0.3, 1.0, 1.6)
				zt = lerpf(0.27, 0.17, close) + 0.1 * _ss(1.7, 2.4)
				pt = lerpf(0.6, 0.42, close) + 0.25 * _ss(1.7, 2.4)
				yt = lerp_angle(base, side, 0.85 * close)
				_focus_up = 0.5 * close
			"slam":
				var up := _win(0.3, 0.9, 1.5, 1.7)
				var hit := _win(1.6, 1.7, 2.0, 2.5)
				zt = lerpf(0.26, 0.3, up) - 0.1 * hit
				pt = lerpf(0.6, 0.35, up) + 0.1 * hit
				yt = lerp_angle(base, side, _win(0.2, 0.7, 1.9, 2.5))
				_focus_up = 1.4 * up
			"impale":
				var heave := _win(0.3, 1.0, 1.5, 1.8)
				zt = lerpf(0.25, 0.3, heave) + 0.1 * _ss(1.6, 2.4)
				pt = lerpf(0.55, 0.3, heave) + 0.2 * _ss(1.6, 2.4)
				yt = lerp_angle(base, side, _win(0.0, 0.4, 1.8, 2.5))
				_focus_up = 1.0 * heave
			"shoot":
				var face := _win(0.1, 0.5, 0.95, 1.3)
				zt = lerpf(0.26, 0.17, face) + 0.1 * _ss(1.4, 2.2)
				pt = lerpf(0.55, 0.38, face) + 0.2 * _ss(1.4, 2.2)
				yt = lerp_angle(base, side, _win(0.1, 0.6, 1.3, 2.0))
				_focus_up = 0.2 * face
			"blast":
				var face := _win(0.1, 0.4, 1.3, 1.9)
				zt = lerpf(0.26, 0.19, face) + 0.1 * _ss(1.7, 2.5)
				pt = lerpf(0.55, 0.4, face) + 0.2 * _ss(1.7, 2.5)
				yt = lerp_angle(base, side, _win(0.05, 0.4, 1.6, 2.4))
				_focus_up = 0.7 * face
			"stab":
				var close := _win(0.0, 0.3, 1.2, 1.6)
				zt = lerpf(0.26, 0.2, close) + 0.06 * _ss(1.6, 2.4)
				pt = lerpf(0.55, 0.4, close) + 0.2 * _ss(1.6, 2.4)
				yt = lerp_angle(base, side, 0.7 * close)
				_focus_up = 0.6 * _win(1.2, 1.5, 1.8, 2.1)
			_:
				zt = 0.28
				pt = 0.7
		_look_head = _look_head if kind == "decap" else 0.0
	_cam_ease(zt, pt, yt, dt)


# ------------------------------------------------------------------ events: the grab

## The grab every finisher opens with: lunge, seize by the throat, hoist, headbutt, then jab / hook / knee. Each blow freezes the frame.
func _ev_pre(e: Dictionary) -> void:
	if _atp("lunge", 0.02):
		g.sfx("swing", -2.0, 0.6)
		g._burst(g.p_pos, 8, Color("c8b89a"), 4.0, 0.2)
	if _atp("seize", 0.3):
		g.sfx("hit", 1.0, 0.65)
		g.sfx("crumble", -6.0, 1.5)
		g.shake = maxf(g.shake, 9.0)
		g._burst(e.pos, 10, Color("ffe9b0"), 5.0, 1.5)
		g._ring(e.pos, Color("ffe9b0"), 3.0, 0.35, 0.6, "ring")
		_flash(0.3)
		g._enemy_voice(e, "hit")
		g.vox.hero_effort(true)
		_hitstop(0.09)
	if _atp("hoist", 0.4):
		g.sfx("swing", -4.0, 0.5)
	if _atp("choke", 0.62):
		g.sfx("crumble", -5.0, 0.9)
		g.shake = maxf(g.shake, 4.0)
	if _atp("headbutt", 0.84):
		g.sfx("hit", 2.0, 0.55)
		_blood(e, 20, 1.0)
		g.shake = maxf(g.shake, 12.0)
		g._burst(e.pos, 10, Color("ffe9b0"), 5.0, 1.7)
		_flash(0.35)
		_hitstop(0.08)
	if _atp("jab", 1.0):
		_combo_hit(e, 0)
	if _atp("hook", 1.16):
		_combo_hit(e, 1)
	if _atp("knee", 1.32):
		_combo_hit(e, 2)


func _combo_hit(e: Dictionary, n: int) -> void:
	_blood(e, 10 + n * 8, 0.8 + 0.3 * n)
	g.sfx("hit", -2.0 + n * 1.5, 1.05 - 0.15 * n)
	g.shake = maxf(g.shake, 6.0 + 4.0 * n)
	g._burst(e.pos, 8, Color("ffe9b0"), 5.0, 1.4)
	_flash(0.22 + 0.1 * n)
	g.vox.hero_effort(n == 2)
	if n != 1:
		g._enemy_voice(e, "hit")
	_hitstop(0.06)


# ------------------------------------------------------------------ events: the finishers

func _ev_rip(e: Dictionary) -> void:
	# step in, brace, burst a fist through the chest, grope around, wrench the heart out with its strands, show it, raise it, crush it
	if _at("brace", 0.05):
		g.sfx("swing", -3.0, 0.5)
	if _at("coil", 0.32):
		g.sfx("crumble", -6.0, 0.7)
		g.shake = maxf(g.shake, 4.0)
	if _at("punch", 0.55):
		var c := _chest(e)
		_wound(e, Vector3(0, 1.22, -0.12), 0.1, 0.45)
		_spurt_at(c + _fwd() * -0.2, 50, 7.0)
		_spurt_at(c + _fwd() * 0.3, 30, 8.0)
		_blood(e, 70, 2.0)
		g._burst(e.pos, 16, Color("e8dcc0"), 8.0, 1.5)
		g.sfx("hit", 4.0, 0.45)
		g.sfx("boom", -4.0, 1.5)
		g.sfx("crumble", -1.0, 1.1)
		g.shake = 24.0
		g.fx.pulse(0.6, 0.25)
		g.vox.hero_effort(true)
		g._enemy_voice(e, "die")
		_flash(0.65)
		_hitstop(0.18)
		_spawn_heart(c)
	if _at("crunch", 0.82):
		g.sfx("crumble", 0.0, 0.6)
		g.shake = maxf(g.shake, 9.0)
		_spurt_at(_chest(e), 20, 6.0)
	if _at("grip", 1.0):
		g.sfx("crumble", -2.0, 0.5)
		g.sfx("swing", -4.0, 0.4)
		g.shake = maxf(g.shake, 8.0)
	if _at("rip", 1.1):
		g.sfx("hit", 4.0, 0.4)
		g.sfx("swing", -1.0, 0.5)
		_spurt_at(_chest(e), 80, 9.0)
		_blood(e, 90, 2.3)
		g.shake = 26.0
		g.vox.hero_effort(true)
		_flash(0.85)
		_fatality()
		_slowmo(0.75, 0.2)
	if _at("snap", 1.32):
		# the strands tear
		_drop_vein()
		_spurt_at(_hand(true), 30, 6.0)
		g.sfx("crumble", -3.0, 1.4)
	if _at("raise", 1.95):
		g.sfx("swing", -4.0, 0.5)
	if _at("crush", 2.45):
		g.sfx("boom", -2.0, 1.4)
		g.sfx("hit", 1.0, 0.7)
		g.sfx("crumble", -2.0, 0.8)
		_drop_heart(true)
		_blood(e, 60, 1.9)
		g.shake = 18.0
		_flash(0.5)
		_hitstop(0.12)
	if _at("end", 3.3):
		_kill()


func _ev_decap(e: Dictionary) -> void:
	# haul the head back by the hair, draw the blade, one spinning slash: the head flies off and the headless body spurts, sways, buckles and falls
	if _at("grab", 0.0):
		g.sfx("hit", -3.0, 0.8)
	if _at("pull", 0.22):
		g.sfx("crumble", -5.0, 0.8)
		g.shake = maxf(g.shake, 5.0)
	if _at("wind", 0.4):
		g.sfx("swing", -3.0, 0.45)
	if _at("slash", 0.48):
		g.sfx("swing", 3.0, 0.8)
		_start_trail(e)
		g.shake = maxf(g.shake, 8.0)
	if _at("cut", 0.57):
		g.sfx("hit", 4.0, 0.55)
		g.sfx("crumble", -2.0, 1.8)
		g.shake = 24.0
		g.fx.pulse(0.6, 0.25)
		g.vox.hero_effort(true)
		g._enemy_voice(e, "die")
		_sever_head(e)
		_blood(e, 70, 1.7)
		_flash(0.85)
		_fatality()
		_hitstop(0.14)
	if _at("slowmo", 0.72):
		_slowmo(0.9, 0.22)
	if _at("buckle", 1.3):
		g.sfx("crumble", -4.0, 0.7)
	if _at("flick", 1.45):
		_spurt_at(_hand(false), 12, 5.0)
		g.sfx("swing", -4.0, 1.2)
	if _at("thud", 2.05):
		g.sfx("boom", -4.0, 1.4)
		g.shake = maxf(g.shake, 8.0)
		_blood(e, 40, 1.5)
	if _at("end", 2.7):
		_kill()


## Height of the uppercut victim above its start: it flies up spinning, hangs, is hammered down and crashes.
func _up_h(ft: float) -> float:
	var u := ft - 0.25
	if u <= 0.0:
		return 0.0
	if u < 0.72:
		var q := (0.72 - u) / 0.72
		return 6.5 * (1.0 - q * q)
	if u < 0.82:
		return 6.5
	if u < 1.1:
		var k := (u - 0.82) / 0.28
		return 6.5 * (1.0 - k * k)
	return 0.0


func _ev_uppercut(e: Dictionary) -> void:
	# coil, rising fist launches the victim skyward, the hero leaps after it, hammers it down with both fists, lands as it crashes
	lift = _up_h(t) * 0.45
	if _at("coil", 0.0):
		g.sfx("crumble", -6.0, 0.6)
		g._burst(g.p_pos, 10, Color("c8b89a"), 5.0, 0.2)
	if _at("wind", 0.15):
		g.sfx("swing", -3.0, 0.5)
	if _at("hit", 0.25):
		_blood(e, 60, 1.7)
		g.sfx("hit", 4.0, 0.5)
		g.sfx("boom", -3.0, 1.3)
		g.shake = 22.0
		g.fx.pulse(0.7, 0.3)
		g.vox.hero_effort(true)
		g._enemy_voice(e, "hit")
		g._ring(g.p_pos, Color("ffe9b0"), 6.0, 0.5, 0.7, "ring")
		_flash(0.75)
		_fatality()
		_hitstop(0.16)
	if _at("slowmo", 0.45):
		_slowmo(0.7, 0.3)
	if _at("apex", 0.95):
		g._burst(e.pos, 28, Color("c4392d"), 6.0, 5.0)
		g.sfx("swing", -4.0, 0.4)
	if _at("hammer", 1.03):
		_blood(e, 50, 1.8)
		g.sfx("hit", 4.0, 0.45)
		g.sfx("boom", 0.0, 1.0)
		g.shake = 24.0
		g.fx.strike(_neck(e) + Vector3(0, 3.0, 0))
		_flash(0.6)
		_hitstop(0.12)
	if _at("slam", 1.35):
		g.sfx("boom", 3.0, 0.75)
		g.sfx("hit", 3.0, 0.5)
		g.sfx("crumble", -2.0, 1.0)
		g.shake = 28.0
		g._ring(e.pos, Color("c4392d"), 10.0, 0.7, 0.7, "ring")
		g._burst(e.pos, 50, RED, 11.0, 0.3)
		_blood(e, 90, 2.2)
		g.fx.pulse(0.8, 0.3)
		_flash(0.6)
		_hitstop(0.12)
	if _at("bounce", 1.6):
		g.sfx("hit", -2.0, 0.7)
		g.shake = maxf(g.shake, 8.0)
		g._burst(e.pos, 14, RED, 5.0, 0.4)
	if _at("end", 2.4):
		_kill()


func _ev_snap(e: Dictionary) -> void:
	# both hands clamp the head, slow twisting strain, one violent wrench, the corpse is shoved away
	if _at("grip", 0.0):
		g.sfx("hit", -2.0, 0.7)
	if _at("strain", 0.35):
		g.sfx("crumble", -5.0, 0.8)
		g.shake = maxf(g.shake, 4.0)
	if _at("strain2", 0.65):
		g.sfx("crumble", -3.0, 0.65)
		g.shake = maxf(g.shake, 7.0)
		g._enemy_voice(e, "hit")
	if _at("wrench", 0.95):
		g.sfx("swing", 0.0, 0.7)
	if _at("crack", 1.02):
		g.sfx("hit", 4.0, 2.2)
		g.sfx("crumble", 0.0, 1.8)
		g.sfx("boom", -6.0, 1.7)
		g.shake = 20.0
		g._burst(e.pos, 16, Color("e8dcc0"), 6.0, 1.8)
		g._blood(e.pos, _dir.angle(), 14, 0.8)
		g.vox.hero_effort(true)
		_flash(0.7)
		_fatality()
		_hitstop(0.15)
		_slowmo(0.5, 0.25)
	if _at("shove", 1.3):
		g.sfx("swing", -1.0, 0.8)
		g.shake = maxf(g.shake, 7.0)
	if _at("thud", 1.7):
		g.sfx("boom", -3.0, 1.4)
		g._burst(e.pos, 14, Color("8a6a4a"), 5.0, 0.2)
	if _at("end", 2.5):
		_kill()


func _ev_slam(e: Dictionary) -> void:
	# crouch, hoist the victim overhead, whirl round with it, slam it into the ground
	if _at("crouch", 0.0):
		g.sfx("crumble", -6.0, 0.6)
	if _at("lift", 0.4):
		g.sfx("swing", -3.0, 0.5)
		g.vox.hero_effort(true)
	if _at("whirl", 0.95):
		g.sfx("swing", -2.0, 0.45)
	if _at("whirl2", 1.25):
		g.sfx("swing", -2.0, 0.5)
		g.shake = maxf(g.shake, 6.0)
	if _at("slam", 1.62):
		g.sfx("boom", 0.0, 1.0)
		g.sfx("hit", 4.0, 0.5)
		g.sfx("crumble", -2.0, 1.1)
		g.shake = 26.0
		g._ring(e.pos, Color("ff7a30"), 10.0, 0.7, 0.7, "ring")
		g._burst(e.pos, 44, Color("ff7a30"), 12.0, 0.3)
		_blood(e, 70, 2.0)
		g.fx.pulse(0.7, 0.35)
		g.vox.hero_effort(true)
		g._enemy_voice(e, "die")
		_flash(0.7)
		_fatality()
		_hitstop(0.14)
		_slowmo(0.5, 0.3)
	if _at("bounce", 1.85):
		g.sfx("hit", -2.0, 0.6)
		g._burst(e.pos, 14, RED, 5.0, 0.3)
	if _at("end", 2.7):
		_kill()


func _ev_impale(e: Dictionary) -> void:
	# run the blade through, heave the victim up on it, swing it round, fling it off
	if _at("thrust", 0.12):
		_blood(e, 40, 1.4)
		g.sfx("hit", 3.0, 0.55)
		g.sfx("crumble", -3.0, 1.3)
		g.shake = 18.0
		g.fx.pulse(0.5, 0.25)
		g.vox.hero_effort(true)
		g._enemy_voice(e, "hit")
		_flash(0.6)
		_fatality()
		_hitstop(0.16)
	if _at("heave", 0.5):
		g.sfx("swing", -2.0, 0.6)
		g.vox.hero_effort(true)
	if _at("drip", 0.9):
		_spurt_at(_neck(e) - Vector3(0, 0.6, 0), 16, 3.0)
	if _at("swing", 1.15):
		g.sfx("swing", -1.0, 0.5)
		g.shake = maxf(g.shake, 8.0)
	if _at("fling", 1.58):
		g.sfx("bolt", -4.0, 0.5)
		g.sfx("swing", 1.0, 0.7)
		_blood(e, 50, 1.8)
		g.shake = 16.0
		_flash(0.4)
	if _at("land", 2.15):
		g.sfx("boom", -2.0, 1.2)
		g.shake = 14.0
		_blood(e, 40, 1.5)
		g._burst(e.pos + _dir * 7.0, 20, RED, 7.0, 0.3)
	if _at("end", 2.8):
		_kill()


func _ev_shoot(e: Dictionary) -> void:
	# drive the victim to its knees, draw the pistol, press it to the forehead, a long breath... BANG
	if _at("drive", 0.0):
		g.sfx("hit", 0.0, 0.7)
		g.shake = maxf(g.shake, 8.0)
	if _at("kneel", 0.3):
		g.sfx("boom", -6.0, 1.6)
	if _at("draw", 0.45):
		g.sfx("swing", -4.0, 1.3)
		g.sfx("chime", -14.0, 1.2)
	if _at("press", 0.8):
		g.sfx("crumble", -8.0, 2.0)
	if _at("bang", 1.25):
		var hp := _neck(e) + Vector3(0, 0.1, 0)
		g.sfx("bolt", 2.0, 1.6)
		g.sfx("hit", 3.0, 0.65)
		g.sfx("boom", -2.0, 1.4)
		_sever_head_burst(e)
		g._burst(Vector2(hp.x, hp.z), 50, RED, 9.0, hp.y)
		_blood(e, 60, 1.8)
		g._burst(g.p_pos + _dir * 0.9, 12, Color("ffd070"), 5.0, 1.5)
		g.fx.pulse(0.7, 0.25)
		g.shake = 24.0
		_flash(0.9)
		_fatality()
		_hitstop(0.14)
		_slowmo(0.7, 0.25)
	if _at("kick", 1.75):
		g.sfx("swing", -2.0, 0.8)
		g.sfx("hit", 0.0, 0.8)
		g.shake = maxf(g.shake, 9.0)
	if _at("end", 2.6):
		_kill()


## The head disappears in a red mist (no flying head), leaving a stump that spurts.
func _sever_head_burst(e: Dictionary) -> void:
	var f: Dictionary = e.fig
	if f.get("headless", false) or not f.has("head"):
		return
	f["headless"] = true
	(f.head as Node3D).scale = Vector3.ONE * 0.001
	if f.get("sk") != null:
		var sk: Skeleton3D = f.sk
		var bi := sk.find_bone("Head")
		if bi >= 0:
			sk.set_bone_pose_scale(bi, Vector3.ONE * 0.001)
	var p := _neck(e)
	for i in 8:
		_spawn_chunk(p + Vector3(0, 0.1, 0), Vector3(randf_range(-5, 5), randf_range(3, 8), randf_range(-5, 5)) + _fwd() * -2.0, 0.03 + randf() * 0.04)
	_stump = _wound(e, Vector3(0, 1.5, 0), 0.08, 0.5)
	_fountain = 1.2


func _ev_blast(e: Dictionary) -> void:
	# hoisted by the throat, the revolver pressed to the chest, three shots point blank, the corpse dropped, the gun twirled
	if _at("press", 0.1):
		g.sfx("chime", -12.0, 1.3)
		g.sfx("crumble", -8.0, 2.0)
	for i in 3:
		if _at("b%d" % i, 0.42 + i * 0.24):
			var c := _chest(e)
			g.sfx("bolt", 2.0, 1.5 - 0.1 * i)
			g.sfx("hit", 3.0, 0.65)
			g.sfx("boom", -4.0, 1.5)
			_spurt_at(c + _fwd() * 0.45, 50, 9.0)
			_spurt_at(c - _fwd() * 0.2, 20, 6.0)
			_blood(e, 50, 1.6)
			_wound(e, Vector3(randf_range(-0.08, 0.08), 1.2 + 0.08 * i, -0.12), 0.07, 0.45)
			g._burst(Vector2(_hand(false).x, _hand(false).z), 8, Color("ffd070"), 5.0, _hand(false).y)
			g.shake = 16.0 + 6.0 * i
			g.fx.pulse(0.5, 0.2)
			g.vox.hero_effort(i == 2)
			g._enemy_voice(e, "hit")
			_flash(0.55 + 0.1 * i)
			if i == 2:
				_fatality()
				_slowmo(0.7, 0.22)
			_hitstop(0.08 + 0.03 * i)
	if _at("smoke", 1.2):
		var hp := _hand(false)
		for k in 3:
			g._burst(Vector2(hp.x, hp.z), 6, Color("cfcfcf"), 2.0, hp.y + 0.2 * k)
	if _at("drop", 1.4):
		g.sfx("crumble", -4.0, 0.7)
		g.shake = maxf(g.shake, 8.0)
	if _at("thud", 1.85):
		g.sfx("boom", -3.0, 1.4)
		g._burst(e.pos, 14, Color("8a6a4a"), 5.0, 0.2)
	if _at("twirl", 1.7):
		g.sfx("swing", -3.0, 1.5)
	if _at("end", 2.6):
		_kill()


func _ev_stab(e: Dictionary) -> void:
	# three rapid stabs, a twist of the blade, a kick that sends the victim flying
	if _at("brace", 0.0):
		g.sfx("swing", -3.0, 0.6)
	for i in 3:
		if _at("s%d" % i, 0.3 + i * 0.28):
			_blood(e, 26 + i * 8, 1.1 + 0.2 * i)
			g.sfx("hit", 1.0 + i, 0.7 - 0.08 * i)
			g.vox.hero_effort(i == 2)
			g.shake = maxf(g.shake, 9.0 + 3.0 * i)
			g._burst(e.pos, 8, Color("ffe9b0"), 5.0, 1.2)
			_flash(0.3 + 0.1 * i)
			if i == 0:
				_fatality()
			if i != 1:
				g._enemy_voice(e, "hit")
			_hitstop(0.07 + 0.02 * i)
	if _at("twist", 1.3):
		g.sfx("crumble", -2.0, 0.8)
		g.sfx("hit", 2.0, 0.5)
		_blood(e, 40, 1.6)
		g.shake = 13.0
		_hitstop(0.1)
	if _at("kick", 1.82):
		g.sfx("swing", -1.0, 0.7)
		g.sfx("bolt", -8.0, 0.6)
		g.sfx("hit", 3.0, 0.6)
		g._burst(e.pos, 22, Color("c4392d"), 8.0, 1.2)
		g.shake = 14.0
		_flash(0.4)
		_hitstop(0.1)
	if _at("land", 2.3):
		g.sfx("boom", -3.0, 1.3)
		g.shake = maxf(g.shake, 10.0)
		_blood(e, 30, 1.4)
	if _at("end", 2.8):
		_kill()


func _ev_boss(e: Dictionary) -> void:
	# sprint up, leap, plunge the blade through the head, twist, wrench it out
	if _at("leap", 1.05):
		g.sfx("swing", -2.0, 0.5)
	lift = sin(clampf((t - 1.05) / 0.85, 0.0, 1.0) * PI) * (1.6 if e.type != "demon" else 2.0)
	if _at("plunge", 1.95):
		_blood(e, 70, 2.0)
		g.sfx("boom", 0.0, 1.1)
		g.sfx("hit", 3.0, 0.45)
		g.shake = 22.0
		g.fx.strike(g._p3(e.pos))
		g.vox.hero_effort(true)
		g._enemy_voice(e, "hit")
		_flash(0.7)
		_hitstop(0.15)
		_slowmo(0.45, 0.25)
	if _at("twist", 2.5):
		g.sfx("crumble", -2.0, 0.7)
		_blood(e, 40, 1.6)
		g.shake = 14.0
	if _at("roar", 3.0):
		g.sfx("roar", 0.0, 0.6)
		g.fx.pulse(0.7, 0.5)
		g._ring(e.pos, Color("ff6a3a"), 14.0, 1.1, 0.7, "ring")
		g.shake = 18.0
	if _at("out", 3.7):
		g.sfx("hit", 1.0, 0.5)
		_blood(e, 60, 2.2)
		g.shake = 16.0
		_flash(0.5)
	if _at("end", 4.5):
		_kill()


func _ev_titan(e: Dictionary) -> void:
	lift = sin(clampf((t - 1.7) / 1.1, 0.0, 1.0) * PI) * 7.0 if t < 2.8 else 0.0
	if _at("leap", 1.7):
		g.sfx("swing", -1.0, 0.45)
		g.vox.hero_effort(true)
	if _at("plunge", 2.8):
		g.sfx("boom", 2.0, 0.8)
		g.fx.strike(g._p3(e.pos, 3.0))
		g.shake = 24.0
		g.fx.pulse(1.0, 0.6)
		g._burst(e.pos, 80, Color("30e0ff"), 16.0, 4.0)
		_flash(0.8)
		_hitstop(0.16)
		_slowmo(0.5, 0.25)
	if _at("arc", 3.6):
		g.fx.strike(g._p3(e.pos + Vector2(2, 0), 2.0))
		g._burst(e.pos, 50, Color.WHITE, 12.0, 3.0)
		g.shake = 20.0
		_flash(0.6)
	if _at("end", 4.6):
		_kill()


func _kill() -> void:
	if target.is_empty() or target.dead:
		return
	var e: Dictionary = target
	if e.boss:
		e.hp = 0.0
	else:
		_fatality()
	_drop_heart(true)
	_trail_t = 0.5
	g._kill_enemy(e, true)


func _finish() -> void:
	if not target.is_empty():
		target.exec = null
	if not target.is_empty() and not target.dead:
		_kill()
	abort()


func abort() -> void:
	if not target.is_empty() and target.exec != null:
		target.exec = null
	active = false
	target = {}
	lift = 0.0
	_look_head = 0.0
	Engine.time_scale = 1.0
	_decor.clear()  # wounds live on the (pooled) figure's rig; they are removed when the figure is reused
	if g.p_act == "exec":
		g.p_act = "idle"
		g.p_inv = 0.6


# ------------------------------------------------------------------ the hero's body

func _hero_nodes(f: Dictionary) -> Array:
	return [f.arm, f.elbow, f.larm, f.lelbow, f.body, f.legs[0], f.legs[1], f.knees[0], f.knees[1], f.sword]


func _foe_nodes(f: Dictionary) -> Array:
	var n: Array = [f.body, f.arm, f.elbow, f.larm, f.lelbow, f.legs[0], f.legs[1], f.knees[0], f.knees[1]]
	if f.has("head"):
		n.append(f.head)
	return n


func _snap(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		out.append((n as Node3D).rotation)
	return out


func _blend(nodes: Array, saved: Array, k: float) -> void:
	for i in nodes.size():
		(nodes[i] as Node3D).rotation = ((nodes[i] as Node3D).rotation).lerp(saved[i], k)


## The grab: lunge with both hands out, clamp the throat, hoist, headbutt, then jab / hook / knee.
func _pose_pre(f: Dictionary, p: float) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var dash := smoothstep(0.0, 0.28, p)
	var hold := smoothstep(0.28, 0.34, p)
	var hoist := smoothstep(0.34, 0.6, p) * (1.0 - smoothstep(0.74, 0.86, p)) * clampf(_hoist_h / 1.3, 0.35, 1.0)
	var butt := maxf(0.0, 1.0 - absf(p - 0.84) / 0.1)
	var jab := maxf(0.0, 1.0 - absf(p - 1.0) / 0.1)
	var hook := maxf(0.0, 1.0 - absf(p - 1.16) / 0.1)
	var knee := maxf(0.0, 1.0 - absf(p - 1.32) / 0.12)
	var relax := smoothstep(0.88, 1.0, p)
	var rx := lerpf(0.4, 1.45, dash) + 0.6 * hoist
	var ex := lerpf(1.2, 0.7, dash) - 0.35 * hoist + 0.7 * butt
	larm.rotation = Vector3(rx * (1.0 - relax) + (1.0 + 0.55 * jab) * relax, lerpf(0.3, 0.0, hold) * (1.0 - relax) + 0.15 * relax, 0)
	lelbow.rotation.x = ex * (1.0 - relax) + (0.9 - 0.8 * jab) * relax
	arm.rotation = Vector3(rx * (1.0 - relax) + (1.2 + 0.2 * hook) * relax, (-0.3 * (1.0 - hold)) * (1.0 - relax) + (-1.0 * (1.0 - hook) + 0.6 * hook) * relax, 0)
	elbow.rotation.x = ex * (1.0 - relax) + (0.9 - 0.5 * hook) * relax
	f.sword.rotation.x = -0.5
	body.rotation = Vector3(0.08 + 0.12 * dash - 0.28 * hoist + 0.6 * butt + 0.14 * knee, 0.35 * jab - 0.5 * hook, 0)
	legs[0].rotation.x = (-0.9 * (1.0 - dash) - 0.55 * dash) * (1.0 - relax) + (-0.4 * (1.0 - knee)) * relax
	legs[1].rotation.x = (0.9 * (1.0 - dash) + 0.45 * dash) * (1.0 - relax) + (0.4 * (1.0 - knee) + 1.3 * knee) * relax
	knees[0].rotation.x = -0.45 * hoist - 0.2 * butt
	knees[1].rotation.x = -0.45 * hoist - 1.4 * knee


## The hero's body during the grab and the finisher (called after the normal pose has been set).
func pose_player(f: Dictionary) -> void:
	lift = lift if (kind == "boss" or kind == "titan" or kind == "uppercut") else 0.0
	if t < 0.0:
		_pose_pre(f, t + _pre)
		return
	var nodes := _hero_nodes(f)
	var saved: Array = []
	if _pre > 0.0 and t < 0.2:
		_pose_pre(f, _pre)
		saved = _snap(nodes)
	match kind:
		"rip": _hero_rip(f)
		"decap": _hero_decap(f)
		"uppercut": _hero_uppercut(f)
		"snap": _hero_snap(f)
		"slam": _hero_slam(f)
		"impale": _hero_impale(f)
		"shoot": _hero_shoot(f)
		"blast": _hero_blast(f)
		"stab": _hero_stab(f)
		"boss": _hero_boss(f)
		"titan": _hero_titan(f)
	if not saved.is_empty():
		_blend(nodes, saved, 1.0 - smoothstep(0.0, 0.2, t))


func _hero_rip(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var wind := _k(0.0, 0.5)
	var punch := _k(0.5, 0.58)
	var inside := _win(0.58, 0.6, 1.0, 1.05)
	var pull := _k(1.0, 1.25)
	var raise := _k(1.9, 2.3)
	var crush := _k(2.4, 2.5)
	var lower := _k(2.7, 3.2)
	# right hand pins the victim by the shoulder
	arm.rotation = Vector3(lerpf(1.5, 0.9, pull), -0.25, 0.0)
	elbow.rotation.x = lerpf(0.45, 1.2, pull)
	f.sword.rotation.x = -0.5
	# left arm: cocked back, bursts in, gropes about, wrenches out, shows, raises, crushes
	var lx := lerpf(1.0, -0.55, wind)
	lx = lerpf(lx, 1.75, punch)
	lx += 0.07 * sin(t * 44.0) * inside
	lx = lerpf(lx, 1.15, pull)
	lx = lerpf(lx, 3.05, raise)
	lx = lerpf(lx, 1.0, crush)
	lx = lerpf(lx, 0.45, lower)
	var le := lerpf(0.9, 1.95, wind)
	le = lerpf(le, 0.05, punch)
	le += 0.06 * sin(t * 37.0) * inside
	le = lerpf(le, 1.5, pull)
	le = lerpf(le, 0.55, raise)
	le = lerpf(le, 1.35, crush)
	le = lerpf(le, 0.5, lower)
	larm.rotation = Vector3(lx, 0.08, 0.0)
	lelbow.rotation.x = le
	body.rotation = Vector3(0.1 + 0.3 * punch * (1.0 - pull) - 0.3 * pull * (1.0 - raise) - 0.45 * raise * (1.0 - crush) + 0.4 * crush * (1.0 - lower) + 0.03 * sin(t * 40.0) * inside,
		lerpf(0.0, -0.55, wind) * (1.0 - punch) + 0.15 * punch, 0)
	legs[0].rotation.x = -0.7 + 0.25 * punch
	legs[1].rotation.x = 0.55 - 0.15 * wind
	knees[0].rotation.x = -0.5 * (wind * (1.0 - punch) + 0.5 * punch)
	knees[1].rotation.x = -0.45 * wind


func _hero_decap(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var grab := _k(0.0, 0.25)
	var wnd := _k(0.25, 0.48)
	var slash := _k(0.48, 0.62)
	var flick := _k(1.3, 1.6)
	var rest := _k(1.9, 2.6)
	# left hand drags the head back by the hair, then lets go at the cut
	larm.rotation = Vector3(lerpf(1.0, 2.0, grab) * (1.0 - slash) + 0.55 * slash, 0.1, 0)
	lelbow.rotation.x = lerpf(0.9, 0.5, grab) * (1.0 - slash) + 0.6 * slash
	# right arm: blade drawn back across the body, then a full sweep, follow-through, blood flick, rest
	var yaw := lerpf(-0.2, -1.6, wnd) * (1.0 - slash) + lerpf(-1.6, 1.75, slash) * slash
	yaw = lerpf(yaw, 0.5, flick)
	arm.rotation = Vector3(1.45 - 0.2 * slash + 0.5 * flick + 0.04 * sin(t * 30.0) * _win(0.62, 0.7, 1.2, 1.4) - 0.8 * rest, yaw * (1.0 - rest), 0)
	elbow.rotation.x = lerpf(1.0, 0.2, wnd) * (1.0 - flick) + 0.9 * flick
	f.sword.rotation.x = lerpf(-0.5, -1.4, wnd) * (1.0 - rest) - 0.5 * rest
	body.rotation = Vector3(0.12 + 0.12 * slash * (1.0 - flick), (lerpf(0.0, -0.9, wnd) * (1.0 - slash) + 0.95 * slash) * (1.0 - flick * 0.8), 0)
	legs[0].rotation.x = -0.7 * wnd * (1.0 - slash) + 0.65 * slash * (1.0 - rest)
	legs[1].rotation.x = 0.5 * wnd * (1.0 - slash) - 0.5 * slash * (1.0 - rest)
	knees[0].rotation.x = -0.55 * wnd * (1.0 - slash)
	knees[1].rotation.x = -0.3 * slash * (1.0 - flick)
	lift = 0.2 * sin(slash * PI)


func _hero_uppercut(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var crouch := _k(0.0, 0.22)
	var swing := _k(0.22, 0.3)
	var air := _win(0.3, 0.5, 1.0, 1.1)
	var hammer := _k(0.98, 1.08)
	var land := _win(1.3, 1.38, 1.5, 2.0)
	# uppercut arm: low coil, then straight up; in the air both fists high, then hammer down
	larm.rotation = Vector3((lerpf(1.0, -0.8, crouch) * (1.0 - swing) + 3.1 * swing) * (1.0 - hammer) + 0.5 * hammer, 0.0, 0)
	lelbow.rotation.x = lerpf(1.2, 0.3, swing) * (1.0 - hammer) + 0.2 * hammer
	arm.rotation = Vector3((0.5 + 0.9 * swing + 1.4 * air) * (1.0 - hammer) + 0.4 * hammer, -0.2, 0)
	elbow.rotation.x = 1.2 * (1.0 - air) + 0.3 * air
	body.rotation = Vector3(0.35 * crouch * (1.0 - swing) - 0.45 * swing * (1.0 - hammer) + 0.7 * hammer * (1.0 - land) + 0.5 * land, 0.3 * swing * (1.0 - hammer), 0)
	legs[0].rotation.x = -0.7 * crouch * (1.0 - swing) + 0.95 * air
	legs[1].rotation.x = 0.6 * crouch * (1.0 - swing) + 0.35 * air
	knees[0].rotation.x = -1.2 * crouch * (1.0 - swing) - 1.3 * air - 1.0 * land
	knees[1].rotation.x = -0.7 * crouch * (1.0 - swing) - 0.9 * air - 1.0 * land


func _hero_snap(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var grip := _k(0.0, 0.3)
	var strain := _k(0.3, 0.95)
	var wrench := _k(0.95, 1.05)
	var shove := _k(1.3, 1.45)
	var rest := _k(1.8, 2.4)
	var shake := sin(t * 34.0) * 0.05 * strain * (1.0 - wrench)
	# both hands clamped round the head
	larm.rotation = Vector3((lerpf(1.0, 2.05, grip) + shake) * (1.0 - shove) + 1.5 * shove - 0.5 * rest, 0.45 * grip * (1.0 - shove), 0)
	lelbow.rotation.x = lerpf(0.9, 0.9, grip) * (1.0 - shove) + 0.2 * shove
	arm.rotation = Vector3((lerpf(1.2, 2.05, grip) - shake) * (1.0 - shove) + 1.5 * shove - 0.5 * rest, -0.45 * grip * (1.0 - shove), 0)
	elbow.rotation.x = 0.9 * (1.0 - shove) + 0.2 * shove
	f.sword.rotation.x = -0.5
	# slow strain, then a violent twist of the whole body
	body.rotation = Vector3(0.12 + 0.1 * strain - 0.05 * rest, (0.4 * strain * (1.0 - wrench) - 1.35 * wrench) * (1.0 - shove) - 0.6 * shove * (1.0 - rest), 0)
	legs[0].rotation.x = -0.45 * grip
	legs[1].rotation.x = 0.45 * grip
	knees[0].rotation.x = -0.35 * strain
	knees[1].rotation.x = -0.35 * strain


func _hero_slam(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var crouch := _win(0.0, 0.2, 0.3, 0.5)
	var hoist := _k(0.3, 0.9)
	var spin := _k(0.9, 1.6)
	var slam := _k(1.6, 1.72)
	var rest := _k(2.1, 2.6)
	var ax := lerpf(1.2, 3.0, hoist) * (1.0 - slam) + 0.5 * slam
	ax = lerpf(ax, 0.3, rest)
	arm.rotation = Vector3(ax, 0.05, 0)
	larm.rotation = Vector3(ax, -0.05, 0)
	elbow.rotation.x = 0.35 * (1.0 - slam) + 0.15 * slam
	lelbow.rotation.x = 0.35 * (1.0 - slam) + 0.15 * slam
	f.sword.rotation.x = -0.15
	body.rotation = Vector3(0.2 * crouch - 0.32 * hoist * (1.0 - slam) + 0.6 * slam * (1.0 - rest), spin * TAU * (1.0 - slam), 0)
	legs[0].rotation.x = -0.5 * crouch - 0.45 * hoist * (1.0 - slam) + 0.5 * slam
	legs[1].rotation.x = 0.5 * crouch + 0.45 * hoist * (1.0 - slam) - 0.5 * slam
	knees[0].rotation.x = -1.0 * crouch - 0.4 * slam
	knees[1].rotation.x = -0.8 * crouch - 0.4 * slam


func _hero_impale(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var thrust := _k(0.0, 0.16)
	var heave := _k(0.45, 1.1)
	var turn := _k(1.1, 1.55)
	var fling := _k(1.55, 1.66)
	var rest := _k(2.1, 2.7)
	# two hands on the hilt, the blade out front
	var ax := (lerpf(1.2, 1.5, thrust) + 0.8 * heave) * (1.0 - fling) + 1.2 * fling
	ax = lerpf(ax, 0.5, rest)
	arm.rotation = Vector3(ax, 0.0, 0)
	larm.rotation = Vector3(ax - 0.1, 0.2, 0)
	elbow.rotation.x = lerpf(1.4, 0.15, thrust) * (1.0 - heave) + 0.5 * heave
	lelbow.rotation.x = lerpf(1.2, 0.3, thrust) * (1.0 - heave) + 0.6 * heave
	f.sword.rotation.x = lerpf(-0.5, -1.5, thrust) * (1.0 - fling * 0.4)
	body.rotation = Vector3(0.1 + 0.3 * thrust * (1.0 - heave) - 0.35 * heave * (1.0 - fling) + 0.4 * fling * (1.0 - rest),
		(turn * 2.2) * (1.0 - fling) - 0.6 * fling * (1.0 - rest), 0)
	legs[0].rotation.x = -0.8 * thrust * (1.0 - fling)
	legs[1].rotation.x = 0.65 * thrust * (1.0 - fling)
	knees[0].rotation.x = -0.45 * heave * (1.0 - fling)
	knees[1].rotation.x = -0.35 * heave * (1.0 - fling)


func _hero_shoot(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var drive := _k(0.0, 0.3)
	var draw := _k(0.4, 0.6)
	var kick := _k(1.7, 1.85)
	var recoil := _pf(1.27, 0.12)
	var rest := _k(2.0, 2.5)
	# left hand pushes the head down, right hand draws the pistol to the forehead and holds it there
	larm.rotation = Vector3(lerpf(1.0, 1.9, drive) * (1.0 - rest) + 0.4 * rest, 0.2, 0)
	lelbow.rotation.x = 0.5
	arm.rotation = Vector3(lerpf(1.2, 1.12, draw) + 0.55 * recoil, 0, 0) if rest < 1.0 else Vector3(0.5, 0, 0)
	elbow.rotation.x = lerpf(0.9, 0.12, draw) * (1.0 - rest) + 0.9 * rest
	f.sword.rotation.x = -1.45
	var tremble := sin(t * 45.0) * 0.012 * _win(0.6, 0.9, 1.2, 1.25)
	arm.rotation.x += tremble
	body.rotation = Vector3(0.12 + 0.22 * drive * (1.0 - draw) - 0.2 * recoil + 0.25 * kick * (1.0 - rest), 0, 0)
	legs[0].rotation.x = -0.5 * drive + 1.2 * kick * (1.0 - rest)
	legs[1].rotation.x = 0.5 * drive - 0.2 * kick
	knees[0].rotation.x = -0.5 * drive * (1.0 - kick) - 0.9 * kick * (1.0 - rest)
	knees[1].rotation.x = -0.4 * drive
	f.muzzle.visible = t > 1.25 and t < 1.33


func _hero_blast(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var draw := _k(0.0, 0.2)
	var recoil := 0.0
	for i in 3:
		recoil = maxf(recoil, _pf(0.42 + i * 0.24, 0.09))
	var release := _k(1.3, 1.5)
	var twirl := _k(1.7, 2.3)
	# left hand holds the victim up by the throat, right hand presses the revolver into the chest and bucks with every shot
	larm.rotation = Vector3((lerpf(1.0, 1.85, draw)) * (1.0 - release) + 0.5 * release, 0.2 * (1.0 - release), 0)
	lelbow.rotation.x = 0.3 * (1.0 - release) + 0.7 * release
	arm.rotation = Vector3(lerpf(1.2, 1.5, draw) + 0.6 * recoil - 0.5 * twirl, 0.0, 0)
	elbow.rotation.x = lerpf(0.9, 0.12, draw) * (1.0 - twirl) + 0.8 * twirl
	f.sword.rotation.x = -1.45 + twirl * TAU * 2.0
	body.rotation = Vector3(0.1 + 0.15 * draw - 0.3 * recoil, 0.0, 0)
	legs[0].rotation.x = -0.55
	legs[1].rotation.x = 0.55
	knees[0].rotation.x = -0.35 * (1.0 - twirl)
	f.muzzle.visible = recoil > 0.55


func _foe_blast(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var jolt := 0.0
	for i in 3:
		jolt = maxf(jolt, maxf(0.0, 1.0 - absf(tt - (0.42 + i * 0.24)) / 0.12))
	var drop := smoothstep(1.3, 1.45, tt)
	var fall := smoothstep(1.4, 2.0, tt)
	# held up by the throat, thrown back by each shot, then dropped and crumpled
	body.rotation = Vector3(-0.2 - 0.5 * jolt + 1.2 * fall * -1.0, 0.0, 0.05 * sin(tt * 30.0) * (1.0 - drop))
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3(-0.4 * jolt - 0.5 * drop, 0, 0)
	for i in 2:
		legs[i].rotation.x = sin(tt * 18.0 + i * 3.0) * 0.5 * (1.0 - drop)
		knees[i].rotation.x = -0.4 - 0.2 * drop
	(f.arm as Node3D).rotation = Vector3(lerpf(2.0, 0.3, drop), 0.3, 0.2 + 0.3 * jolt)
	(f.larm as Node3D).rotation = Vector3(lerpf(1.9, 0.3, drop), -0.3, -0.2 - 0.3 * jolt)
	fr.position += -Vector3(_dir.x, 0, _dir.y) * 0.25 * jolt + Vector3(_dir.x, 0, _dir.y) * 0.5 * fall
	_sink = 0.72 * fall
	return 0.9 * (1.0 - drop)


func _hero_stab(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var th := 0.0
	for i in 3:
		th = maxf(th, _pf(0.3 + i * 0.28, 0.1))
	var twist := _win(1.2, 1.35, 1.7, 1.8)
	var kick := _pf(1.88, 0.14)
	var rest := _k(2.2, 2.7)
	# left hand holds the victim, right hand drives the blade in over and over, twists, then the leg lashes out
	larm.rotation = Vector3(1.75 - 0.4 * kick, 0.15, 0)
	lelbow.rotation.x = 0.25
	arm.rotation = Vector3(0.9 + 0.8 * th + 0.2 * twist - 0.4 * rest, -0.4 * (1.0 - th) + 0.5 * twist, 0)
	elbow.rotation.x = 1.5 * (1.0 - th) + 0.1 * th
	f.sword.rotation.x = -0.6 - 0.9 * th - 0.2 * twist
	body.rotation = Vector3(0.12 + 0.3 * th - 0.2 * kick, -0.25 * (1.0 - th) + 0.35 * twist * sin(t * 25.0), 0)
	legs[0].rotation.x = -0.5 + 1.4 * kick
	legs[1].rotation.x = 0.5 - 0.3 * kick
	knees[0].rotation.x = -0.2 - 0.6 * kick
	knees[1].rotation.x = -0.3


func _hero_boss(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var sprint := 1.0 - smoothstep(0.9, 1.1, t)
	legs[0].rotation.x = sin(t * 16.0) * 0.9 * sprint
	legs[1].rotation.x = -sin(t * 16.0) * 0.9 * sprint
	knees[0].rotation.x = -maxf(0.0, cos(t * 16.0)) * 0.9 * sprint
	knees[1].rotation.x = -maxf(0.0, -cos(t * 16.0)) * 0.9 * sprint
	var leap := _k(1.05, 1.6)
	var plunge := _k(1.9, 2.05)
	var hold := _k(2.05, 3.7)
	var pull := _k(3.7, 4.2)
	var ax := lerpf(0.6, 2.9, leap) * (1.0 - plunge) + 0.55 * plunge
	arm.rotation = Vector3(lerpf(ax, 2.2, pull), 0.0, 0)
	larm.rotation = Vector3(lerpf(ax * 0.95, 2.0, pull), -0.1, 0)
	elbow.rotation.x = 0.5 * (1.0 - plunge) + 0.1 * plunge
	f.sword.rotation.x = -0.15
	body.rotation = Vector3(lerpf(0.15, -0.3, leap) * (1.0 - plunge) + 0.5 * plunge * (1.0 - pull), sin(t * 9.0) * 0.12 * hold * (1.0 - pull), 0)
	if lift > 0.1:
		legs[0].rotation.x = 0.9
		legs[1].rotation.x = 0.3
		knees[0].rotation.x = -1.1


func _hero_titan(f: Dictionary) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var body: Node3D = f.body
	var legs: Array = f.legs
	var run := 1.0 - smoothstep(1.6, 1.8, t)
	var dash := smoothstep(0.9, 1.9, t) * run
	legs[0].rotation.x = sin(t * 18.0) * 0.9 * dash
	legs[1].rotation.x = -sin(t * 18.0) * 0.9 * dash
	var leap2 := _k(1.7, 2.4)
	var plunge2 := _k(2.7, 2.85)
	arm.rotation = Vector3(lerpf(0.6, 2.9, leap2) * (1.0 - plunge2) + 0.6 * plunge2, 0, 0)
	larm.rotation = Vector3(lerpf(0.4, 2.8, leap2) * (1.0 - plunge2) + 0.7 * plunge2, -0.1, 0)
	elbow.rotation.x = 0.4
	f.sword.rotation.x = -0.15
	body.rotation.x = lerpf(0.2, -0.3, leap2) * (1.0 - plunge2) + 0.55 * plunge2


# ------------------------------------------------------------------ the victim's body

## Lift (height above the ground) of the hoisted victim during the grab.
func _reel_lift(p: float) -> float:
	var hoist := smoothstep(0.34, 0.6, p) * (1.0 - smoothstep(0.78, 0.9, p))
	var knee := maxf(0.0, 1.0 - absf(p - 1.32) / 0.14)
	return _hoist_h * hoist + minf(_hoist_h, 0.35) * smoothstep(0.88, 1.0, p) + 0.12 * knee


## The victim during the grab: seized by the throat, hoisted off the ground kicking, headbutted, then jabbed / hooked / kneed.
func _pose_reel(f: Dictionary, p: float) -> void:
	if f.get("quad", false) or not f.has("body") or not f.has("legs"):
		return
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var seize := smoothstep(0.28, 0.34, p)
	var hoist := smoothstep(0.34, 0.6, p) * (1.0 - smoothstep(0.78, 0.9, p))
	var butt := maxf(0.0, 1.0 - absf(p - 0.84) / 0.1)
	var jab := maxf(0.0, 1.0 - absf(p - 1.0) / 0.12)
	var hook := maxf(0.0, 1.0 - absf(p - 1.16) / 0.12)
	var knee := maxf(0.0, 1.0 - absf(p - 1.32) / 0.14)
	var kick := sin(p * 30.0)
	body.rotation = Vector3(-0.25 * seize - 0.3 * hoist - 0.45 * butt - 0.4 * jab + 0.85 * knee, 0.0, 0.55 * hook - 0.1 * jab + 0.1 * kick * hoist)
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3(-0.8 * butt - 0.5 * jab + 0.5 * knee, 1.0 * hook, 0.25 * hook + 0.1 * kick * hoist)
	legs[0].rotation.x = kick * 0.9 * hoist
	legs[1].rotation.x = -kick * 0.9 * hoist
	knees[0].rotation.x = -0.4 - 0.5 * hoist
	knees[1].rotation.x = -0.4 - 0.5 * hoist
	(f.arm as Node3D).rotation = Vector3(2.0 + 0.4 * jab + 0.2 * kick * hoist, 0.3, 0.2)
	(f.larm as Node3D).rotation = Vector3(1.9 + 0.4 * hook - 0.2 * kick * hoist, -0.3, -0.2)
	(f.elbow as Node3D).rotation.x = 1.4
	(f.lelbow as Node3D).rotation.x = 1.4


func pose_enemy(e: Dictionary, f: Dictionary, fr: Node3D) -> void:
	var x: Dictionary = e.exec
	var pre: float = x.get("pre", 0.0)
	var tt: float = float(x.t)
	if f.get("quad", false):
		# hounds: held, thrashing, hanging limp
		var held := smoothstep(-pre + 0.34, -pre + 0.6, tt) * (1.0 - smoothstep(-0.1, 0.1, tt) * 0.5)
		fr.position.y += 1.0 * held
		fr.rotation.z = 0.5 * smoothstep(1.0, 1.4, tt) + sin(tt * 18.0) * 0.14 * held * (1.0 - smoothstep(1.0, 1.4, tt))
		return
	if not f.has("body") or not f.has("legs"):
		return
	if tt < 0.0 and pre > 0.0:
		_pose_reel(f, tt + pre)
		fr.position.y += _reel_lift(tt + pre)
		_sink = 0.0
		return
	var body: Node3D = f.body
	var arm: Node3D = f.arm
	var larm: Node3D = f.larm
	var legs: Array = f.legs
	var knees: Array = f.knees
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3.ZERO
	if x.boss:
		var limp := smoothstep(float(x.limp), float(x.limp) + 0.2, tt)
		var k := smoothstep(0.0, 0.9, tt)
		body.rotation = Vector3(0.7 * k + 0.3 * limp, 0.0, sin(tt * 34.0) * 0.04 * smoothstep(1.9, 2.1, tt) * (1.0 - limp))
		body.position.y = 1.0 - 0.45 * k
		for i in 2:
			legs[i].rotation.x = 0.9 * k
			knees[i].rotation.x = -1.5 * k
		arm.rotation.x = lerpf(arm.rotation.x, 0.5, k)
		larm.rotation.x = lerpf(larm.rotation.x, 0.5, k)
		return
	var nodes := _foe_nodes(f)
	var saved: Array = []
	var y_end := 0.0
	if pre > 0.0 and tt < 0.2:
		_pose_reel(f, pre)
		saved = _snap(nodes)
		y_end = _reel_lift(pre)
	var fl := 0.0   # lift of the whole figure
	var ly := 0.0   # how far the body node sinks (lying on the ground)
	match kind_of(x):
		"rip": fl = _foe_rip(e, f, fr, tt)
		"decap": fl = _foe_decap(e, f, fr, tt)
		"uppercut": fl = _foe_uppercut(e, f, fr, tt)
		"snap": fl = _foe_snap(e, f, fr, tt)
		"slam": fl = _foe_slam(e, f, fr, tt)
		"impale": fl = _foe_impale(e, f, fr, tt)
		"shoot": fl = _foe_shoot(e, f, fr, tt)
		"blast": fl = _foe_blast(e, f, fr, tt)
		"stab": fl = _foe_stab(e, f, fr, tt)
	ly = _sink
	if not saved.is_empty():
		var k2 := 1.0 - smoothstep(0.0, 0.2, tt)
		_blend(nodes, saved, k2)
		fl = lerpf(fl, y_end, k2)
	fr.position.y += fl
	body.position.y = 1.0 - ly


var _sink := 0.0   # how far the victim's body node is lowered this frame (lying on the ground)


func kind_of(x: Dictionary) -> String:
	return str(x.get("kind", ""))


func _flop(a: Node3D, b: Node3D, kneel_a: Node3D, kneel_b: Node3D, v: float) -> void:
	a.rotation.x = v
	b.rotation.x = v
	kneel_a.rotation.x = -v
	kneel_b.rotation.x = -v


func _foe_rip(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var arch := smoothstep(0.52, 0.6, tt) * (1.0 - smoothstep(1.0, 1.1, tt))
	var conv := sin(tt * 34.0) * 0.07 * smoothstep(0.6, 0.7, tt) * (1.0 - smoothstep(0.95, 1.0, tt))
	var yank := smoothstep(1.0, 1.12, tt) * (1.0 - smoothstep(1.12, 1.4, tt))
	var collapse := smoothstep(1.3, 2.0, tt)
	var fall := smoothstep(1.8, 2.6, tt)
	body.rotation = Vector3(-0.55 * arch + 0.7 * yank + 1.35 * fall, 0.0, conv)
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3(-1.0 * arch + 0.6 * yank + 0.3 * fall, 0, 0)
	for i in 2:
		legs[i].rotation.x = (sin(tt * 26.0 + i * 3.0) * 0.3 * arch if tt < 1.0 else 0.0) + 0.5 * collapse
		knees[i].rotation.x = -0.4 - 1.1 * collapse
	# arms flung wide when the fist bursts in, clawing at the wrist, then hanging
	(f.arm as Node3D).rotation = Vector3(lerpf(2.0, 0.5, arch) * (1.0 - collapse) + 0.2 * collapse, 0.6 * arch, 0.6 * arch)
	(f.larm as Node3D).rotation = Vector3(lerpf(1.9, 0.5, arch) * (1.0 - collapse) + 0.2 * collapse, -0.6 * arch, -0.6 * arch)
	fr.position -= Vector3(_dir.x, 0, _dir.y) * 0.18 * yank
	_sink = 0.75 * fall
	return 0.3 * (1.0 - smoothstep(1.2, 1.7, tt)) - 0.35 * collapse * (1.0 - fall)


func _foe_decap(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var cut := smoothstep(0.55, 0.62, tt)
	var back := smoothstep(0.1, 0.4, tt) * (1.0 - cut)
	var fall := smoothstep(1.5, 2.2, tt)
	var buckle := smoothstep(1.2, 1.8, tt)
	# the head is hauled back by the hair; after the cut the headless body sways, spasms and topples
	body.rotation = Vector3(-0.25 * back + 0.1 * cut * (1.0 - fall) + 1.3 * fall, 0.0, sin(tt * 14.0) * 0.1 * cut * (1.0 - fall))
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3(-0.75 * back, 0, 0)
	for i in 2:
		legs[i].rotation.x = (sin(tt * 18.0 + i * 3.1) * 0.5 * cut * (1.0 - fall))
		knees[i].rotation.x = -0.3 - 0.9 * buckle
	(f.arm as Node3D).rotation = Vector3(lerpf(2.2, 2.7 + sin(tt * 22.0) * 0.4, cut), 0.4 * cut, 0.2 + 0.4 * cut) if tt < 1.5 else Vector3(0.6, 0.2, 0.2)
	(f.larm as Node3D).rotation = Vector3(lerpf(2.0, 2.6 + sin(tt * 20.0 + 1.0) * 0.4, cut), -0.4 * cut, -0.2 - 0.4 * cut) if tt < 1.5 else Vector3(0.6, -0.2, -0.2)
	_sink = 0.7 * fall
	return 0.2 * smoothstep(0.1, 0.3, tt) * (1.0 - cut) - 0.5 * buckle * (1.0 - fall)


func _foe_uppercut(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var u := tt - 0.25
	var h := _up_h(tt)
	fr.position += Vector3(_dir.x, 0, _dir.y) * 2.2 * smoothstep(0.0, 0.72, u) * (1.0 if u > 0.0 else 0.0)
	var spin := smoothstep(0.0, 0.8, u) * TAU * 1.25
	var dive := smoothstep(0.8, 1.1, u)
	var lying := smoothstep(1.1, 1.4, u)
	body.rotation = Vector3(spin + dive * (PI * 0.5) - lying * 1.5 + (0.0 if u > 0.0 else -0.2), 0.0, 0.0)
	for i in 2:
		legs[i].rotation.x = sin(tt * 14.0 + i * 2.0) * 0.8 * (1.0 if (u > 0.0 and u < 1.1) else 0.1)
		knees[i].rotation.x = -0.5
	(f.arm as Node3D).rotation = Vector3(2.4, 0.3, 0.2)
	(f.larm as Node3D).rotation = Vector3(2.2, -0.3, -0.2)
	_sink = 0.7 * lying
	return h + (0.3 if u < 0.0 else 0.0)


func _foe_snap(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var strain := smoothstep(0.3, 0.95, tt)
	var crack := smoothstep(1.0, 1.06, tt)
	var shove := smoothstep(1.3, 1.5, tt)
	var fall := smoothstep(1.5, 2.1, tt)
	body.rotation = Vector3(-0.2 * strain * (1.0 - crack) + 0.9 * crack * (1.0 - fall) - 1.3 * fall, 0.0, sin(tt * 30.0) * 0.06 * strain * (1.0 - crack))
	if f.has("head"):
		# the head winds slowly round, then spins right round on the broken neck
		(f.head as Node3D).rotation = Vector3(0.0, 0.5 * strain * (1.0 - crack) + 2.9 * crack, 0.15 * crack)
	for i in 2:
		legs[i].rotation.x = sin(tt * 20.0 + i * 3.0) * 0.4 * strain * (1.0 - crack)
		knees[i].rotation.x = -0.3 - 0.2 * crack
	(f.arm as Node3D).rotation = Vector3(lerpf(2.0, 0.1, crack), 0.3, 0.2)
	(f.larm as Node3D).rotation = Vector3(lerpf(1.9, 0.1, crack), -0.3, -0.2)
	fr.position += Vector3(_dir.x, 0, _dir.y) * 0.9 * shove
	_sink = 0.72 * fall
	return 0.6 * (1.0 - smoothstep(1.28, 1.5, tt))


func _foe_slam(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var over := smoothstep(0.3, 0.9, tt) * (1.0 - smoothstep(1.6, 1.7, tt))
	var after := smoothstep(1.6, 1.75, tt)
	var spin := smoothstep(0.9, 1.6, tt)
	# carried above the hero's head, lying across the arms, whirled round, then smashed down in front
	fr.position += -Vector3(_dir.x, 0, _dir.y) * (_stand - 0.1) * over + Vector3(_dir.x, 0, _dir.y) * 1.2 * after
	fr.rotation.y += spin * TAU * (1.0 - after)
	body.rotation = Vector3(-1.5 * over - 1.45 * after * (1.0 - over), 0.0, 0.1 * sin(tt * 22.0) * over)
	for i in 2:
		legs[i].rotation.x = sin(tt * 18.0 + i * 3.0) * 0.4 * over
		knees[i].rotation.x = -0.4
	(f.arm as Node3D).rotation = Vector3(0.4, 0.3, 0.8 * over)
	(f.larm as Node3D).rotation = Vector3(0.4, -0.3, -0.8 * over)
	_sink = 0.72 * after
	return 2.3 * over * (1.0 - after)


func _foe_impale(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var thrust := smoothstep(0.0, 0.16, tt)
	var heave := smoothstep(0.45, 1.1, tt)
	var fling := smoothstep(1.55, 1.66, tt)
	var flight := clampf((tt - 1.58) / 0.57, 0.0, 1.0)
	var lying := smoothstep(2.1, 2.3, tt)
	var d := Vector3(_dir.x, 0, _dir.y)
	# dragged onto the blade, hoisted on it, swung round, flung off to crash down several metres away
	fr.position += -d * 0.55 * thrust * (1.0 - fling) + d * 7.0 * smoothstep(0.0, 1.0, flight)
	body.rotation = Vector3(-0.15 * thrust * (1.0 - fling) + 0.3 * sin(tt * 8.0) * heave * (1.0 - fling) + (flight * 5.0 if flight < 1.0 else 0.0) - lying * 1.5 * 0.0, 0.0, 0.1 * sin(tt * 6.0) * heave)
	for i in 2:
		legs[i].rotation.x = sin(tt * 9.0 + i * 3.0) * 0.5 * heave * (1.0 - smoothstep(1.3, 1.55, tt)) + 0.3 * fling
		knees[i].rotation.x = -0.2 - 0.3 * heave
	(f.arm as Node3D).rotation = Vector3(0.2, 0.2, 0.5 * thrust)
	(f.larm as Node3D).rotation = Vector3(0.2, -0.2, -0.5 * thrust)
	_sink = 0.72 * lying
	return 2.1 * heave * (1.0 - fling) + 2.6 * sin(flight * PI) * (1.0 if flight < 1.0 else 0.0)


func _foe_shoot(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var kneel := smoothstep(0.0, 0.35, tt)
	var bang := smoothstep(1.25, 1.32, tt)
	var slump := smoothstep(1.3, 1.9, tt)
	var kicked := smoothstep(1.75, 1.95, tt)
	# forced to its knees, head pressed back to the muzzle, then the headless body slumps and is kicked over
	body.rotation = Vector3(-0.15 * kneel * (1.0 - bang) + 0.2 * bang + 0.9 * slump - 0.5 * kicked, 0.0, 0.0)
	if f.has("head"):
		(f.head as Node3D).rotation = Vector3(-0.5 * kneel * (1.0 - bang), 0, 0)
	for i in 2:
		legs[i].rotation.x = 0.7 * kneel
		knees[i].rotation.x = -1.6 * kneel
	(f.arm as Node3D).rotation = Vector3(lerpf(2.0, 0.3, bang), 0.3, 0.2)
	(f.larm as Node3D).rotation = Vector3(lerpf(1.9, 0.3, bang), -0.3, -0.2)
	fr.position += Vector3(_dir.x, 0, _dir.y) * 0.9 * kicked
	_sink = 0.55 * kneel + 0.2 * slump
	return -0.05 * kneel


func _foe_stab(_e: Dictionary, f: Dictionary, fr: Node3D, tt: float) -> float:
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var th := 0.0
	for i in 3:
		th = maxf(th, maxf(0.0, 1.0 - absf(tt - (0.3 + i * 0.28)) / 0.1))
	var hang := smoothstep(0.9, 1.3, tt) * (1.0 - smoothstep(1.85, 1.95, tt))
	var flown := clampf((tt - 1.85) / 0.55, 0.0, 1.0)
	var lying := smoothstep(2.3, 2.5, tt)
	var d := Vector3(_dir.x, 0, _dir.y)
	# doubles over on every stab, hangs on the twisted blade, is kicked off it and flies away
	body.rotation = Vector3(0.5 * th - 0.2 * hang + (flown * 4.0 if flown < 1.0 else 0.0), 0.0, 0.08 * sin(tt * 20.0) * hang)
	for i in 2:
		legs[i].rotation.x = sin(tt * 12.0 + i * 3.0) * 0.5 * hang
		knees[i].rotation.x = -0.3 - 0.4 * hang
	(f.arm as Node3D).rotation = Vector3(0.9 + 0.4 * th, 0.3, 0.2)
	(f.larm as Node3D).rotation = Vector3(0.9 + 0.4 * th, -0.3, -0.2)
	fr.position += d * 3.8 * smoothstep(0.0, 1.0, flown)
	_sink = 0.72 * lying
	return 0.6 * (1.0 - smoothstep(1.8, 1.9, tt)) + 1.2 * hang * (1.0 - smoothstep(1.8, 1.9, tt)) + 1.2 * sin(flown * PI) * (1.0 if flown < 1.0 else 0.0)


# ------------------------------------------------------------------ HUD

## "GRAB" marks above every enemy that can be executed, letterbox bars, hit flashes and the FATALITY splash.
func draw_marks(vs: Vector2) -> void:
	if active and not target.is_empty():
		var bar := clampf(minf((t + _pre) / 0.35, (dur - t) / 0.3), 0.0, 1.0) * vs.y * 0.09
		g.hud.draw_rect(Rect2(0, 0, vs.x, bar), Color.BLACK)
		g.hud.draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color.BLACK)
	if _flash_a > 0.01:
		g.hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.95, 0.9, clampf(_flash_a, 0.0, 0.8)))
	if _fat_t > 0.0:
		var age := 2.8 - _fat_t
		var a := clampf(minf(age / 0.08, _fat_t / 0.6), 0.0, 1.0)
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - age / 0.25)
		g.hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.45, 0.0, 0.0, 0.3 * a * maxf(0.0, 1.0 - age / 1.2)))
		var fs := int(86.0 * pop * clampf(vs.y / 720.0, 0.6, 1.4))
		g._text("FATALITY", Vector2(0, vs.y * 0.24), fs, Color(0.86, 0.06, 0.06, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 12)
		if _fat_name != "" and _fat_name != "FATALITY":
			g._text(_fat_name, Vector2(0, vs.y * 0.24 + 44), 26, Color(0.9, 0.82, 0.66, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 6)
	for e in g.enemies:
		if not can_exec(e):
			continue
		var sh: float = e.fig.root.scale.y
		var sp: Vector2 = g._w2s(g._p3(e.pos, minf(2.9 * sh, 11.0) + float(g.ENEMY[e.type].get("fly", 0.0))))
		var pulse := 0.5 + 0.5 * sin(g.t * 8.0)
		var col := Color("ffe9a8") if not e.boss else Color("ff9a6a")
		g.hud.draw_circle(sp, 19.0 + pulse * 4.0, Color(col, 0.2))
		g.hud.draw_arc(sp, 19.0, 0, TAU, 28, Color(col, 0.9), 2.5)
		g._text("GRAB" if not e.boss else "FINISH", sp + Vector2(-40, 5), 14, col, HORIZONTAL_ALIGNMENT_CENTER, 80)
