extends RefCounted
## Character portraits for dialogue and boss bars: each head is rendered once in its own little 3D world.

var g
var _tex := {}


func setup(game) -> void:
	g = game


## Returns a texture for the character `kind` (humanoid kind, "serpent" or "hound"), built on first use.
func get_tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	g.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.72)
	env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 160, 0)
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.3
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(1.5, 1.0, 2.0)
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 1.2
	rim.omni_range = 40.0
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	if kind == "serpent":
		var f: Dictionary = g.M.serpent()
		vp.add_child(f.root)
		f.head.position = Vector3.ZERO
		for s in f.segs:
			s.visible = false
		cam.position = Vector3(0, 0.05, -3.4)
		cam.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	elif kind == "hound":
		var f2: Dictionary = g.M.hound()
		vp.add_child(f2.root)
		cam.position = Vector3(0.0, 1.1, -2.2)
		cam.look_at(Vector3(0, 0.95, -0.8), Vector3.UP)
	else:
		var f3: Dictionary = g.M.humanoid(kind)
		vp.add_child(f3.root)
		var s: float = f3.root.scale.x
		var hy: float = float(f3.head_y) + 0.05 * s
		if kind == "cyborg":
			f3.root.position.y = -3.0
			hy -= 3.0
		cam.position = Vector3(0, hy, -1.35 * s)
		cam.look_at(Vector3(0, hy - 0.02 * s, 0), Vector3.UP)
	var t: Texture2D = vp.get_texture()
	_tex[kind] = t
	return t
