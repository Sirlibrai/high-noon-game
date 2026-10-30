extends Node
## Optional visual skins (data/skins.json). The active and owned skins are kept
## in the save (progress.skins). Applying a skin does two things:
##   - its asset overrides go to Assets.set_skin(), which shows a skin's own
##     image for a name when it has one and the standard art otherwise;
##   - its shader goes on the final full-screen layer, drawn above everything
##     else (game, HUD, cards), so every frame passes through it. With no shader
##     the layer is hidden and costs nothing.
## Skins never touch gameplay: geometry, hitboxes and timing don't read art.
## Screens built after a switch use the new art; the menus rebuild on the way.

const DATA := "res://data/skins.json"
const FINAL_LAYER := 1000

var skins: Array = []
var default_id := "standard"
var _by_id: Dictionary = {}
var _layer: CanvasLayer
var _screen: ColorRect


func _ready() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	skins = raw.skins
	default_id = raw.get("default", "standard")
	for s in skins:
		_by_id[s.id] = s
	_layer = CanvasLayer.new()
	_layer.layer = FINAL_LAYER
	add_child(_layer)
	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_screen)
	apply(get_skin(active_id()))


func get_skin(id: String) -> Dictionary:
	return _by_id.get(id, _by_id[default_id])


## The player's skins in the save: {"active": id, "owned": {id: true}}.
func _saved() -> Dictionary:
	var p: Dictionary = SaveManager.data.progress
	if not p.has("skins"):
		p.skins = {"active": default_id, "owned": {default_id: true}}
	return p.skins


func active_id() -> String:
	var id: String = _saved().get("active", default_id)
	return id if _by_id.has(id) and owns(id) else default_id


func owns(id: String) -> bool:
	return id == default_id or bool(_saved().owned.get(id, false))


## Switches to an owned skin and remembers it. Returns false for a skin the player doesn't own.
func set_active(id: String) -> bool:
	if not _by_id.has(id) or not owns(id):
		return false
	_saved().active = id
	SaveManager.save_game()
	apply(get_skin(id))
	return true


## Shows a skin: its overrides through Assets, its shader on the final layer.
func apply(skin: Dictionary) -> void:
	Assets.set_skin(skin.get("overrides", {}))
	var shader_path: Variant = skin.get("shader")
	if shader_path == null or shader_path == "" or not ResourceLoader.exists(shader_path):
		_screen.material = null
		_layer.visible = false
		return
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	_screen.material = m
	_layer.visible = true


## The final layer's shader material, or null when no shader is active (tests).
func final_material() -> ShaderMaterial:
	return _screen.material if _layer.visible else null
