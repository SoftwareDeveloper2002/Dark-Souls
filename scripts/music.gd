extends Node
## Background music that survives scene changes: calm adventure theme on the home screen, epic loop in the field.
## Tracks are CC0 from OpenGameArt: "Treasure Hunter" (TAD), "Determined Pursuit" (Emma_MA), "Epic Boss Battle" (Juhani Junkala),
## "Boss Battle #2" (nene).

const TRACKS := {
	"title": {"path": "res://assets/music/treasure_hunter.mp3", "db": -9.0},
	"game": {"path": "res://assets/music/determined_pursuit_loop.wav", "db": -11.0},
	"boss": {"path": "res://assets/music/boss_epic.wav", "db": -8.0},
	"final": {"path": "res://assets/music/boss_final.wav", "db": -8.0},
}
const FADE := 1.4

var _cur := ""
var _player: AudioStreamPlayer


func play(track: String) -> void:
	if track == _cur or not TRACKS.has(track):
		return
	_cur = track
	var stream = load(TRACKS[track].path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var bytes := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / bytes
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var old := _player
	var nxt := AudioStreamPlayer.new()
	nxt.stream = stream
	nxt.volume_db = -60.0
	nxt.bus = "Music"
	add_child(nxt)
	nxt.play()
	_player = nxt
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", float(TRACKS[track].db), FADE)
	if old != null:
		tw.tween_property(old, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(old.queue_free)
