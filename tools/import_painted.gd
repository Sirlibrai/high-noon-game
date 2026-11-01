extends SceneTree
## Cuts the painted art in assets/incoming into game-ready sprites in
## assets/painted, and prints their manifest entries (anchors measured here).
## Re-run after replacing a sheet:
##   Godot --headless --path . -s res://tools/import_painted.gd
## Boxes come from tools/measure_sheets.gd. For each piece it:
##   - removes plain cream backgrounds by flooding in from the box's edges, and
##     trims the faint matte halo on sheets that already have transparency;
##   - keeps the figure itself (the fall pose without its flying hat, the hat on its own);
##   - scales to the game's size: outlaws so the standing pose matches the
##     19-unit hitbox, props to their cover sizes in cover_sizes.json;
##   - trims to the opaque pixels and measures the foot (or base) anchor.
## Output is at 8 pixels per gameplay unit, drawn at scale 0.5 on the 1280×720
## base (4 px per unit), so the art stays sharp on a phone screen.

const IN := "res://assets/incoming/"
const OUT := "res://assets/painted/"
const D := 8.0  # output pixels per gameplay unit
const POSES := "Four Poses of a Dusty Outlaw.png"
const ACTION := "Western Outlaw Action Sprite Sheet.png"
const PROPS := "Wild West Props Asset Sheet.png"
const GUN := "Western Revolver in Hand.png"
const STREET := "Golden Hour Western Main Street.png"
## The idle pose's full height (724 sheet pixels) becomes 20 units: about the 19-unit hitbox, plus the hat brim.
const OUTLAW_K := 20.0 * D / 724.0

## [name, sheet, box, scale (output px per sheet px), anchor rule, keep rule]
## anchor: "feet" (between the feet, at the soles), "base" (bottom centre: used for the runs and the lean so the
## body sits over its hit area), "center", "sign" (board's top-left).
## keep: "figure" (the main shape and its small specks), "largest" (only the biggest shape).
var CUTS := [
	["outlaw/idle", POSES, Rect2i(40, 64, 412, 732), OUTLAW_K, "feet", "figure"],
	["outlaw/aim", POSES, Rect2i(476, 72, 460, 724), OUTLAW_K, "feet", "figure"],
	["outlaw/hit", POSES, Rect2i(936, 128, 472, 668), OUTLAW_K, "feet", "figure"],
	["outlaw/crouch", POSES, Rect2i(1420, 320, 384, 476), OUTLAW_K, "feet", "figure"],
	["outlaw/run_left", ACTION, Rect2i(16, 40, 564, 652), OUTLAW_K, "base", "figure"],
	["outlaw/run_right", ACTION, Rect2i(596, 40, 584, 652), OUTLAW_K, "base", "figure"],
	["outlaw/lean", ACTION, Rect2i(1212, 36, 372, 672), OUTLAW_K, "base", "figure"],
	["outlaw/fall", ACTION, Rect2i(1644, 112, 524, 552), OUTLAW_K, "base", "largest"],
	["fx/hat", ACTION, Rect2i(1624, 20, 180, 152), OUTLAW_K, "center", "largest"],
	["prop/barrel", PROPS, Rect2i(36, 200, 248, 320), 18.0 * D / 312.0, "base", "largest"],
	["prop/crate", PROPS, Rect2i(316, 160, 328, 356), 22.0 * D / 348.0, "base", "largest"],
	["prop/tnt", PROPS, Rect2i(680, 120, 232, 396), 18.0 * D / 312.0, "base", "figure"],
	["prop/wagon", PROPS, Rect2i(972, 20, 936, 520), 50.0 * D / 928.0, "base", "largest"],
	["prop/trough", PROPS, Rect2i(36, 600, 820, 192), 12.0 * D / 184.0, "base", "largest"],
	["prop/sign", PROPS, Rect2i(916, 496, 484, 288), 22.0 * D / 476.0, "sign", "largest"],
	["prop/tumbleweed", PROPS, Rect2i(1488, 556, 280, 248), 10.0 * D / 272.0, "base", "largest"],
]
const Cut := preload("res://tools/cut.gd")
var _sheets := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for c in CUTS:
		_cut(c[0], c[1], c[2], c[3], c[4], c[5])
	_gun()
	_street()
	quit()


func _sheet(name: String) -> Image:
	if not _sheets.has(name):
		var im := Image.load_from_file(ProjectSettings.globalize_path(IN + name))
		im.convert(Image.FORMAT_RGBA8)
		_sheets[name] = im
	return _sheets[name]


func _cut(name: String, sheet: String, box: Rect2i, k: float, anchor_rule: String, keep: String) -> void:
	var src := _sheet(sheet)
	var im := src.get_region(box)
	if src.detect_alpha() == Image.ALPHA_NONE:
		_remove_cream(im)
	else:
		Cut.defringe(im)
	Cut.keep(im, keep)
	var out := Cut.scale(im, k)
	_save(name, out, anchor_rule)


## Floods the cream background in from the edges; light areas inside the figure stay.
func _remove_cream(im: Image) -> void:
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

func _save(name: String, im: Image, rule: String, extra := "") -> void:
	var w := im.get_width()
	var h := im.get_height()
	var anchor := Vector2i(w / 2, h)
	match rule:
		"feet", "base":
			# The lowest solid row, and the middle of what touches the ground there.
			var bottom := h - 1
			while bottom > 0 and _row_count(im, bottom) == 0:
				bottom -= 1
			var band := maxi(2, int(h * 0.04))
			var sx := 0.0
			var n := 0
			for y in range(bottom - band, bottom + 1):
				for x in w:
					if im.get_pixel(x, y).a > 0.5:
						sx += x
						n += 1
			anchor = Vector2i(roundi(sx / maxi(1, n)) if rule == "feet" else w / 2, bottom + 1)
		"center":
			anchor = Vector2i(w / 2, h / 2)
		"sign":
			var y := 0  # the board's top edge: the first row wider than half the sign (above it are the chains)
			while y < h and _row_count(im, y) < w / 2:
				y += 1
			anchor = Vector2i(0, y)
	var file := name.replace("/", "_") + ".png"
	var path := ProjectSettings.globalize_path(OUT + file)
	im.save_png(path)
	print('    "%s": {"frames": ["painted/%s"], "anchor": [%d, %d], "scale": 0.5%s},  # %dx%d' % [name, file, anchor.x, anchor.y, extra, w, h])


func _row_count(im: Image, y: int) -> int:
	var n := 0
	for x in im.get_width():
		if im.get_pixel(x, y).a > 0.5:
			n += 1
	return n


## The first-person revolver: the gloved hand and gun, with the coat sleeve cut away.
func _gun() -> void:
	var box := Rect2i(560, 150, 760, 800)
	var im := _sheet(GUN).get_region(box)
	_remove_cream(im)
	# Everything right of the glove's cuff (the shirt cuff and coat sleeve) goes.
	var a := Vector2(690, 440)
	var b := Vector2(552, 800)
	for y in im.get_height():
		for x in im.get_width():
			if (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x) < 0:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
	Cut.keep(im, "largest")
	var k := 300.0 / 800.0  # drawn about 150 base pixels tall: small, in the corner
	var out := Cut.scale(im, k, false)  # untrimmed, so the pivot and muzzle below stay put
	# The pivot is the glove's cuff, which goes in the screen's corner; the muzzle is the barrel's tip.
	var pivot := Vector2i(roundi(560 * k), roundi(780 * k))
	var muzzle := Vector2i(roundi(12 * k), roundi(75 * k))
	var file := "gun_peacemaker.png"
	out.save_png(ProjectSettings.globalize_path(OUT + file))
	print('    gun %dx%d: anchor %s, muzzle %s from the anchor' % [out.get_width(), out.get_height(), pivot, muzzle - pivot])


func _street() -> void:
	var im := _sheet(STREET)
	im.save_png(ProjectSettings.globalize_path(OUT + "main_street.png"))
	print('    "main_street/painted": {"frames": ["painted/main_street.png"], "anchor": [%d, 0], "scale": %.5f},' % [roundi(im.get_width() / 2.0 - 640.0 * im.get_height() / 720.0), 720.0 / im.get_height()])  # the pixel that lands on world x = 0, centring the play area
