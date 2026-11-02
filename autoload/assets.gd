extends Node
## The single source of art. Reads res://assets/manifest.json, which maps names
## like "prop/tnt" to image files, and builds a SpriteFrames per set
## ("prop") with one animation per name ("tnt"). Also fills the textures of
## the shared UI theme from manifest entries that list theme slots.
##
## Skins (see autoload/skins.gd): set_skin() looks up the active skin's
## overrides first. An override replaces a name's image files and keeps the
## standard entry's anchor, timing and points unless it sets its own; an
## override whose files are missing falls back to the standard art. Skins only
## change pictures: hitboxes live in data/geometry.json and never read art.

const ROOT := "res://assets/"
const MANIFEST := ROOT + "manifest.json"
const THEME := "res://ui/ui_theme.tres"
const DEFAULT_FPS := 8.0

var scenes: Dictionary = {}
var _entries: Dictionary = {}  # name -> {frames, fps, loop, anchor, points}: what the game shows now
var _base: Dictionary = {}  # the same, for the standard art only
var _sets: Dictionary = {}  # set name -> SpriteFrames
var errors: Array[String] = []
## Overrides of the active skin that could not be used, so the standard art shows instead.
var skin_fallbacks: Array[String] = []
signal skin_changed


func _ready() -> void:
	load_manifest()
	_apply_theme()


func load_manifest() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not raw is Dictionary:
		errors.append("manifest.json is not valid JSON")
		push_error(errors[-1])
		return
	scenes = raw.get("scenes", {})
	for name in raw.assets:
		var e := _parse(name, raw.assets[name])
		if e.frames.is_empty():
			continue
		_base[name] = e
	_entries = _base.duplicate()


## Shows a skin's art: `overrides` maps manifest names to replacement entries
## (a file path, or an entry with frames and any options to change). An empty
## dictionary is the standard art.
func set_skin(overrides: Dictionary) -> void:
	_entries = _base.duplicate()
	skin_fallbacks.clear()
	for name in overrides:
		if not _base.has(name):
			skin_fallbacks.append(name + " (not in the manifest)")
			continue
		var v: Variant = overrides[name]
		var merged: Dictionary = _base[name].raw.duplicate(true)
		merged.erase("sequence")
		merged.merge({"frames": [v]} if v is String else v, true)
		var e := _parse(name, merged, false)
		if e.missing > 0 or e.frames.is_empty():
			skin_fallbacks.append(name)  # keep the standard art
			continue
		_entries[name] = e
	_sets.clear()
	_apply_theme()
	skin_changed.emit()


func _parse(name: String, v: Variant, report := true) -> Dictionary:
	if v is String:
		v = {"frames": [v]}
	var files: Array = v.get("frames", []).duplicate()
	if v.has("sequence"):
		for i in int(v.sequence.count):
			files.append(v.sequence.pattern % i)
	var frames: Array[Texture2D] = []
	var missing := 0
	for f in files:
		var path: String = ROOT + f
		if not ResourceLoader.exists(path):
			missing += 1
			if report:
				errors.append("%s: missing file %s" % [name, path])
				push_error(errors[-1])
			continue
		frames.append(load(path))
	var anchor := Vector2.ZERO
	if not frames.is_empty():
		var size := frames[0].get_size()
		var a: Variant = v.get("anchor", "feet")
		match a:
			"feet", "base": anchor = Vector2(floorf(size.x / 2), size.y)
			"center": anchor = (size / 2).floor()
			"top_left": anchor = Vector2.ZERO
			_: anchor = Vector2(a[0], a[1]) if a is Array else Vector2(floorf(size.x / 2), size.y)
	var points := {}
	for k in v.get("points", {}):
		points[k] = Vector2(v.points[k][0], v.points[k][1])
	return {"frames": frames, "fps": float(v.get("fps", DEFAULT_FPS)), "loop": bool(v.get("loop", true)),
		"anchor": anchor, "points": points, "theme": v.get("theme", []), "raw": v, "missing": missing}


func has(name: String) -> bool:
	return _entries.has(name)


func names() -> Array:
	return _entries.keys()


func texture(name: String) -> Texture2D:
	assert(_entries.has(name), "No asset named " + name)
	return _entries[name].frames[0]


## The anchor of an asset, in pixels of its first frame.
func anchor(name: String) -> Vector2:
	return _entries[name].anchor


## A named point of an asset (such as a gun's muzzle), in pixels from its anchor.
func point(name: String, key: String) -> Vector2:
	return _entries[name].points.get(key, Vector2.ZERO)


## Any other option written on a manifest entry (e.g. "nine_patch").
func meta(name: String, key: String, default: Variant = null) -> Variant:
	return _entries[name].raw.get(key, default)


func frame_count(name: String) -> int:
	return _entries[name].frames.size()


## One SpriteFrames per set: "outlaw" holds the animations idle, aim, run...
func frames_for(set_name: String) -> SpriteFrames:
	if _sets.has(set_name):
		return _sets[set_name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in _entries:
		if name.get_slice("/", 0) != set_name:
			continue
		var anim: String = name.get_slice("/", 1)
		var e: Dictionary = _entries[name]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, e.fps)
		sf.set_animation_loop(anim, e.loop)
		var durations: Array = e.raw.get("durations", [])
		for i in e.frames.size():
			sf.add_frame(anim, e.frames[i], float(durations[i]) if i < durations.size() else 1.0)
	_sets[set_name] = sf
	return sf


func _apply_theme() -> void:
	var theme: Theme = load(THEME)
	for name in _entries:
		for slot in _entries[name].theme:
			var type: String = slot.get_slice("/", 0)
			var style: String = slot.get_slice("/", 1)
			var sb: StyleBox = theme.get_stylebox(style, type) if theme.has_stylebox(style, type) else null
			if sb is StyleBoxTexture:
				sb.texture = _entries[name].frames[0]
			else:
				errors.append("%s: theme slot %s is not a StyleBoxTexture in ui/ui_theme.tres" % [name, slot])
				push_error(errors[-1])
