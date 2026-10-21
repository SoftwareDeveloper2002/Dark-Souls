extends Node3D
## Open-world night adventure: travel the canyon road through 40 quests, cross the tunnel, find the revolver in the
## labyrinth, beat the four bosses and rescue Princess Elara. Fixed, tilted MOBA-style camera.

const UI := preload("res://scripts/ui.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Models := preload("res://scripts/models.gd")
const Quests := preload("res://scripts/quests.gd")
const World := preload("res://scripts/world.gd")
const Save := preload("res://scripts/save.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Fx := preload("res://scripts/fx.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Shop := preload("res://scripts/shop.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Bosses := preload("res://scripts/bosses.gd")
const BossTalk := preload("res://scripts/boss_talk.gd")
const Vox := preload("res://scripts/vox.gd")
const Projectiles := preload("res://scripts/projectiles.gd")
const Forest := preload("res://scripts/forest.gd")
const Execution := preload("res://scripts/execution.gd")
const Comic := preload("res://scripts/comic.gd")
const Civilians := preload("res://scripts/civilians.gd")
const Torch := preload("res://scripts/torch.gd")
const MapView := preload("res://scripts/map_view.gd")
const Emblems := preload("res://scripts/emblems.gd")
const Structures := preload("res://scripts/structures.gd")
const Portraits := preload("res://scripts/portraits.gd")
const A := "res://demo/assets/"  # assets reused from the Terrain3D demo
const CAM_OFFSET := Vector3(0, 17.2, 12.4)  # ~54 degree pitch, looking "north"
const ARENA_FLAT := 30.0
const ARENA_BLEND := 26.0
const ARENA_R := 34.0
const CAMP_RANGE := 85.0     # camp appears when the player is this close
const ARRIVE_RANGE := 26.0   # objective starts when the player is this close
const BONE := Color("d9cfb8")
const EMBER := Color("e8892b")
const GOLD := Color("8a7a55")

const ENEMY := {
	"hollow": {"hp": 45.0, "speed": [3.1, 3.9], "dmg": 14.0, "r": 0.7, "reach": 1.9, "wind": 0.55, "rec": 0.7, "souls": 20, "name": "HOLLOW SOLDIER", "ai": "melee"},
	"zombie": {"hp": 75.0, "speed": [1.7, 2.3], "dmg": 15.0, "r": 0.75, "reach": 1.9, "wind": 0.9, "rec": 0.9, "souls": 24, "name": "ZOMBIE", "ai": "melee"},
	"ghoul": {"hp": 55.0, "speed": [4.2, 4.8], "dmg": 18.0, "r": 0.7, "reach": 2.3, "wind": 0.45, "rec": 0.6, "souls": 34, "name": "GHOUL", "ai": "melee", "lunge": 9.0},
	"skeleton": {"hp": 60.0, "speed": [3.0, 3.6], "dmg": 16.0, "r": 0.7, "reach": 2.0, "wind": 0.5, "rec": 0.65, "souls": 26, "name": "SKELETON", "ai": "melee"},
	"archer": {"hp": 34.0, "speed": [2.8, 3.2], "dmg": 12.0, "r": 0.7, "wind": 0.8, "souls": 28, "name": "HOLLOW ARCHER", "ai": "ranged", "range": 9.0, "proj": "arrow", "cd": 2.4},
	"mage": {"hp": 40.0, "speed": [2.6, 3.0], "dmg": 18.0, "r": 0.7, "wind": 0.9, "souls": 40, "name": "CULTIST MAGE", "ai": "ranged", "range": 10.0, "proj": "magic", "cd": 2.8},
	"imp": {"hp": 30.0, "speed": [3.4, 3.9], "dmg": 16.0, "r": 0.6, "wind": 0.7, "souls": 32, "name": "IMP", "ai": "ranged", "range": 9.5, "proj": "fire", "cd": 2.2, "fly": 2.0},
	"fiend": {"hp": 150.0, "speed": [3.0, 3.4], "dmg": 26.0, "r": 1.0, "reach": 2.8, "wind": 0.75, "rec": 0.8, "souls": 70, "name": "FIEND", "ai": "melee", "lunge": 6.0},
	"hound": {"hp": 50.0, "speed": [5.4, 6.2], "dmg": 14.0, "r": 0.8, "reach": 2.0, "wind": 0.4, "rec": 0.55, "souls": 30, "name": "HELLHOUND", "ai": "melee", "lunge": 10.0},
	"knight": {"hp": 120.0, "speed": [2.3, 2.6], "dmg": 22.0, "r": 0.85, "reach": 2.4, "wind": 0.8, "rec": 0.9, "souls": 50, "name": "HOLLOW KNIGHT", "ai": "melee", "shield": true},
	"stonesoldier": {"hp": 95.0, "speed": [2.4, 2.8], "dmg": 20.0, "r": 0.85, "reach": 4.0, "wind": 0.7, "rec": 0.8, "souls": 45, "name": "STONE SOLDIER", "ai": "melee"},
	"brute": {"hp": 260.0, "speed": [1.9, 2.2], "dmg": 34.0, "r": 1.1, "reach": 2.9, "wind": 1.0, "rec": 1.2, "souls": 80, "name": "BRUTE", "ai": "melee"},
	"captain": {"hp": 380.0, "speed": [2.8, 3.0], "dmg": 28.0, "r": 1.0, "reach": 2.8, "wind": 0.7, "rec": 0.8, "souls": 200, "name": "CAPTAIN", "ai": "melee", "shield": true},
	"demon": {"hp": 1000.0, "speed": [2.9, 2.9], "dmg": 38.0, "r": 1.7, "reach": 3.1, "wind": 0.95, "rec": 1.1, "souls": 1500, "name": "ASYLUM DEMON", "ai": "boss"},
	"serpent": {"hp": 2000.0, "speed": [3.4, 3.4], "dmg": 34.0, "r": 1.4, "reach": 3.2, "wind": 0.8, "rec": 0.9, "souls": 4000, "name": "SERPENT QUEEN", "ai": "boss"},
	"cyborg": {"hp": 3500.0, "speed": [2.0, 2.0], "dmg": 42.0, "r": 4.5, "reach": 0.0, "wind": 1.0, "rec": 1.0, "souls": 6500, "name": "CYBORG TITAN", "ai": "boss"},
	"malakar": {"hp": 30000.0, "speed": [3.3, 3.3], "dmg": 48.0, "r": 1.8, "reach": 3.6, "wind": 0.9, "rec": 0.9, "souls": 12000, "name": "LORD MALAKAR", "ai": "boss"},
	"fist": {"hp": 1.0, "speed": [0.0, 0.0], "dmg": 0.0, "r": 2.6, "reach": 0.0, "wind": 1.0, "rec": 1.0, "souls": 0, "name": "TITAN FIST", "ai": "fist"},
}
const BOSS := {
	"demon": {"slam_r": 5.5, "sweep_len": 5.8, "phases": [0.5]},
	"serpent": {"slam_r": 5.2, "sweep_len": 6.0, "phases": [0.5]},
	"cyborg": {"slam_r": 5.0, "sweep_len": 0.0, "phases": [0.5]},
	"malakar": {"slam_r": 7.0, "sweep_len": 7.5, "phases": [0.66, 0.33]},
}
const CH_COLORS := [Color("8a1c14"), Color("2a6a4a"), Color("6a8ac0"), Color("5a0a14")]
const PORTRAIT_OF := {"ELARA": "princess", "ASYLUM DEMON": "demon", "SERPENT QUEEN": "serpent", "CYBORG TITAN": "cyborg", "MALAKAR": "malakar"}

var state := "play"  # play | dead | win | leaving
var paused := false
var t := 0.0
var end_timer := 0.0

# player (logic on the XZ plane: Vector2.x -> world X, Vector2.y -> world Z)
var p_pos := Vector2.ZERO
var p_r := 0.7
var p_face := -PI / 2.0
var p_hp := 100.0
var p_max_hp := 100.0
var hp_trail := 100.0
var p_st := 100.0
var p_max_st := 100.0
var p_st_delay := 0.0
var p_act := "idle"  # idle | block | roll | attack | shoot | drink | spin | cast | dead
var p_act_t := 0.0
var p_hit_done := false
var p_hit2 := false
var p_atk := {"anim": "slash_r", "dmg": 1.0, "range": 1.0, "arc": 1.0, "stam": 1.0, "lunge": 1.0, "time": 0.42, "hit_t": 0.14, "kb": 1.0}
var p_combo := -1       # index of the last strike in the chain
var p_combo_win := 0.0  # seconds left to chain the next strike
var p_hit_i := 0        # strikes of the current attack already landed
var p_block := 0.0      # 0..1 how far the shield is raised
var p_block_t := 0.0    # seconds the guard has been up (first moments parry)
var p_shield_hit := 0.0 # shield recoil after taking a blow
var p_hit_t := 0.0      # flinch timer after being wounded
var p_hit_dir := 0.0    # side the last wound came from (-1 left .. 1 right)
var p_drip := 0.0
var blood_drips: Array = []
var splats: Array = []
var splat_tex: GradientTexture2D
var blood_vig: GradientTexture2D
var p_roll_dir := 0.0
var p_inv := 0.0
var p_stun := 0.0
var p_stone := 0.0
var p_flash := 0.0
var p_since_hit := 0.0
var p_move_speed := 0.0
var p_gun_cd := 0.0
var walk_phase := 0.0
var has_weapon := false

# gear
var weapons_owned := {"sword": true, "cleaver": false, "spear": false, "gun": false}
var wtier := {"sword": 0, "cleaver": 0, "spear": 0, "gun": 0}
var equipped := "sword"
var ammo := 0
var armors_owned := {"ashen": true, "demon": false, "serpent": false, "cyborg": false}
var armor := "ashen"

# progression
var quest_n := 1
var q: Dictionary = {}
var site := Vector2.ZERO
var q_arrived := false
var camp_spawned := false
var q_active := false
var q_kills := 0
var q_spawned := 0
var q_timer := 0.0
var q_cd := 0.0
var q_boss_dead := false
var q_elite_dead := false
var q_maze_done := false
var q_done := false
var q_done_t := 0.0
var q_stage := ""
var keys := 0
var skills := Weapons.fresh_skills()  # weapon id -> [slot a, slot b], each {"u": unlocked, "l": level}
var cds := Weapons.fresh_cds()        # weapon id -> [cooldown a, cooldown b]
var civilians: Civilians
var _maze_fail_t := -1.0
var torch: Torch
var maze_k := 0.0                     # 0 = top-down view, 1 = third-person view inside the labyrinth
var _look_hold := 0.0
var _iv_screen := Vector2.ZERO
var p_rage := 0.0                     # seconds of Blood Rage left
var p_skl := 0                        # level of the skill being played
var p_hit_list: Array = []            # uids already hit by the current dash
var _rage_mat: StandardMaterial3D
var lv := {"attack": 0, "vigor": 0, "endurance": 0, "defense": 0, "mobility": 0, "regen": 0, "potency": 0}
var souls := 0
var lost_souls := 0
var flasks := 3
var chapter_shown := -1
var arena_active := false
var bridge_active := false
var away_warn := 0.0
var moon_base := 0.9
var cam_zoom := 1.0
var cam_yaw := 0.0
var tunnel_seen := false

var enemies: Array = []
var corpses: Array = []
var wayside: Array = []
var floaters: Array = []
var orbs: Array = []
var projs: Array = []
var zones: Array = []
var shake := 0.0
var banner_text := ""
var banner_sub := ""
var banner_t := 0.0
var tip_t := 0.0

var buf_atk := 0.0
var buf_roll := 0.0
var buf_estus := 0.0
var buf_sk1 := 0.0
var buf_sk2 := 0.0

var cam: Camera3D
var cam_focus := Vector3.ZERO
var hud: Control
var controls
var vignette: GradientTexture2D
var band: GradientTexture2D
var pfig: Dictionary
var M: Models
var fx: Fx
var dialog: Dialogue
var shop: Shop
var bosses: Bosses
var talk: BossTalk
var vox: Vox
var forest: Forest
var exec: Execution
var map_view: MapView
var emblems: Emblems
var unlimited_ammo := false
var proj_art := Projectiles.new()
var _uid_next := 1
var loaded := false  # false while _ready is still building the world over several frames
var _hud_skip := 0
var speeches: Array = []  # boss speech bubbles
var fx_rings: Array = []  # expanding shockwave rings / light pillars
const BOSS_FX := {"demon": Color("ff8a20"), "serpent": Color("50ff80"), "cyborg": Color("30e0ff"), "malakar": Color("ff2040")}
var structures: Structures
var portraits: Portraits
var sword_node: Node3D
var sword_blade: Node3D
var sword_pos := Vector2.ZERO
var embers: CPUParticles3D
var orb_mesh: Mesh
var overlay_layer: CanvasLayer
var settings_root: Control
var pause_root: Control
var arc_mat: StandardMaterial3D
var flash_mat: StandardMaterial3D
var stone_mat: StandardMaterial3D
var terrain
var env: Environment
var moon: DirectionalLight3D
var camp_root: Node3D
var chest: Node3D
var chest_lid: Node3D
var chest_t := -1.0
var cage: Node3D
var princess: Dictionary = {}
var princess_walk := false
var rock_mat: Material
var last_h := 0.0
var _snd := {}
var _pl: Array = []
var _pi := 0
var _skill_sig := ""


func _ready() -> void:
	Music.play("game")
	# loading screen first, so the phone shows progress instead of looking frozen while the world builds
	var load_layer := CanvasLayer.new()
	load_layer.layer = 100
	add_child(load_layer)
	var load_bg := ColorRect.new()
	load_bg.color = Color("050403")
	load_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_layer.add_child(load_bg)
	var load_lbl := Label.new()
	load_lbl.text = "L O A D I N G"
	load_lbl.add_theme_font_size_override("font_size", 30)
	load_lbl.add_theme_color_override("font_color", Color("d9cfb8"))
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_bg.add_child(load_lbl)
	_preload_models()
	await get_tree().process_frame
	await get_tree().process_frame
	M = Models.new()
	arc_mat = M.unshaded(Color.WHITE)
	arc_mat.vertex_color_use_as_albedo = true
	arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	M.arc_mat = arc_mat
	flash_mat = M.unshaded(Color(1, 1, 1, 0.7))
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stone_mat = M.unshaded(Color(0.62, 0.62, 0.6, 0.85))
	stone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	structures = Structures.new()
	structures.setup(self)
	bosses = Bosses.new()
	bosses.setup(self)
	talk = BossTalk.new()
	talk.setup(self)
	vox = Vox.new()
	add_child(vox)
	vox.setup(self)
	exec = Execution.new()
	exec.setup(self)
	civilians = Civilians.new()
	civilians.setup(self)
	torch = Torch.new()
	torch.setup(self)
	portraits = Portraits.new()
	portraits.setup(self)
	load_lbl.text = "L O A D I N G  .  .  ."
	await get_tree().process_frame
	_build_world()
	forest = Forest.new()
	forest.setup(self)
	emblems = Emblems.new()
	emblems.setup(self)
	await get_tree().process_frame
	p_pos = World.start()
	p_face = (World.sword_spot() - p_pos).angle()
	pfig = M.player()
	M.optimize(pfig)
	await get_tree().process_frame
	add_child(pfig.root)
	pfig.sword.visible = false
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.85, 0.9, 1.0)
	pl.light_energy = 1.1
	pl.omni_range = 9.0
	pl.position = Vector3(0, 3.2, 1.0)
	pfig.root.add_child(pl)

	if cam == null:
		_make_camera()
	if terrain != null:
		terrain.set_camera(cam)
	cam_focus = _p3(p_pos)
	cam.look_at_from_position(cam_focus + CAM_OFFSET, cam_focus, Vector3.UP)

	for i in 10:
		var ap := AudioStreamPlayer.new()
		ap.bus = "SFX"
		add_child(ap)
		_pl.append(ap)
	for n in ["hit", "swing", "hurt", "chime", "potion", "roar"]:
		_snd[n] = Sfx.make(n)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.draw.connect(_draw_hud)

	controls = TouchControls.new()
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.attack_pressed.connect(func(): buf_atk = 0.25)
	controls.roll_pressed.connect(func(): buf_roll = 0.25)
	controls.estus_pressed.connect(func(): buf_estus = 0.25)
	controls.skill1_pressed.connect(func(): buf_sk1 = 0.25)
	controls.torch_pressed.connect(func(): torch.toggle())
	controls.cmd_pressed.connect(func(): civilians.command_toggle())
	controls.look_dragged.connect(func(dx: float):
		if maze_k > 0.3:
			cam_yaw -= dx * 0.006
			_look_hold = 1.2)
	controls.skill2_pressed.connect(func(): buf_sk2 = 0.25)
	controls.swap_pressed.connect(cycle_weapon)
	controls.pause_pressed.connect(_toggle_pause)
	controls.map_pressed.connect(_toggle_map)
	controls.flasks = flasks

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)
	map_view = MapView.new()
	map_view.setup(self)
	overlay_layer.add_child(map_view)
	shop = Shop.new()
	shop.build(self, overlay_layer)
	shop.on_continue = _close_shop
	dialog = Dialogue.new()
	dialog.build(overlay_layer)
	dialog.portrait_for = func(speaker: String):
		if PORTRAIT_OF.has(speaker):
			return portraits.get_tex(PORTRAIT_OF[speaker])
		return null
	_build_pause()

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.8)])
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 0.5)
	vignette.width = 256
	vignette.height = 256
	var gb := Gradient.new()
	gb.offsets = PackedFloat32Array([0.35, 0.75, 1.0])
	gb.colors = PackedColorArray([Color(0.45, 0, 0, 0), Color(0.5, 0.02, 0.02, 0.45), Color(0.28, 0, 0, 0.95)])
	blood_vig = GradientTexture2D.new()
	blood_vig.gradient = gb
	blood_vig.fill = GradientTexture2D.FILL_RADIAL
	blood_vig.fill_from = Vector2(0.5, 0.5)
	blood_vig.fill_to = Vector2(1.0, 0.5)
	blood_vig.width = 256
	blood_vig.height = 256
	var gs := Gradient.new()
	gs.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gs.colors = PackedColorArray([Color(0.32, 0.0, 0.0, 0.9), Color(0.22, 0.0, 0.0, 0.7), Color(0.12, 0, 0, 0)])
	splat_tex = GradientTexture2D.new()
	splat_tex.gradient = gs
	splat_tex.fill = GradientTexture2D.FILL_RADIAL
	splat_tex.fill_from = Vector2(0.5, 0.5)
	splat_tex.fill_to = Vector2(1.0, 0.5)
	splat_tex.width = 64
	splat_tex.height = 64
	var g2 := Gradient.new()
	g2.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	g2.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.78), Color(0, 0, 0, 0.78), Color(0, 0, 0, 0)])
	band = GradientTexture2D.new()
	band.gradient = g2
	band.fill = GradientTexture2D.FILL_LINEAR
	band.fill_from = Vector2(0, 0.5)
	band.fill_to = Vector2(1, 0.5)
	band.width = 256
	band.height = 4

	fx = Fx.new()
	fx.setup(self, env)
	_apply_chapter(0)

	recalc()
	p_hp = p_max_hp
	p_st = p_max_st
	hp_trail = p_hp
	if Save.continue_game and Save.has_save():
		_load()
	else:
		Save.wipe()
		_set_controls(false)
		dialog.say(Quests.INTRO, func():
			_set_controls(true)
			_show_banner("FIND A WEAPON", 3.5))
	Save.continue_game = false
	style_weapon()
	apply_gear_visuals()
	refresh_skill_buttons()
	refresh_weapon_ui()
	load_lbl.text = "L O A D I N G   .  .  .  ."
	Settings.apply_to(self)
	forest.prime(_p3(p_pos), 40)
	map_view.build_relief()
	await get_tree().process_frame
	await _warm_up()
	Settings.apply_to(self)
	Settings.changed.connect(func():
		Settings.apply_to(self)
		_apply_enemy_shadows())
	load_layer.queue_free()
	loaded = true


# ------------------------------------------------------------- terrain helpers

func _h(p: Vector2) -> float:
	if structures.on_bridge(p):
		return float(structures.bridge.base)
	var v: float = terrain.data.get_height(Vector3(p.x, 0, p.y))
	if is_nan(v):
		return last_h
	last_h = v
	return v


func _p3(p: Vector2, dy: float = 0.0) -> Vector3:
	return Vector3(p.x, _h(p) + dy, p.y)


func _walk_ok(p: Vector2) -> bool:
	var v: float = terrain.data.get_height(Vector3(p.x, 0, p.y))
	return not is_nan(v) and absf(v) > 0.0001


## Moves `pos` by `delta`, refusing steep cliffs and solid walls (slides along them instead).
func _slide(pos: Vector2, delta: Vector2) -> Vector2:
	if delta.length_squared() < 1e-10:
		return pos
	var h0 := _h(pos)
	var stuck_in_wall := structures.wall_hit(pos, 0.5)
	for d in [delta, Vector2(delta.x, 0.0), Vector2(0.0, delta.y)]:
		var dl: float = d.length()
		if dl < 1e-6:
			continue
		var look: Vector2 = pos + d / dl * maxf(dl, 0.6)
		if not _walk_ok(look):
			continue
		if not stuck_in_wall and structures.wall_hit(look, 0.5):
			continue
		if absf(_h(look) - h0) / pos.distance_to(look) > 0.85:
			continue
		return pos + d
	return pos


func _contain(p: Vector2) -> Vector2:
	if bridge_active:
		return structures.bridge_clamp(p)
	if arena_active:
		var v := p - site
		if v.length() > ARENA_R:
			return site + v.normalized() * ARENA_R
	return p


func _move_e(e: Dictionary, delta: Vector2) -> void:
	if e.static:
		return
	e.pos = _contain(_slide(e.pos, delta))


var _flatten_busy := false


## Levels a SQUARE of ground (half-size `half`) with a soft border, a few hundred points per frame so it never stalls the game.
func _flatten_async(center: Vector2, half: float, blend: float) -> void:
	_flatten_busy = true
	var d = terrain.data
	var base := _h(center)
	var reach := half + blend
	var done := 0
	for xi in range(int(center.x - reach), int(center.x + reach) + 1):
		for zi in range(int(center.y - reach), int(center.y + reach) + 1):
			var off := Vector2(absf(xi - center.x), absf(zi - center.y))
			var edge: float = maxf(off.x, off.y)
			var v := Vector3(xi, 0, zi)
			if edge <= half:
				d.set_height(v, base)
			else:
				var h: float = d.get_height(v)
				if not is_nan(h):
					d.set_height(v, lerpf(base, h, smoothstep(half, reach, edge)))
			done += 1
		if done > 700:
			done = 0
			await get_tree().process_frame
	d.update_maps(0)
	_flatten_busy = false


func _flatten(center: Vector2, flat_r: float, blend_r: float) -> void:
	var d = terrain.data
	var base := _h(center)
	var r_all := flat_r + blend_r
	for xi in range(int(center.x - r_all), int(center.x + r_all) + 1):
		for zi in range(int(center.y - r_all), int(center.y + r_all) + 1):
			var dist := Vector2(xi, zi).distance_to(center)
			if dist > r_all:
				continue
			var v := Vector3(xi, 0, zi)
			var h: float = d.get_height(v)
			if is_nan(h):
				continue
			d.set_height(v, lerpf(base, h, smoothstep(flat_r, r_all, dist)))
	d.update_maps(0)  # Terrain3DRegion.TYPE_HEIGHT


# ------------------------------------------------------------- world build

func _mat(col: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
	return M.mat(col, rough, emit)


func _unshaded(col: Color) -> StandardMaterial3D:
	return M.unshaded(col)


func _mesh(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _sphere(r: float, mat: Material = null) -> SphereMesh:
	var s := M.sphere(r)
	if mat != null:
		s.material = mat
	return s


func _cyl(r: float, h: float) -> CylinderMesh:
	return M.cone(r, r, h, 24)


func _aabb_of(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## Instances a demo-asset model at a world XZ, scaled to `height`, sitting on the terrain.
func _place_model(path: String, mat: Material, xz: Vector2, height: float, yaw: float, parent: Node, squash: Vector3 = Vector3.ONE) -> Node3D:
	var res = load(A + path)
	if res == null:
		return null
	var inst: Node3D = res.instantiate()
	parent.add_child(inst)
	var bb := _aabb_of(inst)
	bb.position -= inst.global_position  # measure relative to where it was added, not the world origin
	var s := height / maxf(bb.size.y, 0.001)
	inst.scale = Vector3(s, s, s) * squash
	inst.rotation.y = yaw
	inst.global_position = Vector3(xz.x, -bb.position.y * s * squash.y + _h(xz) - height * 0.05, xz.y)
	if mat != null:
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
	return inst


## Realistic CC0 prop (Poly Haven glTF) set on the terrain at xz, scaled so its largest dimension equals size. Returns null if the file is missing.
func _prop(id: String, xz: Vector2, size: float, yaw: float, parent: Node) -> Node3D:
	var path := "res://assets/models/polyhaven/%s/%s_1k.gltf" % [id, id]
	if not ResourceLoader.exists(path):
		path = "res://assets/models/opengameart/%s/%s.glb" % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	var inst: Node3D = (res as PackedScene).instantiate()
	parent.add_child(inst)
	var bb := _aabb_of(inst)
	bb.position -= inst.global_position  # measure relative to where it was added, not the world origin
	var k := size / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	inst.scale = Vector3.ONE * k
	inst.rotation.y = yaw
	inst.global_position = Vector3(xz.x, -bb.position.y * k + _h(xz) - size * 0.02, xz.y)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in m3.mesh.get_surface_count():
			var sm = m3.mesh.surface_get_material(si)
			if sm is StandardMaterial3D:
				var dm: StandardMaterial3D = (sm as StandardMaterial3D).duplicate()
				dm.metallic = minf(dm.metallic, 0.3)
				m3.set_surface_override_material(si, dm)
	return inst


## The camera exists before the world does: Terrain3D shuts its update loop down if it cannot find one.
func _make_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.top_level = true
	add_child(cam)
	cam.current = true
	if terrain != null:
		terrain.set_camera(cam)


func _setup_terrain() -> void:
	var demo = load("res://demo/Demo.tscn").instantiate()
	terrain = demo.get_node("Terrain3D")
	demo.remove_child(terrain)
	demo.free()
	var parts = terrain.get_node_or_null("Terrain3DParticles")
	if parts != null:
		terrain.remove_child(parts)
		parts.free()
	terrain.collision_mode = 0  # engine collision is never used (movement is script-driven): saves a lot of CPU
	add_child(terrain)
	_make_camera()


func _build_world() -> void:
	# --- night sky / light: demo Environment component, retuned for night ---
	var envn: Node3D = load("res://demo/components/Environment.tscn").instantiate()
	add_child(envn)
	env = envn.get_node("WorldEnvironment").environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = Color("02030a")
	sky_mat.sky_horizon_color = Color("0b1233")
	sky_mat.ground_bottom_color = Color("010206")
	sky_mat.ground_horizon_color = Color("0b1233")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.32, 0.5)
	env.ambient_light_energy = 1.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.09)
	env.fog_density = 0.012
	moon = envn.get_node("DirectionalLight3D")
	moon.rotation_degrees = Vector3(-58, -35, 0)
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.9
	moon.directional_shadow_max_distance = 70.0

	_setup_terrain()
	rock_mat = load(A + "materials/M_rock23_tp.tres")
	structures.build_tunnel()

	# starting bonfire + the weapon waiting on the road
	camp_root = _make_bonfire(World.start() + Vector2(-4, 2))
	sword_pos = World.sword_spot()
	sword_node = Node3D.new()
	sword_node.position = _p3(sword_pos)
	add_child(sword_node)
	if _place_model("models/RockA.glb", rock_mat, sword_pos, 1.0, 0.6, sword_node, Vector3(2.4, 1.0, 2.4)) == null:
		var rock := _mesh(_sphere(0.8), _mat(Color("2c2a33"), 1.0), Vector3(0, 0.1, 0), sword_node)
		rock.scale = Vector3(1.0, 0.4, 1.0)
	sword_blade = Node3D.new()
	sword_node.add_child(sword_blade)
	var gold := _mat(Color("f2d27a"), 0.3, 1.6)
	var bl := BoxMesh.new()
	bl.size = Vector3(0.16, 2.2, 0.05)
	_mesh(bl, gold, Vector3(0, 1.4, 0), sword_blade)
	var gd := BoxMesh.new()
	gd.size = Vector3(0.8, 0.12, 0.12)
	_mesh(gd, _mat(Color("8a6a3a"), 0.4), Vector3(0, 0.3, 0), sword_blade)
	var bm2 := _unshaded(Color(1.0, 0.85, 0.4, 0.14))
	bm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(_cyl(0.3, 14.0), bm2, Vector3(0, 7.0, 0), sword_node)
	var sl := OmniLight3D.new()
	sl.light_color = Color("ffd98a")
	sl.light_energy = 2.5
	sl.omni_range = 9.0
	sl.position = Vector3(0, 1.6, 0)
	sword_node.add_child(sl)

	embers = CPUParticles3D.new()
	embers.amount = 90
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(24, 0.1, 18)
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	embers.gravity = Vector3(0.2, 0.2, 0)
	embers.mesh = _sphere(0.05, _unshaded(EMBER))
	add_child(embers)

	orb_mesh = load(A + "meshes/Gem.obj")


## A little campfire with stones, flames and a light.
func _make_bonfire(c: Vector2, real: bool = false) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _p3(c)
	var stone := _mat(Color("2b2a33"), 1.0)
	var pit: Node3D = _prop("stone_fire_pit", c, 1.8, 0.0, root) if real else null
	for i in 8 if pit == null else 0:
		var a := float(i) / 8.0 * TAU
		var sm := BoxMesh.new()
		sm.size = Vector3(0.45, 0.35, 0.45)
		var s := _mesh(sm, stone, Vector3(cos(a), 0.17, sin(a)) * 1.1, root)
		s.rotation.y = a
	_mesh(_sphere(0.55), _mat(Color("ff8a2a"), 0.5, 2.5), Vector3(0, 0.3, 0), root)
	var flame := CPUParticles3D.new()
	flame.amount = 36
	flame.lifetime = 0.9
	flame.direction = Vector3.UP
	flame.spread = 14.0
	flame.initial_velocity_min = 1.2
	flame.initial_velocity_max = 2.8
	flame.gravity = Vector3.ZERO
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.5
	flame.mesh = _sphere(0.17, _unshaded(Color("ffb347")))
	flame.position = Vector3(0, 0.5, 0)
	root.add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a40")
	l.omni_range = 16.0
	l.light_energy = 3.0
	l.position = Vector3(0, 1.6, 0)
	l.set_meta("fire", true)
	root.add_child(l)
	return root


## Weathered canvas A-frame tent: patched canvas, ridge pole, dark doorway, stakes, a faction-coloured trim strip.
func _make_tent(p: Vector2, yaw: float, faction: Color, parent: Node3D) -> void:
	if _prop("medieval_tent", p, 3.6, yaw, parent) != null:
		return
	var t := Node3D.new()
	parent.add_child(t)
	t.global_position = _p3(p)
	t.rotation.y = yaw
	var canvas := _mat(Color("9a8b6c").lerp(faction, 0.12).darkened(0.15), 0.98)
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := _mat(Color("3a2616"), 0.9)
	var dark := _mat(Color("0d0b0a"), 1.0)
	var trim := _mat(faction.darkened(0.2), 0.9)
	var w := 2.6
	var h := 1.9
	var tlen := 3.2
	var roof := PrismMesh.new()
	roof.size = Vector3(w, h, tlen)
	_mesh(roof, canvas, Vector3(0, h * 0.5 - 0.05, 0), t)
	# doorway on the front gable
	var door := PrismMesh.new()
	door.size = Vector3(w * 0.42, h * 0.62, 0.05)
	_mesh(door, dark, Vector3(0, h * 0.31 - 0.05, tlen * 0.5 + 0.02), t)
	# trim band along each eave and ridge pole sticking out past the gables
	for s in [-1.0, 1.0]:
		var band := _mesh(M.box(0.08, 0.06, tlen), trim, Vector3(s * (w * 0.5 - 0.02), 0.02, 0), t)
		band.rotation.z = 0.0
	var ridge := _mesh(_cyl(0.05, tlen + 0.7), wood, Vector3(0, h - 0.05, 0), t)
	ridge.rotation.x = PI * 0.5
	for zs in [-1.0, 1.0]:
		_mesh(_cyl(0.05, h), wood, Vector3(0, h * 0.5 - 0.05, zs * (tlen * 0.5 + 0.3)), t)
		for xs in [-1.0, 1.0]:
			var stake := _mesh(_cyl(0.025, 0.35), wood, Vector3(xs * (w * 0.5 + 0.45), 0.1, zs * tlen * 0.4), t)
			stake.rotation.z = -xs * 0.5


## Camp / outpost for a quest site: bonfire, tents, crates, banners, rocks (+ arena ring for bosses).
func _build_camp(c: Vector2, ch: int, boss: bool) -> Node3D:
	var root := _make_bonfire(c, true)
	var cloth := _mat(Color(CH_COLORS[ch]).darkened(0.35), 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := _mat(Color("3a2616"), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = quest_n * 97 + 5
	for i in _cnt(3):
		var a := rng.randf() * TAU
		var p := c + Vector2.from_angle(a) * rng.randf_range(6.0, 9.0)
		if structures.wall_hit(p, 2.0):
			continue
		_make_tent(p, rng.randf() * TAU, Color(CH_COLORS[ch]), root)
	for i in _cnt(5):
		var p2 := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.5, 9.0)
		if structures.wall_hit(p2, 1.0):
			continue
		var yaw2 := rng.randf() * TAU
		var pick := i % 5
		var got: Node3D = null
		if pick == 0 or pick == 3:
			got = _prop("wooden_crate_01" if pick == 0 else "wooden_crate_02", p2, 0.95, yaw2, root)
		elif pick == 1:
			got = _prop("wooden_barrels_01", p2, 1.6, yaw2, root)
		elif pick == 2:
			got = _prop("treasure_chest", p2, 0.95, yaw2, root)
		else:
			got = _prop("wicker_basket_01" if i % 2 == 0 else "wooden_bucket_01", p2, 0.7 if i % 2 == 0 else 0.5, yaw2, root)
		if got == null:
			var crate := _mesh(M.box(0.9, 0.8, 0.9), wood, Vector3.ZERO, root)
			crate.global_position = Vector3(p2.x, _h(p2) + 0.4, p2.y)
			crate.rotation.y = yaw2
	for i in _cnt(3):
		var p3 := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(9.0, 13.0)
		if structures.wall_hit(p3, 1.5):
			continue
		var pole := _mesh(_cyl(0.07, 4.5), wood, Vector3.ZERO, root)
		pole.global_position = Vector3(p3.x, _h(p3) + 2.25, p3.y)
		var bar := _mesh(M.box(1.2, 0.06, 0.06), wood, Vector3.ZERO, root)
		bar.global_position = Vector3(p3.x + 0.6, _h(p3) + 4.2, p3.y)
		var flag := _mesh(M.box(0.9, 1.5, 0.02), cloth, Vector3.ZERO, root)
		flag.global_position = Vector3(p3.x + 0.6, _h(p3) + 3.43, p3.y)
	if ch == 1 or ch == 3:
		var bone_mat := _mat(Color("d8d2b8"), 0.8)
		for i in _cnt(4):
			var p4 := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 15.0)
			if structures.wall_hit(p4, 1.5):
				continue
			var stick := _mesh(_cyl(0.05, 2.0), wood, Vector3.ZERO, root)
			stick.global_position = Vector3(p4.x, _h(p4) + 1.0, p4.y)
			var skull := _mesh(_sphere(0.25), bone_mat, Vector3.ZERO, root)
			skull.global_position = Vector3(p4.x, _h(p4) + 2.1, p4.y)
	for i in _cnt(2):
		var ps := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 7.0)
		if not structures.wall_hit(ps, 1.0):
			_prop("tree_stump_01", ps, 0.9, rng.randf() * TAU, root)
			_prop("hatchet", ps + Vector2(0.15, 0.1), 0.7, rng.randf() * TAU, root)
	for i in _cnt(3):
		var pd := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(14.0, 22.0)
		if _walk_ok(pd) and not structures.wall_hit(pd, 2.0):
			_prop("dead_tree_trunk" if i % 2 == 0 else "dead_tree_trunk_02", pd, rng.randf_range(4.0, 6.5), rng.randf() * TAU, root)
	var pl := c + Vector2.from_angle(rng.randf() * TAU) * 2.6
	var lant := _prop("wooden_lantern_01", pl, 0.8, rng.randf() * TAU, root)
	if lant != null:
		var ll := OmniLight3D.new()
		ll.light_color = Color("ffb060")
		ll.omni_range = 7.0
		ll.light_energy = 1.2
		ll.position = Vector3(0, 0.5, 0)
		lant.add_child(ll)
	var rocks := ["models/RockA.glb", "models/RockB.glb", "models/RockC.glb"]
	for i in _cnt(4):
		var p5 := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(11.0, 20.0)
		if _walk_ok(p5) and not structures.wall_hit(p5, 2.0):
			_place_model(rocks[rng.randi() % 3], rock_mat, p5, rng.randf_range(0.8, 2.2), rng.randf() * TAU, root)
	if boss:
		for i in 16:
			if Settings.quality <= 1 and i % 2 == 1:
				continue
			var a2 := float(i) / 16.0 * TAU
			var pp := c + Vector2.from_angle(a2) * (ARENA_R + 1.5)
			if _place_model(["models/RockA.glb", "models/RockB.glb", "models/RockC.glb"][i % 3], rock_mat, pp, rng.randf_range(4.5, 6.5), rng.randf() * TAU, root) == null:
				var pil := _mesh(M.cone(0.9, 1.15, 5.0, 10), rock_mat, Vector3.ZERO, root)
				pil.global_position = Vector3(pp.x, _h(pp) + 2.4, pp.y)
			if i % 4 == 0:
				var fl := CPUParticles3D.new()
				fl.amount = 16
				fl.lifetime = 0.7
				fl.direction = Vector3.UP
				fl.spread = 12.0
				fl.initial_velocity_min = 0.8
				fl.initial_velocity_max = 1.6
				fl.gravity = Vector3.ZERO
				fl.mesh = _sphere(0.12, _unshaded(Color(CH_COLORS[ch]).lightened(0.4)))
				root.add_child(fl)
				fl.global_position = Vector3(pp.x, _h(pp) + 5.3, pp.y)
	return root


func _apply_chapter(ch: int) -> void:
	if chapter_shown == ch:
		return
	chapter_shown = ch
	var c: Dictionary = Quests.CHAPTERS[ch]
	moon.light_color = c.moon
	moon_base = float(c.moon_e)
	moon.light_energy = moon_base
	fx.set_chapter(c)


# ------------------------------------------------------------------ audio

func sfx(name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if name == "roar" and vox != null and pitch < 1.3:
		vox.play_group("crt_roar2" if randf() < 0.5 else "crt_roar", vol + 2.0, clampf(pitch, 0.55, 1.1))
		return
	if not _snd.has(name):
		_snd[name] = Sfx.make(name)
	var p: AudioStreamPlayer = _pl[_pi]
	_pi = (_pi + 1) % _pl.size()
	p.stream = _snd[name]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


# --------------------------------------------------------------- stats & gear

func recalc() -> void:
	var a: Dictionary = Weapons.ARMOR[armor]
	p_max_hp = 100.0 + 12.0 * lv.vigor + float(a.hp)
	p_max_st = 100.0 + 8.0 * lv.endurance + float(a.st)
	p_hp = minf(p_hp, p_max_hp)
	p_st = minf(p_st, p_max_st)


func total_level() -> int:
	var n := 1
	for k in lv:
		n += int(lv[k])
	for id in wtier:
		n += int(wtier[id])
	for id in skills:
		for slot in skills[id]:
			n += int(slot.l) + (1 if slot.u else 0)
	return n


func weapon_dmg() -> float:
	return (Weapons.dmg(equipped, wtier[equipped]) + 3.0 * lv.attack) * (1.5 if p_rage > 0.0 else 1.0)


func move_mult() -> float:
	return (1.0 + 0.03 * lv.mobility + float(Weapons.ARMOR[armor].mob)) * (1.12 if p_rage > 0.0 else 1.0)


func defense_mult() -> float:
	return maxf(0.35, 1.0 - 0.04 * lv.defense - float(Weapons.ARMOR[armor].def))


func style_weapon() -> void:
	var bm: StandardMaterial3D = pfig.blade_mat
	var glow: Color = [Color("cfd6ea"), Color("ffe9a8"), Color("8ab4ff"), Color("ff6a30"), Color("fff2b0")][wtier["sword"]]
	bm.emission_enabled = wtier["sword"] > 0
	bm.emission = glow
	bm.emission_energy_multiplier = 0.5 + 0.35 * wtier["sword"]
	pfig.weapons["sword"].scale = Vector3.ONE * (1.0 + 0.06 * wtier["sword"])


func apply_gear_visuals() -> void:
	M.show_weapon(pfig, equipped)
	M.set_armor(pfig, armor)


func equip_weapon(id: String) -> void:
	if not weapons_owned.get(id, false):
		return
	equipped = id
	apply_gear_visuals()
	refresh_weapon_ui()
	_show_banner(Weapons.weapon_name(id, wtier[id]).to_upper(), 1.4)


func cycle_weapon() -> void:
	var owned: Array = []
	for id in Weapons.ORDER:
		if weapons_owned[id]:
			owned.append(id)
	if owned.size() < 2 or p_act in ["attack", "shoot", "spin", "cast", "quake", "rage", "dash", "flurry", "fan", "blast"]:
		return
	equip_weapon(owned[(owned.find(equipped) + 1) % owned.size()])
	sfx("swing", -8.0, 1.6)


func equip_armor(id: String) -> void:
	if not armors_owned.get(id, false):
		return
	armor = id
	recalc()
	apply_gear_visuals()


func refresh_weapon_ui() -> void:
	var owned := 0
	for id in weapons_owned:
		if weapons_owned[id]:
			owned += 1
	controls.weapon_icon = str(Weapons.W[equipped].icon)
	controls.ammo = -1 if unlimited_ammo else ammo
	controls.can_swap = owned > 1
	refresh_skill_buttons()


func refresh_skill_buttons() -> void:
	var defs: Array = Weapons.SKILLS[equipped]
	controls.skill_unlocked = [skills[equipped][0].u, skills[equipped][1].u]
	controls.skill_ids = [defs[0].id, defs[1].id]
	controls.skill_labels = [defs[0].label, defs[1].label]
	controls.queue_redraw()


func sk_state(slot: int) -> Dictionary:
	return skills[equipped][slot]


func sk_def(slot: int) -> Dictionary:
	return Weapons.SKILLS[equipped][slot]


func _skill_cd_max(slot: int) -> float:
	return maxf(3.0, float(sk_def(slot).cd) - 0.6 * float(sk_state(slot).l))


func _skill_ready(slot: int) -> bool:
	if torch.held:
		return false
	var d: Dictionary = sk_def(slot)
	if not sk_state(slot).u or cds[equipped][slot] > 0.0 or p_st < float(d.st):
		return false
	var need := int(d.get("ammo", 0))
	return need == 0 or unlimited_ammo or ammo >= need


## Turns the hero toward the best enemy in reach before a skill that has a direction.
## True in the labyrinth's third-person view: the hero faces where the camera looks.
func _tp() -> bool:
	return maze_k > 0.3 and not exec.active


func _skill_aim(rng: float) -> void:
	var best = null
	var bd := 1e9
	for e in enemies:
		if e.dead or e.type == "fist" or (e.mode == "idle" and not e.force):
			continue
		var d: float = p_pos.distance_to(e.pos)
		if d > rng:
			continue
		var away: float = absf(angle_difference((e.pos - p_pos).angle(), p_face))
		var score := d + away * 6.0
		if score < bd:
			bd = score
			best = e
	if best != null:
		p_face = (best.pos - p_pos).angle()


func _use_skill(slot: int) -> void:
	var d: Dictionary = sk_def(slot)
	p_st -= float(d.st)
	p_st_delay = 0.7
	cds[equipped][slot] = _skill_cd_max(slot)
	var need := int(d.get("ammo", 0))
	if need > 0 and not unlimited_ammo:
		ammo -= need
		refresh_weapon_ui()
	p_skl = int(sk_state(slot).l)
	p_act = str(d.act)
	p_act_t = 0.0
	p_hit_done = false
	p_hit2 = false
	p_hit_i = 0
	p_hit_list.clear()
	match p_act:
		"spin":
			p_inv = 0.35
			sfx("swing", -2.0, 0.7)
		"cast":
			sfx("roar", -10.0, 1.6)
		"quake":
			_skill_aim(6.0)
			p_inv = 0.8
			sfx("swing", -2.0, 0.5)
			vox.hero_effort(true)
		"rage":
			p_inv = 0.3
			sfx("roar", 0.0, 0.55)
			vox.hero_effort(true)
		"dash":
			_skill_aim(9.0)
			p_inv = 0.6
			sfx("swing", -1.0, 0.6)
			vox.hero_effort(true)
		"flurry":
			_skill_aim(6.0)
			p_inv = 0.2
			sfx("swing", -3.0, 1.2)
		"fan":
			_skill_aim(float(Weapons.W[equipped].range))
			p_gun_cd = 0.8
		"blast":
			_skill_aim(float(Weapons.W[equipped].range))
			p_gun_cd = 0.6
			sfx("chime", -12.0, 1.4)


func _quake_hit() -> void:
	shake = maxf(shake, 24.0)
	fx.pulse(0.6, 0.3)
	_ring(p_pos, Color("ff7a30"), 11.0, 0.7, 0.7, "ring")
	_burst(p_pos, 60, Color("ff7a30"), 12.0, 0.3)
	_burst(p_pos, 30, Color("8a6a4a"), 9.0, 0.4)
	sfx("boom", 2.0, 0.7)
	sfx("hit", 2.0, 0.5)
	var dmg := weapon_dmg() * (1.6 + 0.25 * p_skl)
	for e in enemies:
		if e.dead:
			continue
		var off: Vector2 = e.pos - p_pos
		if off.length() < 5.8 + e.r:
			_hurt_enemy(e, dmg, off.angle(), false, 2.0)


func _dash_hit() -> void:
	var dmg := weapon_dmg() * (1.4 + 0.2 * p_skl)
	for e in enemies:
		if e.dead or p_hit_list.has(e.uid):
			continue
		var off: Vector2 = e.pos - p_pos
		if off.length() < 2.0 + e.r and absf(angle_difference(off.angle(), p_face)) < 1.3:
			p_hit_list.append(e.uid)
			_hurt_enemy(e, dmg, off.angle(), false, 2.5)
			_burst(e.pos, 14, Color("e8dcc0"), 7.0, 1.2)
			shake = maxf(shake, 10.0)
			sfx("hit", -2.0, 0.8)


func _flurry_hit() -> void:
	_skill_aim(6.0)
	var dmg := weapon_dmg() * (0.5 + 0.08 * p_skl)
	sfx("swing", -6.0, randf_range(1.3, 1.7))
	for e in enemies:
		if e.dead:
			continue
		var off: Vector2 = e.pos - p_pos
		if off.length() < 4.2 + e.r and absf(angle_difference(off.angle(), p_face)) < 0.6:
			_hurt_enemy(e, dmg, off.angle(), false, 0.4)
			_burst(e.pos, 5, Color("ffe9b0"), 5.0, 1.3)
	shake = maxf(shake, 3.0)


## The explosive shell: a bright shot that bursts where it lands.
func _fire_shell() -> void:
	var tgt := p_pos + Vector2.from_angle(p_face) * 10.0
	var bd := 16.0
	for e in enemies:
		if e.dead or e.type == "fist" or (e.mode == "idle" and not e.force):
			continue
		var d: float = p_pos.distance_to(e.pos)
		if d < bd and absf(angle_difference((e.pos - p_pos).angle(), p_face)) < 0.5:
			bd = d
			tgt = e.pos
	var travel := maxf(p_pos.distance_to(tgt) / 38.0, 0.12)
	var node: Node3D = proj_art.make("fire")
	add_child(node)
	var from := p_pos + Vector2.from_angle(p_face) * 0.9
	node.global_position = _p3(from, 1.35)
	projs.append({"pos": from, "vel": (tgt - from).normalized() * 38.0, "dmg": 0.0, "life": travel, "node": node, "kind": "fire", "team": "none", "homing": 0.0, "h": 1.35})
	_add_zone(tgt, 3.8, travel, weapon_dmg() * (2.6 + 0.4 * p_skl), "player", {"boom": true})
	shake = maxf(shake, 9.0)
	_burst(from, 10, Color("ffd070"), 5.0, 1.4)
	sfx("bolt", -2.0, 0.8)


func _air_h() -> float:
	if p_act == "quake":
		return sin(clampf(p_act_t / 0.55, 0.0, 1.0) * PI) * 2.4
	return 0.0


func _set_rage(on: bool) -> void:
	if _rage_mat == null:
		_rage_mat = _unshaded(Color(1.0, 0.1, 0.05, 0.28))
		_rage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if on:
		if pfig.meshes.size() > 0 and pfig.meshes[0].material_overlay == null:
			for mi in pfig.meshes:
				mi.material_overlay = _rage_mat
	elif pfig.get("rage_on", false):
		for mi in pfig.meshes:
			if mi.material_overlay == _rage_mat:
				mi.material_overlay = null
	pfig["rage_on"] = on


# ----------------------------------------------------------------- save

func _save() -> void:
	Save.write({"quest": quest_n, "souls": souls, "lv": lv, "skills": skills, "flasks": flasks, "keys": keys,
		"weapons": weapons_owned, "wtier": wtier, "equipped": equipped, "ammo": ammo, "armors": armors_owned, "armor": armor,
		"emblems": emblems.to_array(), "unlimited": unlimited_ammo})


func _load() -> void:
	var d := Save.read()
	quest_n = int(d.get("quest", 1))
	emblems.from_array(d.get("emblems", []))
	unlimited_ammo = bool(d.get("unlimited", false)) or emblems.complete()
	souls = int(d.get("souls", 0))
	var l: Dictionary = d.get("lv", {})
	for k in lv:
		lv[k] = int(l.get(k, 0))
	var sk: Dictionary = d.get("skills", {})
	skills = Weapons.fresh_skills()
	cds = Weapons.fresh_cds()
	if sk.has("w") and sk.get("w") is Dictionary:
		# older saves: whirlwind and thunder belonged to everyone; now they are the sword's skills
		var sw: Dictionary = sk.get("w", {})
		var st: Dictionary = sk.get("t", {})
		skills.sword[0] = {"u": bool(sw.get("u", false)), "l": int(sw.get("l", 0))}
		skills.sword[1] = {"u": bool(st.get("u", false)), "l": int(st.get("l", 0))}
	else:
		for id in skills:
			var arr = sk.get(id, [])
			if arr is Array and arr.size() == 2:
				for i in 2:
					var one: Dictionary = arr[i]
					skills[id][i] = {"u": bool(one.get("u", false)), "l": clampi(int(one.get("l", 0)), 0, 5)}
	var wo: Dictionary = d.get("weapons", {})
	var wt: Dictionary = d.get("wtier", {})
	for id in weapons_owned:
		weapons_owned[id] = bool(wo.get(id, id == "sword"))
		wtier[id] = clampi(int(wt.get(id, 0)), 0, 4)
	if d.has("tier"):
		wtier["sword"] = clampi(int(d.tier), 0, 4)
	equipped = str(d.get("equipped", "sword"))
	if not weapons_owned.get(equipped, false):
		equipped = "sword"
	ammo = int(d.get("ammo", 0))
	var ao: Dictionary = d.get("armors", {})
	for id in armors_owned:
		armors_owned[id] = bool(ao.get(id, id == "ashen"))
	armor = str(d.get("armor", "ashen"))
	if not armors_owned.get(armor, false):
		armor = "ashen"
	flasks = int(d.get("flasks", 3))
	keys = int(d.get("keys", 0))
	controls.flasks = flasks
	refresh_skill_buttons()
	recalc()
	p_hp = p_max_hp
	p_st = p_max_st
	hp_trail = p_hp
	has_weapon = true
	pfig.sword.visible = true
	if sword_node != null:
		sword_node.queue_free()
		sword_node = null
	quest_n = clampi(quest_n, 1, Quests.MAX_QUEST)
	p_pos = World.checkpoint(quest_n)
	cam_focus = _p3(p_pos)
	_begin_quest(quest_n, true, true)


# ---------------------------------------------------------------- menus

func _build_pause() -> void:
	var o := UI.overlay("PAUSED")
	pause_root = o.root
	var box: VBoxContainer = o.box
	var r := UI.button("RESUME", _toggle_pause, 320.0)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(r)
	var sb := UI.button("SETTINGS", func(): settings_root.visible = true, 320.0)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sb)
	var eb := UI.button("WATCH THE EPILOGUE", _preview_epilogue, 320.0)
	eb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(eb)
	var qb := UI.button("QUIT TO TITLE", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"), 320.0)
	qb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(qb)
	pause_root.visible = false
	overlay_layer.add_child(pause_root)
	settings_root = Settings.build_panel(func(): pass)
	overlay_layer.add_child(settings_root)


## Plays the story comic from the pause menu (the same one that follows the ending), then goes back to the game.
func _preview_epilogue() -> void:
	_toggle_pause()
	var prev := state
	state = "epilogue"
	_set_controls(false)
	Comic.new().play(self, func():
		state = prev
		_set_controls(true)
		Music.play("game"))


func _frozen() -> bool:
	return paused or shop.root.visible or dialog.active or (map_view != null and map_view.visible)


func _toggle_map() -> void:
	if state != "play" or shop.root.visible or dialog.active or paused:
		return
	if map_view.visible:
		map_view.close()
		_set_controls(true)
	else:
		map_view.open()
		_set_controls(false)


func _set_controls(on: bool) -> void:
	controls.visible = on
	if not on:
		controls.reset()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == "play" and not paused and not _frozen() and controls != null:
		_toggle_pause()


func _toggle_pause() -> void:
	if state != "play" or shop.root.visible or dialog.active:
		return
	paused = not paused
	pause_root.visible = paused
	_set_controls(not paused)


func _show_banner(text: String, secs: float, sub: String = "") -> void:
	banner_text = text
	banner_sub = sub
	banner_t = secs


func _input(event: InputEvent) -> void:
	if not loaded:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J, KEY_SPACE: buf_atk = 0.25
			KEY_K: buf_roll = 0.25
			KEY_E: buf_estus = 0.25
			KEY_U, KEY_1: buf_sk1 = 0.25
			KEY_I, KEY_2: buf_sk2 = 0.25
			KEY_Q: cycle_weapon()
			KEY_T: torch.toggle()
			KEY_F: civilians.command_toggle()
			KEY_M: _toggle_map()
			KEY_ESCAPE:
				if map_view.visible:
					_toggle_map()
				else:
					_toggle_pause()
	if (state == "dead" or state == "win") and end_timer > 2.2:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			if state == "win":
				# the story goes on as a comic book, then the credits
				state = "epilogue"
				Comic.new().play(self, func():
					Save.wipe()
					state = "leaving"
					get_tree().change_scene_to_file("res://scenes/title.tscn"))
			else:
				_respawn()


# ---------------------------------------------------------------- quests

## Starts quest n: pick its site, prepare wayside encounters, then the player travels there.
func _begin_quest(n: int, intro: bool = true, with_fire: bool = false) -> void:
	quest_n = n
	q = Quests.quest(n)
	site = World.site(n)
	q_active = false
	q_arrived = false
	camp_spawned = false
	arena_active = false
	bridge_active = false
	q_done = false
	q_stage = ""
	q_kills = 0
	q_spawned = 0
	q_timer = 0.0
	q_cd = 0.8
	q_boss_dead = false
	q_elite_dead = false
	q_maze_done = false
	away_warn = 0.0
	_clear_field()
	if with_fire:
		_free_camp()
		camp_root = _make_bonfire(p_pos + Vector2(-3, 2))
	var ch: int = q.ch
	_apply_chapter(ch)
	_prewarm()
	# one-off structures are built on demand (they edit the terrain)
	if n == 27 and structures.maze.is_empty() and not _flatten_busy:
		var tdir := World.dir_at(World.site_index(27))
		structures.build_maze(site, tdir)  # builds itself over the next second or so
	elif n == 30 and structures.bridge.is_empty():
		structures.build_bridge(site, World.dir_at(World.site_index(30)))
	elif q.kind == "boss" and n != 30:
		_flatten(site, ARENA_FLAT, ARENA_BLEND)
	_setup_wayside()
	var lines: Array = []
	if intro and q.idx == 1:
		lines.append_array(Quests.CHAPTER_START[ch])
		var c: Dictionary = Quests.CHAPTERS[ch]
		_show_banner(c.name, 2.8, c.sub)
	if lines.is_empty():
		_set_controls(true)
		if not (intro and q.idx == 1):
			_show_banner("QUEST %d" % quest_n, 2.2, str(q.title).to_upper())
	else:
		_set_controls(false)
		dialog.say(lines, func(): _set_controls(true))


func _free_camp() -> void:
	if camp_root != null:
		camp_root.queue_free()
		camp_root = null


## Builds each model once up front (fills the mesh/material caches) so spawns never hitch.
func _prewarm() -> void:
	var kinds: Array = []
	for e in q.table:
		kinds.append(e[0])
	if q.kind == "boss":
		kinds.append(q.boss)
	if q.kind == "elite":
		kinds.append("captain")
	if quest_n == 20 or quest_n == 40:
		kinds.append("stonesoldier")
	if quest_n >= 40:
		kinds.append("princess")
	if quest_n == 11 or q.kind == "maze":
		kinds.append_array(["zombie", "ghoul", "hound"])
	for k in kinds:
		if ENEMY.has(k) and _fig_pool.get(k, []).is_empty():
			_pool_make(k)


func _setup_wayside() -> void:
	wayside.clear()
	var i1 := World.site_index(quest_n)
	var i0 := World.START_IDX + 6 if quest_n == 1 else World.site_index(quest_n - 1)
	var spots := World.between(i0, i1, 3)
	var ch: int = q.ch
	for sp in spots:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 5.0)
		var p: Vector2 = sp + off
		if not _walk_ok(p) or structures.wall_hit(p, 1.5):
			p = sp
		var kinds: Array = []
		var cnt := 2 + (1 if quest_n > 18 else 0) + (1 if quest_n > 32 else 0)
		for k in cnt:
			kinds.append(_pick_kind_for(ch))
		wayside.append({"pos": p, "kinds": kinds, "members": [], "spawned": false, "done": false})
	if quest_n == 11:
		# the tunnel is full of the dead
		var tr := World.tunnel_range()
		for f in [0.2, 0.5, 0.8]:
			var tp: Vector2 = World.ROUTE[int(lerpf(tr.x, tr.y, f))]
			wayside.append({"pos": tp, "kinds": ["zombie", "ghoul", "zombie", "skeleton"].slice(0, 3), "members": [], "spawned": false, "done": false})


func _pick_kind_for(ch: int) -> String:
	var pool: Array = []
	for e in Quests.POOLS[ch]:
		pool.append(e)
	var tot := 0
	for e in pool:
		tot += int(e[1])
	var r := randi() % maxi(tot, 1)
	for e in pool:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return pool[0][0]


func _update_wayside() -> void:
	for g in wayside:
		if g.done:
			continue
		var d: float = p_pos.distance_to(g.pos)
		if q.get("kind", "") == "boss" and g.pos.distance_to(site) < 52.0:
			g.done = true  # keep boss arenas clear of stray groups
			continue
		if not g.spawned and d < 80.0:
			g.spawned = true
			g.members.clear()
			for k in g.kinds.size():
				var p: Vector2 = g.pos + Vector2.from_angle(float(k) / g.kinds.size() * TAU) * 2.5
				var e := _spawn_enemy(g.kinds[k], p, false, true)
				e.wayside = true
				g.members.append(e)
		elif g.spawned:
			var alive := 0
			var calm := true
			for e in g.members:
				if not e.dead:
					alive += 1
					if e.mode != "idle":
						calm = false
			if alive == 0:
				g.done = true
			elif d > 170.0 and calm:
				for e in g.members:
					_remove_enemy(e)
				g.spawned = false


func _pick_kind() -> String:
	var tot := 0
	for e in q.table:
		tot += int(e[1])
	var r := randi() % maxi(tot, 1)
	for e in q.table:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return q.table[0][0]


## Camp appears when the player gets close: props and the idle enemies guarding the site.
func _spawn_camp() -> void:
	if q.kind == "maze" and structures.maze.is_empty():
		return  # the labyrinth is still being built; try again next frame
	camp_spawned = true
	if q.kind != "maze" and quest_n != 30:
		_free_camp()
		camp_root = _build_camp(site, q.ch, q.kind == "boss")
	match q.kind:
		"kill":
			for i in mini(int(q.target), mini(4 + int(q.ch), Settings.enemy_cap() + 1)):
				_spawn_enemy(_pick_kind(), _spawn_near(site, 5.0, 16.0), true, true)
		"elite":
			_spawn_enemy("captain", site + Vector2(0, -4), true, true)
			for i in 2:
				_spawn_enemy(_pick_kind(), _spawn_near(site, 5.0, 14.0), true, true)
		"maze":
			civilians.spawn(structures.maze.get("civ_spots", []))
			var pts: Array = structures.maze_spawn_points(13, structures.maze.entrance, structures.maze.get("civ_spots", []))
			var kinds := ["zombie", "ghoul", "hound", "skeleton", "ghoul", "fiend", "hound", "zombie", "skeleton", "ghoul", "hound", "fiend", "zombie"]
			for i in pts.size():
				var e := _spawn_enemy(kinds[i % kinds.size()], pts[i], false, true)
				e.wayside = true
		"boss":
			var bpos := site + Vector2(0, -8)
			if quest_n == 30:
				bpos = structures.bridge.boss_pos
			_spawn_enemy(q.boss, bpos, true, true)


func _spawn_near(c: Vector2, rmin: float, rmax: float) -> Vector2:
	var hc := _h(c)
	for i in 16:
		var p := c + Vector2.from_angle(randf() * TAU) * randf_range(rmin, rmax)
		if _walk_ok(p) and absf(_h(p) - hc) < 5.0 and p.distance_to(p_pos) > 9.0 and not structures.wall_hit(p, 0.8):
			return p
	return c + Vector2(rmin, 0)


func _arrive() -> void:
	q_arrived = true
	q_active = true
	for e in enemies:
		if e.quest:
			e.force = true
	if q.kind == "boss":
		if quest_n == 30:
			bridge_active = true
		else:
			arena_active = true
		sfx("roar", -2.0, 0.8 + 0.1 * q.ch)
		Music.play("final" if q.boss == "malakar" else "boss")
		fx.intensity = 1.8
		fx.strike(_p3(site + Vector2(0, -8)))
		shake = 10.0
		if quest_n == 40:
			_build_cage()
		_set_controls(false)
		dialog.say(Quests.BOSS_INTRO[quest_n], func(): _set_controls(true))
	elif q.kind == "maze":
		_set_controls(false)
		dialog.say(Quests.MAZE_TEXT, func(): _set_controls(true))
	_show_banner("QUEST %d  -  %s" % [quest_n, str(q.title).to_upper()], 2.4, "")


## How many quest enemies may be alive at once: the quest's number, held down on low graphics levels (every enemy costs ~30 draw calls).
func _alive_cap() -> int:
	return mini(int(q.max_alive), Settings.enemy_cap())


func add_cap(base: int) -> int:
	return mini(base, Settings.enemy_cap() + 3)


## Camp decoration count scaled by quality.
func _cnt(n: int) -> int:
	return maxi(1, int(round(float(n) * Settings.prop_mult())))


func _quest_enemy_count() -> int:
	var n := 0
	for e in enemies:
		if e.quest and not e.dead and e.type != "fist":
			n += 1
	return n


func _quest_update(dt: float) -> void:
	if q_done or q.is_empty():
		return
	var dist := p_pos.distance_to(site)
	if not camp_spawned and dist < CAMP_RANGE:
		_spawn_camp()
	if not q_arrived:
		var ar := ARRIVE_RANGE
		if quest_n == 30:
			ar = 34.0
		if camp_spawned and q.kind == "maze":
			# the labyrinth is huge: the quest starts the moment you step inside its walls
			if structures.maze_margin(p_pos) > 1.0:
				_arrive()
		elif camp_spawned and dist < ar:
			_arrive()
		return
	var alive := _quest_enemy_count()
	match q.kind:
		"kill":
			if q_kills >= int(q.target):
				_complete_quest()
				return
			q_cd -= dt
			var remaining: int = int(q.target) - q_kills - alive
			if q_cd <= 0.0 and alive < _alive_cap() and remaining > 0:
				q_cd = q.interval
				_spawn_enemy(_pick_kind(), _spawn_near(site, 18.0, 28.0), true, false)
		"survive":
			if dist < 34.0:
				q_timer += dt
				away_warn = 0.0
			else:
				away_warn += dt
			if q_timer >= float(q.target):
				_cleanup_quest_enemies()
				_complete_quest()
				return
			q_cd -= dt
			if q_cd <= 0.0 and alive < _alive_cap():
				q_cd = q.interval
				_spawn_enemy(_pick_kind(), _spawn_near(site, 18.0, 28.0), true, false)
		"elite":
			if q_elite_dead:
				_cleanup_quest_enemies()
				_complete_quest()
				return
			q_cd -= dt
			if q_cd <= 0.0 and alive < _alive_cap() + 1:
				q_cd = q.interval * 1.4
				_spawn_enemy(_pick_kind(), _spawn_near(site, 18.0, 28.0), true, false)
		"maze":
			if civilians.all_saved():
				_complete_quest()
		"boss":
			if q_boss_dead and not _boss_dying():
				_cleanup_quest_enemies()
				_complete_quest()


func _cleanup_quest_enemies() -> void:
	for e in enemies:
		if e.quest and not e.dead:
			_kill_enemy(e, false)


func _complete_quest() -> void:
	q_done = true
	q_done_t = 0.0
	arena_active = false
	bridge_active = false
	var reward := 40 + 12 * quest_n
	souls += reward
	sfx("chime", -4.0)
	_show_banner("QUEST COMPLETE", 2.4, "+%d SOULS" % reward)
	q_stage = "wait"


## Drives the post-quest sequence: pause -> chest -> story -> bonfire shop.
func _post_quest(dt: float) -> void:
	q_done_t += dt
	match q_stage:
		"wait":
			if q_done_t > 2.0:
				if Quests.is_boss(quest_n):
					_spawn_chest()
					q_stage = "chest"
					q_done_t = 0.0
				else:
					q_stage = "shop"
					_open_shop()
		"chest":
			if chest_t >= 0.0:
				chest_t += dt
				if chest_lid != null:
					chest_lid.rotation.x = -clampf(chest_t / 0.8, 0.0, 1.0) * 1.3
				if chest_t > 0.8:
					q_stage = "chest_open"
					var rw: Dictionary = Quests.BOSS_REWARDS[quest_n]
					souls += int(rw.souls)
					sfx("chime", -2.0, 0.8)
					_burst(Vector2(chest.global_position.x, chest.global_position.z), 40, Color("ffd770"), 9.0, 1.4)
					_float(chest.global_position + Vector3(0, 2.4, 0), "TREASURE +%d" % int(rw.souls), Color("ffd770"))
					var gains: Array = []
					if rw.key != "":
						keys += 1
						gains.append("THE " + str(rw.key))
					if str(rw.weapon) != "":
						weapons_owned[rw.weapon] = true
						gains.append(str(Weapons.W[rw.weapon].name).to_upper())
						equip_weapon(rw.weapon)
					if str(rw.armor) != "":
						armors_owned[rw.armor] = true
						gains.append(str(Weapons.ARMOR[rw.armor].name).to_upper())
						equip_armor(rw.armor)
					if not gains.is_empty():
						_show_banner("FOUND: " + ", ".join(gains), 4.0, "KEYS %d / 3" % keys)
					refresh_weapon_ui()
					q_done_t = 0.0
		"chest_open":
			if q_done_t > 2.8:
				q_stage = "story"
				_set_controls(false)
				if quest_n == 40:
					princess_walk = true
					_open_cage()
				else:
					dialog.say(Quests.BOSS_DEFEAT[quest_n], func():
						q_stage = "shop"
						_open_shop())
		"story":
			if quest_n == 40 and princess_walk:
				_update_princess(dt)


func _open_shop() -> void:
	_set_controls(false)
	_save_next()
	p_hp = p_max_hp
	p_st = p_max_st
	hp_trail = p_hp
	flasks = maxi(flasks, 3)
	controls.flasks = flasks
	if camp_root == null or camp_root.global_position.distance_to(_p3(p_pos)) > 30.0:
		_free_camp()
		camp_root = _make_bonfire(p_pos + Vector2(2.5, 1.5))
	_burst(p_pos, 30, Color("ffb347"), 8.0)
	sfx("potion", -6.0)
	shop.open()


func _save_next() -> void:
	var cur := quest_n
	quest_n = mini(cur + 1, Quests.MAX_QUEST)
	_save()
	quest_n = cur


func _close_shop() -> void:
	shop.close()
	_save_next()
	_set_controls(true)
	refresh_weapon_ui()
	_begin_quest(mini(quest_n + 1, Quests.MAX_QUEST))


func _remove_enemy(e: Dictionary) -> void:
	e.dead = true
	if e.type == "fist":
		e.fig.root.queue_free()
		return
	e.fig.root.queue_free()
	if e.boss:
		bosses.free_nodes(e)


func _clear_field() -> void:
	civilians.clear()
	torch.leave()
	for e in enemies:
		if not e.dead:
			_remove_enemy(e)
	enemies.clear()
	wayside.clear()
	for c in corpses:
		c.fig.root.queue_free()
	corpses.clear()
	for p in projs:
		p.node.queue_free()
	projs.clear()
	for z in zones:
		z.node.queue_free()
	zones.clear()
	if chest != null:
		chest.queue_free()
		chest = null
		chest_lid = null
	chest_t = -1.0
	if cage != null:
		cage.queue_free()
		cage = null
	princess = {}
	princess_walk = false


func _respawn() -> void:
	lost_souls = souls / 4
	souls -= lost_souls
	p_pos = World.checkpoint(quest_n)
	cam_focus = _p3(p_pos)
	p_hp = p_max_hp
	hp_trail = p_hp
	p_st = p_max_st
	p_act = "idle"
	p_stun = 0.0
	p_stone = 0.0
	p_inv = 1.0
	flasks = maxi(flasks, 3)
	controls.flasks = flasks
	state = "play"
	_set_controls(true)
	_begin_quest(quest_n, false, true)
	_show_banner("YOU RETURN TO THE FIRE", 2.2, "QUEST %d" % quest_n)


# ---------------------------------------------------------------- spawning

## Runs every kind of effect, sound and model once while the loading screen is still up. This is where the one-time costs
## (synthesising sounds, compiling shaders, reading models) are paid, so they cannot stutter the fight later.
func _warm_up() -> void:
	for n in ["hit", "swing", "hurt", "chime", "potion", "roar", "bolt", "boom", "crumble", "v0", "v1", "v2", "v3", "h0", "h1", "h2", "h3", "m0", "m1", "m2", "m3"]:
		if not _snd.has(n):
			_snd[n] = Sfx.make(n)
		await get_tree().process_frame
	await vox.warm()
	for k in ["hollow", "skeleton", "knight"]:
		_pool_make(k)
		await get_tree().process_frame
	var holder := Node3D.new()
	add_child(holder)
	for k in _fig_pool:
		for fig in _fig_pool[k]:
			fig.root.visible = true
			fig.root.position = _p3(p_pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 1.0)))
	for col in [Color("c4392d"), Color("ffd9a0"), Color("f2c25a"), Color("ffe7a8"), Color.WHITE, Color("a0201a"), Color("50ff80"), Color("30e0ff"), Color("ff2040"), Color("ff8a20")]:
		_burst(p_pos + Vector2(1, -1), 8, col, 4.0)
	_blood(p_pos + Vector2(-1, 1), 0.5, 10, 1.0)
	_spawn_orbs(p_pos + Vector2(0, 1), 1, "soul")
	_spawn_orbs(p_pos + Vector2(0, 1), 1, "ammo")
	for kind in ["arrow", "orb", "fire", "venom", "missile", "magic"]:
		_fire(p_pos + Vector2(2, 0), PI, 0.0, 0.0, kind)
	_add_zone(p_pos + Vector2(3, 2), 2.0, 5.0, 0.0, "enemy")
	_add_zone(p_pos + Vector2(-3, 2), 2.0, 5.0, 0.0, "player")
	_ring(p_pos, Color.WHITE, 3.0, 5.0, 0.4, "ring")
	_ring(p_pos, Color.WHITE, 0.5, 5.0, 0.2, "pillar")
	_splat(p_pos + Vector2(1, 1), 1.0)
	var tmp_camp := _build_camp(p_pos + Vector2(1, -4), 0, true)
	exec.warm_up()
	_add_zone(p_pos + Vector2(4, 2), 2.0, 5.0, 0.0, "player", {"boom": true})
	_set_rage(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	exec.warm_done()
	_set_rage(false)
	for pr in projs:
		(pr.node as Node).free()
	projs.clear()
	for z in zones:
		(z.node as Node).free()
	zones.clear()
	for o in orbs:
		(o.node as Node).free()
	orbs.clear()
	for r in fx_rings:
		(r.node as Node).free()
	fx_rings.clear()
	for sp in splats:
		(sp.node as Node).free()
	splats.clear()
	floaters.clear()
	tmp_camp.free()
	holder.free()
	for k in _fig_pool:
		for fig in _fig_pool[k]:
			fig.root.visible = false


func _build_fig(kind: String) -> Dictionary:
	var fig: Dictionary
	if kind == "hound":
		fig = M.hound()
	elif kind == "serpent":
		fig = M.serpent()
	else:
		fig = M.humanoid(kind)
		M.optimize(fig)
	return fig


func _take_fig(kind: String) -> Dictionary:
	var pool: Array = _fig_pool.get(kind, [])
	if not pool.is_empty():
		var fig: Dictionary = pool.pop_back()
		exec.restore_fig(fig)
		fig.root.visible = true
		_fig_shadows(fig)
		return fig
	var nf := _build_fig(kind)
	add_child(nf.root)
	_fig_shadows(nf)
	return nf


## Enemies only cast shadows on the Realistic level: the shadow pass re-draws every part of every enemy.
func _fig_shadows(fig: Dictionary) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.quality >= 5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in fig.get("meshes", []):
		if is_instance_valid(mi):
			(mi as MeshInstance3D).cast_shadow = mode


func _apply_enemy_shadows() -> void:
	for e in enemies:
		if e.fig.has("meshes"):
			_fig_shadows(e.fig)
	for k in _fig_pool:
		for fig in _fig_pool[k]:
			_fig_shadows(fig)


func _pool_make(kind: String) -> void:
	var fig := _build_fig(kind)
	add_child(fig.root)
	fig.root.visible = false
	if not _fig_pool.has(kind):
		_fig_pool[kind] = []
	_fig_pool[kind].append(fig)


## Builds one spare enemy body at a time while nothing is happening, so spawning mid-game costs almost nothing.
func _pool_tick(dt: float) -> void:
	_pool_t -= dt
	if _pool_t > 0.0 or state != "play":
		return
	_pool_t = 0.8
	for e in enemies:
		if not e.dead and e.mode == "alert" and e.pos.distance_squared_to(p_pos) < 18.0 * 18.0:
			return
	var kinds: Array = ["hollow"]
	for row in q.get("table", []):
		if not kinds.has(row[0]):
			kinds.append(row[0])
	if q.get("kind", "") == "boss" and q.get("boss", "") != "":
		kinds.append(q.boss)
	for k in kinds:
		var want := 1 if ENEMY[k].ai == "boss" else 2
		if _fig_pool.get(k, []).size() < want:
			_pool_make(k)
			return


func _spawn_enemy(kind: String, at = null, is_quest: bool = true, idle: bool = false) -> Dictionary:
	var cfg: Dictionary = ENEMY[kind]
	var boss: bool = cfg.ai == "boss"
	var fig: Dictionary = _take_fig(kind)
	var pos: Vector2 = at if at != null else _spawn_near(site, 18.0, 28.0)
	var hs: float = 1.0 if boss else float(q.get("scale", 1.0))
	var ds: float = 1.0 if boss else float(q.get("dmg_scale", 1.0))
	var elite: bool = kind == "captain"
	_uid_next += 1
	var e := {
		"type": kind, "ai": cfg.ai, "pos": pos, "r": cfg.r, "hp": cfg.hp * hs, "max_hp": cfg.hp * hs,
		"speed": randf_range(cfg.speed[0], cfg.speed[1]), "st": "chase", "t": 0.0, "face": randf() * TAU, "dmg": cfg.dmg * ds,
		"hit_done": false, "kb": Vector2.ZERO, "flash": 0.0, "dead": false, "name": cfg.name, "atk": "", "phase": 1,
		"cd": randf_range(1.0, 2.5), "walk": randf() * 6.0, "mv": 0.0, "last": pos, "dash": Vector2.ZERO, "side": 1.0 if randf() < 0.5 else -1.0,
		"fig": fig, "tele": null, "tele2": null, "boss": boss, "elite": elite, "uid": _uid_next, "daze": 0.0, "exec": null, "vcd": 0.0, "said_cry": false, "taunt_t": randf_range(6.0, 14.0),
		"souls": int(float(cfg.souls) * (1.0 + 0.03 * (quest_n - 1))),
		"mode": "idle" if idle else "alert", "home": pos, "aggro": 18.0 if cfg.ai == "ranged" else 15.0,
		"force": false, "quest": is_quest, "wayside": false,
		"static": false, "sink": 0.0, "link": null, "life": 0.0, "cone": null, "beam": null, "dome": null,
	}
	if boss:
		e.aggro = 0.0
		bosses.attach(e)
	enemies.append(e)
	q_spawned += 1
	return e


func _build_cage() -> void:
	cage = Node3D.new()
	add_child(cage)
	cage.global_position = _p3(site + Vector2(-15, -4))
	var bar_mat := _mat(Color("2a2c34"), 0.5)
	bar_mat.metallic = 0.6
	for i in 12:
		var a := float(i) / 12.0 * TAU
		_mesh(_cyl(0.06, 3.4), bar_mat, Vector3(cos(a) * 1.7, 1.7, sin(a) * 1.7), cage)
	var rim := TorusMesh.new()
	rim.inner_radius = 1.65
	rim.outer_radius = 1.78
	_mesh(rim, bar_mat, Vector3(0, 3.4, 0), cage)
	_mesh(rim, bar_mat, Vector3(0, 0.15, 0), cage)
	princess = M.princess()
	cage.add_child(princess.root)
	princess.arm.rotation = Vector3(0.5, 0.35, 0)
	princess.elbow.rotation = Vector3(1.25, 0, 0)
	princess.larm.rotation = Vector3(0.5, -0.35, 0)
	princess.lelbow.rotation = Vector3(1.25, 0, 0)
	M.princess_sync(princess)
	var gl := OmniLight3D.new()
	gl.light_color = Color("fff0c8")
	gl.light_energy = 1.4
	gl.omni_range = 7.0
	gl.position = Vector3(0, 2.4, 0)
	cage.add_child(gl)


func _open_cage() -> void:
	if cage == null:
		return
	for c in cage.get_children():
		if c is MeshInstance3D and c != princess.root:
			c.visible = false
	_burst(Vector2(cage.global_position.x, cage.global_position.z), 30, Color("fff0c8"), 8.0, 1.5)
	fx.strike(cage.global_position)
	sfx("chime", -2.0, 1.3)


func _update_princess(dt: float) -> void:
	if princess.is_empty() or cage == null:
		return
	var pr: Node3D = princess.root
	var cur := Vector2(cage.global_position.x + pr.position.x, cage.global_position.z + pr.position.z)
	var target := p_pos + Vector2(-1.8, -0.5)
	var d := target - cur
	if d.length() > 0.25:
		var step := d.normalized() * 3.2 * dt
		pr.position += Vector3(step.x, 0, step.y)
		pr.global_position.y = _h(Vector2(pr.global_position.x, pr.global_position.z))
		pr.rotation.y = _face_rot(d.angle())
		var ph := t * 9.0
		princess.legs[0].rotation.x = sin(ph) * 0.5
		princess.legs[1].rotation.x = -sin(ph) * 0.5
		princess.knees[0].rotation.x = -maxf(0.0, cos(ph)) * 0.5
		princess.knees[1].rotation.x = -maxf(0.0, -cos(ph)) * 0.5
	else:
		princess_walk = false
		princess.legs[0].rotation.x = 0.0
		princess.legs[1].rotation.x = 0.0
		pr.rotation.y = _face_rot((p_pos - cur).angle())
		dialog.say(Quests.BOSS_DEFEAT[40], func():
			state = "win"
			end_timer = 0.0
			_set_controls(false))


func _spawn_chest() -> void:
	chest = Node3D.new()
	add_child(chest)
	chest.global_position = _p3(site + Vector2(0, 8))
	var wood := _mat(Color("4a2c18"), 0.8)
	var gold := _mat(Color("d8b050"), 0.3, 1.2)
	_mesh(M.box(1.3, 0.7, 0.85), wood, Vector3(0, 0.35, 0), chest)
	_mesh(M.box(1.34, 0.1, 0.9), gold, Vector3(0, 0.1, 0), chest)
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0, 0.7, 0.42)
	chest.add_child(chest_lid)
	_mesh(M.box(1.3, 0.28, 0.85), wood, Vector3(0, 0.14, -0.42), chest_lid)
	_mesh(M.box(1.34, 0.1, 0.9), gold, Vector3(0, 0.2, -0.42), chest_lid)
	_mesh(_sphere(0.25), gold, Vector3(0, 0.55, -0.45), chest)
	var l := OmniLight3D.new()
	l.light_color = Color("ffd770")
	l.light_energy = 2.0
	l.omni_range = 7.0
	l.position = Vector3(0, 1.2, 0)
	chest.add_child(l)
	chest_t = 0.0
	_burst(site + Vector2(0, 8), 30, Color("ffd770"), 8.0, 0.6)
	sfx("chime", -6.0, 0.7)


## Opens a labyrinth chest. The gun chest completes quest 27.
func _open_maze_chest(i: int) -> void:
	var c: Dictionary = structures.open_chest(i)
	_burst(c.pos, 30, Color("ffd770"), 8.0, 1.0)
	sfx("chime", -4.0, 0.9)
	match c.kind:
		"gun":
			weapons_owned["gun"] = true
			ammo = mini(99, ammo + 24)
			equip_weapon("gun")
			refresh_weapon_ui()
			_show_banner("ASHEN REVOLVER FOUND", 3.5, "24 ammo - tap SWAP to switch weapons")
			q_maze_done = true
			fx.strike(_p3(c.pos))
		"ammo":
			ammo = mini(99, ammo + 14)
			_float(_p3(c.pos, 2.2), "+14 AMMO", Color("ffd070"))
			refresh_weapon_ui()
		"souls":
			var amt := 250 + 25 * quest_n
			souls += amt
			_float(_p3(c.pos, 2.2), "+%d SOULS" % amt, Color("f2d27a"))
		"potion":
			flasks = mini(9, flasks + 2)
			controls.flasks = flasks
			_float(_p3(c.pos, 2.2), "+2 POTIONS", Color("ffb347"))


func _pickup_weapon() -> void:
	has_weapon = true
	pfig.sword.visible = true
	_burst(sword_pos, 44, Color("ffd98a"), 9.0, 1.4)
	sword_node.queue_free()
	sword_node = null
	controls.attack_label = "ATTACK"
	sfx("chime", -2.0)
	fx.strike(_p3(sword_pos))
	_show_banner("BLADE OF THE FALLEN", 2.6)
	tip_t = 9.0
	shake = 4.0
	apply_gear_visuals()
	_begin_quest(1)


# ------------------------------------------------------------------ combat

var _burst_pool: Array = []
var _blood_pool: Array = []
var _spark_meshes := {}
var _blood_mesh: SphereMesh
var _zone_mats := {}
var _orb_mats := {}
var _fig_pool := {}
var _pool_t := 2.0
var _res_pending: Array = []
var _res_hold: Array = []


## A reusable one-shot emitter: reusing nodes, meshes and materials avoids allocation and shader-compile stalls mid-fight.
func _emitter(pool: Array) -> CPUParticles3D:
	if not pool.is_empty():
		return pool.pop_back()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	add_child(p)
	p.finished.connect(func(): pool.append(p))
	return p


func _burst(pos: Vector2, n: int, col: Color, spd: float = 6.0, y: float = 1.0) -> void:
	n = maxi(int(n * Settings.part_mult()), 2)
	var p := _emitter(_burst_pool)
	var key := col.to_html()
	if not _spark_meshes.has(key):
		_spark_meshes[key] = _sphere(0.06, _unshaded(col))
	p.mesh = _spark_meshes[key]
	if p.amount != n:
		p.amount = n
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = spd * 0.3
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -10, 0)
	p.global_position = _p3(pos, y)
	p.restart()


func _float(pos: Vector3, text: String, col: Color) -> void:
	floaters.append({"pos": pos, "text": text, "col": col, "age": 0.0, "life": 1.0})


func petrify_player(secs: float, dmg: float) -> void:
	if p_inv > 0.0 or p_act == "roll" or state != "play":
		_float(_p3(p_pos, 2.4), "DODGED", Color("a0ffb8"))
		return
	if p_act == "block" and p_st > 0.0:
		_float(_p3(p_pos, 2.4), "SHIELDED", Color("a0ffb8"))
		p_st = maxf(0.0, p_st - 30.0)
		return
	p_stun = maxf(p_stun, secs)
	p_stone = secs
	p_act = "idle"
	_float(_p3(p_pos, 2.6), "PETRIFIED!", Color("d0d0c8"))
	_hurt_player(dmg, p_pos + Vector2(1, 0), true)
	sfx("bolt", -4.0, 0.5)


func _hurt_player(dmg: float, src: Vector2, unblockable: bool = false) -> void:
	if p_inv > 0.0 or p_act == "dead" or state != "play":
		return
	dmg *= defense_mult()
	var to_src := (src - p_pos).angle()
	var side := signf(angle_difference(p_face, to_src))
	if not unblockable and p_act == "block" and absf(angle_difference(to_src, p_face)) < 1.3 and p_st > 0.0:
		# a raised shield takes the whole blow: no health lost, stamina pays for it
		var parry := p_block_t < 0.2
		p_st_delay = 1.0
		p_shield_hit = 0.3
		p_hit_dir = side
		var spark := p_pos + Vector2.from_angle(p_face) * 1.0
		_burst(spark, 14 if parry else 10, Color("fff0c0") if parry else Color("ffd9a0"), 8.0, 1.3)
		shake = maxf(shake, 3.0 if parry else 4.0)
		sfx("hit", -4.0, 1.7 if parry else 1.4)
		p_inv = 0.12
		if parry:
			p_st = minf(p_max_st, p_st + 8.0)
			_float(_p3(p_pos, 2.5), "PARRY", Color("fff0a0"))
			for e in enemies:
				if not e.dead and not e.boss and e.type != "brute" and e.pos.distance_to(src) < 1.2:
					e.st = "stagger"
					e.t = 0.0
					e.kb = Vector2.from_angle(-to_src) * 7.0
		else:
			p_st -= dmg * 0.9
			_float(_p3(p_pos, 2.5), "BLOCKED", Color("c9e8ff"))
		if p_st <= 0.0:
			p_st = 0.0
			p_stun = 0.9
			p_act = "idle"
			_burst(p_pos, 16, Color.WHITE, 9.0)
			_float(_p3(p_pos, 2.9), "GUARD BROKEN", Color("ffd9a0"))
		return
	if p_act in ["attack", "drink", "cast", "shoot", "flurry", "fan", "blast"]:
		p_act = "idle"
	p_stun = maxf(p_stun, 0.12)
	p_hit_t = 0.4
	p_hit_dir = side
	shake = maxf(shake, 9.0)
	_blood(p_pos, to_src + PI, 22, 1.0)
	_screen_blood(4)
	sfx("hit", -5.0, randf_range(0.8, 1.0))
	vox.hero_hurt()
	p_hp -= dmg
	p_flash = 0.2
	p_since_hit = 0.0
	_float(_p3(p_pos, 2.2), str(int(ceil(dmg))), Color("ff6a5a"))
	if p_hp <= 0.0:
		p_hp = 0.0
		state = "dead"
		p_act = "dead"
		end_timer = 0.0
		lost_souls = souls / 4
		_set_controls(false)
		vox.hero_die()
		exec.abort()
		for b in enemies:
			if b.boss and not b.dead:
				talk.say(b, "kill", true)
				break


## Spray of blood (droplets that arc away along `ang`) and splats on the ground. `amount` ~1 for a normal wound.
func _blood(pos: Vector2, ang: float, n: int, amount: float) -> void:
	n = maxi(int(n * Settings.part_mult()), 3)
	var p := _emitter(_blood_pool)
	if _blood_mesh == null:
		_blood_mesh = SphereMesh.new()
		_blood_mesh.radius = 0.045
		_blood_mesh.height = 0.14
		_blood_mesh.radial_segments = 6
		_blood_mesh.rings = 3
		_blood_mesh.material = _unshaded(Color(0.42, 0.02, 0.02))
	p.mesh = _blood_mesh
	if p.amount != n:
		p.amount = n
	p.lifetime = 0.8
	p.direction = Vector3(cos(ang), 0.55, sin(ang))
	p.spread = 38.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.5 * amount
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.global_position = _p3(pos, 1.3)
	p.restart()
	for i in 1 + int(2.0 * amount):
		_splat(pos + Vector2.from_angle(ang + randf_range(-0.7, 0.7)) * randf_range(0.4, 2.6) * amount, randf_range(0.5, 1.1) * amount)


## Blood running down from the top of the screen.
func _screen_blood(n: int) -> void:
	for i in n:
		blood_drips.append({"x": randf(), "y": -6.0, "len": randf_range(8.0, 30.0), "spd": randf_range(22.0, 70.0), "w": randf_range(3.0, 9.0), "a": 1.0})
	if blood_drips.size() > 40:
		blood_drips = blood_drips.slice(blood_drips.size() - 40)


## Ground stains fade away; a badly wounded hero keeps bleeding and the screen drips.
func _update_gore(dt: float) -> void:
	for sp in splats:
		sp.age += dt
		var a := clampf(1.0 - (float(sp.age) - 12.0) / 6.0, 0.0, 1.0)
		(sp.mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)
	while not splats.is_empty() and float(splats[0].age) > 18.0:
		var old: Dictionary = splats.pop_front()
		old.node.queue_free()
	for d in blood_drips:
		d.y += d.spd * dt
		d.len += d.spd * dt * 0.45
		d.spd = maxf(6.0, d.spd - 9.0 * dt)
		d.a -= dt * 0.18
	blood_drips = blood_drips.filter(func(d): return d.a > 0.0 and d.y < 420.0)
	if state != "play" or p_hp <= 0.0:
		return
	var low := clampf(1.0 - p_hp / (p_max_hp * 0.4), 0.0, 1.0)
	if low <= 0.0:
		return
	p_drip -= dt * (0.6 + 2.4 * low)
	if p_drip <= 0.0:
		p_drip = randf_range(0.6, 1.2)
		_splat(p_pos + Vector2.from_angle(randf() * TAU) * randf_range(0.2, 0.9), randf_range(0.25, 0.5) * (0.6 + low))
		if randf() < 0.4 + 0.5 * low:
			_screen_blood(1)


## A fading blood stain on the ground.
func _splat(pos: Vector2, size: float) -> void:
	if splats.size() > 36:
		var old: Dictionary = splats.pop_front()
		old.node.queue_free()
	var q := QuadMesh.new()
	q.size = Vector2(size * randf_range(0.8, 1.5), size * randf_range(0.8, 1.5))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = splat_tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = q
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = _p3(pos, 0.05)
	node.rotation = Vector3(-PI / 2, randf() * TAU, 0)
	splats.append({"node": node, "mat": m, "age": 0.0})


func _hurt_enemy(e: Dictionary, dmg: float, ang: float, blocked: bool, kb_mul: float = 1.0) -> void:
	if e.dead:
		return
	# Titan fists pass the damage on to the Titan itself
	if e.link != null:
		e.flash = 0.12
		_float(_p3(e.pos, 3.2), str(int(dmg)), Color("a0e8ff"))
		sfx("hit", -2.0, 0.7)
		_burst(e.pos, 8, Color("9ae8ff"), 6.0, 1.5)
		_hurt_enemy(e.link, dmg, ang, false)
		return
	if e.boss:
		var before := dmg
		dmg = bosses.absorb(e, dmg)
		if dmg <= 0.0:
			e.flash = 0.1
			return
	e.hp -= dmg
	e.flash = 0.15
	e.mode = "alert"
	if not blocked:
		_enemy_voice(e, "hit")
	var big: bool = e.boss or e.type == "brute"
	e.kb = Vector2.from_angle(ang) * (2.0 if e.boss else (3.0 if big else (4.0 if blocked else 12.0))) * kb_mul
	if not e.boss and e.type != "brute" and not blocked and e.st != "strike" and e.type != "fist":
		e.st = "stagger"
		e.t = 0.0
	var sh: float = e.fig.root.scale.y
	if blocked:
		_burst(e.pos, 10, Color("ffe7a8"), 7.0, 1.4)
		_float(_p3(e.pos, 2.4 * sh), "BLOCKED", Color("c9c3a8"))
		sfx("hit", -4.0, 1.5)
	else:
		_blood(e.pos, ang, 14 if not big else 26, 0.8 if not big else 1.3)
		_float(_p3(e.pos, minf(2.3 * sh, 12.0)), str(int(dmg)), Color("fff1c8"))
		sfx("hit", -2.0, randf_range(0.9, 1.15))
	shake = maxf(shake, 5.0)
	if e.hp > 0.0 and e.type != "fist" and e.exec == null and e.daze <= 0.0 and float(e.get("stun", 0.0)) <= 0.0:
		var thr := 0.1 if e.boss else (0.42 if e.elite else 0.45)
		if e.hp < e.max_hp * thr:
			if e.boss:
				e.stun = 9.0
				e.atk = ""
				e.st = "chase"
				e.t = 0.0
				_show_banner("FINISH HIM!", 2.4, "Get close and press GRAB")
				sfx("chime", -4.0, 0.7)
			elif e.elite or randf() < 0.7:
				e.daze = 3.6
				e.st = "stagger"
	if e.hp <= 0.0:
		_kill_enemy(e, true)


func _kill_enemy(e: Dictionary, reward: bool) -> void:
	if e.dead:
		return
	e.dead = true
	if e.type != "fist":
		_enemy_voice(e, "die")
	if e.type == "fist":
		_burst(e.pos, 14, Color("9aaaba"), 8.0, 1.0)
		e.fig.root.queue_free()
		return
	var sh: float = e.fig.root.scale.y
	if reward:
		souls += int(e.souls)
		_float(_p3(e.pos, minf(3.0 * sh, 12.0)), "+%d" % int(e.souls), Color("f2d27a"))
		_spawn_orbs(e.pos, 3 if not e.boss else 14, "soul")
		if weapons_owned.gun and (randf() < 0.2 or e.boss):
			_spawn_orbs(e.pos + Vector2(0.6, 0.4), 1, "ammo")
		if e.quest:
			if q.get("kind", "") == "kill":
				q_kills += 1
			if e.elite:
				q_elite_dead = true
			if e.boss:
				q_boss_dead = true
				_show_banner("%s  DEFEATED" % str(ENEMY[e.type].name), 4.0)
				get_tree().create_timer(5.0).timeout.connect(func(): Music.play("game"))
	_burst(e.pos, 36 if e.boss else 20, Color("f2c25a"), 8.0)
	if e.boss:
		bosses.free_nodes(e)
		# a dead Titan takes its fists with it
		for o in enemies:
			if o.link == e:
				_kill_enemy(o, false)
	if e.type == "serpent":
		for s in e.fig.segs:
			s.visible = true
	var entry := {"fig": e.fig, "t": 0.0, "base_y": e.fig.root.position.y, "quad": e.fig.quad, "serpent": e.fig.get("serpent", false)}
	if e.boss:
		talk.say(e, "death", true)
		entry["boss"] = true
		entry["type"] = e.type
		entry["pos"] = e.pos
		entry["col"] = BOSS_FX.get(e.type, Color("ff8a20"))
		entry["next"] = 0.0
		entry["boom"] = false
		entry["boom2"] = false
		entry["crumble"] = false
		entry["base_x"] = e.fig.root.position.x
		entry["base_z"] = e.fig.root.position.z
		entry["scale0"] = e.fig.root.scale
	corpses.append(entry)


func _spawn_orbs(pos: Vector2, n: int, kind: String = "soul") -> void:
	if orb_mesh == null:
		return
	for i in n:
		if not _orb_mats.has(kind):
			_orb_mats[kind] = _mat(Color("f2d27a") if kind == "soul" else Color("8ad8ff"), 0.3, 2.5)
		var m := _mesh(orb_mesh, _orb_mats[kind])
		m.global_position = _p3(pos, 0.8)
		m.scale = Vector3.ONE * (0.28 if kind == "soul" else 0.36)
		orbs.append({"node": m, "t": 0.0, "kind": kind, "vel": Vector3(randf_range(-2, 2), randf_range(3, 5), randf_range(-2, 2))})


## Enemy projectile (or Titan missile). homing = turn rate in rad/s.
func _fire(from: Vector2, ang: float, dmg: float, spd: float, kind: String, homing: float = 0.0, height: float = 1.3) -> void:
	var node: Node3D = proj_art.make(kind)
	add_child(node)
	node.global_position = _p3(from, height)
	node.rotation.y = _face_rot(ang)
	projs.append({"pos": from, "vel": Vector2.from_angle(ang) * spd, "dmg": dmg, "life": 5.0 if homing > 0.0 else 3.0, "node": node,
		"kind": kind, "team": "enemy", "homing": homing, "h": height})


func _fire_bullet(ang: float, mult: float = 1.0) -> void:
	var node: Node3D = proj_art.make("bullet")
	add_child(node)
	var from := p_pos + Vector2.from_angle(ang) * 0.9
	node.global_position = _p3(from, 1.35)
	node.rotation.y = _face_rot(ang)
	var wd := weapon_dmg() * mult
	projs.append({"pos": from, "vel": Vector2.from_angle(ang) * 44.0, "dmg": wd, "life": 0.75, "node": node,
		"kind": "bullet", "team": "player", "homing": 0.0, "h": 1.35})


func _add_zone(pos: Vector2, r: float, delay: float, dmg: float, team: String, tag: Dictionary = {}) -> void:
	if not _zone_mats.has(team):
		var zm := _unshaded(Color(1.0, 0.25, 0.15, 0.35) if team == "enemy" else Color(0.4, 0.6, 1.0, 0.4))
		zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_zone_mats[team] = zm
	if tag.has("boom") and not _zone_mats.has("boom"):
		var bm := _unshaded(Color(1.0, 0.55, 0.15, 0.4))
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_zone_mats["boom"] = bm
	var node := _mesh(_cyl(r, 0.04), _zone_mats["boom" if tag.has("boom") else team])
	node.global_position = _p3(pos, 0.12)
	zones.append({"pos": pos, "r": r, "t": 0.0, "delay": delay, "dmg": dmg, "team": team, "node": node, "done": false, "tag": tag})


func _update_zones(dt: float) -> void:
	for z in zones:
		z.t += dt
		var k: float = clampf(z.t / z.delay, 0.0, 1.0)
		z.node.scale = Vector3(0.4 + 0.6 * k, 1.0, 0.4 + 0.6 * k)
		if z.t >= z.delay:
			z.done = true
			z.node.queue_free()
			if z.tag.has("fist"):
				if not z.tag.fist.dead:
					bosses.spawn_fist(z.tag.fist, z.pos)
				continue
			if z.tag.has("boom"):
				_burst(z.pos, 60, Color("ff9a30"), 13.0, 1.0)
				_burst(z.pos, 24, Color("5a5048"), 7.0, 1.4)
				_ring(z.pos, Color("ff9a30"), float(z.r) * 2.4, 0.5, 0.8, "ring")
				sfx("boom", 0.0, 1.1)
				shake = maxf(shake, 15.0)
			else:
				fx.strike(_p3(z.pos))
				shake = maxf(shake, 7.0)
			if z.team == "enemy":
				if p_pos.distance_to(z.pos) < z.r + p_r:
					_hurt_player(z.dmg, z.pos, true)
			else:
				for e in enemies:
					if e.pos.distance_to(z.pos) < z.r + e.r:
						_hurt_enemy(e, z.dmg, (e.pos - z.pos).angle(), false)
	zones = zones.filter(func(z): return not z.done)


func _update_projs(dt: float) -> void:
	for p in projs:
		p.life -= dt
		if p.homing > 0.0 and p.team == "enemy":
			var want: float = (p_pos - p.pos).angle()
			var cur: float = p.vel.angle()
			var diff := angle_difference(cur, want)
			var turn := clampf(diff, -p.homing * dt, p.homing * dt)
			p.vel = Vector2.from_angle(cur + turn) * p.vel.length()
		p.pos += p.vel * dt
		var n: Node3D = p.node
		n.global_position = _p3(p.pos, p.h)
		n.rotation.y = _face_rot(p.vel.angle())
		if structures.wall_hit(p.pos, 0.1):
			p.life = 0.0
			continue
		if p.team == "enemy":
			if p.pos.distance_to(p_pos) < p_r + 0.5 and p_inv <= 0.0 and state == "play":
				_hurt_player(p.dmg, p.pos - p.vel.normalized() * 0.5)
				p.life = 0.0
				_burst(p.pos, 8, Color("ffc080"), 5.0)
		elif p.team == "player":
			for e in enemies:
				if e.dead or e.type == "fist" and false:
					continue
				if p.pos.distance_to(e.pos) < e.r + 0.35:
					_hurt_enemy(e, p.dmg, p.vel.angle(), false)
					_burst(p.pos, 6, Color("ffd070"), 5.0, 1.3)
					p.life = 0.0
					break
		if p.pos.distance_to(p_pos) > 80.0:
			p.life = 0.0
	for p in projs:
		if p.life <= 0.0:
			p.node.queue_free()
	projs = projs.filter(func(p): return p.life > 0.0)


# ------------------------------------------------------------------ update

const PRELOAD := ["stone_fire_pit", "wooden_crate_01", "wooden_crate_02", "wooden_barrels_01", "treasure_chest", "wooden_bucket_01",
	"wicker_basket_01", "tree_stump_01", "hatchet", "dead_tree_trunk", "dead_tree_trunk_02", "wooden_lantern_01",
	"vintage_oil_lamp", "antique_estoc", "ornate_war_hammer", "ornate_medieval_mace", "wooden_axe_03", "service_pistol", "kite_shield"]


## Starts loading the heavy Poly Haven models on background threads so a camp or chest never has to read them from disk mid-game.
func _preload_models() -> void:
	var paths: Array = ["res://assets/models/opengameart/medieval_tent/medieval_tent.glb"]
	for id in PRELOAD:
		paths.append("res://assets/models/polyhaven/%s/%s_1k.gltf" % [id, id])
	for p in paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)
			_res_pending.append(p)


func _poll_preload() -> void:
	if _res_pending.is_empty():
		return
	var still: Array = []
	for p in _res_pending:
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_res_hold.append(ResourceLoader.load_threaded_get(p))
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			still.append(p)
	_res_pending = still


func _process(delta: float) -> void:
	_poll_preload()
	if not loaded:
		return
	_pool_tick(delta)
	_auto_quality(delta)
	_manage_lights(delta)
	vox.process(delta)
	exec.tick(delta)
	forest.update(delta, cam_focus, p_pos, cam.global_position)
	if state == "play" and not _frozen():
		emblems.update(delta)
	delta = minf(delta, 0.05)
	t += delta
	dialog.process(delta)
	for f in floaters:
		f.age += delta
	floaters = floaters.filter(func(f): return f.age < f.life)
	# darker, quieter inside the tunnel
	var depth := structures.tunnel_depth(p_pos)
	fx.indoor = depth
	fx.dark = move_toward(fx.dark, clampf(structures.maze_margin(p_pos) / 3.0, 0.0, 1.0), delta * 2.0)
	moon.light_energy = moon_base * (1.0 - 0.88 * depth)
	if depth > 0.6 and not tunnel_seen:
		tunnel_seen = true
		_show_banner("THE SUNKEN TUNNEL", 2.6, "Something shuffles in the dark...")
	fx.update(delta, cam_focus)
	if state == "play":
		if not _frozen():
			_update(delta)
		if q_done:
			_post_quest(delta)
	else:
		end_timer += delta
	structures.update_chests(delta)
	_update_speeches(delta)
	_update_corpses(delta)
	_sync_visuals(delta)
	_hud_skip += 1
	if _hud_skip >= Settings.hud_every():
		_hud_skip = 0
		hud.queue_redraw()


var _lights: Array = []
var _light_scan := 0.0
var _light_sort := 0.0
var _aq_t := 0.0
var _aq_frames := 0
var _aq_warm := 8.0


## Only the nearest few lights stay on (the quality level sets how many): every light costs extra passes on every nearby surface.
func _manage_lights(dt: float) -> void:
	_light_scan -= dt
	_light_sort -= dt
	if _light_scan <= 0.0:
		_light_scan = 3.0
		_lights = find_children("*", "OmniLight3D", true, false)
		_light_sort = 0.0
	if _light_sort > 0.0:
		return
	_light_sort = 0.4
	var live: Array = _lights.filter(func(l): return is_instance_valid(l))
	_lights = live
	var pp := _p3(p_pos)
	live.sort_custom(func(a, b): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
	var keep := Settings.max_lights()
	if Settings.eco():
		keep = maxi(1, keep - 1)
	for i in live.size():
		(live[i] as OmniLight3D).visible = i < keep
	Settings.device_tick(0.4)


var _dyn_t := 0.0
var _dyn_frames := 0
var _dyn_cool := 0.0
var _aq_low := 0.0


## Dynamic resolution: when frames run long the 3D image is rendered a little smaller (and sharpened back up when there is headroom). Small, rare steps -
## this is what absorbs the heavy scenes on a phone without the stutter of rebuilding the whole graphics level.
func _dyn_res(raw_dt: float) -> void:
	if not Settings.auto_quality or paused or state != "play" or _frozen() or raw_dt > 0.4:
		return
	_dyn_cool -= raw_dt
	_dyn_t += raw_dt
	_dyn_frames += 1
	if _dyn_t < 0.6:
		return
	var fps := float(_dyn_frames) / _dyn_t
	_dyn_t = 0.0
	_dyn_frames = 0
	if _dyn_cool > 0.0:
		return
	var cap: int = Settings.FPS_OPTIONS[Settings.fps_idx]
	var target := 60.0 if cap == 0 else minf(float(cap), 60.0)
	if Engine.max_fps > 0:
		target = minf(target, float(Engine.max_fps))
	var want := Settings.dyn_scale
	if fps < target * 0.88:
		want = maxf(0.62, want - 0.08)
	elif fps > target * 0.97 and want < 1.0:
		want = minf(1.0, want + 0.04)
	if absf(want - Settings.dyn_scale) > 0.001:
		Settings.dyn_scale = want
		get_viewport().scaling_3d_scale = clampf(Settings.base_scale * want, 0.3, 1.0)
		_dyn_cool = 1.2 if want < 1.0 else 3.0


## If the frame rate stays poor even at the smallest dynamic resolution for a good while, step the graphics level down (and say so).
func _auto_quality(raw_dt: float) -> void:
	_dyn_res(raw_dt)
	if not Settings.auto_quality or Settings.quality <= 0 or paused or state != "play" or _frozen() or raw_dt > 0.4:
		return
	if _aq_warm > 0.0:
		_aq_warm -= raw_dt
		return
	_aq_t += raw_dt
	_aq_frames += 1
	if _aq_t < 4.0:
		return
	var fps := float(_aq_frames) / _aq_t
	_aq_t = 0.0
	_aq_frames = 0
	var cap: int = Settings.FPS_OPTIONS[Settings.fps_idx]
	var target := 60.0 if cap == 0 else minf(float(cap), 60.0)
	if Engine.max_fps > 0:
		target = minf(target, float(Engine.max_fps))
	if fps < target * 0.72 and Settings.dyn_scale <= 0.7:
		_aq_low += 4.0
	else:
		_aq_low = 0.0
	if _aq_low >= 8.0:
		_aq_low = 0.0
		Settings.dyn_scale = 1.0
		Settings.set_quality(Settings.quality - 1)
		_aq_warm = 3.0
		_show_banner("GRAPHICS LOWERED FOR SMOOTHER PLAY", 2.6, Settings.NAMES[Settings.quality])


func _update_corpses(dt: float) -> void:
	_update_rings(dt)
	for c in corpses:
		c.t += dt
		var f: Dictionary = c.fig
		if c.get("boss", false):
			_boss_death_tick(c, dt)
			if c.t > 5.2:
				f.root.queue_free()
				c.t = -99.0
			continue
		if c.serpent:
			for s in f.segs:
				s.position.y -= dt * 0.6
			f.head.position.y -= dt * 1.2
		elif c.quad:
			f.body.rotation = Vector3(0, 0, 1.4 * minf(c.t * 2.5, 1.0))
			if c.t > 1.4:
				f.root.position.y = c.base_y - (c.t - 1.4) * 0.7
		else:
			f.body.rotation = Vector3(-minf(c.t * 2.6, 1.5), 0, 0)
			if c.t > 1.6:
				f.root.position.y = c.base_y - (c.t - 1.6) * 0.7
		if c.t > 3.2:
			f.root.queue_free()
			c.t = -99.0
	corpses = corpses.filter(func(c): return c.t > -50.0)


## True while a defeated boss is still going through its death sequence.
func _boss_dying() -> bool:
	for c in corpses:
		if c.get("boss", false):
			return true
	return false


## Boss death: trembling, strobing flashes and chained blasts, a huge detonation with shockwaves and a light pillar,
## then the body topples, crumbles to ash and sinks away. Each boss burns in its own colour.
func _boss_death_tick(c: Dictionary, dt: float) -> void:
	var f: Dictionary = c.fig
	var col: Color = c.col
	var t: float = c.t
	var sh: float = f.root.scale.y
	var top := minf(2.6 * sh, 11.0)
	var pos: Vector2 = c.pos
	var serpent: bool = c.serpent
	if t < 2.0:
		_set_flash(f, int(t * 16.0) % 2 == 0)
		if not serpent:
			var j := 0.06 * sh * (1.0 - t / 2.0)
			f.root.position.x = c.base_x + randf_range(-j, j)
			f.root.position.z = c.base_z + randf_range(-j, j)
	elif not c.boom:
		_set_flash(f, false)
	# kneel, then topple
	if not serpent and f.has("body") and f.has("legs"):
		var k := smoothstep(0.0, 1.8, t)
		var fall := smoothstep(2.0, 4.0, t)
		var body: Node3D = f.body
		body.rotation = Vector3(lerpf(0.0, 0.7, k) + fall * 0.85, 0.0, sin(t * 28.0) * 0.035 * (1.0 - fall))
		body.position.y = 1.0 - 0.42 * k
		for i in 2:
			f.legs[i].rotation.x = 0.9 * k
			f.knees[i].rotation.x = -1.5 * k
		f.arm.rotation.x = lerpf(f.arm.rotation.x, 0.3, 0.1)
		f.larm.rotation.x = lerpf(f.larm.rotation.x, 0.3, 0.1)
	elif serpent:
		f.head.position.x += randf_range(-0.04, 0.04) * (1.0 - clampf(t / 2.0, 0.0, 1.0))
		f.head.position.y -= dt * 0.4 * smoothstep(0.0, 2.0, t)
		for s in f.segs:
			s.position.y -= dt * 0.9 * smoothstep(1.5, 3.0, t)
	# chained mini blasts while it falls apart
	c.next -= dt
	if c.next <= 0.0 and t < 2.0:
		c.next = randf_range(0.1, 0.22)
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.7 * sh)
		_burst(pos + off, 14, col, 8.0, randf_range(0.6, top))
		sfx("hit", -5.0, randf_range(0.4, 0.75))
		shake = maxf(shake, 4.0 + 6.0 * t / 2.0)
	if t >= 2.0 and not c.boom:
		c.boom = true
		sfx("boom", 2.0, 0.9)
		sfx("roar", -3.0, 0.55)
		shake = 22.0
		fx.strike(_p3(pos))
		fx.intensity += 0.6
		_burst(pos, 90, col, 18.0, top * 0.6)
		_burst(pos, 50, Color.WHITE, 14.0, top * 0.4)
		_ring(pos, col, 20.0, 1.3, 0.95, "ring")
		_ring(pos, Color.WHITE, 30.0, 1.9, 0.5, "ring")
		_ring(pos, col, 0.6, 3.2, 0.55, "pillar")
	if c.type == "malakar" and t >= 2.8 and not c.boom2:
		c.boom2 = true
		sfx("boom", 3.0, 0.65)
		shake = 26.0
		fx.strike(_p3(pos))
		_burst(pos, 120, Color("ff2040"), 22.0, top * 0.5)
		_ring(pos, Color("ff2040"), 40.0, 2.4, 0.8, "ring")
		_ring(pos, Color.BLACK, 28.0, 2.0, 0.6, "ring")
	if t >= 2.0:
		# ash and embers drifting up from the toppling body
		if randf() < 18.0 * dt:
			var off2 := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 1.2 * sh * 0.5)
			_burst(pos + off2, 6, col.darkened(0.4), 3.5, randf_range(0.3, top * 0.8))
		if t >= 2.1 and not c.crumble:
			c.crumble = true
			sfx("crumble", -2.0, 0.8)
		if not serpent and t > 3.0:
			f.root.position.y = c.base_y - (t - 3.0) * 0.9
			var shrink := clampf(1.0 - (t - 3.3) / 1.7, 0.0, 1.0)
			f.root.scale = (c.scale0 as Vector3) * shrink


## Expanding glowing ring (shockwave) or tall light pillar at a point on the ground.
func _ring(pos: Vector2, col: Color, grow: float, life: float, a0: float, kind: String) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r, col.g, col.b, a0)
	var node := MeshInstance3D.new()
	if kind == "pillar":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9
		cm.bottom_radius = 1.2
		cm.height = 60.0
		node.mesh = cm
	else:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.93
		tm.outer_radius = 1.0
		node.mesh = tm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = _p3(pos, 30.0 if kind == "pillar" else 0.4)
	fx_rings.append({"node": node, "mat": m, "col": col, "a0": a0, "age": 0.0, "life": life, "grow": grow, "pillar": kind == "pillar"})


func _update_rings(dt: float) -> void:
	for r in fx_rings:
		r.age += dt
		var u := clampf(float(r.age) / float(r.life), 0.0, 1.0)
		var a := pow(1.0 - u, 1.6) * float(r.a0)
		var col: Color = r.col
		(r.mat as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, a)
		var node: Node3D = r.node
		if r.pillar:
			node.scale = Vector3(1.0 + u * 0.8, 1.0, 1.0 + u * 0.8)
		else:
			var sc := 1.0 + float(r.grow) * u
			node.scale = Vector3(sc, 1.0, sc)
		if u >= 1.0:
			node.queue_free()
			r.age = -99.0
	fx_rings = fx_rings.filter(func(r): return r.age > -50.0)


## A boss speech bubble above `e`, typed out with voiced syllables.
## A short line shouted by an ordinary enemy (its recorded voice is already playing): a smaller, shorter bubble.
func shout(e: Dictionary, text: String) -> void:
	if e.boss or p_pos.distance_to(e.pos) > 26.0:
		return
	var live := speeches.filter(func(s): return not s.boss)
	if live.size() >= 3:
		return
	speak(e, text, false, false)


func _enemy_voice(e: Dictionary, event: String) -> void:
	var line: String = vox.enemy(e, event)
	if line != "":
		shout(e, line)


func speak(e: Dictionary, text: String, last_words: bool = false, blips: bool = true) -> void:
	var v: Dictionary = talk.voice_of(e.type)
	speeches = speeches.filter(func(s): return s.uid != e.uid)
	var sh: float = e.fig.root.scale.y
	# bosses really speak their lines (a recorded, processed voice); the little syllable blips are only a fallback
	var clip_len := -1.0
	if e.boss:
		clip_len = vox.boss_line(str(e.type), text, p_pos.distance_to(e.pos))
	var spoken := clip_len > 0.0
	var life := (clampf(1.8 + text.length() * 0.06, 2.6, 6.0) if blips else clampf(1.3 + text.length() * 0.05, 1.8, 3.2))
	if spoken:
		life = maxf(clip_len + 0.9, 2.2)
	speeches.append({"e": e, "uid": e.uid, "boss": e.boss, "blips": blips and not spoken, "type": e.type, "pos": e.pos, "text": text, "name": str(ENEMY[e.type].name), "col": v.col, "snd": v.snd, "pitch": v.pitch,
		"cps": (float(text.length()) / maxf(clip_len * 0.9, 0.6)) if spoken else 34.0,
		"t": 0.0, "life": life + (1.6 if last_words else 0.0), "chars": 0.0, "voiced": 0,
		"h": minf(3.6 * sh, 12.0) + float(ENEMY[e.type].get("fly", 0.0))})


func _update_speeches(dt: float) -> void:
	for s in speeches:
		s.t += dt
		var e: Dictionary = s.e
		if not e.dead:
			s.pos = e.pos
		s.chars += dt * float(s.get("cps", 34.0))
		var shown := mini(int(s.chars), String(s.text).length())
		if s.blips and shown - int(s.voiced) >= 2 and shown < String(s.text).length():
			s.voiced = shown
			if p_pos.distance_to(s.pos) < 45.0:
				sfx("%s%d" % [s.snd, randi() % 4], -7.0, float(s.pitch) * randf_range(0.88, 1.18))
	speeches = speeches.filter(func(s): return s.t < s.life)


func _wrap_words(text: String, maxc: int) -> Array:
	var lines: Array = []
	var cur := ""
	for w in text.split(" "):
		if cur != "" and cur.length() + 1 + w.length() > maxc:
			lines.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	if cur != "":
		lines.append(cur)
	return lines


func _draw_speeches(vs: Vector2) -> void:
	for s in speeches:
		var a := clampf(minf(float(s.t) / 0.15, (float(s.life) - float(s.t)) / 0.4), 0.0, 1.0)
		var lines := _wrap_words(String(s.text), 30)
		var longest := 0
		for l in lines:
			longest = maxi(longest, String(l).length())
		var w := longest * 8.6 + 28.0
		var h := lines.size() * 21.0 + 38.0
		var sp := _w2s(_p3(s.pos, s.h))
		var x := clampf(sp.x - w * 0.5, 10.0, vs.x - w - 10.0)
		var y := clampf(sp.y - h - 16.0, 8.0, vs.y - h - 8.0)
		var col: Color = s.col
		hud.draw_rect(Rect2(x, y, w, h), Color(0.04, 0.03, 0.05, 0.9 * a))
		hud.draw_rect(Rect2(x, y, w, h), Color(col, a), false, 2.0)
		var tail_x := clampf(sp.x, x + 16.0, x + w - 16.0)
		hud.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 9, y + h), Vector2(tail_x + 9, y + h), Vector2(tail_x, y + h + 12)]), Color(0.04, 0.03, 0.05, 0.9 * a))
		hud.draw_line(Vector2(tail_x - 9, y + h), Vector2(tail_x, y + h + 12), Color(col, a), 2.0)
		hud.draw_line(Vector2(tail_x + 9, y + h), Vector2(tail_x, y + h + 12), Color(col, a), 2.0)
		_text(String(s.name), Vector2(x + 12, y + 22), 12, Color(col, a))
		var budget := int(s.chars)
		for i in lines.size():
			var line: String = lines[i]
			var part := line.substr(0, clampi(budget, 0, line.length()))
			budget -= line.length() + 1
			_text(part, Vector2(x + 12, y + 44 + i * 21.0), 15, Color(BONE, a))


func _chest_prompt() -> int:
	return structures.chest_near(p_pos, 2.6)


func _try_attack(iv: Vector2, il: float) -> void:
	if torch.held:
		_float(_p3(p_pos, 2.4), "DROP THE TORCH FIRST", Color("ffb050"))
		sfx("hit", -12.0, 1.8)
		return
	var w: Dictionary = Weapons.W[equipped]
	if w.style == "shoot":
		if p_gun_cd > 0.0:
			return
		if ammo <= 0 and not unlimited_ammo:
			_float(_p3(p_pos, 2.4), "OUT OF AMMO", Color("ff8a6a"))
			sfx("hit", -12.0, 2.2)
			p_gun_cd = 0.4
			return
		# aim at the best enemy in front, else along the facing / stick
		var best = null
		var bd := 1e9
		for e in enemies:
			if e.dead or (e.mode == "idle" and not e.force):
				continue
			var d: float = p_pos.distance_to(e.pos)
			if d > float(w.range) or e.type == "fist":
				continue
			var away: float = absf(angle_difference((e.pos - p_pos).angle(), iv.angle() if (il > 0.1 and not _tp()) else p_face))
			if _tp() and away > 1.0:
				continue
			var score := d + away * 6.0
			if score < bd:
				bd = score
				best = e
		if best != null:
			p_face = (best.pos - p_pos).angle()
		elif il > 0.1 and not _tp():
			p_face = iv.angle()
		if not unlimited_ammo:
			ammo -= 1
		p_gun_cd = float(w.time)
		_fire_bullet(p_face)
		p_act = "shoot"
		p_act_t = 0.0
		shake = maxf(shake, 2.5)
		_burst(p_pos + Vector2.from_angle(p_face) * 1.0, 6, Color("ffd070"), 4.0, 1.4)
		sfx("bolt", -6.0, 2.2)
		refresh_weapon_ui()
		return
	# pick the next strike of this weapon's chain (resets if you wait too long)
	var chain: Array = Weapons.COMBO.get(equipped, [])
	var nxt := 0
	if not chain.is_empty() and p_combo_win > 0.0:
		nxt = (p_combo + 1) % chain.size()
	var var_d: Dictionary = chain[nxt] if not chain.is_empty() else {}
	var cost := float(w.stam) * float(var_d.get("stam", 1.0))
	if p_st < cost:
		return
	p_st -= cost
	p_st_delay = 0.7
	p_combo = nxt
	p_combo_win = 1.0  # stays open while swinging; shrinks once the swing is over
	p_atk = {
		"anim": var_d.get("anim", "slash_r"),
		"dmg": float(var_d.get("dmg", 1.0)),
		"range": float(w.range) * float(var_d.get("range", 1.0)),
		"arc": float(w.arc) * float(var_d.get("arc", 1.0)),
		"time": float(var_d.get("time", w.time)),
		"hit_t": float(var_d.get("hit_t", w.hit_t)),
		"lunge": float(w.lunge) * float(var_d.get("lunge", 1.0)),
		"kb": float(var_d.get("kb", 1.0)),
		"slam": bool(var_d.get("slam", false)),
		"hits": var_d.get("hits", [float(var_d.get("hit_t", w.hit_t))]),
	}
	p_act = "attack"
	p_act_t = 0.0
	p_hit_done = false
	p_hit_i = 0
	var heavy: bool = nxt == chain.size() - 1
	vox.hero_effort(heavy or bool(p_atk.slam))
	sfx("swing", -6.0 if not heavy else -3.0, randf_range(0.9, 1.2) * (0.7 if (p_atk.slam or heavy) else 1.0))
	var best2 = null
	var bd2 := float(w.range) + 3.0
	for e in enemies:
		if e.dead or (e.mode == "idle" and not e.force):
			continue
		if _tp() and absf(angle_difference((e.pos - p_pos).angle(), p_face)) > 1.1:
			continue
		var d2: float = p_pos.distance_to(e.pos) - e.r
		if d2 < bd2:
			bd2 = d2
			best2 = e
	if best2 != null:
		p_face = (best2.pos - p_pos).angle()
	elif il > 0.1 and not _tp():
		p_face = iv.angle()


func _melee_hit() -> void:
	var a: Dictionary = p_atk
	var rng: float = a.range
	for e in enemies:
		if e.dead:
			continue
		var off: Vector2 = e.pos - p_pos
		if off.length() < rng + e.r and absf(angle_difference(off.angle(), p_face)) < float(a.arc):
			var dmg: float = weapon_dmg() * float(a.dmg)
			var blocked := false
			if ENEMY[e.type].get("shield", false) and absf(angle_difference((p_pos - e.pos).angle(), e.face)) < 1.1:
				dmg *= 0.3
				blocked = true
			_hurt_enemy(e, dmg, off.angle(), blocked, float(a.kb))
	if a.slam:
		# the cleaver cracks the ground in front of you
		var impact := p_pos + Vector2.from_angle(p_face) * 3.2
		shake = maxf(shake, 11.0 * float(a.kb) * 0.6 + 4.0)
		_burst(impact, 30, Color("ff7a30"), 10.0, 0.4)
		sfx("bolt", -6.0, 0.8)
		for e in enemies:
			if not e.dead and e.pos.distance_to(impact) < 3.2 + e.r and absf(angle_difference((e.pos - p_pos).angle(), p_face)) >= float(a.arc):
				_hurt_enemy(e, weapon_dmg() * float(a.dmg) * 0.6, (e.pos - impact).angle(), false)
	elif float(a.kb) >= 2.0:
		shake = maxf(shake, 7.0)


func _update(dt: float) -> void:
	banner_t -= dt
	tip_t -= dt
	for wid in cds:
		cds[wid][0] = maxf(0.0, float(cds[wid][0]) - dt)
		cds[wid][1] = maxf(0.0, float(cds[wid][1]) - dt)
	if p_rage > 0.0:
		p_rage = maxf(0.0, p_rage - dt)
		if randf() < 0.5:
			_burst(p_pos, 1, Color("ff3020"), 3.0, 0.4 + randf() * 1.6)
	p_gun_cd = maxf(0.0, p_gun_cd - dt)
	p_stone = maxf(0.0, p_stone - dt)
	buf_atk = maxf(0.0, buf_atk - dt)
	buf_roll = maxf(0.0, buf_roll - dt)
	buf_estus = maxf(0.0, buf_estus - dt)
	buf_sk1 = maxf(0.0, buf_sk1 - dt)
	buf_sk2 = maxf(0.0, buf_sk2 - dt)
	if p_act != "attack":
		p_combo_win = maxf(0.0, p_combo_win - dt)
	p_hit_t = maxf(0.0, p_hit_t - dt)
	p_shield_hit = maxf(0.0, p_shield_hit - dt)
	p_block = move_toward(p_block, 1.0 if p_act == "block" else 0.0, dt * 9.0)
	p_block_t = p_block_t + dt if p_act == "block" else 0.0
	_update_gore(dt)

	# --- the labyrinth: torch, civilians ---
	var mz := structures.maze_margin(p_pos)
	if mz > 2.0 and not torch.active and has_weapon:
		torch.enter()
	elif mz < -4.0 and torch.active:
		torch.leave()
	torch.update(dt)
	civilians.update(dt)
	_look_hold = maxf(0.0, _look_hold - dt)
	controls.torch_visible = torch.active
	controls.cmd_visible = civilians.total > 0 and not civilians.all_saved() and structures.maze_margin(p_pos) > 0.0
	controls.cmd_enabled = civilians.following_count() > 0
	controls.cmd_label = ("STAY" if civilians.follow_count() > 0 else "FOLLOW") if civilians.following_count() > 0 else "COMMAND"
	if _maze_fail_t >= 0.0:
		_maze_fail_t += dt
		if _maze_fail_t > 3.6:
			_maze_retry()
	controls.torch_label = "DROP" if torch.held else ("PICK UP" if torch.can_pick() else "TORCH")
	if maze_k > 0.3:
		if Input.is_physical_key_pressed(KEY_Z):
			cam_yaw += 1.8 * dt
			_look_hold = 1.2
		if Input.is_physical_key_pressed(KEY_C):
			cam_yaw -= 1.8 * dt
			_look_hold = 1.2

	# --- input ---
	var iv: Vector2 = controls.move_vec
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): iv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): iv.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): iv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): iv.y += 1.0
	if iv.length() > 1.0:
		iv = iv.normalized()
	_iv_screen = iv
	# third person: the stick moves the hero relative to the camera (up = forward, sideways = strafe); the hero always faces where the camera looks
	iv = iv.rotated(-cam_yaw)
	var il := iv.length()
	var want_block: bool = controls.block_held or Input.is_physical_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_SHIFT)

	var near_sword := sword_node != null and p_pos.distance_to(sword_pos) < 2.6
	var chest_i := _chest_prompt()
	var civ_i: int = civilians.near_index(p_pos, 2.8) if q.get("kind", "") == "maze" else -1
	if near_sword:
		controls.attack_label = "TAKE"
	elif chest_i >= 0:
		controls.attack_label = "OPEN"
	elif civ_i >= 0:
		controls.attack_label = "RESCUE"
	elif torch.held:
		controls.attack_label = "NO WEAPON"
	elif has_weapon and not exec.active and not exec.find().is_empty():
		controls.attack_label = "GRAB"
	else:
		controls.attack_label = "SHOOT" if Weapons.W[equipped].style == "shoot" else "ATTACK"
	controls.atk_ok = (not has_weapon) or (p_st >= float(Weapons.W[equipped].stam) and not torch.held) or civ_i >= 0
	controls.roll_ok = p_st >= 20.0
	controls.skill_cd = [float(cds[equipped][0]) / _skill_cd_max(0), float(cds[equipped][1]) / _skill_cd_max(1)]
	var sig := "%d%d%d%s" % [int(float(cds[equipped][0]) * 8), int(float(cds[equipped][1]) * 8), int(p_st / 8), equipped]
	if sig != _skill_sig:
		_skill_sig = sig
		controls.queue_redraw()

	# --- player ---
	p_flash = maxf(0.0, p_flash - dt)
	p_inv = maxf(0.0, p_inv - dt)
	p_since_hit += dt
	if lv.regen > 0 and p_since_hit > 4.0 and p_hp < p_max_hp:
		p_hp = minf(p_max_hp, p_hp + 0.5 * lv.regen * dt)
	if p_st_delay > 0.0:
		p_st_delay -= dt
	else:
		p_st = minf(p_max_st, p_st + (12.0 if p_act == "block" else 34.0) * dt)
	if hp_trail > p_hp:
		hp_trail = maxf(p_hp, hp_trail - 28.0 * dt)
	else:
		hp_trail = p_hp

	if p_stun > 0.0:
		p_stun -= dt
	else:
		var chain_ready: bool = p_act == "attack" and p_hit_done and p_act_t > float(p_atk.time) * 0.7 and buf_atk > 0.0
		var free := p_act == "idle" or p_act == "block" or (p_act == "shoot" and p_act_t > 0.15) or chain_ready
		if free and p_act == "shoot":
			p_act = "idle"
		if free and want_block and p_st > 0.0 and not chain_ready:
			p_act = "block"
		elif p_act == "block":
			p_act = "idle"

		if free and buf_estus > 0.0 and flasks > 0 and p_hp < p_max_hp:
			buf_estus = 0.0
			flasks -= 1
			controls.flasks = flasks
			controls.queue_redraw()
			p_act = "drink"
			p_act_t = 0.0
		elif free and buf_roll > 0.0 and p_st >= 20.0:
			buf_roll = 0.0
			p_st -= 22.0
			p_st_delay = 0.7
			p_act = "roll"
			p_act_t = 0.0
			p_inv = 0.32 + 0.01 * lv.mobility
			p_roll_dir = iv.angle() if il > 0.1 else p_face
			sfx("swing", -10.0, 0.8)
		elif free and buf_sk1 > 0.0 and has_weapon and _skill_ready(0):
			buf_sk1 = 0.0
			_use_skill(0)
		elif free and buf_sk2 > 0.0 and has_weapon and _skill_ready(1):
			buf_sk2 = 0.0
			_use_skill(1)
		elif free and buf_atk > 0.0:
			buf_atk = 0.0
			if not has_weapon:
				if near_sword:
					_pickup_weapon()
			elif chest_i >= 0:
				_open_maze_chest(chest_i)
			elif civ_i >= 0:
				civilians.rescue(civ_i)
			elif controls.attack_label == "GRAB" and not exec.find().is_empty():
				exec.start(exec.find())
			else:
				_try_attack(iv, il)

	var spd := 0.0
	var mv := Vector2.ZERO
	var sp := 8.75 * move_mult()
	if p_stun <= 0.0:
		match p_act:
			"idle":
				spd = sp
				mv = iv
				if il > 0.1 and not _tp(): p_face = iv.angle()
			"block":
				spd = 4.0 * move_mult()
				mv = iv
				if il > 0.1 and not _tp(): p_face = iv.angle()
			"shoot":
				p_act_t += dt
				spd = 4.5
				mv = iv
				if p_act_t > 0.3: p_act = "idle"
			"roll":
				p_act_t += dt
				spd = 20.0 * (1.0 + 0.04 * lv.mobility) * (1.0 - p_act_t / 0.5)
				mv = Vector2.from_angle(p_roll_dir)
				p_face = p_roll_dir
				if p_act_t >= 0.45: p_act = "idle"
			"attack":
				p_act_t += dt
				spd = float(p_atk.lunge) if p_act_t < float(p_atk.hit_t) + 0.08 else 1.0
				mv = Vector2.from_angle(p_face)
				var hits: Array = p_atk.hits
				if p_hit_i < hits.size() and p_act_t > float(hits[p_hit_i]):
					p_hit_i += 1
					if p_hit_i >= hits.size():
						p_hit_done = true
					_melee_hit()
				if p_act_t > float(p_atk.time):
					p_act = "idle"
					p_combo_win = 0.55
			"spin":
				p_act_t += dt
				spd = 2.0
				mv = iv
				if not p_hit_done and p_act_t > 0.2:
					p_hit_done = true
					_spin_hit()
				if not p_hit2 and p_act_t > 0.45:
					p_hit2 = true
					_spin_hit()
				if p_act_t > 0.75: p_act = "idle"
			"cast":
				p_act_t += dt
				spd = 0.0
				if not p_hit_done and p_act_t > 0.25:
					p_hit_done = true
					var tgt := p_pos + Vector2.from_angle(p_face) * 6.0
					var bd2 := 14.0
					for e in enemies:
						if e.dead or e.type == "fist":
							continue
						var d2: float = p_pos.distance_to(e.pos)
						var lim := 14.0 if e.type != "cyborg" else 60.0
						if d2 < lim and d2 < bd2 + (50.0 if e.type == "cyborg" else 0.0):
							bd2 = d2
							tgt = e.pos
					_add_zone(tgt, 3.6 if bridge_active == false else 5.5, 0.45, weapon_dmg() * (2.4 + 0.4 * p_skl), "player")
				if p_act_t > 0.6: p_act = "idle"
			"quake":
				p_act_t += dt
				spd = 0.0
				mv = Vector2.ZERO
				if not p_hit_done and p_act_t > 0.55:
					p_hit_done = true
					_quake_hit()
				if p_act_t > 1.0:
					p_act = "idle"
			"rage":
				p_act_t += dt
				spd = 0.0
				mv = Vector2.ZERO
				if not p_hit_done and p_act_t > 0.3:
					p_hit_done = true
					p_rage = 7.0 + float(p_skl)
					_ring(p_pos, Color("ff3020"), 9.0, 0.8, 0.7, "ring")
					_burst(p_pos, 50, Color("ff3020"), 9.0, 1.0)
					fx.pulse(0.7, 0.4)
					shake = maxf(shake, 14.0)
					_float(_p3(p_pos, 2.8), "BLOOD RAGE", Color("ff6a5a"))
				if p_act_t > 0.75:
					p_act = "idle"
			"dash":
				p_act_t += dt
				spd = 30.0 if p_act_t < 0.34 else 1.0
				mv = Vector2.from_angle(p_face)
				if p_act_t < 0.34:
					_dash_hit()
					if randf() < 0.6:
						_burst(p_pos, 2, Color("e8dcc0"), 4.0, 0.3)
				if p_act_t > 0.6:
					p_act = "idle"
			"flurry":
				p_act_t += dt
				spd = 1.5
				mv = Vector2.ZERO
				var fi := int(p_act_t / 0.13)
				if fi > p_hit_i and fi <= 7:
					p_hit_i = fi
					_flurry_hit()
				if p_act_t > 1.05:
					p_act = "idle"
			"fan":
				p_act_t += dt
				spd = 2.5
				mv = iv
				var gi := int(p_act_t / 0.1)
				if gi > p_hit_i and gi <= 6:
					p_hit_i = gi
					_fire_bullet(p_face + lerpf(-0.42, 0.42, float(gi - 1) / 5.0), 0.7 + 0.08 * p_skl)
					sfx("bolt", -6.0, 1.8 + 0.06 * gi)
					shake = maxf(shake, 3.0)
					_burst(p_pos + Vector2.from_angle(p_face) * 1.0, 4, Color("ffd070"), 4.0, 1.4)
				if p_act_t > 0.85:
					p_act = "idle"
			"blast":
				p_act_t += dt
				spd = 0.0
				mv = Vector2.ZERO
				if not p_hit_done and p_act_t > 0.3:
					p_hit_done = true
					_fire_shell()
				if p_act_t > 0.65:
					p_act = "idle"
			"exec":
				spd = 0.0
				mv = Vector2.ZERO
				exec.update(dt)
			"drink":
				p_act_t += dt
				spd = 2.0
				mv = iv
				if p_act_t > 0.9:
					var heal: float = 55.0 + 6.0 * lv.potency
					p_hp = minf(p_max_hp, p_hp + heal)
					_burst(p_pos, 18, Color("ffb347"), 5.0)
					_float(_p3(p_pos, 2.4), "+%d" % int(heal), Color("ffb347"))
					sfx("potion", -6.0)
					p_act = "idle"
	if _tp() and p_act in ["idle", "block", "shoot", "drink", "fan", "blast", "flurry", "quake", "dash"]:
		p_face = atan2(-cos(cam_yaw), -sin(cam_yaw))
	var before := p_pos
	p_pos = _contain(_slide(p_pos, mv * spd * dt))
	var moved := p_pos.distance_to(before) / maxf(dt, 0.0001)
	p_move_speed = moved if (p_act == "idle" or p_act == "block" or p_act == "shoot") and p_stun <= 0.0 else 0.0

	# --- enemies ---
	for e in enemies:
		if exec.active and e != exec.target:
			continue
		if e.boss and not e.dead and e.mode == "alert" and e.exec == null:
			talk.update(e, dt)
		_update_enemy(e, dt)
	for e in enemies:
		if e.dead or e.static or (e.mode == "idle" and not e.force):
			continue
		for o in enemies:
			if o != e and not o.dead and not o.static:
				var off2: Vector2 = e.pos - o.pos
				var od := off2.length()
				var m: float = e.r + o.r
				if od > 0.0 and od < m:
					e.pos += off2 / od * (m - od) * 0.5
		var body: Vector2 = p_pos - e.pos
		var bl := body.length()
		var mm: float = e.r + p_r
		if bl > 0.0 and bl < mm and p_act != "roll":
			p_pos = _contain(_slide(p_pos, body / bl * (mm - bl)))
	enemies = enemies.filter(func(e): return not e.dead)

	_update_projs(dt)
	_update_zones(dt)
	_update_wayside()
	_quest_update(dt)
	shake = maxf(0.0, shake - 40.0 * dt)


func _spin_hit() -> void:
	shake = maxf(shake, 6.0)
	_burst(p_pos, 18, Color("dfe6ff"), 9.0, 1.0)
	for e in enemies:
		var off: Vector2 = e.pos - p_pos
		if off.length() < 4.8 + e.r and not e.dead:
			_hurt_enemy(e, weapon_dmg() * (0.85 + 0.2 * p_skl), off.angle(), false)


func _update_enemy(e: Dictionary, dt: float) -> void:
	var cfg: Dictionary = ENEMY[e.type]
	e.flash = maxf(0.0, e.flash - dt)
	e.vcd = maxf(0.0, float(e.vcd) - dt)
	if e.mode == "alert" and e.ai != "fist":
		if not e.said_cry and e.pos.distance_squared_to(p_pos) < 38.0 * 38.0:
			e.said_cry = true
			_enemy_voice(e, "cry")
		elif e.pos.distance_squared_to(p_pos) < 24.0 * 24.0:
			e.taunt_t -= dt
			if e.taunt_t <= 0.0:
				e.taunt_t = randf_range(9.0, 18.0)
				_enemy_voice(e, "taunt")
	if e.ai == "fist":
		e.t += dt
		e.life += dt
		if e.life > 4.8:
			_kill_enemy(e, false)
		return
	_move_e(e, e.kb * dt)
	e.kb *= pow(0.02, dt)
	if e.exec != null:
		e.mv = 0.0
		return
	if e.daze > 0.0:
		# dazed: reeling, glowing, defenceless - the hero can GRAB it
		e.daze -= dt
		e.st = "stagger"
		e.t = 0.0
		e.mv = 0.0
		e.flash = maxf(e.flash, 0.07 if int(t * 5.0) % 2 == 0 else 0.0)
		return
	var to_p: Vector2 = p_pos - e.pos
	var dist := to_p.length()
	var ang := to_p.angle()
	# idle camps and wayside groups wait until you come close
	if e.mode == "idle":
		e.mv = 0.0
		e.last = e.pos
		if e.force or dist < e.aggro:
			e.mode = "alert"
		else:
			return
	elif e.mode == "return":
		var back: Vector2 = e.home - e.pos
		if back.length() < 1.5:
			e.mode = "idle"
			e.hp = e.max_hp
			e.st = "chase"
		else:
			e.face = back.angle()
			_move_e(e, back.normalized() * e.speed * dt)
		e.mv = e.pos.distance_to(e.last) / maxf(dt, 0.0001)
		e.last = e.pos
		return
	elif e.wayside and dist > 52.0 and e.st != "strike":
		e.mode = "return"
		return
	e.t += dt
	match e.ai:
		"melee":
			_ai_melee(e, cfg, dt, dist, ang)
		"ranged":
			_ai_ranged(e, cfg, dt, dist, ang)
		"boss":
			bosses.ai(e, dt, dist, ang)
	e.mv = e.pos.distance_to(e.last) / maxf(dt, 0.0001)
	e.last = e.pos


func _ai_melee(e: Dictionary, cfg: Dictionary, dt: float, dist: float, ang: float) -> void:
	var reach: float = cfg.reach
	var lunge: float = float(cfg.get("lunge", 0.0))
	match e.st:
		"chase":
			e.face = ang
			if dist > reach + (3.5 if lunge > 0.0 else 0.0):
				_move_e(e, Vector2.from_angle(ang) * e.speed * dt)
			else:
				e.st = "wind"
				if randf() < 0.22:
					_enemy_voice(e, "attack")
				e.t = 0.0
				e.hit_done = false
		"wind":
			if e.t < float(cfg.wind) * 0.45:
				e.face = ang
			if e.t > float(cfg.wind):
				e.st = "strike"
				e.t = 0.0
				e.dash = Vector2.from_angle(e.face)
		"strike":
			if lunge > 0.0:
				if e.t < 0.28:
					_move_e(e, e.dash * lunge * dt)
				if not e.hit_done and e.t > 0.22:
					e.hit_done = true
					if dist < reach + p_r + 0.8:
						_hurt_player(e.dmg, e.pos)
				if e.t > 0.3:
					e.st = "recover"
					e.t = 0.0
			else:
				if not e.hit_done:
					e.hit_done = true
					if dist < reach + p_r + 0.6 and absf(angle_difference(ang, e.face)) < 1.0:
						_hurt_player(e.dmg, e.pos)
					elif e.type == "brute":
						shake = maxf(shake, 5.0)
				if e.t > 0.15:
					e.st = "recover"
					e.t = 0.0
		"recover":
			if e.t > float(cfg.rec):
				e.st = "chase"
				e.t = 0.0
		"stagger":
			if e.t > 0.45:
				e.st = "chase"
				e.t = 0.0


func _ai_ranged(e: Dictionary, cfg: Dictionary, dt: float, dist: float, ang: float) -> void:
	e.cd -= dt
	var rng_d: float = cfg.range
	match e.st:
		"chase":
			e.face = ang
			if dist < rng_d * 0.55:
				_move_e(e, -Vector2.from_angle(ang) * e.speed * 1.1 * dt)
			elif dist > rng_d:
				_move_e(e, Vector2.from_angle(ang) * e.speed * dt)
			else:
				_move_e(e, Vector2.from_angle(ang + PI / 2.0) * e.side * e.speed * 0.45 * dt)
			if e.cd <= 0.0 and dist < rng_d + 3.0:
				e.st = "wind"
				if randf() < 0.22:
					_enemy_voice(e, "attack")
				e.t = 0.0
		"wind":
			e.face = ang
			if e.t > float(cfg.wind):
				_fire(e.pos, ang, e.dmg, 12.0 if cfg.proj == "arrow" else 9.0, cfg.proj, 0.0, 1.3 + float(cfg.get("fly", 0.0)))
				e.st = "recover"
				e.t = 0.0
				e.cd = float(cfg.cd) * randf_range(0.8, 1.25)
				e.side = -e.side
		"recover":
			if e.t > 0.5:
				e.st = "chase"
				e.t = 0.0
		"stagger":
			if e.t > 0.45:
				e.st = "chase"
				e.t = 0.0


# --------------------------------------------------------- visual syncing

func _face_rot(f: float) -> float:
	return atan2(-cos(f), -sin(f))


func _set_flash(fig: Dictionary, on: bool) -> void:
	if fig.get("flash_on", false) == on:
		return
	fig["flash_on"] = on
	for mi in fig.meshes:
		mi.material_overlay = flash_mat if on else null


func _set_stone(on: bool) -> void:
	if pfig.get("stone_on", false) == on:
		return
	pfig["stone_on"] = on
	for mi in pfig.meshes:
		mi.material_overlay = stone_mat if on else null
	if not on:
		pfig["flash_on"] = false


var _cam_off := 0.0        # how far the camera has swung round to dodge something in the way
var _cam_chk := 0.0
var _cam_free := 0.0


## True when a wall or a ridge of ground stands between the camera at `yaw` and what it looks at.
func _cam_blocked(yaw: float, focus: Vector3, zoom: float, pitch: float) -> bool:
	var off: Vector3 = (CAM_OFFSET * Vector3(1.0, pitch, 1.0) * zoom).rotated(Vector3.UP, yaw)
	for i in range(2, 11):
		var k := float(i) / 10.0
		var p: Vector3 = focus + off * k
		var p2 := Vector2(p.x, p.z)
		if k > 0.25 and structures.wall_only(p2, 0.6) and p.y - _h(p2) < 7.0:
			return true
		if _h(p2) > p.y - 0.3:
			return true
	return false


## Swings the camera round (smoothly, via cam_yaw) when something solid blocks the view of the hero; swings back once the way is clear again.
func _cam_avoid(yaw_t: float, focus: Vector3, zoom: float, pitch: float, dt: float) -> float:
	_cam_chk -= dt
	if _cam_chk > 0.0:
		return _cam_off
	_cam_chk = 0.15
	if not _cam_blocked(yaw_t + _cam_off, focus, zoom, pitch):
		if absf(_cam_off) > 0.01:
			# the default view may be free again: go back to it after it has stayed free for a moment
			if not _cam_blocked(yaw_t, focus, zoom, pitch):
				_cam_free += 0.15
				if _cam_free > 0.8:
					_cam_off = 0.0
					_cam_free = 0.0
			else:
				_cam_free = 0.0
		return _cam_off
	_cam_free = 0.0
	var first := 1.0 if _cam_off >= 0.0 else -1.0
	for step in [0.5, 1.0, 1.5, 2.0, 2.6, PI]:
		for sgn in [first, -first]:
			var cand: float = step * sgn
			if not _cam_blocked(yaw_t + cand, focus, zoom, pitch):
				_cam_off = cand
				return _cam_off
	return _cam_off


func _sync_visuals(dt: float) -> void:
	var target := _p3(p_pos)
	var zoom_t := 1.0
	if bridge_active:
		# Titan fight: look ahead and pull back so the colossus rises into frame
		for e in enemies:
			if e.type == "cyborg" and not e.dead:
				target = target.lerp(_p3(e.pos), 0.4)
				zoom_t = 1.55
	# on the bridge the camera swings behind the hero so the Titan always rises at the top of the screen
	var yaw_t := 0.0
	if bridge_active and zoom_t > 1.0:
		var bd: Vector2 = structures.bridge.d
		yaw_t = atan2(-bd.x, -bd.y)
	var pitch_k := 1.0
	var cine := exec.active
	if cine:
		# finisher: the camera closes in on the pair and swings round them
		zoom_t = exec.cam.zoom
		yaw_t = exec.cam.yaw
		target = exec.cam.focus
		pitch_k = exec.cam.pitch
	cam_zoom = lerpf(cam_zoom, zoom_t, 1.0 - exp(-(7.0 if cine else 2.5) * dt))
	var in_maze_view := not structures.maze.is_empty() and structures.in_maze(p_pos) and state == "play" and not cine
	maze_k = move_toward(maze_k, 1.0 if in_maze_view else 0.0, dt / 0.8)
	if maze_k < 0.5:
		if not bridge_active and maze_k < 0.01:
			yaw_t += _cam_avoid(yaw_t, target, zoom_t, pitch_k, dt)
		cam_yaw = lerp_angle(cam_yaw, yaw_t, 1.0 - exp(-(6.0 if cine else 3.0) * dt))
	cam_focus = cam_focus.lerp(target, 1.0 - exp(-(12.0 if cine else 9.0) * dt))
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.03
	var top_pos := cam_focus + (CAM_OFFSET * Vector3(1.0, pitch_k, 1.0) * cam_zoom).rotated(Vector3.UP, cam_yaw) + sh
	if maze_k > 0.001:
		# over-the-shoulder third person: low behind the hero, the towering walls rising on both sides
		var e := smoothstep(0.0, 1.0, maze_k)
		var fwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var head := _p3(p_pos, 1.6)
		var want := head - fwd * 4.2 + right * 0.55 + Vector3(0, 0.55, 0)
		var dirn := want - head
		var dist := dirn.length()
		dirn /= dist
		var reach := 0.0
		while reach < dist:
			var q := head + dirn * reach
			var q2 := Vector2(q.x, q.z)
			if structures.wall_only(q2, 0.55) or _h(q2) > q.y - 0.2:
				break
			reach += 0.25
		var tp_pos := head + dirn * maxf(reach - 0.35, 0.9)
		var tp_look := head + fwd * 5.0 + right * 0.45 + Vector3(0, -0.3, 0)
		cam.fov = lerpf(45.0, 68.0, e)
		cam.look_at_from_position(top_pos.lerp(tp_pos + sh, e), (cam_focus + sh).lerp(tp_look + sh, e), Vector3.UP)
	else:
		cam.fov = 45.0
		cam.look_at_from_position(top_pos, cam_focus + sh, Vector3.UP)
	embers.position = Vector3(cam_focus.x, cam_focus.y, cam_focus.z)

	if camp_root != null:
		for c in camp_root.get_children():
			if c is OmniLight3D and c.has_meta("fire"):
				c.light_energy = 3.0 + sin(t * 9.0) * 0.5 + randf() * 0.4
	if sword_node != null:
		sword_blade.position.y = 0.25 + sin(t * 2.5) * 0.15
		sword_blade.rotation.y = t * 1.2

	# soul / ammo orbs fly to the player
	var ptar := _p3(p_pos, 1.2)
	for o in orbs:
		o.t += dt
		var n: Node3D = o.node
		if o.t < 0.45:
			o.vel.y -= 14.0 * dt
			n.position += o.vel * dt
		else:
			n.position = n.position.lerp(ptar, 1.0 - exp(-7.0 * dt))
		n.rotation.y += 4.0 * dt
		if o.t > 0.6 and n.position.distance_to(ptar) < 0.7:
			n.queue_free()
			if o.kind == "ammo":
				var gain := randi_range(4, 7)
				ammo = mini(99, ammo + gain)
				_float(_p3(p_pos, 2.6), "+%d AMMO" % gain, Color("8ad8ff"))
				refresh_weapon_ui()
			o.t = -99.0
	orbs = orbs.filter(func(o): return o.t > -50.0)

	_sync_player(dt)
	for e in enemies:
		_sync_enemy(e, dt)

	if not princess.is_empty():
		if not princess_walk:
			princess.body.rotation.x = sin(t * 1.5) * 0.02
		M.princess_sync(princess)


func _sync_player(dt: float) -> void:
	var r: Node3D = pfig.root
	r.position = _p3(p_pos)
	r.rotation.y = _face_rot(p_face)
	var body: Node3D = pfig.body
	var arm: Node3D = pfig.arm
	var elbow: Node3D = pfig.elbow
	var larm: Node3D = pfig.larm
	var lelbow: Node3D = pfig.lelbow
	var legs: Array = pfig.legs
	var knees: Array = pfig.knees
	var psword: Node3D = pfig.sword
	var moving := clampf(p_move_speed / (8.75 * move_mult()), 0.0, 1.0)
	walk_phase += dt * (5.0 + moving * 6.0) * (1.0 if moving > 0.05 else 0.0)
	var sn := sin(walk_phase)
	var cs := cos(walk_phase)
	var style: String = Weapons.W[equipped].style
	body.rotation = Vector3(moving * 0.08, 0, 0)
	body.position.y = 1.0 + absf(sn) * 0.035 * moving
	pfig.rig.rotation = Vector3(0, sn * 0.12 * moving, 0)
	legs[0].rotation = Vector3(sn * 0.7 * moving, 0, 0)
	legs[1].rotation = Vector3(-sn * 0.7 * moving, 0, 0)
	knees[0].rotation.x = -maxf(0.0, cs) * 0.9 * moving
	knees[1].rotation.x = -maxf(0.0, -cs) * 0.9 * moving
	arm.rotation = Vector3(0.2 + sn * 0.5 * moving, -0.15, 0)
	elbow.rotation = Vector3(1.25, 0, 0)
	psword.rotation = Vector3(-0.6, 0, 0)
	larm.rotation = Vector3(0.1 - sn * 0.45 * moving, 0, 0)
	lelbow.rotation = Vector3(0.35, 0, 0)
	match style:
		"shoot":
			arm.rotation = Vector3(0.9 + sn * 0.2 * moving, -0.1, 0)
			elbow.rotation.x = 1.0
			psword.rotation = Vector3(-0.9, 0, 0)
		"overhead":
			arm.rotation = Vector3(0.5 + sn * 0.4 * moving, -0.1, 0)
			larm.rotation = Vector3(0.7, 0.2, 0)
			lelbow.rotation.x = 0.9
			psword.rotation = Vector3(-0.2, 0, 0)
		"thrust":
			arm.rotation = Vector3(0.4 + sn * 0.4 * moving, -0.1, 0)
			psword.rotation = Vector3(-0.15, 0, 0)
	if exec.active:
		r.position.y += exec.lift
	r.position.y += _air_h()
	_pose_shield(pfig.shield, dt)
	pfig.arc.visible = false
	pfig.arc.rotation = Vector3.ZERO
	pfig.arc.scale = Vector3.ONE
	pfig.muzzle.visible = false
	M.drive_asset(pfig, moving, p_act == "attack", p_act == "roll")
	match p_act:
		"roll":
			body.rotation.x = -(p_act_t / 0.45) * TAU
			legs[0].rotation.x = 1.4
			legs[1].rotation.x = 1.4
			knees[0].rotation.x = -1.7
			knees[1].rotation.x = -1.7
		"attack":
			_pose_attack(pfig, p_act_t / float(p_atk.time))
		"shoot":
			var recoil := maxf(0.0, 0.3 - p_act_t) * 1.4
			arm.rotation = Vector3(1.55 + recoil, 0.0, 0)
			elbow.rotation.x = 0.15
			psword.rotation = Vector3(-1.45, 0, 0)
			body.rotation.x = -recoil * 0.2
			larm.rotation = Vector3(1.1, 0.4, 0)
			lelbow.rotation.x = 0.9
			pfig.muzzle.visible = p_act_t < 0.07
		"spin":
			arm.rotation = Vector3(1.4, 0, 0)
			elbow.rotation.x = 0.2
			psword.rotation.x = -1.5
			larm.rotation = Vector3(1.2, -0.8, 0)
			body.rotation.y = (p_act_t / 0.75) * TAU * 2.0
			pfig.arc.visible = true
			pfig.arc.rotation.y = (p_act_t / 0.75) * TAU * 3.0
			arc_mat.albedo_color.a = 0.9
		"cast":
			arm.rotation = Vector3(2.7, 0.2, 0)
			elbow.rotation.x = 0.3
			psword.rotation.x = -0.1
			larm.rotation = Vector3(2.2, -0.2, 0)
		"quake":
			# crouch, leap with the blade overhead in both hands, smash it into the ground
			var qk := clampf(p_act_t / 0.55, 0.0, 1.0)
			var smash := clampf((p_act_t - 0.5) / 0.1, 0.0, 1.0)
			var rec := clampf((p_act_t - 0.6) / 0.35, 0.0, 1.0)
			arm.rotation = Vector3(lerpf(0.6, 3.0, minf(qk * 1.6, 1.0)) * (1.0 - smash) + 0.5 * smash, 0.1, 0)
			larm.rotation = Vector3(lerpf(0.6, 3.0, minf(qk * 1.6, 1.0)) * (1.0 - smash) + 0.5 * smash, -0.1, 0)
			elbow.rotation.x = 0.4 * (1.0 - smash)
			psword.rotation.x = -0.15
			body.rotation.x = (-0.3 * qk) * (1.0 - smash) + 0.55 * smash * (1.0 - rec)
			legs[0].rotation.x = 0.8 * sin(qk * PI) - 0.6 * smash * (1.0 - rec)
			legs[1].rotation.x = 0.4 * sin(qk * PI) + 0.6 * smash * (1.0 - rec)
			knees[0].rotation.x = -1.3 * sin(qk * PI) - 0.9 * smash * (1.0 - rec)
			knees[1].rotation.x = -0.9 * sin(qk * PI) - 0.9 * smash * (1.0 - rec)
		"rage":
			# head back, chest out, arms wide, the whole body trembling
			var rg := clampf(p_act_t / 0.3, 0.0, 1.0)
			arm.rotation = Vector3(1.0 * rg, -0.7 * rg, 0)
			larm.rotation = Vector3(1.0 * rg, 0.7 * rg, 0)
			elbow.rotation.x = 0.4
			lelbow.rotation.x = 0.4
			body.rotation = Vector3(-0.35 * rg + sin(p_act_t * 50.0) * 0.03, sin(p_act_t * 41.0) * 0.04, 0)
			pfig.head.rotation.x = -0.5 * rg
			legs[0].rotation.x = -0.4 * rg
			legs[1].rotation.x = 0.4 * rg
		"dash":
			arm.rotation = Vector3(1.55, 0.0, 0)
			elbow.rotation.x = 0.1
			psword.rotation.x = -1.5
			larm.rotation = Vector3(1.3, 0.25, 0)
			lelbow.rotation.x = 0.3
			body.rotation.x = 0.55
			legs[0].rotation.x = -1.0
			legs[1].rotation.x = 0.9
			knees[1].rotation.x = -0.8
		"flurry":
			# alternating lightning thrusts
			var ph := fmod(p_act_t / 0.13, 1.0)
			var thr := sin(ph * PI)
			var side := 1.0 if int(p_act_t / 0.13) % 2 == 0 else -1.0
			arm.rotation = Vector3(1.2 + 0.4 * thr, 0.25 * side, 0)
			elbow.rotation.x = 0.9 - 0.8 * thr
			psword.rotation.x = -1.3
			larm.rotation = Vector3(1.0 + 0.4 * thr, -0.4 * side, 0)
			lelbow.rotation.x = 0.7
			body.rotation = Vector3(0.25, 0.3 * side * thr, 0)
			legs[0].rotation.x = -0.6
			legs[1].rotation.x = 0.55
			knees[0].rotation.x = -0.4
		"fan":
			# the off hand chops across the hammer while the revolver bucks
			var fr := fmod(p_act_t, 0.1) / 0.1
			arm.rotation = Vector3(1.55 + 0.3 * (1.0 - fr), 0.0, 0)
			elbow.rotation.x = 0.15
			psword.rotation.x = -1.45
			larm.rotation = Vector3(1.5, 0.6 - 1.2 * fr, 0)
			lelbow.rotation.x = 0.5
			body.rotation.x = -0.1 * (1.0 - fr)
			legs[0].rotation.x = -0.35
			legs[1].rotation.x = 0.4
			pfig.muzzle.visible = fr < 0.4
		"blast":
			var bk := maxf(0.0, 0.5 - p_act_t) if p_act_t > 0.3 else 0.0
			arm.rotation = Vector3(1.55 + bk * 2.2, 0.0, 0)
			elbow.rotation.x = 0.15
			psword.rotation.x = -1.45
			larm.rotation = Vector3(1.4, 0.4, 0)
			lelbow.rotation.x = 0.3
			body.rotation.x = -bk * 0.8 + 0.1
			legs[0].rotation.x = -0.5
			legs[1].rotation.x = 0.5
			knees[0].rotation.x = -0.3
			pfig.muzzle.visible = p_act_t > 0.3 and p_act_t < 0.38
		"drink":
			arm.rotation = Vector3(2.3, 0.0, 0.0)
			elbow.rotation.x = 1.7
		"dead":
			body.rotation.z = lerpf(body.rotation.z, PI / 2.0, 0.1)
	if p_act == "exec":
		exec.pose_player(pfig)
	if p_block > 0.001 and p_act != "dead":
		# guard up: shield arm comes across the body, braced stance, jolt when the shield is struck
		var pb := ease(p_block, -2.0)
		var kick := p_shield_hit / 0.3
		larm.rotation = larm.rotation.lerp(Vector3(1.2 + kick * 0.25, 0.65 + p_hit_dir * kick * 0.2, 0.0), pb)
		lelbow.rotation.x = lerpf(lelbow.rotation.x, 1.35 - kick * 0.3, pb)
		body.rotation.x = lerpf(body.rotation.x, 0.1 + kick * 0.12, pb)
		legs[0].rotation.x = lerpf(legs[0].rotation.x, -0.25, pb)
		legs[1].rotation.x = lerpf(legs[1].rotation.x, 0.3, pb)
		knees[1].rotation.x = lerpf(knees[1].rotation.x, -0.35, pb)
	if p_hit_t > 0.0 and p_stone <= 0.0 and p_act != "dead":
		# wound flinch: torso snaps back and away from the blow, arms fling out, settles over 0.4 s
		var fl := clampf(p_hit_t / 0.4, 0.0, 1.0)
		var fe := fl * fl
		body.rotation.x = lerpf(body.rotation.x, -0.38, fe)
		body.rotation.z = p_hit_dir * -0.22 * fe
		arm.rotation = arm.rotation.lerp(Vector3(0.9, -0.5, -0.6), fe * 0.8)
		larm.rotation = larm.rotation.lerp(Vector3(0.7, 0.4, 0.6), fe * 0.8)
		pfig.head.rotation.x = 0.35 * fe
	else:
		pfig.head.rotation.x = 0.0
	pfig.cape.rotation.x = -moving * 0.5 - 0.05 - sin(t * 2.5) * 0.05 * (0.4 + moving)
	if p_stone > 0.0:
		_set_stone(true)
		arm.rotation.x = 0.5
	else:
		_set_stone(false)
		_set_flash(pfig, p_flash > 0.0)
		_set_rage(p_rage > 0.0 and p_flash <= 0.0)


## Shield: slung on the back until the guard goes up, then swings round to the front; recoils when struck.
func _pose_shield(sh: Node3D, dt: float) -> void:
	var u := ease(clampf(p_block, 0.0, 1.0), -2.0)
	var stow_pos := Vector3(0.0, 1.12, 0.2)
	var up_pos := Vector3(-0.18, 1.06, -0.5)
	var pos := stow_pos.lerp(up_pos, u)
	pos.x -= sin(u * PI) * 0.38
	var rot := Vector3(lerpf(0.0, -0.08, u), lerp_angle(PI, 0.0, u), lerpf(0.25, 0.0, u))
	var kick := p_shield_hit / 0.3
	if kick > 0.0:
		# a short, sharp jolt back into the arm, tilting away from the blow
		var jolt := sin(kick * PI) * 0.6 + kick * 0.4
		pos.z += jolt * 0.16
		pos.x += p_hit_dir * jolt * 0.04
		rot.x += jolt * 0.28
		rot.z += p_hit_dir * jolt * 0.25
	elif p_block > 0.99:
		pos.y += sin(t * 2.0) * 0.006
	sh.position = pos
	sh.rotation = rot
	sh.scale = Vector3.ONE * lerpf(0.85, 1.0, u)


## One strike of the sword / cleaver / spear chain. `k` = progress 0..1 through the swing.
func _pose_attack(f: Dictionary, k: float) -> void:
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var psword: Node3D = f.sword
	var body: Node3D = f.body
	var legs: Array = f.legs
	var knees: Array = f.knees
	var a: Dictionary = p_atk
	var tm: float = a.time
	var hk: float = clampf(float(a.hit_t) / tm, 0.1, 0.8)
	var idle_arm: Vector3 = arm.rotation
	var idle_elbow: float = elbow.rotation.x
	var idle_larm: Vector3 = larm.rotation
	var idle_lelbow: float = lelbow.rotation.x
	var idle_sword: float = psword.rotation.x
	var idle_body: Vector3 = body.rotation
	var u := clampf((k - hk * 0.35) / (hk * 1.25), 0.0, 1.0)  # swing progress; mid-swing lands on the hit
	var us := 1.0 - pow(1.0 - u, 2.0)
	var arc_on := p_act_t > float(a.hit_t) - 0.05 and p_act_t < float(a.hit_t) + 0.22
	var arc_a := clampf(1.0 - (p_act_t - (float(a.hit_t) - 0.05)) / 0.27, 0.0, 1.0)
	var arc_tilt := 0.0
	var arc_flip := 1.0
	var arc_wide := 1.0
	var anim := str(a.anim)
	match anim:
		"slash_r", "slash_l":
			var dirn := 1.0 if anim == "slash_r" else -1.0
			var sweep := lerpf(1.5 * dirn, -1.5 * dirn, us)
			arm.rotation = Vector3(lerpf(2.0, 1.35, us), sweep, 0.0)
			elbow.rotation.x = lerpf(0.8, 0.25, us)
			psword.rotation.x = lerpf(-0.5, -1.5, us)
			larm.rotation = Vector3(0.5, -0.5 * dirn * (1.0 - us), 0.0)
			body.rotation.y = -sweep * 0.22
			legs[0].rotation.x = -0.5 * dirn
			legs[1].rotation.x = 0.5 * dirn
			knees[1 if dirn > 0.0 else 0].rotation.x = -0.4
			arc_flip = dirn
		"diag":
			arm.rotation = Vector3(lerpf(2.7, 0.7, us), lerpf(1.0, -1.1, us), lerpf(-0.5, 0.4, us))
			elbow.rotation.x = lerpf(0.5, 0.3, us)
			psword.rotation.x = lerpf(-0.3, -1.4, us)
			larm.rotation = Vector3(lerpf(2.2, 0.8, us), -0.25, 0.0)
			lelbow.rotation.x = 0.6
			body.rotation = Vector3(lerpf(-0.2, 0.35, us), lerpf(0.4, -0.4, us), 0.0)
			legs[0].rotation.x = -0.6 * us
			legs[1].rotation.x = 0.5 * us
			arc_tilt = 0.75
		"lunge", "thrust":
			var big := anim == "lunge"
			arm.rotation = Vector3(lerpf(0.5, 1.55, us), lerpf(-0.25, 0.0, us), 0.0)
			elbow.rotation.x = lerpf(2.1, 0.1, us)
			psword.rotation.x = lerpf(-0.4, -1.5, us)
			larm.rotation = Vector3(lerpf(0.5, 1.1, us), 0.5, 0.0)
			body.rotation = Vector3(0.2 * us * (1.6 if big else 1.0), lerpf(-0.35, 0.15, us), 0.0)
			legs[0].rotation.x = lerpf(0.3, -0.9 if big else -0.7, us)
			legs[1].rotation.x = lerpf(-0.2, 0.7 if big else 0.6, us)
		"vault":
			var arc_j := sin(u * PI)
			arm.rotation = Vector3(lerpf(2.5, 1.3, us), lerpf(0.2, 0.0, us), 0.0)
			elbow.rotation.x = lerpf(0.7, 0.1, us)
			psword.rotation.x = lerpf(-2.3, -1.0, us)
			larm.rotation = Vector3(lerpf(2.0, 1.0, us), 0.3, 0.0)
			body.rotation.x = lerpf(-0.2, 0.55, us)
			body.position.y += arc_j * 0.5
			legs[0].rotation.x = 0.9 * arc_j
			legs[1].rotation.x = 0.3 * arc_j
			knees[0].rotation.x = -1.1 * arc_j
		"double":
			var ph := fmod(k * 2.0, 1.0)
			var pu := clampf((ph - 0.1) / 0.45, 0.0, 1.0)
			var pe := 1.0 - pow(1.0 - pu, 2.0)
			arm.rotation = Vector3(lerpf(0.5, 1.55, pe), lerpf(-0.25, 0.0, pe), 0.0)
			elbow.rotation.x = lerpf(2.1, 0.1, pe)
			psword.rotation.x = lerpf(-0.4, -1.5, pe)
			larm.rotation = Vector3(0.9, 0.5, 0.0)
			body.rotation = Vector3(0.18 * pe, lerpf(-0.3, 0.1, pe), 0.0)
			legs[0].rotation.x = lerpf(0.3, -0.7, pe)
			legs[1].rotation.x = lerpf(-0.2, 0.6, pe)
		"overhead":
			var rise := clampf(k / (hk * 0.85), 0.0, 1.0)
			var drop := clampf((k - hk * 0.85) / (hk * 0.35 + 0.02), 0.0, 1.0)
			var ax := lerpf(0.6, 2.9, rise) if drop <= 0.0 else lerpf(2.9, 0.55, drop)
			var lx := lerpf(0.7, 2.7, rise) if drop <= 0.0 else lerpf(2.7, 0.6, drop)
			arm.rotation = Vector3(ax, 0.1 * (1.0 - drop), 0.0)
			larm.rotation = Vector3(lx, -0.1, 0.0)
			elbow.rotation.x = 0.5 - 0.1 * drop
			lelbow.rotation.x = 0.6
			psword.rotation.x = -0.15
			body.rotation.x = lerpf(0.0, -0.22, rise) if drop <= 0.0 else lerpf(-0.22, 0.4, drop)
			if drop > 0.0:
				legs[0].rotation.x = -0.4
				legs[1].rotation.x = 0.4
			arc_on = drop > 0.2 and p_act_t < tm - 0.1
			arc_a = clampf(1.0 - (p_act_t - float(a.hit_t)) / 0.3, 0.0, 1.0)
		"sweep":
			var sw := lerpf(1.9, -1.9, us)
			arm.rotation = Vector3(1.45, sw, 0.0)
			larm.rotation = Vector3(1.3, sw * 0.7, 0.0)
			elbow.rotation.x = lerpf(0.5, 0.2, us)
			lelbow.rotation.x = 0.5
			psword.rotation.x = -1.5
			body.rotation = Vector3(0.15, -sw * 0.3, 0.0)
			legs[0].rotation.x = -0.55
			legs[1].rotation.x = 0.55
			knees[1].rotation.x = -0.45
			arc_wide = 1.25
		"upper":
			arm.rotation = Vector3(lerpf(0.1, 2.7, us), lerpf(0.6, -0.2, us), lerpf(0.7, -0.3, us))
			larm.rotation = Vector3(lerpf(0.2, 2.3, us), 0.0, 0.3)
			elbow.rotation.x = lerpf(0.6, 0.3, us)
			lelbow.rotation.x = 0.7
			psword.rotation.x = lerpf(-0.5, -1.2, us)
			body.rotation = Vector3(lerpf(0.35, -0.3, us), 0.0, 0.0)
			knees[0].rotation.x = -0.5 * (1.0 - us)
			knees[1].rotation.x = -0.5 * (1.0 - us)
			arc_tilt = 1.1
	# ease back into the idle pose before the swing ends
	var rec := smoothstep(clampf(hk * 1.65, 0.0, 0.88), 1.0, k)
	if rec > 0.0:
		arm.rotation = arm.rotation.lerp(idle_arm, rec)
		elbow.rotation.x = lerpf(elbow.rotation.x, idle_elbow, rec)
		larm.rotation = larm.rotation.lerp(idle_larm, rec)
		lelbow.rotation.x = lerpf(lelbow.rotation.x, idle_lelbow, rec)
		psword.rotation.x = lerpf(psword.rotation.x, idle_sword, rec)
		body.rotation = body.rotation.lerp(idle_body, rec)
	if arc_on and anim not in ["thrust", "lunge", "double", "vault"]:
		f.arc.visible = true
		f.arc.rotation = Vector3(0, 0, arc_tilt)
		f.arc.scale = Vector3(arc_flip * arc_wide, 1.0, arc_wide)
		arc_mat.albedo_color.a = arc_a


func _sync_enemy(e: Dictionary, dt: float) -> void:
	var f: Dictionary = e.fig
	var fr: Node3D = f.root
	if e.type == "fist":
		var drop := clampf(e.life / 0.25, 0.0, 1.0)
		fr.global_position = _p3(e.pos, lerpf(18.0, 0.0, drop * drop))
		fr.visible = true
		return
	var near_d := Settings.enemy_dist()
	var near: bool = e.pos.distance_squared_to(p_pos) < near_d * near_d or e.boss
	fr.visible = near
	if not near:
		return
	var cfg: Dictionary = ENEMY[e.type]
	if f.get("serpent", false):
		fr.position = Vector3.ZERO
		bosses.visuals(e, dt)
		_set_flash(f, e.flash > 0.0)
		return
	fr.position = _p3(e.pos)
	fr.position.y -= float(e.sink)
	fr.rotation.y = _face_rot(e.face)
	if cfg.has("fly"):
		fr.position.y += float(cfg.fly) + sin(t * 3.0 + e.walk) * 0.25
	if f.quad:
		_sync_hound(e, f, dt)
		if e.exec != null:
			exec.pose_enemy(e, f, fr)
		return
	var body: Node3D = f.body
	var arm: Node3D = f.arm
	var elbow: Node3D = f.elbow
	var larm: Node3D = f.larm
	var lelbow: Node3D = f.lelbow
	var wpn: Node3D = f.sword
	var legs: Array = f.legs
	var knees: Array = f.knees
	var moving := clampf(e.mv / maxf(e.speed, 0.1), 0.0, 1.2)
	if moving > 0.05:
		e.walk += dt * (4.0 + e.mv * 1.1)
	var sn := sin(e.walk)
	var cs := cos(e.walk)
	var boss: bool = e.boss
	var wtype: String = f.wtype
	body.rotation = Vector3(float(f.hunch) + moving * 0.05, 0, 0)
	body.position.y = 1.0 + absf(sn) * 0.03 * moving
	f.rig.rotation = Vector3(0, sn * 0.1 * moving, 0)
	legs[0].rotation = Vector3(sn * 0.65 * moving, 0, 0)
	legs[1].rotation = Vector3(-sn * 0.65 * moving, 0, 0)
	knees[0].rotation.x = -maxf(0.0, cs) * 0.8 * moving
	knees[1].rotation.x = -maxf(0.0, -cs) * 0.8 * moving
	# idle arms
	arm.rotation = Vector3(0.2 + sn * 0.4 * moving, -0.15, 0)
	elbow.rotation = Vector3(1.25, 0, 0)
	wpn.rotation = Vector3(-0.6, 0, 0)
	larm.rotation = Vector3(0.1 - sn * 0.4 * moving, 0, 0)
	lelbow.rotation = Vector3(0.35, 0, 0)
	if wtype == "staff":
		wpn.rotation = Vector3(-0.15, 0, 0)
		arm.rotation.x = 0.5
		elbow.rotation.x = 1.0
	elif wtype == "bow":
		larm.rotation = Vector3(0.9, -0.2, 0)
		lelbow.rotation = Vector3(0.6, 0, 0)
		wpn.rotation = Vector3(0, 0, 0)
	elif wtype == "spear":
		wpn.rotation = Vector3(-0.35, 0, 0)
	if f.pose == "zombie":
		arm.rotation = Vector3(1.45 + sn * 0.08, -0.1, 0)
		larm.rotation = Vector3(1.4 - sn * 0.08, 0.1, 0)
		elbow.rotation.x = 0.25
		lelbow.rotation.x = 0.2
		body.rotation.z = sin(e.walk * 0.5) * 0.06 * moving
	elif f.pose == "ghoul":
		arm.rotation = Vector3(1.0 + sn * 0.5 * moving, -0.2, 0)
		larm.rotation = Vector3(1.0 - sn * 0.5 * moving, 0.2, 0)
		elbow.rotation.x = 0.6
		lelbow.rotation.x = 0.6
	for i in f.wings.size():
		var sgn := 1.0 if i == 1 else -1.0
		f.wings[i].rotation.z = sgn * (0.25 + sin(t * 9.0 + e.walk) * 0.5) if cfg.has("fly") else sgn * (0.5 + sin(t * 1.5 + e.walk) * 0.06)
	if f.tail != null:
		f.tail.rotation.y = sin(t * 2.5 + e.walk) * 0.5
	var wd: float = float(cfg.wind)
	if boss and e.atk != "":
		wd = bosses.wind_time(e)
	var w := clampf(e.t / maxf(wd, 0.01), 0.0, 1.0)
	if e.mode == "idle":
		body.rotation.x = float(f.hunch) + sin(t * 1.4 + e.walk) * 0.02
	M.drive_asset(f, moving, e.st == "wind" or e.st == "strike")
	match e.st:
		"wind":
			if e.ai == "ranged":
				if wtype == "bow":
					larm.rotation = Vector3(1.45, -0.15, 0)
					lelbow.rotation = Vector3(0.1, 0, 0)
					arm.rotation = Vector3(1.3, 0.55 * w, 0)
					elbow.rotation.x = 1.9 * w + 0.3
				else:
					arm.rotation = Vector3(lerpf(0.5, 2.6, w), 0.1, 0)
					elbow.rotation.x = 0.6
					wpn.rotation = Vector3(-0.1, 0, 0)
			elif boss and e.atk in ["volley", "bolts", "summon", "stone", "gaze", "spit"]:
				arm.rotation = Vector3(lerpf(0.5, 2.6, w), 0.15, 0)
				larm.rotation = Vector3(lerpf(0.3, 2.6, w), -0.15, 0)
				elbow.rotation.x = 0.4
				lelbow.rotation.x = 0.4
				wpn.rotation = Vector3(-0.1, 0, 0)
			elif boss and e.atk == "sweep":
				arm.rotation = Vector3(1.35, lerpf(0.0, 1.6, w), 0)
				elbow.rotation.x = 0.3
				wpn.rotation = Vector3(-1.5, 0, 0)
				body.rotation.y = lerpf(0.0, 0.4, w)
			elif boss and e.atk in ["charge", "bite"]:
				body.rotation.x = lerpf(0.1, -0.25, w)
				arm.rotation = Vector3(0.6, 0.3, 0)
				elbow.rotation.x = 1.5
			elif wtype == "spear":
				arm.rotation = Vector3(0.6, -0.3, 0)
				elbow.rotation.x = lerpf(1.2, 2.2, w)
				wpn.rotation = Vector3(-0.35, 0, 0)
			elif f.pose == "ghoul" or f.pose == "zombie" or wtype == "claws":
				arm.rotation = Vector3(lerpf(1.2, 2.4, w), 0.2, 0)
				larm.rotation = Vector3(lerpf(1.2, 2.4, w), -0.2, 0)
				body.rotation.x = float(f.hunch) - 0.1 * w
			else:
				arm.rotation = Vector3(lerpf(0.2, 2.3 if (boss or e.type == "brute") else 1.9, w), lerpf(-0.15, 0.4, w), 0)
				elbow.rotation.x = lerpf(1.25, 0.7, w)
				if boss or e.type == "brute":
					larm.rotation = Vector3(lerpf(0.1, 2.0, w), -0.2, 0)
					lelbow.rotation.x = 0.6
				wpn.rotation = Vector3(-0.5, 0, 0)
		"strike":
			if e.ai == "ranged":
				pass
			elif boss and e.atk == "sweep":
				var k := clampf(e.t / 0.2, 0.0, 1.0)
				arm.rotation = Vector3(1.35, lerpf(1.6, -1.6, k), 0)
				elbow.rotation.x = 0.25
				wpn.rotation = Vector3(-1.5, 0, 0)
				body.rotation.y = lerpf(0.4, -0.4, k)
			elif boss and e.atk in ["charge", "bite"]:
				body.rotation.x = 0.55
				arm.rotation = Vector3(1.0, 0, 0)
				elbow.rotation.x = 0.4
				wpn.rotation = Vector3(-1.4, 0, 0)
				legs[0].rotation.x = sin(t * 30.0) * 0.8
				legs[1].rotation.x = -sin(t * 30.0) * 0.8
			elif boss and e.atk in ["volley", "bolts", "summon", "stone", "gaze", "spit"]:
				arm.rotation = Vector3(2.7, 0.15, 0)
				larm.rotation = Vector3(2.7, -0.15, 0)
			elif wtype == "spear":
				arm.rotation = Vector3(1.5, 0.0, 0)
				elbow.rotation.x = 0.1
				wpn.rotation = Vector3(-1.5, 0, 0)
				body.rotation.x = float(f.hunch) + 0.25
			elif f.pose == "ghoul" or wtype == "claws":
				arm.rotation = Vector3(1.6, 0.0, 0)
				larm.rotation = Vector3(1.6, 0.0, 0)
				elbow.rotation.x = 0.2
				lelbow.rotation.x = 0.2
				body.rotation.x = float(f.hunch) + 0.4
			else:
				arm.rotation = Vector3(0.6, -0.1, 0)
				elbow.rotation.x = 0.35
				wpn.rotation = Vector3(-1.3, 0, 0)
				body.rotation.x = float(f.hunch) + 0.3
				if boss or e.type == "brute":
					larm.rotation = Vector3(0.7, -0.1, 0)
		"recover":
			var kk := clampf(1.0 - e.t * 2.0, 0.0, 1.0)
			if kk > 0.0 and e.ai == "melee":
				arm.rotation.x = lerpf(arm.rotation.x, 0.7, kk)
				elbow.rotation.x = lerpf(elbow.rotation.x, 0.35, kk)
		"stagger":
			body.rotation.x = -0.4
	if boss:
		bosses.visuals(e, dt)
		bosses.post_pose(e)
	else:
		var eye_e := 4.0
		f.eye.emission_energy_multiplier = eye_e
	if e.exec != null:
		exec.pose_enemy(e, f, fr)
	if f.get("real", false):
		M.princess_sync(f)
	_set_flash(f, e.flash > 0.0)
	# boss telegraphs
	if e.tele != null:
		var bc: Dictionary = BOSS[e.type if e.type != "malakar" else "malakar"]
		var winding: bool = e.st == "wind"
		var circle: bool = winding and (e.atk == "slam" or e.atk == "tail")
		e.tele.visible = circle
		e.tele.global_position = _p3(e.pos, 0.12)
		var rr: float = float(bc.slam_r) * w
		e.tele.scale = Vector3(rr, 1, rr)
		if e.atk != "roll":
			var swp: bool = winding and (e.atk == "sweep" or e.atk == "charge" or e.atk == "bite")
			e.tele2.visible = swp
			if swp:
				var fwd := Vector2.from_angle(e.face)
				var ln: float = float(bc.sweep_len) if e.atk == "sweep" else (14.0 if e.atk == "charge" else 7.0)
				var wd2: float = float(bc.sweep_len) * 1.3 if e.atk == "sweep" else 3.2
				e.tele2.global_position = _p3(e.pos + fwd * ln * 0.5, 0.12)
				e.tele2.rotation.y = _face_rot(e.face)
				e.tele2.scale = Vector3(wd2, 1, ln * w)


func _sync_hound(e: Dictionary, f: Dictionary, dt: float) -> void:
	var cfg: Dictionary = ENEMY[e.type]
	var moving := clampf(e.mv / maxf(e.speed, 0.1), 0.0, 1.2)
	if moving > 0.05:
		e.walk += dt * (6.0 + e.mv * 1.3)
	var sn := sin(e.walk)
	var legs: Array = f.legs
	var body: Node3D = f.body
	# gallop: front/back pairs swing together, diagonals offset
	var anim: AnimationPlayer = f.get("anim")
	if anim != null:
		# the real wolf plays its own clips: gallop speed follows the chase speed
		var clip := "Idle"
		if e.st == "wind" or e.st == "strike":
			clip = "Attack"
		elif e.st == "stagger":
			clip = "Idle_HitReact1"
		elif moving > 0.7:
			clip = "Gallop"
		elif moving > 0.05:
			clip = "Walk"
		if f.anim_cur != clip:
			f["anim_cur"] = clip
			anim.play(clip, 0.15)
			anim.speed_scale = 1.0
		if clip == "Gallop" or clip == "Walk":
			anim.speed_scale = clampf(e.mv / 4.5, 0.6, 1.6)
		body.position.y = 0.78
	else:
		legs[0].rotation.x = sn * 0.9 * moving
		legs[1].rotation.x = sin(e.walk + 0.6) * 0.9 * moving
		legs[2].rotation.x = -sn * 0.9 * moving
		legs[3].rotation.x = sin(e.walk + 0.6 + PI) * 0.9 * moving
		body.position.y = 0.78 + absf(sn) * 0.08 * moving
	body.rotation = Vector3(0, 0, 0)
	f.tail.rotation.y = sin(t * 4.0 + e.walk) * 0.5
	f.head.rotation = Vector3(0, 0, 0)
	f.jaw.rotation.x = 0.0
	match e.st:
		"wind":
			body.rotation.x = 0.35 * clampf(e.t / float(cfg.wind), 0.0, 1.0)
			f.head.rotation.x = -0.2
			f.jaw.rotation.x = 0.4
		"strike":
			body.rotation.x = -0.35
			f.jaw.rotation.x = 0.9
		"stagger":
			body.rotation.x = -0.3
	f.eye.emission_energy_multiplier = 5.0
	_set_flash(f, e.flash > 0.0)


# --------------------------------------------------------------------- HUD

func _w2s(p: Vector3) -> Vector2:
	return cam.unproject_position(p)


func _text(s: String, pos: Vector2, fs: int, col: Color, al: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, ol: int = 4) -> void:
	var f := UI.font()
	hud.draw_string_outline(f, pos, s, al, w, fs, ol, Color(0, 0, 0, 0.9))
	hud.draw_string(f, pos, s, al, w, fs, col)


func _ornate_bar(pos: Vector2, w: float, h: float, frac: float, trail: float, col: Color, back: Color) -> void:
	hud.draw_rect(Rect2(pos - Vector2(4, 4), Vector2(w + 8, h + 8)), Color(0, 0, 0, 0.78))
	hud.draw_rect(Rect2(pos, Vector2(w, h)), back)
	if trail > frac:
		hud.draw_rect(Rect2(pos, Vector2(w * clampf(trail, 0.0, 1.0), h)), Color("d9c9a0", 0.85))
	hud.draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	hud.draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h * 0.4)), Color(1, 1, 1, 0.14))
	hud.draw_rect(Rect2(pos - Vector2(4, 4), Vector2(w + 8, h + 8)), GOLD, false, 2.0)
	hud.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.5), false, 1.0)


func _band(y: float, h: float, a: float = 1.0) -> void:
	hud.draw_texture_rect(band, Rect2(0, y, hud.size.x, h), false, Color(1, 1, 1, a))
	hud.draw_rect(Rect2(hud.size.x * 0.2, y, hud.size.x * 0.6, 1), Color(GOLD, 0.35 * a))
	hud.draw_rect(Rect2(hud.size.x * 0.2, y + h, hud.size.x * 0.6, 1), Color(GOLD, 0.35 * a))


## A civilian died: the labyrinth resets and the hero starts again at the entrance.
func maze_failed(reason: String) -> void:
	if _maze_fail_t >= 0.0:
		return
	_maze_fail_t = 0.0
	_show_banner("QUEST FAILED", 3.4, reason)
	sfx("roar", -6.0, 0.7)
	shake = 12.0


func _maze_retry() -> void:
	_maze_fail_t = -1.0
	_clear_field()
	camp_spawned = false
	_spawn_camp()
	p_pos = structures.maze.entrance
	cam_focus = _p3(p_pos)
	p_hp = p_max_hp
	p_st = p_max_st
	_show_banner("TRY AGAIN", 2.2, "Keep every civilian alive")


func _quest_line() -> String:
	if q.is_empty() or not has_weapon:
		return ""
	if not q_arrived:
		return "Travel to the marker   %d m" % int(p_pos.distance_to(site))
	match q.kind:
		"kill":
			return "Clear the camp   %d / %d" % [mini(q_kills, int(q.target)), int(q.target)]
		"survive":
			if away_warn > 1.0:
				return "RETURN TO THE CAMP!"
			return "Hold the position   %d / %ds" % [int(q_timer), int(q.target)]
		"elite":
			return "Defeat the Captain" + ("   [DONE]" if q_elite_dead else "")
		"maze":
			if civilians.rescued < civilians.total:
				return "Rescue the civilians   %d / %d   (no one may die)" % [civilians.rescued, civilians.total]
			if civilians.staying_count() > 0:
				return "Call them back  -  tap FOLLOW"
			return "Lead them across to the far gate"
	return "Defeat " + str(q.title)


## Guide arrow next to the hero pointing along the road toward `target`.
func _draw_guide(target: Vector2, col: Color) -> void:
	var d := target - p_pos
	if d.length() < 8.0:
		return
	var dn := d.normalized()
	var ps := _w2s(_p3(p_pos, 1.0))
	var pd := _w2s(_p3(p_pos + dn * 10.0, 1.0))
	var n := (pd - ps).normalized()
	var c := ps + n * 78.0
	var side := Vector2(-n.y, n.x)
	var pulse := 0.65 + 0.35 * sin(t * 4.0)
	hud.draw_colored_polygon(PackedVector2Array([c + n * 16, c - n * 10 + side * 13, c - n * 10 - side * 13]), Color(col, pulse))
	hud.draw_arc(c, 24, 0, TAU, 20, Color(col, 0.25 * pulse), 2.0)


func _draw_minimap() -> void:
	var c := Vector2(116, 250)
	var rad := 78.0
	var rng_m := 130.0
	var sc := rad / rng_m
	hud.draw_circle(c, rad + 4, Color(0, 0, 0, 0.7))
	hud.draw_circle(c, rad, Color(0.04, 0.05, 0.08, 0.8))
	var prev := Vector2.ZERO
	var have := false
	for pt in World.ROUTE:
		var rel: Vector2 = ((pt - p_pos) * sc).rotated(cam_yaw)
		if rel.length() < rad - 2.0:
			if have:
				hud.draw_line(c + prev, c + rel, Color(0.55, 0.5, 0.4, 0.5), 3.0)
			prev = rel
			have = true
		else:
			have = false
	# the tunnel on the road
	for tp in structures.tunnel_pts:
		var tr: Vector2 = ((tp - p_pos) * sc).rotated(cam_yaw)
		if tr.length() < rad - 3.0:
			hud.draw_circle(c + tr, 2.4, Color(0.3, 0.55, 0.6, 0.9))
	for n in range(quest_n, mini(quest_n + 3, Quests.MAX_QUEST) + 1):
		var sr: Vector2 = (World.site(n) - p_pos) * sc
		if sr.length() < rad - 4.0 and n != quest_n:
			hud.draw_circle(c + sr, 3.0, Color(GOLD, 0.7))
	if not q.is_empty() and has_weapon and not q_done:
		var orel: Vector2 = ((site - p_pos) * sc).rotated(cam_yaw)
		var lim := rad - 6.0
		if orel.length() > lim:
			orel = orel.normalized() * lim
		var oc := c + orel
		hud.draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -7), oc + Vector2(6, 0), oc + Vector2(0, 7), oc + Vector2(-6, 0)]), Color("f2d27a"))
	for ch in structures.maze.get("chests", []):
		if not ch.opened:
			var cr: Vector2 = ((ch.pos - p_pos) * sc).rotated(cam_yaw)
			if cr.length() < rad - 3.0 and structures.in_maze(p_pos):
				hud.draw_rect(Rect2(c + cr - Vector2(2.5, 2.5), Vector2(5, 5)), Color("ffd070"))
	if structures.in_maze(p_pos):
		for cv in civilians.list:
			if cv.state == "hiding":
				var vr: Vector2 = ((cv.pos - p_pos) * sc).rotated(cam_yaw)
				if vr.length() < rad - 3.0:
					hud.draw_circle(c + vr, 3.4, Color("9adfff"))
		if torch.ground != Vector2.INF:
			var tr: Vector2 = ((torch.ground - p_pos) * sc).rotated(cam_yaw)
			if tr.length() < rad - 3.0:
				hud.draw_circle(c + tr, 3.0, Color("ffa040"))
	for e in enemies:
		if e.type == "fist":
			continue
		var er: Vector2 = ((e.pos - p_pos) * sc).rotated(cam_yaw)
		if er.length() < rad - 3.0:
			hud.draw_circle(c + er, 2.6 if not e.boss else 4.5, Color("d8402a") if not (e.mode == "idle") else Color("a05a3a"))
	var fa := p_face + cam_yaw
	var tip := c + Vector2(cos(fa), sin(fa)) * 8.0
	var l := c + Vector2(cos(fa + 2.5), sin(fa + 2.5)) * 6.0
	var r := c + Vector2(cos(fa - 2.5), sin(fa - 2.5)) * 6.0
	hud.draw_colored_polygon(PackedVector2Array([tip, l, r]), Color("e8f0ff"))
	hud.draw_arc(c, rad + 4, 0, TAU, 48, GOLD, 2.0)
	_text("TAP FOR MAP", Vector2(c.x - 50, c.y + rad + 22), 11, Color(BONE, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 100)


func _draw_boss_bar(e: Dictionary, vs: Vector2) -> void:
	var bw := minf(vs.x * 0.44, 500.0)
	var bx := (vs.x - bw) / 2.0 + 30.0
	var key: String = e.type
	var tex: Texture2D = portraits.get_tex(key)
	var py := 62.0
	hud.draw_rect(Rect2(bx - 78, py - 4, 68, 68), Color(0, 0, 0, 0.8))
	hud.draw_texture_rect(tex, Rect2(bx - 76, py - 2, 64, 64), false)
	hud.draw_rect(Rect2(bx - 78, py - 4, 68, 68), GOLD, false, 2.0)
	var title: String = e.name
	if e.type == "malakar":
		title += "  -  " + str(bosses.FORM_NAME[e.form])
	_text(title, Vector2(bx, 84), 17, BONE)
	var yy := 96.0
	if e.shield > 0.0:
		_ornate_bar(Vector2(bx, 96), bw, 8, e.shield / maxf(e.shield_max, 1.0), 0.0, Color("5ac8ff"), Color("08141f"))
		yy = 112.0
		_text("DOME SHIELD", Vector2(bx + bw - 90, 92), 10, Color("7ad0ff"))
	_ornate_bar(Vector2(bx, yy), bw, 12, e.hp / e.max_hp, 0.0, Color("8f1f18"), Color("1a0807"))
	var bc: Dictionary = BOSS[e.type]
	for th in bc.phases:
		hud.draw_rect(Rect2(bx + bw * float(th) - 1, yy - 2, 2, 16), Color(GOLD, 0.9))
	if e.stun > 0.0:
		_text("DIZZY - HIT HIM!", Vector2(bx + bw * 0.5 - 70, yy + 32), 14, Color("ffe070"))
	if e.type == "cyborg" and e.exposed > 0.0:
		_text("CORE EXPOSED", Vector2(bx + bw * 0.5 - 60, yy + 32), 14, Color("7ad0ff"))
	if e.type == "serpent" and e.cds.gaze < 2.5:
		_text("GORGON GAZE!", Vector2(bx + bw * 0.5 - 60, yy + 32), 14, Color("8affb0"))


func _draw_princess_panel(vs: Vector2) -> void:
	if quest_n != 40 or princess.is_empty() or not q_active or q_done:
		return
	var tex: Texture2D = portraits.get_tex("princess")
	var x := vs.x - 232.0
	var y := 118.0
	hud.draw_rect(Rect2(x, y, 208, 76), Color(0, 0, 0, 0.7))
	hud.draw_rect(Rect2(x, y, 208, 76), GOLD, false, 2.0)
	hud.draw_texture_rect(tex, Rect2(x + 6, y + 6, 64, 64), false)
	_text("PRINCESS ELARA", Vector2(x + 76, y + 28), 13, Color("f2d27a"))
	_text("held captive", Vector2(x + 76, y + 46), 12, Color(BONE, 0.7))
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	hud.draw_arc(Vector2(x + 84, y + 62), 6, 0, TAU, 12, Color("ff8aa0", 0.4 + 0.5 * pulse), 2.0)


func _draw_hud() -> void:
	var vs := hud.size
	hud.draw_texture_rect(vignette, Rect2(Vector2.ZERO, vs), false)
	if state == "play" or state == "dead":
		var low := clampf(1.0 - p_hp / (p_max_hp * 0.4), 0.0, 1.0)
		if low > 0.0:
			# heartbeat: two quick throbs, faster as health drops
			var ph := fmod(t * (1.1 + 1.4 * low), 1.0)
			var beat := maxf(exp(-pow((ph - 0.08) * 14.0, 2.0)), 0.7 * exp(-pow((ph - 0.26) * 14.0, 2.0)))
			hud.draw_texture_rect(blood_vig, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, clampf(0.35 + 0.65 * low, 0.0, 1.0) * (0.72 + 0.28 * beat)))
		if p_hit_t > 0.0:
			hud.draw_texture_rect(blood_vig, Rect2(Vector2.ZERO, vs), false, Color(1, 0.3, 0.3, clampf(p_hit_t / 0.4, 0.0, 1.0) * 0.85))
		for d in blood_drips:
			var dx: float = float(d.x) * vs.x
			var col := Color(0.5, 0.02, 0.02, clampf(float(d.a), 0.0, 1.0))
			var top := float(d.y) - float(d.len)
			hud.draw_line(Vector2(dx, top), Vector2(dx, float(d.y)), col, float(d.w))
			hud.draw_circle(Vector2(dx, float(d.y)), float(d.w) * 0.75, col)
			hud.draw_line(Vector2(dx - 0.8, top + 2.0), Vector2(dx - 0.8, float(d.y) - 3.0), Color(0.8, 0.1, 0.1, col.a * 0.5), 1.5)
	if p_stone > 0.0:
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.6, 0.62, 0.6, 0.18))
	if fx != null and fx.flash_i > 0.01:
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.88, 1.0, fx.flash_i * 0.38))

	# enemy health bars above their heads
	for e in enemies:
		if e.hp < e.max_hp and not e.boss and e.type != "fist" and e.fig.root.visible:
			var sc: float = e.fig.root.scale.y
			var lift := 2.5 * sc + (float(ENEMY[e.type].get("fly", 0.0)))
			var sp := _w2s(_p3(e.pos, lift))
			var w := 56.0 if e.r < 0.8 else (74.0 if e.r < 1.05 else 96.0)
			hud.draw_rect(Rect2(sp - Vector2(w / 2 + 2, 5), Vector2(w + 4, 10)), Color(0, 0, 0, 0.75))
			hud.draw_rect(Rect2(sp - Vector2(w / 2, 3), Vector2(w * maxf(0.0, e.hp / e.max_hp), 6)), Color("ff6a30") if e.elite else Color("a32a22"))
			hud.draw_rect(Rect2(sp - Vector2(w / 2 + 2, 5), Vector2(w + 4, 10)), Color(GOLD, 0.7), false, 1.0)

	_draw_speeches(vs)
	if Settings.show_fps:
		_text("%d FPS" % Engine.get_frames_per_second(), Vector2(vs.x - 110, vs.y - 18), 15, Color(BONE, 0.75))
	exec.draw_marks(vs)
	for f in floaters:
		var sp2 := _w2s(f.pos + Vector3(0, f.age * 1.8, 0))
		var c: Color = f.col
		c.a = clampf(1.6 - f.age / f.life * 1.6, 0.0, 1.0)
		_text(f.text, sp2 + Vector2(-90, 0), 22, c, HORIZONTAL_ALIGNMENT_CENTER, 180, 5)

	# weapon prompt / objective guide
	if not has_weapon and sword_node != null and state == "play" and not _frozen():
		var sp3 := _w2s(_p3(sword_pos, 3.4))
		var pulse := 0.6 + 0.4 * sin(t * 4.0)
		_text("ANCIENT BLADE", sp3 + Vector2(-90, 0), 17, Color("f2d27a", pulse), HORIZONTAL_ALIGNMENT_CENTER, 180)
		_draw_guide(sword_pos, Color("f2d27a"))
		if banner_t <= 0.0:
			_text("FOLLOW THE ARROW TO THE GLOWING SWORD, THEN TAP  TAKE", Vector2(0, vs.y - 34), 16, Color(BONE, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	elif q.get("kind", "") == "maze" and q_arrived and not q_done and state == "play" and not _frozen() and structures.in_maze(p_pos):
		var goal: Vector2 = civilians.nearest_waiting(p_pos)
		if goal == Vector2.INF:
			goal = structures.maze.get("exit", site)
		_draw_guide(goal, Color("9adfff"))
	elif has_weapon and not q_arrived and not q_done and state == "play" and not _frozen():
		_draw_guide(site, Color("f2d27a"))
		if tip_t > 0.0:
			_text("FOLLOW THE ROAD  -  the arrow and minimap show your objective", Vector2(0, vs.y - 34), 15,
				Color(BONE, clampf(tip_t / 1.5, 0.0, 0.8)), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	elif tip_t > 0.0 and state == "play":
		_text("ATTACK  -  ROLL to dodge  -  hold BLOCK to guard  -  POTION heals", Vector2(0, vs.y - 34), 15,
			Color(BONE, clampf(tip_t / 1.5, 0.0, 0.8)), HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# --- top-left: HP + stamina + quest tracker + minimap ---
	var hw := minf(230.0 + (p_max_hp - 100.0) * 1.2, vs.x * 0.42)
	var sw2 := minf(190.0 + (p_max_st - 100.0) * 1.0, vs.x * 0.36)
	_ornate_bar(Vector2(28, 26), hw, 16, p_hp / p_max_hp, hp_trail / p_max_hp, Color("a82a22"), Color("2a0d0b"))
	_ornate_bar(Vector2(28, 54), sw2, 10, p_st / p_max_st, 0.0, Color("777777") if p_stun > 0.0 else Color("5b9a52"), Color("101a0e"))
	if has_weapon and not q.is_empty():
		_text("QUEST %d / 40" % quest_n, Vector2(28, 94), 15, Color("f2d27a"))
		_text(str(q.title).to_upper(), Vector2(28, 113), 13, Color(BONE, 0.8))
		var ql := _quest_line()
		if ql != "":
			_text(ql, Vector2(28, 132), 13, Color("ff8a6a") if away_warn > 1.0 else Color(BONE, 0.7))
			if q_arrived and (q.kind == "kill" or q.kind == "survive"):
				var frac: float = float(q_kills) / float(q.target) if q.kind == "kill" else q_timer / float(q.target)
				hud.draw_rect(Rect2(28, 140, 200, 5), Color(0, 0, 0, 0.7))
				hud.draw_rect(Rect2(28, 140, 200.0 * clampf(frac, 0.0, 1.0), 5), Color("c9a552"))
	if state == "play":
		_draw_minimap()

	# --- top-right: souls, level, keys ---
	var sx := vs.x - 28.0
	var sw := UI.font().get_string_size(str(souls), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text(str(souls), Vector2(sx - sw, 46), 30, Color("f2d27a"))
	var ic := Vector2(sx - sw - 22, 36)
	hud.draw_circle(ic, 10, Color("f2d27a", 0.25))
	hud.draw_circle(ic, 6, Color("f2d27a"))
	hud.draw_arc(ic, 10, 0, TAU, 20, Color("fff1c8", 0.8), 1.5)
	_text("LEVEL %d" % total_level(), Vector2(0, 68), 14, Color(BONE, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, sx)
	for i in 3:
		var kc := Vector2(sx - 10 - i * 26, 90)
		var got := i < keys
		var kcol := Color("f2d27a") if got else Color(BONE, 0.25)
		hud.draw_arc(kc, 6, 0, TAU, 14, kcol, 2.5)
		hud.draw_line(kc + Vector2(0, 6), kc + Vector2(0, 18), kcol, 2.5)
		hud.draw_line(kc + Vector2(0, 15), kc + Vector2(5, 15), kcol, 2.5)
	# hidden quest: the counter only appears once the first emblem has been found
	if emblems.found.size() > 0:
		var ec := Vector2(sx - 6.0, 122.0)
		hud.draw_circle(ec, 8, Color("e8c25a", 0.3))
		hud.draw_circle(ec, 5, Color("e8c25a"))
		hud.draw_circle(ec, 2, Color("5ad0ff"))
		_text("%d / %d%s" % [emblems.found.size(), emblems.COUNT, "  INF AMMO" if unlimited_ammo else ""], Vector2(0, 128), 13, Color("e8c25a", 0.9), HORIZONTAL_ALIGNMENT_RIGHT, sx - 22.0)
	_draw_princess_panel(vs)

	# --- boss bar (top centre) ---
	for e in enemies:
		if e.boss and e.mode != "idle":
			_draw_boss_bar(e, vs)

	if p_rage > 0.0 and state == "play":
		var pulse_r := 0.5 + 0.5 * sin(t * 9.0)
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.6, 0.0, 0.0, 0.1 + 0.06 * pulse_r))
		_text("BLOOD RAGE  %d" % ceili(p_rage), Vector2(0, vs.y - 30), 16, Color("ff7a6a"), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 4)
	if not civilians.list.is_empty() and state == "play" and not _frozen():
		civilians.draw_hud()
	if maze_k > 0.6 and state == "play" and not _frozen():
		var ch := _w2s(_p3(p_pos + Vector2.from_angle(p_face) * 9.0, 1.4))
		hud.draw_arc(ch, 9.0, 0, TAU, 20, Color(BONE, 0.55), 1.8, true)
		hud.draw_circle(ch, 1.8, Color(BONE, 0.8))
	# --- banners ---
	if banner_t > 0.0 and state == "play" and not shop.root.visible and not dialog.active:
		var a := clampf(minf(banner_t / 0.6, (3.6 - banner_t) / 0.4 + 1.0), 0.0, 1.0)
		_band(vs.y * 0.26, 100 if banner_sub != "" else 92, a)
		_text(banner_text, Vector2(0, vs.y * 0.26 + 56), 42, Color(BONE, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 6)
		if banner_sub != "":
			_text(banner_sub, Vector2(0, vs.y * 0.26 + 86), 17, Color("f2d27a", a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	if state == "dead" or state == "win":
		var a2 := clampf(end_timer / 1.2, 0.0, 1.0)
		var win := state == "win"
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45 * a2) if win else Color(0.12, 0, 0, 0.6 * a2))
		_band(vs.y * 0.5 - 80, 160, a2)
		var msg := "PRINCESS RESCUED" if win else "YOU DIED"
		_text(msg, Vector2(0, vs.y * 0.5 + 30), 70 if win else 104, Color("d8b25a", a2) if win else Color("9a1c14", a2), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 8)
		if end_timer > 2.2:
			var sub := "THE KINGDOM OF ELDORIA IS SAVED" if win else "SOULS LOST: %d" % lost_souls
			_text(sub, Vector2(0, vs.y * 0.5 + 100), 16, Color(BONE, 0.7), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
			_text("TAP TO RETURN" if win else "TAP TO TRY AGAIN", Vector2(0, vs.y * 0.5 + 130), 15, Color(BONE, 0.45 + 0.35 * sin(t * 3.0)), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
