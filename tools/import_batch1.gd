extends SceneTree
## Cuts the rest of art batch 1 out of the sheets in assets/incoming into assets/painted, and prints
## the measurements the manifest needs (anchors and points, in pixels of the saved images):
##   Godot --headless --path . -s res://tools/import_batch1.gd
## - the clocktower splash: the painting with its bell lifted out (so the bell can swing), the bell,
##   painted-iron clock hands and the two standoff silhouettes (the painted outlaw, darkened);
## - the outlaw's walk: two frames each way on one shared anchor (the belt), so they don't jitter;
## - Target Practice: three bottles and their shattered bases, glass shards, the bench, the bucket;
## - hanging hardware: the signpost, the wall bracket, one repeatable stretch of chain, the hook;
## - the UI kit and icon sheet: wooden and parchment panels, gold and wooden buttons (with pressed
##   versions), the wanted poster, the CAPTURED stamp, hearts, cartridges, stars, the padlock, the
##   coin, the brass plaque and the control icons (lightly outlined so they read on wood, with red
##   slashes for sound and music off).
## Images drawn in the street or as icons are stored at twice their screen size (manifest scale 0.5).

const Cut := preload("res://tools/cut.gd")
const IN := "res://assets/incoming/"
const OUT := "res://assets/painted/"
const D := 8.0  # output pixels per gameplay unit, as in import_painted.gd
const SPLASH := "High Noon Clocktower in a Western Frontier Town.png"
const WALK := "Four Walking Outlaw Poses.png"
const BOTTLES := "Rustic Bottles, Glass, Bench and Bucket.png"
const HARDWARE := "Western-Style Sign Hanging Hardware Sheet.png"
const UI := "Western Game UI Asset Kit.png"
const ICONS := "Hand-Painted Western Game Icon Sheet.png"
## The walking outlaw is drawn at the same size as the standing poses (import_painted.gd OUTLAW_K).
const OUTLAW_K := 20.0 * D / 724.0
## Where the painting's clock and bell are, in its pixels (measured by eye, refined below).
const CLOCK_NEAR := Vector2i(960, 288)
const BELL_BOX := Rect2i(916, 114, 86, 80)

var _sheets := {}
var G: Dictionary


func _init() -> void:
	G = JSON.parse_string(FileAccess.get_file_as_string("res://data/geometry.json"))
	_splash()
	_walk()
	_bottles()
	_hardware()
	_ui()
	_icons()
	quit()


func _sheet(name: String) -> Image:
	if not _sheets.has(name):
		var im := Image.load_from_file(ProjectSettings.globalize_path(IN + name))
		im.convert(Image.FORMAT_RGBA8)
		_sheets[name] = im
	return _sheets[name]


## A piece of a transparent sheet: its halo trimmed, and only its main shape kept unless keep is "all".
func _piece(sheet: String, box: Rect2i, keep := "largest") -> Image:
	var im := _sheet(sheet).get_region(box)
	Cut.defringe(im)
	if keep != "all":
		Cut.keep(im, keep)
	return im


func _save(file: String, im: Image) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT + file + ".png"))


func _say(name: String, file: String, anchor: Vector2i, extra := "") -> void:
	print('    "%s": {"frames": ["painted/%s.png"], "anchor": [%d, %d]%s},' % [name, file, anchor.x, anchor.y, extra])


static func _lowest_row(im: Image) -> int:
	for y in range(im.get_height() - 1, -1, -1):
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.5:
				return y
	return 0


static func _row_count(im: Image, y: int) -> int:
	var n := 0
	for x in im.get_width():
		if im.get_pixel(x, y).a > 0.5:
			n += 1
	return n


## The mean x of the solid pixels between two heights (fractions of the image).
static func _mid_x(im: Image, from: float, to: float) -> float:
	var sx := 0.0
	var n := 0
	for y in range(int(im.get_height() * from), int(im.get_height() * to)):
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.5:
				sx += x
				n += 1
	return sx / maxi(1, n)


## Puts an image on a transparent canvas of `size` with its pixel `at` landing on `to`.
static func _pad(im: Image, size: Vector2i, at: Vector2i, to: Vector2i) -> Image:
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), to - at)
	return out


# --- The splash ---------------------------------------------------------------------------------

func _splash() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(IN + SPLASH))
	src.convert(Image.FORMAT_RGBA8)
	# The clock's centre pin: the darkest pixel near the middle of the face.
	var pin := CLOCK_NEAR
	var darkest := 9.0
	for y in range(CLOCK_NEAR.y - 12, CLOCK_NEAR.y + 13):
		for x in range(CLOCK_NEAR.x - 12, CLOCK_NEAR.x + 13):
			var l := src.get_pixel(x, y).get_luminance()
			if l < darkest:
				darkest = l
				pin = Vector2i(x, y)
	# The bell: bronze pixels joined to its middle, inside its box (not the dark belfry, sky or beams).
	var B := BELL_BOX
	var mask := PackedByteArray()
	mask.resize(B.size.x * B.size.y)
	var stack: Array[Vector2i] = [Vector2i(B.size.x / 2, B.size.y / 2)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= B.size.x or p.y >= B.size.y or mask[p.y * B.size.x + p.x]:
			continue
		var c := src.get_pixel(B.position.x + p.x, B.position.y + p.y)
		if c.b > c.r - 0.05 or c.get_luminance() < 0.2:
			continue
		mask[p.y * B.size.x + p.x] = 1
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			stack.append(p + d)
	_fill_holes(mask, B.size)
	_open_top(mask, B.size, 2, int(B.size.y * 0.6))  # the brace stubs touching its shoulders
	var grown := _grow(mask, B.size, 2)
	var bell := Image.create_empty(B.size.x, B.size.y, false, Image.FORMAT_RGBA8)
	var top := B.size.y
	var sx := 0.0
	var n := 0
	for y in B.size.y:
		for x in B.size.x:
			if mask[y * B.size.x + x]:
				bell.set_pixel(x, y, src.get_pixel(B.position.x + x, B.position.y + y))
				if y < top:
					top = y
			elif grown[y * B.size.x + x] and _grow_touch(mask, B.size, x, y):
				bell.set_pixel(x, y, Color(src.get_pixel(B.position.x + x, B.position.y + y), 0.5))  # soft edge
	for x in B.size.x:
		for y in range(top, top + 4):
			if mask[y * B.size.x + x]:
				sx += x
				n += 1
	var hang := Vector2i(roundi(sx / maxi(1, n)), top)  # where it hangs: the top of its yoke
	# The painting without its bell: each row filled across between the pixels either side.
	for y in B.size.y:
		var x := 0
		while x < B.size.x:
			if not grown[y * B.size.x + x]:
				x += 1
				continue
			var x1 := x
			while x < B.size.x and grown[y * B.size.x + x]:
				x += 1
			var a := src.get_pixel(B.position.x + x1 - 1, B.position.y + y)
			var b := src.get_pixel(B.position.x + x, B.position.y + y)
			for i in range(x1, x):
				src.set_pixel(B.position.x + i, B.position.y + y, a.lerp(b, float(i - x1 + 1) / (x - x1 + 1)))
	var bg: Image = src.duplicate()
	bg.convert(Image.FORMAT_RGB8)
	bg.save_png(ProjectSettings.globalize_path(OUT + "splash.png"))
	_save("splash_bell", bell)
	print('    "splash/painted": {"frames": ["painted/splash.png"], "anchor": "top_left"},')
	_say("splash/bell", "splash_bell", hang, ', "points": {"at": [%d, %d]}' % [B.position.x + hang.x, B.position.y + hang.y])
	# The face's radius: from the pin out to the brass rim (the first dark-orange ring pixel going up).
	var r := 10
	while r < 120 and src.get_pixel(pin.x, pin.y - r).get_luminance() > 0.62:
		r += 1
	print("    clock pin %s, face radius %d" % [pin, r])
	_hand("splash_minute", r * 0.78, 3.4, 2.0)
	_hand("splash_hour", r * 0.52, 4.6, 2.0)
	_silhouette()


## Fills the holes inside a mask (dark shading inside the bell): what the outside can't reach.
static func _fill_holes(mask: PackedByteArray, size: Vector2i) -> void:
	var out := PackedByteArray()
	out.resize(mask.size())
	var stack: Array[Vector2i] = []
	for x in size.x:
		stack.append(Vector2i(x, size.y - 1))
		stack.append(Vector2i(x, 0))
	for y in size.y:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(size.x - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
			continue
		var i := p.y * size.x + p.x
		if out[i] or mask[i]:
			continue
		out[i] = 1
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			stack.append(p + d)
	for i in mask.size():
		if not out[i]:
			mask[i] = 1


## Drops parts thinner than 2r + 1 pixels above row `rows` (a shrink, then a grow back).
static func _open_top(mask: PackedByteArray, size: Vector2i, r: int, rows: int) -> void:
	var core := PackedByteArray()
	core.resize(mask.size())
	for y in size.y:
		for x in size.x:
			var all := true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var qx := x + dx
					var qy := y + dy
					if qx < 0 or qy < 0 or qx >= size.x or qy >= size.y or not mask[qy * size.x + qx]:
						all = false
			core[y * size.x + x] = 1 if all else 0
	var kept := _grow(core, size, r)
	for y in rows:
		for x in size.x:
			mask[y * size.x + x] = mask[y * size.x + x] & kept[y * size.x + x]


static func _grow(mask: PackedByteArray, size: Vector2i, r: int) -> PackedByteArray:
	var out := mask.duplicate()
	for y in size.y:
		for x in size.x:
			if mask[y * size.x + x]:
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var qx := x + dx
						var qy := y + dy
						if qx >= 0 and qy >= 0 and qx < size.x and qy < size.y:
							out[qy * size.x + qx] = 1
	return out


static func _grow_touch(mask: PackedByteArray, size: Vector2i, x: int, y: int) -> bool:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var q: Vector2i = Vector2i(x, y) + d
		if q.x >= 0 and q.y >= 0 and q.x < size.x and q.y < size.y and mask[q.y * size.x + q.x]:
			return true
	return false


## A wrought-iron clock hand pointing up, `length` painting pixels from the pin, stored at `k` times
## the painting's size; anchored on the pin.
func _hand(file: String, length: float, width: float, k: float) -> void:
	var L := length * k
	var W := width * k
	var tail := L * 0.18
	var w := int(W * 4 + 6)
	var h := int(L + tail + 6)
	var im := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var pin_y := L + 3
	for y in h:
		for x in w:
			var dx := absf(x + 0.5 - cx)
			var up := pin_y - (y + 0.5)  # distance up the hand from the pin
			var half := 0.0
			if up > -tail and up < L * 0.72:
				half = W / 2
			elif up >= L * 0.72 and up < L:  # a spade tip
				var t := (up - L * 0.72) / (L * 0.28)
				half = W * (1.9 * sin(minf(1, t * 1.6) * PI * 0.6)) * (1 - t) + W * 0.15
			var ring := Vector2(x + 0.5 - cx, up).length()
			var a := clampf(half - dx + 0.5, 0, 1)
			a = maxf(a, clampf(W * 1.1 - ring + 0.5, 0, 1))  # the boss over the pin
			if a <= 0:
				continue
			var light := 0.16 + 0.1 * clampf(1 - dx / maxf(1, half), 0, 1)
			im.set_pixel(x, y, Color(light, light * 0.72, light * 0.55, a))
	_save(file, im)
	_say("splash/" + file.trim_prefix("splash_"), file, Vector2i(roundi(cx), roundi(pin_y)), ', "scale": %.2f' % (1.0 / k))


## The standoff's two figures: the painted outlaw as a dark silhouette with a warm rim of light.
func _silhouette() -> void:
	var im := Image.load_from_file(ProjectSettings.globalize_path(OUT + "outlaw_idle.png"))
	im.convert(Image.FORMAT_RGBA8)
	var out: Image = im.duplicate()
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a == 0:
				continue
			var edge := x + 2 >= im.get_width() or im.get_pixel(x + 2, y).a < 0.3  # lit from the right
			out.set_pixel(x, y, Color(0.42, 0.24, 0.12, c.a) if edge else Color(0.075, 0.05, 0.04, c.a))
	_save("splash_figure", out)
	print('    "splash/hero" and "splash/rival": painted/splash_figure.png, anchor as outlaw/idle')


# --- The walk -----------------------------------------------------------------------------------

func _walk() -> void:
	var boxes := [Rect2i(52, 4, 488, 716), Rect2i(612, 8, 416, 712), Rect2i(1088, 8, 508, 712), Rect2i(1628, 8, 472, 712)]
	var frames: Array[Image] = []
	var anchors: Array[Vector2i] = []
	for box in boxes:
		var im := Cut.scale(_piece(WALK, box, "figure"), OUTLAW_K)
		frames.append(im)
		anchors.append(Vector2i(roundi(_mid_x(im, 0.38, 0.48)), _lowest_row(im) + 1))  # the belt, over the soles
	var left := 0
	var right := 0
	var up := 0
	for i in 4:
		left = maxi(left, anchors[i].x)
		right = maxi(right, frames[i].get_width() - anchors[i].x)
		up = maxi(up, anchors[i].y)
	var names := ["walk_left_0", "walk_left_1", "walk_right_0", "walk_right_1"]  # the sheet: two going left, two going right
	for i in 4:
		_save("outlaw_" + names[i], _pad(frames[i], Vector2i(left + right, up), anchors[i], Vector2i(left, up)))
	print('    "outlaw/walk_left" / "outlaw/walk_right": anchor [%d, %d], scale 1.0' % [left, up])


# --- Target Practice ----------------------------------------------------------------------------

func _bottles() -> void:
	var k := 15.0 * D / 364.0  # the tall bottles are the bottle's 15-unit hit area
	var whole := [Rect2i(64, 180, 124, 388), Rect2i(208, 240, 156, 328), Rect2i(388, 176, 124, 392)]
	var broken := [Rect2i(500, 300, 216, 276), Rect2i(716, 300, 184, 276), Rect2i(900, 300, 168, 276)]
	for i in 3:
		for pair in [["whole", whole[i], "largest", 0.0, 1.0], ["broken", broken[i], "all", 0.2, 0.75]]:
			var im := Cut.scale(_piece(BOTTLES, pair[1], pair[2]), k)
			var file := "bottle_%s_%d" % [pair[0], i]
			_save(file, im)
			_say("bottle/%s%d" % [pair[0], i], file, Vector2i(roundi(_mid_x(im, pair[3], pair[4])), _lowest_row(im) + 1), ', "scale": 0.5')
	# Shards for the glass burst: one per frame, each centred on the same small canvas.
	var shards := [Rect2i(548, 492, 48, 36), Rect2i(568, 516, 76, 48), Rect2i(744, 520, 76, 56), Rect2i(940, 524, 68, 48), Rect2i(1000, 512, 64, 52), Rect2i(676, 516, 44, 28)]
	var files: Array[String] = []
	for i in shards.size():
		var s := Cut.scale(_piece(BOTTLES, shards[i]), 0.48)
		_save("glass_%d" % i, _pad(s, Vector2i(40, 40), s.get_size() / 2, Vector2i(20, 20)))
		files.append('"painted/glass_%d.png"' % i)
	print('    "fx/glass": {"frames": [%s], "anchor": "center", "scale": 0.5},' % ", ".join(files))
	# The bench: its top board at the bottles' rail, its feet on the street.
	var bench := _piece(BOTTLES, Rect2i(1112, 228, 704, 376))
	var top := 0
	while _row_count(bench, top) < bench.get_width() * 0.6:
		top += 1
	var feet := _lowest_row(bench)
	var gy: float = G.scenes.street.GY
	var kb := (gy - float(G.bottle.rail_y)) * D / (feet - top - 3)
	var b := Cut.scale(bench, kb)
	var btop := 0
	while _row_count(b, btop) < b.get_width() * 0.6:
		btop += 1
	_save("prop_bench", b)
	_say("prop/bench", "prop_bench", Vector2i(b.get_width() / 2, btop + roundi(3 * kb)), ', "scale": 0.5')
	# The bucket: its body the hit area's height, anchored at the middle of its rim; the bail's top is a point.
	var raw := _piece(BOTTLES, Rect2i(1852, 188, 300, 384))
	var widest := 0
	for y in raw.get_height():
		widest = maxi(widest, _row_count(raw, y))
	var rim := 0
	while _row_count(raw, rim) < widest * 0.7:
		rim += 1
	var kk := float(G.bucket.size[1]) * D / (_lowest_row(raw) - rim)
	var bucket := Cut.scale(raw, kk)
	var brim := 0
	while _row_count(bucket, brim) < widest * kk * 0.7:
		brim += 1
	var bail_top := 0
	while _row_count(bucket, bail_top) == 0:
		bail_top += 1
	var cx := roundi(_mid_x(bucket, float(brim) / bucket.get_height(), 1.0))
	_save("prop_bucket", bucket)
	_say("prop/bucket", "prop_bucket", Vector2i(cx, brim), ', "scale": 0.5, "points": {"bail": [0, %d]}' % (bail_top - brim))


# --- Hanging hardware ---------------------------------------------------------------------------

func _hardware() -> void:
	# The signpost: anchored at the foot of the post; points along the underside of its arm.
	var post := Cut.scale(_piece(HARDWARE, Rect2i(140, 8, 556, 808)), 0.75)
	var ground := _lowest_row(post) + 1
	var px := roundi(_mid_x(post, 0.8, 0.9))
	var arm_end := 0
	for y in int(post.get_height() * 0.3):
		for x in post.get_width():
			if post.get_pixel(x, y).a > 0.5:
				arm_end = maxi(arm_end, x)
	var col := arm_end - 12
	var under := 0
	for y in int(post.get_height() * 0.4):
		if post.get_pixel(col, y).a > 0.5:
			under = y
	var post_right := px  # where the arm leaves the post, below the brace
	while post.get_pixel(post_right, ground - 40).a > 0.5:
		post_right += 1
	_save("prop_signpost", post)
	_say("prop/signpost", "prop_signpost", Vector2i(px, ground), ', "points": {"arm_from": [%d, %d], "arm_to": [%d, %d]}' % [
		post_right - px + 24, under - ground, arm_end - 10 - px, under - ground])
	# The wall bracket: anchored at the bottom of its ring, where a chain hooks on.
	var br := Cut.scale(_piece(HARDWARE, Rect2i(468, 328, 416, 292)), 0.75)
	var rx0 := roundi((755 - 468) * 0.75)
	var rx1 := roundi((812 - 468) * 0.75)
	var ring := Vector2i(0, 0)
	for x in range(rx0, rx1):
		for y in range(br.get_height() - 1, -1, -1):
			if br.get_pixel(x, y).a > 0.5:
				if y > ring.y:
					ring = Vector2i(x, y)
				break
	var plate_x := 0
	while _column_count(br, plate_x) == 0:
		plate_x += 1
	_save("prop_bracket", br)
	_say("prop/bracket", "prop_bracket", ring, ', "points": {"wall": [%d, 0]}' % (plate_x - ring.x))
	# The chain: one period of its alternating links, which repeats seamlessly.
	# The INN sign's board without its painted chains: chains are now built from links.
	var sign := Image.load_from_file(ProjectSettings.globalize_path(OUT + "prop_sign.png"))
	var board_top := 0
	while _row_count(sign, board_top) < sign.get_width() / 2:
		board_top += 1
	_save("prop_sign_board", sign.get_region(Rect2i(0, board_top - 2, sign.get_width(), sign.get_height() - board_top + 2)))
	_say("prop/sign", "prop_sign_board", Vector2i(0, 2), ', "scale": 0.85')
	var kc := 0.3
	var chain := Cut.scale(_piece(HARDWARE, Rect2i(1012, 280, 80, 444), "all"), kc)
	var prof: Array[int] = []
	for y in chain.get_height():
		prof.append(_row_count(chain, y))
	var best := 0
	var best_s := 1e9
	var scores := {}
	for p in range(12, chain.get_height() / 2):
		var s := 0.0
		var cnt := 0
		for y in range(4, chain.get_height() - p - 4):
			s += absf(prof[y] - prof[y + p])
			cnt += 1
		scores[p] = s / maxi(1, cnt)
		if scores[p] < best_s:
			best_s = scores[p]
			best = p
	for p in range(12, best):  # the shortest period nearly as good (not two periods at once)
		if scores[p] < best_s * 1.2 + 0.3:
			best = p
			break
	var y0 := (chain.get_height() - best) / 2
	var tile := chain.get_region(Rect2i(0, y0, chain.get_width(), best))
	_save("prop_chain", tile)
	print('    "prop/chain": {"frames": ["painted/prop_chain.png"], "anchor": [%d, 0], "scale": 0.5},  # period %d px' % [tile.get_width() / 2, best])
	# The hook: hangs from its eye; the bucket's bail sits in the bottom of the J.
	var hook := Cut.scale(_piece(HARDWARE, Rect2i(1224, 368, 116, 240)), kc)
	var low := _lowest_row(hook)
	var lx := 0
	for x in hook.get_width():
		if hook.get_pixel(x, low).a > 0.5:
			lx = x
			break
	var t := 0
	while low - t > 0 and hook.get_pixel(lx + 1, low - t).a > 0.5:
		t += 1
	var eye_x := roundi(_mid_x(hook, 0.0, 0.08))
	_save("prop_hook", hook)
	_say("prop/hook", "prop_hook", Vector2i(eye_x, 0), ', "scale": 0.5, "points": {"catch": [%d, %d]}' % [lx + 1 - eye_x, low - t])


static func _column_count(im: Image, x: int) -> int:
	var n := 0
	for y in im.get_height():
		if im.get_pixel(x, y).a > 0.5:
			n += 1
	return n


# --- The UI kit ---------------------------------------------------------------------------------

func _ui() -> void:
	var panel := _piece(UI, Rect2i(24, 12, 920, 304))
	_save("ui_panel", Cut.scale(panel, 0.75))  # its planks tile down a tall card
	_save("ui_panel_small", Cut.scale(panel, 0.25))
	_save("ui_parchment", Cut.scale(_piece(UI, Rect2i(1000, 12, 580, 308)), 0.5))
	var kb := 72.0 / 136.0
	_save("ui_button_wood", Cut.scale(_piece(UI, Rect2i(24, 356, 416, 152)), kb))
	_save("ui_button_wood_pressed", Cut.scale(_piece(UI, Rect2i(24, 512, 416, 148)), kb))
	_save("ui_button_gold", Cut.scale(_piece(UI, Rect2i(468, 360, 412, 148)), kb))
	_save("ui_button_gold_pressed", Cut.scale(_piece(UI, Rect2i(464, 512, 420, 148)), kb))
	var round := Cut.scale(_piece(UI, Rect2i(188, 680, 204, 204)), 0.36)
	_save("ui_button_round", round)
	var pressed: Image = round.duplicate()
	pressed.adjust_bcs(0.82, 1.0, 1.0)
	_save("ui_button_round_pressed", pressed)
	var poster := _piece(UI, Rect2i(892, 332, 400, 520))
	_erase_frame_box(poster)  # the text runs the poster's full width
	var p := Cut.scale(poster, 0.46)
	_save("ui_poster", p)
	var dark: Image = p.duplicate()
	dark.adjust_bcs(0.55, 1.0, 0.45)
	_save("ui_poster_locked", dark)
	_save("ui_stamp_captured", Cut.scale(_piece(UI, Rect2i(1288, 448, 484, 272), "all"), 0.64))
	for f in ["ui_panel", "ui_panel_small", "ui_parchment", "ui_button_wood", "ui_button_gold", "ui_button_round", "ui_stamp_captured"]:
		print("    %s %s" % [f, Image.load_from_file(ProjectSettings.globalize_path(OUT + f + ".png")).get_size()])


func _icons() -> void:
	_icon_pair("heart_full", Rect2i(68, 72, 256, 228), "heart_empty", Rect2i(360, 72, 248, 228), 0.41)
	_icon_pair("bullet_full", Rect2i(696, 60, 128, 244), "bullet_empty", Rect2i(936, 56, 140, 244), 0.38)
	_icon_pair("star_on", Rect2i(1156, 56, 248, 240), "star_off", Rect2i(1452, 56, 248, 244), 0.65)
	_save("ui_icon_lock", Cut.scale(_piece(ICONS, Rect2i(84, 352, 216, 272)), 0.27))
	_save("ui_coin", Cut.scale(_piece(ICONS, Rect2i(480, 640, 236, 240)), 0.31))
	var plaque := Cut.scale(_piece(ICONS, Rect2i(796, 672, 476, 168)), 0.32)
	_save("ui_plaque", plaque)
	var plaque_dark: Image = plaque.duplicate()
	plaque_dark.adjust_bcs(0.8, 1.0, 1.0)
	_save("ui_plaque_pressed", plaque_dark)
	var plaque_soon: Image = plaque.duplicate()
	plaque_soon.adjust_bcs(0.7, 1.0, 0.35)
	_save("ui_plaque_soon", plaque_soon)
	var k := 88.0 / 248.0
	var pause := _outlined(Cut.scale(_piece(ICONS, Rect2i(348, 368, 248, 256)), k))
	_save("ui_icon_pause", pause)
	var restart := _outlined(Cut.scale(_piece(ICONS, Rect2i(1184, 384, 228, 232)), k))
	_save("ui_icon_restart", restart)
	var sound := _outlined(Cut.scale(_piece(ICONS, Rect2i(628, 384, 248, 224), "all"), k))
	_save("ui_icon_sound_on", sound)
	_save("ui_icon_sound_off", _slashed(sound))
	var music := _outlined(Cut.scale(_piece(ICONS, Rect2i(908, 376, 216, 232)), k))
	_save("ui_icon_music", music)
	_save("ui_icon_music_off", _slashed(music))
	for f in ["ui_heart_full", "ui_bullet_full", "ui_star_on", "ui_icon_lock", "ui_coin", "ui_plaque", "ui_icon_pause", "ui_icon_sound_on", "ui_icon_music"]:
		print("    %s %s" % [f, Image.load_from_file(ProjectSettings.globalize_path(OUT + f + ".png")).get_size()])


## Two icons that swap in place (full and empty) on canvases of the same size, centred.
func _icon_pair(a: String, box_a: Rect2i, b: String, box_b: Rect2i, k: float) -> void:
	var ia := Cut.scale(_piece(ICONS, box_a), k)
	var ib := Cut.scale(_piece(ICONS, box_b), k)
	var size := Vector2i(maxi(ia.get_width(), ib.get_width()), maxi(ia.get_height(), ib.get_height()))
	_save("ui_" + a, _pad(ia, size, ia.get_size() / 2, size / 2))
	_save("ui_" + b, _pad(ib, size, ib.get_size() / 2, size / 2))


## A copper icon with a light cream outline and a little brightening, so it stands out on wood.
static func _outlined(im: Image, r := 3) -> Image:
	var w := im.get_width() + r * 2
	var h := im.get_height() + r * 2
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := 0.0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > r * r:
						continue
					var sx := x - r + dx
					var sy := y - r + dy
					if sx >= 0 and sy >= 0 and sx < im.get_width() and sy < im.get_height():
						a = maxf(a, im.get_pixel(sx, sy).a)
			if a > 0:
				out.set_pixel(x, y, Color(1.0, 0.93, 0.78, a * 0.9))
	var lit: Image = im.duplicate()
	lit.adjust_bcs(1.15, 1.05, 1.0)
	out.blend_rect(lit, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(r, r))
	return out


## The off state: a red slash with a dark edge across the icon, top-left to bottom-right.
static func _slashed(im: Image) -> Image:
	var out: Image = im.duplicate()
	var w := out.get_width()
	var h := out.get_height()
	var a := Vector2(w * 0.14, h * 0.14)
	var b := Vector2(w * 0.86, h * 0.86)
	var half := w * 0.065
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0, 1)
			var d := p.distance_to(a + (b - a) * t)
			if d > half + 2.5:
				continue
			var col := Color(0.78, 0.1, 0.07) if d < half else Color(0.25, 0.03, 0.02)
			var alpha := clampf(half + 2.5 - d, 0, 1)
			out.set_pixel(x, y, out.get_pixel(x, y).blend(Color(col, alpha)))
	return out


## Paints out the thin box printed under WANTED (for a photo) with the paper just outside each line.
static func _erase_frame_box(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var dark := func(x: int, y: int) -> bool: return im.get_pixel(x, y).get_luminance() < 0.42 and im.get_pixel(x, y).a > 0.9
	var cols: Array[int] = []
	for x in w:
		var n := 0
		for y in range(int(h * 0.4), int(h * 0.75)):
			if dark.call(x, y):
				n += 1
		if n > h * 0.3:
			cols.append(x)
	var rows: Array[int] = []
	for y in range(int(h * 0.2), h):
		var n := 0
		for x in range(int(w * 0.3), int(w * 0.7)):
			if dark.call(x, y):
				n += 1
		if n > w * 0.36:
			rows.append(y)
	if cols.is_empty() or rows.is_empty():
		return
	var box := Rect2i(cols[0], rows[0], cols[-1] - cols[0] + 1, rows[-1] - rows[0] + 1)
	var src: Image = im.duplicate()
	for y in range(box.position.y - 2, box.end.y + 2):
		for x in range(box.position.x - 2, box.end.x + 2):
			var near_v := mini(absi(x - box.position.x), absi(x - box.end.x + 1))
			var near_h := mini(absi(y - box.position.y), absi(y - box.end.y + 1))
			if mini(near_v, near_h) > 4:
				continue
			var off := Vector2i.ZERO  # towards the paper outside the box
			if near_v <= near_h:
				off.x = -9 if absi(x - box.position.x) <= 4 else 9
			else:
				off.y = -9 if absi(y - box.position.y) <= 4 else 9
			var q := Vector2i(x, y) + off
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				im.set_pixel(x, y, src.get_pixel(q.x, q.y))
	print("    poster box erased at %s" % box)
