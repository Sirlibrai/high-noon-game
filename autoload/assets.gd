extends Node
## The single source of art. Reads res://assets/manifest.json, which maps names
## like "outlaw/aim" to image files, and builds a SpriteFrames per set
## ("outlaw") with one animation per name ("aim"). Also fills the textures of
## the shared UI theme from manifest entries that list theme slots.

const ROOT := "res://assets/"
const MANIFEST := ROOT + "manifest.json"
const THEME := "res://ui/theme.tres"
const DEFAULT_FPS := 8.0

var scenes: Dictionary = {}
var _entries: Dictionary = {}  # name -> {frames, fps, loop, anchor, points}
var _sets: Dictionary = {}  # set name -> SpriteFrames
var errors: Array[String] = []


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
		_entries[name] = e


func _parse(name: String, v: Variant) -> Dictionary:
	if v is String:
		v = {"frames": [v]}
	var files: Array = v.get("frames", [])
	if v.has("sequence"):
		for i in int(v.sequence.count):
			files.append(v.sequence.pattern % i)
	var frames: Array[Texture2D] = []
	for f in files:
		var path: String = ROOT + f
		if not ResourceLoader.exists(path):
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
		"anchor": anchor, "points": points, "theme": v.get("theme", []), "raw": v}


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
				errors.append("%s: theme slot %s is not a StyleBoxTexture in ui/theme.tres" % [name, slot])
				push_error(errors[-1])
