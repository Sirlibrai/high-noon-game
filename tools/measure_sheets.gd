extends SceneTree
## Lists the separate figures on each painted sheet in assets/incoming (bounding
## boxes in sheet pixels), so tools/import_painted.gd can cut them out by
## measured coordinates. Run: Godot --headless --path . -s res://tools/measure_sheets.gd

const DIR := "res://assets/incoming/"
const STEP := 4  # analyse at quarter size for speed


func _init() -> void:
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".png") and f != "Golden Hour Western Main Street.png":
			_report(f)
	quit()


## Opaque pixels of a sheet: real alpha, or for cream sheets everything not connected to the border's colour.
static func solid_mask(im: Image, step: int, tol: float) -> Array:
	var w := im.get_width() / step
	var h := im.get_height() / step
	var mask := []
	mask.resize(w * h)
	var has_alpha := im.detect_alpha() != Image.ALPHA_NONE
	var bg := im.get_pixel(2, 2)
	for y in h:
		for x in w:
			var c := im.get_pixel(x * step, y * step)
			mask[y * w + x] = c.a > 0.25 if has_alpha else 1
	if not has_alpha:  # flood the background in from the edges
		var stack: Array = []
		for x in w:
			stack.append(Vector2i(x, 0))
			stack.append(Vector2i(x, h - 1))
		for y in h:
			stack.append(Vector2i(0, y))
			stack.append(Vector2i(w - 1, y))
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
				continue
			var i := p.y * w + p.x
			if mask[i] != 1:
				continue
			var c := im.get_pixel(p.x * step, p.y * step)
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > tol:
				continue
			mask[i] = 0
			stack.append(p + Vector2i.RIGHT)
			stack.append(p + Vector2i.LEFT)
			stack.append(p + Vector2i.DOWN)
			stack.append(p + Vector2i.UP)
		for i in mask.size():
			mask[i] = 1 if mask[i] == 1 else 0
	else:
		for i in mask.size():
			mask[i] = 1 if mask[i] else 0
	return [mask, w, h]


func _report(f: String) -> void:
	var im := Image.load_from_file(ProjectSettings.globalize_path(DIR + f))
	im.convert(Image.FORMAT_RGBA8)
	var r := solid_mask(im, STEP, 0.16)
	var mask: Array = r[0]
	var w: int = r[1]
	var h: int = r[2]
	var seen := PackedByteArray()
	seen.resize(w * h)
	var comps: Array = []
	for y in h:
		for x in w:
			var i := y * w + x
			if mask[i] == 0 or seen[i]:
				continue
			var box := Rect2i(x, y, 1, 1)
			var n := 0
			var stack := [Vector2i(x, y)]
			seen[i] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				box = box.expand(p)
				for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var j := q.y * w + q.x
					if mask[j] == 1 and not seen[j]:
						seen[j] = 1
						stack.append(q)
			if n >= 12:
				comps.append([box.position.x * STEP, box.position.y * STEP, (box.size.x + 1) * STEP, (box.size.y + 1) * STEP, n * STEP * STEP])
	comps.sort_custom(func(a, b): return a[0] < b[0])
	print("== %s (%dx%d, alpha %s, bg %s)" % [f, im.get_width(), im.get_height(), im.detect_alpha() != Image.ALPHA_NONE, im.get_pixel(2, 2).to_html(false)])
	for c in comps:
		print("  x %4d y %4d  w %4d h %4d  area %d" % c)
