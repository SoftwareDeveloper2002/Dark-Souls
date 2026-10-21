extends RefCounted
## Tiny JSON save: progress is written after every quest.

const PATH := "user://savegame.json"
static var continue_game := false  # set by the title screen before loading the game scene


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func write(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func wipe() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
