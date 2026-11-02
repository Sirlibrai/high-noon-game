extends SceneTree
## Brings the painted sheriff's office and the gunsmith into assets/painted:
##   Godot --headless --path . -s res://tools/import_office.gd
## The office painting is copied as it is (the office scene works in its pixels), and its doorway's
## front is cut out as a layer of its own: the doorframe, and the crate and barrel in front of the
## workshop, drawn over the gunsmith so he is seen through the doorway, in the next room. The
## gunsmith sheet's three poses are split at the transparent gaps between them, trimmed, scaled so
## his stool covers the stool painted at the workbench, and anchored at the foot of the stool's
## front-left leg. Prints the manifest entries with the anchors measured here.

const IN := "res://assets/incoming/"
const OUT := "res://assets/painted/"
const OFFICE := "Sunset Sheriff’s Office Interior.png"
const SMITH := "Three Poses of a Western Craftsman.png"
const POSES := ["polish", "hammer", "tip"]
const Cut := preload("res://tools/cut.gd")
## The painted stool is 124 office pixels tall (seat to floor); his is 197 sheet pixels, scaled to match
## it exactly, which makes him the right size for the room. Stored at twice that density (drawn at
## scale 0.5), sharp on wide phones.
const SMITH_K := 124.0 / 197.0 * 2.0
## The doorway's front layer: the region it covers, the opening (painting pixels), and inside the
## opening, the workshop crate (left) and the office's barrel (right, an outline) that stand in front of him.
const DOOR_REGION := Rect2i(1290, 76, 382, 690)
const OPENING := Rect2i(1351, 127, 294, 613)
const CRATE := Rect2i(1351, 631, 50, 110)
const BARREL := [Vector2(1612, 576), Vector2(1672, 576), Vector2(1672, 714), Vector2(1579, 714), Vector2(1580, 668), Vector2(1586, 640), Vector2(1597, 604)]


func _init() -> void:
	var office := Image.load_from_file(ProjectSettings.globalize_path(IN + OFFICE))
	office.convert(Image.FORMAT_RGB8)
	office.save_png(ProjectSettings.globalize_path(OUT + "office.png"))
	print('    "office/painted": {"frames": ["painted/office.png"], "anchor": "top_left"},')
	_doorway_front(office).save_png(ProjectSettings.globalize_path(OUT + "office_doorway_front.png"))
	print('    "office/doorway_front": {"frames": ["painted/office_doorway_front.png"], "anchor": "top_left"},  # at %s' % DOOR_REGION.position)
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(IN + SMITH))
	sheet.convert(Image.FORMAT_RGBA8)
	var spans := _spans(sheet)
	assert(spans.size() == 3, "expected three poses, found %d" % spans.size())
	for i in 3:
		var box := _bbox(sheet, spans[i])
		var pose := sheet.get_region(box)
		Cut.remove_shadow(pose)  # the game adds its own contact shadow
		pose = pose.get_region(pose.get_used_rect())
		var leg := _stool_leg(pose)
		pose.resize(int(pose.get_width() * SMITH_K), int(pose.get_height() * SMITH_K), Image.INTERPOLATE_LANCZOS)
		pose.save_png(ProjectSettings.globalize_path(OUT + "gunsmith_%s.png" % POSES[i]))
		print('    "gunsmith/%s": {"frames": ["painted/gunsmith_%s.png"], "anchor": [%d, %d], "scale": 0.5},' % [
			POSES[i], POSES[i], roundi(leg.x * SMITH_K), roundi(leg.y * SMITH_K)])
	quit()


## Column ranges holding opaque pixels, split at fully transparent gaps.
func _spans(im: Image) -> Array:
	var out: Array = []
	var start := -1
	for x in im.get_width():
		var any := false
		for y in range(0, im.get_height(), 2):
			if im.get_pixel(x, y).a > 0.3:
				any = true
				break
		if any and start < 0:
			start = x
		elif not any and start >= 0:
			if x - start > 100:
				out.append(Vector2i(start, x))
			start = -1
	if start >= 0:
		out.append(Vector2i(start, im.get_width()))
	return out


func _bbox(im: Image, span: Vector2i) -> Rect2i:
	var top := im.get_height()
	var bottom := 0
	for x in range(span.x, span.y):
		for y in im.get_height():
			if im.get_pixel(x, y).a > 0.3:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return Rect2i(span.x, top, span.y - span.x, bottom - top + 1)


## The foot of the stool's front-left leg: the leftmost solid pixel low in the figure (only the stool
## reaches that far left down there; his boots are to the right), and the lowest pixel under it.
func _stool_leg(im: Image) -> Vector2:
	var h := im.get_height()
	var left := im.get_width()
	for y in range(int(h * 0.8), int(h * 0.92)):
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				break
	var bottom := 0
	for x in range(left, left + 20):
		for y in range(h - 1, 0, -1):
			if im.get_pixel(x, y).a > 0.5:
				bottom = maxi(bottom, y)
				break
	return Vector2(left, bottom)


## The doorway's front: the painting over DOOR_REGION, see-through in the opening except where the
## crate and the barrel stand in front of the workshop.
func _doorway_front(office: Image) -> Image:
	var out := Image.create_empty(DOOR_REGION.size.x, DOOR_REGION.size.y, false, Image.FORMAT_RGBA8)
	var barrel := PackedVector2Array(BARREL)
	for y in DOOR_REGION.size.y:
		for x in DOOR_REGION.size.x:
			var p := DOOR_REGION.position + Vector2i(x, y)
			var front := not OPENING.has_point(p) or CRATE.has_point(p) or Geometry2D.is_point_in_polygon(Vector2(p) + Vector2(0.5, 0.5), barrel)
			if front:
				var c := office.get_pixelv(p)
				out.set_pixel(x, y, Color(c, 1.0))
	return out
