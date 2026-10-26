extends RefCounted
## World structures along the road: the cutaway tunnel, the treasure labyrinth, and the boss bridge.
## All walls are solid (line segments with thickness) so the player and enemies can't pass through.

const World := preload("res://scripts/world.gd")

var g  # the game node
var walls: Array = []     # {a: Vector2, b: Vector2, r: float, grp: int}
var groups: Array = []    # {c: Vector2, r: float} quick-reject bounds per structure
var tunnel_pts := PackedVector2Array()
var tunnel_w := 5.0
var maze := {}
const GRID := 8.0
const _NO_WALLS: Array = []
var _wall_mat: StandardMaterial3D = null
var bridge := {}


func setup(game) -> void:
	g = game


# ------------------------------------------------------------------ helpers

func wall_hit(p: Vector2, rad: float) -> bool:
	if g.get("forest") != null and g.forest.blocks(p, rad):
		return true
	for grp in groups.size():
		var gr: Dictionary = groups[grp]
		if p.distance_squared_to(gr.c) > (gr.r + 4.0) * (gr.r + 4.0):
			continue
		for w in gr.grid.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), _NO_WALLS):
			var a: Vector2 = w.a
			var b: Vector2 = w.b
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var cp := a + ab * t
			var lim: float = rad + float(w.r)
			if p.distance_squared_to(cp) < lim * lim:
				return true
	return false


## Like wall_hit but only for built walls (trees are made see-through instead), with a loose radius; used to keep the camera's view clear.
func wall_only(p: Vector2, rad: float) -> bool:
	for grp in groups.size():
		var gr: Dictionary = groups[grp]
		if p.distance_squared_to(gr.c) > (gr.r + 4.0) * (gr.r + 4.0):
			continue
		for w in gr.grid.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), _NO_WALLS):
			var a: Vector2 = w.a
			var b: Vector2 = w.b
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var cp := a + ab * t
			var lim: float = rad + float(w.r)
			if p.distance_squared_to(cp) < lim * lim:
				return true
	return false


func _new_group(c: Vector2, r: float) -> int:
	groups.append({"c": c, "r": r, "w": [], "grid": {}})
	return groups.size() - 1


func _add_wall_seg(grp: int, a: Vector2, b: Vector2, thick: float) -> void:
	var w := {"a": a, "b": b, "r": thick * 0.5, "grp": grp}
	walls.append(w)
	groups[grp].w.append(w)
	# register the wall in every grid cell its (slightly fattened) box touches, so collision looks at one small list instead of every wall
	var grid: Dictionary = groups[grp].grid
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(2.8, 2.8)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(2.8, 2.8)
	for cx in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
		for cz in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
			var key := Vector2i(cx, cz)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(w)


func _batch() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## One box of a merged wall mesh (all boxes become a single draw call).
func _box(st: SurfaceTool, center: Vector3, size: Vector3, yaw: float) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	st.append_from(bm, 0, Transform3D(Basis(Vector3.UP, yaw), center))


func _finish(st: SurfaceTool, material: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _yaw_of(d: Vector2) -> float:
	return atan2(-d.y, d.x)


func _torch(parent: Node, pos: Vector3, col: Color) -> void:
	var lamp = g._prop("vintage_oil_lamp", Vector2(pos.x, pos.z), 1.5, 0.0, parent)
	if lamp == null:
		var pole = g._mesh(g._cyl(0.07, 1.5), g._mat(Color("2a1c10")), pos + Vector3(0, 0.75, 0), parent)
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fl := CPUParticles3D.new()
	fl.amount = 14
	fl.lifetime = 0.7
	fl.direction = Vector3.UP
	fl.spread = 12.0
	fl.initial_velocity_min = 0.8
	fl.initial_velocity_max = 1.6
	fl.gravity = Vector3.ZERO
	fl.mesh = g._sphere(0.11, g._unshaded(col))
	parent.add_child(fl)
	fl.global_position = pos + Vector3(0, 1.0 if lamp != null else 1.55, 0)


# ------------------------------------------------------------------- tunnel

func build_tunnel() -> void:
	var r := World.tunnel_range()
	var pts: Array = []
	for i in range(r.x - 1, r.y + 2):
		pts.append(World.ROUTE[i])
	tunnel_pts = PackedVector2Array(pts)
	var root := Node3D.new()
	g.add_child(root)
	var mid: Vector2 = pts[pts.size() / 2]
	var grp := _new_group(mid, 130.0)
	var st := _batch()
	var wall_h := 6.8
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		for side in [-1.0, 1.0]:
			var oa: Vector2 = a + nrm * tunnel_w * side - d * 0.9
			var ob: Vector2 = b + nrm * tunnel_w * side + d * 0.9
			var mp := (oa + ob) * 0.5
			var len := oa.distance_to(ob)
			var gh = g._h(mp)
			_box(st, Vector3(mp.x, gh + wall_h * 0.5 - 1.2, mp.y), Vector3(len, wall_h, 1.4), _yaw_of((ob - oa).normalized()))
			_add_wall_seg(grp, oa, ob, 1.4)
	_finish(st, g.rock_mat, root)

	# arched ribs overhead every ~6 m: you see the interior from above, but it still reads as a tunnel
	var rib := _batch()
	var carry := 0.0
	var ribs: Array = []
	for i in pts.size() - 1:
		var a2: Vector2 = pts[i]
		var b2: Vector2 = pts[i + 1]
		var seg := a2.distance_to(b2)
		var pos := carry
		while pos < seg:
			ribs.append([a2.lerp(b2, pos / seg), (b2 - a2).normalized()])
			pos += 6.0
		carry = pos - seg
	var torch_i := 0
	for rb in ribs:
		var c: Vector2 = rb[0]
		var d2: Vector2 = rb[1]
		var gh2 = g._h(c)
		var perp := _yaw_of(Vector2(-d2.y, d2.x))
		_box(rib, Vector3(c.x, gh2 + 5.9, c.y), Vector3(tunnel_w * 2.0 + 2.2, 0.9, 1.1), perp)
		_box(rib, Vector3(c.x, gh2 + 6.6, c.y), Vector3(tunnel_w * 2.0 + 0.6, 0.5, 0.7), perp)
		if torch_i % 2 == 0:
			var nrm2 := Vector2(-d2.y, d2.x)
			var side := 1.0 if (torch_i / 2) % 2 == 0 else -1.0
			var tp: Vector2 = c + nrm2 * (tunnel_w - 0.8) * side
			_torch(root, Vector3(tp.x, g._h(tp), tp.y), Color("ffb347"))
		torch_i += 1
	_finish(rib, g.rock_mat, root)

	# portal gates at both ends, with skull reliefs
	for end in [1, pts.size() - 2]:
		var pc: Vector2 = pts[end]
		var pd: Vector2 = (pts[mini(end + 1, pts.size() - 1)] - pts[maxi(end - 1, 0)]).normalized()
		var pn := Vector2(-pd.y, pd.x)
		var gh3 = g._h(pc)
		var port := _batch()
		for side in [-1.0, 1.0]:
			var pp: Vector2 = pc + pn * (tunnel_w + 0.6) * side
			_box(port, Vector3(pp.x, gh3 + 4.2, pp.y), Vector3(2.2, 9.0, 2.2), _yaw_of(pd))
		_box(port, Vector3(pc.x, gh3 + 8.6, pc.y), Vector3(tunnel_w * 2.0 + 5.0, 2.0, 2.4), _yaw_of(pn))
		_box(port, Vector3(pc.x, gh3 + 7.1, pc.y), Vector3(tunnel_w * 2.0 + 1.0, 1.0, 1.6), _yaw_of(pn))
		_finish(port, g.rock_mat, root)
		var bone = g._mat(Color("d8d2b8"), 0.8)
		for k in 5:
			var sp: Vector2 = pc + pn * lerpf(-3.6, 3.6, float(k) / 4.0) - pd * 1.3
			var sk = g._mesh(g._sphere(0.32), bone, Vector3(sp.x, gh3 + 7.5, sp.y), root)
			sk.scale = Vector3(1.0, 1.15, 1.0)
		_torch(root, Vector3((pc + pn * (tunnel_w + 2.4)).x, gh3, (pc + pn * (tunnel_w + 2.4)).y), Color("ff9a40"))
		_torch(root, Vector3((pc - pn * (tunnel_w + 2.4)).x, gh3, (pc - pn * (tunnel_w + 2.4)).y), Color("ff9a40"))

	# a few real lights inside (kept few for mobile)
	for f in [0.25, 0.55, 0.85]:
		var lp: Vector2 = pts[int(f * (pts.size() - 1))]
		var l := OmniLight3D.new()
		l.light_color = Color("ffa050")
		l.light_energy = 2.2
		l.omni_range = 15.0
		root.add_child(l)
		l.global_position = Vector3(lp.x, g._h(lp) + 3.4, lp.y)

	# bones, barrels and crates scattered along the sides
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var wood = g._mat(Color("3a2616"), 0.9)
	var bone2 = g._mat(Color("cfc8aa"), 0.85)
	for k in 26:
		var i := rng.randi_range(1, pts.size() - 2)
		var a3: Vector2 = pts[i]
		var b3: Vector2 = pts[i + 1]
		var d3 := (b3 - a3).normalized()
		var n3 := Vector2(-d3.y, d3.x)
		var side2 := 1.0 if rng.randf() < 0.5 else -1.0
		var pp2: Vector2 = a3.lerp(b3, rng.randf()) + n3 * side2 * rng.randf_range(2.8, tunnel_w - 1.0)
		var gy = g._h(pp2)
		match k % 3:
			0:
				var skm = g._mesh(g._sphere(0.28), bone2, Vector3(pp2.x, gy + 0.22, pp2.y), root)
				skm.scale = Vector3(1.0, 1.1, 1.0)
				var rib2 = g._mesh(g.M.box(0.9, 0.08, 0.1), bone2, Vector3(pp2.x + 0.2, gy + 0.06, pp2.y + 0.2), root)
				rib2.rotation.y = rng.randf() * TAU
			1:
				if g._prop("wooden_barrels_01", pp2, 1.6, rng.randf() * TAU, root) == null:
					var br = g._mesh(g._cyl(0.4, 0.9), wood, Vector3(pp2.x, gy + 0.45, pp2.y), root)
					br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_:
				if g._prop("wooden_crate_01" if k % 2 == 0 else "wooden_crate_02", pp2, 0.95, rng.randf() * TAU, root) == null:
					var cr = g._mesh(g.M.box(0.9, 0.8, 0.9), wood, Vector3(pp2.x, gy + 0.4, pp2.y), root)
					cr.rotation.y = rng.randf() * TAU


## 0 = outside, 1 = deep inside the tunnel.
func tunnel_depth(p: Vector2) -> float:
	if tunnel_pts.size() < 2:
		return 0.0
	var best := 1e9
	for i in tunnel_pts.size() - 1:
		var a := tunnel_pts[i]
		var b := tunnel_pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return clampf(1.0 - (best - (tunnel_w - 1.0)) / 4.0, 0.0, 1.0)


# --------------------------------------------------------------------- maze

## Builds the labyrinth in small steps over many frames (the quest begins far away, so nobody sees it happen): flatten the ground, then the walls,
## then chests and torches. `maze` is only filled in when everything is finished.
func build_maze(center: Vector2, travel: Vector2) -> void:
	var n := 15
	var cell := 6.0
	var size := n * cell
	g._flatten_async(center, size * 0.5 + 4.0, 12.0)
	while g._flatten_busy:
		await g.get_tree().process_frame
	await _build_maze_body(center, travel)


func _build_maze_body(center: Vector2, travel: Vector2) -> void:
	var n := 15
	var cell := 6.0
	var size := n * cell
	var origin := center - Vector2(size, size) * 0.5
	if g.get("forest") != null:
		g.forest.add_disc(center, 84.0)  # no trees growing inside the labyrinth
	var base = g._h(center)
	var root := Node3D.new()
	g.add_child(root)
	var grp := _new_group(center, 70.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2727
	# vw[i][j]: wall on vertical line i (0..n) beside row j; hw[i][j]: wall on horizontal line j beside column i
	var vw: Array = []
	var hw: Array = []
	for i in n + 1:
		vw.append([])
		hw.append([])
		for j in n + 1:
			vw[i].append(true)
			hw[i].append(true)
	# recursive-backtracker carve
	var seen: Array = []
	for i in n:
		seen.append([])
		for j in n:
			seen[i].append(false)
	var stack: Array = [Vector2i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1))]
	seen[stack[0].x][stack[0].y] = true
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var opts: Array = []
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + dd
			if nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and not seen[nb.x][nb.y]:
				opts.append(dd)
		if opts.is_empty():
			stack.pop_back()
			continue
		var dd2: Vector2i = opts[rng.randi() % opts.size()]
		var nb2: Vector2i = cur + dd2
		if dd2.x == 1:
			vw[cur.x + 1][cur.y] = false
		elif dd2.x == -1:
			vw[cur.x][cur.y] = false
		elif dd2.y == 1:
			hw[cur.x][cur.y + 1] = false
		else:
			hw[cur.x][cur.y] = false
		seen[nb2.x][nb2.y] = true
		stack.append(nb2)
	# entrance on the side the player arrives from, exit on the opposite side (middle cells)
	var mid := n / 2
	var entrance_cell := Vector2i(mid, 0)
	var exit_cell := Vector2i(mid, n - 1)
	if absf(travel.x) > absf(travel.y):
		if travel.x > 0.0:
			vw[0][mid] = false
			vw[n][mid] = false
			entrance_cell = Vector2i(0, mid)
			exit_cell = Vector2i(n - 1, mid)
		else:
			vw[n][mid] = false
			vw[0][mid] = false
			entrance_cell = Vector2i(n - 1, mid)
			exit_cell = Vector2i(0, mid)
	else:
		if travel.y > 0.0:
			hw[mid][0] = false
			hw[mid][n] = false
			entrance_cell = Vector2i(mid, 0)
			exit_cell = Vector2i(mid, n - 1)
		else:
			hw[mid][n] = false
			hw[mid][0] = false
			entrance_cell = Vector2i(mid, n - 1)
			exit_cell = Vector2i(mid, 0)

	var st := _batch()
	var wh := 7.5
	for i in n + 1:
		for j in n:
			if vw[i][j]:
				var a := origin + Vector2(i * cell, j * cell)
				var b := origin + Vector2(i * cell, (j + 1) * cell)
				_box(st, Vector3(a.x, base + wh * 0.5 - 0.3, (a.y + b.y) * 0.5), Vector3(1.4, wh, cell + 1.4), 0.0)
				_add_wall_seg(grp, a, b, 1.4)
	for j in n + 1:
		for i in n:
			if hw[i][j]:
				var a2 := origin + Vector2(i * cell, j * cell)
				var b2 := origin + Vector2((i + 1) * cell, j * cell)
				_box(st, Vector3((a2.x + b2.x) * 0.5, base + wh * 0.5 - 0.3, a2.y), Vector3(cell + 1.4, wh, 1.4), 0.0)
				_add_wall_seg(grp, a2, b2, 1.4)
	if _wall_mat == null:
		_wall_mat = (g.rock_mat as StandardMaterial3D).duplicate()
		_wall_mat.normal_enabled = false
		_wall_mat.uv1_scale = Vector3.ONE * 0.1
		_wall_mat.albedo_color = Color(0.6, 0.6, 0.62)
	_finish(st, _wall_mat, root)
	await g.get_tree().process_frame
	# entrance / exit torches
	for cc in [entrance_cell, exit_cell]:
		var cpos := origin + Vector2((cc.x + 0.5) * cell, (cc.y + 0.5) * cell)
		_torch(root, Vector3(cpos.x, g._h(cpos), cpos.y), Color("ffd070"))

	# BFS depth from the entrance, then pick dead ends for the treasure
	var open_to := func(c: Vector2i, d: Vector2i) -> bool:
		if d.x == 1: return not vw[c.x + 1][c.y]
		if d.x == -1: return not vw[c.x][c.y]
		if d.y == 1: return not hw[c.x][c.y + 1]
		return not hw[c.x][c.y]
	var depth := {}
	depth[entrance_cell] = 0
	var q: Array = [entrance_cell]
	var qi := 0
	while qi < q.size():
		var cur2: Vector2i = q[qi]
		qi += 1
		for dd3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb3: Vector2i = cur2 + dd3
			if nb3.x < 0 or nb3.y < 0 or nb3.x >= n or nb3.y >= n or depth.has(nb3):
				continue
			if open_to.call(cur2, dd3):
				depth[nb3] = depth[cur2] + 1
				q.append(nb3)
	var dead: Array = []
	for i in n:
		for j in n:
			var c := Vector2i(i, j)
			if c == entrance_cell or c == exit_cell:
				continue
			var openings := 0
			for dd4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if open_to.call(c, dd4):
					openings += 1
			if openings == 1 and depth.has(c):
				dead.append(c)
	dead.sort_custom(func(a, b): return depth[a] > depth[b])
	var cpos_of := func(c: Vector2i) -> Vector2:
		return origin + Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)
	var chests: Array = []
	var kinds := ["gun", "ammo", "souls", "ammo", "potion", "ammo", "souls"]
	var chosen: Array = []
	for c in dead:
		var ok := true
		for o in chosen:
			if Vector2(c - o).length() < 4.0:
				ok = false
		if ok:
			chosen.append(c)
		if chosen.size() >= kinds.size():
			break
	for k in chosen.size():
		var cp: Vector2 = cpos_of.call(chosen[k])
		chests.append(_make_chest(root, cp, kinds[k]))
		await g.get_tree().process_frame
	# the civilians hide in the other dead ends, well spread out
	var civ_cells: Array = []
	var pool := dead.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	# every cell, deepest first, as a last resort when there are too few dead ends
	var all_cells: Array = depth.keys()
	all_cells.sort_custom(func(a, b): return depth[a] > depth[b])
	for pass_i in 3:
		var source: Array = pool if pass_i < 2 else all_cells
		var min_depth := 6 if pass_i == 0 else 3
		var gap := 4.0 if pass_i == 0 else 3.2
		for c in source:
			if civ_cells.size() >= 6:
				break
			if chosen.has(c) or c == entrance_cell or c == exit_cell or depth[c] < min_depth:
				continue
			var far := true
			for o in civ_cells + chosen:
				if Vector2(c - o).length() < gap:
					far = false
			if far:
				civ_cells.append(c)
	var civ_spots: Array = civ_cells.map(func(c): return cpos_of.call(c))
	# sconces along the walls (flames only, no extra lights)
	var tr := RandomNumberGenerator.new()
	tr.seed = 99
	for k in 14:
		var tc := Vector2i(tr.randi_range(0, n - 1), tr.randi_range(0, n - 1))
		var tp: Vector2 = cpos_of.call(tc) + Vector2(tr.randf_range(-1.8, 1.8), tr.randf_range(-1.8, 1.8))
		_torch(root, Vector3(tp.x, g._h(tp), tp.y), Color("ff9a40"))
		if k % 3 == 2:
			await g.get_tree().process_frame
	maze = {"center": center, "origin": origin, "cell": cell, "n": n, "entrance": cpos_of.call(entrance_cell), "exit": cpos_of.call(exit_cell),
		"chests": chests, "dead": dead.map(func(c): return cpos_of.call(c)), "root": root, "grp": grp, "civ_spots": civ_spots, "size": size}
	g.emblems.maze_built(maze)


func _make_chest(parent: Node3D, pos: Vector2, kind: String) -> Dictionary:
	var node := Node3D.new()
	parent.add_child(node)
	node.global_position = Vector3(pos.x, g._h(pos), pos.y)
	var lid := Node3D.new()
	var model: Node3D = g._prop("treasure_chest", pos, 1.5, 0.0, node)
	var lid_mesh: Node3D = model.find_child("treasure_chest_lid", true, false) if model != null else null
	if lid_mesh != null:
		# real chest: hinge the lid along its back edge so it can swing open
		var lb: AABB = (lid_mesh as MeshInstance3D).global_transform * (lid_mesh as MeshInstance3D).get_aabb()
		node.add_child(lid)
		lid.global_position = Vector3(lb.position.x + lb.size.x * 0.5, lb.position.y, lb.position.z + lb.size.z)
		lid_mesh.reparent(lid, true)
	else:
		var wood = g._mat(Color("4a2c18"), 0.8)
		var gold = g._mat(Color("d8b050"), 0.3, 1.0)
		g._mesh(g.M.box(1.3, 0.7, 0.85), wood, Vector3(0, 0.35, 0), node)
		g._mesh(g.M.box(1.34, 0.1, 0.9), gold, Vector3(0, 0.1, 0), node)
		lid.position = Vector3(0, 0.7, 0.42)
		node.add_child(lid)
		g._mesh(g.M.box(1.3, 0.28, 0.85), wood, Vector3(0, 0.14, -0.42), lid)
		g._mesh(g.M.box(1.34, 0.1, 0.9), gold, Vector3(0, 0.2, -0.42), lid)
		g._mesh(g._sphere(0.2), gold, Vector3(0, 0.55, -0.45), node)
	var beam_col := Color(1.0, 0.85, 0.4, 0.18) if kind == "gun" else Color(0.7, 0.85, 1.0, 0.12)
	var bm = g._unshaded(beam_col)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g._mesh(g._cyl(0.35 if kind == "gun" else 0.22, 22.0), bm, Vector3(0, 11.0, 0), node)
	return {"pos": pos, "kind": kind, "opened": false, "node": node, "lid": lid, "t": -1.0}


func chest_near(p: Vector2, reach: float) -> int:
	var ch: Array = maze.get("chests", [])
	for i in ch.size():
		if not ch[i].opened and p.distance_to(ch[i].pos) < reach:
			return i
	return -1


func open_chest(i: int) -> Dictionary:
	var c: Dictionary = maze.chests[i]
	c.opened = true
	c.t = 0.0
	return c


func update_chests(dt: float) -> void:
	var ch: Array = maze.get("chests", [])
	for c in ch:
		if c.t >= 0.0:
			c.t += dt
			c.lid.rotation.x = clampf(c.t / 0.7, 0.0, 1.0) * 1.3


## How far inside the labyrinth's square a point is (negative outside).
func maze_margin(p: Vector2) -> float:
	if maze.is_empty():
		return -99.0
	var o: Vector2 = maze.origin
	var sz: float = float(maze.n) * float(maze.cell)
	return minf(minf(p.x - o.x, o.x + sz - p.x), minf(p.y - o.y, o.y + sz - p.y))


func in_maze(p: Vector2) -> bool:
	if maze.is_empty():
		return false
	var o: Vector2 = maze.origin
	var s: float = float(maze.n) * float(maze.cell)
	return p.x > o.x and p.y > o.y and p.x < o.x + s and p.y < o.y + s


func maze_spawn_points(count: int, avoid: Vector2, keep_clear: Array = []) -> Array:
	var out: Array = []
	var pool: Array = maze.get("dead", []).duplicate()
	pool.shuffle()
	for p in pool:
		if p.distance_to(avoid) > 14.0:
			var spread := true
			for kc in keep_clear:
				if p.distance_to(kc) < 11.0:
					spread = false
			for o in out:
				if p.distance_to(o) < 8.0:
					spread = false
			if spread:
				out.append(p)
		if out.size() >= count:
			break
	return out


# ------------------------------------------------------------------- bridge

## A long stone bridge over a chasm carved into the canyon. The Cyborg Titan rises beyond its far end.
func build_bridge(center: Vector2, d: Vector2) -> void:
	var half_len := 22.0
	var half_w := 4.3
	var n := Vector2(-d.y, d.x)
	var base = g._h(center)
	var terr = g.terrain.data
	# carve: a deep rectangular chasm under the span, level approach ground at both ends, original terrain beyond
	var R := 64
	for xi in range(int(center.x - R), int(center.x + R) + 1):
		for zi in range(int(center.y - R), int(center.y + R) + 1):
			var p := Vector2(xi, zi)
			var rel := p - center
			if rel.length() > R:
				continue
			var lon := rel.dot(d)
			var lat := rel.dot(n)
			var v := Vector3(xi, 0, zi)
			var h0: float = terr.get_height(v)
			if is_nan(h0):
				continue
			# ground: level with the deck near the approaches, easing back to the real terrain further out
			var level: float = base
			if absf(lat) > 9.0 or absf(lon) > half_len + 6.0:
				level = lerpf(base, h0, smoothstep(half_len + 4.0, half_len + 22.0, maxf(absf(lon), absf(lat) * 1.6)))
			# the chasm: sheer ends (1 m) and sloping sides
			var along: float = 1.0 - smoothstep(half_len - 1.2, half_len - 0.2, absf(lon))
			var across := 1.0 - smoothstep(16.0, 26.0, absf(lat))
			var chasm := along * across
			var target := lerpf(level, base - 38.0, chasm)
			var w := smoothstep(R - 14.0, R - 1.0, rel.length())
			target = lerpf(target, h0, w)
			terr.set_height(v, target)
	terr.update_maps(0)
	var root := Node3D.new()
	g.add_child(root)
	var st := _batch()
	var yaw := _yaw_of(d)
	_box(st, Vector3(center.x, base - 0.45, center.y), Vector3(half_len * 2.0 + 1.0, 0.9, half_w * 2.0), yaw)
	# parapets
	for side in [-1.0, 1.0]:
		var pc: Vector2 = center + n * (half_w - 0.2) * side
		_box(st, Vector3(pc.x, base + 0.45, pc.y), Vector3(half_len * 2.0 + 2.0, 0.9, 0.5), yaw)
		for k in range(-5, 6):
			var pp: Vector2 = center + d * (k * 4.0) + n * (half_w - 0.2) * side
			_box(st, Vector3(pp.x, base + 1.1, pp.y), Vector3(0.7, 2.2, 0.7), yaw)
	# piers going down into the dark chasm
	for k in range(-2, 3):
		var pp2: Vector2 = center + d * (k * 10.0)
		_box(st, Vector3(pp2.x, base - 20.0, pp2.y), Vector3(2.4, 38.0, half_w * 1.4), yaw)
		_box(st, Vector3(pp2.x, base - 1.3, pp2.y), Vector3(3.2, 1.0, half_w * 2.0), yaw)
	_finish(st, g.rock_mat, root)
	for k in [-4, 0, 4]:
		for side in [-1.0, 1.0]:
			var tp: Vector2 = center + d * (k * 4.5) + n * (half_w - 0.2) * side
			_torch(root, Vector3(tp.x, base + 2.2, tp.y) + Vector3(0, -0.8, 0), Color("ff6a30"))
	# a dark mist plane far below so the chasm reads as a drop
	var mist = g._unshaded(Color(0.02, 0.03, 0.06, 0.55))
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g._mesh(g._cyl(34.0, 0.2), mist, Vector3(center.x, base - 30.0, center.y), root)
	bridge = {"center": center, "d": d, "n": n, "half_len": half_len, "half_w": half_w, "base": base,
		"boss_pos": center + d * (half_len + 10.0), "root": root}


## True when `p` is over the bridge deck (the ground there is the deck, not the chasm floor).
func on_bridge(p: Vector2) -> bool:
	if bridge.is_empty():
		return false
	var rel: Vector2 = p - bridge.center
	return absf(rel.dot(bridge.d)) < float(bridge.half_len) + 0.4 and absf(rel.dot(bridge.n)) < float(bridge.half_w) + 0.3


## Keeps a position on the bridge deck while the Titan fight is on.
func bridge_clamp(p: Vector2) -> Vector2:
	if bridge.is_empty():
		return p
	var rel: Vector2 = p - bridge.center
	var lon := rel.dot(bridge.d)
	var lat := rel.dot(bridge.n)
	lon = clampf(lon, -float(bridge.half_len) - 6.0, float(bridge.half_len) - 0.5)
	lat = clampf(lat, -float(bridge.half_w) + 0.8, float(bridge.half_w) - 0.8)
	return bridge.center + bridge.d * lon + bridge.n * lat
