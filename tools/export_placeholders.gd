extends SceneTree
## Exports the prototype's code-drawn visuals as placeholder PNGs, so the game
## itself only ever shows image files. Re-run after changing a recipe:
##   Godot --headless --path . -s res://tools/export_placeholders.gd
##
## Recipes are ported from highnoon.html (buildBg, drawCover, drawWindowFrame,
## drawDuel, drawGun, the HUD icons...). Everything is drawn in the prototype's
## 320×180 units. Recipes pass the scale for the old 640×360 base (PX = 2 per
## unit, UI at 1×); save() multiplies every image by OUTPUT_SCALE for the
## 1280×720 base, so world art lands at 4 pixels per unit and UI at 2×.
## Kit sprites (art/sprites, art/guns) are copied at the same density, and each
## outlaw is also cut into parts for its cut-out rig (_rig_parts).
## Nothing here runs in the game.

const OUT := "res://assets/placeholder/"
const KIT := "res://port_kit/high-noon-port-kit/"
const PX := 2  # pixels per unit at the old 640×360 base
const OUTPUT_SCALE := 2  # 640×360 -> 1280×720
const BG_LEFT := -80  # wide background layers cover world x -80..400 (960 px)
const BG_W := 480
const H := 180
const GY := 160

var written := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_backgrounds()
	_props()
	_characters()
	_guns()
	_fx()
	_duel()
	_ui()
	_splash()
	_office()
	_posters()
	_home_ui()
	print("Exported %d placeholder images to %s" % [written, OUT])
	quit()


# ---------- drawing primitives (units) ----------

func img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func rect(im: Image, x: float, y: float, w: float, h: float, col: Variant) -> void:
	var c: Color = Color(col) if col is String else col
	var x0 := maxi(0, floori(x))
	var y0 := maxi(0, floori(y))
	var x1 := mini(im.get_width(), floori(x + w))
	var y1 := mini(im.get_height(), floori(y + h))
	if x1 <= x0 or y1 <= y0:
		return
	if c.a >= 1.0:
		im.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
		return
	for py in range(y0, y1):
		for px in range(x0, x1):
			im.set_pixel(px, py, im.get_pixel(px, py).blend(c))


func disc(im: Image, cx: float, cy: float, r: float, col: Variant) -> void:
	var ri := int(r)
	for dy in range(-ri, ri + 1):
		var w := floori(sqrt(r * r - dy * dy))
		rect(im, roundf(cx - w), roundf(cy + dy), w * 2, 1, col)


const GLYPHS := {"A": "25755", "B": "65656", "C": "34443", "D": "65556", "E": "74647", "H": "55755", "I": "72227",
	"K": "55655", "L": "44447", "N": "65555", "O": "25552", "S": "34216", "T": "72222", "W": "55775", "G": "34553",
	"X": "55255", "J": "11152", "Q": "25563", "3": "61216", "5": "74616", "7": "71122", "9": "75716", "P": "65644",
	"R": "65655", "U": "55557", "M": "57755", "!": "22202", " ": "00000"}


func text(im: Image, s: String, x: float, y: float, col: String, sc := 1) -> void:
	for i in s.length():
		var gl: String = GLYPHS.get(s[i], "")
		for r in gl.length():
			for k in 3:
				if int(gl[r]) & (4 >> k):
					rect(im, x + (i * 4 + k) * sc, y + r * sc, sc, sc, col)


func rows(lines: Array, pal: Dictionary) -> Image:
	var w := 0
	for l in lines:
		w = maxi(w, l.length())
	var im := img(w, lines.size())
	for y in lines.size():
		for x in lines[y].length():
			var ch: String = lines[y][x]
			if ch != ".":
				im.set_pixel(x, y, Color(pal[ch]))
	return im


func save(im: Image, path: String, scale := PX) -> void:
	var out := im.duplicate()
	var k := scale * OUTPUT_SCALE
	if k != 1:
		out.resize(im.get_width() * k, im.get_height() * k, Image.INTERPOLATE_NEAREST)
	var full := ProjectSettings.globalize_path(OUT + path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	out.save_png(full)
	written += 1


func kit_image(path: String) -> Image:
	var im := Image.load_from_file(ProjectSettings.globalize_path(KIT + path))
	im.convert(Image.FORMAT_RGBA8)
	return im


static func hash32(n: int) -> int:
	const M := 0xFFFFFFFF
	n = ((n ^ 61) ^ (n >> 16)) & M
	n = (n * 9) & M
	n = (n ^ (n >> 4)) & M
	n = (n * 0x27d4eb2d) & M
	n = (n ^ (n >> 15)) & M
	return n


# ---------- Main Street background layers (buildBg) ----------

func _backgrounds() -> void:
	var ox := -BG_LEFT  # image x = world x + ox
	# Sky with the sun.
	var sky := img(BG_W, H)
	var top := Color("#E8894A")
	var bottom := Color("#F7D9A0")
	for y in 130:
		rect(sky, 0, y, BG_W, 1, top.lerp(bottom, clampf((y + 0.5) / 110.0, 0, 1)))
	rect(sky, 0, 130, BG_W, H - 130, bottom)
	disc(sky, 160 + ox, 34, 12, "#FFE9B0")
	save(sky, "main_street/sky.png")

	# Distant mesas.
	var far := img(BG_W, H)
	for m in [[-74, 72, 50], [-28, 66, 30], [0, 70, 60], [50, 60, 40], [230, 64, 90], [290, 74, 40], [336, 66, 34], [366, 60, 34]]:
		rect(far, m[0] + ox, m[1], m[2], 60, "#D07E52")
		rect(far, m[0] + 4 + ox, m[1] - 4, m[2] - 8, 4, "#D07E52")
	save(far, "main_street/far.png")

	# Saloon, bank and their neighbours, with the painted signs.
	var b := img(BG_W, H)
	_plank(b, -78 + ox, 52, 84, 76, "#8A6440", "#704E30")
	rect(b, -80 + ox, 50, 88, 3, "#5A3A24")
	rect(b, -60 + ox, 66, 22, 18, "#2A1A12")
	_plank(b, 8 + ox, 30, 140, 98, "#9A4430", "#7E3424")
	rect(b, 6 + ox, 28, 144, 3, "#6E4526")
	rect(b, 8 + ox, 90, 140, 4, "#6E4526")
	rect(b, 40 + ox, 36, 76, 14, "#F2D9A8")
	rect(b, 40 + ox, 36, 76, 1, "#6E4526")
	rect(b, 40 + ox, 49, 76, 1, "#6E4526")
	_plank(b, 172 + ox, 42, 140, 86, "#6E9A8E", "#577F74")
	rect(b, 170 + ox, 40, 144, 3, "#7A5232")
	rect(b, 172 + ox, 98, 140, 4, "#7A5232")
	rect(b, 216 + ox, 48, 52, 14, "#E8E2D2")
	rect(b, 216 + ox, 48, 52, 1, "#7A5232")
	rect(b, 216 + ox, 61, 52, 1, "#7A5232")
	_plank(b, 314 + ox, 58, 86, 70, "#B08A58", "#94713F")
	rect(b, 312 + ox, 56, 90, 3, "#6E4526")
	rect(b, 340 + ox, 72, 22, 18, "#2A1A12")
	rect(b, 148 + ox, 60, 24, 68, "#5A3A24")
	var windows: Array = _json("data/scenes.json").street.windows
	for w in windows:
		rect(b, w.x + ox, w.y, w.w, w.h, "#2A1A12")
	rect(b, 66 + ox, 98, 28, 30, "#2A1A12")
	rect(b, 226 + ox, 102, 26, 26, "#2A1A12")
	rect(b, 68 + ox, 106, 11, 14, "#C08A54")
	rect(b, 81 + ox, 106, 11, 14, "#C08A54")
	rect(b, 228 + ox, 102, 22, 26, "#7A5232")
	rect(b, 238 + ox, 102, 2, 26, "#5A3A24")
	text(b, "SALOON", 54 + ox, 39, "#8E2A1E", 2)
	text(b, "BANK", 226 + ox, 51, "#2A3A5A", 2)
	save(b, "main_street/buildings.png")

	# Boardwalk, posts, the bottle rail and the street.
	var s := img(BG_W, H)
	rect(s, 0, 128, BG_W, 6, "#7A5232")
	for i in range(0, BG_W, 10):
		rect(s, i, 128, 1, 6, "#5A3A24")
	for px in [-70, -30, 10, 60, 100, 146, 174, 220, 260, 310, 350, 390]:
		rect(s, px + ox, 94, 3, 34, "#6E4526")
	rect(s, 0, 118, BG_W, 2, "#6E4526")
	rect(s, 0, 134, BG_W, H - 134, "#D9A86C")
	for i in 390:
		var hh := hash32(i * 7 + 3)
		var x := hh % 320 + ox if i < 260 else (hh % 160 if hh % 160 < 80 else hh % 160 + 320)
		rect(s, x, 136 + (hh >> 9) % 44, 1 + (hh >> 3) % 3, 1, "#C9965A" if hh % 3 else "#E6BC84")
	rect(s, 0, 134, BG_W, 2, Color(120 / 255.0, 70 / 255.0, 30 / 255.0, 0.25))
	save(s, "main_street/street.png")

	# Window frames, drawn in front of window outlaws. Anchor: the window's top-left.
	for i in windows.size():
		var w: Dictionary = windows[i]
		var f := img(w.w + 4, w.h + 5)
		rect(f, 0, 0, w.w + 4, 2, "#5A3A24")
		rect(f, 0, w.h + 2, w.w + 4, 3, "#5A3A24")
		rect(f, 0, 2, 2, w.h, "#5A3A24")
		rect(f, w.w + 2, 2, 2, w.h, "#5A3A24")
		var curtain := "#E8C36A" if w.x < 150 else "#B8323E"
		rect(f, 2, 2, 4, w.h - 4, curtain)
		rect(f, w.w - 2, 2, 4, w.h - 4, curtain)
		save(f, "main_street/window_%d.png" % i)


func _plank(im: Image, x0: int, y0: int, w: int, h: int, base: String, line: String) -> void:
	rect(im, x0, y0, w, h, base)
	for yy in range(y0 + 4, y0 + h, 5):
		rect(im, x0, yy, w, 1, line)
	for i in w * h / 60:
		var hh := hash32(i + x0 * 31)
		rect(im, x0 + hh % w, y0 + (hh >> 8) % h, 2, 1, line)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(KIT + path))


# ---------- props (drawCover, the sign) ----------

func _props() -> void:
	for kind in ["barrel", "tnt"]:
		var tnt: bool = kind == "tnt"
		for spark in ([0, 1] if tnt else [0]):
			var im := img(14, 23)
			var y := 23
			rect(im, 0, y - 18, 14, 18, "#3A2414")
			rect(im, 1, y - 17, 12, 16, "#B8323E" if tnt else "#8A5A32")
			rect(im, 1, y - 14, 12, 2, "#8E2530" if tnt else "#6E4526")
			rect(im, 1, y - 6, 12, 2, "#8E2530" if tnt else "#6E4526")
			if tnt:
				text(im, "TNT", 2, y - 12, "#F4E2B8")
				rect(im, 6, y - 22, 1, 4, "#E8DCC4")
				if spark:
					rect(im, 6, y - 23, 1, 1, "#FFD45E")
			save(im.get_region(Rect2i(0, 0 if tnt else 5, 14, 23 if tnt else 18)), "props/%s%s.png" % [kind, "_%d" % spark if tnt else ""])
	var crate := img(18, 22)
	for bx in [[0, 11, 18, 11], [2, 0, 14, 11]]:
		rect(crate, bx[0], bx[1], bx[2], bx[3], "#5A3A24")
		rect(crate, bx[0] + 1, bx[1] + 1, bx[2] - 2, bx[3] - 2, "#C08A54")
		rect(crate, bx[0] + 1, floorf(bx[1] + bx[3] / 2.0 - 1), bx[2] - 2, 1, "#8E5E34")
	save(crate, "props/crate.png")
	var wagon := img(50, 26)
	rect(wagon, 0, 4, 50, 14, "#5A3A24")
	rect(wagon, 1, 5, 48, 12, "#9C6A43")
	for i in 3:
		rect(wagon, 1, 8 + i * 4, 48, 1, "#865834")
	rect(wagon, 4, 0, 42, 4, "#E8DCC4")
	for cx in [9, 41]:
		disc(wagon, cx, 19, 7, "#3A2414")
		disc(wagon, cx, 19, 5, "#8A5A32")
		rect(wagon, cx - 1, 18, 2, 2, "#3A2414")
	save(wagon, "props/wagon.png")
	var trough := img(34, 12)
	rect(trough, 0, 0, 34, 12, "#5A3A24")
	rect(trough, 1, 1, 32, 10, "#9C6A43")
	rect(trough, 2, 1, 30, 2, "#5FA8C8")
	save(trough, "props/trough.png")
	var sign := img(22, 12)
	rect(sign, 0, 0, 22, 12, "#3A2414")
	rect(sign, 1, 1, 20, 10, "#C9A25A")
	text(sign, "INN", 5, 4, "#5A2E1A")
	save(sign, "props/sign.png")
	var beam := img(30, 3)
	rect(beam, 0, 0, 30, 3, "#5A3A24")
	save(beam, "props/sign_beam.png")
	var rope := img(1, 5)
	rect(rope, 0, 0, 1, 5, "#E8DCC4")
	save(rope, "props/sign_rope.png")


# ---------- characters: cut-out rig parts ----------

## Cut-out rig parts for each outlaw, cut from the kit's 14×19 sprites. Real art replaces each part
## separately; the joints and animations live in the manifest's "rigs" section.
func _characters() -> void:
	for who in ["outlaw", "iron_eli", "black_jack"]:
		var idle := kit_image("art/sprites/%s_idle.png" % who)
		var aim := kit_image("art/sprites/%s_aim.png" % who)
		var run := kit_image("art/sprites/%s_run.png" % who)
		save(idle.get_region(Rect2i(0, 0, 14, 8)), "%s_parts/head.png" % who)  # hat, face and bandana
		var torso := idle.get_region(Rect2i(2, 8, 10, 6))
		torso.fill_rect(Rect2i(0, 1, 2, 4), Color(0, 0, 0, 0))  # the arms are separate parts
		torso.fill_rect(Rect2i(8, 1, 2, 4), Color(0, 0, 0, 0))
		save(torso, "%s_parts/torso.png" % who)
		save(idle.get_region(Rect2i(1, 9, 3, 4)), "%s_parts/arm_back.png" % who)
		save(idle.get_region(Rect2i(10, 9, 3, 4)), "%s_parts/arm_front.png" % who)
		save(aim.get_region(Rect2i(2, 10, 10, 3)), "%s_parts/gun_hand.png" % who)  # both hands on the revolver
		save(idle.get_region(Rect2i(0, 14, 14, 5)), "%s_parts/legs.png" % who)
		save(run.get_region(Rect2i(0, 14, 14, 5)), "%s_parts/legs_run.png" % who)
	# Iron Eli's breastplate, a part over his torso while he wears it (drawEnemy).
	for cracked in [false, true]:
		var plate := img(10, 6)  # same box as the torso part
		rect(plate, 1, 0, 8, 6, "#3A3F4A")
		rect(plate, 2, 1, 6, 4, "#8A93A2")
		for rv in [[2, 1], [7, 1], [2, 4], [7, 4]]:
			rect(plate, rv[0], rv[1], 1, 1, "#C9D0DA")
		if cracked:
			for cr in [[4, 1, 1, 2], [5, 2, 1, 2], [4, 4, 1, 1], [6, 1, 1, 1]]:
				rect(plate, cr[0], cr[1], cr[2], cr[3], "#1E1A16")
		save(plate, "iron_eli_parts/armour_%s.png" % ("cracked" if cracked else "intact"))
	for name in ["hostage", "bottle", "tumbleweed"]:
		save(kit_image("art/sprites/%s.png" % name), "props/%s.png" % name)


# ---------- guns (the kit's guns, plus the reload glint frame) ----------

func _guns() -> void:
	for w in _json("data/weapons.json"):
		for f in w.fins.size():
			var im := kit_image("art/guns/%s_%d.png" % [w.id, f])
			save(im, "guns/%s_%d.png" % [w.id, f])
			rect(im, 34, 3, 13, 1, w.fins[f].p.hi)
			save(im, "guns/%s_%d_reload.png" % [w.id, f])


# ---------- effects ----------

const PARTICLES := {
	"blood": ["#B8323E", "#F4E2B8"], "dust_ground": ["#E6BC84", "#C9965A"], "dust_wall": ["#5A3A24", "#C08A54"],
	"splinter": ["#C08A54", "#5A3A24"], "glass": ["#3FA45B", "#C8F2D2"], "smoke": ["#E6E6E6", "#BDBDC4"],
	"blast": ["#FFD45E", "#FF8A1F", "#E2463B", "#3A2414", "#8A5A32"], "debris": ["#8A5A32", "#C08A54"],
	"rope": ["#E8DCC4"], "sign_dust": ["#E6BC84", "#8A5A32"], "ping": ["#FFFFFF", "#FFE9B0", "#9AA3B5"],
	"armour": ["#9AA3B5", "#5A5F6A", "#FFFFFF"], "dynamite_blast": ["#FFD45E", "#FF8A1F", "#E2463B"]}


func _fx() -> void:
	for kind in PARTICLES:
		var cols: Array = PARTICLES[kind]
		for i in cols.size():
			var p := img(2, 2)
			rect(p, 0, 0, 2, 2, cols[i])
			save(p, "fx/%s_%d.png" % [kind, i])
	var hat := img(8, 3)
	rect(hat, 0, 0, 8, 3, "#4A3426")
	save(hat, "fx/hat.png")
	var brass := img(1, 2)
	rect(brass, 0, 0, 1, 2, "#E8B84A")
	save(brass, "fx/brass.png")
	var mark := img(2, 2)
	rect(mark, 0, 0, 2, 2, "#1E140C")
	save(mark, "fx/bullet_hole.png")
	save(mark, "fx/miss_mark.png")
	for t in 30:
		var e := img(108, 108)
		var col := Color(1, 233 / 255.0, 176 / 255.0, 0.85) if t < 8 else Color(1, 138 / 255.0, 31 / 255.0, maxf(0, 0.6 - t / 50.0))
		disc(e, 54, 54, 6 + t * 1.6, col)
		save(e, "fx/explosion_%02d.png" % t)
	var flash := img(9, 11)
	rect(flash, 0, 3, 9, 5, "#FFE9B0")
	rect(flash, 3, 0, 3, 11, "#FFE9B0")
	rect(flash, 3, 4, 4, 3, "#FFFFFF")
	save(flash, "fx/muzzle_flash.png")
	for kind in {"hit": "#FFE9B0", "miss": "#FF8A6A", "hover": Color(1, 1, 1, 0.9)}.keys():
		var col: Variant = {"hit": "#FFE9B0", "miss": "#FF8A6A", "hover": Color(1, 1, 1, 0.9)}[kind]
		var c := img(13, 13)
		rect(c, 0, 6, 4, 1, col)
		rect(c, 9, 6, 4, 1, col)
		rect(c, 6, 0, 1, 4, col)
		rect(c, 6, 9, 1, 4, col)
		save(c, "fx/crosshair_%s.png" % kind)
	for kind in {"normal": "#FFE9B0", "urgent": "#FF3B2F"}.keys():
		var ring := img(24, 24)
		var col := Color({"normal": "#FFE9B0", "urgent": "#FF3B2F"}[kind])
		for y in 24:
			for x in 24:
				if absf(Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 12)) - 11) < 0.6:
					ring.set_pixel(x, y, col)
		save(ring, "fx/draw_ring_%s.png" % kind)
	var alert := img(3, 5)
	text(alert, "!", 0, 0, "#FF3B2F")
	save(alert, "fx/alert.png")
	var arrow := img(5, 3)
	rect(arrow, 0, 0, 5, 1, "#FFE9B0")
	rect(arrow, 1, 1, 3, 1, "#FFE9B0")
	rect(arrow, 2, 2, 1, 1, "#FFE9B0")
	save(arrow, "fx/tutorial_arrow.png")
	var hurt := img(4, 4)
	rect(hurt, 0, 0, 4, 4, Color(200 / 255.0, 30 / 255.0, 20 / 255.0))
	save(hurt, "fx/hurt_flash.png")
	# Iron Eli's thrown dynamite (drawThrows), drawn at pixel size: the stick is 8×3 units with a 2-unit fuse.
	var stick := img(20, 6)
	rect(stick, 0, 0, 16, 6, "#7A1E1E")
	rect(stick, 0, 0, 16, 3, "#B8323E")
	rect(stick, 16, 2, 4, 2, "#E8DCC4")
	save(stick, "fx/dynamite.png", 1)
	var spark := img(2, 2)
	rect(spark, 0, 0, 2, 2, "#FFE9B0")
	save(spark, "fx/fuse_spark.png")
	# The clue glow around a puzzle's key prop: a nine-patch frame, stretched to fit.
	var glow := img(6, 6)
	rect(glow, 0, 0, 6, 6, "#FFD45E")
	rect(glow, 2, 2, 2, 2, Color(0, 0, 0, 0))
	glow.fill_rect(Rect2i(2, 2, 2, 2), Color(0, 0, 0, 0))
	save(glow, "fx/hint_glow.png", 1)
	var puff := img(26, 26)
	disc(puff, 13, 13, 12, Color(225 / 255.0, 225 / 255.0, 230 / 255.0, 0.55))
	save(puff, "fx/smoke_puff.png")


# ---------- duel props (drawDuel) ----------

func _duel() -> void:
	var box := img(14, 18)
	rect(box, 0, 0, 14, 18, "#3A2414")
	rect(box, 1, 1, 12, 16, "#8A5A32")
	rect(box, 1, 4, 12, 2, "#6E4526")
	save(box, "duel/card_box.png")
	for card in ["A", "K", "Q", "J", "9", "7", "5", "3"]:
		var c := img(12, 16)
		rect(c, 0, 0, 12, 16, "#1E1A16")
		rect(c, 1, 1, 10, 14, "#FBF6EA")
		text(c, card, 5, 5, "#B8323E" if card == "A" else "#1E1A16")
		save(c, "duel/card_%s.png" % card)
	var shadow := img(28, 3)
	rect(shadow, 0, 0, 28, 3, Color(0, 0, 0, 0.2))
	save(shadow, "duel/shadow.png")
	var pip := img(8, 3)
	rect(pip, 0, 0, 8, 3, "#B8323E")
	save(pip, "duel/pip_full.png")
	pip = img(8, 3)
	rect(pip, 0, 0, 8, 3, Color(1, 1, 1, 0.35))
	save(pip, "duel/pip_empty.png")
	var twitch := img(3, 3)
	rect(twitch, 0, 0, 3, 3, "#FFE9B0")
	save(twitch, "duel/twitch.png")


# ---------- UI (drawn at UI pixel size, not ×2) ----------

const HEART := [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
const ICONS := {
	"pause": ["............", "..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..",
		"..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..", "..xxx..xxx..", "............"],
	"restart": ["....xxxx.x..", "...xx..xxx..", "..xx...xxx..", ".xx...xxxx..", ".x..........", ".x..........", ".x.........x",
		".xx.......xx", "..xx.....xx.", "...xx...xx..", "....xxxxx...", "............"],
	"sound_on": ["............", ".....x......", "....xx...x..", "...xxx....x.", "xxxxxx.x..x.", "xxxxxx..x.x.", "xxxxxx..x.x.",
		"xxxxxx.x..x.", "...xxx....x.", "....xx...x..", ".....x......", "............"],
	"sound_off": ["............", ".....x......", "....xx......", "...xxx......", "xxxxxx.x...x", "xxxxxx..x.x.", "xxxxxx...x..",
		"xxxxxx..x.x.", "...xxx.x...x", "....xx......", ".....x......", "............"],
}
const STAR := [Vector2(5, 0.6), Vector2(6.3, 3.5), Vector2(9.4, 3.8), Vector2(7.0, 5.9), Vector2(7.7, 9.0),
	Vector2(5, 7.4), Vector2(2.3, 9.0), Vector2(3.0, 5.9), Vector2(0.6, 3.8), Vector2(3.7, 3.5)]


func _ui() -> void:
	save(rows(HEART, {"x": "#FF5A5F"}), "ui/heart_full.png", 3)
	var empty := rows(HEART, {"x": "#FFFFFF"})
	_fade(empty, 0.35)
	save(empty, "ui/heart_empty.png", 3)
	for full in [true, false]:
		var b := img(6, 16)
		rect(b, 1, 0, 4, 4, "#C9C9C9" if full else Color(1, 1, 1, 0.2))
		rect(b, 0, 4, 6, 12, "#E8B84A" if full else Color(1, 1, 1, 0.3))
		save(b, "ui/bullet_%s.png" % ("full" if full else "empty"), 1)
	for name in ICONS:
		save(rows(ICONS[name], {"x": "#FFFFFF"}), "ui/icon_%s.png" % name)
	for on in [true, false]:
		var s := img(40, 40)
		var poly := PackedVector2Array()
		for v in STAR:
			poly.append(v * 4)
		for y in 40:
			for x in 40:
				var p := Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(p, poly):
					var edge := 99.0
					for i in poly.size():
						edge = minf(edge, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
					s.set_pixel(x, y, Color("#A8452A") if on and edge < 1.5 else (Color("#F2B544") if on else Color(1, 1, 1, 0.25)))
		save(s, "ui/star_%s.png" % ("on" if on else "off"), 1)
	# Nine-patch boxes for the theme.
	save(_rounded(24, 28, 9, Color("#F2B544"), Color("#A8452A"), 4), "ui/button.png", 1)
	save(_rounded(24, 28, 9, Color("#F2B544"), Color("#A8452A"), 1), "ui/button_pressed.png", 1)
	save(_rounded(24, 24, 9, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0, Color(1, 1, 1, 0.5)), "ui/button_ghost.png", 1)
	save(_rounded(24, 24, 9, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0), 0, Color(1, 1, 1, 0.5)), "ui/button_ghost_pressed.png", 1)
	save(_rounded(28, 28, 13, Color("#F6E7CC"), Color("#A8452A"), 3), "ui/pill.png", 1)
	save(_rounded(20, 20, 7, Color(42 / 255.0, 26 / 255.0, 16 / 255.0, 0.4), Color(), 0), "ui/icon_button.png", 1)
	save(_rounded(20, 20, 7, Color(42 / 255.0, 26 / 255.0, 16 / 255.0, 0.65), Color(), 0), "ui/icon_button_pressed.png", 1)
	var shade := img(4, 4)
	rect(shade, 0, 0, 4, 4, Color(42 / 255.0, 22 / 255.0, 10 / 255.0, 0.62))
	save(shade, "ui/shade.png", 1)
	save(_rounded(12, 10, 4, Color(1, 1, 1, 0.2), Color(), 0), "ui/bar_back.png", 1)
	save(_rounded(12, 10, 4, Color("#F2B544"), Color(), 0), "ui/bar_fill.png", 1)


func _fade(im: Image, a: float) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0:
				im.set_pixel(x, y, Color(c, a))


## A rounded box: body colour, a solid bottom edge `lip` pixels tall, and an optional 2 px border.
func _rounded(w: int, h: int, r: float, body: Color, lip_col: Color, lip: int, border := Color(0, 0, 0, 0)) -> Image:
	var im := img(w, h)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(p.x, r, w - r), clampf(p.y, r, h - r))
			var d := p.distance_to(q)
			if d > r:
				continue
			var col := lip_col if y >= h - lip else body
			if border.a > 0 and (d > r - 2 or x < 2 or x >= w - 2 or y < 2 or y >= h - 2):
				col = border
			im.set_pixel(x, y, col)
	return im


# ================= home flow (drawStandoff, buildOffice, drawOffice, posterCanvas) =================

func poly(im: Image, pts: Array, col: Color) -> void:
	var p := PackedVector2Array(pts)
	var box := Rect2(p[0], Vector2.ZERO)
	for v in p:
		box = box.expand(v)
	for y in range(maxi(0, floori(box.position.y)), mini(im.get_height(), ceili(box.end.y))):
		for x in range(maxi(0, floori(box.position.x)), mini(im.get_width(), ceili(box.end.x))):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), p):
				im.set_pixel(x, y, im.get_pixel(x, y).blend(col))


## A soft radial light, like the prototype's createRadialGradient fills.
func radial(im: Image, cx: float, cy: float, r0: float, r1: float, col: Color) -> void:
	for y in range(maxi(0, floori(cy - r1)), mini(im.get_height(), ceili(cy + r1))):
		for x in range(maxi(0, floori(cx - r1)), mini(im.get_width(), ceili(cx + r1))):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d < r1:
				var k := clampf((d - r0) / (r1 - r0), 0, 1)
				im.set_pixel(x, y, im.get_pixel(x, y).blend(Color(col, col.a * (1 - k))))


func vgrad(im: Image, x: int, y: int, w: int, h: int, top: String, bottom: String, y0: float, y1: float) -> void:
	for yy in range(y, y + h):
		rect(im, x, yy, w, 1, Color(top).lerp(Color(bottom), clampf((yy + 0.5 - y0) / (y1 - y0), 0, 1)))


func silhouette_of(im: Image, col: String) -> Image:
	var out := im.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			if out.get_pixel(x, y).a > 0:
				out.set_pixel(x, y, Color(col))
	return out


func scaled(im: Image, k: int) -> Image:
	var out := im.duplicate()
	out.resize(im.get_width() * k, im.get_height() * k, Image.INTERPOLATE_NEAREST)
	return out


## The default bounty hunter (avatarSprite with the prototype's default avatar).
func avatar_image() -> Image:
	var pal := {"k": "#1E1A16", "h": "#4A3426", "b": "#2B1E14", "s": "#A0663F", "e": "#1E1A16", "d": "#B8323E", "c": "#5B4636", "v": "#7A5A3A", "p": "#3A3F5A"}
	return rows(["...hhhhhhhh...", "...hhhhhhhh...", ".hhhbbbbbbhhh.", "hhhhhhhhhhhhhh", "....ssssss....", "....sesses....",
		"....dddddd....", "...dddddddd...", "..cccvvvvccc..", ".ccccvvvvcccc.", ".cc.cvvvvc.cc.", ".cc.cvvvvc.cc.", ".ss.cvvvvc.ss.",
		"....cccccc....", "....pppppp....", "....pp..pp....", "....pp..pp....", "....pp..pp....", "...kkk..kkk..."], pal)


func _splash() -> void:
	var ox := -BG_LEFT
	var sky := img(BG_W, H)
	vgrad(sky, 0, 0, BG_W, 112, "#F6EBC8", "#EBC489", 0, 112)
	disc(sky, 250 + ox, 18, 6, "#FFF8E0")
	save(sky, "splash/sky.png")
	var far := img(BG_W, H)
	for m in [[-80, 88, 80], [0, 86, 70], [54, 92, 50], [220, 84, 100], [330, 90, 70]]:
		rect(far, m[0] + ox, m[1], m[2], 26, "#DDB07E")
		rect(far, m[0] + 6 + ox, m[1] - 4, m[2] - 12, 4, "#DDB07E")
	for m in [[-60, 80, 26, 32], [6, 76, 30, 36], [40, 84, 22, 28], [252, 78, 34, 34], [288, 86, 30, 26], [340, 80, 30, 32]]:
		rect(far, m[0] + ox, m[1], m[2], m[3], "#B98457")
		rect(far, m[0] + 3 + ox, m[1] - 4, m[2] - 6, 4, "#B98457")
	save(far, "splash/far.png")
	# The clock tower and its face; the minute hand and the bell move, so they are separate.
	var tower := img(28, 92)  # world x 146..174, y 20..112
	rect(tower, 2, 16, 24, 76, "#8E5E3A")
	rect(tower, 0, 14, 28, 4, "#6E4526")
	for i in 14:
		rect(tower, 14 - i, i, i * 2, 1, "#5A3A24")
	disc(tower, 14, 34, 10, "#2E1C10")
	disc(tower, 14, 34, 8, "#F6EBC8")
	for k in 12:
		var a := k / 12.0 * TAU
		rect(tower, roundf(14 + cos(a) * 7), roundf(34 + sin(a) * 7), 1, 1, "#2E1C10")
	for r in 5:
		rect(tower, 14, 34 - r, 1, 1, "#1E120A")
	save(tower, "splash/tower.png")
	var hand := img(8, 1)
	rect(hand, 0, 0, 8, 1, "#1E120A")
	save(hand, "splash/minute_hand.png")
	var bell := img(6, 5)
	rect(bell, 0, 0, 6, 5, "#C9A25A")
	save(bell, "splash/bell.png")
	var street := img(BG_W, H)
	rect(street, 0, 112, BG_W, H - 112, "#D9A86C")
	for i in 9:
		rect(street, 0, roundf(118 + i * i * 0.8), BG_W, 1, "#C9965A")
	save(street, "splash/street.png")
	for f in 12:  # heat haze, one cycle
		var haze := img(BG_W, 12)
		var t := f / 12.0 * TAU / 4.0
		for i in 6:
			for x in range(0, BG_W, 2):
				if sin((x - ox) * 0.12 + t * 4 + i) > 0.6:
					rect(haze, x, i * 2, 2, 1, Color(1, 248 / 255.0, 224 / 255.0, 0.35))
		save(haze, "splash/haze_%02d.png" % f)
	# The two figures, as dark silhouettes three times the street size (drawn 42×57).
	save(scaled(silhouette_of(avatar_image(), "#1E120A"), 3), "splash/hero.png")
	var rival := silhouette_of(kit_image("art/sprites/iron_eli_idle.png"), "#1E120A")
	rival.flip_x()
	save(scaled(rival, 3), "splash/rival.png")
	var shadow := img(34, 3)
	rect(shadow, 0, 0, 34, 3, Color(30 / 255.0, 18 / 255.0, 10 / 255.0, 0.25))
	save(shadow, "splash/shadow.png")
	var flash := img(12, 14)
	rect(flash, 0, 4, 12, 6, "#FFE9B0")
	rect(flash, 4, 0, 4, 14, "#FFE9B0")
	save(flash, "splash/muzzle_flash.png")
	for kind in {"white": Color.WHITE, "black": Color.BLACK}:
		var s := img(4, 4)
		rect(s, 0, 0, 4, 4, {"white": Color.WHITE, "black": Color.BLACK}[kind])
		save(s, "fx/screen_%s.png" % kind, 1)


func _office() -> void:
	var ox := -BG_LEFT
	var o := img(BG_W, H)
	var R := func(col: Variant, a: float, b: float, w: float, h: float): rect(o, a + ox, b, w, h, col)
	# Walls, wainscot and floor, wider than the prototype's room so wide phones see more of it.
	rect(o, 0, 0, BG_W, 140, "#5A3A22")
	for i in range(0, BG_W, 12):
		rect(o, i, 0, 1, 140, "#4A2E1A")
	for i in 180:
		var hh := hash32(i * 11 + 5)
		rect(o, hh % BG_W, (hh >> 8) % 104, 2, 1, "#4E321C" if hh % 2 else "#64432A")
	rect(o, 0, 104, BG_W, 36, "#3E2716")
	rect(o, 0, 104, BG_W, 2, "#2E1C10")
	for i in range(6 - 78, 250 + 160, 26):
		if i < 96 or i > 230:  # the desk hides the middle panels
			R.call("#35210F", i, 110, 20, 24)
	rect(o, 0, 140, BG_W, 40, "#3A2414")
	for y in range(146, 180, 8):
		rect(o, 0, y, BG_W, 1, "#2E1C10")
	# Window onto Main Street (the duel teaser).
	R.call("#2E1C10", 8, 22, 64, 72)
	for y in range(26, 72):
		R.call(Color("#F6E3B4").lerp(Color("#E8A86A"), clampf((y - 26) / 44.0, 0, 1)), 12, y, 56, 1)
	R.call("#DDB07E", 12, 60, 18, 10)
	R.call("#C99868", 50, 58, 18, 12)
	R.call("#9C6A43", 38, 42, 6, 28)
	R.call("#6E4526", 37, 40, 8, 2)
	R.call("#C9A25A", 40, 44, 2, 2)
	R.call("#F6EBC8", 39, 50, 4, 4)
	R.call("#2E1C10", 41, 50, 1, 2)
	R.call("#D9A86C", 12, 70, 56, 20)
	R.call("#C9965A", 12, 78, 56, 1)
	R.call("#C9965A", 12, 84, 56, 1)
	for f in [[22, false], [58, true]]:
		var fx: int = f[0]
		for r in [[fx - 2, 64, 6, 1], [fx - 1, 62, 4, 2], [fx, 65, 2, 2], [fx - 1, 67, 4, 6], [fx - 1, 73, 1, 4], [fx + 2, 73, 1, 4], [fx + (-2 if f[1] else 3), 68, 1, 3]]:
			R.call("#1E120A", r[0], r[1], r[2], r[3])
	R.call("#6E4526", 6, 92, 68, 4)
	# Calendar (Daily Bounty) and the shooting target (Survival).
	R.call("#2E1C10", 77, 19, 24, 31)
	R.call("#F6E7CC", 78, 20, 22, 29)
	R.call("#B8323E", 78, 20, 22, 6)
	R.call("#5A3A24", 88, 18, 2, 3)
	for r in 4:
		for k in 5:
			R.call("#B8323E" if r == 2 and k == 3 else "#8A6A4A", 80 + k * 4, 29 + r * 4, 2, 2)
	for rr in [11, 8, 5, 2]:
		disc(o, 89 + ox, 79, rr, "#E8DCC4" if (rr / 3) % 2 else "#B8323E")
	R.call("#1E120A", 86, 76, 2, 2)
	R.call("#1E120A", 92, 81, 2, 2)
	R.call("#5A3A24", 88, 66, 2, 2)
	# The bounty board (posters are separate sprites).
	R.call(Color(0, 0, 0, 0.25), 108, 16, 108, 88)
	R.call("#2E1C10", 106, 12, 108, 88)
	R.call("#B88A5A", 109, 15, 102, 82)
	for i in 200:
		var hh := hash32(i * 7 + 3)
		R.call("#A0754A" if hh % 3 else "#C9A070", 109 + hh % 102, 15 + (hh >> 8) % 82, 1, 1)
	R.call("#EFE2C2", 140, 80, 40, 14)
	R.call("#B8A07A", 143, 84, 30, 1)
	R.call("#B8A07A", 143, 88, 24, 1)
	R.call("#8E2A1E", 159, 79, 2, 2)
	# The portrait frame (the bounty hunter is a separate sprite).
	R.call("#3A2414", 221, 17, 32, 60)
	R.call("#C9A25A", 222, 18, 30, 58)
	R.call("#8A6A2E", 224, 20, 26, 54)
	for y in range(21, 73):
		R.call(Color("#4A5A60").lerp(Color("#26302F"), (y - 21) / 52.0), 225, y, 24, 1)
	for c in [[222, 18], [248, 18], [222, 72], [248, 72]]:
		R.call("#F2D27A", c[0], c[1], 4, 4)
		R.call("#8A6A2E", c[0] + 1, c[1] + 1, 2, 2)
	# The gunsmith's doorway, sign and rack (guns on the rack are separate sprites).
	R.call(Color(0, 0, 0, 0.25), 258, 18, 60, 124)
	R.call("#2E1C10", 256, 16, 60, 126)
	R.call("#6E4526", 258, 18, 56, 4)
	R.call("#6E4526", 258, 18, 4, 122)
	R.call("#6E4526", 310, 18, 4, 122)
	for y in range(22, 140):
		R.call(Color("#3A2414").lerp(Color("#5A3A22"), (y - 22) / 118.0), 262, y, 48, 1)
	R.call("#4A2C16", 268, 34, 38, 64)
	R.call("#6E4526", 270, 36, 34, 60)
	R.call("#4A2C16", 270, 56, 34, 2)
	R.call("#4A2C16", 270, 80, 34, 2)
	R.call("#7A5232", 262, 122, 48, 18)
	for y in range(126, 140, 4):
		R.call("#6A4428", 262, y, 48, 1)
	poly(o, [Vector2(262 + ox, 140), Vector2(310 + ox, 140), Vector2(300 + ox, 180), Vector2(232 + ox, 180)], Color(1, 196 / 255.0, 110 / 255.0, 0.16))
	R.call("#4A2C16", 260, 4, 2, 14)
	R.call("#4A2C16", 310, 4, 2, 14)
	R.call("#2E1C10", 262, 5, 48, 12)
	R.call("#8A5A32", 263, 6, 46, 10)
	R.call("#6E4526", 263, 11, 46, 1)
	text(o, "GUNSMITH", 270 + ox, 8, "#F6E7CC")
	for r in [["#3A3F4A", 264, 8, 5, 2], ["#3A3F4A", 267, 10, 2, 4], ["#6E4526", 268, 11, 2, 4], ["#3A3F4A", 303, 8, 5, 2], ["#3A3F4A", 303, 10, 2, 4], ["#6E4526", 302, 11, 2, 4]]:
		R.call(r[0], r[1], r[2], r[3], r[4])
	R.call("#5A3A22", 280, 100, 28, 4)
	R.call("#3A2414", 282, 104, 2, 18)
	R.call("#3A2414", 304, 104, 2, 18)
	# The trophy cabinet (trophies are separate sprites, one per bounty).
	R.call("#2E1C10", 14, 108, 70, 36)
	R.call("#6E4526", 16, 110, 66, 32)
	R.call("#3A2414", 18, 112, 62, 13)
	R.call("#3A2414", 18, 128, 62, 12)
	R.call("#8A5A32", 18, 125, 62, 2)
	R.call("#2E1C10", 16, 144, 4, 6)
	R.call("#2E1C10", 78, 144, 4, 6)
	# The sheriff's desk and what's on it.
	R.call(Color(0, 0, 0, 0.28), 96, 146, 134, 4)
	R.call("#2E1C10", 94, 104, 134, 6)
	R.call("#7A4E2A", 96, 105, 130, 4)
	R.call("#4A2C16", 98, 110, 126, 36)
	R.call("#3A2414", 102, 114, 54, 28)
	R.call("#3A2414", 166, 114, 54, 28)
	R.call("#C9A25A", 127, 126, 6, 2)
	R.call("#C9A25A", 191, 126, 6, 2)
	for r in [["#C9A25A", 107, 93, 2, 11], ["#2E6A4A", 101, 86, 14, 7], ["#1E4A32", 101, 92, 14, 1], ["#8A6A2E", 104, 103, 8, 2],
			["#E8E2D2", 119, 97, 7, 8], ["#5A3A24", 120, 98, 5, 1], ["#E8E2D2", 126, 99, 2, 3], ["#EFE2C2", 132, 101, 18, 4],
			["#E3D2AA", 133, 99, 16, 2], ["#D2BC92", 134, 97, 14, 2], ["#EDDDB4", 154, 96, 18, 9], ["#8E2A1E", 156, 97, 14, 1],
			["#2E1C10", 160, 99, 6, 4], ["#1E1A16", 176, 101, 18, 3], ["#5A5F6A", 177, 101, 16, 1], ["#4A4F5A", 188, 99, 6, 5],
			["#6E4526", 193, 101, 5, 5], ["#EFE2C2", 212, 98, 12, 6], ["#8E2A1E", 217, 98, 1, 6]]:
		R.call(r[0], r[1], r[2], r[3], r[4])
	for pt in [[4, 0], [3, 1], [4, 1], [5, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [1, 3], [2, 3], [3, 3],
			[4, 3], [5, 3], [6, 3], [7, 3], [2, 4], [3, 4], [4, 4], [5, 4], [6, 4], [1, 5], [2, 5], [6, 5], [7, 5]]:
		R.call("#E2B23C", 202 + pt[0], 98 + pt[1], 1, 1)
	R.call("#FFF3C4", 206, 100, 1, 1)
	save(o, "office/room.png")

	# Drawn over the window's street life: the mullions and the DUEL SOON notice.
	var wf := img(56, 64)  # world x 12..68, y 26..90
	rect(wf, 27, 0, 2, 64, "#2E1C10")
	rect(wf, 0, 22, 56, 2, "#2E1C10")
	rect(wf, 4, 3, 22, 15, "#EFE2C2")
	rect(wf, 4, 17, 22, 1, "#E3D2AA")
	text(wf, "DUEL", 7, 5, "#8E2A1E")
	text(wf, "SOON", 7, 11, "#2E1C10")
	save(wf, "office/window_front.png")
	# Warm light: sun rays from the window, the desk lamp, the doorway glow.
	var light := img(BG_W, H)
	poly(light, [Vector2(12 + ox, 28), Vector2(40 + ox, 28), Vector2(140 + ox, 180), Vector2(60 + ox, 180)], Color(1, 228 / 255.0, 165 / 255.0, 0.07))
	poly(light, [Vector2(42 + ox, 28), Vector2(68 + ox, 28), Vector2(190 + ox, 180), Vector2(148 + ox, 180)], Color(1, 228 / 255.0, 165 / 255.0, 0.056))
	radial(light, 108 + ox, 96, 2, 56, Color(1, 214 / 255.0, 140 / 255.0, 0.15))
	radial(light, 286 + ox, 70, 4, 44, Color(1, 200 / 255.0, 120 / 255.0, 0.12))
	radial(light, 286 + ox, 120, 4, 60, Color(1, 200 / 255.0, 120 / 255.0, 0.10))
	save(light, "office/light.png")
	# Street life through the window: a dog, a walker, a horse (two frames each).
	for f in 2:
		var dog := img(6, 4)
		rect(dog, 1, 0, 4, 1, "#8A6A44")
		rect(dog, 0, 1, 6, 2, "#8A6A44")
		rect(dog, 1, 3, 4, 1, "#8A6A44")
		save(dog, "office/dog_%d.png" % f)
		var walker := img(4, 11)
		var bob := f
		rect(walker, 0, 1 + bob, 4, 1, "#2E1C10")
		rect(walker, 1, bob, 2, 1, "#2E1C10")
		rect(walker, 1, 2 + bob, 2, 5, "#2E1C10")
		rect(walker, 1 + f, 7, 1, 3, "#2E1C10")
		save(walker, "office/walker_%d.png" % f)
		var horse := img(11, 11)
		rect(horse, 2, 5, 9, 3, "#2E1C10")
		rect(horse, 0, 3, 3, 3, "#2E1C10")
		rect(horse, 5, 0, 3, 5, "#2E1C10")
		rect(horse, 2 + f, 8, 1, 3, "#2E1C10")
		rect(horse, 9 - f, 8, 1, 3, "#2E1C10")
		save(horse, "office/horse_%d.png" % f)
	var mote := img(1, 1)
	rect(mote, 0, 0, 1, 1, Color(1, 240 / 255.0, 200 / 255.0, 0.55))
	save(mote, "office/mote.png")
	var flap := img(4, 4)
	rect(flap, 0, 0, 4, 4, "#E3D2AA")
	save(flap, "office/paper_flap.png")
	# The gunsmith at work: hammer raised, then the strike with sparks.
	for hit in [false, true]:
		var s := img(14, 14)  # world x 288..302, y 86..100
		rect(s, 0, 2, 7, 2, "#2E1C10")
		rect(s, 1, 0, 5, 2, "#2E1C10")
		rect(s, 2, 4, 3, 3, "#A0663F")
		rect(s, 1, 7, 6, 7, "#5B4636")
		rect(s, 2, 8, 4, 6, "#8A6A4A")
		rect(s, 6, 10 if hit else 6, 2, 4 if hit else 5, "#5B4636")
		rect(s, 7, 12 if hit else 4, 3, 2, "#3A3F4A")
		if hit:
			for sp in [[10, 12], [12, 10], [9, 9]]:
				rect(s, sp[0], sp[1], 1, 1, "#FFD45E")
		save(s, "office/smith_%s.png" % ("hit" if hit else "up"))
	var door := img(16, 118)
	rect(door, 0, 0, 16, 118, "#4A2C16")
	rect(door, 1, 2, 14, 114, "#5A3A22")
	rect(door, 13, 60, 2, 3, "#C9A25A")
	save(door, "office/door.png")
	var dglow := img(48, 118)
	rect(dglow, 0, 0, 48, 118, Color(1, 214 / 255.0, 140 / 255.0, 0.25))
	save(dglow, "office/door_glow.png")
	var glint := img(6, 6)
	rect(glint, 0, 0, 6, 6, "#FFD45E")
	glint.fill_rect(Rect2i(2, 2, 2, 2), Color(0, 0, 0, 0))
	save(glint, "office/glint.png", 1)
	# The gun rack: each gun on its peg, owned or still an empty outline, and the equipped marker.
	for w in _json("data/weapons.json"):
		for own in [true, false]:
			var g := img(4, 51)
			rect(g, 1, 0, 2, 40, "#5A5F6A" if own else Color(0, 0, 0, 0.28))
			rect(g, 0, 35, 4, 16, "#8A5A32" if own else Color(0, 0, 0, 0.2))
			save(g, "office/rack_%s%s.png" % [w.id, "" if own else "_empty"])
	var mark := img(2, 2)
	rect(mark, 0, 0, 2, 2, "#F2B544")
	save(mark, "office/rack_equipped.png")
	# Trophies in the cabinet, one per captured bounty (TROPHY_OFFICE).
	var tro := [
		[["#8A6A2E", 2, 2, 6, 9], ["#F2C14E", 3, 3, 4, 7], ["#C9C9C9", 3, 0, 4, 3], ["#FFF3C4", 4, 4, 1, 4]],
		[["#8A6A2E", 1, 6, 9, 3], ["#E2B23C", 2, 2, 3, 7], ["#E2B23C", 6, 4, 3, 5], ["#FFF3C4", 2, 2, 1, 6], ["#5A3A24", 3, 0, 1, 2]],
		[["#B8862A", 2, 5, 6, 5], ["#F2C14E", 3, 4, 4, 4], ["#FFF3C4", 4, 5, 1, 1]],
		[["#2E1C10", 3, 0, 4, 2], ["#2E1C10", 2, 2, 6, 8], ["#8FD0C8", 3, 3, 4, 6], ["#E8FFF8", 4, 5, 2, 2]],
		[]]
	for k in 5:
		var t := img(11, 11)
		for r in tro[k]:
			rect(t, r[1], r[2], r[3], r[4], r[0])
		if k == 4:
			for pt in [[4, 0], [3, 1], [5, 1], [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [2, 4], [3, 4], [4, 4],
					[5, 4], [6, 4], [3, 5], [4, 5], [5, 5], [2, 6], [3, 6], [5, 6], [6, 6], [1, 7], [7, 7]]:
				rect(t, 1 + pt[0], 2 + pt[1], 1, 1, "#F2C14E")
		save(t, "office/trophy_%d.png" % k)
	var empty_t := img(11, 11)
	rect(empty_t, 2, 3, 7, 8, Color(1, 1, 1, 0.07))
	save(empty_t, "office/trophy_empty.png")
	var glass := img(62, 28)
	rect(glass, 0, 0, 62, 28, Color(200 / 255.0, 230 / 255.0, 240 / 255.0, 0.12))
	rect(glass, 2, 1, 1, 10, Color(1, 1, 1, 0.18))
	save(glass, "office/cabinet_glass.png")
	# The bounty hunter's portrait (the default avatar, at the portrait's size).
	save(scaled(avatar_image(), 2), "office/portrait.png")


## One wanted poster (posterCanvas), in each state: open, locked (has levels, not reached), soon (no levels yet).
func _poster(c: int, ch: Dictionary, state: String, w: int, h: int, big: bool) -> Image:
	var has_lv := state != "soon"
	var open := state == "open"
	var x := img(w, h)
	rect(x, 0, 0, w, h, ("#EDDDB4" if open else "#B8A47E") if has_lv else "#D2BC92")
	for i in w * h / 9:
		var hh := hash32(i * 13 + c * 97)
		rect(x, hh % w, (hh >> 8) % h, 1, 1, Color(120 / 255.0, 80 / 255.0, 40 / 255.0, 0.10) if hh % 3 else Color(1, 1, 1, 0.18))
	var edge := Color(90 / 255.0, 58 / 255.0, 36 / 255.0, 0.35)
	rect(x, 0, 0, w, 1, edge)
	rect(x, 0, h - 1, w, 1, edge)
	rect(x, 0, 0, 1, h, edge)
	rect(x, w - 1, 0, 1, h, edge)
	if big:
		text(x, "WANTED", floori((w - 23) / 2.0), 3, "#8E2A1E")
	else:
		rect(x, 3, 2, w - 6, 2, "#8E2A1E")
	var s2 := maxi(1, floori((w - 8) / 14.0))
	var pw := 14 * s2
	var ph := 13 * s2
	var px := floori((w - pw) / 2.0)
	var py := 10 if big else 6
	rect(x, px, py, pw, ph, "#D9C08C" if has_lv else "#B79E74")
	var face := kit_image("art/sprites/%s_idle.png" % ("iron_eli" if c == 0 else "outlaw")).get_region(Rect2i(0, 0, 14, 13))
	if not open:
		face = silhouette_of(face, "#2E1C10" if has_lv else "#5A4632")
	face.resize(pw, ph, Image.INTERPOLATE_NEAREST)
	x.blend_rect(face, Rect2i(0, 0, pw, ph), Vector2i(px, py))
	var frame := Color(46 / 255.0, 28 / 255.0, 16 / 255.0, 0.55)
	rect(x, px - 1, py - 1, pw + 2, 1, frame)
	rect(x, px - 1, py + ph, pw + 2, 1, frame)
	rect(x, 4, py + ph + 3, w - 8, 1, "#6B2A1A")
	rect(x, 6, py + ph + 6, w - 12, 1, "#6B2A1A")
	if big:
		rect(x, 5, py + ph + 9, w - 10, 1, "#6B2A1A")
	if not open:
		rect(x, 0, 0, w, h, Color(30 / 255.0, 18 / 255.0, 10 / 255.0, 0.32))
		var lx := floori(w / 2.0) - 3
		var ly := h - (13 if big else 10)
		rect(x, lx + 1, ly, 4, 1, "#5A4632")
		rect(x, lx, ly + 1, 1, 3, "#5A4632")
		rect(x, lx + 5, ly + 1, 1, 3, "#5A4632")
		rect(x, lx - 1, ly + 3, 8, 6, "#8A6A3A")
		rect(x, lx + 2, ly + 5, 2, 2, "#3A2A1A")
	return x


func _posters() -> void:
	var chapters: Array = _json("data/chapters.json")
	for c in chapters.size():
		for state in ["open", "locked", "soon"]:
			save(_poster(c, chapters[c], state, 38, 52, true), "posters/ch%d_%s_big.png" % [c, state])
			save(_poster(c, chapters[c], state, 22, 30, false), "posters/ch%d_%s_small.png" % [c, state])
		# The portrait used on the Bounty board screen's paper posters.
		var face := kit_image("art/sprites/%s_idle.png" % ("iron_eli" if c == 0 else "outlaw")).get_region(Rect2i(0, 0, 14, 13))
		save(face, "posters/portrait_ch%d.png" % c, 6)
	for big in [true, false]:
		var sw := 36 if big else 24
		var sh := 12 if big else 10
		var t := 1 if big else 2
		var st := img(sw, sh)
		var col := Color(184 / 255.0, 50 / 255.0, 62 / 255.0, 0.92)
		rect(st, 0, 0, sw, t, col)
		rect(st, 0, sh - t, sw, t, col)
		rect(st, 0, 0, t, sh, col)
		rect(st, sw - t, 0, t, sh, col)
		if big:
			text(st, "CAPTURED", 2, 4, "#B8323E")
		else:
			rect(st, 4, 4, 16, 2, col)
		save(st, "posters/stamp_%s.png" % ("big" if big else "small"))
		var shadow := img(38 if big else 22, 52 if big else 30)
		rect(shadow, 0, 0, shadow.get_width(), shadow.get_height(), Color(30 / 255.0, 18 / 255.0, 10 / 255.0, 0.35))
		save(shadow, "posters/shadow_%s.png" % ("big" if big else "small"))
	var pin := img(3, 3)
	rect(pin, 1, 0, 2, 2, "#C9A25A")
	rect(pin, 0, 2, 3, 1, "#2E1C10")
	save(pin, "posters/pin.png")


## Home-screen UI boxes and icons for the theme (drawn at UI pixel size).
func _home_ui() -> void:
	# Brass plaques on the office hotspots; greyed ones for "coming soon".
	for kind in {"plaque": ["#D9B866", "#C29A48", "#5A3A1A"], "plaque_soon": ["#C7B796", "#AE9E7C", "#4A3A26"],
			"plaque_pressed": ["#C29A48", "#B08A3A", "#5A3A1A"]}.keys():
		var c: Array = {"plaque": ["#D9B866", "#C29A48", "#5A3A1A"], "plaque_soon": ["#C7B796", "#AE9E7C", "#4A3A26"],
			"plaque_pressed": ["#C29A48", "#B08A3A", "#5A3A1A"]}[kind]
		var p := img(16, 18)
		for y in 15:
			rect(p, 0, y, 16, 1, Color(c[0]).lerp(Color(c[1]), y / 14.0))
		rect(p, 0, 15, 16, 3, c[2])
		rect(p, 0, 0, 1, 1, Color(0, 0, 0, 0))
		rect(p, 15, 0, 1, 1, Color(0, 0, 0, 0))
		save(p, "ui/%s.png" % kind, 1)
	save(_rounded(24, 24, 11, Color("#2A1A10"), Color(), 0, Color("#F2B544")), "ui/wallet.png", 1)
	save(_rounded(24, 26, 6, Color("#EFE2C2"), Color("#6E4526"), 3), "ui/desk_plaque.png", 1)
	save(_rounded(24, 26, 6, Color("#E3D2AA"), Color("#6E4526"), 3), "ui/desk_plaque_pressed.png", 1)
	save(_rounded(16, 16, 2, Color("#EBD9B0"), Color("#C9B486"), 2), "ui/poster_paper.png", 1)
	save(_rounded(16, 16, 2, Color("#C9B88E"), Color("#A8976E"), 2), "ui/poster_paper_locked.png", 1)
	save(_rounded(16, 16, 1, Color("#EFE2C2"), Color("#D2BC92"), 2), "ui/telegram.png", 1)
	var stamp := img(16, 16)
	for i in 16:
		for j in 2:
			stamp.set_pixel(i, j, Color("#B8323E"))
			stamp.set_pixel(i, 15 - j, Color("#B8323E"))
			stamp.set_pixel(j, i, Color("#B8323E"))
			stamp.set_pixel(15 - j, i, Color("#B8323E"))
	save(stamp, "ui/stamp_box.png", 1)
	save(rows(["..xxxx..", ".x....x.", ".x....x.", "xxxxxxxx", "xxxxxxxx", "xxxx.xxx", "xxxx.xxx", "xxxxxxxx", "xxxxxxxx"], {"x": "#2A1A10"}), "ui/icon_lock.png")
	save(rows(["....xxxxx", "....x...x", "....x...x", "....x...x", "....xxxxx", "..xxx..xx", ".xxxx.xxx", ".xxx..xx.", "..x......"], {"x": "#FFFFFF"}), "ui/icon_music.png")
	var off := rows(["....xxxxx", "....x...x", "....x...x", "....x...x", "....xxxxx", "..xxx..xx", ".xxxx.xxx", ".xxx..xx.", "..x......"], {"x": "#FFFFFF"})
	_fade(off, 0.4)
	save(off, "ui/icon_music_off.png")
