extends SceneTree
## Art batch 2: Black Jack, his cards and his strongbox, into assets/painted, printing the manifest
## entries (anchors and points measured here):
##   Godot --headless --path . -s res://tools/import_black_jack.gd
## - his six poses: the hat-tip idle, the crouch (only what shows over the crate's rim: hat, eyes and
##   fingers; the game's own crate hides the rest), the card flip (his barrel kept, the drawn falling ace
##   and its motion strokes erased: the game's cards appear on the barrel top), aim, hit and the fall,
##   with his hat flying off cut out on its own;
## - the cards (ace of hearts, king of spades, seven of clubs, three of diamonds, the back), the hanging
##   strongbox (with the ring it hangs by) and the smashed crate;
## - his portrait: his head from the idle pose on a warm painted ground, like the bounty portraits;
## - the two henchmen: the painted outlaw recoloured, one with a grey hat and a blue bandana, one with
##   a black hat and a yellow bandana.
## Figures and props drawn in the street are stored at twice their screen size (manifest scale 0.5).

const Cut := preload("res://tools/cut.gd")
const IN := "res://assets/incoming/"
const OUT := "res://assets/painted/"
const JACK := "Black Jack_ Six Rogue Poses.png"
const CARDS := "Western Cards and Broken Strongboxes.png"
## His standing (idle) pose is this tall in the saved image: the outlaw's 165 screen pixels, stored at twice that.
const IDLE_PX := 330.0
## [name, box on the sheet, keep rule]
const POSES := [
	["idle", Rect2i(0, 16, 316, 700), "figure"],
	["crouch", Rect2i(316, 276, 316, 440), "all"],
	["flip", Rect2i(620, 20, 452, 696), "all"],
	["aim", Rect2i(1080, 16, 260, 700), "figure"],
	["hit", Rect2i(1336, 88, 380, 628), "figure"],
	["fall", Rect2i(1716, 160, 456, 552), "largest"],
]
const HAT := Rect2i(1984, 68, 172, 168)
## The crouch: the crate's rim (sheet pixels). Everything from it down goes but his fingertips over
## it (his skin, in the two hands' boxes), and so do the crate's back corners beside him above it.
const RIM_Y := 465
const RIM_KEEP_X := Vector2i(336, 596)
const HANDS := [Rect2i(336, 440, 68, 40), Rect2i(530, 445, 58, 35)]
## The card flip: the falling ace and the strokes drawn round it, and the crouch's crate edge at the
## box's left (sheet pixels). The barrel's top rim
## starts at y 397, below them.
const FLIP_ERASE := [Rect2i(620, 20, 14, 696), Rect2i(906, 262, 112, 135), Rect2i(880, 340, 28, 58), Rect2i(968, 236, 50, 28)]
## The barrel's columns on the sheet start right of his boots.
const BARREL_FROM_X := 778
const CARD_BOXES := {"A": Rect2i(476, 20, 204, 296), "K": Rect2i(728, 20, 208, 300), "7": Rect2i(992, 20, 204, 300),
	"3": Rect2i(1248, 20, 204, 300), "back": Rect2i(1496, 20, 208, 296)}
const CARD_PX := 96.0  # cards stand 12 units tall on the barrel (stored at twice their 48 screen pixels)
const STRONGBOX := Rect2i(396, 328, 420, 380)
const STRONGBOX_PX := 128.0  # 16 units wide
const SMASHED := Rect2i(860, 336, 1050, 384)
const SMASHED_PX := 480.0  # 60 units across, splinters and all
const HEAD := Rect2i(40, 12, 256, 256)  # the portrait: his head and hat-tipping hand, from the idle pose
const LOOKS := {
	"grey": {"hat": "grey", "bandana": 0.6},  # a grey hat, a blue bandana
	"black": {"hat": "black", "bandana": 0.13},  # a black hat, a yellow bandana
}
const OUTLAW_POSES := ["idle", "aim", "hit", "fall"]

var _sheets := {}
var _k := 0.0


func _init() -> void:
	_poses()
	_cards()
	_portrait()
	_henchmen()
	quit()


func _sheet(name: String) -> Image:
	if not _sheets.has(name):
		var im := Image.load_from_file(ProjectSettings.globalize_path(IN + name))
		im.convert(Image.FORMAT_RGBA8)
		_sheets[name] = im
	return _sheets[name]


func _poses() -> void:
	var src := _sheet(JACK)
	for p in POSES:
		var box: Rect2i = p[1]
		var im := src.get_region(box)
		Cut.defringe(im)
		match p[0]:
			"crouch":
				for y in im.get_height():
					for x in im.get_width():
						var s := Vector2i(x, y) + box.position
						var finger: bool = HANDS.any(func(r): return r.has_point(s)) and _skin(im.get_pixel(x, y))
						if (s.y >= RIM_Y and not finger) or (s.y >= RIM_Y - 25 and s.y < RIM_Y and (s.x < RIM_KEEP_X.x or s.x > RIM_KEEP_X.y)):
							im.set_pixel(x, y, Color(0, 0, 0, 0))
			"flip":
				for r in FLIP_ERASE:
					im.fill_rect(Rect2i(r.position - box.position, r.size), Color(0, 0, 0, 0))
		if p[2] != "all":
			Cut.keep(im, p[2])
		var used := im.get_used_rect()
		if _k == 0.0:
			_k = IDLE_PX / used.size.y
		var out := Cut.scale(im, _k)
		var file: String = "black_jack_" + p[0]
		match p[0]:
			"crouch":  # anchored at the rim's middle: the game puts it on its crate's top edge, in front
				_save(file, out)
				_say("black_jack/crouch", file, Vector2i(out.get_width() / 2, roundi((RIM_Y - box.position.y - used.position.y) * _k)))
			"flip":
				_flip(file, out, used)
			_:
				_save(file, out)
				_say("black_jack/" + p[0], file, _feet(out, 0, out.get_width()))
	var hat := src.get_region(HAT)
	Cut.defringe(hat)
	Cut.keep(hat, "largest")
	var h := Cut.scale(hat, _k)
	_save("fx_jack_hat", h)
	_say("fx/jack_hat", "fx_jack_hat", Vector2i(h.get_width() / 2, h.get_height() / 2))


## The card flip: anchored at his boots (not the barrel), with the barrel's top centre (where the game's
## cards land) and its base as points.
func _flip(file: String, out: Image, used: Rect2i) -> void:
	var split := roundi((BARREL_FROM_X - POSES[2][1].position.x - used.position.x) * _k)
	var feet := _feet(out, 0, split)
	# The barrel's sides, low down; then its top: the highest row still spanning most of it (his arm
	# reaches over the barrel higher up, but never that wide).
	var row := int(out.get_height() * 0.85)
	var lo := out.get_width()
	var hi := 0
	for x in range(split, out.get_width()):
		if out.get_pixel(x, row).a > 0.5:
			lo = mini(lo, x)
			hi = maxi(hi, x)
	var top := row
	while top > 0 and _count_in(out, top - 1, lo, hi + 1) >= (hi - lo) * 0.6:
		top -= 1
	var card := Vector2i((lo + hi) / 2, top + roundi(10 * _k))  # a little into the top's ellipse
	_save(file, out)
	_say("black_jack/flip", file, feet, ', "points": {"card": [%d, %d], "barrel": [%d, 0]}, "barrel_width": %d' % [
		card.x - feet.x, card.y - feet.y, (lo + hi) / 2 - feet.x, hi - lo + 1])


func _cards() -> void:
	var src := _sheet(CARDS)
	for key in CARD_BOXES:
		var im := src.get_region(CARD_BOXES[key])
		Cut.defringe(im)
		Cut.keep(im, "largest")
		var out := Cut.scale(im, CARD_PX / im.get_used_rect().size.y)
		_save("card_" + key, out)
		_say("card/" + key, "card_" + key, Vector2i(out.get_width() / 2, out.get_height()))
	var box := src.get_region(STRONGBOX)
	Cut.defringe(box)
	Cut.keep(box, "largest")
	var sb := Cut.scale(box, STRONGBOX_PX / box.get_used_rect().size.x)
	_save("prop_strongbox", sb)
	var ring_x := 0.0
	var rn := 0
	for x in sb.get_width():
		if sb.get_pixel(x, 1).a > 0.5:
			ring_x += x
			rn += 1
	var body_top := 0  # the box's lid: the first row wider than half the image (above it is the ring)
	while body_top < sb.get_height() and _row_count(sb, body_top) < sb.get_width() / 2:
		body_top += 1
	_say("prop/strongbox", "prop_strongbox", Vector2i(sb.get_width() / 2, sb.get_height()), ', "points": {"ring": [%d, %d], "lid": [0, %d]}' % [
		roundi(ring_x / maxi(1, rn)) - sb.get_width() / 2, -sb.get_height(), body_top - sb.get_height()])
	var sm := src.get_region(SMASHED)
	Cut.defringe(sm)
	var smo := Cut.scale(sm, SMASHED_PX / sm.get_used_rect().size.x)
	_save("prop_crate_smashed", smo)
	_say("prop/crate_smashed", "prop_crate_smashed", Vector2i(smo.get_width() / 2, smo.get_height()))


## His head on a warm painted ground (a soft radial wash, like the bounty portraits' backgrounds).
func _portrait() -> void:
	var head := _sheet(JACK).get_region(HEAD)
	Cut.defringe(head)
	var out := Image.create_empty(HEAD.size.x, HEAD.size.y, false, Image.FORMAT_RGBA8)
	var c := Vector2(HEAD.size) * Vector2(0.55, 0.4)
	for y in out.get_height():
		for x in out.get_width():
			var d := minf(1.0, Vector2(x, y).distance_to(c) / (HEAD.size.x * 0.75))
			var grain := sin(x * 0.31 + y * 0.17) * 0.012 + sin(x * 0.07 - y * 0.13) * 0.02
			out.set_pixel(x, y, Color(0.88, 0.62, 0.36).lerp(Color(0.62, 0.36, 0.2), d * d) + Color(grain, grain, grain, 0))
	out.blend_rect(head, Rect2i(Vector2i.ZERO, head.get_size()), Vector2i.ZERO)
	_save("portrait_black_jack", out)
	print('    "portrait/black_jack": "painted/portrait_black_jack.png",')


## The henchmen: the painted outlaw's poses, his hat and bandana recoloured.
func _henchmen() -> void:
	for look in LOOKS:
		for pose in OUTLAW_POSES:
			var im := Image.load_from_file(ProjectSettings.globalize_path(OUT + "outlaw_%s.png" % pose))
			im.convert(Image.FORMAT_RGBA8)
			if pose != "fall":  # he loses his hat as he falls (it flies off as fx/hat)
				_recolour_hat(im, _hat_mask(im), LOOKS[look].hat)
			_recolour_bandana(im, LOOKS[look].bandana)
			_save("henchman_%s_%s" % [look, pose], im)
		var hat := Image.load_from_file(ProjectSettings.globalize_path(OUT + "fx_hat.png"))
		hat.convert(Image.FORMAT_RGBA8)
		var all := PackedByteArray()
		all.resize(hat.get_width() * hat.get_height())
		all.fill(1)
		_recolour_hat(hat, all, LOOKS[look].hat)
		_save("fx_hat_%s" % look, hat)
	print("    henchmen: copy the outlaw's anchors and scale for henchman_<look>/<pose> and fx/hat_<look>")


## The hat: every sizeable patch of the hat's browns above the brim's depth (its painted texture and
## outline split it into patches). His skin is yellower and brighter, so the face never joins in.
func _hat_mask(im: Image) -> PackedByteArray:
	var w := im.get_width()
	var h := im.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var top := 0
	while top < h and _row_count(im, top) == 0:
		top += 1
	var limit := mini(h, top + int(h * 0.24))
	for sy in range(top, limit):
		for sx in w:
			if seen[sy * w + sx] == 1 or not _hat_colour(im.get_pixel(sx, sy)):
				continue
			var patch: Array[Vector2i] = [Vector2i(sx, sy)]
			seen[sy * w + sx] = 1
			var i := 0
			while i < patch.size():
				var p: Vector2i = patch[i]
				i += 1
				for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < top or q.x >= w or q.y >= limit or seen[q.y * w + q.x] == 1:
						continue
					if _hat_colour(im.get_pixel(q.x, q.y)):
						seen[q.y * w + q.x] = 1
						patch.append(q)
			if patch.size() >= 12:
				for p in patch:
					mask[p.y * w + p.x] = 1
	# Its rim light and soft edges: orange pixels touching it (not his skin).
	for _ring in 2:
		_grow_hat(im, mask, top, limit)
	return mask


## One ring of the hat's edge: orange pixels touching it. Above the brim (no face up there) its
## brightest highlights join too; lower down, nothing that could be his skin.
func _grow_hat(im: Image, mask: PackedByteArray, top: int, limit: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var crown := top + int(h * 0.13)
	var edge: Array[int] = []
	for y in range(top, limit):
		for x in w:
			var c := im.get_pixel(x, y)
			if mask[y * w + x] == 1 or c.a < 0.05 or c.h > 0.11 or c.v < 0.2 or (_skin(c) and y > crown):
				continue
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and mask[q.y * w + q.x] == 1:
					edge.append(y * w + x)
					break
	for i in edge:
		mask[i] = 1


static func _skin(c: Color) -> bool:
	return c.a > 0.5 and c.v > 0.72 and c.s < 0.72 and c.h > 0.03 and c.h < 0.12


static func _hat_colour(c: Color) -> bool:
	return c.a > 0.5 and c.v > 0.2 and c.v < 0.8 and c.s > 0.35 and c.h > 0.015 and c.h < 0.06  # his skin is yellower and brighter, the bandana and impact strokes redder


static func _recolour_hat(im: Image, mask: PackedByteArray, to: String) -> void:
	var w := im.get_width()
	for y in im.get_height():
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var c := im.get_pixel(x, y)
			var v := c.v
			var out := Color.from_hsv(0.6, 0.07, clampf(v * 0.95 + 0.06, 0, 1), c.a) if to == "grey" else Color.from_hsv(0.05, 0.25, v * 0.36, c.a)
			im.set_pixel(x, y, out)


## The bandana: the outlaw's strong red (nothing else on him is that red), turned to a new hue.
static func _recolour_bandana(im: Image, hue: float) -> void:
	for y in int(im.get_height() * 0.5):
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.05 and c.s > 0.55 and c.v > 0.3 and (c.h < 0.035 or c.h > 0.95):
				var v := clampf(c.v * (1.15 if hue < 0.3 else 0.9), 0, 1)
				im.set_pixel(x, y, Color.from_hsv(hue, c.s * (0.9 if hue < 0.3 else 0.8), v, c.a))


static func _feet(im: Image, from_x: int, to_x: int) -> Vector2i:
	var bottom := im.get_height() - 1
	while bottom > 0 and _count_in(im, bottom, from_x, to_x) == 0:
		bottom -= 1
	var band := maxi(2, int(im.get_height() * 0.04))
	var sx := 0.0
	var n := 0
	for y in range(bottom - band, bottom + 1):
		for x in range(from_x, to_x):
			if im.get_pixel(x, y).a > 0.5:
				sx += x
				n += 1
	return Vector2i(roundi(sx / maxi(1, n)), bottom + 1)


static func _count_in(im: Image, y: int, from_x: int, to_x: int) -> int:
	var n := 0
	for x in range(from_x, to_x):
		if im.get_pixel(x, y).a > 0.5:
			n += 1
	return n


static func _row_count(im: Image, y: int) -> int:
	return _count_in(im, y, 0, im.get_width())


func _save(file: String, im: Image) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT + file + ".png"))


func _say(name: String, file: String, anchor: Vector2i, extra := "") -> void:
	print('    "%s": {"frames": ["painted/%s.png"], "anchor": [%d, %d], "scale": 0.5%s},' % [name, file, anchor.x, anchor.y, extra])
