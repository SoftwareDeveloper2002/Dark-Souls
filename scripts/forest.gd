extends RefCounted
## The forest that fills the map: conifers, dead trees, bushes and fallen logs placed deterministically on the terrain in 40 m chunks that
## stream in and out around the hero. Every chunk holds three detail levels of its trees (MultiMeshes) and shows the one that fits its distance.
## The road, camps, boss arenas, the tunnel and the start are kept clear; trunks block movement (see blocks()).

const World := preload("res://scripts/world.gd")
const CHUNK := 40.0
const MODELS := ["pine_1", "pine_1_lod1", "pine_1_lod2", "pine_2", "pine_2_lod1", "pine_2_lod2", "fir_1", "fir_1_lod1", "fir_1_lod2",
	"dead_1", "dead_2", "bush_1", "bush_2", "log_1"]
const VARIANTS := ["pine_1", "pine_2", "fir_1"]

var g  # the game node
var root: Node3D
var _mesh := {}
var _chunks := {}                 # Vector2i -> {"mmi": [[MultiMeshInstance3D, lod]...], "c": Vector2, "lod": int}
var _trunks := {}                 # Vector2i (6 m cells) -> Array of Vector3(x, z, radius)
var _route_hash := {}
var _discs: Array = []            # [centre Vector2, radius] clearings (camps, arenas, tunnel, start)
var _noise := FastNoiseLite.new()
var near_d := 36.0
var mid_d := 64.0
var far_d := 116.0
var density := 1.0
var enabled := true
var _focus := Vector2.ZERO
var _build_budget := 1
var stats := {"cand": 0, "thin": 0, "walk": 0, "slope": 0, "clear": 0, "kept": 0}
var _fade := {}  # tree key -> {"a": opacity, "ghost": MeshInstance3D, "mats": [materials]} for trees that block the camera's view of the hero
var _ghost_pool := {}  # mesh -> Array of idle see-through copies ({"mi": MeshInstance3D, "mats": [materials]}), reused so walking through trees allocates nothing


func setup(game: Node3D) -> void:
	g = game
	root = Node3D.new()
	root.name = "Forest"
	g.add_child(root)
	_noise.seed = 4242
	_noise.frequency = 0.011
	_noise.fractal_octaves = 2
	for name in MODELS:
		var path := "res://assets/models/forest/%s.glb" % name
		if not ResourceLoader.exists(path):
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		var mi := inst.find_children("*", "MeshInstance3D", true, false)
		if not mi.is_empty():
			var mesh: Mesh = (mi[0] as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var sm = mesh.surface_get_material(si)
				if sm is StandardMaterial3D and not (sm as StandardMaterial3D).vertex_color_use_as_albedo:
					var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
					dm.vertex_color_use_as_albedo = true
					dm.roughness = 0.9
					mesh.surface_set_material(si, dm)
			_mesh[name] = mesh
		inst.free()
	enabled = _mesh.has("pine_1")
	# clearings: the road, quest sites, start
	for i in World.ROUTE.size():
		var c := Vector2i(floori(World.ROUTE[i].x / 32.0), floori(World.ROUTE[i].y / 32.0))
		if not _route_hash.has(c):
			_route_hash[c] = []
		_route_hash[c].append(i)
	_discs.append([World.start(), 18.0])
	_discs.append([World.sword_spot(), 10.0])
	for n in range(1, 41):
		_discs.append([World.site(n), 40.0])


## Applies a graphics level: detail distances and how thick the forest is.
func set_params(near: float, mid: float, far: float, dens: float) -> void:
	if near == near_d and mid == mid_d and far == far_d and dens == density:
		return
	near_d = near
	mid_d = mid
	far_d = far
	density = dens
	clear_all()


func clear_all() -> void:
	for ci in _chunks.keys():
		_free_chunk(ci)


func _free_chunk(ci: Vector2i) -> void:
	var ch: Dictionary = _chunks[ci]
	for k in _fade.keys():
		if k.begins_with("%d_%d_" % [ci.x, ci.y]):
			_release_ghost(_fade[k])
			_fade.erase(k)
	for e in ch.mmi:
		(e[0] as Node).queue_free()
	for cell in ch.cells:
		_trunks.erase(cell)
	_chunks.erase(ci)


## Rebuilds the trees around a point (after a maze, bridge or arena has been built there).
func refresh_near(pos: Vector2, radius: float) -> void:
	for ci in _chunks.keys():
		var ch: Dictionary = _chunks[ci]
		if (ch.c as Vector2).distance_to(pos) < radius + CHUNK:
			_free_chunk(ci)


func add_disc(pos: Vector2, radius: float) -> void:
	_discs.append([pos, radius])
	refresh_near(pos, radius)


# ------------------------------------------------------------------ collision

## The trunk closest to `p` (within `reach`), or Vector2.INF when the surrounding chunks have none.
func nearest_tree(p: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	var bd := reach * reach
	var cr := ceili(reach / 6.0)
	var cx := floori(p.x / 6.0)
	var cz := floori(p.y / 6.0)
	for dx in range(-cr, cr + 1):
		for dz in range(-cr, cr + 1):
			var arr = _trunks.get(Vector2i(cx + dx, cz + dz))
			if arr == null:
				continue
			for t in arr:
				var d: float = (p.x - t.x) * (p.x - t.x) + (p.y - float(t.y)) * (p.y - float(t.y))
				if d < bd:
					bd = d
					best = Vector2(t.x, t.y)
	return best


func blocks(p: Vector2, rad: float) -> bool:
	var cx := floori(p.x / 6.0)
	var cz := floori(p.y / 6.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var arr = _trunks.get(Vector2i(cx + dx, cz + dz))
			if arr == null:
				continue
			for t in arr:
				var lim: float = rad + float(t.z)
				if (p.x - t.x) * (p.x - t.x) + (p.y - float(t.y)) * (p.y - float(t.y)) < lim * lim:
					return true
	return false


# ------------------------------------------------------------------ placement

func _cleared(p: Vector2) -> bool:
	var rc := Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lst = _route_hash.get(Vector2i(rc.x + dx, rc.y + dz))
			if lst == null:
				continue
			for i in lst:
				var lim := float(World.CLEAR[i]) * 0.5 + 4.5
				if p.distance_squared_to(World.ROUTE[i]) < lim * lim:
					return true
	for d in _discs:
		var c: Vector2 = d[0]
		var r: float = d[1]
		if absf(p.x - c.x) < r and absf(p.y - c.y) < r and p.distance_squared_to(c) < r * r:
			return true
	var tp: PackedVector2Array = g.structures.tunnel_pts
	for q in tp:
		if p.distance_squared_to(q) < 26.0 * 26.0:
			return true
	if g.structures.in_maze(p) or g.structures.on_bridge(p):
		return true
	return g.structures.wall_hit(p, 3.0)


func _hash(ci: Vector2i) -> int:
	return ci.x * 73856093 ^ ci.y * 19349663 ^ 0x5bd1e995


func _make_chunk(ci: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(ci)
	var origin := Vector2(ci.x * CHUNK, ci.y * CHUNK)
	var variant: String = VARIANTS[rng.randi() % VARIANTS.size()]
	var conifers: Array = []
	var dead: Array = []
	var bushes: Array = []
	var logs: Array = []
	var cells: Array = []
	var step := 3.7
	var n := int(CHUNK / step)
	for gx in n:
		for gz in n:
			var p := origin + Vector2((gx + 0.5) * step, (gz + 0.5) * step) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			var thick := clampf(0.92 + 0.5 * _noise.get_noise_2d(p.x, p.y), 0.3, 1.0) * density
			stats.cand += 1
			var roll := rng.randf()
			if roll > thick:
				stats.thin += 1
				continue
			if not g._walk_ok(p):
				stats.walk += 1
				continue
			var h: float = g._h(p)
			if absf(g._h(p + Vector2(1.6, 0)) - h) > 2.3 or absf(g._h(p + Vector2(0, 1.6)) - h) > 2.3:
				stats.slope += 1
				continue
			if _cleared(p):
				stats.clear += 1
				continue
			stats.kept += 1
			var kind := rng.randf()
			var yaw := rng.randf() * TAU
			var s := rng.randf_range(0.75, 1.35)
			var tilt := Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
			var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)).scaled(Vector3(s * rng.randf_range(0.92, 1.08), s, s * rng.randf_range(0.92, 1.08)))
			var shade := rng.randf_range(0.7, 1.15)
			var col := Color(shade, shade * rng.randf_range(0.98, 1.06), shade * rng.randf_range(0.9, 1.0))
			var tr := Transform3D(b, Vector3(p.x, h - 0.15, p.y))
			if kind < 0.025:
				logs.append([Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), Vector3(p.x, h - 0.05, p.y)), col])
			elif kind < 0.06:
				dead.append([tr, col])
				_add_trunk(p, 0.28 * s, cells)
			else:
				conifers.append([tr, col])
				_add_trunk(p, 0.34 * s, cells)
				# undergrowth around the trunk
				if rng.randf() < 0.55:
					var bp := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.2, 2.6)
					bushes.append([Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(bp.x, g._h(bp) - 0.05, bp.y)), col])
	var mmis: Array = []
	var trees: Array = []
	for lod in 3:
		var suffix: String = ["", "_lod1", "_lod2"][lod]
		if _mesh.has(variant + suffix) and not conifers.is_empty():
			var mmi := _make_mmi(_mesh[variant + suffix], conifers)
			mmis.append([mmi, lod, true])
			for i in conifers.size():
				if lod == 0:
					trees.append({"p": Vector2((conifers[i][0] as Transform3D).origin.x, (conifers[i][0] as Transform3D).origin.z), "tr": conifers[i][0], "col": conifers[i][1], "mesh": _mesh[variant], "refs": []})
				trees[i].refs.append([mmi.multimesh, i])
	if not dead.is_empty():
		var dmmi := _make_mmi(_mesh["dead_1" if rng.randf() < 0.5 else "dead_2"], dead)
		mmis.append([dmmi, 0, false])
		for i in dead.size():
			trees.append({"p": Vector2((dead[i][0] as Transform3D).origin.x, (dead[i][0] as Transform3D).origin.z), "tr": dead[i][0], "col": dead[i][1], "mesh": dmmi.multimesh.mesh, "refs": [[dmmi.multimesh, i]]})
	if not bushes.is_empty():
		mmis.append([_make_mmi(_mesh["bush_1" if rng.randf() < 0.5 else "bush_2"], bushes), 0, false])
	if not logs.is_empty():
		mmis.append([_make_mmi(_mesh["log_1"], logs), 0, false])
	_chunks[ci] = {"mmi": mmis, "c": origin + Vector2(CHUNK, CHUNK) * 0.5, "lod": -1, "cells": cells, "trees": trees}
	_apply_lod(ci)


func _add_trunk(p: Vector2, r: float, cells: Array) -> void:
	var cell := Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))
	if not _trunks.has(cell):
		_trunks[cell] = []
		cells.append(cell)
	_trunks[cell].append(Vector3(p.x, p.y, r))


func _make_mmi(mesh: Mesh, items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi


func _apply_lod(ci: Vector2i) -> void:
	var ch: Dictionary = _chunks[ci]
	var d: float = (ch.c as Vector2).distance_to(_focus) - CHUNK * 0.5
	var lod := 0 if d < near_d else (1 if d < mid_d else 2)
	if lod == ch.lod:
		return
	ch.lod = lod
	for e in ch.mmi:
		# live trees have one MultiMesh per level; bushes, dead trees and logs only exist at the nearest level
		(e[0] as MultiMeshInstance3D).visible = (e[1] == lod) if e[2] else lod == 0


## Trees between the camera and the hero turn see-through (and solid again) so the hero and the fight are never hidden behind a trunk.
## A blocking tree is swapped for a ghost copy with blended materials; every other tree stays a cheap opaque MultiMesh instance.
func _see_through(dt: float, hero: Vector2, back: Vector2) -> void:
	# trees that are already ghosts: fade toward their target, wherever the hero has gone
	for key in _fade.keys():
		var f: Dictionary = _fade[key]
		var t: Dictionary = f.t
		var v: Vector2 = (t.p as Vector2) - hero
		f.a = move_toward(f.a, 0.18 if _blocks_view(v, back) else 1.0, dt * 3.0)
		for m in f.mats:
			(m as StandardMaterial3D).albedo_color.a = f.a
		if f.a >= 0.999:
			# solid again: drop the ghost and bring the instance back
			_release_ghost(f)
			_fade.erase(key)
			for r in t.refs:
				(r[0] as MultiMesh).set_instance_transform(r[1], t.tr)
	# new blockers near the hero
	var rc := Vector2i(floori(hero.x / CHUNK), floori(hero.y / CHUNK))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var ci := Vector2i(rc.x + dx, rc.y + dz)
			if not _chunks.has(ci):
				continue
			var trees: Array = _chunks[ci].trees
			for ti in trees.size():
				var t: Dictionary = trees[ti]
				var v: Vector2 = (t.p as Vector2) - hero
				if v.length_squared() > 190.0 or not _blocks_view(v, back):
					continue
				var key := "%d_%d_%d" % [ci.x, ci.y, ti]
				if not _fade.has(key):
					_fade[key] = _start_ghost(t)


func _blocks_view(v: Vector2, back: Vector2) -> bool:
	var along := v.dot(back)
	var perp := absf(v.x * back.y - v.y * back.x)
	return v.length_squared() < 6.0 or (along > -1.5 and along < 11.0 and perp < 3.4)


func _release_ghost(f: Dictionary) -> void:
	var mi: MeshInstance3D = f.ghost
	mi.visible = false
	var mesh: Mesh = f.mesh
	if not _ghost_pool.has(mesh):
		_ghost_pool[mesh] = []
	if (_ghost_pool[mesh] as Array).size() < 16:
		(_ghost_pool[mesh] as Array).append({"mi": mi, "mats": f.mats})
	else:
		mi.queue_free()


func _start_ghost(t: Dictionary) -> Dictionary:
	var mesh: Mesh = t.mesh
	var col: Color = t.col
	var gh: Dictionary
	var pool: Array = _ghost_pool.get(mesh, [])
	if not pool.is_empty():
		gh = pool.pop_back()
		for m in gh.mats:
			(m as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 1.0)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mats: Array = []
		for si in mesh.get_surface_count():
			var sm = mesh.surface_get_material(si)
			if sm is StandardMaterial3D:
				var gm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				gm.albedo_color = Color(col.r, col.g, col.b, 1.0)
				mi.set_surface_override_material(si, gm)
				mats.append(gm)
		root.add_child(mi)
		gh = {"mi": mi, "mats": mats}
	var node: MeshInstance3D = gh.mi
	node.transform = t.tr
	node.visible = true
	# hide the opaque instance (zero scale) while the ghost stands in for it
	var hidden: Transform3D = t.tr
	hidden.basis = Basis.from_scale(Vector3.ONE * 0.0001)
	for r in t.refs:
		(r[0] as MultiMesh).set_instance_transform(r[1], hidden)
	return {"a": 1.0, "ghost": node, "mats": gh.mats, "t": t, "mesh": mesh}


## Streams chunks around `focus` (world position of the hero): builds a few per call, frees the far ones, switches detail levels.
func update(dt: float, focus: Vector3, hero: Vector2 = Vector2.INF, cam_pos: Vector3 = Vector3.INF) -> void:
	if not enabled:
		return
	_focus = Vector2(focus.x, focus.z)
	if hero != Vector2.INF and cam_pos != Vector3.INF:
		var back := Vector2(cam_pos.x - hero.x, cam_pos.z - hero.y)
		if back.length() > 0.5 and dt > 0.0:
			_see_through(dt, hero, back.normalized())
	var r := far_d + CHUNK
	var c0 := Vector2i(floori((_focus.x - r) / CHUNK), floori((_focus.y - r) / CHUNK))
	var c1 := Vector2i(floori((_focus.x + r) / CHUNK), floori((_focus.y + r) / CHUNK))
	var wanted: Array = []
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			var ci := Vector2i(x, z)
			var centre := Vector2((x + 0.5) * CHUNK, (z + 0.5) * CHUNK)
			var d := centre.distance_to(_focus)
			if d < far_d + CHUNK * 0.4 and not _chunks.has(ci):
				wanted.append([d, ci])
	if not wanted.is_empty():
		wanted.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(_build_budget, wanted.size()):
			_make_chunk(wanted[i][1])
	for ci in _chunks.keys():
		var ch: Dictionary = _chunks[ci]
		var d2: float = (ch.c as Vector2).distance_to(_focus)
		if d2 > far_d + CHUNK * 1.6:
			_free_chunk(ci)
		else:
			_apply_lod(ci)


## Builds everything near `focus` at once (used behind the loading screen).
func prime(focus: Vector3, count: int = 12) -> void:
	_build_budget = count
	update(0.0, focus)
	_build_budget = 1
