extends RefCounted
## The labyrinth is pitch dark: the only light is the torch in the hero's hand. A hero holding the torch cannot use any weapon - to fight, the
## torch has to be dropped on the ground (where it keeps burning and lights the fight) and picked up again afterwards.

var g  # the game node
var active := false          # inside the labyrinth: the torch exists
var held := false            # carried in the weapon hand
var ground := Vector2.INF    # where it lies when dropped
var _hand: Node3D = null
var _floor: Node3D = null
var _hand_light: OmniLight3D = null
var _floor_light: OmniLight3D = null
var _t := 0.0


func setup(game: Node3D) -> void:
	g = game


func _flame_mesh() -> Mesh:
	return g._sphere(0.045, g._unshaded(Color("ffb050")))


## A stick with a burning head: oriented along -Z like the weapons (grip at the origin), or standing up when `upright`.
func _build(upright: bool) -> Dictionary:
	var n := Node3D.new()
	var wood = g._mat(Color("3a2616"), 0.9)
	var rag = g._mat(Color("1a120c"), 0.95)
	var stick: Node3D
	var tip: Vector3
	if upright:
		stick = g._mesh(g._cyl(0.045, 1.0), wood, Vector3(0, 0.5, 0), n)
		stick.rotation = Vector3(0.0, 0.0, 0.18)
		tip = Vector3(-0.09, 1.05, 0)
	else:
		stick = g._mesh(g._cyl(0.035, 0.95), wood, Vector3(0, 0, -0.45), n)
		stick.rotation = Vector3(PI / 2.0, 0, 0)
		tip = Vector3(0, 0.02, -0.95)
	g._mesh(g._sphere(0.085), rag, tip, n)
	var flame := CPUParticles3D.new()
	flame.amount = 16
	flame.lifetime = 0.55
	flame.direction = Vector3.UP
	flame.spread = 14.0
	flame.initial_velocity_min = 0.5
	flame.initial_velocity_max = 1.1
	flame.gravity = Vector3(0, 1.0, 0)
	flame.scale_amount_min = 0.7
	flame.scale_amount_max = 1.3
	flame.mesh = _flame_mesh()
	flame.local_coords = false
	n.add_child(flame)
	flame.position = tip + Vector3(0, 0.07, 0)
	# a steady core so the flame never disappears between particles
	var core1: Node3D = g._mesh(g.M.cone(0.0, 0.07, 0.26), g._unshaded(Color("ff8a28")), tip + Vector3(0, 0.2, 0), n)
	var core2: Node3D = g._mesh(g.M.cone(0.0, 0.04, 0.18), g._unshaded(Color("ffe39a")), tip + Vector3(0, 0.16, 0), n)
	core1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 3.4
	light.omni_range = 17.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	n.add_child(light)
	light.position = tip + Vector3(0, 0.45, 0)
	return {"node": n, "light": light, "core1": core1, "core2": core2}


func enter() -> void:
	if active:
		return
	active = true
	held = true
	var b := _build(false)
	_hand = b.node
	_hand_light = b.light
	(g.pfig.sword.get_parent() as Node3D).add_child(_hand)
	g.pfig.sword.visible = false
	g._light_scan = 0.0
	g._show_banner("THE LABYRINTH IS DARK", 3.2, "Drag the right side of the screen to look  -  drop the torch to fight")
	g.sfx("crumble", -6.0, 1.4)


func leave() -> void:
	if not active:
		return
	active = false
	held = false
	ground = Vector2.INF
	for n in [_hand, _floor]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_hand = null
	_floor = null
	g.pfig.sword.visible = true


func can_pick() -> bool:
	return active and not held and ground != Vector2.INF and g.p_pos.distance_to(ground) < 3.2


## Button / key: drop the torch (to fight) or pick it up again.
func toggle() -> void:
	if not active or g.p_act not in ["idle", "block"]:
		return
	if held:
		held = false
		ground = g.p_pos + Vector2.from_angle(g.p_face) * 1.0
		var b := _build(true)
		_floor = b.node
		_floor_light = b.light
		g.add_child(_floor)
		_floor.global_position = g._p3(ground)
		_floor_light.light_energy = 3.0
		if _hand != null:
			_hand.visible = false
		g.pfig.sword.visible = true
		g._light_scan = 0.0
		g._burst(ground, 10, Color("ffb050"), 4.0, 0.3)
		g.sfx("crumble", -4.0, 1.0)
		g._float(g._p3(g.p_pos, 2.5), "TORCH DROPPED", Color("ffb050"))
	elif can_pick():
		held = true
		ground = Vector2.INF
		if _floor != null:
			_floor.queue_free()
			_floor = null
		if _hand != null:
			_hand.visible = true
		g.pfig.sword.visible = false
		g._light_scan = 0.0
		g.sfx("swing", -8.0, 0.7)
		g._float(g._p3(g.p_pos, 2.5), "TORCH", Color("ffb050"))


func update(dt: float) -> void:
	if not active:
		return
	_t += dt
	var flick := 1.0 + 0.1 * sin(_t * 13.0) + 0.06 * sin(_t * 29.0 + 1.0) + randf_range(-0.04, 0.04)
	if _hand_light != null:
		_hand_light.light_energy = 3.4 * flick
	if _floor_light != null and is_instance_valid(_floor_light):
		_floor_light.light_energy = 3.0 * flick
	# the torch in hand follows the weapon hand's pose
	if _hand != null and held:
		_hand.transform = g.pfig.sword.transform
		g.pfig.sword.visible = false
