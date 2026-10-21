extends RefCounted
## The hidden quest: twelve ASHEN EMBLEMS glint in the dark forest, each off the road in a spot you only find by exploring (like the
## BSAA emblems in Resident Evil 5). Nothing on screen mentions them until the first one is found. Collect all twelve for a secret
## reward: unlimited ammo for every gun.

const World := preload("res://scripts/world.gd")
const COUNT := 12
const SHOW_DIST := 95.0

var g  # the game node
var root: Node3D
var items: Array = []   # {"pos": Vector2, "node": Node3D or null}
var found: Array = []   # indices already collected
var _gold: StandardMaterial3D
var _gem: StandardMaterial3D
var _dark: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _t := 0.0


func setup(game: Node3D) -> void:
	g = game
	root = Node3D.new()
	root.name = "Emblems"
	g.add_child(root)
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color("e8c25a")
	_gold.metallic = 0.85
	_gold.roughness = 0.3
	_gold.emission_enabled = true
	_gold.emission = Color("c8902a")
	_gold.emission_energy_multiplier = 0.9
	_gem = StandardMaterial3D.new()
	_gem.albedo_color = Color("5ad0ff")
	_gem.emission_enabled = true
	_gem.emission = Color("5ad0ff")
	_gem.emission_energy_multiplier = 2.5
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color("2a1a0a")
	_dark.roughness = 0.6
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.albedo_texture = g.proj_art._glow()
	_glow_mat.albedo_color = Color(1.0, 0.82, 0.35, 0.5)
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_place()


func _valid(p: Vector2) -> bool:
	if not g._walk_ok(p):
		return false
	var h: float = g._h(p)
	if absf(g._h(p + Vector2(1.5, 0)) - h) > 1.2 or absf(g._h(p + Vector2(0, 1.5)) - h) > 1.2:
		return false
	for n in range(1, 41):
		if p.distance_to(World.site(n)) < 52.0:
			return false
	if p.distance_to(World.start()) < 40.0:
		return false
	return not g.structures.wall_hit(p, 2.0) and not g.structures.on_bridge(p)


func _place() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var n := World.ROUTE.size()
	var tr := World.tunnel_range()
	for k in COUNT:
		var base := 14 + int(float(k) * float(n - 40) / float(COUNT - 1))
		var spot := Vector2.ZERO
		var ok := false
		for attempt in 60:
			var idx := clampi(base + rng.randi_range(-9, 9), 8, n - 10)
			if idx >= tr.x - 16 and idx <= tr.y + 16:
				continue
			var d := World.dir_at(idx)
			var nrm := Vector2(-d.y, d.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p: Vector2 = World.ROUTE[idx] + nrm * rng.randf_range(30.0, 64.0)
			if _valid(p):
				spot = p
				ok = true
				break
		if not ok:
			var idx2 := clampi(base, 8, n - 10)
			spot = World.ROUTE[idx2] + Vector2(-World.dir_at(idx2).y, World.dir_at(idx2).x) * 24.0
		items.append({"pos": spot, "node": null})
		g.forest.add_disc(spot, 2.4)  # a small clearing so it can always be reached


func found_positions() -> Array:
	var out: Array = []
	for i in found:
		out.append(items[i].pos)
	return out


func complete() -> bool:
	return found.size() >= COUNT


func to_array() -> Array:
	return found.duplicate()


func from_array(a: Array) -> void:
	found.clear()
	for v in a:
		if int(v) >= 0 and int(v) < COUNT and not found.has(int(v)):
			found.append(int(v))


func _make_node() -> Node3D:
	var n := Node3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.24
	disc.bottom_radius = 0.24
	disc.height = 0.05
	disc.radial_segments = 20
	disc.rings = 1
	var holder := Node3D.new()
	holder.rotation.x = PI / 2
	n.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _gold
	holder.add_child(mi)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.215
	rim.outer_radius = 0.265
	rim.rings = 20
	rim.ring_segments = 8
	var rm := MeshInstance3D.new()
	rm.mesh = rim
	rm.material_override = _gold
	holder.add_child(rm)
	# a cross of dark inlay and a blue gem in the middle
	for dim in [Vector3(0.05, 0.02, 0.32), Vector3(0.32, 0.02, 0.05)]:
		var bx := BoxMesh.new()
		bx.size = dim
		var bm := MeshInstance3D.new()
		bm.mesh = bx
		bm.material_override = _dark
		bm.position = Vector3(0, -0.03, 0)
		holder.add_child(bm)
	var gem := SphereMesh.new()
	gem.radius = 0.045
	gem.height = 0.09
	gem.radial_segments = 10
	gem.rings = 5
	var gm := MeshInstance3D.new()
	gm.mesh = gem
	gm.material_override = _gem
	gm.position = Vector3(0, -0.045, 0)
	holder.add_child(gm)
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	var glow := MeshInstance3D.new()
	glow.mesh = q
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(glow)
	var p := CPUParticles3D.new()
	p.amount = maxi(int(6 * Settings.part_mult()), 2)
	p.lifetime = 1.8
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var pq := QuadMesh.new()
	pq.size = Vector2(0.07, 0.07)
	p.mesh = pq
	p.material_override = _glow_mat
	n.add_child(p)
	return n


func update(dt: float) -> void:
	_t += dt
	var hero: Vector2 = g.p_pos
	for i in items.size():
		if found.has(i):
			continue
		var it: Dictionary = items[i]
		var d: float = hero.distance_to(it.pos)
		if d < SHOW_DIST and it.node == null:
			var nd := _make_node()
			root.add_child(nd)
			it["node"] = nd
		elif d > SHOW_DIST + 25.0 and it.node != null:
			(it.node as Node).queue_free()
			it["node"] = null
		if it.node != null:
			var n3: Node3D = it.node
			n3.global_position = Vector3(it.pos.x, g._h(it.pos) + 0.75 + sin(_t * 1.6 + float(i)) * 0.08, it.pos.y)
			n3.rotation.y = _t * 1.4 + float(i)
		if d < 1.9 and g.state == "play":
			_collect(i)


func _collect(i: int) -> void:
	var it: Dictionary = items[i]
	found.append(i)
	if it.node != null:
		(it.node as Node).queue_free()
		it["node"] = null
	g._burst(it.pos, 30, Color("f2d27a"), 7.0, 1.0)
	g._burst(it.pos, 14, Color.WHITE, 4.0, 1.4)
	g.sfx("chime", -1.0, 1.15)
	g._float(g._p3(it.pos, 1.8), "ASHEN EMBLEM  %d / %d" % [found.size(), COUNT], Color("f2d27a"))
	if found.size() == 1:
		g._show_banner("A HIDDEN ASHEN EMBLEM", 4.0, "Eleven more are hidden in the forest...")
	elif complete():
		g.unlimited_ammo = true
		g._show_banner("THE ASHEN ARSENAL", 5.0, "All 12 emblems found - UNLIMITED AMMO for every gun")
		g.fx.strike(g._p3(g.p_pos))
		g.sfx("chime", 0.0, 0.8)
		g.refresh_weapon_ui()
	else:
		g._show_banner("ASHEN EMBLEM  %d / %d" % [found.size(), COUNT], 2.4, "")
	g._save()
