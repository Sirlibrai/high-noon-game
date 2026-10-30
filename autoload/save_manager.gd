extends Node
## Persists settings and progress as JSON in user://. Same shape as the prototype's
## `highnoon:progress3` save so the rule functions in GameState port one to one.

const PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"

var data: Dictionary = {}
## Tests and scripted playthroughs turn this off so they never touch the player's save.
var persist := true


func _ready() -> void:
	load_game()


static func fresh_progress() -> Dictionary:
	return {
		"bucks": 0,
		"ch": [],
		"stats": {"shots": 0, "hits": 0, "kills": 0, "levels": 0, "perfect": 0, "bosses": 0, "earned": 0},
		"inv": {"guns": {"peacemaker": true}, "fins": {"peacemaker:0": true}, "equip": {"gun": "peacemaker", "fin": 0}},
		"hints": {},
	}


func load_game() -> void:
	data = {"settings": {"sound": true, "music": true}, "progress": fresh_progress()}
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data.settings.merge(parsed.get("settings", {}), true)
		var p: Variant = parsed.get("progress")
		if p is Dictionary:
			var base := fresh_progress()
			base.merge(p, true)
			base.stats = fresh_progress().stats.merged(p.get("stats", {}), true)
			data.progress = base


func save_game() -> void:
	if not persist:
		return
	# Write to a temp file then swap it in, so a crash mid-write never corrupts the save.
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(TMP_PATH, PATH)


func get_setting(key: String, default: Variant = null) -> Variant:
	return data.settings.get(key, default)


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	save_game()
