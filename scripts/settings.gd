extends Node
## Player settings (autoload): music / sound-effect mute and a six-step graphics quality. Saved to user://settings.cfg.
## Audio goes through two buses ("Music", "SFX") that this script creates, so muting is just a bus mute.

signal changed

const UI := preload("res://scripts/ui.gd")
const FILE := "user://settings.cfg"

const NAMES := ["VERY LOW", "LOW", "MEDIUM", "HIGH", "VERY HIGH", "REALISTIC"]
const FPS_OPTIONS := [30, 45, 60, 90, 120, 0]
const FPS_NAMES := ["30 FPS", "45 FPS", "60 FPS", "90 FPS", "120 FPS", "UNLIMITED"]
## Per level:
##  res    3D render height cap in pixels (0 = the screen's native resolution); phones have 1200+ px tall screens, so most levels render below native
##  aa     0 none, 1 FXAA (cheap post filter), 2 MSAA 2x, 3 MSAA 4x
##  shadow / sdist / ssize / splits   moon shadow on/off, distance (m), map size, cascades (1 = one cheap pass)
##  far    camera far plane          aniso   anisotropic filter       parts   particle amount multiplier
##  mesh / lods   terrain mesh size and number of detail rings
##  tshadow terrain casts shadows    dual / macro / proj / bg   terrain shader extras (dual texture scale, macro colour variation,
##                                    slope projection, world background 0 none 1 flat 2 noise)
##  sky    procedural sky (off = plain colour, saves a full-screen shader)   glow   bloom
##  cap / props / edist / lights / hud   max enemies alive, camp decoration density, enemy draw distance, active lights, HUD redraw interval
const LEVELS := [
	{"res": 540, "aa": 0, "shadow": false, "sdist": 0.0, "ssize": 1024, "splits": 1, "far": 100.0, "aniso": 0, "parts": 0.3, "mesh": 16, "lods": 5,
		"tshadow": false, "dual": false, "macro": false, "proj": false, "bg": 0, "sky": false, "glow": false,
		"forest": [14, 26, 44, 0.4], "cap": 3, "props": 0.35, "edist": 30, "lights": 2, "hud": 2,
		"desc": "540p, no shadows, plain ground shader, few lights. For weak or hot phones (4 GB class)."},
	{"res": 648, "aa": 0, "shadow": false, "sdist": 0.0, "ssize": 1024, "splits": 1, "far": 130.0, "aniso": 0, "parts": 0.5, "mesh": 24, "lods": 6,
		"tshadow": false, "dual": false, "macro": false, "proj": false, "bg": 0, "sky": false, "glow": false,
		"forest": [18, 34, 58, 0.55], "cap": 4, "props": 0.5, "edist": 38, "lights": 3, "hud": 1,
		"desc": "648p, no shadows, simple ground shader. Smooth on most phones."},
	{"res": 720, "aa": 1, "shadow": true, "sdist": 25.0, "ssize": 1024, "splits": 1, "far": 170.0, "aniso": 2, "parts": 0.75, "mesh": 32, "lods": 7,
		"tshadow": false, "dual": false, "macro": false, "proj": false, "bg": 1, "sky": false, "glow": false,
		"forest": [24, 44, 76, 0.7], "cap": 5, "props": 0.75, "edist": 55, "lights": 4, "hud": 1,
		"desc": "720p, edge smoothing and close-range shadows."},
	{"res": 864, "aa": 1, "shadow": true, "sdist": 35.0, "ssize": 2048, "splits": 1, "far": 220.0, "aniso": 4, "parts": 1.0, "mesh": 40, "lods": 7,
		"tshadow": false, "dual": false, "macro": true, "proj": false, "bg": 1, "sky": true, "glow": false,
		"forest": [30, 54, 96, 0.85], "cap": 7, "props": 1.0, "edist": 75, "lights": 6, "hud": 1,
		"desc": "864p, edge smoothing, sky, shadows and colour variation on the ground."},
	{"res": 1080, "aa": 2, "shadow": true, "sdist": 50.0, "ssize": 2048, "splits": 1, "far": 300.0, "aniso": 8, "parts": 1.0, "mesh": 48, "lods": 7,
		"tshadow": false, "dual": false, "macro": true, "proj": true, "bg": 1, "sky": true, "glow": false,
		"forest": [36, 64, 116, 1.0], "cap": 8, "props": 1.0, "edist": 90, "lights": 6, "hud": 1,
		"desc": "1080p, 2x anti-aliasing, longer shadows, slope-projected ground textures. Tuned to stay smooth on mid-range phones."},
	{"res": 0, "aa": 3, "shadow": true, "sdist": 90.0, "ssize": 4096, "splits": 2, "far": 550.0, "aniso": 16, "parts": 1.4, "mesh": 64, "lods": 7,
		"tshadow": true, "dual": true, "macro": true, "proj": true, "bg": 2, "sky": true, "glow": true,
		"forest": [46, 84, 150, 1.15], "cap": 9, "props": 1.0, "edist": 100, "lights": 10, "hud": 1,
		"desc": "Native resolution, 4x anti-aliasing, cascaded shadows, glow, full ground shader. Needs a flagship device."},
]

var music_on := true
var sfx_on := true
var quality := 3
var fps_idx := 2          # index into FPS_OPTIONS
var show_fps := false
var auto_quality := true  # lowers the graphics level by itself when the frame rate is poor
var _panel: Control


func _ready() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	quality = 3
	if OS.has_feature("mobile"):
		# first-run default by physical memory: 4 GB class phones start at the lowest level, 8 GB+ at medium
		var gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
		quality = 0 if gb <= 4.6 else (1 if gb <= 6.6 else 2)
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		music_on = bool(cf.get_value("audio", "music", true))
		sfx_on = bool(cf.get_value("audio", "sfx", true))
		quality = clampi(int(cf.get_value("video", "quality", quality)), 0, LEVELS.size() - 1)
		fps_idx = clampi(int(cf.get_value("video", "fps", fps_idx)), 0, FPS_OPTIONS.size() - 1)
		show_fps = bool(cf.get_value("video", "show_fps", false))
		auto_quality = bool(cf.get_value("video", "auto", true))
	_apply_audio()
	poll_device()
	_apply_fps()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_on)
	cf.set_value("audio", "sfx", sfx_on)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "fps", fps_idx)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("video", "auto", auto_quality)
	cf.save(FILE)


func _apply_audio() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)


func _apply_fps() -> void:
	var cap := int(FPS_OPTIONS[fps_idx])
	# Battery Game Mode / battery saver / a hot phone: hold 30 fps, which keeps the chip cool and the frame pacing even
	if OS.has_feature("mobile") and eco() and (cap == 0 or cap > 30):
		cap = 30
	elif OS.has_feature("mobile") and game_mode == 2 and cap == 0:
		cap = int(maxf(refresh_hz, 60.0))
	Engine.max_fps = cap


func set_fps(i: int) -> void:
	fps_idx = clampi(i, 0, FPS_OPTIONS.size() - 1)
	_apply_fps()
	_save()
	changed.emit()


func set_auto(on: bool) -> void:
	auto_quality = on
	_save()
	changed.emit()


func part_mult() -> float:
	return float(LEVELS[quality].parts)


func max_lights() -> int:
	return int(LEVELS[quality].lights)


func enemy_cap() -> int:
	return int(LEVELS[quality].cap)


func prop_mult() -> float:
	return float(LEVELS[quality].props)


func enemy_dist() -> float:
	return float(LEVELS[quality].edist)


func set_show_fps(on: bool) -> void:
	show_fps = on
	_save()
	changed.emit()


func set_music(on: bool) -> void:
	music_on = on
	_apply_audio()
	_save()
	changed.emit()


func set_sfx(on: bool) -> void:
	sfx_on = on
	_apply_audio()
	_save()
	changed.emit()


# ------------------------------------------------------------------ device state (Android Game Mode, heat, battery saver)
var game_mode := 0        # Android GameManager: 0 unknown, 1 standard, 2 performance, 3 battery
var thermal := 0          # PowerManager thermal status 0 (none) .. 6 (shutdown)
var power_save := false
var gpu_name := ""
var refresh_hz := 60.0
var base_scale := 1.0     # the quality level's render scale
var dyn_scale := 1.0      # 0.62..1.0 multiplier chosen on the fly from the measured frame time
var _poll_t := 0.0


func game_mode_name() -> String:
	return ["NOT REPORTED", "STANDARD", "PERFORMANCE", "BATTERY"][clampi(game_mode, 0, 3)]


## Asks Android which Game Mode the player picked for this game, how hot the phone is and whether the battery saver is on. Every call is guarded:
## any failure (older Android, no singleton) simply leaves the values alone.
func poll_device() -> void:
	refresh_hz = DisplayServer.screen_get_refresh_rate()
	if refresh_hz <= 0.0:
		refresh_hz = 60.0
	gpu_name = RenderingServer.get_video_adapter_name()
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return
	var rt = Engine.get_singleton("AndroidRuntime")
	var ctx = rt.getApplicationContext() if rt != null else null
	if ctx == null:
		return
	var gm = ctx.getSystemService("game")
	if gm != null:
		var m = gm.getGameMode()
		if typeof(m) == TYPE_INT:
			game_mode = int(m) if int(m) in [1, 2, 3] else 1
	var pm = ctx.getSystemService("power")
	if pm != null:
		var th = pm.getCurrentThermalStatus()
		if typeof(th) == TYPE_INT:
			thermal = int(th)
		power_save = bool(pm.isPowerSaveMode())


## Called a few times a second from the game: re-reads the device state now and then and works out the frame-rate cap it asks for.
func device_tick(dt: float) -> void:
	_poll_t -= dt
	if _poll_t > 0.0:
		return
	_poll_t = 6.0
	var before := [game_mode, thermal, power_save]
	poll_device()
	if before != [game_mode, thermal, power_save]:
		changed.emit()
	_apply_fps()


## True when the phone (or the player's Game Mode choice) wants less work done: battery mode, battery saver or a hot chip.
func eco() -> bool:
	return game_mode == 3 or power_save or thermal >= 3


func set_quality(q: int) -> void:
	quality = clampi(q, 0, LEVELS.size() - 1)
	_save()
	changed.emit()


## Applies the current quality to a running game (the node must expose cam, moon, env, fx, terrain, embers).
func apply_to(game: Node) -> void:
	var lv: Dictionary = LEVELS[quality]
	var vp: Viewport = game.get_viewport()
	# render height in pixels, capped per level (the HUD still draws at full sharpness)
	var short_px := float(mini(DisplayServer.window_get_size().x, DisplayServer.window_get_size().y))
	var scale := 1.0 if int(lv.res) == 0 else clampf(float(lv.res) / maxf(short_px, 1.0), 0.3, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	base_scale = scale
	vp.scaling_3d_scale = clampf(scale * dyn_scale, 0.3, 1.0)
	var aa := int(lv.aa)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_2X if aa == 2 else (Viewport.MSAA_4X if aa == 3 else Viewport.MSAA_DISABLED)
	vp.anisotropic_filtering_level = {0: Viewport.ANISOTROPY_DISABLED, 2: Viewport.ANISOTROPY_2X, 4: Viewport.ANISOTROPY_4X,
		8: Viewport.ANISOTROPY_8X, 16: Viewport.ANISOTROPY_16X}[int(lv.aniso)]
	RenderingServer.directional_shadow_atlas_set_size(int(lv.ssize), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if quality >= 4 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	if game.get("moon") != null:
		var moon: DirectionalLight3D = game.moon
		moon.shadow_enabled = bool(lv.shadow)
		moon.directional_shadow_max_distance = maxf(float(lv.sdist), 1.0)
		# one cascade = the scene is drawn once into the shadow map instead of up to four times
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if int(lv.splits) == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if game.get("cam") != null and game.cam != null:
		game.cam.far = float(lv.far)
	if game.get("env") != null and game.env != null:
		var env: Environment = game.env
		env.glow_enabled = bool(lv.glow)
		env.glow_intensity = 0.6 if quality < 5 else 0.9
		env.background_mode = Environment.BG_SKY if bool(lv.sky) else Environment.BG_COLOR
		env.background_color = Color("0b1233")
	if game.get("terrain") != null and game.terrain != null:
		var t = game.terrain
		if "mesh_size" in t:
			t.mesh_size = int(lv.mesh)
		if "mesh_lods" in t:
			t.mesh_lods = int(lv.lods)
		if "cast_shadows" in t:
			t.cast_shadows = 1 if bool(lv.tshadow) else 0
		var m = t.material
		if m != null:
			# the ground shader is the heaviest fragment shader in the game: switch its extras off on weaker levels
			m.dual_scaling = bool(lv.dual)
			m.enable_macro_variation = bool(lv.macro)
			m.enable_projection = bool(lv.proj)
			m.world_background = int(lv.bg)
	if game.get("forest") != null:
		var fo: Array = lv.forest
		game.forest.set_params(float(fo[0]), float(fo[1]), float(fo[2]), float(fo[3]))
	for node in [game.get("embers"), game.fx.rain if game.get("fx") != null else null]:
		if node is CPUParticles3D:
			if not node.has_meta("base_amount"):
				node.set_meta("base_amount", node.amount)
			node.amount = maxi(int(float(node.get_meta("base_amount")) * float(lv.parts)), 8)


func hud_every() -> int:
	return int(LEVELS[quality].hud)


## Builds the settings overlay. Add the returned node to a CanvasLayer / Control; call on_close when BACK is pressed.
func build_panel(on_close: Callable) -> Control:
	var o := UI.overlay("SETTINGS")
	var root: Control = o.root
	var box: VBoxContainer = o.box
	box.custom_minimum_size = Vector2(520, 0)
	var toggles := {}
	var rows := [["MUSIC", "music"], ["SOUND EFFECTS", "sfx"]]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var l := UI.label(r[0], 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var key: String = r[1]
		var b := UI.button("", func(): pass, 140.0)
		b.pressed.connect(func():
			if key == "music":
				set_music(not music_on)
			else:
				set_sfx(not sfx_on))
		toggles[key] = b
		row.add_child(b)
		box.add_child(row)
	var gtitle := UI.label("GRAPHICS", 22)
	box.add_child(gtitle)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 10)
	var prev := UI.button("<", func(): set_quality(quality - 1), 70.0)
	var qname := UI.label("", 24, UI.EMBER, HORIZONTAL_ALIGNMENT_CENTER)
	qname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nxt := UI.button(">", func(): set_quality(quality + 1), 70.0)
	grow.add_child(prev)
	grow.add_child(qname)
	grow.add_child(nxt)
	box.add_child(grow)
	var desc := UI.label("", 15, Color(UI.BONE, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(480, 44)
	box.add_child(desc)
	box.add_child(UI.label("FRAME RATE", 22))
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 10)
	var fprev := UI.button("<", func(): set_fps(fps_idx - 1), 70.0)
	var fname := UI.label("", 24, UI.EMBER, HORIZONTAL_ALIGNMENT_CENTER)
	fname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fnext := UI.button(">", func(): set_fps(fps_idx + 1), 70.0)
	frow.add_child(fprev)
	frow.add_child(fname)
	frow.add_child(fnext)
	box.add_child(frow)
	var shrow := HBoxContainer.new()
	var arow := HBoxContainer.new()
	var al := UI.label("AUTO-LOWER WHEN SLOW", 22)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(al)
	var ab := UI.button("", func(): set_auto(not auto_quality), 140.0)
	arow.add_child(ab)
	box.add_child(arow)
	var shl := UI.label("SHOW FPS COUNTER", 22)
	shl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shrow.add_child(shl)
	var shb := UI.button("", func(): set_show_fps(not show_fps), 140.0)
	shrow.add_child(shb)
	box.add_child(shrow)
	var dev := UI.label("", 14, Color(UI.BONE, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev.custom_minimum_size = Vector2(480, 40)
	box.add_child(dev)
	var back := UI.button("BACK", func():
		root.visible = false
		on_close.call(), 320.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)

	var refresh := func():
		(toggles["music"] as Button).text = "ON" if music_on else "OFF"
		(toggles["sfx"] as Button).text = "ON" if sfx_on else "OFF"
		qname.text = "%d / %d    %s" % [quality + 1, LEVELS.size(), NAMES[quality]]
		desc.text = str(LEVELS[quality].desc)
		prev.disabled = quality <= 0
		nxt.disabled = quality >= LEVELS.size() - 1
		fname.text = str(FPS_NAMES[fps_idx])
		fprev.disabled = fps_idx <= 0
		fnext.disabled = fps_idx >= FPS_OPTIONS.size() - 1
		shb.text = "ON" if show_fps else "OFF"
		ab.text = "ON" if auto_quality else "OFF"
		dev.text = "GAME MODE: %s   |   %d Hz   |   HEAT %d/6%s\n%s" % [game_mode_name(), int(refresh_hz), thermal, "   |   BATTERY SAVER" if power_save else "", gpu_name]
	refresh.call()
	changed.connect(refresh)
	root.tree_exiting.connect(func(): changed.disconnect(refresh))
	root.visible = false
	return root
