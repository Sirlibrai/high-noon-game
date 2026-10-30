extends SceneTree
## Exports the prototype's code-drawn visuals as placeholder PNGs, so the game
## itself only ever shows image files. Re-run after changing a recipe:
##   Godot --headless --path . -s res://tools/export_placeholders.gd
##
## Recipes are ported from highnoon.html (buildBg, drawCover, drawWindowFrame,
## drawDuel, drawGun, the HUD icons...). Everything is drawn in the prototype's
## 320×180 units and saved at ×2, the 640×360 base resolution's pixel density.
## Kit sprites (art/sprites, art/guns) are copied at the same density.
## Nothing here runs in the game.

const OUT := "res://assets/placeholder/"
const KIT := "res://port_kit/high-noon-port-kit/"
const PX := 2  # pixels per unit
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
	if scale != 1:
		out.resize(im.get_width() * scale, im.get_height() * scale, Image.INTERPOLATE_NEAREST)
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


# ---------- characters (kit sprites at ×2; the hit flash is a white silhouette) ----------

func _characters() -> void:
	for pose in ["idle", "aim", "run"]:
		save(kit_image("art/sprites/outlaw_%s.png" % pose), "outlaw/%s.png" % pose)
	var flash := kit_image("art/sprites/outlaw_aim.png")
	for y in flash.get_height():
		for x in flash.get_width():
			if flash.get_pixel(x, y).a > 0:
				flash.set_pixel(x, y, Color.WHITE)
	save(flash, "outlaw/hit.png")
	for pose in ["idle", "aim", "run"]:
		save(kit_image("art/sprites/iron_eli_%s.png" % pose), "iron_eli/%s.png" % pose)
	# Iron Eli's breastplate, drawn over him while he wears it (drawEnemy). Same frame as the outlaw sprite.
	for cracked in [false, true]:
		var plate := img(14, 19)
		rect(plate, 3, 8, 8, 6, "#3A3F4A")
		rect(plate, 4, 9, 6, 4, "#8A93A2")
		for rv in [[4, 9], [9, 9], [4, 12], [9, 12]]:
			rect(plate, rv[0], rv[1], 1, 1, "#C9D0DA")
		if cracked:
			for cr in [[6, 9, 1, 2], [7, 10, 1, 2], [6, 12, 1, 1], [8, 9, 1, 1]]:
				rect(plate, cr[0], cr[1], cr[2], cr[3], "#1E1A16")
		save(plate, "iron_eli/armour_%s.png" % ("cracked" if cracked else "intact"))
	# Duel bosses stand closer, at twice the street size: the kit's @4x files are exactly that.
	for boss in ["black_jack", "iron_eli"]:
		for pose in ["idle", "aim"]:
			save(kit_image("art/sprites/%s_%s@4x.png" % [boss, pose]), "%s_duel/%s.png" % [boss, pose], 1)
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
