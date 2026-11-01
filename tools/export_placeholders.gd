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
## Kit sprites (art/sprites, art/guns) are copied at the same density. Main Street, its props,
## the outlaw and the Peacemaker now use painted art (tools/import_painted.gd), as do the splash, bottles, hanging
## hardware and most of the UI (tools/import_batch1.gd); their old recipes were removed. The code-drawn hearts,
## bullets, stars, icons, buttons and panels stay as a fallback the manifest can point back to.
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
	_characters()
	_guns()
	_fx()
	_duel()
	_ui()
	_screens()
	_home_ui()
	_painted_ui()
	_painted_cards()
	_office_overlays()
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


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(KIT + path))


# ---------- characters: pose placeholders for the bosses ----------

## Pose placeholders for the characters that have no painted art yet (Iron Eli, Black Jack), with the same
## pose names as the painted outlaw in assets/painted, so they swap straight in when their art arrives.
func _characters() -> void:
	for who in ["iron_eli", "black_jack"]:
		var idle := kit_image("art/sprites/%s_idle.png" % who)
		var aim := kit_image("art/sprites/%s_aim.png" % who)
		var run := kit_image("art/sprites/%s_run.png" % who)
		var poses := {"idle": idle, "aim": aim, "hit": idle, "crouch": aim, "lean": aim, "run_right": run, "fall": idle}
		for pose in poses:
			save(poses[pose], "%s/%s.png" % [who, pose])
		var left: Image = run.duplicate()
		left.flip_x()
		save(left, "%s/run_left.png" % who)
	# Iron Eli's breastplate, drawn over him while he wears it (drawEnemy). Same frame as his pose sprites.
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
	save(kit_image("art/sprites/hostage.png"), "props/hostage.png")


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
	"splinter": ["#C08A54", "#5A3A24"], "smoke": ["#E6E6E6", "#BDBDC4"],
	"blast": ["#FFD45E", "#FF8A1F", "#E2463B", "#3A2414", "#8A5A32"], "debris": ["#8A5A32", "#C08A54"],
	"chain": ["#5A5F6A", "#9AA3B5"], "sign_dust": ["#E6BC84", "#8A5A32"], "ping": ["#FFFFFF", "#FFE9B0", "#9AA3B5"],
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


# ================= home flow (drawStandoff); the office is painted (tools/import_office.gd) =================

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


## The full-screen white flash and black fade (the splash itself is painted art now: tools/import_batch1.gd).
func _screens() -> void:
	for kind in {"white": Color.WHITE, "black": Color.BLACK}:
		var s := img(4, 4)
		rect(s, 0, 0, 4, 4, {"white": Color.WHITE, "black": Color.BLACK}[kind])
		save(s, "fx/screen_%s.png" % kind, 1)


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


# ================= painted-style HUD and gameplay effects (smooth, drawn at final size) =================

func save_exact(im: Image, path: String) -> void:
	var full := ProjectSettings.globalize_path(OUT + path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	im.save_png(full)
	written += 1


## Renders a smooth image: `shade` gives the colour at a point (pixel units), averaged over 4×4 samples.
func smooth(w: int, h: int, shade: Callable) -> Image:
	var im := img(w, h)
	for y in h:
		for x in w:
			var acc := Color(0, 0, 0, 0)
			for sy in 4:
				for sx in 4:
					var c: Color = shade.call(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)
					acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			acc /= 16.0
			im.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a) if acc.a > 0.001 else Color(0, 0, 0, 0))
	return im


func noise2(x: float, y: float) -> float:
	return float(hash32(int(x) * 73856093 ^ int(y) * 19349663) % 1000) / 1000.0


func _painted_ui() -> void:
	# A heart: (x² + y² - 1)³ - x² y³ <= 0, shaded from a warm top-left light, with a dark rim and a gloss.
	for full in [true, false]:
		save_exact(smooth(52, 48, func(px: float, py: float) -> Color:
			var x := (px - 26.0) / 18.0
			var y := -(py - 27.0) / 18.0
			var f := pow(x * x + y * y - 1, 3) - x * x * y * y * y
			if f > 0:
				return Color(0, 0, 0, 0)
			var rim := f > -0.035
			if not full:
				return Color("#2A1A10") if rim else Color(0.32, 0.2, 0.14, 0.55)
			if rim:
				return Color("#4A0E10")
			var light := clampf(0.55 - 0.45 * x + 0.35 * y, 0, 1)
			var c := Color("#8E1A22").lerp(Color("#E8414A"), light)
			var gloss := Vector2((x + 0.45) / 0.28, (y - 0.45) / 0.16).length()
			return c.lerp(Color(1, 0.9, 0.85), clampf(1 - gloss, 0, 1) * 0.8)),
			"ui_painted/heart_%s.png" % ("full" if full else "empty"))
	# A brass cartridge with a copper bullet, lit from the left.
	for full in [true, false]:
		save_exact(smooth(18, 46, func(px: float, py: float) -> Color:
			var u := (px - 9.0) / 7.0  # -1..1 across
			if py < 2 or py > 45:
				return Color(0, 0, 0, 0)
			var shade := clampf(0.75 - 0.6 * u - 0.5 * u * u, 0, 1)
			if py < 16:  # the bullet's rounded tip
				var t := (16.0 - py) / 14.0
				if absf(u) > sqrt(maxf(0, 1 - t * t)) * 0.85:
					return Color(0, 0, 0, 0)
				return Color("#6E3B1E").lerp(Color("#E59A5E"), shade) if full else Color(0.25, 0.17, 0.12, 0.5)
			if absf(u) > 1:
				return Color(0, 0, 0, 0)
			if not full:
				return Color(0.25, 0.17, 0.12, 0.5)
			var c := Color("#7A5418").lerp(Color("#F6D27A"), shade)
			if py > 41:  # the rim
				c = c.darkened(0.35)
			return c),
			"ui_painted/bullet_%s.png" % ("full" if full else "empty"))
	# Wooden planks with grain, a dark frame and brass nails: a nine-patch for HUD panels and buttons.
	for kind in ["panel", "button", "button_pressed"]:
		var dark := 0.18 if kind == "button_pressed" else 0.0
		save_exact(smooth(64, 64, func(px: float, py: float) -> Color:
			var edge := minf(minf(px, 64 - px), minf(py, 64 - py))
			var r := 10.0
			var cx := clampf(px, r, 64 - r)
			var cy := clampf(py, r, 64 - r)
			if Vector2(px - cx, py - cy).length() > r:
				return Color(0, 0, 0, 0)
			if edge < 3.5:
				return Color("#2A1A10")
			var plank := int(py / 16.0)
			var grain := sin(px * 0.35 + plank * 7.0 + sin(px * 0.07 + plank) * 3.0) * 0.5 + 0.5
			var c := Color("#7A4A26").lerp(Color("#A86A38"), grain * 0.55 + noise2(px, py) * 0.2)
			if fmod(py, 16.0) < 1.2 and py > 4 and py < 60:
				c = Color("#3A2414")  # the seam between planks
			if edge < 6:
				c = c.lightened(0.18)  # bevel
			for nail in [Vector2(9, 9), Vector2(55, 9), Vector2(9, 55), Vector2(55, 55)]:
				var d := Vector2(px, py).distance_to(nail)
				if d < 2.4:
					return Color("#5A3A1A").lerp(Color("#F2C14E"), clampf(1.2 - d / 2.4, 0, 1))
			return c.darkened(dark)),
			"ui_painted/wood_%s.png" % kind)
	# Glowing draw rings: a bright core line with a soft halo, gold and (when time is short) red.
	for kind in {"normal": ["#FFF4C8", "#FFC85A"], "urgent": ["#FFE0D0", "#FF3B2F"]}.keys():
		var cols: Array = {"normal": ["#FFF4C8", "#FFC85A"], "urgent": ["#FFE0D0", "#FF3B2F"]}[kind]
		save_exact(smooth(176, 176, func(px: float, py: float) -> Color:
			var d := absf(Vector2(px, py).distance_to(Vector2(88, 88)) - 72.0)
			var core := clampf(1.0 - d / 2.6, 0, 1)
			var halo := exp(-d * d / 60.0) * 0.55
			var a := maxf(core, halo)
			return Color(Color(cols[1]).lerp(Color(cols[0]), core), a)),
			"ui_painted/draw_ring_%s.png" % kind)
	# A soft dark contact shadow, stretched under whatever stands on the street.
	save_exact(smooth(128, 32, func(px: float, py: float) -> Color:
		var d := Vector2((px - 64.0) / 62.0, (py - 16.0) / 14.0).length()
		return Color(0.12, 0.06, 0.02, clampf(pow(maxf(0, 1 - d * d), 1.6) * 0.6, 0, 1))),
		"ui_painted/contact_shadow.png")


## Signed distance to a five-pointed star pointing up (y up), outer radius r, inner ratio rf.
static func star5(p: Vector2, r: float, rf: float) -> float:
	var k1 := Vector2(0.809016994375, -0.587785252292)
	var k2 := Vector2(-k1.x, k1.y)
	p.x = absf(p.x)
	p -= 2.0 * maxf(k1.dot(p), 0.0) * k1
	p -= 2.0 * maxf(k2.dot(p), 0.0) * k2
	p.x = absf(p.x)
	p.y -= r
	var ba := rf * Vector2(-k1.y, k1.x) - Vector2(0, 1)
	var h := clampf(p.dot(ba) / ba.dot(ba), 0.0, r)
	return (p - ba * h).length() * signf(p.y * ba.x - p.x * ba.y)


## Signed distance to a triangle (negative inside), approximately: the furthest edge.
static func tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var d := -INF
	var s := signf((b - a).cross(c - a))
	for e in [[a, b], [b, c], [c, a]]:
		var edge: Vector2 = e[1] - e[0]
		d = maxf(d, -s * edge.cross(p - e[0]) / edge.length())
	return d


## Signed distance to a rounded rectangle (negative inside), for the painted UI below.
static func rr(px: float, py: float, x: float, y: float, w: float, h: float, r: float) -> float:
	var qx := absf(px - (x + w / 2)) - (w / 2 - r)
	var qy := absf(py - (y + h / 2)) - (h / 2 - r)
	return Vector2(maxf(qx, 0), maxf(qy, 0)).length() + minf(maxf(qx, qy), 0) - r


## Wood grain colour at a point: planks running across, lit from the top left.
func grain(px: float, py: float, base: Color, plank_h := 18.0) -> Color:
	var plank := int(py / plank_h)
	var g := sin(px * 0.21 + plank * 7.0 + sin(px * 0.05 + plank) * 3.0) * 0.5 + 0.5
	return base.lerp(base.lightened(0.28), g * 0.45 + noise2(px, py) * 0.15)


## Brass: a warm metal ramp lit from the top left.
static func brass(t: float) -> Color:
	return Color("#6B4A1A").lerp(Color("#F4D58A"), clampf(t, 0, 1))


## The painted UI kit (no pixel art): the overlay card, wood and brass buttons, parchment tags,
## stars, icons, office plates and poster paper. All nine-patches; the theme sets their margins.
func _painted_cards() -> void:
	var clear := Color(0, 0, 0, 0)
	var rim := Color("#1E120A")
	# The card every overlay screen sits on: a wooden frame with nails round a dark stained inset.
	save_exact(smooth(128, 128, func(px: float, py: float) -> Color:
		var d := rr(px, py, 1, 1, 126, 126, 18)
		if d > 0:
			return clear
		if d > -3:
			return rim
		var inset := rr(px, py, 22, 22, 84, 84, 8)
		if inset < 0:
			var c := Color("#2B1B10").lerp(Color("#3A2616"), (sin(px * 0.15 + sin(py * 0.04) * 2.0) * 0.5 + 0.5) * 0.5 + noise2(px, py) * 0.1)
			return c.darkened(clampf(1.0 + inset / 6.0, 0, 1) * 0.5)  # a shadow along the inset's edge
		if inset < 2.5:
			return Color("#120A05")
		var c2 := grain(px, py, Color("#6E4222"), 22.0)
		if d > -7:
			c2 = c2.lightened(0.15)  # bevel
		for nail in [Vector2(11, 11), Vector2(117, 11), Vector2(11, 117), Vector2(117, 117)]:
			var nd := Vector2(px, py).distance_to(nail)
			if nd < 3.2:
				return brass(1.3 - nd / 3.2)
		return c2),
		"ui_painted/card.png")
	# Buttons: a brass-rimmed plank with a lip underneath (the lip shrinks when pressed).
	for kind in ["gold", "gold_pressed", "wood", "wood_pressed"]:
		var pressed: bool = kind.ends_with("pressed")
		var gold: bool = kind.begins_with("gold")
		var lip := 3.0 if pressed else 8.0
		save_exact(smooth(96, 72, func(px: float, py: float) -> Color:
			var top := 2.0 + (8.0 - lip)
			var body := rr(px, py, 2, top, 92, 68 - top, 16)
			if body > 0:
				return clear
			if body > -2.5:
				return rim
			var face := rr(px, py, 2, top, 92, 68 - top - lip, 16)
			if face > -2.5 and face <= 0:
				return brass(0.9 - (py - top) / 60.0)  # the brass edge
			if face > 0:  # the lip
				return (Color("#8A5A16") if gold else Color("#3A2414")).darkened(0.2)
			var c: Color
			if gold:
				c = Color("#C9862E").lerp(Color("#F7CC6A"), clampf(1.0 - (py - top) / 50.0, 0, 1))
				c = c.lerp(c.darkened(0.12), (sin(px * 0.2 + sin(px * 0.05) * 3.0) * 0.5 + 0.5) * 0.3)
			else:
				c = grain(px, py, Color("#5E3A1E"), 30.0)
			if face > -6:
				c = c.lightened(0.12)
			return c.darkened(0.12 if pressed else 0.0)),
			"ui_painted/button_%s.png" % kind)
	# A parchment tag for counts on the intro card (bullets, par).
	save_exact(smooth(64, 56, func(px: float, py: float) -> Color:
		var d := rr(px, py, 2, 2, 60, 52, 24)
		if d > 0:
			return clear
		if d > -2.5:
			return Color("#5A3A1E")
		var c := Color("#E8D3A8").lerp(Color("#F7ECCF"), clampf(1.0 - py / 50.0, 0, 1) * 0.6 + noise2(px * 0.5, py * 0.5) * 0.15)
		return c.darkened(clampf(1.0 + d / 8.0, 0, 1) * 0.15)),
		"ui_painted/pill.png")
	# Parchment for posters and the telegram (aged edges), and a darker one for locked posters.
	for kind in ["paper", "paper_locked"]:
		var locked: bool = kind == "paper_locked"
		save_exact(smooth(64, 64, func(px: float, py: float) -> Color:
			var wob := sin(px * 0.9) * 0.6 + sin(py * 1.1) * 0.6
			var d := rr(px, py, 2, 2, 60, 60, 4) + wob
			if d > 0:
				return clear
			var c := Color("#E2C994").lerp(Color("#F4E4BE"), noise2(px * 0.4, py * 0.4) * 0.35 + 0.4)
			c = c.darkened(clampf(1.0 + d / 10.0, 0, 1) * 0.35)  # browned edges
			return c.darkened(0.45) if locked else c),
			"ui_painted/%s.png" % kind)
	# The red ink box of a stamp.
	save_exact(smooth(64, 48, func(px: float, py: float) -> Color:
		var d := absf(rr(px, py, 4, 4, 56, 40, 4)) - 2.6
		if d > 0 or noise2(px * 1.7, py * 1.7) < 0.12:
			return clear
		return Color(0.72, 0.16, 0.18, 0.92)),
		"ui_painted/stamp_box.png")
	# Office plates: brass name plates (dull for "coming soon"), wooden desk plaques, a leather wallet.
	for kind in ["plate", "plate_pressed", "plate_soon"]:
		save_exact(smooth(48, 48, func(px: float, py: float) -> Color:
			var d := rr(px, py, 1, 1, 46, 46, 8)
			if d > 0:
				return clear
			if d > -2:
				return rim
			var t := 1.0 - py / 46.0 + (0.0 if kind != "plate_pressed" else -0.25)
			var c := brass(0.35 + t * 0.6)
			if kind == "plate_soon":
				c = Color(c.get_luminance(), c.get_luminance(), c.get_luminance()).darkened(0.25)
			return c.darkened(clampf(1.0 + d / 5.0, 0, 1) * 0.25)),
			"ui_painted/%s.png" % kind)
	for kind in ["desk", "desk_pressed"]:
		save_exact(smooth(48, 52, func(px: float, py: float) -> Color:
			var d := rr(px, py, 1, 1, 46, 50, 10)
			if d > 0:
				return clear
			if d > -2.5:
				return rim
			var c := Color("#E9D7B0").lerp(Color("#F8EDD2"), clampf(1.0 - py / 48.0, 0, 1) * 0.5)
			return c.darkened((0.12 if kind == "desk_pressed" else 0.0) + clampf(1.0 + d / 6.0, 0, 1) * 0.2)),
			"ui_painted/%s.png" % kind)
	save_exact(smooth(64, 64, func(px: float, py: float) -> Color:
		var d := rr(px, py, 1, 1, 62, 62, 14)
		if d > 0:
			return clear
		if d > -2.5:
			return rim
		if absf(d + 7) < 0.9 and int(px + py) % 6 < 3:
			return Color("#C9A86A")  # stitching
		return Color("#3E2414").lerp(Color("#6A3E22"), clampf(1.0 - py / 60.0, 0, 1) * 0.6 + noise2(px, py) * 0.15)),
		"ui_painted/wallet.png")
	# Stars: polished gold, or an empty carved socket.
	for on in [true, false]:
		save_exact(smooth(80, 80, func(px: float, py: float) -> Color:
			var p := Vector2(px - 40, py - 43)
			var d := star5(Vector2(p.x, -p.y), 34.0, 0.48)
			if d > 0:
				return clear
			if d > -3:
				return rim
			if not on:
				return Color("#3A2A1E").lerp(Color("#5A4634"), clampf(-p.y / 30.0, 0, 1) * 0.5)
			var light := clampf(0.55 - p.x / 60.0 - p.y / 45.0, 0, 1)
			var c := Color("#B9781E").lerp(Color("#FFE08A"), light)
			return c.lerp(Color(1, 0.97, 0.85), clampf(1 - Vector2(p.x + 8, p.y + 10).length() / 7.0, 0, 1) * 0.8)),
			"ui_painted/star_%s.png" % ("on" if on else "off"))
	# Icons: cream glyphs with a dark outline, for the wooden icon buttons and plates.
	var glyph := func(sz: int, inside: Callable, path: String) -> void:
		save_exact(smooth(sz, sz, func(px: float, py: float) -> Color:
			var d: float = inside.call(px / sz, py / sz) * sz
			if d < 0:
				return Color("#F6E7CC")
			if d < 2.2:
				return Color(0.12, 0.07, 0.04, 0.9)
			return clear), path)
	var seg := func(x: float, y: float, ax: float, ay: float, bx: float, by: float, w: float) -> float:
		var pa := Vector2(x - ax, y - ay)
		var ba := Vector2(bx - ax, by - ay)
		var h := clampf(pa.dot(ba) / ba.dot(ba), 0, 1)
		return (pa - ba * h).length() - w
	var box := func(x: float, y: float, cx: float, cy: float, hw: float, hh: float) -> float:
		return maxf(absf(x - cx) - hw, absf(y - cy) - hh)
	var speaker := func(x: float, y: float) -> float:
		return minf(box.call(x, y, 0.24, 0.5, 0.08, 0.12), maxf(absf(y - 0.5) - (x - 0.18) * 0.9, absf(x - 0.36) - 0.12))
	glyph.call(48, func(x, y): return minf(box.call(x, y, 0.36, 0.5, 0.08, 0.27), box.call(x, y, 0.64, 0.5, 0.08, 0.27)), "ui_painted/icon_pause.png")
	glyph.call(48, func(x, y):
		var p := Vector2(x - 0.5, y - 0.53)
		var ring := absf(p.length() - 0.25) - 0.065
		var a := atan2(p.y, p.x)
		if a > -1.75 and a < -0.75:
			ring = 1.0  # the gap the arrow head points into
		return minf(ring, tri(Vector2(x, y), Vector2(0.42, 0.14), Vector2(0.42, 0.42), Vector2(0.62, 0.28))), "ui_painted/icon_restart.png")
	glyph.call(48, func(x, y):
		var p := Vector2(x - 0.42, y - 0.5)
		var waves := 1.0
		for r in [0.18, 0.3]:
			if p.x > 0 and absf(atan2(p.y, p.x)) < 0.8:
				waves = minf(waves, absf(p.length() - r) - 0.04)
		return minf(speaker.call(x, y), waves), "ui_painted/icon_sound_on.png")
	glyph.call(48, func(x, y):
		return minf(speaker.call(x, y), minf(seg.call(x, y, 0.58, 0.38, 0.8, 0.62, 0.045), seg.call(x, y, 0.58, 0.62, 0.8, 0.38, 0.045))), "ui_painted/icon_sound_off.png")
	for off in [false, true]:
		glyph.call(36, func(x, y):
			var note := minf(Vector2((x - 0.38) / 1.25, y - 0.72).length() - 0.12, minf(box.call(x, y, 0.5, 0.45, 0.045, 0.28), seg.call(x, y, 0.5, 0.19, 0.74, 0.32, 0.05)))
			return minf(note, seg.call(x, y, 0.18, 0.18, 0.82, 0.84, 0.05)) if off else note,
			"ui_painted/icon_music%s.png" % ("_off" if off else ""))
	glyph.call(36, func(x, y):
		var shackle := maxf(absf(Vector2(x - 0.5, y - 0.4).length() - 0.2) - 0.06, y - 0.45)
		return minf(box.call(x, y, 0.5, 0.65, 0.28, 0.2), shackle), "ui_painted/icon_lock.png")
	# A brass pin for the posters on the office wall.
	save_exact(smooth(16, 16, func(px: float, py: float) -> Color:
		var d := Vector2(px - 8, py - 8).length()
		if d > 6.5:
			return clear
		return rim if d > 5.2 else brass(1.1 - Vector2(px - 6, py - 6).length() / 6.0)), "ui_painted/pin.png")
	# Wanted-poster portraits: the painted outlaw's head and shoulders, inked in sepia (placeholders).
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/painted/outlaw_idle.png"))
	var tints := [Color("#5A3A22"), Color("#3E3A30"), Color("#4A2E2A"), Color("#2E3A3A"), Color("#4A3A1E")]
	for c in 5:
		var head := src.get_region(Rect2i(0, 0, src.get_width(), 84))
		head.resize(int(head.get_width() * 156.0 / 84.0), 156, Image.INTERPOLATE_LANCZOS)
		if c % 2 == 1:
			head.flip_x()
		var out := img(168, 156)
		var ox := (168 - head.get_width()) / 2
		for y in 156:
			for x in 168:
				var paper := Color("#EAD6A8").darkened(Vector2((x - 84) / 84.0, (y - 78) / 78.0).length_squared() * 0.18)
				var hx := x - ox
				var px_c := head.get_pixel(hx, y) if hx >= 0 and hx < head.get_width() else Color(0, 0, 0, 0)
				var ink: Color = Color(tints[c]).lerp(Color("#EAD6A8"), clampf(px_c.get_luminance() * 1.6, 0, 1) * 0.7)
				out.set_pixel(x, y, paper.lerp(ink, px_c.a))
		save_exact(out, "ui_painted/portrait_ch%d.png" % c)


## Overlays for the painted sheriff's office (assets/painted/office.png), in its own pixels:
## trophies for the cabinet, guns for the gunsmith's rack, the hunter's portrait for the gilt
## frame, lamp glow and dust motes. Placeholders until painted versions arrive.
func _office_overlays() -> void:
	var clear := Color(0, 0, 0, 0)
	var rim := Color(0.12, 0.07, 0.04, 1)
	# Trophy cups, each with its bounty's ribbon colour.
	var ribbons := [Color("#9A2A22"), Color("#2A4A8A"), Color("#2E6A3A"), Color("#5A2A6A"), Color("#1E1E1E")]
	for k in 5:
		save_exact(smooth(48, 56, func(px: float, py: float) -> Color:
			var x := px - 24.0
			var cup := py > 4 and py < 30 and absf(x) < lerpf(15.0, 7.0, (py - 4) / 26.0)
			var handle := absf(Vector2(absf(x) - 15.0, py - 13.0).length() - 5.0) < 1.6 and absf(x) > 13
			var stem := py >= 30 and py < 40 and absf(x) < 3.0
			var base := py >= 40 and py < 54 and absf(x) < 13.0
			if not (cup or handle or stem or base):
				return clear
			if base and py >= 46:
				return Color(ribbons[k]).lerp(Color(ribbons[k]).lightened(0.3), clampf(0.6 - x / 20.0, 0, 1))
			var light := clampf(0.65 - x / 18.0 - (py - 20) / 80.0, 0, 1)
			var c := brass(0.25 + light * 0.9)
			if cup and py < 6.5:
				c = c.darkened(0.35)  # the rim's inner shadow
			return c),
			"ui_painted/trophy_%d.png" % k)
	# Guns for the rack, side on, muzzle to the left: [length, barrel colour, grip colour, rifle?].
	var guns := {"peacemaker": [60.0, "#5E6268", "#6A3A1E", false], "quickdraw": [54.0, "#3E4248", "#2A1A10", false],
		"longbarrel": [76.0, "#6E7278", "#7A4A26", false], "coach": [96.0, "#4A4E54", "#6A3A1E", true],
		"repeater": [104.0, "#4E5258", "#8A5A2E", true], "legend": [64.0, "#E8C060", "#F2EAD8", false]}
	for id in guns:
		var g: Array = guns[id]
		var L: float = g[0]
		var w := int(L + 8)
		save_exact(smooth(w, 30, func(px: float, py: float) -> Color:
			var metal := Color(g[1])
			var wood := Color(g[2])
			var barrel_end: float = L * (0.62 if g[3] else 0.5)
			var in_barrel: bool = px > 4 and px < barrel_end and py > 8 and py < 13
			var in_cyl: bool = not g[3] and px > barrel_end - 4 and px < barrel_end + 10 and py > 6 and py < 17
			var in_frame: bool = px > barrel_end - 2 and px < L * 0.8 and py > 7 and py < 16
			var in_grip: bool
			if g[3]:  # a rifle stock
				in_grip = px >= L * 0.78 and px < L + 4 and py > 8 and py < 13 + (px - L * 0.78) * 0.45
			else:  # a revolver grip, raked back
				in_grip = py >= 14 and py < 28 and px > L * 0.66 + (py - 14) * 0.5 and px < L * 0.84 + (py - 14) * 0.5
			var guard: bool = absf(Vector2(px - L * 0.62, py - 17).length() - 3.5) < 1.0 and py > 16
			if not (in_barrel or in_cyl or in_frame or in_grip or guard):
				return clear
			if in_grip:
				return wood.lerp(wood.lightened(0.3), clampf(0.7 - (py - 14) / 20.0, 0, 1) * 0.6)
			var shine := clampf(1.0 - absf(py - 9.5) / 3.0, 0, 1)
			return metal.darkened(0.35).lerp(metal.lightened(0.35), shine)),
			"ui_painted/rack_%s.png" % id)
	# A warm, soft lamp glow and a dust mote.
	save_exact(smooth(128, 128, func(px: float, py: float) -> Color:
		var d := Vector2(px - 64, py - 64).length() / 64.0
		return Color(1.0, 0.82, 0.5, clampf(pow(maxf(0, 1 - d), 2.2) * 0.75, 0, 1))), "ui_painted/glow.png")
	save_exact(smooth(12, 12, func(px: float, py: float) -> Color:
		var d := Vector2(px - 6, py - 6).length() / 6.0
		return Color(1.0, 0.92, 0.75, clampf((1 - d) * 0.9, 0, 1))), "ui_painted/mote.png")
	# The bounty hunter's portrait for the gilt frame: the painted outlaw's head and shoulders.
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/painted/outlaw_idle.png"))
	var head := src.get_region(Rect2i(0, 0, src.get_width(), 92))
	head.resize(int(head.get_width() * 200.0 / 92.0), 200, Image.INTERPOLATE_LANCZOS)
	var out := img(120, 192)
	var ox := (120 - head.get_width()) / 2
	for y in 192:
		for x in 120:
			var bg := Color("#3A2416").lerp(Color("#6A4024"), clampf(1.0 - Vector2((x - 60) / 60.0, (y - 70) / 110.0).length(), 0, 1))
			var hx := x - ox
			var c := head.get_pixel(hx, y + 4) if hx >= 0 and hx < head.get_width() else clear
			out.set_pixel(x, y, bg.lerp(Color(c.r, c.g, c.b), c.a))
	save_exact(out, "ui_painted/hunter_portrait.png")
