extends RefCounted
## Shared steps for cutting painted art out of the sheets in assets/incoming (used by the
## tools/import_*.gd scripts): halo trimming, keeping the figure, clean downscaling.

## Trims the faint glow the matte left round shapes on the transparent sheets.
static func defringe(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a < 1.0:
				im.set_pixel(x, y, Color(c, smoothstep(0.35, 0.9, c.a)))


## Keeps the figure: its biggest shape plus specks (blood, sparks), or only the biggest shape.
static func keep(im: Image, rule: String) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes: Array[int] = [0]
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a < 0.2 or label[y * w + x] != 0:
				continue
			var id := sizes.size()
			var n := 0
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			label[y * w + x] = id
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				for dd in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var q: Vector2i = p + dd
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and label[q.y * w + q.x] == 0 and im.get_pixel(q.x, q.y).a >= 0.2:
						label[q.y * w + q.x] = id
						stack.append(q)
			sizes.append(n)
	var biggest := 0
	for i in range(1, sizes.size()):
		if biggest == 0 or sizes[i] > sizes[biggest]:
			biggest = i
	for y in h:
		for x in w:
			var id := label[y * w + x]
			var drop := false
			if id == 0:
				drop = im.get_pixel(x, y).a < 0.2 and far_from(label, w, h, x, y, biggest)
			elif id != biggest:
				drop = rule == "largest" or sizes[id] > sizes[biggest] * 0.03
			if drop:
				im.set_pixel(x, y, Color(0, 0, 0, 0))


## A faint pixel belongs to the figure only if it touches it (edge softening).
static func far_from(label: PackedInt32Array, w: int, h: int, x: int, y: int, id: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var qx := x + dx
			var qy := y + dy
			if qx >= 0 and qy >= 0 and qx < w and qy < h and label[qy * w + qx] == id:
				return false
	return true


## Downscales without dark edges (premultiplied), then trims to the opaque pixels.
static func scale(im: Image, k: float, trim := true) -> Image:
	var out: Image = im.duplicate()
	out.premultiply_alpha()
	out.resize(maxi(1, roundi(im.get_width() * k)), maxi(1, roundi(im.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.004:
				out.set_pixel(x, y, Color(minf(1, c.r / c.a), minf(1, c.g / c.a), minf(1, c.b / c.a), c.a))
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	if not trim:
		return out
	var used := out.get_used_rect()
	return out.get_region(used.grow(1).intersection(Rect2i(Vector2i.ZERO, out.get_size())))


