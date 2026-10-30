extends Node
## Persists settings and progress as JSON in user://, in the same shape as the
## prototype's `highnoon:progress3` save so the rule functions in GameState
## port one to one.
##
## Survives restarts and crashes: every save is written to a temp file and
## swapped in, the previous save is kept as a backup, and loading falls back to
## the backup if the main file is unreadable. The game also saves when it goes
## to the background or quits. CloudSync merges in the same progress from iCloud
## with merge_progress(), which never loses stars, unlocks or purchases.

const VERSION := 1

var path := "user://save.json"
var data: Dictionary = {}
## Tests and scripted playthroughs turn this off so they never touch the player's save.
var persist := true
signal saved(data: Dictionary)


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_game()


static func fresh_progress() -> Dictionary:
	return {
		"bucks": 0,
		"ch": [],
		"stats": {"shots": 0, "hits": 0, "kills": 0, "levels": 0, "perfect": 0, "bosses": 0, "earned": 0, "clean": 0, "assisted": 0},
		"inv": {"guns": {"peacemaker": true}, "fins": {"peacemaker:0": true}, "equip": {"gun": "peacemaker", "fin": 0}},
		"hints": {},
		"avatar": {"name": "The Stranger", "hat": 0, "hatCol": 0, "skin": 2, "bandana": 1, "coat": 0, "face": 0},
		"avOwned": {},
		"seenOffice": false,
		"skins": {"active": "standard", "owned": {"standard": true}},
	}


static func fresh_data() -> Dictionary:
	return {"version": VERSION, "saved_at": 0.0, "settings": {"sound": true, "music": true}, "progress": fresh_progress()}


## Fills in anything a save is missing (older saves, or new fields added since).
static func normalised(parsed: Dictionary) -> Dictionary:
	var out := fresh_data()
	out.saved_at = float(parsed.get("saved_at", 0.0))
	out.settings.merge(parsed.get("settings", {}), true)
	var p: Variant = parsed.get("progress")
	if p is Dictionary:
		var base := fresh_progress()
		base.merge(p, true)
		for key in ["stats", "inv", "avatar", "skins"]:
			base[key] = fresh_progress()[key].merged(p.get(key, {}), true)
		out.progress = base
	return out


func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	return parsed if parsed is Dictionary and parsed.has("progress") else null


func load_game() -> void:
	var parsed: Variant = _read(path)
	if parsed == null:
		parsed = _read(path + ".bak")  # the main file was lost or damaged mid-write
	data = normalised(parsed) if parsed != null else fresh_data()


func save_game() -> void:
	if not persist:
		return
	data.version = VERSION
	data.saved_at = Time.get_unix_time_from_system()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	saved.emit(data)


func get_setting(key: String, default: Variant = null) -> Variant:
	return data.settings.get(key, default)


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	save_game()


## Merges two copies of the progress (this device's and iCloud's) so nothing earned is lost:
## best stars, furthest unlocks and clues, and every purchase are kept from both; avatar,
## equipped gun and seen-tutorials come from the newer copy. The wallet keeps the ledger
## honest: total earned is the larger of the two, total spent the larger of the two.
static func merge_progress(a: Dictionary, a_time: float, b: Dictionary, b_time: float) -> Dictionary:
	var newer: Dictionary = (a if a_time >= b_time else b).duplicate(true)
	var older: Dictionary = b if a_time >= b_time else a
	var out := newer
	var n := maxi(out.ch.size(), older.ch.size())
	while out.ch.size() < n:
		out.ch.append(null)
	for c in older.ch.size():
		var o: Variant = older.ch[c]
		if o == null:
			continue
		if out.ch[c] == null:
			out.ch[c] = o.duplicate(true)
			continue
		out.ch[c].unlocked = maxi(int(out.ch[c].unlocked), int(o.unlocked))
		for k in o.stars:
			out.ch[c].stars[k] = maxi(int(out.ch[c].stars.get(k, 0)), int(o.stars[k]))
	for k in older.get("hints", {}):
		out.hints[k] = maxi(int(out.hints.get(k, 0)), int(older.hints[k]))
	for group in ["guns", "fins"]:
		for k in older.inv.get(group, {}):
			out.inv[group][k] = out.inv[group].get(k, false) or older.inv[group][k]
	for k in older.get("avOwned", {}):
		out.avOwned[k] = out.avOwned.get(k, false) or older.avOwned[k]
	if not out.has("skins"):
		out.skins = fresh_progress().skins
	for k in older.get("skins", {}).get("owned", {}):  # skins bought on either device; the active one from the newer
		out.skins.owned[k] = out.skins.owned.get(k, false) or older.skins.owned[k]
	out.seenOffice = bool(out.get("seenOffice", false)) or bool(older.get("seenOffice", false))
	var spent := maxf(float(a.stats.earned) - float(a.bucks), float(b.stats.earned) - float(b.bucks))
	for k in older.stats:
		out.stats[k] = maxf(float(out.stats.get(k, 0)), float(older.stats[k]))
	out.bucks = maxf(0, float(out.stats.earned) - spent)
	return out
