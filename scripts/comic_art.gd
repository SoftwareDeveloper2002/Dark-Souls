extends RefCounted
## The 3D stagings behind the epilogue comic: one little scene per panel, rendered once into a SubViewport (the comic shader inks it).
## Everything reuses the game's own figures (hero, Princess Elara, Malakar's crown) with a bit of scenery around them.

const PINE := "res://assets/models/forest/pine_1.glb"

var g  # the game node
var _pine: PackedScene = null


func _init(game) -> void:
	g = game
	if ResourceLoader.exists(PINE):
		_pine = load(PINE) as PackedScene


# ------------------------------------------------------------------ tiny helpers

func _mat(col: Color, rough: float = 0.9, emit: float = 0.0) -> StandardMaterial3D:
	return g.M.mat(col, rough, emit)


func _m(parent: Node, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sky(vp: SubViewport, top: Color, horizon: Color, ambient: Color, fog: Color = Color(0, 0, 0, 0), fog_density: float = 0.0) -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon.darkened(0.25)
	sm.ground_bottom_color = horizon.darkened(0.6)
	sm.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 1.0
	if fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = fog
		env.fog_density = fog_density
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)


func _sun(vp: SubViewport, rot_deg: Vector3, col: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot_deg
	l.light_color = col
	l.light_energy = energy
	vp.add_child(l)


func _omni(parent: Node, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)


func _cam(vp: SubViewport, pos: Vector3, look: Vector3, fov: float = 40.0) -> void:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 400.0
	vp.add_child(c)
	c.look_at_from_position(pos, look, Vector3.UP)
	c.current = true


func _ground(w: Node3D, col: Color, y: float = 0.0, size: float = 260.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	_m(w, pm, _mat(col, 1.0), Vector3(0, y, 0))


func _trees(w: Node3D, count: int, center: Vector3, spread: Vector2, scale_r: Vector2, keep_out: Rect2 = Rect2(), seed_v: int = 1) -> void:
	if _pine == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var p := center + Vector3(rng.randf_range(-spread.x, spread.x), 0, rng.randf_range(-spread.y, spread.y))
		if keep_out.has_point(Vector2(p.x, p.z)):
			continue
		var t: Node3D = _pine.instantiate()
		t.position = p
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(scale_r.x, scale_r.y)
		w.add_child(t)


func _stars(w: Node3D, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 4
	sm.rings = 2
	var mat = g.M.unshaded(Color("fff6d8"))
	for i in n:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.15, 1.0), rng.randf_range(-1, -0.2)).normalized() * 150.0
		_m(w, sm, mat, d, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.5, 1.6))


# ------------------------------------------------------------------ people

func _hero(w: Node3D, pos: Vector3, yaw: float, pose: String = "stand") -> Dictionary:
	var f: Dictionary = g.M.player()
	g.M.set_armor(f, g.armor)
	g.M.show_weapon(f, g.equipped)
	f.root.position = pos
	f.root.rotation.y = yaw
	w.add_child(f.root)
	f.shield.position = Vector3(0.0, 1.12, 0.2)
	f.shield.rotation = Vector3(0.0, PI, 0.25)
	match pose:
		"kneel":
			f.root.position.y -= 0.42
			f.legs[0].rotation.x = 1.35
			f.knees[0].rotation.x = -1.9
			f.legs[1].rotation.x = -0.25
			f.knees[1].rotation.x = -2.5
			f.body.rotation.x = 0.35
			f.arm.rotation = Vector3(1.0, -0.1, 0)
			f.elbow.rotation.x = 0.3
			f.sword.rotation.x = -0.1
			f.larm.rotation = Vector3(0.9, 0.2, 0)
			f.lelbow.rotation.x = 0.5
			f.head.rotation.x = 0.5
		"sit":
			f.root.position.y -= 0.72
			f.legs[0].rotation.x = 1.5
			f.knees[0].rotation.x = -0.5
			f.legs[1].rotation.x = 1.3
			f.knees[1].rotation.x = -0.9
			f.body.rotation.x = 0.25
			f.arm.rotation = Vector3(0.7, -0.1, 0)
			f.elbow.rotation.x = 1.4
			f.larm.rotation = Vector3(0.6, 0.1, 0)
			f.lelbow.rotation.x = 1.5
			f.head.rotation.x = 0.35
			f.sword.visible = false
		"grip":
			f.arm.rotation = Vector3(1.5, -0.2, 0)
			f.elbow.rotation.x = 1.3
			f.sword.rotation.x = -1.2
			f.larm.rotation = Vector3(1.2, 0.3, 0)
			f.lelbow.rotation.x = 1.0
			f.legs[0].rotation.x = -0.35
			f.legs[1].rotation.x = 0.35
		"walk":
			f.legs[0].rotation.x = 0.55
			f.legs[1].rotation.x = -0.55
			f.knees[1].rotation.x = -0.7
			f.arm.rotation = Vector3(-0.4, -0.1, 0)
			f.larm.rotation = Vector3(0.4, 0, 0)
		"bow":
			f.root.position.y -= 0.42
			f.legs[0].rotation.x = 1.35
			f.knees[0].rotation.x = -1.9
			f.legs[1].rotation.x = -0.25
			f.knees[1].rotation.x = -2.5
			f.head.rotation.x = 0.6
			f.arm.rotation = Vector3(0.9, -0.1, 0)
			f.elbow.rotation.x = 0.4
			f.sword.rotation.x = -0.1
	return f


func _princess(w: Node3D, pos: Vector3, yaw: float, pose: String = "stand") -> Dictionary:
	var f: Dictionary = g.M.princess()
	f.root.position = pos
	f.root.rotation.y = yaw
	w.add_child(f.root)
	match pose:
		"reach":
			f.arm.rotation = Vector3(1.4, -0.2, 0)
			f.elbow.rotation.x = 0.5
			f.larm.rotation = Vector3(0.15, 0, 0)
		"hold":
			f.arm.rotation = Vector3(1.2, -0.1, 0)
			f.elbow.rotation.x = 1.3
			f.larm.rotation = Vector3(1.1, 0.1, 0)
			f.lelbow.rotation.x = 1.3
		"raise":
			f.arm.rotation = Vector3(1.9, -0.2, 0)
			f.elbow.rotation.x = 0.5
			f.larm.rotation = Vector3(0.15, 0, 0)
		"walk":
			f.legs[0].rotation.x = 0.4
			f.legs[1].rotation.x = -0.4
			f.arm.rotation = Vector3(-0.3, 0, 0)
			f.larm.rotation = Vector3(0.3, 0, 0)
	g.M.princess_sync(f)
	return f


## Malakar's fallen crown: a black iron band with spikes and a smouldering red gem.
func _crown(w: Node3D, pos: Vector3, scl: float = 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * scl
	w.add_child(n)
	var iron := _mat(Color("1a161c"), 0.4)
	iron.metallic = 0.8
	_m(n, g.M.ring(0.11, 0.135), iron, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1))
	for i in 7:
		var a := float(i) / 7.0 * TAU
		_m(n, g.M.cone(0.0, 0.022, 0.14 + 0.05 * (i % 2)), iron, Vector3(cos(a) * 0.12, 0.08, sin(a) * 0.12))
	_m(n, g.M.sphere(0.03), _mat(Color("ff2a1a"), 0.2, 3.5), Vector3(0.0, 0.03, 0.125))
	return n


# ------------------------------------------------------------------ scenery

func _citadel(w: Node3D, pos: Vector3, s: float, lean: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	w.add_child(n)
	var stone := _mat(Color("1c1722"), 0.95)
	var glow := _mat(Color("ff7a28"), 0.5, 2.8)
	_m(n, g.M.box(16, 11, 9), stone, Vector3(0, 5.5, 0))
	_m(n, g.M.box(8, 7, 6), stone, Vector3(0, 14.5, 0))
	for x in [-9.0, 9.0]:
		_m(n, g.M.cone(2.0, 2.4, 17), stone, Vector3(x, 8.5, 2.0))
		_m(n, g.M.cone(0.0, 3.0, 5.0), stone, Vector3(x, 19.5, 2.0))
	var tall := _m(n, g.M.cone(1.6, 2.0, 24), stone, Vector3(0, 24, 0), Vector3(0, 0, lean))
	_m(tall, g.M.cone(0.0, 2.6, 6.0), stone, Vector3(0, 15, 0))
	for i in 9:
		_m(n, g.M.box(0.7, 1.4, 0.2), glow, Vector3(-6.0 + i * 1.5, 7.0 + (i % 3) * 1.6, 4.6))
	# cracks of fire down the keep
	_m(n, g.M.box(0.35, 9.0, 0.2), glow, Vector3(1.0, 5.5, 4.55), Vector3(0, 0, 0.15))
	_m(n, g.M.box(0.3, 6.0, 0.2), glow, Vector3(-3.0, 6.0, 4.55), Vector3(0, 0, -0.2))


func _bolt(w: Node3D, from: Vector3, to: Vector3) -> void:
	var mat = g.M.unshaded(Color("f4f0ff"))
	var p := from
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var steps := 8
	for i in steps:
		var nxt := from.lerp(to, float(i + 1) / steps) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-1, 1))
		var d := nxt - p
		var mid := p + d * 0.5
		var bm := _m(w, g.M.box(0.35, d.length() * 1.05, 0.35), mat, mid)
		bm.look_at_from_position(mid, nxt, Vector3.UP)
		bm.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		p = nxt


func _fire(w: Node3D, pos: Vector3, s: float = 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	w.add_child(n)
	var stone := _mat(Color("3a3430"), 0.95)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_m(n, g.M.box(0.28, 0.2, 0.3), stone, Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0, a, 0))
	_m(n, g.M.box(0.9, 0.12, 0.14), _mat(Color("2a1a10")), Vector3(0, 0.12, 0), Vector3(0, 0.6, 0.1))
	_m(n, g.M.box(0.9, 0.12, 0.14), _mat(Color("2a1a10")), Vector3(0, 0.12, 0), Vector3(0, -0.7, -0.1))
	_m(n, g.M.cone(0.0, 0.34, 1.0), g.M.unshaded(Color("ff7a20")), Vector3(0, 0.6, 0))
	_m(n, g.M.cone(0.0, 0.22, 0.8), g.M.unshaded(Color("ffd060")), Vector3(0, 0.55, 0))
	_m(n, g.M.cone(0.0, 0.1, 0.5), g.M.unshaded(Color("fff2b0")), Vector3(0, 0.45, 0))
	_omni(n, Vector3(0, 0.9, 0), Color("ff9a40"), 4.0, 9.0)


func _crowd(w: Node3D, center: Vector3, count: int, width: float, depth: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cols := [Color("2a2230"), Color("3a2a2a"), Color("22303a"), Color("30282a"), Color("2a2a22")]
	var capsule = g.M.caps(0.2, 1.2)
	var head = g.M.sphere(0.14)
	var arm = g.M.box(0.08, 0.55, 0.08)
	for i in count:
		var p := center + Vector3(rng.randf_range(-width, width), 0, rng.randf_range(0, depth))
		var mat := _mat(cols[rng.randi() % cols.size()], 0.95)
		var h := rng.randf_range(0.9, 1.15)
		_m(w, capsule, mat, p + Vector3(0, 0.6 * h, 0), Vector3.ZERO, Vector3(1, h, 1))
		_m(w, head, _mat(Color("5a4638"), 0.9), p + Vector3(0, 1.3 * h, 0))
		if rng.randf() < 0.7:
			for sx in [-1.0, 1.0]:
				_m(w, arm, mat, p + Vector3(sx * 0.26, 1.35 * h, 0), Vector3(0, 0, -sx * 0.35))
	# banners on poles
	var pole = g.M.cone(0.03, 0.03, 4.0)
	var flag = g.M.box(0.9, 0.7, 0.04)
	for i in 5:
		var bp := center + Vector3(lerpf(-width, width, float(i) / 4.0), 0, depth * 0.5 + rng.randf_range(-0.5, 0.5))
		_m(w, pole, _mat(Color("2a1c12")), bp + Vector3(0, 2.0, 0))
		_m(w, flag, _mat(Color("b8281c") if i % 2 == 0 else Color("d8b050"), 0.8, 0.3), bp + Vector3(0.45, 3.5, 0))


func _gate(w: Node3D, pos: Vector3) -> void:
	var stone := _mat(Color("6a6258"), 0.95)
	var dark := _mat(Color("2a2420"), 0.95)
	for x in [-6.0, 6.0]:
		_m(w, g.M.box(4, 14, 4), stone, pos + Vector3(x, 7, 0))
		_m(w, g.M.cone(0.0, 3.4, 4.0), dark, pos + Vector3(x, 16, 0))
	_m(w, g.M.box(12, 3.5, 3.5), stone, pos + Vector3(0, 12, 0))
	_m(w, g.M.box(8.0, 10.0, 0.5), dark, pos + Vector3(0, 5, -0.6))
	for x in [-9.0, 9.0]:
		_m(w, g.M.box(9, 6, 3), stone, pos + Vector3(x * 1.4, 3, 0))


# ------------------------------------------------------------------ the panels

## Builds the staging called `id` into `vp`.
func build(id: String, vp: SubViewport) -> void:
	var w := Node3D.new()
	vp.add_child(w)
	match id:
		"fall": _p_fall(vp, w)
		"kneel": _p_kneel(vp, w)
		"face": _p_face(vp, w)
		"two": _p_two(vp, w)
		"crown": _p_crown(vp, w)
		"cycle": _p_cycle(vp, w)
		"look": _p_look(vp, w)
		"vow": _p_vow(vp, w)
		"walk": _p_walk(vp, w)
		"gate": _p_gate(vp, w)
		"coronation": _p_coronation(vp, w)
		"ember": _p_ember(vp, w)


func _p_fall(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("1a0c22"), Color("e0562a"), Color("7a5a6a"), Color("6a2a2a"), 0.003)
	_sun(vp, Vector3(-20, 200, 0), Color("ff8a50"), 1.6)
	_ground(w, Color("2a1e24"))
	_citadel(w, Vector3(0, 0, -62), 1.9, 0.45)
	_bolt(w, Vector3(10, 100, -66), Vector3(-2, 26, -62))
	_bolt(w, Vector3(-36, 90, -80), Vector3(-30, 20, -76))
	_trees(w, 16, Vector3(0, 0, -22), Vector2(40, 12), Vector2(0.5, 0.9), Rect2(-12, -40, 24, 60), 3)
	_hero(w, Vector3(-2.6, 0, 6.5), -0.45, "stand")
	_cam(vp, Vector3(-3.6, 1.3, 11.5), Vector3(0, 10, -62), 52.0)


func _p_kneel(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("2a1428"), Color("e08040"), Color("8a6a70"), Color("5a2a2a"), 0.006)
	_sun(vp, Vector3(-18, 160, 0), Color("ffa860"), 1.8)
	_ground(w, Color("2a2026"))
	_hero(w, Vector3(0, 0, 0), 2.7, "kneel")
	_trees(w, 18, Vector3(0, 0, -25), Vector2(30, 12), Vector2(0.5, 0.9), Rect2(-6, -22, 12, 30), 5)
	_citadel(w, Vector3(8, 0, -45), 1.0, 0.5)
	_cam(vp, Vector3(2.0, 1.15, 2.7), Vector3(0, 0.85, 0), 40.0)


func _p_face(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("ffb878"), Color("ffe0b0"), Color("a88878"))
	_sun(vp, Vector3(-25, 150, 0), Color("ffd8a0"), 1.8)
	_ground(w, Color("3a2e28"))
	_princess(w, Vector3(0, 0, 0), 0.0, "stand")
	_omni(w, Vector3(-0.8, 1.9, -1.2), Color("ffd890"), 2.0, 6.0)
	_cam(vp, Vector3(0.1, 1.52, -1.1), Vector3(0, 1.5, 0), 28.0)


func _p_two(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("5a78b8"), Color("ffd0a0"), Color("9a8878"), Color("e8b890"), 0.003)
	_sun(vp, Vector3(-20, 120, 0), Color("ffd0a0"), 1.7)
	_ground(w, Color("3a3028"))
	_hero(w, Vector3(-0.9, 0, 0), 1.2, "stand")
	_princess(w, Vector3(0.9, 0, 0), -1.4, "reach")
	_trees(w, 24, Vector3(0, 0, -30), Vector2(36, 14), Vector2(0.6, 1.0), Rect2(-8, -30, 16, 40), 9)
	_cam(vp, Vector3(0, 1.5, 3.6), Vector3(0, 1.35, 0), 36.0)


func _p_crown(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("1a0e20"), Color("4a1a24"), Color("6a4a5a"))
	_sun(vp, Vector3(-30, 40, 0), Color("ff6040"), 1.0)
	_ground(w, Color("1e1218"))
	_princess(w, Vector3(0, 0, 0), 0.0, "hold")
	var cr := _crown(w, Vector3(0.1, 1.1, -0.42), 1.5)
	cr.rotation = Vector3(0.7, 0.0, 0.1)
	_omni(w, Vector3(0.1, 1.2, -0.8), Color("ff3a20"), 5.0, 6.0)
	var wisp = g.M.unshaded(Color("ff5a3a"))
	wisp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp.albedo_color.a = 0.5
	for i in 14:
		_m(w, g.M.sphere(0.04 + 0.02 * (i % 3)), wisp, Vector3(0.1 + sin(i * 1.7) * 0.25, 1.35 + i * 0.1, -0.45 + cos(i * 2.3) * 0.2))
	_cam(vp, Vector3(0.1, 1.45, -2.4), Vector3(0.05, 1.25, 0), 30.0)


func _p_cycle(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("2a1020"), Color("9a3a30"), Color("7a5060"), Color("5a1a20"), 0.008)
	_sun(vp, Vector3(-40, 170, 0), Color("ff7050"), 1.4)
	_ground(w, Color("241418"))
	_princess(w, Vector3(0.6, 0, 0), 0.5, "stand")
	# the Ashen Throne: a black seat of spikes, burning at the edges
	var iron := _mat(Color("2a2434"), 0.5)
	iron.metallic = 0.5
	var glow := _mat(Color("ff6a20"), 0.5, 2.5)
	_m(w, g.M.box(3.4, 0.5, 2.6), iron, Vector3(-2.2, 0.25, -5.0))
	_m(w, g.M.box(3.0, 5.5, 0.5), iron, Vector3(-2.2, 2.9, -6.1))
	for i in 7:
		_m(w, g.M.cone(0.0, 0.2, 2.0 + (i % 3) * 0.8), iron, Vector3(-3.6 + i * 0.47, 6.2, -6.1))
	_m(w, g.M.box(0.2, 5.0, 0.12), glow, Vector3(-2.2, 2.9, -5.82))
	_omni(w, Vector3(-2.2, 3.0, -4.0), Color("ff5a30"), 4.0, 14.0)
	var helm := _crown(w, Vector3(1.3, 0.12, -0.6), 1.6)
	helm.rotation = Vector3(1.3, 0.4, 0.3)
	_cam(vp, Vector3(1.8, 1.3, 2.6), Vector3(-0.3, 1.7, -2.0), 46.0)


func _p_look(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("2a2040"), Color("e07a50"), Color("8a6a70"), Color("5a3030"), 0.004)
	_sun(vp, Vector3(-18, 220, 0), Color("ff9a60"), 1.6)
	_ground(w, Color("2a2026"))
	_hero(w, Vector3(0.8, 0, 0), -1.4, "grip")
	_princess(w, Vector3(-0.8, 0, 0), 1.4, "stand")
	_cam(vp, Vector3(0.0, 1.45, 2.9), Vector3(0, 1.4, 0), 36.0)


func _p_vow(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("3a2a58"), Color("ffb070"), Color("9a8090"), Color("c87858"), 0.004)
	_sun(vp, Vector3(-12, 200, 0), Color("ffc080"), 1.8)
	_ground(w, Color("3a2a30"))
	_hero(w, Vector3(0.7, 0, 0), -0.6, "grip")
	_princess(w, Vector3(-1.1, 0, 0.4), 0.7, "stand")
	_trees(w, 14, Vector3(0, 0, -35), Vector2(40, 10), Vector2(0.6, 1.0), Rect2(-8, -40, 16, 50), 13)
	_cam(vp, Vector3(0.1, 0.9, 3.0), Vector3(0, 1.45, 0), 50.0)


func _p_walk(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("7a98c8"), Color("ffe8b8"), Color("b8a898"), Color("ffe0b0"), 0.01)
	_sun(vp, Vector3(-14, 190, 0), Color("fff0c0"), 2.0)
	_ground(w, Color("5a5034"))
	_trees(w, 56, Vector3(0, 0, -30), Vector2(24, 50), Vector2(0.5, 0.9), Rect2(-3.6, -90, 7.2, 130), 17)
	_hero(w, Vector3(0.7, 0, -6), PI, "walk")
	_princess(w, Vector3(-0.7, 0, -6.4), PI, "walk")
	var ray = g.M.unshaded(Color("fff2c0"))
	ray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.albedo_color.a = 0.16
	ray.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 5:
		_m(w, g.M.cone(0.2, 1.6, 22), ray, Vector3(-9 + i * 4.5, 10, -22 - i * 3), Vector3(0, 0, 0.35))
	_cam(vp, Vector3(0, 1.4, 0.8), Vector3(0, 1.5, -12), 46.0)


func _p_gate(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("6a8ad0"), Color("ffe0a8"), Color("b0a090"), Color("ffe8c0"), 0.004)
	_sun(vp, Vector3(-18, 20, 0), Color("fff0c0"), 2.0)
	_ground(w, Color("5a5040"))
	_gate(w, Vector3(0, 0, -28))
	_crowd(w, Vector3(0, 0, -9), 34, 9.0, 8.0, 21)
	_hero(w, Vector3(0.9, 0, 3), PI, "walk")
	_princess(w, Vector3(-0.9, 0, 2.7), PI, "walk")
	_cam(vp, Vector3(0, 1.3, 7.6), Vector3(0, 3.2, -14), 55.0)


func _p_coronation(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("6a90d8"), Color("ffe8b0"), Color("c0b098"), Color("fff0c8"), 0.003)
	_sun(vp, Vector3(-25, 140, 0), Color("fff0c0"), 2.0)
	_ground(w, Color("7a6a50"))
	_crowd(w, Vector3(0, 0, -8), 24, 7.0, 4.0, 31)
	_hero(w, Vector3(-0.5, 0, 0), 1.2, "bow")
	_princess(w, Vector3(0.9, 0, 0), -1.5, "raise")
	_omni(w, Vector3(0, 3.0, 1.0), Color("ffe8a0"), 2.0, 10.0)
	_cam(vp, Vector3(0.2, 1.25, 3.6), Vector3(0.1, 1.2, 0), 38.0)


func _p_ember(vp: SubViewport, w: Node3D) -> void:
	_sky(vp, Color("0c1030"), Color("2a2450"), Color("5a6088"), Color("141028"), 0.008)
	_sun(vp, Vector3(-40, 30, 0), Color("8a9ad0"), 0.9)
	_ground(w, Color("2a2630"))
	_stars(w, 120)
	_fire(w, Vector3(0, 0, 0), 1.3)
	_hero(w, Vector3(-1.5, 0, 0.5), 1.2, "sit")
	_trees(w, 40, Vector3(0, 0, -20), Vector2(36, 26), Vector2(0.6, 1.0), Rect2(-8, -8, 16, 16), 41)
	# something watches from the dark
	var eye = g.M.unshaded(Color("ff2a1a"))
	for sx in [-0.4, 0.4]:
		_m(w, g.M.sphere(0.14), eye, Vector3(5.5 + sx, 1.6, -12.0))
	_cam(vp, Vector3(1.4, 2.4, 4.6), Vector3(-0.3, 0.7, -0.6), 46.0)
