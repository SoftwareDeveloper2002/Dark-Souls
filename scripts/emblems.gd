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


## Where an emblem can lie: three camps (quests 5, 12, 20) each hide one at the TENT, one at the ROCK nearest the bonfire and one at the TREE
## nearest the bonfire; the labyrinth hides the last three against walls of its dead ends. A slot only exists (has = true) while the thing it
## belongs to is standing, i.e. while that quest's camp is up or once the labyrinth is built.
const CAMP_QUESTS := [5, 12, 20]
const CAMP_KINDS := ["tent", "rock", "tree"]


func _place() -> void:
	for qn in CAMP_QUESTS:
		for k in CAMP_KINDS:
			items.append({"pos": Vector2.INF, "node": null, "live": false, "quest": qn, "src": k})
	for i in 3:
		items.append({"pos": Vector2.INF, "node": null, "live": false, "quest": 27, "src": "wall"})


## A point `off` metres from `obj` towards `c`, so the emblem sits right beside the thing and never inside it.
func _beside(obj: Vector2, c: Vector2, off: float) -> Vector2:
	var dir: Vector2 = (c - obj).normalized() if obj.distance_to(c) > 0.1 else Vector2.RIGHT
	for extra: float in [0.0, 1.0, 2.0, -1.0]:
		var p: Vector2 = obj + dir * (off + extra)
		if g._walk_ok(p):
			return p
	return obj + dir * off


## Called when a quest's camp has just been built. `info` lists the camp's tents and rocks.
func camp_built(qn: int, c: Vector2, info: Dictionary) -> void:
	for it in items:
		if it.quest != qn or it.src == "wall":
			continue
		var obj := Vector2.INF
		var off := 2.0
		match it.src:
			"tent":
				var tents: Array = info.get("tents", [])
				if not tents.is_empty():
					obj = _nearest(tents, c)
				off = 2.4
			"rock":
				var rocks: Array = info.get("rocks", [])
				if not rocks.is_empty():
					obj = _nearest(rocks, c)
				off = 1.9
			"tree":
				obj = g.forest.nearest_tree(c, 45.0)
				off = 1.3
		if obj == Vector2.INF:
			# nothing of that kind was built here this time: put it where the thing would stand, at the camp's edge
			obj = c + Vector2.from_angle(float(CAMP_KINDS.find(it.src)) * 2.1) * 9.0
		it.pos = _beside(obj, c, off)
		it.live = true


## The camp was torn down: its emblems go with it (collected ones stay collected).
func camp_freed() -> void:
	for it in items:
		if it.src != "wall" and it.live:
			it.live = false
			if it.node != null:
				(it.node as Node).queue_free()
				it["node"] = null


## The labyrinth is finished: three emblems against the walls of far dead ends.
func maze_built(maze: Dictionary) -> void:
	var dead: Array = (maze.get("dead", []) as Array).duplicate()
	var entrance: Vector2 = maze.entrance
	var civ: Array = maze.get("civ_spots", [])
	dead = dead.filter(func(d): return d.distance_to(entrance) > 18.0 and not civ.any(func(c): return d.distance_to(c) < 7.0))
	dead.sort_custom(func(a, b): return a.distance_to(entrance) < b.distance_to(entrance))
	var picks: Array = []
	for f in [0.35, 0.65, 0.95]:
		if dead.is_empty():
			break
		picks.append(dead[clampi(int(float(dead.size() - 1) * f), 0, dead.size() - 1)])
	var slot := 0
	for it in items:
		if it.src != "wall":
			continue
		if slot >= picks.size():
			break
		var cell: Vector2 = picks[slot]
		slot += 1
		# hug the wall of the dead end: the side that is closed
		var best := cell
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			if g.structures.wall_only(cell + dir * float(maze.cell) * 0.5, 0.2):
				best = cell + dir * 1.5
				break
		it.pos = best
		it.live = true


func _nearest(list: Array, c: Vector2) -> Vector2:
	var best: Vector2 = list[0]
	for p in list:
		if (p as Vector2).distance_to(c) < best.distance_to(c):
			best = p
	return best


func found_positions() -> Array:
	var out: Array = []
	for i in found:
		if items[i].pos != Vector2.INF:
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
		var it: Dictionary = items[i]
		if found.has(i) or not it.live:
			continue
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
		g._show_banner("A HIDDEN ASHEN EMBLEM", 4.0, "Eleven more lie at camp tents, rocks and trees, and in the labyrinth walls...")
	elif complete():
		g.unlimited_ammo = true
		g._show_banner("THE ASHEN ARSENAL", 5.0, "All 12 emblems found - UNLIMITED AMMO for every gun")
		g.fx.strike(g._p3(g.p_pos))
		g.sfx("chime", 0.0, 0.8)
		g.refresh_weapon_ui()
	else:
		g._show_banner("ASHEN EMBLEM  %d / %d" % [found.size(), COUNT], 2.4, "")
	g._save()
