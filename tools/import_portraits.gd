extends SceneTree
## Cuts the five bounty portraits out of assets/incoming into square images in assets/painted:
##   Godot --headless --path . -s res://tools/import_portraits.gd
## The sheet holds five parchment panels on a cream background, left to right: Iron Eli, Cole Haggerty,
## Digger McCall, the Lantern Man and J.R. Each panel is found by scanning for the parchment, then cut
## as a square from its top (the hat) down. J.R. also gets a dark hat-and-shoulders silhouette for while
## his poster is locked: everything that isn't parchment, flooded in from the panel's edges, inked dark.

const Cut := preload("res://tools/cut.gd")
const IN := "res://assets/incoming/Five Wild West Outlaw Portraits.png"
const OUT := "res://assets/painted/"
const SIZE := 256  # output pixels, square
const SILHOUETTE := [4]  # chapters whose locked poster shows a silhouette
const INSET := 10  # sheet pixels trimmed inside each panel's rough edge
## The Bounty board wall's posters show a wide portrait: almost the poster's full width, about half its height.
const WIDE := Vector2i(400, 312)


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(IN))
	sheet.convert(Image.FORMAT_RGBA8)
	var panels := _panels(sheet)
	assert(panels.size() == 5, "expected five portraits, found %d" % panels.size())
	for i in 5:
		var p: Rect2i = panels[i]
		var side := mini(p.size.x, p.size.y) - INSET * 2
		var sq := sheet.get_region(Rect2i(p.position.x + (p.size.x - side) / 2, p.position.y + INSET, side, side))
		var out := Cut.scale(sq, float(SIZE) / side, false)
		out.save_png(ProjectSettings.globalize_path(OUT + "portrait_ch%d.png" % i))
		print('    "portrait/ch%d": {"frames": ["painted/portrait_ch%d.png"]},  # panel %s' % [i, i, p])
		if i in SILHOUETTE:
			_silhouette(out).save_png(ProjectSettings.globalize_path(OUT + "portrait_ch%d_locked.png" % i))
			print('    "portrait/ch%d_locked": {"frames": ["painted/portrait_ch%d_locked.png"]},' % [i, i])
		var ww := p.size.x - INSET * 2
		var wh := roundi(ww * float(WIDE.y) / WIDE.x)
		var wide := Cut.scale(sheet.get_region(Rect2i(p.position.x + INSET, p.position.y + INSET, ww, wh)), float(WIDE.x) / ww, false)
		wide.save_png(ProjectSettings.globalize_path(OUT + "portrait_wide_ch%d.png" % i))
		print('    "portrait_wide/ch%d": "painted/portrait_wide_ch%d.png",' % [i, i])
		if i in SILHOUETTE:
			_silhouette(wide).save_png(ProjectSettings.globalize_path(OUT + "portrait_wide_ch%d_locked.png" % i))
			print('    "portrait_wide/ch%d_locked": "painted/portrait_wide_ch%d_locked.png",' % [i, i])
	quit()


## The parchment panels: runs of columns, then rows, that aren't the sheet's near-white background.
func _panels(im: Image) -> Array:
	var is_bg := func(c: Color) -> bool: return c.r > 0.93 and c.g > 0.9 and c.b > 0.85
	var mid := im.get_height() / 2
	var out: Array = []
	var x := 0
	while x < im.get_width():
		if is_bg.call(im.get_pixel(x, mid)):
			x += 1
			continue
		var x0 := x
		while x < im.get_width() and not is_bg.call(im.get_pixel(x, mid)):
			x += 1
		if x - x0 < 200:
			continue
		var cx := (x0 + x) / 2
		var y0 := mid
		while y0 > 0 and not is_bg.call(im.get_pixel(cx, y0 - 1)):
			y0 -= 1
		var y1 := mid
		while y1 < im.get_height() - 1 and not is_bg.call(im.get_pixel(cx, y1 + 1)):
			y1 += 1
		out.append(Rect2i(x0, y0, x - x0, y1 - y0 + 1))
	return out


## The figure inked dark on the same parchment: the parchment is flooded in from the edges by its
## colour; whatever it can't reach (hat, head, shoulders) becomes the silhouette.
func _silhouette(im: Image) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var paper := im.get_pixel(4, h / 2)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x]:
			continue
		var c := im.get_pixel(p.x, p.y)
		if c.get_luminance() < 0.3 or c.r < c.b + 0.15:  # the figure: dark, or not warm like the parchment
			continue
		seen[p.y * w + p.x] = 1
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)
	var out: Image = im.duplicate()
	var ink := Color(0.13, 0.08, 0.06)
	for y in h:
		for x in w:
			if not seen[y * w + x]:
				out.set_pixel(x, y, ink)
	return out
