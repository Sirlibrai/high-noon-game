extends SceneTree
## Draws the Bounty board's plank wall in the game's cartoon style (flat warm browns, dark seams, a few
## bold grain strokes, knots and nail heads, lit from the top left), as a 720-pixel-tall strip that
## tiles sideways, so the wall scrolls with the posters nailed to it:
##   Godot --headless --path . -s res://tools/make_wall.gd

const OUT := "res://assets/painted/wall_planks.png"
const H := 720
const PLANKS := [92, 104, 86, 98, 110, 90, 100, 88]  # widths; they add up to the tile's width
const BASES := ["#8E4A26", "#7E3F20", "#97532B", "#844422", "#8A4824", "#7A3C1E", "#93502A", "#80421F"]
const SEAM := Color("#3A1C0E")
const BEAM_Y := [0, 52]  # the cross-beam along the top


func _init() -> void:
	var w := 0
	for p in PLANKS:
		w += p
	var im := Image.create_empty(w, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1885
	var x0 := 0
	for i in PLANKS.size():
		var pw: int = PLANKS[i]
		var base := Color(BASES[i])
		var hi := base.lightened(0.16)
		var lo := base.darkened(0.18)
		for y in H:
			for x in pw:
				var c := base
				if x < 7:
					c = hi  # the lit left edge
				elif x > pw - 9:
					c = lo  # the shaded right edge
				im.set_pixel(x0 + x, y, c)
		# Grain: a few long bold strokes, gently wavy, in the plank's shadow colour.
		for s in 3 + rng.randi() % 2:
			var gx := 14.0 + rng.randf() * (pw - 30)
			var y_from := rng.randi_range(-100, H - 260)
			var length := rng.randi_range(160, 380)
			var phase := rng.randf() * TAU
			for y in range(maxi(0, y_from), mini(H, y_from + length)):
				var t := float(y - y_from) / length
				var thick := 1.0 + 1.6 * sin(t * PI)  # tapered ends
				var cx := gx + sin(y * 0.018 + phase) * 4.0
				for dx in range(-2, 3):
					var px := int(cx) + dx
					if absf(px - cx) <= thick * 0.5 and px > 8 and px < pw - 9:
						im.set_pixel(x0 + px, y, base.darkened(0.3))
		# A knot or two: dark ovals with a light ring.
		for k in rng.randi() % 2 + 1:
			var kc := Vector2(14 + rng.randf() * (pw - 28), 140 + rng.randf() * (H - 220))
			for y in range(int(kc.y) - 16, int(kc.y) + 17):
				for x in range(int(kc.x) - 10, int(kc.x) + 11):
					var d := Vector2((x - kc.x) / 9.0, (y - kc.y) / 15.0).length()
					if d < 1.0 and x > 8 and x < pw - 9:
						im.set_pixel(x0 + x, y, base.darkened(0.42) if d < 0.55 else base.lightened(0.1))
		# Seams: a dark outline down each side.
		for y in H:
			for x in [0, 1, 2, pw - 3, pw - 2, pw - 1]:
				im.set_pixel(x0 + x, y, SEAM)
		x0 += pw
	# The cross-beam along the top, with bolts on each plank.
	var beam := Color("#6E3519")
	for y in range(BEAM_Y[0], BEAM_Y[1]):
		for x in w:
			var c := beam.lightened(0.12) if y < BEAM_Y[0] + 8 else (beam.darkened(0.2) if y > BEAM_Y[1] - 9 else beam)
			im.set_pixel(x, y, c)
	for x in w:
		for y in [BEAM_Y[1], BEAM_Y[1] + 1, BEAM_Y[1] + 2, BEAM_Y[1] + 3]:
			im.set_pixel(x, y, SEAM)
	x0 = 0
	for pw in PLANKS:
		_nail(im, Vector2(x0 + pw / 2.0, BEAM_Y[1] / 2.0), 7.0)
		_nail(im, Vector2(x0 + pw / 2.0, H - 40), 5.0)
		x0 += pw
	im.save_png(ProjectSettings.globalize_path(OUT))
	print('    "wall/planks": {"frames": ["painted/wall_planks.png"], "anchor": "top_left"},  # %dx%d, tiles sideways' % [w, H])
	quit()


## A round iron nail head with a dark outline and a highlight.
static func _nail(im: Image, c: Vector2, r: float) -> void:
	for y in range(int(c.y - r - 2), int(c.y + r + 3)):
		for x in range(int(c.x - r - 2), int(c.x + r + 3)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r + 1.5 or x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
				continue
			var col := SEAM if d > r - 0.5 else (Color("#B07A4A") if Vector2(x - c.x, y - c.y).dot(Vector2(-1, -1)) > r * 0.6 else Color("#5E4636"))
			im.set_pixel(x, y, col)
