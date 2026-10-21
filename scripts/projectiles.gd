extends RefCounted
## Visuals for everything that flies: real arrows with fletching, spinning crystal bolts, fireballs, venom globs, missiles and bullet tracers.
## Each projectile is a small Node3D (forward = -Z): a shaped core, a soft additive glow and a particle trail. Meshes, materials and
## textures are built once and shared.

var _glow_tex: GradientTexture2D
var _puff_mat: StandardMaterial3D
var _cache := {}


func _glow() -> GradientTexture2D:
	if _glow_tex == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = gr
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


func _additive(col: Color, billboard: bool = true) -> StandardMaterial3D:
	var key := "add_%s_%s" % [col.to_html(), billboard]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _glow()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_cache[key] = m
	return m


func _solid(col: Color, rough: float = 0.6, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var key := "solid_%s_%s_%s_%s" % [col.to_html(), rough, metal, emit]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


func _quad(size: float) -> QuadMesh:
	var key := "quad_%s" % size
	if not _cache.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		_cache[key] = q
	return _cache[key]


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _glow_sprite(parent: Node3D, size: float, col: Color, pos: Vector3 = Vector3.ZERO) -> void:
	_add(parent, _quad(size), _additive(col), pos)


## Particle trail left in the world behind the projectile.
func _trail(parent: Node3D, col_a: Color, col_b: Color, amount: int, life: float, size: float, up: float = 0.0, spread: float = 18.0, vel: float = 0.4) -> void:
	var p := CPUParticles3D.new()
	p.amount = maxi(int(amount * Settings.part_mult()), 3)
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = spread
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, up, 0)
	p.mesh = _quad(size)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gr.colors = PackedColorArray([col_a, col_b, Color(col_b, 0.0)])
	p.color_ramp = gr
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.material_override = _additive(Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


func make(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"arrow":
			_arrow(n)
		"orb":
			_core_orb(n, Color("ff3a3a"), Color("ffd0c0"), 0.2, 1.5)
			_trail(n, Color(1.0, 0.5, 0.35, 0.9), Color(0.9, 0.1, 0.05, 0.6), 16, 0.5, 0.26, 0.0, 30.0, 0.5)
		"fire":
			_core_orb(n, Color("ff7a1a"), Color("fff0a0"), 0.17, 1.3, Vector3(1, 1, 1.7))
			_trail(n, Color(1.0, 0.85, 0.3, 0.95), Color(1.0, 0.3, 0.05, 0.6), 22, 0.5, 0.3, 2.2, 25.0, 0.6)
		"venom":
			_core_orb(n, Color("5aff6a"), Color("d8ffd0"), 0.17, 1.2, Vector3(1, 1, 1.4))
			_trail(n, Color(0.5, 1.0, 0.4, 0.9), Color(0.1, 0.6, 0.1, 0.5), 12, 0.6, 0.18, -5.0, 40.0, 0.8)
		"missile":
			_missile(n)
		"bullet":
			_bullet(n)
		_:
			_crystal(n)
	return n


func _core_orb(n: Node3D, col: Color, hot: Color, r: float, glow: float, stretch: Vector3 = Vector3.ONE) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	_add(n, s, _solid(col, 0.3, 0.0, 2.0), Vector3.ZERO, Vector3.ZERO, stretch)
	var s2 := SphereMesh.new()
	s2.radius = r * 0.55
	s2.height = r * 1.1
	s2.radial_segments = 8
	s2.rings = 4
	_add(n, s2, _solid(hot.lerp(col, 0.35), 0.2, 0.0, 3.0), Vector3.ZERO, Vector3.ZERO, stretch)
	_glow_sprite(n, glow * 0.85, Color(col, 0.5))
	_glow_sprite(n, glow * 0.38, Color(hot.lerp(col, 0.3), 0.7))


func _arrow(n: Node3D) -> void:
	if not _cache.has("arrow_shaft"):
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.011
		shaft.bottom_radius = 0.011
		shaft.height = 0.82
		shaft.radial_segments = 6
		shaft.rings = 1
		_cache["arrow_shaft"] = shaft
		var head := CylinderMesh.new()
		head.top_radius = 0.0
		head.bottom_radius = 0.026
		head.height = 0.15
		head.radial_segments = 6
		head.rings = 1
		_cache["arrow_head"] = head
		var vane := BoxMesh.new()
		vane.size = Vector3(0.004, 0.05, 0.13)
		_cache["arrow_vane"] = vane
		var nock := SphereMesh.new()
		nock.radius = 0.014
		nock.height = 0.028
		nock.radial_segments = 6
		nock.rings = 3
		_cache["arrow_nock"] = nock
	var holder := Node3D.new()
	n.add_child(holder)
	_add(holder, _cache["arrow_shaft"], _solid(Color("b08a58"), 0.8), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_add(holder, _cache["arrow_head"], _solid(Color("b9c0cc"), 0.35, 0.8), Vector3(0, 0, -0.47), Vector3(-PI / 2, 0, 0))
	for i in 3:
		var a := float(i) / 3.0 * TAU
		_add(holder, _cache["arrow_vane"], _solid(Color("d8d0c0" if i != 0 else "a8261c"), 0.9), Vector3(0, sin(a) * 0.028, 0.35 + 0.0), Vector3(0, 0, a + PI / 2.0))
	_add(holder, _cache["arrow_nock"], _solid(Color("302018"), 0.8), Vector3(0, 0, 0.42))
	_glow_sprite(n, 0.3, Color(1.0, 0.95, 0.8, 0.25), Vector3(0, 0, -0.45))
	_trail(n, Color(1, 1, 1, 0.4), Color(0.8, 0.85, 1.0, 0.2), 8, 0.3, 0.07, 0.0, 6.0, 0.1)


func _crystal(n: Node3D) -> void:
	if not _cache.has("crystal"):
		var c := SphereMesh.new()
		c.radius = 0.16
		c.height = 0.5
		c.radial_segments = 5
		c.rings = 2
		_cache["crystal"] = c
	var holder := Node3D.new()
	n.add_child(holder)
	holder.rotation = Vector3(PI / 2, 0, 0)
	_add(holder, _cache["crystal"], _solid(Color("b060f0"), 0.15, 0.0, 2.2))
	_add(holder, _cache["crystal"], _solid(Color("e0c0ff"), 0.1, 0.0, 3.5), Vector3.ZERO, Vector3.ZERO, Vector3(0.5, 0.6, 0.5))
	_glow_sprite(n, 0.9, Color(0.7, 0.35, 1.0, 0.5))
	_glow_sprite(n, 0.4, Color(1.0, 0.85, 1.0, 0.7))
	_trail(n, Color(0.9, 0.7, 1.0, 0.95), Color(0.5, 0.2, 0.9, 0.6), 16, 0.55, 0.16, 0.0, 35.0, 0.7)


func _missile(n: Node3D) -> void:
	if not _cache.has("missile_body"):
		var body := CylinderMesh.new()
		body.top_radius = 0.1
		body.bottom_radius = 0.1
		body.height = 0.75
		body.radial_segments = 10
		body.rings = 1
		_cache["missile_body"] = body
		var nose := CylinderMesh.new()
		nose.top_radius = 0.0
		nose.bottom_radius = 0.1
		nose.height = 0.25
		nose.radial_segments = 10
		nose.rings = 1
		_cache["missile_nose"] = nose
		var fin := BoxMesh.new()
		fin.size = Vector3(0.015, 0.2, 0.2)
		_cache["missile_fin"] = fin
	var holder := Node3D.new()
	n.add_child(holder)
	_add(holder, _cache["missile_body"], _solid(Color("8a96a6"), 0.35, 0.8), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_add(holder, _cache["missile_nose"], _solid(Color("30e0ff"), 0.3, 0.2, 1.5), Vector3(0, 0, -0.5), Vector3(-PI / 2, 0, 0))
	for i in 4:
		_add(holder, _cache["missile_fin"], _solid(Color("5a6676"), 0.4, 0.7), Vector3(0, 0, 0.3), Vector3(0, 0, float(i) * PI / 2.0))
	_glow_sprite(n, 0.95, Color(0.3, 0.85, 1.0, 0.55), Vector3(0, 0, 0.45))
	_glow_sprite(n, 0.4, Color(0.9, 1.0, 1.0, 0.8), Vector3(0, 0, 0.42))
	_trail(n, Color(0.7, 0.95, 1.0, 0.8), Color(0.3, 0.35, 0.4, 0.5), 22, 0.8, 0.34, 0.6, 14.0, 0.5)


func _bullet(n: Node3D) -> void:
	if not _cache.has("bullet_mesh"):
		var b := CylinderMesh.new()
		b.top_radius = 0.02
		b.bottom_radius = 0.02
		b.height = 0.55
		b.radial_segments = 6
		b.rings = 1
		_cache["bullet_mesh"] = b
	_add(n, _cache["bullet_mesh"], _solid(Color("ffd070"), 0.2, 0.0, 4.0), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_glow_sprite(n, 0.5, Color(1.0, 0.8, 0.35, 0.6))
	_trail(n, Color(1.0, 0.9, 0.5, 0.8), Color(1.0, 0.5, 0.1, 0.4), 10, 0.18, 0.12, 0.0, 4.0, 0.1)
