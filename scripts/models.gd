extends RefCounted
## Procedural character models: player (weapons + armour sets), enemies, monsters, bosses, princess.
## Everything (meshes + textures) is generated in code.

const A := "res://demo/assets/"
const KENNEY := "res://assets/models/kenney_graveyard-kit/Models/GLB format/"

## Downloaded (CC0) models that replace the procedural body of a kind. "h" = height in the figure's local units.
## The weapon / shield / slash arc stay procedural and keep following the code-driven arm rig.
# Kenney's cartoon characters are switched off (too cartoony); re-add an entry here to use one again:
#   "skeleton": {"glb": "character-skeleton.glb", "h": 1.75}, "zombie": ..., "player": {"glb": "character-keeper.glb", "h": 1.8}
const ASSETS := {}
const LOOPED := ["idle", "walk", "sprint"]
const PH := "res://assets/models/polyhaven/"
const HEAVY_SWORD := "res://assets/models/oga_heavy_greatsword/Heavy Sword.fbx"

var arc_mat: StandardMaterial3D
var _mcache := {}
var _meshes: Array = []
var _loft_cache := {}
var cast_shadows := false

# Per-kind look. colour lists are dark -> light (2-4 stops).
const CFG := {
	"hollow": {"scale": 1.0, "build": 1.0, "tex": "rag", "skin": ["56604f", "8a9684"], "cloth": ["2a2420", "4a4036"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3a2a", "7a5a3a"], "armor": "none", "helm": "none", "weapon": "sword", "eye": "ff7a2a", "hunch": 0.3, "bare": true},
	"zombie": {"scale": 1.0, "build": 1.05, "tex": "rot", "skin": ["33422e", "5a6a48", "7a7a58", "4a3646"], "cloth": ["2a2a22", "4a4a38"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3a2a", "7a5a3a"], "armor": "none", "helm": "none", "weapon": "none", "eye": "d0ff60", "hunch": 0.4, "bare": true, "pose": "zombie", "jaw": true},
	"ghoul": {"scale": 1.05, "build": 0.85, "tex": "rot", "skin": ["6a7080", "aab0be", "7a7c90"], "cloth": ["2a2830", "4a4858"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3a2a", "7a5a3a"], "armor": "none", "helm": "none", "weapon": "claws", "eye": "ff4a4a", "hunch": 0.55, "bare": true, "pose": "ghoul", "longarms": true, "jaw": true, "bald": true},
	"skeleton": {"scale": 1.05, "build": 0.78, "tex": "bone", "skin": ["8a8468", "d8d2b4", "efe9d0"], "cloth": ["2e2820", "4e4234"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["5a5040", "9a8a6a"], "armor": "light", "helm": "skull", "weapon": "sword", "eye": "7affc8", "hunch": 0.12, "bare": true, "shield": true},
	"archer": {"scale": 1.0, "build": 0.92, "tex": "rag", "skin": ["6a5a4a", "9a8068"], "cloth": ["2a382a", "485c40"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3420", "7a5a38"], "armor": "light", "helm": "hood", "weapon": "bow", "eye": "ffd27a", "hunch": 0.1},
	"mage": {"scale": 1.0, "build": 0.92, "tex": "rag", "skin": ["6a5a4a", "9a8068"], "cloth": ["241640", "563a86"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "robe", "helm": "hood", "weapon": "staff", "eye": "c070ff", "hunch": 0.05, "robe": true},
	"imp": {"scale": 0.85, "build": 0.8, "tex": "demon", "skin": ["3a0c06", "8a1c10", "d04a20", "ffb050"], "cloth": ["2a1410", "4a2a20"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "none", "helm": "horned_small", "weapon": "claws", "eye": "ffd030", "hunch": 0.18, "bare": true, "wings": true, "tail": true, "glow": true},
	"fiend": {"scale": 1.4, "build": 1.25, "tex": "demon", "skin": ["2a0805", "7a1a0c", "c8381a", "ffa040"], "cloth": ["2a1410", "4a2a20"], "metal": ["2a2a30", "5a4a4a"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "none", "helm": "horned", "weapon": "claws", "eye": "ffb030", "hunch": 0.25, "bare": true, "wings": true, "tail": true, "glow": true},
	"knight": {"scale": 1.18, "build": 1.15, "tex": "rag", "skin": ["6a5a4a", "9a8068"], "cloth": ["3a0c0c", "6a1818"], "metal": ["222838", "586784"],
		"wcol": ["6a707c", "b0b6c4"], "armor": "plate", "helm": "great", "weapon": "sword", "eye": "ff3a2a", "hunch": 0.0, "shield": true},
	"stonesoldier": {"scale": 1.12, "build": 1.15, "tex": "stone", "skin": ["54544f", "8a8a82", "6a7a5a"], "cloth": ["54544f", "8a8a82"], "metal": ["4a4a46", "7a7a72", "5a6a52"],
		"wcol": ["6a6a64", "9a9a90"], "armor": "plate", "helm": "great", "weapon": "spear", "eye": "7aff9a", "hunch": 0.0},
	"brute": {"scale": 1.5, "build": 1.5, "tex": "rag", "skin": ["6a4a3a", "9a6a52"], "cloth": ["2a2018", "4a3828"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "light", "helm": "none", "weapon": "hammer", "eye": "ff5a2a", "hunch": 0.22, "bare": true, "bald": true},
	"captain": {"scale": 1.32, "build": 1.2, "tex": "rag", "skin": ["6a5a4a", "9a8068"], "cloth": ["5a0808", "a01a1a"], "metal": ["301818", "7a3a3a"],
		"wcol": ["6a707c", "c0c6d4"], "armor": "plate", "helm": "great", "weapon": "greatsword", "eye": "ff2020", "hunch": 0.0, "cape": true, "shield": true},
	# ---- bosses ----
	"demon": {"scale": 2.4, "build": 1.6, "tex": "demon", "skin": ["3a0c06", "8a1c10", "d85a22", "ffb050"], "cloth": ["2a1410", "4a2a20"], "metal": ["2a2a30", "5a4a4a"],
		"wcol": ["3a3a3e", "7a7a84"], "armor": "none", "helm": "horned", "weapon": "cleaver", "eye": "ffaa22", "hunch": 0.2, "bare": true, "wings": true, "tail": true, "glow": true},
	"cyborg": {"scale": 5.2, "build": 1.5, "tex": "cyber", "skin": ["2a3038", "5a6672", "7a8896"], "cloth": ["1a2028", "3a4450"], "metal": ["2a3038", "6a7a8a", "9aaaba", "30e0ff"],
		"trim": ["0a5a7a", "30e0ff"], "wcol": ["3a4048", "8a9aaa"], "armor": "plate", "helm": "great", "weapon": "none", "eye": "30e0ff", "hunch": 0.0, "half": true, "cyber": true},
	"malakar": {"scale": 2.15, "build": 1.3, "tex": "rag", "skin": ["6a5a4a", "9a8068"], "cloth": ["14080a", "3a1418"], "metal": ["0c0c12", "2c2c3a"],
		"wcol": ["1a1a22", "5a2a2a"], "trim": ["5a1010", "a02020"], "armor": "plate", "helm": "horned", "weapon": "greatsword", "eye": "ff2020", "hunch": 0.0, "cape": true},
	"bonelord": {"scale": 1.9, "build": 0.95, "tex": "bone", "skin": ["8a8468", "d8d2b4"], "cloth": ["2a2a1c", "4e4e36"], "metal": ["3a4038", "7a8a78"],
		"wcol": ["3a4038", "8a9a88"], "armor": "plate", "helm": "crown", "weapon": "greatsword", "eye": "4affc0", "hunch": 0.05, "cape": true, "skull": true},
	"queen": {"scale": 1.28, "build": 0.86, "tex": "rag", "skin": ["8a6a58", "c8a08a"], "cloth": ["14223e", "4a7ab0"], "metal": ["3a3e48", "9aa8c0"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "robe", "helm": "crown", "weapon": "staff", "eye": "6ab4ff", "hunch": 0.0, "robe": true, "hair": "d8dce8", "cape": true},
	"villager_m": {"scale": 0.97, "build": 0.9, "tex": "rag", "skin": ["8a6a54", "c8a088"], "cloth": ["3a2e22", "7a6a50"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3a2a", "7a5a3a"], "armor": "none", "helm": "none", "weapon": "none", "eye": "ffe8c0", "hunch": 0.1},
	"villager_f": {"scale": 0.97, "build": 0.9, "tex": "rag", "skin": ["8a6a54", "c8a088"], "cloth": ["3a2e22", "7a6a50"], "metal": ["3a3e48", "6a707c"],
		"wcol": ["4a3a2a", "7a5a3a"], "armor": "none", "helm": "none", "weapon": "none", "eye": "ffe8c0", "hunch": 0.1},
	"princess": {"scale": 0.96, "build": 0.84, "tex": "rag", "skin": ["9a7058", "d8aa92"], "cloth": ["b8c4e8", "f4f6ff"], "metal": ["8a7a4a", "d8b860"],
		"wcol": ["3a2a1a", "6a4a2a"], "armor": "robe", "helm": "tiara", "weapon": "none", "eye": "3a2a20", "hunch": 0.0, "robe": true, "hair": "4a2c1a"},
}


# ------------------------------------------------------------ primitives

func mat(col: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func grad_tex(freq: float, colors: Array, seed_v: int, normal: bool = false, bump: float = 2.0, ntype: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, octaves: int = 3) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = ntype
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_v
	var tx := NoiseTexture2D.new()
	tx.noise = n
	tx.width = 128
	tx.height = 128
	tx.seamless = true
	if normal:
		tx.as_normal_map = true
		tx.bump_strength = bump
	else:
		var g := Gradient.new()
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for i in colors.size():
			offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
			cols.append(Color(colors[i]))
		g.offsets = offs
		g.colors = cols
		tx.color_ramp = g
	return tx


## Textured PBR material from 2+ colour stops (albedo + normal map, triplanar).
func grad_mat(colors: Array, freq: float, metal: float, rough: float, uv: float, seed_v: int, bump: float = 2.0, ntype: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = grad_tex(freq, colors, seed_v, false, 2.0, ntype)
	m.normal_enabled = true
	m.normal_texture = grad_tex(freq * 1.8, colors, seed_v + 7, true, bump, ntype)
	m.metallic = metal
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	return m


## Glowing cracks / veins: bright thin lines on black (used as an emission map).
## Gives a material a faint, even glow (emission *textures* are not used: they sample as white on the
## Compatibility renderer). The "veins" come from bright stops in the albedo gradient instead.
func crack_glow(m: StandardMaterial3D, col: Color, _freq: float, _seed_v: int, energy: float) -> void:
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy * 0.16


func tex_mat(c0: Color, c1: Color, freq: float, metal: float, rough: float, uv: float, seed_v: int, bump: float = 2.0) -> StandardMaterial3D:
	return grad_mat([c0, c1], freq, metal, rough, uv, seed_v, bump)


func part(mesh: Mesh, material: Material, pos: Vector3, parent: Node, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func dome(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = 14
	s.rings = 5
	return s


func caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 12
	c.rings = 3
	return c


func box(x: float, y: float, z: float) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(x, y, z)
	return bm


func cone(top: float, bottom: float, h: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 8
	return t


## Smooth lofted solid. rings: [y, rx, rz, cx, cz] cross-sections (ascending y). Has UVs (3 wraps x 2 along).
func loft(rings: Array, seg: int = 14, caps_on: bool = true) -> ArrayMesh:
	var key := str([rings, seg, caps_on])
	if _loft_cache.has(key):
		return _loft_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var n := rings.size()
	var cols := seg + 1  # duplicate seam column so UVs wrap cleanly
	for ri in n:
		var r: Array = rings[ri]
		var cx: float = r[3] if r.size() > 3 else 0.0
		var cz: float = r[4] if r.size() > 4 else 0.0
		for j in cols:
			var a := float(j) / seg * TAU
			st.set_uv(Vector2(float(j) / seg * 3.0, float(ri) / maxf(n - 1, 1) * 2.0))
			st.add_vertex(Vector3(cx + r[1] * cos(a), r[0], cz + r[2] * sin(a)))
	for i in n - 1:
		for j in seg:
			var a0 := i * cols + j
			var a1 := i * cols + j + 1
			var b0 := (i + 1) * cols + j
			var b1 := (i + 1) * cols + j + 1
			st.add_index(b0)
			st.add_index(a0)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(b1)
	if caps_on:
		var lo: Array = rings[0]
		var hi: Array = rings[n - 1]
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(Vector3(lo[3] if lo.size() > 3 else 0.0, lo[0], lo[4] if lo.size() > 4 else 0.0))
		st.set_uv(Vector2(0.5, 2.0))
		st.add_vertex(Vector3(hi[3] if hi.size() > 3 else 0.0, hi[0], hi[4] if hi.size() > 4 else 0.0))
		var cb := n * cols
		var ct := n * cols + 1
		for j in seg:
			st.add_index(cb)
			st.add_index(j + 1)
			st.add_index(j)
			st.add_index(ct)
			st.add_index((n - 1) * cols + j)
			st.add_index((n - 1) * cols + j + 1)
	st.generate_normals()
	var out := st.commit()
	_loft_cache[key] = out
	return out


## Scale every ring's radii (for build/width variation).
func bl(rings: Array, b: float) -> Array:
	var out: Array = []
	for r in rings:
		var rr: Array = r.duplicate()
		rr[1] = r[1] * b
		rr[2] = r[2] * b
		out.append(rr)
	return out


func cape_mesh(wide: float = 1.0, length: float = 1.05) -> ArrayMesh:
	var key := "cape%s%s" % [wide, length]
	if _loft_cache.has(key):
		return _loft_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var cols := 8
	var rows := 12
	for r in rows + 1:
		var v := float(r) / rows
		for c in cols + 1:
			var u := float(c) / cols * 2.0 - 1.0
			var x := u * lerpf(0.2, 0.34, v) * wide
			var z := 0.02 + 0.1 * v + 0.03 * (1.0 - u * u) + sin(v * 9.0 + u * 3.0) * 0.012 * v
			st.add_vertex(Vector3(x, -v * length, z))
	for r in rows:
		for c in cols:
			var i0 := r * (cols + 1) + c
			var i1 := i0 + 1
			var i2 := i0 + cols + 1
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	st.generate_normals()
	var out := st.commit()
	_loft_cache[key] = out
	return out


## Bat-wing membrane in the XY plane (x outward).
func wing_mesh(span: float, height: float) -> ArrayMesh:
	var key := "wing%s%s" % [span, height]
	if _loft_cache.has(key):
		return _loft_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = [Vector3(0, 0, 0), Vector3(span * 0.3, height * 0.95, 0), Vector3(span * 0.62, height * 0.75, 0.02),
		Vector3(span, height * 0.2, 0.0), Vector3(span * 0.74, -height * 0.25, 0.01), Vector3(span * 0.4, -height * 0.5, 0.0),
		Vector3(0.05, -height * 0.3, 0)]
	for i in pts.size() - 1:
		st.add_vertex(pts[0])
		st.add_vertex(pts[i])
		st.add_vertex(pts[i + 1])
	var out := st.commit()
	_loft_cache[key] = out
	return out


func arc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var r0 := 1.2
	var r1 := 3.9
	var ci := Color(0.8, 0.9, 1.0, 0.0)
	var co := Color(0.9, 0.95, 1.0, 0.75)
	for i in n:
		var a0 := lerpf(-1.15, 1.15, float(i) / n)
		var a1 := lerpf(-1.15, 1.15, float(i + 1) / n)
		var p0i := Vector3(sin(a0) * r0, 0, -cos(a0) * r0)
		var p0o := Vector3(sin(a0) * r1, 0, -cos(a0) * r1)
		var p1i := Vector3(sin(a1) * r0, 0, -cos(a1) * r0)
		var p1o := Vector3(sin(a1) * r1, 0, -cos(a1) * r1)
		for v in [[p0i, ci], [p0o, co], [p1o, co], [p0i, ci], [p1o, co], [p1i, ci]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	return st.commit()


# ------------------------------------------------------------ materials

func _mats(kind: String) -> Dictionary:
	if _mcache.has(kind):
		return _mcache[kind]
	var c: Dictionary = CFG[kind]
	var sd: int = hash(kind) % 90
	var tk: String = c.get("tex", "rag")
	var m := {}
	var skin_cols: Array = c.skin
	match tk:
		"rot":
			m.skin = grad_mat(skin_cols, 0.7, 0.0, 0.85, 0.45, sd, 3.5, FastNoiseLite.TYPE_PERLIN)
		"bone":
			m.skin = grad_mat(skin_cols, 0.55, 0.0, 0.6, 0.4, sd, 2.0)
		"demon":
			m.skin = grad_mat(skin_cols, 0.45, 0.0, 0.6, 0.45, sd, 3.0, FastNoiseLite.TYPE_CELLULAR)
			crack_glow(m.skin, Color("ff7a1a"), 1.6, sd + 9, 1.4)
		"stone":
			m.skin = grad_mat(skin_cols, 0.4, 0.0, 0.95, 0.4, sd, 4.5, FastNoiseLite.TYPE_PERLIN)
		"cyber":
			m.skin = grad_mat(skin_cols, 0.5, 0.7, 0.35, 0.8, sd, 1.2, FastNoiseLite.TYPE_CELLULAR)
			crack_glow(m.skin, Color("30e0ff"), 2.2, sd + 9, 1.8)
		_:
			m.skin = grad_mat(skin_cols, 0.5, 0.0, 0.75, 0.5, sd, 0.3)
	m.cloth = grad_mat(c.cloth, 0.9, 0.0, 0.92, 1.4, sd + 1, 1.2)
	m.cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var metal_cols: Array = c.metal
	m.metal = grad_mat(metal_cols, 0.2, 0.55 if tk != "stone" else 0.0, 0.45 if tk != "stone" else 0.9, 1.0, sd + 2, 0.5 if tk != "stone" else 4.0)
	if tk == "cyber":
		crack_glow(m.metal, Color("30e0ff"), 3.0, sd + 11, 1.6)
	var tr: Array = c.get("trim", ["6e5420", "c99f45"])
	m.trim = grad_mat(tr, 0.3, 0.65, 0.32, 1.0, sd + 3, 0.3)
	if kind == "cyborg":
		m.trim.emission_enabled = true
		m.trim.emission = Color("30e0ff")
		m.trim.emission_energy_multiplier = 2.5
	m.leather = tex_mat(Color("1f120a"), Color("40261a"), 0.35, 0.0, 0.8, 1.2, sd + 4, 0.8)
	m.weapon = grad_mat(c.wcol, 0.5, 0.6, 0.3, 1.0, sd + 5, 0.3)
	m.eye = mat(Color(c.eye), 0.4, 4.0)
	m.hair = mat(Color(c.get("hair", "1c130e")), 0.9)
	m.dark = mat(Color("0a0a0c"), 0.5)
	_mcache[kind] = m
	return m


# --------------------------------------------------------------- weapons

## Realistic CC0 weapon (Poly Haven, modelled blade-up along +Y, grip at the bottom) laid along -Z with the grip at the origin.
## Hides the procedural weapon parts already under parent. Returns false (and changes nothing) if the file is missing.
func real_weapon(id: String, parent: Node3D, length: float, grip: float = 0.12, along_x: bool = false) -> bool:
	var path := id if id.begins_with("res://") else "%s%s/%s_1k.gltf" % [PH, id, id]
	if not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if not (packed is PackedScene):
		return false
	var inst: Node3D = (packed as PackedScene).instantiate()
	var acc: Array = [null]
	_glb_aabb(inst, Transform3D.IDENTITY, acc)
	if acc[0] == null:
		inst.free()
		return false
	var bb: AABB = acc[0]
	var k: float = length / maxf(bb.size.x if along_x else bb.size.y, 0.001)
	for ch in parent.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * k
	if along_x:
		# pistol-style model: barrel along +X, grip hangs down; lay the barrel along -Z
		holder.rotation.y = PI / 2
		inst.position = Vector3(-(bb.position.x + grip / k), -(bb.position.y + bb.size.y * 0.75), -(bb.position.z + bb.size.z * 0.5))
	else:
		holder.rotation.x = -PI / 2
		inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -(bb.position.y + grip / k), -(bb.position.z + bb.size.z * 0.5))
	holder.add_child(inst)
	parent.add_child(holder)
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var wmi := n as MeshInstance3D
			wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_meshes.append(wmi)
			# fully-metallic PBR goes black without an environment map to reflect: keep it steel-like but lit
			for si in wmi.mesh.get_surface_count():
				var sm = wmi.mesh.surface_get_material(si)
				if sm is StandardMaterial3D:
					var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
					dm.metallic = minf(dm.metallic, 0.3)
					dm.roughness = clampf(dm.roughness, 0.45, 0.8)
					wmi.set_surface_override_material(si, dm)
	return true


func _weapon(wtype: String, parent: Node3D, m: Dictionary) -> void:
	match wtype:
		"sword":
			if real_weapon("antique_estoc", parent, 1.3):
				return
		"greatsword":
			if real_weapon(HEAVY_SWORD, parent, 2.0, 0.2):
				return
		"hammer":
			if real_weapon("ornate_war_hammer", parent, 1.7, 0.2):
				return
		"club":
			if real_weapon("ornate_medieval_mace", parent, 1.0, 0.15):
				return
	match wtype:
		"sword":
			part(cone(0.017, 0.017, 0.22), m.leather, Vector3(0, 0, -0.02), parent, Vector3(PI / 2, 0, 0))
			part(box(0.22, 0.025, 0.035), m.trim, Vector3(0, 0, -0.14), parent)
			part(box(0.055, 0.012, 0.9), m.weapon, Vector3(0, 0, -0.61), parent)
			var tip := PrismMesh.new()
			tip.size = Vector3(0.055, 0.12, 0.012)
			part(tip, m.weapon, Vector3(0, 0, -1.12), parent, Vector3(-PI / 2, 0, 0))
		"greatsword":
			part(cone(0.02, 0.02, 0.34), m.leather, Vector3(0, 0, 0.0), parent, Vector3(PI / 2, 0, 0))
			part(box(0.34, 0.03, 0.04), m.trim, Vector3(0, 0, -0.18), parent)
			part(box(0.1, 0.015, 1.45), m.weapon, Vector3(0, 0, -0.93), parent)
			var tip2 := PrismMesh.new()
			tip2.size = Vector3(0.1, 0.2, 0.015)
			part(tip2, m.weapon, Vector3(0, 0, -1.76), parent, Vector3(-PI / 2, 0, 0))
		"spear":
			part(cone(0.025, 0.028, 2.3), m.leather, Vector3(0, 0, -0.5), parent, Vector3(PI / 2, 0, 0))
			var head := PrismMesh.new()
			head.size = Vector3(0.14, 0.5, 0.03)
			part(head, m.weapon, Vector3(0, 0, -1.85), parent, Vector3(-PI / 2, 0, 0))
			part(box(0.2, 0.03, 0.06), m.trim, Vector3(0, 0, -1.6), parent)
		"club":
			part(cone(0.1, 0.035, 0.95), m.weapon, Vector3(0, 0, -0.45), parent, Vector3(PI / 2, 0, 0))
		"hammer":
			part(cone(0.03, 0.03, 1.5), m.leather, Vector3(0, 0, -0.5), parent, Vector3(PI / 2, 0, 0))
			part(box(0.3, 0.3, 0.5), m.weapon, Vector3(0, 0, -1.3), parent)
			part(box(0.34, 0.34, 0.1), m.metal, Vector3(0, 0, -1.04), parent)
		"cleaver":
			part(cone(0.03, 0.03, 0.4), m.leather, Vector3(0, 0, 0.0), parent, Vector3(PI / 2, 0, 0))
			part(box(0.3, 0.04, 1.25), m.weapon, Vector3(0, 0, -0.85), parent)
			part(box(0.1, 0.06, 0.1), m.metal, Vector3(0, 0, -0.25), parent)
		"staff":
			part(cone(0.022, 0.026, 1.9), m.weapon, Vector3(0, 0, -0.45), parent, Vector3(PI / 2, 0, 0))
			part(sphere(0.085), m.eye, Vector3(0, 0, -1.45), parent)
			part(ring(0.09, 0.12), m.trim, Vector3(0, 0, -1.4), parent, Vector3(PI / 2, 0, 0))


func _bow(parent: Node3D, m: Dictionary) -> void:
	var n := 7
	for i in n:
		var a := lerpf(-1.0, 1.0, float(i) / (n - 1))
		var py := sin(a) * 0.55
		var pz := -cos(a) * 0.16 + 0.16
		part(box(0.03, 0.2, 0.03), m.weapon, Vector3(0, py, -pz), parent, Vector3(a * 0.9, 0, 0))
	part(box(0.006, 1.1, 0.006), m.leather, Vector3(0, 0, 0.0), parent)


# --------------------------------------------------------------- humanoid

func humanoid(kind: String) -> Dictionary:
	if kind == "princess":
		return princess()
	var c: Dictionary = CFG[kind]
	var b: float = c.build
	var m := _mats(kind)
	_meshes = []
	var armor: String = c.armor
	var helm: String = c.helm
	var robe: bool = c.get("robe", false)
	var bare: bool = c.get("bare", false)
	var half: bool = c.get("half", false)

	var root := Node3D.new()
	root.scale = Vector3.ONE * float(c.scale)
	var blob_mat := unshaded(Color(0, 0, 0, 0.5))
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not half:
		part(cone(0.7, 0.7, 0.02), blob_mat, Vector3(0, 0.07, 0), root)

	# ---- legs ----
	var leg_mat: Material = m.metal if armor == "plate" else (m.skin if (bare and armor == "none") else m.cloth)
	var hips: Array = []
	var knees: Array = []
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.1 * b, 0.92, 0)
		root.add_child(hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.43, 0)
		hip.add_child(knee)
		if not half:
			part(loft(bl([[-0.43, 0.05, 0.052], [-0.30, 0.064, 0.068], [-0.14, 0.082, 0.086], [0.0, 0.088, 0.09]], b)), leg_mat, Vector3.ZERO, hip)
			part(loft(bl([[-0.40, 0.034, 0.04], [-0.28, 0.048, 0.054], [-0.13, 0.06, 0.064], [0.0, 0.05, 0.052]], b)), leg_mat, Vector3.ZERO, knee)
			if armor == "plate":
				part(dome(0.07 * b), m.trim, Vector3(0, 0, -0.045), knee, Vector3(-PI / 2, 0, 0))
				part(loft(bl([[-0.34, 0.04, 0.046], [-0.23, 0.056, 0.06], [-0.1, 0.067, 0.07], [-0.01, 0.058, 0.06]], b * 1.04)), m.metal, Vector3.ZERO, knee)
			var ankle := Node3D.new()
			ankle.position = Vector3(0, -0.40, 0)
			knee.add_child(ankle)
			if c.get("tex", "") == "demon" or c.get("pose", "") == "ghoul":
				# digitigrade claws instead of boots
				part(loft(bl([[-0.07, 0.04, 0.045], [-0.03, 0.05, 0.055], [0.0, 0.048, 0.05]], b)), leg_mat, Vector3.ZERO, ankle)
				for sx2 in [-1.0, 0.0, 1.0]:
					part(cone(0.0, 0.02, 0.14), m.dark, Vector3(sx2 * 0.03, -0.07, -0.14), ankle, Vector3(-PI / 2, 0, 0))
			else:
				part(loft(bl([[-0.07, 0.042, 0.048], [-0.03, 0.052, 0.058], [0.0, 0.05, 0.055]], b)), m.leather, Vector3.ZERO, ankle)
				part(caps(0.045 * b, 0.26), m.leather, Vector3(0, -0.045, -0.07), ankle, Vector3(PI / 2, 0, 0))
		hips.append(hip)
		knees.append(knee)

	# ---- body ----
	var body := Node3D.new()
	body.position = Vector3(0, 1.0, 0)
	root.add_child(body)
	var rig := Node3D.new()
	rig.position = Vector3(0, -1.0, 0)
	body.add_child(rig)

	var torso_mat: Material = m.skin if (bare and armor != "plate") else m.cloth
	var torso_base := 0.84
	if half:
		torso_base = 0.5
	part(loft(bl([[torso_base, 0.155, 0.105], [0.92, 0.18, 0.115], [1.02, 0.15, 0.10], [1.16, 0.17, 0.115], [1.30, 0.2, 0.125, 0, -0.005], [1.40, 0.19, 0.115], [1.47, 0.11, 0.085]], b)), torso_mat, Vector3.ZERO, rig)
	if robe:
		part(loft(bl([[0.04, 0.30, 0.28], [0.35, 0.24, 0.22], [0.7, 0.2, 0.17], [0.96, 0.16, 0.12], [1.1, 0.17, 0.12], [1.3, 0.2, 0.125], [1.42, 0.19, 0.115]], b)), m.cloth, Vector3.ZERO, rig)
	elif armor == "plate":
		part(loft(bl([[1.04, 0.158, 0.108], [1.16, 0.186, 0.13, 0, -0.01], [1.30, 0.215, 0.142, 0, -0.012], [1.40, 0.2, 0.124], [1.45, 0.13, 0.097]], b)), m.metal, Vector3.ZERO, rig)
		if not half:
			part(loft(bl([[0.74, 0.235, 0.165], [0.84, 0.21, 0.14], [0.95, 0.175, 0.12], [1.04, 0.158, 0.108]], b)), m.metal, Vector3.ZERO, rig)
			part(loft(bl([[0.56, 0.25, 0.18], [0.66, 0.245, 0.172], [0.74, 0.235, 0.165]], b)), m.cloth, Vector3.ZERO, rig)
			part(box(0.2 * b, 0.5, 0.012), m.cloth, Vector3(0, 0.76, -0.19 * b), rig)
		part(loft([[1.42, 0.125 * b, 0.105 * b], [1.5, 0.09 * b, 0.08 * b]]), m.metal, Vector3.ZERO, rig)
	elif armor == "light":
		part(loft(bl([[1.0, 0.16, 0.112], [1.16, 0.185, 0.128], [1.30, 0.21, 0.136], [1.40, 0.195, 0.12]], b)), m.leather, Vector3.ZERO, rig)
		part(loft(bl([[0.62, 0.22, 0.16], [0.8, 0.2, 0.14], [0.97, 0.16, 0.11]], b)), m.cloth, Vector3.ZERO, rig)
	else:
		part(loft(bl([[0.66, 0.2, 0.15], [0.8, 0.185, 0.13], [0.95, 0.16, 0.11]], b)), m.cloth, Vector3.ZERO, rig)
	part(loft([[1.46, 0.046 * b, 0.046 * b], [1.62, 0.04 * b, 0.04 * b]]), m.skin, Vector3.ZERO, rig)

	# demon ribs / zombie wounds: darker details on bare torsos
	if bare and armor == "none" and c.get("tex", "") in ["rot"]:
		part(box(0.14 * b, 0.1, 0.02), m.dark, Vector3(0.05, 1.22, -0.13 * b), rig, Vector3(0, 0, 0.4))
		part(box(0.1 * b, 0.07, 0.02), m.dark, Vector3(-0.07, 1.08, -0.12 * b), rig, Vector3(0, 0, -0.3))

	if c.get("cyber", false):
		# glowing reactor core, shoulder cannons, pistons
		part(sphere(0.1 * b), m.trim, Vector3(0, 1.28, -0.16 * b), rig)
		for sx in [-1.0, 1.0]:
			part(cone(0.05, 0.07, 0.4), m.metal, Vector3(sx * 0.3 * b, 1.55, 0.0), rig, Vector3(0.3, 0, sx * 0.25))
			part(cone(0.03, 0.03, 0.34), m.trim, Vector3(sx * 0.12 * b, 1.1, -0.14 * b), rig)

	# ---- head ----
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	rig.add_child(head)
	var skull: bool = helm == "skull" or c.get("skull", false)
	var hs: Material = m.skin
	part(sphere(1.0), hs, Vector3(0, 0.07, 0.008), head, Vector3.ZERO, Vector3(0.088 * b, 0.108, 0.1 * b))
	if skull:
		part(box(0.07 * b, 0.05, 0.06), hs, Vector3(0, -0.02, -0.07), head)
		for sx in [-1.0, 1.0]:
			part(sphere(0.026), m.dark, Vector3(sx * 0.034, 0.08, -0.085 * b), head)
			part(sphere(0.012), m.eye, Vector3(sx * 0.034, 0.08, -0.098 * b), head)
	else:
		part(cone(0.0, 0.017, 0.04), hs, Vector3(0, 0.045, -0.103 * b), head, Vector3(-PI / 2, 0, 0))
		for sx in [-1.0, 1.0]:
			part(sphere(0.013 if kind != "hollow" else 0.018), m.eye, Vector3(sx * 0.032 * b, 0.085, -0.092 * b), head)
			part(sphere(0.019), hs, Vector3(sx * 0.089 * b, 0.07, 0.01), head, Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	if c.get("jaw", false):
		# slack open mouth with teeth
		part(box(0.07 * b, 0.05, 0.07), m.dark, Vector3(0, -0.01, -0.09 * b), head, Vector3(0.3, 0, 0))
		for sx in [-0.03, 0.0, 0.03]:
			part(cone(0.0, 0.008, 0.03), m.hair, Vector3(sx, 0.0, -0.115 * b), head, Vector3(PI, 0, 0))
	var helm_from := _meshes.size()
	match helm:
		"none":
			if not c.get("bald", false):
				part(dome(0.1), m.hair, Vector3(0, 0.1, 0.02), head, Vector3.ZERO, Vector3(1.0, 0.9, 1.1))
		"hood":
			part(loft([[-0.02, 0.1, 0.11, 0, 0.02], [0.08, 0.115, 0.125, 0, 0.02], [0.16, 0.095, 0.1, 0, 0.0], [0.26, 0.02, 0.03, 0, 0.0]], 12), m.cloth, Vector3(0, 0.0, 0.01), head)
			part(sphere(0.085), m.dark, Vector3(0, 0.07, -0.05), head, Vector3.ZERO, Vector3(1.0, 1.1, 0.7))
		"great":
			part(loft([[-0.04, 0.105 * b, 0.115 * b], [0.07, 0.115 * b, 0.125 * b], [0.2, 0.108 * b, 0.118 * b], [0.215, 0.09 * b, 0.1 * b]], 14), m.metal, Vector3(0, 0, 0.005), head)
			part(box(0.15 * b, 0.02, 0.02), m.eye, Vector3(0, 0.09, -0.125 * b), head)
			part(box(0.02, 0.1, 0.02), m.eye, Vector3(0, 0.05, -0.125 * b), head)
			part(box(0.012, 0.03, 0.2), m.trim, Vector3(0, 0.23, 0), head)
		"horned":
			part(dome(0.11 * b), m.metal if armor == "plate" else hs, Vector3(0, 0.1, 0.004), head, Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
			part(box(0.016, 0.07, 0.014), m.metal, Vector3(0, 0.06, -0.113 * b), head)
			for sx in [-1.0, 1.0]:
				var hn := part(cone(0.0, 0.03, 0.34), m.trim if kind == "malakar" else hs, Vector3(sx * 0.1 * b, 0.22, 0.0), head, Vector3(0, 0, -sx * 0.7))
				hn.scale = Vector3.ONE * (1.0 if kind == "malakar" else 0.9)
				if kind in ["demon", "fiend"]:
					part(cone(0.0, 0.022, 0.22), hs, Vector3(sx * 0.13 * b, 0.12, 0.03), head, Vector3(0, 0, -sx * 1.1))
		"horned_small":
			for sx in [-1.0, 1.0]:
				part(cone(0.0, 0.024, 0.2), hs, Vector3(sx * 0.07 * b, 0.19, -0.01), head, Vector3(0.2, 0, -sx * 0.5))
		"skull":
			part(dome(0.092), m.metal, Vector3(0, 0.1, 0.0), head, Vector3.ZERO, Vector3(1.0, 0.6, 1.1))
		"crown":
			for i in 7:
				var a := float(i) / 7.0 * TAU
				part(cone(0.0, 0.014, 0.07), m.trim, Vector3(cos(a) * 0.092 * b, 0.19, sin(a) * 0.095 * b), head)
			part(ring(0.085 * b, 0.1 * b), m.trim, Vector3(0, 0.17, 0), head, Vector3.ZERO, Vector3(1, 0.5, 1))
			if kind == "queen":
				part(dome(0.1), m.hair, Vector3(0, 0.1, 0.02), head, Vector3.ZERO, Vector3(1.0, 0.95, 1.1))
	if kind == "queen":
		part(loft([[-0.6, 0.06, 0.05, 0, 0.1], [-0.3, 0.1, 0.06, 0, 0.1], [0.0, 0.11, 0.09, 0, 0.06], [0.1, 0.1, 0.1, 0, 0.02]], 10), m.hair, Vector3(0, 0, 0.02), head)

	# horns stay when the skin parts are swapped for the real body
	for hi in range(helm_from, _meshes.size()):
		if (_meshes[hi] as MeshInstance3D).mesh is CylinderMesh and helm.begins_with("horned") and kind != "imp":
			(_meshes[hi] as MeshInstance3D).set_meta("keep", true)

	# ---- cape ----
	var cape: Node3D = null
	if c.get("cape", false):
		cape = Node3D.new()
		cape.position = Vector3(0, 1.45, 0.1)
		rig.add_child(cape)
		var ln := 1.2 if kind in ["malakar", "bonelord"] else 1.05
		part(cape_mesh(b, ln), m.cloth, Vector3.ZERO, cape)

	# ---- wings / tail ----
	var wings: Array = []
	if c.get("wings", false):
		var span := 1.0 if kind == "imp" else 1.3
		for sx in [-1.0, 1.0]:
			var wn := Node3D.new()
			wn.position = Vector3(sx * 0.12 * b, 1.4, 0.1)
			rig.add_child(wn)
			var wm := part(wing_mesh(span, span * 0.65), m.cloth, Vector3.ZERO, wn)
			wm.scale = Vector3(sx, 1.0, 1.0)
			# bone fingers
			part(cone(0.01, 0.018, span * 0.9), m.skin, Vector3(sx * span * 0.45, span * 0.4, 0.0), wn, Vector3(0, 0, -sx * 1.1))
			wn.rotation = Vector3(0, sx * 0.5, 0)
			wings.append(wn)
	var tail: Node3D = null
	if c.get("tail", false):
		tail = Node3D.new()
		tail.position = Vector3(0, 0.95, 0.12)
		rig.add_child(tail)
		var tl := 0.35 if kind == "imp" else 0.5
		part(cone(0.012, 0.045, tl, 8), m.skin, Vector3(0, -0.05, tl * 0.5), tail, Vector3(PI / 2 - 0.4, 0, 0))
		part(cone(0.0, 0.03, 0.16, 8), m.dark, Vector3(0, -0.2, tl + 0.05), tail, Vector3(PI / 2 + 0.2, 0, 0))

	# ---- arms ----
	var arms: Array = []
	var elbows: Array = []
	var hands: Array = []
	var sleeve: Material = m.metal if armor == "plate" else (m.skin if bare and armor == "none" else m.cloth)
	for sx in [1.0, -1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.23 * b, 1.4, 0)
		rig.add_child(sh)
		if c.get("longarms", false):
			sh.scale = Vector3(1, 1.35, 1)
		part(loft(bl([[-0.30, 0.04, 0.04], [-0.2, 0.047, 0.047], [-0.08, 0.058, 0.058], [0.0, 0.056, 0.056]], b)), sleeve, Vector3.ZERO, sh)
		if armor == "plate":
			part(dome(0.125 * b), m.metal, Vector3(sx * 0.02, 0.0, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1.05, 0.85, 1.0))
			part(dome(0.115 * b), m.metal, Vector3(sx * 0.03, -0.035, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1.05, 0.7, 1.0))
			part(ring(0.105 * b, 0.125 * b), m.trim, Vector3(sx * 0.03, -0.045, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1, 0.5, 1))
		elif armor == "light":
			part(dome(0.1 * b), m.leather, Vector3(sx * 0.02, 0.0, 0), sh, Vector3(0, 0, sx * -0.2))
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.30, 0)
		sh.add_child(elbow)
		part(loft(bl([[-0.26, 0.032, 0.03], [-0.14, 0.045, 0.042], [0.0, 0.05, 0.048]], b)), sleeve if armor != "robe" else m.cloth, Vector3.ZERO, elbow)
		if armor == "plate":
			part(sphere(0.05 * b), m.trim, Vector3(0, 0, 0.035), elbow)
			part(loft(bl([[-0.22, 0.038, 0.036], [-0.12, 0.05, 0.047], [-0.02, 0.055, 0.052]], b * 1.04)), m.metal, Vector3.ZERO, elbow)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.27, 0)
		elbow.add_child(hand)
		part(loft(bl([[-0.1, 0.026, 0.017], [-0.05, 0.04, 0.024], [0.0, 0.036, 0.024]], b)), m.leather if armor != "none" else m.skin, Vector3.ZERO, hand)
		if c.weapon == "claws":
			for cx in [-0.025, 0.0, 0.025]:
				part(cone(0.0, 0.012, 0.13), m.dark, Vector3(cx, -0.14, -0.015), hand, Vector3(0.25, 0, 0))
		arms.append(sh)
		elbows.append(elbow)
		hands.append(hand)

	# ---- weapon ----
	var weapon := Node3D.new()
	weapon.position = Vector3(0, -0.05, 0)
	var wtype: String = c.weapon
	if wtype == "bow":
		hands[1].add_child(weapon)
		_bow(weapon, m)
	elif wtype != "none" and wtype != "claws":
		hands[0].add_child(weapon)
		_weapon(wtype, weapon, m)

	# ---- shield (strapped to left forearm) ----
	if c.get("shield", false):
		var sdisc := Node3D.new()
		sdisc.position = Vector3(-0.08 * b, -0.14, -0.04)
		elbows[1].add_child(sdisc)
		if kind == "skeleton":
			part(cone(0.22, 0.22, 0.03), m.weapon, Vector3.ZERO, sdisc, Vector3(0, 0, PI / 2))
			part(sphere(0.045), m.trim, Vector3(-0.025, 0, 0), sdisc)
		else:
			part(box(0.04, 0.66, 0.46), m.metal, Vector3.ZERO, sdisc)
			part(box(0.05, 0.7, 0.06), m.trim, Vector3(-0.012, 0, 0), sdisc)
			part(box(0.05, 0.06, 0.5), m.trim, Vector3(-0.012, 0.1, 0), sdisc)

	var fig := {"root": root, "body": body, "rig": rig, "arm": arms[0], "elbow": elbows[0], "larm": arms[1], "lelbow": elbows[1],
		"legs": hips, "knees": knees, "cape": cape, "sword": weapon, "head": head, "eye": m.eye, "meshes": _meshes.duplicate(),
		"hunch": c.get("hunch", 0.0), "wtype": wtype, "mats": [], "wings": wings, "tail": tail, "pose": c.get("pose", ""),
		"kind": kind, "quad": false, "head_y": 1.62 * float(c.scale)}
	_apply_asset(fig, kind)
	_real_body(fig, kind, m)
	return fig


# ------------------------------------------------------------ real bodies

const REAL_DIR := "res://assets/models/enemies/"
## Quaternius Universal Base Character (CC0, same rig as the princess) re-skinned per enemy: skin tint, roughness, hair/beard.
const REAL := {
	"villager_m": {"model": "Civ_M.glb", "h": 1.74, "tint": "", "hair": "Hair_Buzzed", "hair_col": "3a2616", "hide_all": true},
	"villager_f": {"model": "Civ_F.glb", "h": 1.66, "tint": "", "hair": "Hair_SimpleParted", "hair_col": "6a4426", "hide_all": true},
	"hollow": {"tint": "b4b4a6", "light": true, "hair": "Hair_Buzzed", "rough": 0.9},
	"zombie": {"tint": "8ca67e", "light": true, "hair": "", "rough": 0.95},
	"ghoul": {"tint": "b4bcd2", "light": true, "hair": "", "rough": 0.9},
	"archer": {"tint": "d2b9a0", "light": true, "hair": "Hair_Buzzed", "rough": 0.85},
	"mage": {"tint": "d0bcae", "light": true, "hair": "Hair_Beard", "rough": 0.85},
	"imp": {"model": "Imp.glb", "h": 1.45, "tint": "", "hair": ""},
	"skeleton": {"tint": "d6cfb4", "light": false, "flat": true, "hair": "", "rough": 0.75, "nohead": true},
	"fiend": {"tint": "a82c16", "light": false, "hair": "", "rough": 0.7},
	"knight": {"tint": "c6b6a6", "light": true, "hair": "", "rough": 0.85},
	"stonesoldier": {"tint": "9c9c92", "light": true, "hair": "", "rough": 1.0},
	"brute": {"tint": "d4a888", "light": false, "hair": "Hair_Beard", "rough": 0.9},
	"captain": {"tint": "c4ac98", "light": true, "hair": "Hair_Beard", "rough": 0.85},
	"demon": {"tint": "9a2c18", "light": false, "hair": "", "rough": 0.7},
	"malakar": {"tint": "8e807a", "light": true, "hair": "Hair_Beard", "rough": 0.8},
}


## Replaces the procedural skin / limbs / head of a humanoid with the real skinned body. The old procedural rig nodes stay (armour, cape, wings,
## weapons hang on them and the game keeps posing them); princess_sync() copies their rotations onto the bones every frame.
func _real_body(fig: Dictionary, kind: String, m: Dictionary) -> void:
	if not REAL.has(kind):
		return
	var r: Dictionary = REAL[kind]
	var path := REAL_DIR + String(r.get("model", "Body_Male.glb"))
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if not (packed is PackedScene):
		return
	var model: Node3D = (packed as PackedScene).instantiate()
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		model.free()
		return
	var sk: Skeleton3D = found[0]
	sk.reset_bone_poses()
	var c: Dictionary = CFG[kind]
	var b: float = c.build
	var body: Node3D = fig.body
	var holder := Node3D.new()
	holder.position = Vector3(0, -1.0, 0)
	holder.rotation.y = PI  # the model faces +Z, the game's figures face -Z
	holder.scale = Vector3(0.96 * lerpf(1.0, b, 0.6), 0.96, 0.96 * lerpf(1.0, b, 0.6))
	if r.has("h"):
		var acc: Array = [null]
		_glb_aabb(model, Transform3D.IDENTITY, acc)
		holder.scale = Vector3.ONE * float(r.h) / maxf((acc[0] as AABB).size.y, 0.01)
	holder.position.y -= float(r.get("sink", 0.0))  # half-bodied bosses: legs below the ground
	body.add_child(holder)
	holder.add_child(model)
	var real_meshes: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		real_meshes.append(m3)
		if r.tint != "" and (m3.name.begins_with("SuperHero") or m3.name.begins_with("Superhero")):
			var sm = m3.mesh.surface_get_material(0)
			if sm is StandardMaterial3D:
				var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				dm.albedo_color = Color(r.tint)
				dm.roughness = float(r.rough)
				dm.metallic = float(r.get("metal", 0.0))
				if r.get("flat", false):
					dm.albedo_texture = null
				elif r.light and ResourceLoader.exists(REAL_DIR + "T_Superhero_Male_Light.png"):
					dm.albedo_texture = load(REAL_DIR + "T_Superhero_Male_Light.png")
				m3.set_surface_override_material(0, dm)
	if r.get("nohead", false):
		sk.set_bone_pose_scale(sk.find_bone("Head"), Vector3.ONE * 0.001)  # the skull helm is the head
	var hair_name: String = r.hair
	if hair_name != "":
		var hp := REAL_DIR + hair_name + ".gltf"
		if ResourceLoader.exists(hp):
			var hair = (load(hp) as PackedScene).instantiate()
			for hm in hair.find_children("*", "MeshInstance3D", true, false):
				(hm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_tint_surfaces(hm as MeshInstance3D, Color(str(r.get("hair_col", "2a1c14"))) if kind != "mage" else Color("b8b8c0"))
				real_meshes.append(hm)
			_on_bone(sk, "Head", hair)
	# drop the procedural skin / hair parts; armour, cloth, horns, wings, tail, weapons stay
	var keepers: Array = [fig.cape, fig.tail, fig.sword]
	keepers.append_array(fig.wings)
	var kept: Array = []
	for mi in fig.meshes:
		var pm := mi as MeshInstance3D
		if not is_instance_valid(pm):
			continue
		var bare_eye: bool = pm.material_override == m.eye and pm.mesh is SphereMesh and (c.helm == "none" or kind == "imp")
		if bare_eye:
			pm.get_parent().remove_child(pm)
			pm.free()
			continue
		if pm.get_parent() == fig.root or pm.has_meta("keep") or pm.material_override == m.eye:
			kept.append(pm)
			continue
		var under := false
		var p: Node = pm
		while p != null and p != fig.root:
			if keepers.has(p):
				under = true
				break
			p = p.get_parent()
		var wound: bool = pm.material_override == m.dark and pm.mesh is BoxMesh and pm.get_parent() == fig.rig
		if r.get("nohead", false) and pm.get_parent() == fig.head:
			kept.append(pm)
			continue
		if not under and (pm.material_override == m.skin or pm.material_override == m.hair or wound or bool(r.get("hide_all", false))):
			pm.get_parent().remove_child(pm)
			pm.free()
		else:
			kept.append(pm)
	for rm in real_meshes:
		kept.append(rm)
	fig["meshes"] = kept
	fig["sk"] = sk
	fig["real"] = true
	princess_sync(fig)


# ---------------------------------------------------------------- hound

## Four-legged hellhound (monster). Faces -Z.
func hound() -> Dictionary:
	var kind := "hound"
	if not _mcache.has(kind):
		var m := {}
		m.fur = grad_mat([Color("0c0c10"), Color("26242c"), Color("3a2c2c"), Color("8a3a18")], 1.1, 0.0, 0.85, 0.7, 41, 3.5, FastNoiseLite.TYPE_PERLIN)
		m.dark = mat(Color("0a0a0c"), 0.5)
		m.eye = mat(Color("ff7a1a"), 0.4, 5.0)
		m.tooth = mat(Color("e8e2cc"), 0.5)
		_mcache[kind] = m
	var m: Dictionary = _mcache[kind]
	_meshes = []
	var root := Node3D.new()
	root.scale = Vector3.ONE * 1.1
	var blob_mat := unshaded(Color(0, 0, 0, 0.5))
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part(cone(0.8, 0.8, 0.02), blob_mat, Vector3(0, 0.07, 0), root)
	var body := Node3D.new()
	body.position = Vector3(0, 0.78, 0)
	root.add_child(body)
	# torso lies along -Z (rings ascend toward the head)
	part(loft([[-0.55, 0.17, 0.18], [-0.2, 0.22, 0.25], [0.15, 0.26, 0.3], [0.5, 0.23, 0.27], [0.8, 0.16, 0.2]]), m.fur, Vector3.ZERO, body, Vector3(-PI / 2, 0, 0))
	part(box(0.06, 0.1, 0.9), m.dark, Vector3(0, 0.3, 0.0), body)  # spiky mane ridge
	var head := Node3D.new()
	head.position = Vector3(0, 0.12, -0.78)
	body.add_child(head)
	part(sphere(0.2), m.fur, Vector3.ZERO, head, Vector3.ZERO, Vector3(1.0, 0.95, 1.2))
	part(cone(0.06, 0.12, 0.34), m.fur, Vector3(0, -0.04, -0.28), head, Vector3(-PI / 2 + 0.1, 0, 0))
	var jaw := Node3D.new()
	jaw.position = Vector3(0, -0.1, -0.12)
	head.add_child(jaw)
	part(cone(0.04, 0.09, 0.3), m.fur, Vector3(0, -0.02, -0.14), jaw, Vector3(-PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		part(cone(0.0, 0.025, 0.12), m.tooth, Vector3(sx * 0.05, 0.05, -0.2), jaw, Vector3(0, 0, 0))
		part(cone(0.0, 0.025, 0.1), m.tooth, Vector3(sx * 0.05, -0.04, -0.28), head, Vector3(PI, 0, 0))
		part(sphere(0.03), m.eye, Vector3(sx * 0.1, 0.07, -0.17), head)
		part(cone(0.0, 0.07, 0.22), m.fur, Vector3(sx * 0.1, 0.22, 0.02), head, Vector3(0.2, 0, -sx * 0.3))
	var legs: Array = []
	for fz in [-0.45, 0.4]:
		for sx in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(sx * 0.17, -0.02, fz)
			body.add_child(leg)
			part(loft([[-0.38, 0.04, 0.05], [-0.18, 0.06, 0.08], [0.0, 0.085, 0.1]]), m.fur, Vector3.ZERO, leg)
			part(cone(0.0, 0.05, 0.12), m.dark, Vector3(0, -0.4, -0.06), leg, Vector3(-PI / 2, 0, 0))
			legs.append(leg)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.1, 0.78)
	body.add_child(tail)
	part(cone(0.01, 0.06, 0.6, 8), m.fur, Vector3(0, 0.1, 0.28), tail, Vector3(PI / 2 + 0.5, 0, 0))
	var fig := {"root": root, "body": body, "rig": body, "legs": legs, "head": head, "jaw": jaw, "tail": tail, "eye": m.eye, "meshes": _meshes.duplicate(),
		"quad": true, "hunch": 0.0, "wtype": "none", "kind": "hound", "head_y": 1.0, "wings": [], "pose": "", "cape": null}
	_real_hound(fig)
	return fig


## Swaps the procedural hound for the animated Quaternius wolf (CC0): body, legs, head and tail are the real skinned model.
func _real_hound(fig: Dictionary) -> void:
	var path := REAL_DIR + "Wolf.glb"
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if not (packed is PackedScene):
		return
	var model: Node3D = (packed as PackedScene).instantiate()
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if ap == null:
		model.free()
		return
	var acc: Array = [null]
	_glb_aabb(model, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0]
	var k := 1.45 / maxf(maxf(bb.size.x, bb.size.z), 0.001)  # nose to tail about 1.45 m
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * k
	holder.position = Vector3(0, -0.78 - bb.position.y * k, 0)
	holder.rotation.y = 0.0 if bb.size.z >= bb.size.x else -PI / 2.0
	var body: Node3D = fig.body
	body.add_child(holder)
	holder.add_child(model)
	for an in ["Idle", "Walk", "Gallop", "Idle_2"]:
		if ap.has_animation(an):
			ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	var real_meshes: Array = []
	var fur: Material = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		real_meshes.append(m3)
		for si in m3.mesh.get_surface_count():
			var sm = m3.mesh.surface_get_material(si)
			if sm is StandardMaterial3D:
				var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				dm.albedo_color = Color(0.24, 0.2, 0.2)  # scorched dark pelt
				m3.set_surface_override_material(si, dm)
	for pm in fig.meshes:
		if is_instance_valid(pm) and pm.get_parent() != fig.root:
			pm.get_parent().remove_child(pm)
			pm.free()
	fig["meshes"] = real_meshes
	fig["anim"] = ap
	fig["anim_cur"] = ""
	fig["real"] = true
	_play(fig, "Idle")


# -------------------------------------------------------------- serpent

## Giant cobra-queen: a head node plus trailing body segments. Everything lives under `root`
## at the world origin; the game positions the head and each segment itself.
func serpent() -> Dictionary:
	var kind := "serpent"
	if not _mcache.has(kind):
		var m := {}
		m.scale = grad_mat([Color("062a1a"), Color("14683c"), Color("3aa05a"), Color("c8b440")], 1.6, 0.25, 0.45, 0.35, 61, 4.0, FastNoiseLite.TYPE_CELLULAR)
		m.belly = grad_mat([Color("a89a50"), Color("e0d490")], 1.2, 0.0, 0.6, 0.5, 63, 2.0)
		m.hood = grad_mat([Color("0a3a22"), Color("1a8a4a"), Color("d8c040")], 1.0, 0.2, 0.5, 0.4, 65, 3.0, FastNoiseLite.TYPE_CELLULAR)
		m.hood.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.eye = mat(Color("66ff88"), 0.3, 6.0)
		m.tooth = mat(Color("f4efdc"), 0.4)
		m.tongue = mat(Color("c01830"), 0.5)
		m.dark = mat(Color("050806"), 0.5)
		_mcache[kind] = m
	var m: Dictionary = _mcache[kind]
	_meshes = []
	var root := Node3D.new()
	var head := Node3D.new()
	root.add_child(head)
	# skull + snout
	part(sphere(0.62), m.scale, Vector3(0, 0, 0), head, Vector3.ZERO, Vector3(0.95, 0.75, 1.15))
	part(cone(0.18, 0.46, 0.9), m.scale, Vector3(0, -0.08, -0.7), head, Vector3(-PI / 2 + 0.05, 0, 0))
	part(cone(0.12, 0.4, 0.8), m.belly, Vector3(0, -0.28, -0.62), head, Vector3(-PI / 2 + 0.05, 0, 0), Vector3(1, 1, 0.5))
	for sx in [-1.0, 1.0]:
		part(sphere(0.12), m.eye, Vector3(sx * 0.36, 0.12, -0.38), head)
		part(cone(0.0, 0.05, 0.4), m.tooth, Vector3(sx * 0.2, -0.3, -0.85), head, Vector3(PI, 0, 0))
		part(cone(0.0, 0.05, 0.3), m.dark, Vector3(sx * 0.4, 0.2, -0.45), head, Vector3(0, 0, -sx * 0.6))
	part(box(0.04, 0.02, 0.6), m.tongue, Vector3(0, -0.32, -1.25), head)
	for sx in [-1.0, 1.0]:
		part(box(0.03, 0.02, 0.25), m.tongue, Vector3(sx * 0.07, -0.32, -1.62), head, Vector3(0, sx * 0.4, 0))
	# cobra hood (two flared discs behind the head, with glowing "eye spots")
	var hood := Node3D.new()
	hood.position = Vector3(0, -0.15, 0.55)
	head.add_child(hood)
	part(sphere(1.0), m.hood, Vector3.ZERO, hood, Vector3.ZERO, Vector3(1.35, 1.5, 0.12))
	for sx in [-1.0, 1.0]:
		part(sphere(0.2), m.eye, Vector3(sx * 0.5, 0.35, -0.1), hood, Vector3.ZERO, Vector3(1, 1, 0.4))
	# gorgon snakes writhing around the hood
	var snakes: Array = []
	for i in 8:
		var sn := Node3D.new()
		var a := float(i) / 8.0 * TAU
		sn.position = Vector3(cos(a) * 0.55, 0.45 + sin(a) * 0.5, 0.15)
		head.add_child(sn)
		part(cone(0.02, 0.07, 0.9, 6), m.scale, Vector3(0, 0.4, 0), sn)
		part(sphere(0.07), m.scale, Vector3(0, 0.88, 0), sn)
		snakes.append(sn)
	# body segments (thick near the head, tapering to the tail)
	var segs: Array = []
	var n := 22
	for i in n:
		var seg := Node3D.new()
		root.add_child(seg)
		var t := float(i) / (n - 1)
		var r := lerpf(0.78, 0.1, pow(t, 0.8))
		part(sphere(r), m.scale, Vector3.ZERO, seg, Vector3.ZERO, Vector3(1.0, 0.95, 1.35))
		part(sphere(r * 0.75), m.belly, Vector3(0, -r * 0.3, 0), seg, Vector3.ZERO, Vector3(0.9, 0.7, 1.35))
		segs.append(seg)
	return {"root": root, "head": head, "segs": segs, "snakes": snakes, "hood": hood, "eye": m.eye, "meshes": _meshes.duplicate(),
		"serpent": true, "quad": false, "hunch": 0.0, "wtype": "none", "kind": "serpent", "head_y": 0.0, "wings": [], "pose": "", "cape": null}


# ----------------------------------------------------------------- player

## Poly Haven (CC0) shield model, centred on the pivot with its face toward -Z. False if the file is missing.
func _real_shield(pivot: Node3D, id: String, height: float) -> bool:
	var path := "%s%s/%s_1k.gltf" % [PH, id, id]
	if not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if not (packed is PackedScene):
		return false
	var inst: Node3D = (packed as PackedScene).instantiate()
	var acc: Array = [null]
	_glb_aabb(inst, Transform3D.IDENTITY, acc)
	if acc[0] == null:
		inst.free()
		return false
	var bb: AABB = acc[0]
	var k := height / maxf(bb.size.y, 0.001)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * k
	holder.rotation.y = PI
	inst.position = -(bb.position + bb.size * 0.5)
	holder.add_child(inst)
	pivot.add_child(holder)
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var smi := n as MeshInstance3D
			smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for si in smi.mesh.get_surface_count():
				var sm = smi.mesh.surface_get_material(si)
				if sm is StandardMaterial3D:
					var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
					dm.metallic = minf(dm.metallic, 0.3)
					dm.roughness = clampf(dm.roughness, 0.45, 0.8)
					smi.set_surface_override_material(si, dm)
	return true


## Heater shield: domed steel face, leather back, gold rim and boss, painted cross, rivets. Face looks toward -Z.
func heater_shield(steel: Material, dark: Material, gold: Material, cloth: Material) -> Node3D:
	var pivot := Node3D.new()
	if _real_shield(pivot, "kite_shield", 0.9):
		return pivot
	var c := Vector2(0, 0.02)
	var outline: Array = []
	var top := 6
	for i in top + 1:
		var x := lerpf(-0.26, 0.26, float(i) / top)
		outline.append(Vector2(x, 0.30 + 0.02 * (1.0 - pow(x / 0.26, 2.0))))
	for i in range(1, 4):
		outline.append(Vector2(0.26, lerpf(0.30, 0.02, float(i) / 3.0)))
	for i in range(1, 9):
		var a := float(i) / 8.0 * PI / 2.0
		outline.append(Vector2(0.26 * cos(a), 0.02 - 0.40 * sin(a)))
	var left: Array = []
	for i in range(outline.size() - 1, top, -1):
		var q: Vector2 = outline[i]
		left.append(Vector2(-q.x, q.y))
	# the left side comes back up from the tip; drop the duplicate tip point
	if not left.is_empty():
		left.remove_at(0)
	var ring: Array = outline + left
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := ring.size()
	for i in n:
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % n]
		var m0 := c + (p0 - c) * 0.5
		var m1 := c + (p1 - c) * 0.5
		var tris := [
			[c, -0.05], [m0, -0.04], [m1, -0.04],
			[m0, -0.04], [p0, -0.005], [p1, -0.005],
			[m0, -0.04], [p1, -0.005], [m1, -0.04],
		]
		for v in tris:
			var pv: Vector2 = v[0]
			st.set_uv(pv * 2.0 + Vector2(0.5, 0.5))
			st.add_vertex(Vector3(pv.x, pv.y, float(v[1])))
	st.generate_normals()
	var face := st.commit()
	var steel2 := (steel as StandardMaterial3D).duplicate() as StandardMaterial3D
	steel2.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(face, steel2, Vector3.ZERO, pivot)
	part(face, dark, Vector3(0, 0, 0.012), pivot, Vector3.ZERO, Vector3(0.94, 0.94, 0.6))
	for i in n:
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % n]
		var d := p1 - p0
		part(box(d.length() + 0.012, 0.034, 0.045), gold, Vector3((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5, -0.008), pivot, Vector3(0, 0, d.angle()))
		if i % 3 == 0:
			var rp: Vector2 = c + (p0 - c) * 0.84
			part(sphere(0.014), gold, Vector3(rp.x, rp.y, -0.016), pivot)
	part(box(0.075, 0.5, 0.012), cloth, Vector3(0, 0.04, -0.036), pivot)
	part(box(0.4, 0.075, 0.012), cloth, Vector3(0, 0.13, -0.036), pivot)
	part(box(0.016, 0.5, 0.014), gold, Vector3(0, 0.04, -0.04), pivot)
	part(box(0.4, 0.016, 0.014), gold, Vector3(0, 0.13, -0.04), pivot)
	part(sphere(0.07), gold, Vector3(0, 0.1, -0.055), pivot, Vector3.ZERO, Vector3(1, 1, 0.55))
	part(sphere(0.03), dark, Vector3(0, 0.1, -0.07), pivot, Vector3.ZERO, Vector3(1, 1, 0.5))
	return pivot


func player() -> Dictionary:
	cast_shadows = true
	var steel := tex_mat(Color("4d525e"), Color("9aa1b0"), 0.2, 0.55, 0.42, 1.0, 3, 0.4)
	var dark := tex_mat(Color("1d2027"), Color("353a46"), 0.22, 0.45, 0.5, 1.0, 5, 0.4)
	var gold := tex_mat(Color("6e5420"), Color("c99f45"), 0.3, 0.65, 0.32, 1.0, 9, 0.3)
	var cloth := tex_mat(Color("3a0907"), Color("7a1812"), 0.9, 0.0, 0.92, 1.4, 11, 1.2)
	var under := tex_mat(Color("16181e"), Color("2c2f3a"), 0.8, 0.0, 0.9, 1.4, 15, 1.2)
	var leather := tex_mat(Color("1f120a"), Color("40261a"), 0.35, 0.0, 0.8, 1.2, 13, 0.8)
	var skin := tex_mat(Color("8a5a42"), Color("bb8466"), 0.5, 0.0, 0.7, 0.5, 21, 0.25)
	var hair := mat(Color("1c130e"), 0.9)
	var blade_m := tex_mat(Color("8c929e"), Color("e6eaf2"), 0.5, 0.6, 0.2, 1.0, 17, 0.3)
	var eye_m := mat(Color("0b0b0d"), 0.3)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_meshes = []

	var root := Node3D.new()
	var blob_mat := unshaded(Color(0, 0, 0, 0.5))
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part(cone(0.7, 0.7, 0.02), blob_mat, Vector3(0, 0.07, 0), root)

	var hips: Array = []
	var knees: Array = []
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.1, 0.92, 0)
		root.add_child(hip)
		part(loft([[-0.43, 0.05, 0.052], [-0.30, 0.064, 0.068], [-0.14, 0.082, 0.086], [0.0, 0.088, 0.09]]), under, Vector3.ZERO, hip)
		part(loft([[-0.38, 0.062, 0.066], [-0.26, 0.075, 0.079], [-0.12, 0.093, 0.097], [-0.02, 0.097, 0.099]]), steel, Vector3.ZERO, hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.43, 0)
		hip.add_child(knee)
		part(dome(0.07), gold, Vector3(0, 0.0, -0.045), knee, Vector3(-PI / 2, 0, 0))
		part(loft([[-0.40, 0.034, 0.04], [-0.28, 0.048, 0.054], [-0.13, 0.06, 0.064], [0.0, 0.05, 0.052]]), under, Vector3.ZERO, knee)
		part(loft([[-0.34, 0.04, 0.046], [-0.23, 0.056, 0.06], [-0.1, 0.067, 0.07], [-0.01, 0.058, 0.06]]), steel, Vector3(0, 0, -0.004), knee)
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -0.40, 0)
		knee.add_child(ankle)
		part(loft([[-0.07, 0.042, 0.048], [-0.03, 0.052, 0.058], [0.0, 0.05, 0.055]]), leather, Vector3.ZERO, ankle)
		part(caps(0.045, 0.26), leather, Vector3(0, -0.045, -0.07), ankle, Vector3(PI / 2, 0, 0))
		part(caps(0.042, 0.14), steel, Vector3(0, -0.04, -0.15), ankle, Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.7))
		hips.append(hip)
		knees.append(knee)

	var body := Node3D.new()
	body.position = Vector3(0, 1.0, 0)
	root.add_child(body)
	var rig := Node3D.new()
	rig.position = Vector3(0, -1.0, 0)
	body.add_child(rig)

	part(loft([[0.84, 0.155, 0.105], [0.92, 0.18, 0.115], [1.02, 0.15, 0.10], [1.16, 0.17, 0.115], [1.30, 0.2, 0.125, 0, -0.005], [1.40, 0.19, 0.115], [1.47, 0.11, 0.085]]), under, Vector3.ZERO, rig)
	part(loft([[1.04, 0.158, 0.108], [1.16, 0.186, 0.13, 0, -0.01], [1.30, 0.215, 0.142, 0, -0.012], [1.40, 0.2, 0.124], [1.45, 0.13, 0.097]]), steel, Vector3.ZERO, rig)
	part(loft([[0.76, 0.235, 0.165], [0.84, 0.21, 0.14], [0.95, 0.175, 0.12], [1.04, 0.158, 0.108]]), dark, Vector3.ZERO, rig)
	part(loft([[0.58, 0.25, 0.18], [0.68, 0.245, 0.172], [0.76, 0.235, 0.165]]), under, Vector3.ZERO, rig)
	part(loft([[0.97, 0.165, 0.114], [1.03, 0.165, 0.114]]), leather, Vector3.ZERO, rig)
	part(box(0.07, 0.06, 0.02), gold, Vector3(0, 1.0, -0.118), rig)
	part(box(0.2, 0.5, 0.012), cloth, Vector3(0, 0.78, -0.178), rig)
	part(box(0.22, 0.03, 0.02), gold, Vector3(0, 0.53, -0.178), rig)
	var emblem: Mesh = load(A + "meshes/Diamond.obj")
	if emblem != null:
		part(emblem, gold, Vector3(0, 1.28, -0.157), rig, Vector3.ZERO, Vector3.ONE * 0.05)
	part(loft([[1.42, 0.125, 0.105], [1.5, 0.088, 0.078]]), steel, Vector3.ZERO, rig)
	part(loft([[1.46, 0.046, 0.046], [1.62, 0.04, 0.04]]), skin, Vector3.ZERO, rig)

	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	rig.add_child(head)
	part(sphere(1.0), skin, Vector3(0, 0.07, 0.008), head, Vector3.ZERO, Vector3(0.088, 0.108, 0.1))
	part(cone(0.0, 0.017, 0.04), skin, Vector3(0, 0.045, -0.103), head, Vector3(-PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		part(sphere(0.011), eye_m, Vector3(sx * 0.032, 0.085, -0.092), head)
		part(box(0.04, 0.008, 0.012), hair, Vector3(sx * 0.032, 0.103, -0.095), head, Vector3(0, 0, sx * -0.12))
		part(sphere(0.019), skin, Vector3(sx * 0.089, 0.07, 0.01), head, Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	part(sphere(0.06), hair, Vector3(0, 0.0, -0.045), head, Vector3.ZERO, Vector3(1.0, 0.75, 0.8))
	part(dome(0.108), steel, Vector3(0, 0.1, 0.004), head, Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
	part(ring(0.098, 0.128), steel, Vector3(0, 0.1, 0.0), head, Vector3.ZERO, Vector3(1.0, 0.35, 1.1))
	part(box(0.014, 0.075, 0.012), steel, Vector3(0, 0.07, -0.113), head)
	for sx in [-1.0, 1.0]:
		part(box(0.01, 0.075, 0.075), steel, Vector3(sx * 0.1, 0.045, -0.01), head)
	part(box(0.012, 0.018, 0.2), gold, Vector3(0, 0.215, 0.0), head)

	# armour-set extras (hidden until a set is equipped)
	var armor_nodes := {"demon": [], "serpent": [], "cyborg": []}
	for sx in [-1.0, 1.0]:
		var dh := part(cone(0.0, 0.03, 0.34), gold, Vector3(sx * 0.1, 0.24, 0.0), head, Vector3(0, 0, -sx * 0.6))
		dh.visible = false
		armor_nodes.demon.append(dh)
		var sp := part(cone(0.0, 0.05, 0.3), gold, Vector3(sx * 0.15, 0.2, 0.0), head, Vector3(0, 0, -sx * 1.2))
		sp.visible = false
		armor_nodes.cyborg.append(sp)
	var crest := part(cone(0.0, 0.12, 0.45), gold, Vector3(0, 0.34, 0.08), head, Vector3(0.7, 0, 0), Vector3(0.3, 1.0, 1.0))
	crest.visible = false
	armor_nodes.serpent.append(crest)
	var vis := part(box(0.3, 0.03, 0.02), gold, Vector3(0, 0.08, -0.115), head)
	vis.visible = false
	armor_nodes.cyborg.append(vis)

	var cape := Node3D.new()
	cape.position = Vector3(0, 1.45, 0.1)
	rig.add_child(cape)
	part(cape_mesh(), cloth, Vector3.ZERO, cape)

	var arms: Array = []
	var elbows: Array = []
	var hands: Array = []
	for sx in [1.0, -1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.23, 1.4, 0)
		rig.add_child(sh)
		part(loft([[-0.30, 0.04, 0.04], [-0.2, 0.047, 0.047], [-0.08, 0.058, 0.058], [0.0, 0.056, 0.056]]), under, Vector3.ZERO, sh)
		part(loft([[-0.25, 0.048, 0.048], [-0.15, 0.055, 0.055], [-0.05, 0.066, 0.066]]), steel, Vector3.ZERO, sh)
		part(dome(0.125), steel, Vector3(sx * 0.02, 0.0, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1.05, 0.85, 1.0))
		part(dome(0.115), steel, Vector3(sx * 0.03, -0.035, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1.05, 0.7, 1.0))
		part(ring(0.105, 0.125), gold, Vector3(sx * 0.03, -0.045, 0), sh, Vector3(0, 0, sx * -0.2), Vector3(1, 0.5, 1))
		var spike := part(cone(0.0, 0.04, 0.28), gold, Vector3(sx * 0.1, 0.12, 0), sh, Vector3(0, 0, -sx * 0.5))
		spike.visible = false
		armor_nodes.demon.append(spike)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.30, 0)
		sh.add_child(elbow)
		part(sphere(0.05), gold, Vector3(0, 0, 0.035), elbow)
		part(loft([[-0.26, 0.032, 0.03], [-0.14, 0.045, 0.042], [0.0, 0.05, 0.048]]), under, Vector3.ZERO, elbow)
		part(loft([[-0.22, 0.038, 0.036], [-0.12, 0.05, 0.047], [-0.02, 0.055, 0.052]]), steel, Vector3.ZERO, elbow)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.27, 0)
		elbow.add_child(hand)
		part(loft([[-0.1, 0.026, 0.017], [-0.05, 0.04, 0.024], [0.0, 0.036, 0.024]]), leather, Vector3.ZERO, hand)
		arms.append(sh)
		elbows.append(elbow)
		hands.append(hand)

	# ---- weapons: one pivot in the right hand holding every weapon model ----
	var sword := Node3D.new()
	sword.position = Vector3(0, -0.05, 0)
	hands[0].add_child(sword)
	var weapons := {}
	var w_sword := Node3D.new()
	sword.add_child(w_sword)
	var blen := 1.0
	part(cone(0.018, 0.018, 0.22), leather, Vector3(0, 0, -0.02), w_sword, Vector3(PI / 2, 0, 0))
	part(sphere(0.028), gold, Vector3(0, 0, 0.1), w_sword)
	part(box(0.24, 0.025, 0.035), gold, Vector3(0, 0, -0.14), w_sword)
	part(box(0.055, 0.012, blen), blade_m, Vector3(0, 0, -0.16 - blen / 2.0), w_sword)
	part(box(0.015, 0.014, blen * 0.8), dark, Vector3(0, 0.005, -0.18 - blen * 0.4), w_sword)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.055, 0.12, 0.012)
	part(tip, blade_m, Vector3(0, 0, -0.16 - blen - 0.06), w_sword, Vector3(-PI / 2, 0, 0))
	real_weapon(HEAVY_SWORD, w_sword, 1.5, 0.18)
	weapons["sword"] = w_sword

	# Demon Cleaver: huge notched slab with glowing runes
	var w_cleaver := Node3D.new()
	sword.add_child(w_cleaver)
	var demon_steel := grad_mat([Color("1a0a08"), Color("5a1a10"), Color("8a3a20")], 0.4, 0.6, 0.4, 1.0, 71, 1.0)
	var rune := mat(Color("ff5a1a"), 0.3, 4.0)
	part(cone(0.03, 0.03, 0.9), leather, Vector3(0, 0, 0.1), w_cleaver, Vector3(PI / 2, 0, 0))
	part(sphere(0.05), gold, Vector3(0, 0, 0.58), w_cleaver)
	part(box(0.36, 0.06, 0.08), gold, Vector3(0, 0, -0.36), w_cleaver)
	part(box(0.5, 0.035, 0.95), demon_steel, Vector3(0.06, 0, -0.9), w_cleaver)
	part(box(0.04, 0.045, 0.9), rune, Vector3(0.28, 0, -0.9), w_cleaver)
	for k in 4:
		part(box(0.12, 0.04, 0.1), demon_steel, Vector3(0.34, 0, -0.55 - k * 0.22), w_cleaver, Vector3(0, 0.4, 0))
	part(box(0.1, 0.04, 0.5), rune, Vector3(0.05, 0.02, -0.9), w_cleaver)
	real_weapon("wooden_axe_03", w_cleaver, 1.7, 0.16)
	w_cleaver.visible = false
	weapons["cleaver"] = w_cleaver

	# Serpent Fang: a long spear with a leaf blade and green glow
	var w_spear := Node3D.new()
	sword.add_child(w_spear)
	var jade := mat(Color("30d070"), 0.3, 2.5)
	part(cone(0.022, 0.026, 2.3), leather, Vector3(0, 0, -0.55), w_spear, Vector3(PI / 2, 0, 0))
	var sp_head := PrismMesh.new()
	sp_head.size = Vector3(0.15, 0.55, 0.03)
	part(sp_head, blade_m, Vector3(0, 0, -1.95), w_spear, Vector3(-PI / 2, 0, 0))
	part(box(0.04, 0.035, 0.4), jade, Vector3(0, 0.0, -1.95), w_spear)
	part(box(0.22, 0.03, 0.05), gold, Vector3(0, 0, -1.65), w_spear)
	for sx in [-1.0, 1.0]:
		part(cone(0.0, 0.03, 0.2), jade, Vector3(sx * 0.07, 0, -1.7), w_spear, Vector3(-PI / 2 - 0.3, 0, 0))
	w_spear.visible = false
	weapons["spear"] = w_spear

	# Ashen Revolver
	var w_gun := Node3D.new()
	sword.add_child(w_gun)
	part(box(0.045, 0.05, 0.4), steel, Vector3(0, 0.02, -0.3), w_gun)
	part(cone(0.04, 0.04, 0.12), dark, Vector3(0, 0.0, -0.02), w_gun, Vector3(PI / 2, 0, 0))
	part(box(0.04, 0.12, 0.06), leather, Vector3(0, -0.07, 0.05), w_gun, Vector3(-0.3, 0, 0))
	part(box(0.02, 0.05, 0.02), gold, Vector3(0, 0.07, 0.02), w_gun, Vector3(0.4, 0, 0))
	part(box(0.016, 0.02, 0.5), gold, Vector3(0, 0.055, -0.3), w_gun)
	var muzzle := part(sphere(0.12), mat(Color("ffd070"), 0.3, 6.0), Vector3(0, 0.02, -0.55), w_gun)
	muzzle.visible = false
	if real_weapon("service_pistol", w_gun, 0.42, 0.09, true):
		muzzle.position = Vector3(0, 0.0, -0.36)
	w_gun.visible = false
	weapons["gun"] = w_gun

	var shield := heater_shield(steel, dark, gold, cloth)
	rig.add_child(shield)
	shield.position = Vector3(0, 1.12, 0.2)
	shield.rotation = Vector3(0, PI, 0.25)

	var arc := MeshInstance3D.new()
	arc.mesh = arc_mesh()
	arc.material_override = arc_mat
	arc.position = Vector3(0, 1.0, 0)
	arc.visible = false
	root.add_child(arc)
	cast_shadows = false
	var fig := {"root": root, "body": body, "rig": rig, "arm": arms[0], "elbow": elbows[0], "larm": arms[1], "lelbow": elbows[1],
		"legs": hips, "knees": knees, "cape": cape, "sword": sword, "shield": shield, "head": head,
		"blade_mat": blade_m, "gold_mat": gold, "meshes": _meshes.duplicate(), "eye": eye_m, "arc": arc, "hunch": 0.0, "wtype": "sword",
		"weapons": weapons, "muzzle": muzzle, "armor_nodes": armor_nodes,
		"armor_mats": {"steel": steel, "dark": dark, "gold": gold, "cloth": cloth}}
	_apply_asset(fig, "player", [sword, shield, arc, muzzle])
	return fig


# ---------------------------------------------------------- downloaded models

## Draw-call saver for a built figure: every joint (shoulder, elbow, hip...) keeps ONE mesh per material instead of a
## MeshInstance3D per decorative piece. Hidden pieces (armour sets, unused weapons) and anything a script touches individually stay as is.
func optimize(fig: Dictionary) -> void:
	var root: Node = fig.root
	var nodes: Array = [root]
	var i := 0
	while i < nodes.size():
		nodes.append_array((nodes[i] as Node).get_children().filter(func(c): return c is Node3D and not (c is MeshInstance3D)))
		i += 1
	var meshes: Array = (fig.meshes as Array).filter(func(m): return is_instance_valid(m))
	for n in nodes:
		var groups := {}
		for c in (n as Node).get_children():
			if c is MeshInstance3D and c.visible and c.material_override != null and c.mesh != null and c.get_child_count() == 0 and c != fig.get("arc"):
				var mat: Material = c.material_override
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue
				var key := "%d_%d" % [mat.get_instance_id(), c.cast_shadow]
				if not groups.has(key):
					groups[key] = []
				groups[key].append(c)
		for key in groups:
			var arr: Array = groups[key]
			if arr.size() < 2:
				continue
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for c in arr:
				for si in (c as MeshInstance3D).mesh.get_surface_count():
					st.append_from((c as MeshInstance3D).mesh, si, (c as MeshInstance3D).transform)
			var merged := MeshInstance3D.new()
			merged.mesh = st.commit()
			merged.material_override = (arr[0] as MeshInstance3D).material_override
			merged.cast_shadow = (arr[0] as MeshInstance3D).cast_shadow
			(n as Node).add_child(merged)
			for c in arr:
				meshes.erase(c)
				(n as Node).remove_child(c)
				(c as Node).free()
			meshes.append(merged)
	fig["meshes"] = meshes


func _glb_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var bb: AABB = xf * (n as MeshInstance3D).get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for ch in n.get_children():
		_glb_aabb(ch, xf, acc)


## Swaps the procedural body for a downloaded GLB (if one is listed in ASSETS and present). keep = nodes whose meshes stay visible.
func _apply_asset(fig: Dictionary, kind: String, keep: Array = []) -> void:
	if not ASSETS.has(kind):
		return
	var path: String = KENNEY + String(ASSETS[kind].glb)
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if not (packed is PackedScene):
		return
	var inst: Node3D = (packed as PackedScene).instantiate()
	var acc: Array = [null]
	_glb_aabb(inst, Transform3D.IDENTITY, acc)
	if acc[0] == null:
		inst.free()
		return
	var bb: AABB = acc[0]
	var k: float = float(ASSETS[kind].h) / maxf(bb.size.y, 0.001)
	inst.scale = Vector3.ONE * k
	# body pivots at the hips (y = 1.0 in the figure); feet of the model go on the floor
	inst.position = Vector3(0, -1.0 - bb.position.y * k, 0)
	# Kenney characters face +Z, the game faces -Z
	inst.rotation.y = PI
	var body: Node3D = fig.body
	body.add_child(inst)
	var shared := StandardMaterial3D.new()
	var have_mat := false
	var meshes: Array = fig.meshes
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			meshes.append(mi)
			if not have_mat and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var src = mi.mesh.surface_get_material(0)
				if src is StandardMaterial3D:
					shared = (src as StandardMaterial3D).duplicate()
					have_mat = true
			mi.material_override = shared if have_mat else null
	if have_mat:
		fig["asset_mat"] = shared
	# hide the procedural body, except weapon-type parts and the ground blob (direct child of root)
	var root: Node = fig.root
	var todo: Array = [root]
	while not todo.is_empty():
		var n2: Node = todo.pop_back()
		if n2 == inst:
			continue
		todo.append_array(n2.get_children())
		if n2 is MeshInstance3D and n2.get_parent() != root:
			var skip: bool = fig.sword == n2
			var p: Node = n2
			while p != null and not skip:
				if p == fig.sword or keep.has(p):
					skip = true
				p = p.get_parent()
			if not skip:
				(n2 as MeshInstance3D).visible = false
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap != null:
		for an in LOOPED:
			if ap.has_animation(an):
				ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		fig["anim"] = ap
		fig["anim_cur"] = ""
		_play(fig, "idle")


func _play(fig: Dictionary, an: String) -> void:
	var ap: AnimationPlayer = fig.anim
	if fig.anim_cur == an or not ap.has_animation(an):
		return
	fig["anim_cur"] = an
	ap.play(an, 0.12)


## Called every frame by game.gd; no-op for procedural figures.
func drive_asset(fig: Dictionary, moving: float, attacking: bool, rolling: bool = false) -> void:
	if not fig.has("anim"):
		return
	if attacking:
		_play(fig, "attack-melee-right")
	elif rolling:
		_play(fig, "sprint")
	elif moving > 0.6:
		_play(fig, "sprint")
	elif moving > 0.05:
		_play(fig, "walk")
	else:
		_play(fig, "idle")


const ARMOR_COLORS := {
	"ashen": {"steel": ["4d525e", "9aa1b0"], "dark": ["1d2027", "353a46"], "gold": ["6e5420", "c99f45"], "cloth": ["3a0907", "7a1812"], "glow": 0.0},
	"demon": {"steel": ["3a0a08", "9a2a18"], "dark": ["120404", "3a0c0a"], "gold": ["8a3a10", "ff8a20"], "cloth": ["14080a", "4a1418"], "glow": 0.8},
	"serpent": {"steel": ["0a3a24", "2e9a58"], "dark": ["06180e", "163a24"], "gold": ["8a7a20", "f0dc60"], "cloth": ["0a2a1a", "1a6a3a"], "glow": 0.0},
	"cyborg": {"steel": ["2a3038", "7a8a9a"], "dark": ["0e1218", "2a3440"], "gold": ["0a5a7a", "30e0ff"], "cloth": ["0e1620", "1e3a50"], "glow": 2.2},
}


## Re-colours the player's armour and shows the matching extra pieces.
func set_armor(fig: Dictionary, id: String) -> void:
	var cols: Dictionary = ARMOR_COLORS[id]
	if fig.has("asset_mat"):
		# downloaded body: tint it with the armour colour instead of toggling the procedural plates
		fig.asset_mat.albedo_color = Color.WHITE.lerp(Color(cols.steel[1]), 0.55)
	var mats: Dictionary = fig.armor_mats
	for k in ["steel", "dark", "gold", "cloth"]:
		var mm: StandardMaterial3D = mats[k]
		var tex: NoiseTexture2D = mm.albedo_texture
		var g: Gradient = tex.color_ramp
		g.colors = PackedColorArray([Color(cols[k][0]), Color(cols[k][1])])
	var gm: StandardMaterial3D = mats.gold
	gm.emission_enabled = float(cols.glow) > 0.0
	gm.emission = Color(cols.gold[1])
	gm.emission_energy_multiplier = float(cols.glow)
	if fig.has("asset_mat"):
		return
	for k in fig.armor_nodes:
		for n in fig.armor_nodes[k]:
			n.visible = (k == id)


func show_weapon(fig: Dictionary, id: String) -> void:
	for k in fig.weapons:
		fig.weapons[k].visible = (k == id)


# --------------------------------------------------------------- princess

## ------------------------------------------------------------------ princess (real model)
## Quaternius "Universal Base Characters" female body (CC0) dressed in a procedural gown, sleeves, sash, tiara and necklace that are
## fitted to her measurements and ride on her skeleton. Returns {} if the model files are missing (the procedural princess is the fallback).

const PRINCESS_DIR := "res://assets/models/princess/"


func _bone_set_basis(sk: Skeleton3D, i: int, basis_g: Basis) -> void:
	var parent := sk.get_bone_parent(i)
	var pg: Transform3D = sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var rest_local: Transform3D = sk.get_bone_rest(i)
	var desired := Transform3D(basis_g, pg * rest_local.origin)
	var local := pg.affine_inverse() * desired
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
	sk.set_bone_pose_position(i, rest_local.origin)


## Parks a node (authored in the model's rest space) on a bone so it follows that bone.
func _on_bone(sk: Skeleton3D, bone: String, node: Node3D) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	sk.add_child(att)
	var rest: Transform3D = sk.get_bone_global_rest(sk.find_bone(bone))
	node.transform = rest.affine_inverse() * node.transform
	att.add_child(node)
	return att


## Multiplies the albedo of every surface of a mesh by a colour (turns the grey base hair golden).
func _tint_surfaces(mi: MeshInstance3D, col: Color) -> void:
	for si in mi.mesh.get_surface_count():
		var sm = mi.mesh.surface_get_material(si)
		if sm is StandardMaterial3D:
			var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
			dm.albedo_color = col
			mi.set_surface_override_material(si, dm)


func _princess_real() -> Dictionary:
	var path := PRINCESS_DIR + "Superhero_Female_FullBody.gltf"
	if not ResourceLoader.exists(path):
		return {}
	var packed = load(path)
	if not (packed is PackedScene):
		return {}
	var model: Node3D = (packed as PackedScene).instantiate()
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		model.free()
		return {}
	var sk: Skeleton3D = found[0]
	var silk := mat(Color("dfe6f6"), 0.6)
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	var silk2 := mat(Color("a9c2ee"), 0.55)
	silk2.cull_mode = BaseMaterial3D.CULL_DISABLED
	var royal := mat(Color("2a4ca8"), 0.45)
	royal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold_m := mat(Color("e8c25a"), 0.28)
	gold_m.metallic = 0.85
	var jewel := mat(Color("5ad0ff"), 0.15, 1.1)
	_meshes = []
	var root := Node3D.new()
	root.scale = Vector3.ONE * (1.68 / 1.775)
	var blob_mat := unshaded(Color(0, 0, 0, 0.5))
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part(cone(0.7, 0.7, 0.02), blob_mat, Vector3(0, 0.07, 0), root)
	var body := Node3D.new()
	body.position = Vector3(0, 1.0, 0)
	root.add_child(body)
	var holder := Node3D.new()
	holder.position = Vector3(0, -1.0, 0)
	holder.rotation.y = PI  # the model faces +Z, the game's figures face -Z
	body.add_child(holder)
	holder.add_child(model)
	# lighter skin for the princess, and let every part receive light like the other figures
	var light_tex_path := PRINCESS_DIR + "T_Superhero_Female_Light_BaseColor.png"
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_meshes.append(m3)
		if m3.name == "Eyebrows":
			_tint_surfaces(m3, Color("6a4326"))
		if m3.name == "Superhero_Female" and ResourceLoader.exists(light_tex_path):
			var sm = m3.mesh.surface_get_material(0)
			if sm is StandardMaterial3D:
				var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				dm.albedo_texture = load(light_tex_path)
				m3.set_surface_override_material(0, dm)
	sk.reset_bone_poses()

	# ---- gown, fitted to the body (measured from the mesh)
	var skirt := Node3D.new()
	part(loft([[0.02, 0.5, 0.48, 0, -0.03], [0.2, 0.42, 0.4, 0, -0.03], [0.45, 0.34, 0.31, 0, -0.04], [0.7, 0.27, 0.23, 0, -0.045],
		[0.9, 0.235, 0.185, 0, -0.04], [1.0, 0.19, 0.15, 0, -0.03], [1.085, 0.13, 0.1, 0, 0.01]], 36, false), silk2, Vector3.ZERO, skirt)
	part(loft([[0.05, 0.53, 0.5, 0, -0.03], [0.25, 0.44, 0.41, 0, -0.03], [0.5, 0.35, 0.32, 0, -0.04], [0.76, 0.275, 0.235, 0, -0.045],
		[0.95, 0.24, 0.19, 0, -0.04], [1.02, 0.2, 0.158, 0, -0.03]], 36, false), silk, Vector3(0, -0.012, 0), skirt)
	part(ring(0.5, 0.55), gold_m, Vector3(0, 0.04, -0.03), skirt, Vector3.ZERO, Vector3(1, 0.5, 1))
	for i in 10:
		var a := float(i) / 10.0 * TAU
		part(sphere(0.02), jewel, Vector3(cos(a) * 0.5, 0.08, -0.03 + sin(a) * 0.48), skirt)
	_on_bone(sk, "pelvis", skirt)
	var bodice := Node3D.new()
	part(loft([[1.0, 0.2, 0.15, 0, -0.03], [1.1, 0.14, 0.1, 0, 0.01], [1.2, 0.15, 0.12, 0, 0.012], [1.3, 0.172, 0.15, 0, 0.007], [1.385, 0.185, 0.145, 0, 0.0]], 28), silk, Vector3.ZERO, bodice)
	part(ring(0.128, 0.162), royal, Vector3(0, 1.09, 0.01), bodice, Vector3.ZERO, Vector3(1.0, 0.7, 0.82))
	part(box(0.07, 0.09, 0.02), royal, Vector3(0, 1.1, 0.12), bodice)
	part(sphere(0.026), jewel, Vector3(0, 1.1, 0.135), bodice)
	part(sphere(0.03), jewel, Vector3(0, 1.31, 0.158), bodice, Vector3.ZERO, Vector3(1, 1, 0.6))
	_on_bone(sk, "spine_02", bodice)
	# sleeves: a soft puff on the upper arm and a long bell sleeve on the forearm, mirrored
	for s in [1.0, -1.0]:
		var side := "l" if s > 0.0 else "r"
		var up_rest: Transform3D = sk.get_bone_global_rest(sk.find_bone("upperarm_" + side))
		var lo_rest: Transform3D = sk.get_bone_global_rest(sk.find_bone("lowerarm_" + side))
		var arm_axis := Basis(Vector3(0, 0, 1), -s * PI / 2.0)  # lofts run along +Y; the arm runs along +/-X
		var puff := Node3D.new()
		part(loft([[-0.03, 0.062, 0.062], [0.05, 0.072, 0.072], [0.14, 0.066, 0.066], [0.24, 0.054, 0.054]], 18), silk, Vector3.ZERO, puff)
		puff.transform = Transform3D(arm_axis, up_rest.origin)
		_on_bone(sk, "upperarm_" + side, puff)
		var bell := Node3D.new()
		part(loft([[0.0, 0.05, 0.05], [0.1, 0.046, 0.046], [0.2, 0.05, 0.05], [0.26, 0.062, 0.062], [0.3, 0.07, 0.07]], 18, false), silk, Vector3.ZERO, bell)
		part(ring(0.066, 0.078), gold_m, Vector3(0, 0.3, 0), bell, Vector3.ZERO, Vector3(1, 0.5, 1))
		bell.transform = Transform3D(arm_axis, lo_rest.origin)
		_on_bone(sk, "lowerarm_" + side, bell)
	# necklace and tiara
	var neck := Node3D.new()
	part(ring(0.052, 0.063), gold_m, Vector3(0, 1.478, -0.035), neck, Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
	part(sphere(0.022), jewel, Vector3(0, 1.45, 0.045), neck, Vector3.ZERO, Vector3(1, 1.2, 0.7))
	_on_bone(sk, "neck_01", neck)
	var crown := Node3D.new()
	part(ring(0.09, 0.098), gold_m, Vector3(0, 1.728, 0.0), crown, Vector3(-0.2, 0, 0), Vector3(1, 0.5, 1.05))
	for i in 5:
		var a2 := lerpf(-0.9, 0.9, float(i) / 4.0)
		var h := 0.05 if i == 2 else 0.03
		part(cone(0.0, 0.011, h), gold_m, Vector3(sin(a2) * 0.093, 1.752 + (0.012 if i == 2 else 0.0), cos(a2) * 0.098), crown, Vector3(-0.3, 0, -a2 * 0.3))
		part(sphere(0.011), jewel, Vector3(sin(a2) * 0.093, 1.738, cos(a2) * 0.099), crown)
	part(sphere(0.018), jewel, Vector3(0, 1.735, 0.103), crown)
	_on_bone(sk, "Head", crown)
	# hair (origin-at-0 asset, so it sits on the head as authored)
	var hair_path := PRINCESS_DIR + "Hair_Long.gltf"
	if ResourceLoader.exists(hair_path):
		var hair = (load(hair_path) as PackedScene).instantiate()
		for hm in hair.find_children("*", "MeshInstance3D", true, false):
			(hm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tint_surfaces(hm as MeshInstance3D, Color("e2a85c"))
			_meshes.append(hm)
		_on_bone(sk, "Head", hair)

	# the game's rig API: arm / elbow / larm / lelbow / legs / knees are plain nodes whose rotations princess_sync() applies to the bones
	var arm := Node3D.new()
	var elbow := Node3D.new()
	var larm := Node3D.new()
	var lelbow := Node3D.new()
	var legs: Array = [Node3D.new(), Node3D.new()]
	var knees: Array = [Node3D.new(), Node3D.new()]
	var weapon := Node3D.new()
	for n in [arm, elbow, larm, lelbow, legs[0], legs[1], knees[0], knees[1], weapon]:
		root.add_child(n)
	var fig := {"root": root, "body": body, "rig": body, "arm": arm, "elbow": elbow, "larm": larm, "lelbow": lelbow,
		"legs": legs, "knees": knees, "cape": null, "sword": weapon, "head": body, "eye": silk, "meshes": _meshes.duplicate(),
		"hunch": 0.0, "wtype": "none", "mats": [], "wings": [], "tail": null, "pose": "", "kind": "princess", "quad": false,
		"head_y": 1.64 * 1.68 / 1.775, "sk": sk, "skirt": skirt, "real": true}
	princess_sync(fig)
	return fig


## Applies the game-side arm / leg rotations (old rig convention: x swings forward) to the princess's bones.
func princess_sync(fig: Dictionary) -> void:
	if not fig.get("real", false):
		return
	var sk: Skeleton3D = fig.sk
	var down := 1.3  # arms hang from the T-pose
	var arms := [[fig.arm, fig.elbow, "r", -1.0], [fig.larm, fig.lelbow, "l", 1.0]]
	for a in arms:
		var rot: Vector3 = (a[0] as Node3D).rotation
		var bend: float = (a[1] as Node3D).rotation.x
		var s: float = a[3]
		var swing := Basis(Vector3(1, 0, 0), -rot.x)
		var inward := Basis(Vector3(0, 1, 0), -s * absf(rot.y))
		var down_b := Basis(Vector3(0, 0, 1), -s * down)
		var up_i := sk.find_bone("upperarm_" + a[2])
		var lo_i := sk.find_bone("lowerarm_" + a[2])
		_bone_set_basis(sk, up_i, inward * swing * down_b * sk.get_bone_global_rest(up_i).basis)
		var swing2 := Basis(Vector3(1, 0, 0), -(rot.x + bend))
		_bone_set_basis(sk, lo_i, inward * swing2 * down_b * sk.get_bone_global_rest(lo_i).basis)
	var sides := [["l", 0], ["r", 1]]
	for sd in sides:
		var th_i := sk.find_bone("thigh_" + sd[0])
		var ca_i := sk.find_bone("calf_" + sd[0])
		var sw: float = (fig.legs[sd[1]] as Node3D).rotation.x
		var kn: float = (fig.knees[sd[1]] as Node3D).rotation.x
		_bone_set_basis(sk, th_i, Basis(Vector3(1, 0, 0), -sw) * sk.get_bone_global_rest(th_i).basis)
		_bone_set_basis(sk, ca_i, Basis(Vector3(1, 0, 0), -(sw + kn)) * sk.get_bone_global_rest(ca_i).basis)


## Elegant princess: layered gown, bodice, sleeves, long hair, tiara, jewelry.
func princess() -> Dictionary:
	var real := _princess_real()
	if not real.is_empty():
		return real
	var kind := "princess"
	if not _mcache.has(kind):
		var m := {}
		m.skin = grad_mat([Color("a07058"), Color("e0b49c")], 0.5, 0.0, 0.7, 0.5, 81, 0.2)
		m.gown = grad_mat([Color("c8d4f4"), Color("f6f8ff"), Color("b0c4ee")], 0.7, 0.0, 0.55, 1.0, 83, 0.8)
		m.gown.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.sash = grad_mat([Color("2a4a9a"), Color("5a7ad8")], 0.9, 0.1, 0.4, 1.0, 85, 0.6)
		m.gold = grad_mat([Color("8a6a20"), Color("f0d060")], 0.3, 0.8, 0.25, 1.0, 87, 0.3)
		m.hair = grad_mat([Color("3a1c0c"), Color("6a3a1a"), Color("8a5a2c")], 1.4, 0.0, 0.45, 0.8, 89, 2.0)
		m.jewel = mat(Color("5ad0ff"), 0.2, 3.5)
		m.eye = mat(Color("3a7ad8"), 0.2, 1.2)
		m.lip = mat(Color("c04a5a"), 0.5)
		m.dark = mat(Color("2a1a14"), 0.6)
		_mcache[kind] = m
	var m: Dictionary = _mcache[kind]
	_meshes = []
	var root := Node3D.new()
	root.scale = Vector3.ONE * 0.97
	var blob_mat := unshaded(Color(0, 0, 0, 0.5))
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part(cone(0.7, 0.7, 0.02), blob_mat, Vector3(0, 0.07, 0), root)
	var hips: Array = []
	var knees: Array = []
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.08, 0.92, 0)
		root.add_child(hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.43, 0)
		hip.add_child(knee)
		part(loft([[-0.4, 0.034, 0.04], [-0.25, 0.05, 0.055], [-0.05, 0.05, 0.052]]), m.skin, Vector3(0, 0, 0), knee)
		part(caps(0.04, 0.2), m.gold, Vector3(0, -0.4, -0.05), knee, Vector3(PI / 2, 0, 0))
		hips.append(hip)
		knees.append(knee)
	var body := Node3D.new()
	body.position = Vector3(0, 1.0, 0)
	root.add_child(body)
	var rig := Node3D.new()
	rig.position = Vector3(0, -1.0, 0)
	body.add_child(rig)
	# gown: flared double skirt, fitted bodice, sash
	part(loft([[0.0, 0.52, 0.5], [0.12, 0.47, 0.45], [0.35, 0.36, 0.34], [0.6, 0.24, 0.22], [0.82, 0.16, 0.13], [0.98, 0.13, 0.1]], 22), m.gown, Vector3.ZERO, rig)
	part(loft([[0.08, 0.44, 0.43], [0.3, 0.33, 0.32], [0.5, 0.22, 0.2], [0.7, 0.16, 0.13]], 18), m.gown, Vector3(0, 0.0, 0.0), rig)
	part(ring(0.47, 0.54), m.gold, Vector3(0, 0.04, 0), rig, Vector3.ZERO, Vector3(1, 0.4, 1))
	for i in 8:
		var a := float(i) / 8.0 * TAU
		part(sphere(0.03), m.jewel, Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.48), rig)
	part(loft([[0.96, 0.13, 0.1], [1.08, 0.12, 0.095], [1.22, 0.15, 0.11], [1.36, 0.16, 0.11], [1.44, 0.11, 0.08]], 16), m.gown, Vector3.ZERO, rig)
	part(ring(0.11, 0.15), m.sash, Vector3(0, 1.0, 0), rig, Vector3.ZERO, Vector3(1.0, 0.7, 0.8))
	part(box(0.1, 0.14, 0.02), m.sash, Vector3(0, 0.98, 0.12), rig)
	part(sphere(0.04), m.jewel, Vector3(0, 1.3, -0.105), rig)
	part(loft([[1.44, 0.04, 0.04], [1.58, 0.036, 0.036]]), m.skin, Vector3.ZERO, rig)
	part(ring(0.05, 0.062), m.gold, Vector3(0, 1.45, 0), rig, Vector3.ZERO, Vector3(1.0, 0.3, 1.0))
	part(sphere(0.03), m.jewel, Vector3(0, 1.43, -0.07), rig)

	var head := Node3D.new()
	head.position = Vector3(0, 1.56, 0)
	rig.add_child(head)
	part(sphere(1.0), m.skin, Vector3(0, 0.07, 0.008), head, Vector3.ZERO, Vector3(0.082, 0.1, 0.09))
	part(cone(0.0, 0.012, 0.03), m.skin, Vector3(0, 0.05, -0.095), head, Vector3(-PI / 2, 0, 0))
	part(box(0.034, 0.008, 0.012), m.lip, Vector3(0, 0.0, -0.088), head)
	for sx in [-1.0, 1.0]:
		part(sphere(0.014), m.eye, Vector3(sx * 0.03, 0.08, -0.08), head)
		part(box(0.04, 0.006, 0.01), m.dark, Vector3(sx * 0.03, 0.098, -0.082), head, Vector3(0, 0, sx * -0.15))
		part(sphere(0.016), m.skin, Vector3(sx * 0.079, 0.07, 0.01), head, Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
		part(sphere(0.012), m.gold, Vector3(sx * 0.083, 0.045, 0.01), head)
	# hair: crown cap, bangs, and a long cascade down the back with side strands
	part(dome(0.095), m.hair, Vector3(0, 0.1, 0.012), head, Vector3.ZERO, Vector3(1.05, 1.0, 1.15))
	part(loft([[-0.75, 0.05, 0.04, 0, 0.12], [-0.45, 0.095, 0.05, 0, 0.13], [-0.15, 0.115, 0.075, 0, 0.1], [0.08, 0.1, 0.09, 0, 0.05]], 12), m.hair, Vector3(0, 0, 0.02), head)
	for sx in [-1.0, 1.0]:
		part(loft([[-0.5, 0.025, 0.025, 0, 0], [-0.2, 0.04, 0.04, 0, 0], [0.06, 0.03, 0.03, 0, 0]], 8), m.hair, Vector3(sx * 0.1, 0.0, -0.02), head)
	part(box(0.07, 0.03, 0.02), m.hair, Vector3(-0.03, 0.15, -0.085), head, Vector3(0.3, 0, 0.3))
	# tiara
	part(ring(0.088, 0.098), m.gold, Vector3(0, 0.15, -0.012), head, Vector3(0.25, 0, 0), Vector3(1, 0.35, 1))
	part(cone(0.0, 0.016, 0.07), m.gold, Vector3(0, 0.2, -0.085), head)
	part(sphere(0.016), m.jewel, Vector3(0, 0.19, -0.09), head)
	for sx in [-1.0, 1.0]:
		part(cone(0.0, 0.012, 0.05), m.gold, Vector3(sx * 0.045, 0.18, -0.08), head, Vector3(0, 0, -sx * 0.35))

	# arms with bell sleeves and gloves
	var arms: Array = []
	var elbows: Array = []
	var hands: Array = []
	for sx in [1.0, -1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.17, 1.38, 0)
		rig.add_child(sh)
		part(sphere(0.07), m.gown, Vector3(0, 0, 0), sh)
		part(loft([[-0.3, 0.03, 0.03], [-0.15, 0.04, 0.04], [0.0, 0.05, 0.05]]), m.skin, Vector3.ZERO, sh)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.28, 0)
		sh.add_child(elbow)
		part(loft([[-0.27, 0.075, 0.075], [-0.16, 0.05, 0.05], [0.0, 0.04, 0.04]], 14), m.gown, Vector3.ZERO, elbow)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.27, 0)
		elbow.add_child(hand)
		part(loft([[-0.1, 0.022, 0.015], [-0.05, 0.034, 0.02], [0.0, 0.03, 0.02]]), m.gown, Vector3.ZERO, hand)
		arms.append(sh)
		elbows.append(elbow)
		hands.append(hand)
	var weapon := Node3D.new()
	hands[0].add_child(weapon)
	return {"root": root, "body": body, "rig": rig, "arm": arms[0], "elbow": elbows[0], "larm": arms[1], "lelbow": elbows[1],
		"legs": hips, "knees": knees, "cape": null, "sword": weapon, "head": head, "eye": m.eye, "meshes": _meshes.duplicate(),
		"hunch": 0.0, "wtype": "none", "mats": [], "wings": [], "tail": null, "pose": "", "kind": "princess", "quad": false, "head_y": 1.62 * 0.97}
