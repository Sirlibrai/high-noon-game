extends Node
## iCloud sync for the save, through the HighNoonCloud iOS plugin
## (ios/plugins/HighNoonCloud). The plugin mirrors two small files in the app's
## Documents folder with iCloud key-value storage:
##   cloud_out.json  written here after every save; the plugin uploads it
##   cloud_in.json   written by the plugin when iCloud has a copy (at launch,
##                   on return to the app, or when another device changes it)
## and cloud_status.json tells us the plugin is running. Whenever cloud_in.json
## changes, its progress is merged into ours with SaveManager.merge_progress(),
## so stars, unlocks, purchases and the avatar survive across devices.
##
## Off the device, or when the plugin is not in the build (free Apple teams
## cannot use iCloud), this does nothing and local saves work as before.

const POLL_SECONDS := 2.0

## Where the files live; on iOS this is the app's Documents folder. Tests point it elsewhere.
var dir := ""
var _last_in := ""
var _timer := 0.0
signal merged


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dir == "":
		dir = OS.get_environment("HOME").path_join("Documents") if OS.has_feature("ios") else ""
	SaveManager.saved.connect(push)
	pull()


func available() -> bool:
	return dir != "" and FileAccess.file_exists(dir.path_join("cloud_status.json"))


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= POLL_SECONDS:
		_timer = 0.0
		pull()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		pull()


## Hands the current progress to the plugin to upload.
func push(data: Dictionary) -> void:
	if not available():
		return
	var payload := JSON.stringify({"version": data.version, "saved_at": data.saved_at, "progress": data.progress})
	var f := FileAccess.open(dir.path_join("cloud_out.json.tmp"), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(payload)
	f.close()
	DirAccess.rename_absolute(dir.path_join("cloud_out.json.tmp"), dir.path_join("cloud_out.json"))


## Merges in iCloud's copy if it changed since we last looked. Returns true if it did.
func pull() -> bool:
	if not available() or not FileAccess.file_exists(dir.path_join("cloud_in.json")):
		return false
	var text := FileAccess.get_file_as_string(dir.path_join("cloud_in.json"))
	if text == "" or text == _last_in:
		return false
	_last_in = text
	var remote: Variant = JSON.parse_string(text)
	if not remote is Dictionary or not remote.has("progress"):
		return false
	var theirs := SaveManager.normalised(remote)
	var local: Dictionary = SaveManager.data
	local.progress = SaveManager.merge_progress(local.progress, float(local.saved_at), theirs.progress, float(theirs.saved_at))
	SaveManager.save_game()
	merged.emit()
	return true
