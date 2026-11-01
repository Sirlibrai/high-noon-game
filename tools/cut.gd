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




## Removes the ground shadow painted under a figure or prop: the soft ellipse its lowest rows show.
## Its colour is read from the lowest pixels that aren't background; everything joined to them in that
## colour within the bottom part of the piece goes (transparent, or `bg` on a cream sheet so the cream
## flood then clears it).
static func remove_shadow(im: Image, bg: Variant = null, band := 0.18, tol := 0.16) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var is_bg := func(c: Color) -> bool:
		return c.a < 0.25 if bg == null else absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) < 0.2
	var low := -1
	for y in range(h - 1, -1, -1):
		for x in w:
			if not is_bg.call(im.get_pixel(x, y)):
				low = y
				break
		if low >= 0:
			break
	if low < 0:
		return
	var sum := Color(0, 0, 0, 0)
	var n := 0
	var stack: Array[Vector2i] = []
	for y in [low, low - 1, low - 2]:
		for x in w:
			var c := im.get_pixel(x, y)
			if not is_bg.call(c):
				sum += c
				n += 1
				stack.append(Vector2i(x, y))
	var shade := sum / n
	var top := int(h * (1.0 - band))
	var seen := PackedByteArray()
	seen.resize(w * h)
	var clear := Color(bg, 1.0) if bg != null else Color(0, 0, 0, 0)
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < top or p.x >= w or p.y >= h or seen[p.y * w + p.x]:
			continue
		seen[p.y * w + p.x] = 1
		var c := im.get_pixel(p.x, p.y)
		var soft := bg == null and c.a < 0.96  # on a transparent sheet the shadow is see-through; the art is not
		if is_bg.call(c) or not (soft or absf(c.r - shade.r) + absf(c.g - shade.g) + absf(c.b - shade.b) <= tol):
			continue
		im.set_pixel(p.x, p.y, clear)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)


## Floods the cream background in from the edges; light areas inside the figure stay.
static func remove_cream(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var bg := im.get_pixel(0, 0)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x]:
			continue
		var c := im.get_pixel(p.x, p.y)
		var d := absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
		if d > 0.22:
			continue
		seen[p.y * w + p.x] = 1
		# Soft edge: nearly-background pixels vanish, slightly tinted ones fade.
		im.set_pixel(p.x, p.y, Color(c, clampf((d - 0.10) / 0.12, 0, 1) * 0.6) if d > 0.10 else Color(0, 0, 0, 0))
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)
	# Cream pockets the flood can't reach (between the legs), and pale dust at the boots.
	var solid_bottom := h - 1
	for y in range(h - 1, -1, -1):
		var dark := false
		for x in w:
			if im.get_pixel(x, y).get_luminance() < 0.4 and im.get_pixel(x, y).a > 0.5:
				dark = true
				break
		if dark:
			solid_bottom = y
			break
	var dust_from := solid_bottom - int(h * 0.07)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a == 0:
				continue
			var d := absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
			if d < 0.12 or (y >= dust_from and c.get_luminance() > 0.5 and d < 0.6) or y > solid_bottom + 1:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d < 0.22:
				im.set_pixel(x, y, Color(c, minf(c.a, (d - 0.12) / 0.10)))
