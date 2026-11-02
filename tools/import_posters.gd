extends SceneTree
## Cuts the five painted wanted posters out of assets/incoming into assets/painted:
##   Godot --headless --path . -s res://tools/import_posters.gd
## The sheet holds them left to right (Iron Eli, Cole Haggerty, Digger McCall, the Lantern Man, J.R.) on
## real transparency, so each is found as a run of columns with paper in it, then trimmed to its paper.
## J.R. also gets his locked poster: the same paper and lettering, with only the figure in the portrait
## inked into a dark hat-and-shoulders silhouette.

const IN := "res://assets/incoming/Vintage Western Wanted Poster Collection.png"
const OUT := "res://assets/painted/"
const SILHOUETTE := [4]  # chapters whose locked poster shows a silhouette
## J.R.'s portrait window, in his cut poster's pixels, a little past its sides and top, down to its bottom edge (paper outside is never inked).
const WINDOW := Rect2i(14, 160, 396, 333)
const INK := Color(0.12, 0.075, 0.055)


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(IN))
	sheet.convert(Image.FORMAT_RGBA8)
	var runs := _runs(sheet)
	assert(runs.size() == 5, "expected five posters, found %d" % runs.size())
	for i in 5:
		var col := sheet.get_region(Rect2i(runs[i].x, 0, runs[i].y - runs[i].x, sheet.get_height()))
		var poster := col.get_region(col.get_used_rect())
		poster.save_png(ProjectSettings.globalize_path(OUT + "poster_ch%d.png" % i))
		print('    "poster/ch%d": "painted/poster_ch%d.png",  # %dx%d' % [i, i, poster.get_width(), poster.get_height()])
		if i in SILHOUETTE:
			_silhouette(poster, WINDOW).save_png(ProjectSettings.globalize_path(OUT + "poster_ch%d_locked.png" % i))
			print('    "poster/ch%d_locked": "painted/poster_ch%d_locked.png",' % [i, i])
	quit()


## The posters: runs of columns with a fair amount of opaque paper in them.
static func _runs(im: Image) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x := 0
	var solid := func(cx: int) -> bool:
		var n := 0
		for y in range(0, im.get_height(), 4):
			if im.get_pixel(cx, y).a > 0.5:
				n += 1
		return n > 10
	while x < im.get_width():
		if not solid.call(x):
			x += 1
			continue
		var x0 := x
		while x < im.get_width() and solid.call(x):
			x += 1
		out.append(Vector2i(x0, x))
	return out


## The poster with the figure in its portrait window inked dark. The background (sky, rocks, paper) is
## flooded in from the window's edges, stopping at the figure's dark outline; the biggest patch the
## flood can't reach is the figure (hat, face, coat). Its holes are filled and it is inked, its edge softened.
static func _silhouette(im: Image, win: Rect2i) -> Image:
	var w := win.size.x
	var h := win.size.y
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
		var c := im.get_pixelv(win.position + p)
		if c.a > 0.5 and c.get_luminance() < 0.27:  # the figure's outline and dark clothes
			continue
		seen[p.y * w + p.x] = 1
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)
	var figure := _biggest(seen, w, h)
	var out: Image = im.duplicate()
	for y in h:
		for x in w:
			var k := 0.0  # softened: how much of the 3x3 around is figure
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := Vector2i(x + dx, y + dy)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and figure[q.y * w + q.x]:
						k += 1.0 / 9.0
			if k > 0:
				var at := win.position + Vector2i(x, y)
				var c := out.get_pixelv(at)
				out.set_pixelv(at, Color(c.lerp(INK, k), c.a))
	return out


## The largest 4-connected patch the flood didn't reach, with the holes in it filled.
static func _biggest(seen: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var label := PackedInt32Array()
	label.resize(w * h)
	var best := 0
	var best_n := 0
	var next := 0
	for start in w * h:
		if seen[start] or label[start] != 0:
			continue
		next += 1
		var n := 0
		var stack: Array[int] = [start]
		label[start] = next
		while not stack.is_empty():
			var i: int = stack.pop_back()
			n += 1
			var x := i % w
			var y := i / w
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and not seen[j] and label[j] == 0:
					label[j] = next
					stack.append(j)
		if n > best_n:
			best_n = n
			best = next
	# Fill holes: anything not reachable from the window's top or sides without crossing the figure (the
	# figure runs off the window's bottom, so lit patches there, like a watch chain, are inside it).
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if outside[i] or label[i] == best:
			continue
		outside[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	var out := PackedByteArray()
	out.resize(w * h)
	for i in w * h:
		out[i] = 1 if not outside[i] else 0
	return out
