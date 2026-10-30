class_name CutoutRig
extends Node2D
## A cut-out character: separate parts (legs, torso, arms, gun hand, head with
## hat) placed at joints and animated with simple clips, all described in the
## manifest's "rigs" and "rig_animations". The node's position is the
## character's feet, like the sprites it replaces. New art, joints or timing
## need no code: only the manifest and the part images change.
##
## Gameplay calls pose(): "idle", "pop_up", "aim", "flinch", "fall", "run".

const FLASH_SHADER := preload("res://ui/flash.gdshader")

var rig_name := ""
var parts: Dictionary = {}  # part name -> AssetSprite
var current := ""
var _rest: Dictionary = {}  # part name -> {position, visible}
var _player: AnimationPlayer
var _material: ShaderMaterial

## The white hit flash, 0..1, animated by clips through "rig:flash".
var flash := 0.0:
	set(v):
		flash = v
		if _material != null:
			_material.set_shader_parameter("flash", v)


static func make(name: String, parent: Node = null) -> CutoutRig:
	var r := CutoutRig.new()
	r.rig_name = name
	r._build()
	if parent != null:
		parent.add_child(r)
	return r


func _build() -> void:
	var def: Dictionary = Assets.rigs[rig_name]
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	for p in def.parts:
		var s := AssetSprite.make(p.asset)
		s.name = p.name
		s.material = _material
		s.pause()  # frames are picked by the clips, not played
		(parts[p.parent] if p.has("parent") else self).add_child(s)
		s.position = Vector2(p.at[0], p.at[1])
		s.show_behind_parent = p.get("behind", false)
		s.visible = not p.get("hidden", false)
		parts[p.name] = s
		_rest[p.name] = {"position": s.position, "visible": s.visible}
	_player = AnimationPlayer.new()
	add_child(_player)
	var lib := AnimationLibrary.new()
	var clips: Dictionary = Assets.rig_animations[def.animations]
	for clip in clips:
		lib.add_animation(clip, _clip(clips[clip]))
	_player.add_animation_library("", lib)
	pose("idle")


func _clip(def: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = def.length
	a.loop_mode = Animation.LOOP_LINEAR if def.get("loop", false) else Animation.LOOP_NONE
	for key in def.tracks:
		var part: String = key.get_slice(":", 0)
		var prop: String = key.get_slice(":", 1)
		if part != "rig" and not parts.has(part):
			continue  # a clip may animate parts some rigs don't have
		var t := a.add_track(Animation.TYPE_VALUE)
		var path := "." if part == "rig" else _part_path(part)
		a.track_set_path(t, path + ":" + prop)
		if prop in ["visible", "frame"]:
			a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		for k in def.tracks[key]:
			a.track_insert_key(t, float(k[0]), _value(part, prop, k[1]))
	return a


## A part's path from the rig (parts can be nested: torso/head).
func _part_path(part: String) -> String:
	var n: Node = parts[part]
	var names: Array[String] = []
	while n != self:
		names.push_front(n.name)
		n = n.get_parent()
	return "/".join(names)


func _value(part: String, prop: String, v: Variant) -> Variant:
	match prop:
		"rotation":
			return deg_to_rad(float(v))
		"position":
			return _rest[part].position + Vector2(v[0], v[1])
		"scale":
			return Vector2(v[0], v[1])
		"frame":
			return int(v)
	return v


## Plays a clip from the rest pose; the same clip again keeps playing.
func pose(clip: String) -> void:
	if clip == current:
		return
	current = clip
	for name in parts:
		var s: AssetSprite = parts[name]
		s.position = _rest[name].position
		s.rotation = 0.0
		s.scale = Vector2.ONE
		s.visible = _rest[name].visible
		s.frame = 0
	flash = 0.0
	if _player.has_animation(clip):
		_player.play(clip)
		_player.advance(0)


func set_part_visible(part: String, on: bool) -> void:
	if parts.has(part):
		_rest[part].visible = on
		parts[part].visible = on


## Swaps a part's art (e.g. Iron Eli's armour when it cracks).
func set_part_asset(part: String, asset: String) -> void:
	if parts.has(part):
		parts[part].show_asset(asset)
		parts[part].pause()
