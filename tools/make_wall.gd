extends SceneTree
## Makes the Bounty board wall from the office's notice board (assets/painted/office.png), so the two
## match: a seamless cork tile (the board's cork, its lamp-light gradient evened out, mirrored so it
## repeats without seams), the board's wooden frame rail (repeating sideways, for the top and the
## bottom edge), and a brass tack (the board's corner bolt) for pinning the posters:
##   Godot --headless --path . -s res://tools/make_wall.gd

const OFFICE := "res://assets/painted/office.png"
const OUT := "res://assets/painted/"
const CORK := Rect2i(600, 196, 400, 220)  # inside the frame, clear of its edges
const RAIL := Rect2i(560, 138, 480, 27)  # the frame's top rail, between its corner blocks
const BOLT := Vector2(532, 152)  # a corner block's brass bolt, and its radius
const BOLT_R := 9.0
const CORK_K := 1.6  # drawn bigger than in the office: the wall is the whole screen
const RAIL_K := 2.0


func _init() -> void:
	var office := Image.load_from_file(ProjectSettings.globalize_path(OFFICE))
	office.convert(Image.FORMAT_RGBA8)
	var cork := _even(office.get_region(CORK))
	cork.resize(int(cork.get_width() * CORK_K), int(cork.get_height() * CORK_K), Image.INTERPOLATE_LANCZOS)
	_mirror_tile(cork).save_png(ProjectSettings.globalize_path(OUT + "wall_cork.png"))
	var rail := _even(office.get_region(RAIL), 8, RAIL.size.y)  # its shading across, without the lamp's glow along it
	rail.resize(int(rail.get_width() * RAIL_K), int(rail.get_height() * RAIL_K), Image.INTERPOLATE_LANCZOS)
	var wide := Image.create_empty(rail.get_width() * 2, rail.get_height(), false, Image.FORMAT_RGBA8)
	wide.blit_rect(rail, Rect2i(Vector2i.ZERO, rail.get_size()), Vector2i.ZERO)
	rail.flip_x()
	wide.blit_rect(rail, Rect2i(Vector2i.ZERO, rail.get_size()), Vector2i(rail.get_width(), 0))
	wide.save_png(ProjectSettings.globalize_path(OUT + "wall_rail.png"))
	_tack().save_png(ProjectSettings.globalize_path(OUT + "poster_tack.png"))
	print('    "wall/cork": "painted/wall_cork.png", "wall/rail": "painted/wall_rail.png" (%d px tall), "poster/tack": "painted/poster_tack.png"' % wide.get_height())
	quit()


## Evens out the painting's lighting (the lamp's warm pool) across the cork, keeping its grain:
## each pixel divided by a heavy blur of its surroundings, times the patch's mean colour.
static func _even(im: Image, cols := 6, rows := 3) -> Image:
	var small: Image = im.duplicate()
	small.resize(cols, rows, Image.INTERPOLATE_BILINEAR)
	var blur: Image = small.duplicate()
	blur.resize(im.get_width(), im.get_height(), Image.INTERPOLATE_BILINEAR)
	var mean := Color(0, 0, 0)
	for y in small.get_height():
		for x in small.get_width():
			mean += small.get_pixel(x, y)
	mean /= small.get_width() * small.get_height()
	var out: Image = im.duplicate()
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var b := blur.get_pixel(x, y)
			out.set_pixel(x, y, Color(c.r / b.r * mean.r, c.g / b.g * mean.g, c.b / b.b * mean.b))
	return out


## A 2x2 tile of the image and its mirror images: it repeats in both directions without seams.
static func _mirror_tile(im: Image) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var out := Image.create_empty(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for k in 4:
		var part: Image = im.duplicate()
		if k % 2 == 1:
			part.flip_x()
		if k >= 2:
			part.flip_y()
		out.blit_rect(part, Rect2i(0, 0, w, h), Vector2i(w * (k % 2), h * (k / 2)))
	return out


## A round brass tack like the board's corner bolts: a dark outline, a domed brass head lit from the top
## left, and a soft shadow below-right on the cork.
static func _tack() -> Image:
	var r := 15.0
	var size := int(r * 2 + 10)
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0 - 2, size / 2.0 - 2)
	var light := Color("#FFE49A")
	var brass := Color("#E3A12E")
	var deep := Color("#8A4C12")
	var ink := Color("#3A1E0A")
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var sd := p.distance_to(c + Vector2(3.5, 3.5))
			var col := Color(0.1, 0.05, 0.02, 0.4 * clampf(r + 1.5 - sd, 0, 1)) if sd < r + 1.5 else Color(0, 0, 0, 0)
			if d < r + 1.0:
				var q := (p - c) / r
				var t := clampf(q.dot(Vector2(0.7, 0.7)) * 0.5 + 0.5, 0, 1)  # 0 at the lit top left
				var body := brass.lerp(deep, smoothstep(0.45, 1.0, t)).lerp(light, smoothstep(0.42, 0.0, (q - Vector2(-0.35, -0.35)).length()))
				if d > r - 2.2:
					body = ink
				col = Color(body, clampf(r + 1.0 - d, 0, 1)) if col.a == 0 or d < r else col.blend(Color(body, clampf(r + 1.0 - d, 0, 1)))
			out.set_pixel(x, y, col)
	return out
