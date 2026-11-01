extends SceneTree
## Cuts the painted art in assets/incoming into game-ready sprites in
## assets/painted, and prints their manifest entries (anchors measured here).
## Re-run after replacing a sheet:
##   Godot --headless --path . -s res://tools/import_painted.gd
## Boxes come from tools/measure_sheets.gd. For each piece it:
##   - removes plain cream backgrounds by flooding in from the box's edges, and
##     trims the faint matte halo on sheets that already have transparency;
##   - removes the ground shadow painted under it (the game adds its own contact shadows);
##   - keeps the figure itself (the fall pose without its flying hat, the hat on its own);
##   - scales it to the size the game already draws it at: outlaws so the standing pose is
##     160 pixels tall, props to a set height or width (the art they replace);
##   - trims to the opaque pixels and measures the foot (or base) anchor.
## Outlaws are stored at 8 pixels per gameplay unit; props at their manifest scale.

const IN := "res://assets/incoming/"
const OUT := "res://assets/painted/"
const D := 8.0  # output pixels per gameplay unit
const POSES := "Stylised Western Outlaw Pose Collection.png"
const ACTION := "Angular Cowboy Outlaw Pose Sheet.png"
const PROPS := "Western Town Essentials_ Barrels, Crates and Wagon.png"
const GUN := "Stylised Western Revolver Close-Up.png"
const STREET := "High Noon Western Main Street.png"
## The idle pose's full height becomes 20 units (160 pixels): about the hitbox, plus the hat brim.
const IDLE_PX := 20.0 * D

## [name, sheet, box, size, anchor rule, keep rule, ground shadow to remove]
## size: "outlaw" (the outlaw's common scale, set by the idle pose), or ["h", px] / ["w", px] for the output height or width.
## anchor: "feet" (between the feet, at the soles), "base" (bottom centre: used for the runs and the lean so the
## body sits over its hit area), "center", "sign" (board's top-left).
## keep: "figure" (the main shape and its small specks), "largest" (only the biggest shape).
var CUTS := [
	["outlaw/idle", POSES, Rect2i(44, 16, 348, 692), "outlaw", "feet", "figure", false],
	["outlaw/aim", POSES, Rect2i(408, 20, 392, 688), "outlaw", "feet", "figure", false],
	["outlaw/hit", POSES, Rect2i(796, 48, 494, 660), "outlaw", "feet", "figure", false],
	["outlaw/crouch", POSES, Rect2i(1284, 208, 424, 500), "outlaw", "feet", "largest", false],
	["outlaw/lean", POSES, Rect2i(1708, 92, 452, 616), "outlaw", "base", "figure", false],
	["outlaw/run_left", ACTION, Rect2i(44, 40, 516, 664), "outlaw", "base", "figure", true],
	["outlaw/run_right", ACTION, Rect2i(564, 40, 560, 664), "outlaw", "base", "figure", true],
	["outlaw/fall", ACTION, Rect2i(1620, 104, 548, 600), "outlaw", "base", "largest", true],
	["fx/hat", ACTION, Rect2i(1580, 24, 200, 160), "outlaw", "center", "largest", false],
	["prop/barrel", PROPS, Rect2i(36, 184, 268, 344), ["h", 148], "base", "largest", true],
	["prop/crate", PROPS, Rect2i(316, 148, 344, 380), ["h", 178], "base", "largest", true],
	["prop/tnt", PROPS, Rect2i(676, 90, 252, 436), ["h", 165], "base", "figure", true],
	["prop/wagon", PROPS, Rect2i(972, 12, 924, 516), ["w", 403], "base", "largest", true],
	["prop/trough", PROPS, Rect2i(40, 568, 836, 244), ["w", 427], "base", "largest", true],
	["prop/sign", PROPS, Rect2i(930, 540, 484, 272), ["w", 179], "sign", "largest", false],
	["prop/tumbleweed", PROPS, Rect2i(1464, 540, 356, 276), ["h", 72], "base", "largest", true],
]
const Cut := preload("res://tools/cut.gd")
var _sheets := {}
var _outlaw_k := 0.0  # output px per sheet px for every outlaw piece, from the idle pose


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for c in CUTS:
		_cut(c[0], c[1], c[2], c[3], c[4], c[5], c[6])
	_gun()
	_street()
	quit()


func _sheet(name: String) -> Image:
	if not _sheets.has(name):
		var im := Image.load_from_file(ProjectSettings.globalize_path(IN + name))
		im.convert(Image.FORMAT_RGBA8)
		_sheets[name] = im
	return _sheets[name]


func _cut(name: String, sheet: String, box: Rect2i, size: Variant, anchor_rule: String, keep: String, shadow: bool) -> void:
	var src := _sheet(sheet)
	var im := src.get_region(box)
	var cream := src.detect_alpha() == Image.ALPHA_NONE
	if shadow:
		Cut.remove_shadow(im, im.get_pixel(0, 0) if cream else null, 0.18, 0.45 if cream else 0.16)  # flat cream sheets: a wider match for its soft edge
	if cream:
		Cut.remove_cream(im)
	else:
		Cut.defringe(im)
	Cut.keep(im, keep)
	var used := im.get_used_rect()
	var k: float
	if size is String:  # the outlaw: one scale for all his pieces, set by the standing pose
		if _outlaw_k == 0.0:
			_outlaw_k = IDLE_PX / used.size.y
		k = _outlaw_k
	else:
		k = float(size[1]) / (used.size.y if size[0] == "h" else used.size.x)
	var out := Cut.scale(im, k)
	_save(name, out, anchor_rule)


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
	var box := Rect2i(470, 130, 830, 894)
	var im := _sheet(GUN).get_region(box)
	Cut.remove_cream(im)
	# Everything right of the glove's cuff (the shirt cuff and coat sleeve) goes.
	var a := Vector2(1290, 672) - Vector2(box.position)
	var b := Vector2(1103, 1024) - Vector2(box.position)
	for y in im.get_height():
		for x in im.get_width():
			if (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x) < 0:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x + box.position.x > 1120 and y + box.position.y > 650:  # the light shirt cuff curving under the glove's edge
				var c := im.get_pixel(x, y)
				if c.r > 0.8 and c.g > 0.55 and c.b > 0.35:
					im.set_pixel(x, y, Color(0, 0, 0, 0))
	Cut.keep(im, "largest")
	var k := 300.0 / box.size.y  # drawn 150 base pixels tall (about a fifth of the screen), in the corner
	var out := Cut.scale(im, k, false)  # untrimmed, so the pivot and muzzle below stay put
	# The pivot is the glove's cuff, which goes in the screen's corner; the muzzle is the barrel's tip.
	var pivot := Vector2i(roundi(680 * k), roundi(870 * k))
	var muzzle := Vector2i(roundi(25 * k), roundi(83 * k))
	var file := "gun_peacemaker.png"
	out.save_png(ProjectSettings.globalize_path(OUT + file))
	print('    gun %dx%d: anchor %s, muzzle %s from the anchor' % [out.get_width(), out.get_height(), pivot, muzzle - pivot])


func _street() -> void:
	var im := _sheet(STREET)
	im.save_png(ProjectSettings.globalize_path(OUT + "main_street.png"))
	print('    "main_street/painted": {"frames": ["painted/main_street.png"], "anchor": [%d, 0], "scale": %.5f},' % [roundi(im.get_width() / 2.0 - 640.0 * im.get_height() / 720.0), 720.0 / im.get_height()])  # the pixel that lands on world x = 0, centring the play area
