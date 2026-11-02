extends SceneTree
## Generates the UI art of the approved mockup (port_kit/high-noon-port-kit/style/ui-reference) into
## assets/ui_art, the way the mockup built it (high_noon_ui_reference.py): rough shapes are polygons whose
## points are nudged inward at random (fixed seeds, so every run gives the same art), with a dark brown
## outline shape behind a coloured face, hard drop shadows straight down, and buttons with a darker
## base the face sinks into when pressed. Re-run after changing a colour or a size here:
##   Godot --headless --path . -s res://tools/make_ui_art.gd
## Each shape is written as SVG and rasterised to PNG at SCALE times its design size (sharp on iPhone; the
## game draws them at half their pixel size). Icons are written as SVG files (Godot imports them sharp).
##   panel_cream, panel_strip    the torn parchment card and the pause menu's tall strip (nine-slices)
##   pill_<orange|teal>_<up|down>  the pill button, raised and pressed (nine-slices); pill_*_face/base
##   round_<orange|teal>_<up|down> the round button, raised and pressed; round_*_face/base
##   chip_teal, tag_cream, tag_orange  small torn slabs (nine-slices)
##   badge_teal, tack           the level-number badge and the brass tack
##   heart_full/empty, bullet_full/empty, star_on/off, coin
##   icons/<pause|play|restart|sound|sound_off|music|music_off|haptics|haptics_off|home|levels|lock|lock_ink>.svg

const OUT := "res://assets/ui_art/"
const SCALE := 2.0

const INK := "#3B2416"
const CREAM := "#F7E8C8"
const CREAM_D := "#E6CB98"
const ORANGE := "#F08A24"
const ORANGE_HI := "#FFB861"
const ORANGE_LO := "#A9511A"
const TEAL := "#2E7A80"
const TEAL_HI := "#4FA5A6"
const TEAL_LO := "#1C4F54"
const GOLD := "#FFC83D"
const RED := "#D9342B"
const BRASS := "#C9A04A"

## Sizes in design pixels (the game's 720-pixel-tall screen).
const PANEL := Vector2(600, 300)
const STRIP := Vector2(150, 660)
const PILL := Vector2(320, 96)
const ROUND := 96.0
const SLAB := Vector2(200, 58)
const BADGE := 92.0

var _manifest: Array[String] = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "icons"))
	_panel("panel_cream", PANEL, 11, 6, 8, CREAM)
	_panel("panel_strip", STRIP, 23, 6, 8, CREAM)
	for kind in ["orange", "teal"]:
		_pill(kind, 31 if kind == "orange" else 41)
		_round(kind, 51 if kind == "orange" else 61)
	_slab("chip_teal", SLAB, 71, TEAL)
	_slab("tag_cream", SLAB, 81, CREAM)
	_slab("tag_orange", SLAB, 91, ORANGE)
	_badge()
	_tack()
	_hud_art()
	_icons()
	print("UI art written to ", OUT, ":\n  ", "\n  ".join(_manifest))
	quit()


# ---------- the mockup's rough shapes (in pixels of a w x h box) ----------

## A rough rectangle: points along the edges (every `step` pixels, give or take 40%), each nudged inward
## at random by up to `jit` pixels. (The mockup gave both in % of each side; pixels keep the long and short
## edges equally rough once the shape is stretched as a nine-slice.)
static func torn(seed: int, w: float, h: float, jit := 7.0, step := 22.0) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, r.randf_range(0, jit)))
		x += r.randf_range(step * 0.6, step * 1.4)
	var y := 0.0
	while y < h:
		pts.append(Vector2(w - r.randf_range(0, jit), y))
		y += r.randf_range(step * 0.6, step * 1.4)
	x = w
	while x > 0:
		pts.append(Vector2(x, h - r.randf_range(0, jit)))
		x -= r.randf_range(step * 0.6, step * 1.4)
	y = h
	while y > 0:
		pts.append(Vector2(r.randf_range(0, jit), y))
		y -= r.randf_range(step * 0.6, step * 1.4)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(clampf(p.x, 0, w), clampf(p.y, 0, h)))
	return out


static func rough_ellipse(seed: int, w: float, h: float, n := 26, jit := 0.035) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 - r.randf_range(0, jit)
		out.append(Vector2(w / 2 + w / 2 * k * cos(a), h / 2 + h / 2 * k * sin(a)))
	return out


## A stadium in a w x h box with a small random wobble.
static func rough_pill(seed: int, w: float, h: float, jit := 1.2) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var rad := h / 2
	var pts := PackedVector2Array()
	for i in 14:  # right cap
		var a := -PI / 2 + PI * i / 13
		pts.append(Vector2(w - rad + rad * cos(a), rad + rad * sin(a)))
	var x := w - rad
	while x > rad:  # bottom edge
		pts.append(Vector2(x, h))
		x -= w / 9
	for i in 14:  # left cap
		var a := PI / 2 + PI * i / 13
		pts.append(Vector2(rad + rad * cos(a), rad + rad * sin(a)))
	x = rad
	while x < w - rad:  # top edge
		pts.append(Vector2(x, 0))
		x += w / 9
	var out := PackedVector2Array()
	for p in pts:
		var k := 1.0 - r.randf_range(0, jit) / 100.0 * 2.0
		out.append(Vector2(w / 2, h / 2) + (p - Vector2(w / 2, h / 2)) * k)
	return out


# ---------- SVG ----------

static func poly(pts: PackedVector2Array, fill: String, at := Vector2.ZERO, opacity := 1.0) -> String:
	var s := PackedStringArray()
	for p in pts:
		s.append("%.2f,%.2f" % [p.x + at.x, p.y + at.y])
	return '<polygon points="%s" fill="%s" fill-opacity="%.2f"/>' % [" ".join(s), fill, opacity]


func _svg(w: float, h: float, body: String, vb := Vector2.ZERO) -> String:
	var v := vb if vb != Vector2.ZERO else Vector2(w, h)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s">%s</svg>' % [
		ceili(w), ceili(h), str(v.x), str(v.y), body]


func _save(name: String, svg: String) -> void:
	var im := Image.new()
	var err := im.load_svg_from_string(svg, SCALE)
	assert(err == OK, "could not rasterise " + name)
	im.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	_manifest.append("%s.png  %dx%d" % [name, im.get_width(), im.get_height()])


# ---------- the pieces ----------

## The torn parchment: a dark outline shape, the cream face inset `pad`, a hard shadow `drop` below.
func _panel(name: String, size: Vector2, seed: int, pad: float, drop: float, fill: String) -> void:
	var o := torn(seed, size.x, size.y)
	var i := torn(seed + 101, size.x - pad * 2, size.y - pad * 2)
	var body := poly(o, INK, Vector2(0, drop), 0.55) + poly(o, INK) + poly(i, fill, Vector2(pad, pad))
	_save(name, _svg(size.x, size.y + drop, body))


func _colours(kind: String) -> Array:
	return [ORANGE, ORANGE_HI, ORANGE_LO] if kind == "orange" else [TEAL, TEAL_HI, TEAL_LO]


## The pill button: its darker base, and the face raised above it (up) or sunk into it (down).
func _pill(kind: String, seed: int) -> void:
	var c := _colours(kind)
	var w := PILL.x
	var h := PILL.y
	var depth := maxf(6.0, roundf(h * 0.1))
	var p1 := rough_pill(seed, w, h)
	var p2 := rough_pill(seed + 3, w - 10, h - 10)
	var p3 := rough_pill(seed + 5, w - 10, h - 10 - depth)
	var hi := '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" fill-opacity="0.9"/>'
	var stripe := func(dy: float) -> String: return hi % [h * 0.45, h * 0.13 + dy, w - h * 0.9, h * 0.14, h * 0.07, c[1]]
	var base := poly(p1, INK, Vector2(0, depth)) + poly(p1, INK) + poly(p2, c[2], Vector2(5, 5))
	var up: String = base + poly(p3, c[0], Vector2(5, 5)) + stripe.call(0.0)
	var down: String = poly(p1, INK, Vector2(0, depth)) + poly(p2, c[2], Vector2(5, 5 + depth)) + poly(p2, c[0], Vector2(5, 5 + depth)) + stripe.call(depth)
	_save("pill_%s_up" % kind, _svg(w, h + depth, up))
	_save("pill_%s_down" % kind, _svg(w, h + depth, down))
	_save("pill_%s_base" % kind, _svg(w, h + depth, base))
	_save("pill_%s_face" % kind, _svg(w, h + depth, poly(p3, c[0], Vector2(5, 5)) + stripe.call(0.0)))


## The round button, like the pill: base, and face up or sunk.
func _round(kind: String, seed: int) -> void:
	var c := _colours(kind)
	var s := ROUND
	var depth := maxf(5.0, roundf(s * 0.08))
	var c1 := rough_ellipse(seed, s, s)
	var c2 := rough_ellipse(seed + 7, s - 10, s - 10)
	var c3 := rough_ellipse(seed + 13, s - 10, s - 10 - depth)
	var hi := '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" fill-opacity="0.9"/>'
	var gleam := func(dy: float) -> String: return hi % [s * 0.5, s * 0.19 + dy, s * 0.26, s * 0.07, c[1]]
	var base := poly(c1, INK, Vector2(0, depth)) + poly(c1, INK) + poly(c2, c[2], Vector2(5, 5))
	var up: String = base + poly(c3, c[0], Vector2(5, 5)) + gleam.call(0.0)
	var down: String = poly(c1, INK, Vector2(0, depth)) + poly(c2, c[2], Vector2(5, 5 + depth)) + poly(c2, c[0], Vector2(5, 5 + depth)) + gleam.call(depth)
	_save("round_%s_up" % kind, _svg(s, s + depth, up))
	_save("round_%s_down" % kind, _svg(s, s + depth, down))
	_save("round_%s_base" % kind, _svg(s, s + depth, base))
	_save("round_%s_face" % kind, _svg(s, s + depth, poly(c3, c[0], Vector2(5, 5)) + gleam.call(0.0)))


## A small torn slab (chips and paper tags): dark outline, coloured face, a short hard shadow.
func _slab(name: String, size: Vector2, seed: int, fill: String) -> void:
	var drop := 4.0
	var o := torn(seed, size.x, size.y, 4.5, 14)
	var i := torn(seed + 9, size.x - 8, size.y - 8, 4.5, 14)
	_save(name, _svg(size.x, size.y + drop, poly(o, INK, Vector2(0, drop), 0.5) + poly(o, INK) + poly(i, fill, Vector2(4, 4))))


func _badge() -> void:
	var s := BADGE
	var o := rough_ellipse(101, s, s)
	var i := rough_ellipse(108, s - 12, s - 12)
	var gleam := '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" fill-opacity="0.8"/>' % [s * 0.5, s * 0.22, s * 0.24, s * 0.06, TEAL_HI]
	_save("badge_teal", _svg(s, s + 6, poly(o, INK, Vector2(0, 6), 0.55) + poly(o, INK) + poly(i, TEAL, Vector2(6, 6)) + gleam))


func _tack() -> void:
	var body := ('<circle cx="15" cy="18" r="12" fill="%s" fill-opacity="0.55"/>' % INK
		+ '<circle cx="15" cy="15" r="12" fill="%s"/><circle cx="15" cy="15" r="9" fill="%s"/>' % [INK, BRASS]
		+ '<ellipse cx="12" cy="11.5" rx="3.6" ry="2.2" fill="#F3D88A"/>')
	_save("tack", _svg(30, 30, body))


## Hearts, bullets, stars and the coin, outlined, each with a hard shadow below; empty states too.
func _hud_art() -> void:
	const HEART := 'M12 21s-8.5-5.3-8.5-11.2C3.5 6.6 5.9 4.5 8.5 4.5c1.6 0 2.8.8 3.5 2 .7-1.2 1.9-2 3.5-2 2.6 0 5 2.1 5 5.3C20.5 15.7 12 21 12 21z'
	const STAR := 'M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6-4.9-4.6 6.6-.8z'
	for full in [true, false]:
		var fill := RED if full else INK
		var op := 1.0 if full else 0.25
		var body := ('<path d="%s" transform="translate(0 1.2)" fill="%s" fill-opacity="0.6"/>' % [HEART, INK]
			+ '<path d="%s" fill="%s" fill-opacity="%.2f" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % [HEART, fill, op, INK]
			+ ('<path d="M7.5 8.2c.6-1.1 1.6-1.5 2.4-1.4" fill="none" stroke="#FFB3A8" stroke-width="1.6" stroke-linecap="round"/>' if full else ""))
		_save("heart_" + ("full" if full else "empty"), _svg(48, 52, body, Vector2(24, 26)))
	for on in [true, false]:
		var body := ('<path d="%s" transform="translate(0 1.5)" fill="%s" fill-opacity="0.6"/>' % [STAR, INK]
			+ '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % [STAR, GOLD if on else "#C9B48D", INK]
			+ ('<path d="M9.2 9.6l1.6-.2" fill="none" stroke="#FFF1B8" stroke-width="1.3" stroke-linecap="round"/>' if on else ""))
		_save("star_" + ("on" if on else "off"), _svg(96, 102, body, Vector2(24, 25.5)))
	for loaded in [true, false]:
		var b := "#E2A63A" if loaded else INK
		var t := "#C9883A" if loaded else INK
		var op := 1.0 if loaded else 0.25
		var body := ('<g transform="translate(0 1)" fill="%s" fill-opacity="0.6"><path d="M2 10C2 5 3.5 1.5 5 1.5S8 5 8 10z"/><rect x="1.5" y="10" width="7" height="12.5" rx="1"/></g>' % INK
			+ '<path d="M2 10C2 5 3.5 1.5 5 1.5S8 5 8 10z" fill="%s" fill-opacity="%.2f" stroke="%s" stroke-width="1.4" stroke-linejoin="round"/>' % [t, op * 0.6 if not loaded else 1.0, INK]
			+ '<rect x="1.5" y="10" width="7" height="12.5" rx="1" fill="%s" fill-opacity="%.2f" stroke="%s" stroke-width="1.4"/>' % [b, op, INK]
			+ ('<path d="M3 12v8" stroke="#FFE3A3" stroke-width="1.1" stroke-linecap="round" fill="none"/>' if loaded else ""))
		_save("bullet_" + ("full" if loaded else "empty"), _svg(24, 59, body, Vector2(10, 24.5)))
	var coin := ('<circle cx="12" cy="13" r="10" fill="%s" fill-opacity="0.6"/>' % INK
		+ '<circle cx="12" cy="12" r="10" fill="%s" stroke="%s" stroke-width="1.8"/>' % [GOLD, INK]
		+ '<circle cx="12" cy="12" r="6.6" fill="none" stroke="#C98A16" stroke-width="1.4"/>'
		+ '<path d="M12 8v8M14.2 9.6c-.5-.7-1.3-1-2.2-1-1.2 0-2.1.6-2.1 1.6 0 2.2 4.4 1.2 4.4 3.5 0 1-1 1.7-2.3 1.7-1 0-1.8-.4-2.3-1.1" fill="none" stroke="#9A6510" stroke-width="1.5" stroke-linecap="round"/>')
	_save("coin", _svg(96, 100, coin, Vector2(24, 25)))


## The control icons, as SVG files (the mockup's paths): cream strokes for the round buttons, ink for tags.
func _icons() -> void:
	var paths := {
		"pause": '<path d="M8 5v14M16 5v14"/>',
		"play": '<path d="M8 4.5l11 7.5-11 7.5z" fill="%s"/>' % CREAM,
		"restart": '<path d="M5 12a7 7 0 1 0 2.3-5.2"/><path d="M6 3v4.5h4.5"/>',
		"sound": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11"/>',
		"sound_off": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
		"music": '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
		"music_off": '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/><path d="M3 3l18 18"/>',
		"haptics": '<rect x="8" y="4" width="8" height="16" rx="2"/><path d="M4 9v6M20 9v6"/>',
		"haptics_off": '<rect x="8" y="4" width="8" height="16" rx="2"/><path d="M3 3l18 18"/>',
		"home": '<path d="M4 11l8-7 8 7"/><path d="M6.5 9.5V20h11V9.5"/>',
		"levels": '<rect x="4.5" y="4.5" width="6" height="6" rx="1"/><rect x="13.5" y="4.5" width="6" height="6" rx="1"/><rect x="4.5" y="13.5" width="6" height="6" rx="1"/><rect x="13.5" y="13.5" width="6" height="6" rx="1"/>',
		"lock": '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
	}
	for n in paths:
		_icon(n, paths[n], CREAM, 3.0)
	_icon("lock_ink", paths.lock, INK, 2.6)


func _icon(name: String, body: String, colour: String, width: float) -> void:
	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24" fill="none" stroke="%s" '
		+ 'stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round">%s</svg>') % [colour, width, body]
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "icons/" + name + ".svg"), FileAccess.WRITE)
	f.store_string(svg)
	f.close()
	_manifest.append("icons/%s.svg" % name)
