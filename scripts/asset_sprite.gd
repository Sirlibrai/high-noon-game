class_name AssetSprite
extends AnimatedSprite2D
## An AnimatedSprite2D that shows a manifest asset by name ("outlaw/aim") and
## positions it by the asset's anchor, so the node's position is where the
## character's feet or the prop's base stand.

var asset := ""


static func make(asset_name: String, parent: Node = null) -> AssetSprite:
	var s := AssetSprite.new()
	s.centered = false
	s.show_asset(asset_name)
	if parent != null:
		parent.add_child(s)
	return s


## Switches to another asset; restarts the animation only when it changes.
func show_asset(asset_name: String) -> void:
	if asset_name == asset:
		return
	var set_name := asset_name.get_slice("/", 0)
	if asset.get_slice("/", 0) != set_name or sprite_frames == null:
		sprite_frames = Assets.frames_for(set_name)
	asset = asset_name
	offset = -Assets.anchor(asset_name)
	play(asset_name.get_slice("/", 1))


## Shows one frame without animating (particle colour variants, explosion frames).
func show_frame(i: int) -> void:
	pause()
	frame = i % sprite_frames.get_frame_count(animation)
