extends RefCounted
## The labyrinth's civilians. They cower in the dead ends until the hero frees them (walk up, tap RESCUE). Freed civilians FOLLOW the hero in single
## file along his trail, or STAY where they are when ordered to (the COMMAND button). Monsters maul any civilian they reach: if even one dies the
## quest fails and the labyrinth resets. Lead everyone across the maze to the far gate to save them.

const SAYS := ["thank_you_bless_you_knight", "i_thought_no_one_would_ever_come", "please_get_us_out_of_here", "you_saved_me_i_will_follow_you",
	"oh_thank_the_stars", "hurry_the_corridors_are_full_of_monsters"]
const FREE := ["we_are_free_thank_you_ashen_knight", "you_have_our_thanks_brave_knight"]
const STAYS := ["we_will_wait_here", "please_hurry_back"]
const FOLLOWS := ["right_behind_you", "lead_the_way"]
const MAX_HP := 80.0

var g  # the game node
var list: Array = []   # {fig, pos, state, face, walk, t, order, beam, hp, hit_t}
var trail: Array = []  # the hero's breadcrumbs
var total := 0
var rescued := 0
var saved := 0
var stay := false      # the standing order for freed civilians: false = follow, true = stay
var _freed := false
var _tex2: Texture2D = null
var _free_t := 0.0


func setup(game: Node3D) -> void:
	g = game


func clear() -> void:
	for c in list:
		if is_instance_valid(c.fig.root):
			(c.fig.root as Node).queue_free()
		if is_instance_valid(c.beam):
			(c.beam as Node).queue_free()
	list.clear()
	trail.clear()
	total = 0
	rescued = 0
	saved = 0
	stay = false
	_freed = false


func spawn(spots: Array) -> void:
	clear()
	var bm = g._unshaded(Color(0.5, 0.9, 1.0, 0.16))
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in spots.size():
		var fig: Dictionary = g.M.humanoid("villager_m" if i % 2 == 0 else "villager_f")
		g.M.optimize(fig)
		if i % 3 == 1:
			_recolour(fig)
		g.add_child(fig.root)
		fig.root.scale *= randf_range(0.93, 1.05)
		var pos: Vector2 = spots[i]
		var beam: Node3D = g._mesh(g._cyl(0.3, 24.0), bm, Vector3(pos.x, g._h(pos) + 12.0, pos.y), g)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		list.append({"fig": fig, "pos": pos, "state": "hiding", "face": randf() * TAU, "walk": 0.0, "t": randf() * 6.0, "order": -1, "beam": beam,
			"hp": MAX_HP, "hit_t": 0.0, "dead_t": 0.0})
	total = list.size()


## Some civilians wear the second colour scheme of the peasant outfit.
func _recolour(fig: Dictionary) -> void:
	if _tex2 == null and ResourceLoader.exists("res://assets/models/enemies/T_Peasant_2.jpg"):
		_tex2 = load("res://assets/models/enemies/T_Peasant_2.jpg") as Texture2D
	if _tex2 == null:
		return
	for mi in fig.meshes:
		var m3 := mi as MeshInstance3D
		if m3 == null or not is_instance_valid(m3) or not str(m3.name).contains("Peasant"):
			continue
		for si in m3.mesh.get_surface_count():
			var sm = m3.mesh.surface_get_material(si)
			if sm is StandardMaterial3D:
				var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				dm.albedo_texture = _tex2
				m3.set_surface_override_material(si, dm)


func all_saved() -> bool:
	if total == 0:
		return false
	for c in list:
		if c.state != "gone":
			return false
	return true


func follow_count() -> int:
	var n := 0
	for c in list:
		if c.state == "follow":
			n += 1
	return n


func staying_count() -> int:
	var n := 0
	for c in list:
		if c.state == "stay":
			n += 1
	return n


func following_count() -> int:
	var n := 0
	for c in list:
		if c.state == "follow" or c.state == "stay":
			n += 1
	return n


## Index of the nearest civilian still waiting to be freed within reach, or -1.
func near_index(p: Vector2, reach: float) -> int:
	for i in list.size():
		var c: Dictionary = list[i]
		if c.state == "hiding" and p.distance_to(c.pos) < reach:
			return i
	return -1


func nearest_waiting(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for c in list:
		if c.state == "hiding":
			var d: float = p.distance_to(c.pos)
			if d < bd:
				bd = d
				best = c.pos
	return best


## Where the civilians that were ordered to stay are (for the guide arrow when the hero has to fetch them).
func nearest_staying(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for c in list:
		if c.state == "stay":
			var d: float = p.distance_to(c.pos)
			if d < bd:
				bd = d
				best = c.pos
	return best


func rescue(i: int) -> void:
	var c: Dictionary = list[i]
	c.state = "follow"  # newly freed civilians always follow; the COMMAND button then sends everyone one way or the other
	c.order = rescued
	rescued += 1
	if is_instance_valid(c.beam):
		(c.beam as Node).queue_free()
	g._burst(c.pos, 22, Color("9adfff"), 7.0, 1.2)
	g.sfx("chime", -4.0, 1.3)
	g.vox.play("say_civ_" + SAYS[randi() % SAYS.size()], 0.0, 1.0)
	g._float(g._p3(c.pos, 2.4), "RESCUED  %d / %d" % [rescued, total], Color("9adfff"))
	if rescued >= total:
		g._show_banner("EVERYONE IS FREE", 2.6, "Keep them alive and lead them to the far gate")


## The COMMAND button: everyone freed either follows the hero or stays put (crouched, harder to hit).
func command_toggle() -> void:
	if rescued <= 0 or following_count() <= 0:
		g._show_banner("NOBODY TO COMMAND", 1.4, "Rescue a civilian first")
		return
	# anyone following? then everybody stays; otherwise everybody follows again
	stay = follow_count() > 0
	var any := false
	for c in list:
		if c.state == "follow" or c.state == "stay":
			c.state = "stay" if stay else "follow"
			any = true
	if any:
		var pool: Array = STAYS if stay else FOLLOWS
		g.vox.play("say_civ_" + pool[randi() % pool.size()], 0.0, 1.0)
		g.sfx("chime", -8.0, 1.0 if stay else 1.4)
		g._float(g._p3(g.p_pos, 2.7), "STAY HERE" if stay else "FOLLOW ME", Color("9adfff"))
		g._show_banner("CIVILIANS: STAY" if stay else "CIVILIANS: FOLLOW", 1.6, "They will wait here until you call them" if stay else "They follow you in single file")
	else:
		g._show_banner("NOBODY TO COMMAND", 1.4, "Rescue a civilian first")


func _hero_trail(p: Vector2) -> void:
	if trail.is_empty() or p.distance_to(trail[trail.size() - 1]) > 0.7:
		trail.append(p)
		if trail.size() > 600:
			trail.pop_front()


func _damage(c: Dictionary, amt: float, from: Vector2) -> void:
	c.hp -= amt
	c.hit_t = 0.8
	g._float(g._p3(c.pos, 2.6), "-%d" % int(amt), Color("ff6a5a"))
	g._burst(c.pos, 10, Color("a01018"), 5.0, 1.2)
	g.sfx("hurt", -8.0, 1.5)
	if c.hp <= 0.0 and c.state != "dead":
		c.state = "dead"
		c.dead_t = 0.0
		g._burst(c.pos, 24, Color("a01018"), 8.0, 1.0)
		g.maze_failed("A civilian was killed")


func update(dt: float) -> void:
	if list.is_empty():
		return
	var hero: Vector2 = g.p_pos
	_hero_trail(hero)
	var exit_p: Vector2 = g.structures.maze.get("exit", hero)
	var out_dir: Vector2 = (exit_p - g.structures.maze.center).normalized() if g.structures.maze.has("center") else Vector2.RIGHT
	# everyone is free and gathered at the gate: they run out to safety
	if rescued >= total and not _freed and hero.distance_to(exit_p) < 10.0:
		var near := true
		for c in list:
			if c.state != "dead" and c.pos.distance_to(exit_p) > 16.0:
				near = false
		if near:
			_freed = true
			_free_t = 0.0
			for c in list:
				c.state = "escape"
			g.vox.play("say_civ_" + FREE[randi() % FREE.size()], 1.0, 1.0)
			g.sfx("chime", -2.0, 1.1)
			g._burst(exit_p, 40, Color("ffe9a8"), 8.0, 1.4)
			g._show_banner("CIVILIANS SAVED", 3.0, "+%d SOULS" % (120 * total))
			g.souls += 120 * total
	if _freed:
		_free_t += dt
	# followers walk in the order they were freed
	var followers: Array = []
	for c in list:
		if c.state == "follow":
			followers.append(c)
	followers.sort_custom(func(a, b): return a.order < b.order)
	for c in list:
		c.hit_t = maxf(0.0, float(c.hit_t) - dt)
		var fig: Dictionary = c.fig
		var root: Node3D = fig.root
		if c.state in ["hiding", "follow", "stay"] and not g.exec.active:
			_maul(c)
		match c.state:
			"hiding", "stay":
				c.t += dt
				if hero.distance_to(c.pos) < 14.0:
					c.face = lerp_angle(c.face, (hero - c.pos).angle(), 1.0 - exp(-3.0 * dt))
				_huddle(fig, float(c.t))
			"follow":
				var rank := followers.find(c)
				var idx: int = trail.size() - 1 - 8 * (rank + 1)
				var target: Vector2 = c.pos
				if idx >= 0:
					target = trail[idx]
				var d: Vector2 = target - c.pos
				var dl := d.length()
				if dl > 30.0:
					c.pos = target
				elif dl > 0.35:
					var step := minf(dl, (3.4 + minf(dl, 4.0) * 0.9) * dt)
					c.pos += d / dl * step
					c.face = lerp_angle(c.face, d.angle(), 1.0 - exp(-8.0 * dt))
					c.walk += dt * 9.0
					_walk(fig, float(c.walk), 1.0)
				else:
					_walk(fig, float(c.walk), 0.0)
			"escape":
				var goal: Vector2 = exit_p + out_dir * 22.0
				var d2: Vector2 = goal - c.pos
				if d2.length() < 1.0 or _free_t > 14.0:
					c.state = "gone"
					root.visible = false
				else:
					c.pos += d2.normalized() * 4.6 * dt
					c.face = lerp_angle(c.face, d2.angle(), 1.0 - exp(-8.0 * dt))
					c.walk += dt * 10.0
					_walk(fig, float(c.walk), 1.0)
			"dead":
				c.dead_t += dt
				fig.body.rotation = Vector3(-1.5, 0.0, 0.0)
				fig.body.position.y = 0.3
			"gone":
				continue
		root.position = g._p3(c.pos)
		root.rotation.y = g._face_rot(float(c.face))
		if c.state == "hiding" or c.state == "stay":
			root.position.y -= 0.32
		g.M.princess_sync(fig)
		if c.hit_t > 0.0 and c.state != "dead":
			root.position.x += sin(g.t * 60.0) * 0.03


## Monsters maul any civilian they reach, and enemy shots that hit one are stopped by it.
func _maul(c: Dictionary) -> void:
	if g.get("_maze_fail_t") != null and float(g._maze_fail_t) >= 0.0:
		return
	var reach_add := 1.9 if c.state == "follow" else 1.5
	if c.hit_t <= 0.0:
		for e in g.enemies:
			if e.dead or e.type == "fist" or e.static or (e.mode == "idle" and not e.force):
				continue
			if e.pos.distance_to(c.pos) < float(e.r) + reach_add:
				_damage(c, float(g.ENEMY[e.type].dmg) * 0.5, e.pos)
				return
	for pr in g.projs:
		if pr.team == "enemy" and pr.life > 0.0 and pr.pos.distance_to(c.pos) < 0.9:
			pr.life = 0.0
			_damage(c, maxf(float(pr.dmg) * 0.5, 6.0), pr.pos)
			return


func _walk(fig: Dictionary, ph: float, amt: float) -> void:
	fig.legs[0].rotation.x = sin(ph) * 0.6 * amt
	fig.legs[1].rotation.x = -sin(ph) * 0.6 * amt
	fig.knees[0].rotation.x = -maxf(0.0, cos(ph)) * 0.7 * amt
	fig.knees[1].rotation.x = -maxf(0.0, -cos(ph)) * 0.7 * amt
	fig.arm.rotation = Vector3(-sin(ph) * 0.4 * amt + 0.1, 0.0, 0.0)
	fig.larm.rotation = Vector3(sin(ph) * 0.4 * amt + 0.1, 0.0, 0.0)
	fig.elbow.rotation.x = 0.3
	fig.lelbow.rotation.x = 0.3
	fig.body.rotation = Vector3(0.05 * amt, 0.0, 0.0)
	fig.body.position.y = 1.0


## Crouched, shaking, arms over the head.
func _huddle(fig: Dictionary, t: float) -> void:
	var tremble := sin(t * 28.0) * 0.03
	fig.legs[0].rotation.x = 1.15
	fig.legs[1].rotation.x = 1.0
	fig.knees[0].rotation.x = -1.7
	fig.knees[1].rotation.x = -1.6
	# hands clasped up in front of the chest and face
	fig.arm.rotation = Vector3(1.15 + tremble, 0.6, 0.0)
	fig.larm.rotation = Vector3(1.15 - tremble, 0.6, 0.0)
	fig.elbow.rotation.x = 2.1
	fig.lelbow.rotation.x = 2.1
	fig.body.rotation = Vector3(0.45 + tremble, 0.0, 0.0)
	fig.body.position.y = 0.85
	if fig.has("head"):
		(fig.head as Node3D).rotation = Vector3(0.5, 0.0, 0.0)


## A small health bar and an order tag over every civilian that is still in danger.
func draw_hud() -> void:
	for c in list:
		if not (c.state in ["follow", "stay", "hiding"]):
			continue
		var sp: Vector2 = g._w2s(g._p3(c.pos, 2.5))
		if sp.x < -40 or sp.y < -40 or sp.x > g.hud.size.x + 40 or sp.y > g.hud.size.y + 40:
			continue
		var w := 46.0
		var frac := clampf(float(c.hp) / MAX_HP, 0.0, 1.0)
		var col := Color("8fe0ff") if frac > 0.45 else Color("ff7a5a")
		g.hud.draw_rect(Rect2(sp.x - w * 0.5 - 1, sp.y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
		g.hud.draw_rect(Rect2(sp.x - w * 0.5, sp.y, w * frac, 5), col)
		if c.state != "hiding":
			g._text("STAY" if c.state == "stay" else "FOLLOW", Vector2(sp.x - 40, sp.y - 6), 10, Color(col, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 80, 3)
