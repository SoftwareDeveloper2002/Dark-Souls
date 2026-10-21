extends Node
## Recorded voices (CC0, assets/audio/vox): the hero's grunts and cries, every enemy's battle cry / taunt / pain / death sound,
## and the forest soundscape: wind, crickets and unseen monsters that circle and snarl in the dark.

const DIR := "res://assets/audio/vox/"
const COUNTS := {
	"hero_hurt": 7, "hero_effort": 3, "cry": 12, "gru": 4,
	"crt_roar": 3, "crt_roar2": 3, "crt_troll": 3, "crt_bark": 2, "crt_scream": 2, "crt_grunt": 5, "crt_grunt2": 4,
	"crt_attack": 5, "crt_die": 4, "crt_hurt": 5, "crt_mon": 20, "crt_snarl": 5,
}

## Per enemy type: sound groups for each moment, pitch range (lower = bigger), volume offset and the words shouted (text bubble).
const VOICES := {
	"hollow": {"cry": "cry", "hit": "gru", "die": "cry", "taunt": "cry", "pitch": [0.95, 1.08], "vol": -3.0,
		"lines": {"cry": ["Hrraaah!", "For the Order!", "Die, intruder!", "Cut him down!"], "taunt": ["You are not welcome here!", "Run while you can!", "There is no way out!"]}},
	"knight": {"cry": "cry", "hit": "gru", "die": "cry", "taunt": "cry", "pitch": [0.88, 0.98], "vol": -2.0,
		"lines": {"cry": ["Hold the line!", "Shields up!", "None shall pass!"], "taunt": ["Your blade is nothing!", "Kneel, Ashen one!", "Steel beats sorrow!"]}},
	"captain": {"cry": "cry", "hit": "gru", "die": "cry", "taunt": "cry", "pitch": [0.82, 0.92], "vol": 1.0,
		"lines": {"cry": ["Fall in! Crush him!", "You face a captain of the Order!"], "taunt": ["Is that all you have?", "I have broken better men!", "Come, die with honour!"]}},
	"stonesoldier": {"cry": "cry", "hit": "gru", "die": "crt_die", "taunt": "crt_mon", "pitch": [0.8, 0.92], "vol": -1.0,
		"lines": {"cry": ["Stone does not yield!", "Crush!"], "taunt": ["We were never alive...", "Turn to dust!"]}},
	"skeleton": {"cry": "crt_grunt", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_grunt2", "pitch": [0.9, 1.05], "vol": -5.0,
		"lines": {"cry": ["Bones remember...", "Join us!"], "taunt": ["Dust to dust!", "The dead never rest!"]}},
	"archer": {"cry": "cry", "hit": "gru", "die": "cry", "taunt": "cry", "pitch": [0.98, 1.1], "vol": -4.0,
		"lines": {"cry": ["Loose!", "Arrows ready!"], "taunt": ["I have you in my sights!", "You cannot dodge them all!"]}},
	"mage": {"cry": "cry", "hit": "gru", "die": "cry", "taunt": "cry", "pitch": [1.0, 1.12], "vol": -4.0,
		"lines": {"cry": ["Burn!", "The dark hungers!"], "taunt": ["Feel the flame!", "Knowledge is power!"]}},
	"imp": {"cry": "crt_scream", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_bark", "pitch": [0.95, 1.15], "vol": -4.0,
		"lines": {"cry": ["Skreee!", "Hee-hee-hee!"], "taunt": ["Tasty knight!", "Catch me, catch me!"]}},
	"zombie": {"cry": "crt_mon", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_grunt", "pitch": [0.82, 0.96], "vol": -2.0,
		"lines": {"cry": ["Uuurrgh...", "Brainsss..."], "taunt": ["Hungry...", "Staaay..."]}},
	"ghoul": {"cry": "crt_scream", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_snarl", "pitch": [0.9, 1.05], "vol": -2.0,
		"lines": {"cry": ["Skreeeee!", "Flesh!"], "taunt": ["More meat!", "So hungry!"]}},
	"hound": {"cry": "crt_bark", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_snarl", "pitch": [0.9, 1.1], "vol": -1.0,
		"lines": {"cry": ["*BARK BARK!*", "*GRRR!*"], "taunt": ["*SNARL*", "*GROWL*"]}},
	"fiend": {"cry": "crt_roar", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_snarl", "pitch": [0.86, 1.0], "vol": 0.0,
		"lines": {"cry": ["ROOOAR!", "I will tear you apart!"], "taunt": ["Mine!", "Your bones will crack!"]}},
	"brute": {"cry": "crt_troll", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_troll", "pitch": [0.8, 0.92], "vol": 1.0,
		"lines": {"cry": ["SMASH!", "RAAARGH!"], "taunt": ["Little man... squash!", "Me crush you!"]}},
	"demon": {"cry": "crt_roar2", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_roar", "pitch": [0.76, 0.9], "vol": 3.0, "lines": {}},
	"serpent": {"cry": "crt_scream", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_snarl", "pitch": [0.82, 0.96], "vol": 2.0, "lines": {}},
	"cyborg": {"cry": "crt_mon", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_mon", "pitch": [0.72, 0.84], "vol": 3.0, "lines": {}},
	"malakar": {"cry": "crt_roar", "hit": "crt_hurt", "die": "crt_die", "taunt": "crt_roar2", "pitch": [0.74, 0.86], "vol": 4.0, "lines": {}},
}
const LURK := ["crt_howl", "crt_snarl", "crt_mon", "crt_roar", "crt_grunt2", "crt_bark"]

var g  # the game node
var _cache := {}
var _pool: Array = []
var _pi := 0
var _lurk_t := 9.0
var _gust_t := 14.0
var _chain: Array = []
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _recent := 0.0


func setup(game: Node3D) -> void:
	g = game
	if AudioServer.get_bus_index("Lurk") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Lurk")
		AudioServer.set_bus_send(i, "SFX")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 1900.0
		AudioServer.add_bus_effect(i, lp)
	for k in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_wind = _bed("amb_wind", -24.0, true)
	_crickets = _bed("amb_crickets", -22.0, true)


func _bed(name: String, vol: float, loop: bool) -> AudioStreamPlayer:
	var st := clip(name)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = st
	p.volume_db = vol
	add_child(p)
	p.play()
	return p


## Loads (once) a clip from the library by base name, trying ogg, wav and mp3.
func clip(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var st: AudioStream = null
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = DIR + name + ext
		if ResourceLoader.exists(path):
			st = load(path) as AudioStream
			break
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = name.begins_with("amb_")
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = name.begins_with("amb_")
	_cache[name] = st
	return st


## Plays a boss's spoken trash-talk line (say_boss_<boss>_<words>.wav, a synthesised voice made menacing per boss). Returns its length in
## seconds, or -1 if there is no recording for that line.
func boss_line(type: String, text: String, dist: float) -> float:
	var n := _say_name("boss_" + type, text)
	var st := clip(n)
	if st == null:
		return -1.0
	play(n, 1.0 - clampf(dist * 0.12, 0.0, 9.0), 1.0)
	return st.get_length()


## File name of the spoken version of an enemy's line (say_<type>_<words>).
func _say_name(type: String, line: String) -> String:
	var slug := ""
	for ch in line.to_lower():
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return "say_%s_%s" % [type, "_".join(slug.split("_", false))]


## Loads every clip once, a few per frame, behind the loading screen so no sound ever has to be read from storage in the middle of a fight.
func warm() -> void:
	var names: Array = []
	for group in COUNTS:
		for i in int(COUNTS[group]):
			names.append("%s_%d" % [group, i + 1])
	names.append_array(["hero_die", "mk_fatality", "mk_finish_him", "crt_howl"])
	for cn in g.Civilians.SAYS + g.Civilians.FREE + g.Civilians.STAYS + g.Civilians.FOLLOWS:
		names.append("say_civ_" + cn)
	if g != null and g.get("talk") != null:
		for btype in g.talk.LINES:
			for key in g.talk.LINES[btype]:
				for line in g.talk.LINES[btype][key]:
					names.append(_say_name("boss_" + btype, line))
	for type in VOICES:
		var lines: Dictionary = VOICES[type].get("lines", {})
		for key in lines:
			for line in lines[key]:
				names.append(_say_name(type, line))
	var k := 0
	for n in names:
		clip(n)
		k += 1
		if k % 8 == 0:
			await g.get_tree().process_frame


func _pick(group: String) -> String:
	var n: int = COUNTS.get(group, 1)
	return "%s_%d" % [group, randi_range(1, n)]


func play(name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	var st := clip(name)
	if st == null:
		return
	var p: AudioStreamPlayer = _pool[_pi]
	_pi = (_pi + 1) % _pool.size()
	p.stream = st
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


func play_group(group: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	play(_pick(group), vol, pitch)


# ------------------------------------------------------------------ hero

func hero_hurt() -> void:
	play_group("hero_hurt", 1.0, randf_range(0.92, 1.06))


func hero_effort(heavy: bool = false) -> void:
	if randf() < (0.8 if heavy else 0.3):
		play_group("hero_effort", -4.0 if not heavy else -1.0, randf_range(0.9, 1.05))


func hero_die() -> void:
	play("hero_die", 2.0, 1.0)


# ------------------------------------------------------------------ enemies

## One enemy voices an event: "cry" (battle cry on seeing the hero), "taunt", "hit", "die" or "attack".
## Returns the line to show above its head ("" if none). Enemies are quiet when far away and never all shout at once.
func enemy(e: Dictionary, event: String) -> String:
	var v: Dictionary = VOICES.get(e.type, {})
	if v.is_empty() or g == null:
		return ""
	if float(e.get("vcd", 0.0)) > 0.0 and event != "die" and event != "cry":
		return ""
	if _recent > 0.9 and event != "die":
		return ""
	var dist: float = g.p_pos.distance_to(e.pos)
	if dist > 60.0 and not e.boss:
		return ""
	var group: String = v.get("hit" if event == "hit" else ("die" if event == "die" else ("taunt" if event == "taunt" else "cry")), "crt_grunt")
	if event == "attack":
		group = v.get("cry", "crt_grunt")
	var pr: Array = v.pitch
	var vol: float = float(v.vol) - clampf(dist * 0.25, 0.0, 18.0)
	if event == "hit":
		vol -= 3.0
	if event == "attack":
		vol -= 3.0
	var lines: Dictionary = v.get("lines", {})
	var key := "cry" if event == "attack" else event
	var line := ""
	if lines.has(key) and (event == "cry" or event == "taunt" or (event == "attack" and randf() < 0.3)):
		var pool: Array = lines[key]
		line = pool[randi() % pool.size()]
	e["vcd"] = 1.2 if event == "hit" else (4.0 if event == "attack" else 2.5)
	_recent += 0.35
	# a spoken line is voiced for real (say_*.wav, made with a speech synthesiser and roughened per enemy); otherwise a creature clip
	var said := false
	if line != "":
		var sname := _say_name(e.type, line)
		if clip(sname) != null:
			play(sname, minf(vol + 7.0, 3.0), 1.0)
			e["vcd"] = 3.5
			said = true
	if not said:
		play(_pick(group), vol, randf_range(pr[0], pr[1]))
	return line


# ------------------------------------------------------------------ forest soundscape

func process(dt: float) -> void:
	_recent = maxf(0.0, _recent - dt)
	_lurk_t -= dt
	_gust_t -= dt
	if _wind != null:
		_wind.volume_db = -24.0 + sin(Time.get_ticks_msec() * 0.00025) * 4.0
	if _gust_t <= 0.0:
		_gust_t = randf_range(18.0, 40.0)
		play("amb_gust", randf_range(-18.0, -12.0), randf_range(0.8, 1.1))
	if not _chain.is_empty():
		for c in _chain:
			c.t -= dt
		var due: Array = _chain.filter(func(c): return c.t <= 0.0)
		for c in due:
			_lurk(c.dist, c.ang)
		_chain = _chain.filter(func(c): return c.t > 0.0)
	if _lurk_t <= 0.0:
		_lurk_t = randf_range(8.0, 19.0)
		var ang := randf() * TAU
		var dist := randf_range(32.0, 52.0)
		_lurk(dist, ang)
		# sometimes the thing comes closer: two more calls from the same direction
		if randf() < 0.35:
			_chain.append({"t": randf_range(2.2, 3.6), "dist": dist * 0.72, "ang": ang + randf_range(-0.2, 0.2)})
			_chain.append({"t": randf_range(5.0, 7.0), "dist": dist * 0.5, "ang": ang + randf_range(-0.3, 0.3)})


## A sound from something unseen, placed in the dark at a distance around the hero and muffled by the trees.
func _lurk(dist: float, ang: float) -> void:
	if g == null or g.state != "play":
		return
	var group: String = LURK[randi() % LURK.size()]
	var name := "crt_howl" if group == "crt_howl" else _pick(group)
	var st := clip(name)
	if st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "Lurk"
	p.volume_db = randf_range(-8.0, -2.0) - dist * 0.12
	p.pitch_scale = randf_range(0.65, 0.95) if group != "crt_howl" else randf_range(0.85, 1.05)
	p.max_distance = 110.0
	p.unit_size = 14.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	g.add_child(p)
	p.global_position = g.cam_focus + Vector3(cos(ang), 0.0, sin(ang)) * dist
	p.finished.connect(p.queue_free)
	p.play()
