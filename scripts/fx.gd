extends RefCounted
## Weather + lightning: rain, thunder flashes, jagged bolts, and the booms that follow.

const Sfx := preload("res://scripts/sfx.gd")

var game: Node3D
var env: Environment
var base_ambient := 1.5
var flash_light: DirectionalLight3D
var rain: CPUParticles3D
var rain_player: AudioStreamPlayer
var flash_i := 0.0         # 0..1 current flash intensity (HUD overlay reads this)
var _flash_t := 99.0
var _flash_len := 0.5
var _flash_pow := 1.0
var _timer := 6.0
var _interval := [9.0, 18.0]
var _bolts: Array = []
var _bolt_mat: StandardMaterial3D
var _thunder: AudioStreamWAV
var _crack: AudioStream
var _rolls: Array = []
var _bolt_snd: AudioStreamWAV
var _players: Array = []
var _next_player := 0
var intensity := 1.0       # multiplier for scarier boss fights
var dark := 0.0            # 1 = pitch black (inside the labyrinth: only torches give light)
var _fog_base := Color(0.03, 0.04, 0.09)
var indoor := 0.0          # 0 outside .. 1 deep inside the tunnel


func setup(g: Node3D, environment: Environment) -> void:
	game = g
	env = environment
	base_ambient = env.ambient_light_energy
	flash_light = DirectionalLight3D.new()
	flash_light.rotation_degrees = Vector3(-70, 20, 0)
	flash_light.light_color = Color(0.8, 0.88, 1.0)
	flash_light.light_energy = 0.0
	game.add_child(flash_light)

	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.albedo_color = Color(1.0, 1.0, 1.0)
	_bolt_mat.emission_enabled = true
	_bolt_mat.emission = Color(0.7, 0.85, 1.0)
	_bolt_mat.emission_energy_multiplier = 8.0
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# rain streaks that follow the camera focus
	rain = CPUParticles3D.new()
	rain.amount = 300
	rain.lifetime = 0.6
	rain.preprocess = 0.6
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(22, 0.1, 18)
	rain.direction = Vector3(0.1, -1, 0.05)
	rain.spread = 2.0
	rain.initial_velocity_min = 26.0
	rain.initial_velocity_max = 31.0
	rain.gravity = Vector3(0, -8, 0)
	rain.particle_flag_align_y = true
	rain.local_coords = false
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, 0.55, 0.012)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.72, 0.82, 1.0, 0.32)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.material = rmat
	rain.mesh = rm
	rain.position = Vector3(0, 16, 0)
	game.add_child(rain)

	_thunder = Sfx.make("thunder")
	_bolt_snd = Sfx.make("bolt")
	# real recordings (CC0, assets/audio): a sharp close crack and two rolling rumbles; the synthesised thunder is the fallback
	_crack = _load_clip("thunder_crack")
	for n in ["thunder_roll_a", "thunder_roll_b"]:
		var c := _load_clip(n)
		if c != null:
			_rolls.append(c)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		game.add_child(p)
		_players.append(p)
	rain_player = AudioStreamPlayer.new()
	rain_player.bus = "SFX"
	var rain_clip := _load_clip("rain_loop", true)
	rain_player.stream = rain_clip if rain_clip != null else Sfx.make("rain")
	rain_player.volume_db = -13.0 if rain_clip != null else -20.0
	game.add_child(rain_player)
	rain_player.play()


func _load_clip(name: String, loop: bool = false) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		return null
	var st = load(path)
	if st is AudioStreamWAV:
		var wav := st as AudioStreamWAV
		if loop:
			var bytes := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / bytes
		return wav
	return null


func set_chapter(ch: Dictionary) -> void:
	env.fog_light_color = ch.fog
	_fog_base = ch.fog
	env.ambient_light_color = ch.ambient
	_interval = ch.thunder
	rain.amount = int(ch.rain)
	_timer = randf_range(2.0, 5.0)


func update(dt: float, focus: Vector3) -> void:
	rain.position = focus + Vector3(0, 16.0, 0)
	# periodic ambient lightning
	_timer -= dt
	if _timer <= 0.0:
		_timer = randf_range(_interval[0], _interval[1]) / intensity
		var a := randf() * TAU
		var d := randf_range(25.0, 55.0)
		var sp := Vector2(focus.x + cos(a) * d, focus.z + sin(a) * d)
		ambient_strike(Vector3(sp.x, game._h(sp), sp.y))
	# flash envelope: sharp double flicker that decays
	_flash_t += dt
	if _flash_t < _flash_len:
		var u := _flash_t / _flash_len
		var flick := 0.55 + 0.45 * absf(sin(_flash_t * 46.0))
		flash_i = clampf((1.0 - u) * (1.0 - u) * flick * _flash_pow, 0.0, 1.0)
	else:
		flash_i = 0.0
	var lit := maxf(indoor, dark)
	flash_light.light_energy = 3.2 * flash_i * (1.0 - lit)
	env.ambient_light_energy = (base_ambient * (1.0 - 0.72 * indoor) + 3.0 * flash_i * (1.0 - lit)) * (1.0 - 0.94 * dark)
	rain.visible = lit < 0.5
	env.fog_density = lerpf(0.012, 0.03, indoor) + 0.02 * dark
	env.fog_light_color = _fog_base.lerp(Color(0.004, 0.004, 0.008), dark)
	# bolt fade-out
	for b in _bolts:
		b.t += dt
		var mi: MeshInstance3D = b.node
		var k: float = clampf(1.0 - b.t / b.life, 0.0, 1.0)
		mi.transparency = 1.0 - k
	_bolts = _bolts.filter(func(b):
		if b.t >= b.life:
			b.node.queue_free()
			return false
		return true)


func _play(stream: AudioStream, vol: float, pitch: float, delay: float) -> void:
	if delay > 0.0:
		game.get_tree().create_timer(delay).timeout.connect(func(): _play(stream, vol, pitch, 0.0))
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


## Distant lightning with a delayed rumble (more delay = further away).
func ambient_strike(pos: Vector3) -> void:
	_make_bolt(pos + Vector3(0, 0, 0), 38.0, 0.34)
	pulse(0.55, 0.55)
	var dist := Vector2(pos.x, pos.z).distance_to(Vector2(game.cam_focus.x, game.cam_focus.z))
	var delay := clampf(dist / 40.0, 0.25, 1.6)
	if _crack != null and not _rolls.is_empty():
		# near strikes crack, far ones only rumble (muffled), like real thunder
		if dist < 32.0:
			_play(_crack, -4.0, randf_range(0.92, 1.05), delay)
		else:
			_play(_rolls[randi() % _rolls.size()], -3.0, randf_range(0.9, 1.05), delay)
	else:
		_play(_thunder, -4.0, randf_range(0.85, 1.1), delay)


## Strike at a specific ground position (boss attacks, Thunder Smite).
func strike(pos: Vector3) -> void:
	_make_bolt(pos, 30.0, 0.4)
	pulse(0.9, 0.45)
	if _crack != null and not _rolls.is_empty():
		_play(_crack, -1.0, randf_range(0.95, 1.08), 0.0)
		_play(_rolls[randi() % _rolls.size()], -9.0, randf_range(0.95, 1.1), 0.7)
	else:
		_play(_bolt_snd, 0.0, randf_range(0.9, 1.1), 0.0)
		_play(_thunder, -8.0, randf_range(1.0, 1.25), 0.25)


func pulse(power: float, length: float) -> void:
	_flash_t = 0.0
	_flash_len = length
	_flash_pow = power


func _make_bolt(ground: Vector3, height: float, life: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	var top := ground + Vector3(randf_range(-6, 6), height, randf_range(-6, 6))
	var segs := 12
	for i in segs + 1:
		var u := float(i) / segs
		var p := top.lerp(ground, u)
		if i > 0 and i < segs:
			p += Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6)) * (1.0 - absf(u - 0.5) * 0.6)
		pts.append(p)
	_ribbon(st, pts, 0.15)
	# one or two forks
	for f in 2:
		var si := randi_range(3, 8)
		var fork: Array = [pts[si]]
		var dir := Vector3(randf_range(-1, 1), -0.7, randf_range(-1, 1)).normalized()
		for j in 4:
			fork.append(fork[j] + dir * 2.2 + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
		_ribbon(st, fork, 0.1)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _bolt_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(mi)
	_bolts.append({"node": mi, "t": 0.0, "life": life})
	# ground flare
	game._burst(Vector2(ground.x, ground.z), 14, Color(0.8, 0.9, 1.0), 7.0, 0.3)


func _ribbon(st: SurfaceTool, pts: Array, w: float) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := (b - a).normalized()
		for axis in [Vector3.RIGHT, Vector3.FORWARD]:
			var side: Vector3 = d.cross(axis).normalized() * w
			if side.length() < 0.001:
				continue
			st.add_vertex(a - side)
			st.add_vertex(a + side)
			st.add_vertex(b + side)
			st.add_vertex(a - side)
			st.add_vertex(b + side)
			st.add_vertex(b - side)
