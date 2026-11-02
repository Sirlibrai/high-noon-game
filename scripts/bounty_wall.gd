class_name BountyWall
extends Control
## The Bounty board: the office notice board's cork filling the screen, its wooden frame along the
## top and bottom, with the wanted posters pinned to it by brass tacks, side by side, about 80% of the
## screen tall. A lantern's warm pool of light falls on the middle of the screen and the edges fade
## into shadow, so the centred poster is the brightest. Swipe sideways along the board; it snaps to a
## poster, and never shows bare cork before the first poster or after the last. It opens with the
## current hunt centred (as near as those ends allow). Tapping a poster that can be hunted emits
## `chosen`. Main adds the Home button and the Bounty Dollars in the corners.

signal chosen(index: int)

## Poster size and spacing, in screen pixels (720 tall).
const POSTER := Vector2(372, 568)
const GAP := 64.0
## The portrait spans almost the poster's width and about half its height, right under WANTED.
const PORTRAIT := Vector2(328, 246)
## Names are condensed: their line is squeezed to this much of its width (letters and spacing alike).
const CONDENSE := 0.8
const TILTS := [-1.2, 0.8, -0.6, 1.1, -0.9]
## Brass tacks: one at each corner of a poster, over the paper's own nail holes.
const TACKS := [Vector2(39.5, 38.5), Vector2(339.5, 38.5), Vector2(41.5, 532), Vector2(331, 530)]
## The frame rails, top and bottom (their art's height), and the bare cork kept beside the first and
## last posters (past the safe area) when the board is at either end.
const RAIL_H := 54.0
const EDGE := 28.0
## How far (pixels) a finger may move and still count as a tap, and how hard a flick must be
## (pixels a second) to move on a poster without dragging halfway.
const TAP_SLOP := 14.0
const FLICK := 700.0

## The safe area's insets (left, right, bottom) in screen pixels, set by Main before it is added.
var safe_lrb := Vector3.ZERO
var posters: Array[Button] = []
var scroll := 0.0  # the board's offset: poster i is centred when scroll is i * step()
var target := 0.0
var _cork: TextureRect
var _rails: Array[TextureRect] = []
var _strip: Control
var _light: ColorRect
var _drag := {"on": false, "from": Vector2.ZERO, "scroll": 0.0, "moved": false, "v": 0.0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_cork = _tiled("wall/cork")
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_light = ColorRect.new()
	_light.material = ShaderMaterial.new()
	_light.material.shader = load("res://ui/board_light.gdshader")
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_light)
	for k in 2:  # the frame's rails, over the light's vignette (shaded, but always visible)
		var r := _tiled("wall/rail")
		r.modulate = Color(0.8, 0.72, 0.64)
		var lip := ColorRect.new()  # the dark edge where the rail meets the cork
		lip.color = Color(0.2, 0.09, 0.03)
		lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lip.size = Vector2(1, 3)
		lip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if k == 0 else Control.PRESET_TOP_WIDE)
		r.add_child(lip)
		lip.offset_top = -3 if k == 0 else 0
		lip.offset_bottom = 0 if k == 0 else 3
		_rails.append(r)
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
	for i in GameState.chapters.size():
		var p := poster(i, GameState.poster_state(pg, i, pt), pg)
		p.position = Vector2(i * step(), 0)
		p.pivot_offset = POSTER / 2
		p.rotation = deg_to_rad(TILTS[i % TILTS.size()])
		_strip.add_child(p)
		posters.append(p)
	show_poster(GameState.current_hunt(pg, pt))


func _tiled(asset: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.texture(asset)
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


static func step() -> float:
	return POSTER.x + GAP


func _vis() -> Vector2:
	return size if size.x > 0 else get_viewport_rect().size


## The scroll range: at the start the first poster's left edge sits EDGE past the safe area's left
## edge; at the end the last poster's right edge sits EDGE inside its right edge.
func scroll_range() -> Vector2:
	var vis := _vis()
	var lo := vis.x / 2 - POSTER.x / 2 - safe_lrb.x - EDGE
	var hi := (posters.size() - 1) * step() - (vis.x / 2 - POSTER.x / 2 - safe_lrb.y - EDGE)
	if hi < lo:  # a screen wide enough for every poster: centre the row
		return Vector2.ONE * ((posters.size() - 1) * step() / 2)
	return Vector2(lo, hi)


## Where the board can come to rest: its two ends, and each poster centred between them (a poster
## whose centre is within half a poster of an end rests at that end).
func stops() -> Array[float]:
	var r := scroll_range()
	var out: Array[float] = [r.x]
	for i in posters.size():
		var s := i * step()
		if s > r.x + step() / 2 and s < r.y - step() / 2:
			out.append(s)
	if r.y > r.x:
		out.append(r.y)
	return out


## The poster nearest the middle of the screen.
func centred() -> int:
	return clampi(roundi(scroll / step()), 0, posters.size() - 1)


func _place() -> void:
	var vis := _vis()
	_strip.position = Vector2(vis.x / 2 - POSTER.x / 2 - scroll, RAIL_H + (vis.y - RAIL_H * 2 - POSTER.y) / 2)
	var tile := _cork.texture.get_size()
	_cork.position = Vector2(-fposmod(scroll, tile.x), RAIL_H - tile.y / 2)  # the cork moves with the posters pinned to it
	_cork.size = Vector2(vis.x + tile.x * 2, vis.y + tile.y)
	var rw := float(_rails[0].texture.get_width())
	for k in 2:
		_rails[k].position = Vector2(-fposmod(scroll, rw), 0.0 if k == 0 else vis.y - RAIL_H)
		_rails[k].size = Vector2(vis.x + rw * 2, RAIL_H)
	_light.size = vis


func _process(delta: float) -> void:
	if not _drag.on:
		scroll += (target - scroll) * minf(1.0, delta * 12.0)
		if absf(target - scroll) < 0.5:
			scroll = target
	_place()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = {"on": true, "from": event.position, "scroll": scroll, "moved": false, "v": 0.0}
		elif _drag.on:
			_drag.on = false
			if not _drag.moved:
				_tap(event.position)
			else:
				snap(_drag.v)
		accept_event()
	elif event is InputEventMouseMotion and _drag.on:
		var dx: float = event.position.x - _drag.from.x
		if absf(dx) > TAP_SLOP:
			_drag.moved = true
		_drag.v = event.velocity.x  # pixels a second, as the finger moves
		var want: float = _drag.scroll - dx
		var r := scroll_range()
		if want < r.x:  # a little give past either end
			want = r.x + (want - r.x) * 0.35
		elif want > r.y:
			want = r.y + (want - r.y) * 0.35
		scroll = want
		accept_event()


## Lets go of the board: it settles on the nearest stop, or the next one along after a flick.
func snap(velocity := 0.0) -> void:
	var s := stops()
	var near := 0
	for k in s.size():
		if absf(s[k] - scroll) < absf(s[near] - scroll):
			near = k
	if absf(velocity) > FLICK:
		var from := 0
		for k in s.size():
			if absf(s[k] - _drag.scroll) < absf(s[from] - _drag.scroll):
				from = k
		near = clampi(from + (-1 if velocity > 0 else 1), 0, s.size() - 1)
	target = s[near]


func _tap(at: Vector2) -> void:
	for i in posters.size():
		var p := posters[i]
		if p.get_global_rect().has_point(get_global_transform() * at) and not p.disabled:
			chosen.emit(i)
			return


## Moves the board at once to poster i, centred as near as the ends allow (on opening, for tests, and
## for coming back from a hunt screen).
func show_poster(i: int) -> void:
	var want := clampi(i, 0, posters.size() - 1) * step()
	var s := stops()
	var near := 0
	for k in s.size():
		if absf(s[k] - want) < absf(s[near] - want):
			near = k
	scroll = s[near]
	target = scroll
	_place()


## One wanted poster: WANTED (in the art), a wide portrait right under it, the outlaw's name in big,
## heavy, condensed slab capitals filling the width, a one-line title in small capitals, the reward
## large on a red banner, and small star progress under it once the bounty is started. Pinned with
## brass tacks. Stamps: CAPTURED in red across the portrait, a padlock while locked, COMING SOON in
## dark faded ink. J.R. shows his silhouette until he can be hunted.
static func poster(i: int, state: String, pg: Dictionary) -> Button:
	var ch: Dictionary = GameState.chapters[i]
	var open := state == "open" or state == "captured"
	var b := Button.new()
	b.theme = load(Assets.THEME)
	b.theme_type_variation = &"WallPoster"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the board takes the taps (and tells a tap from a swipe)
	b.disabled = not open
	b.size = POSTER
	b.custom_minimum_size = POSTER
	b.tooltip_text = "%s, %s, %s" % [ch.poster_name, ch.title, ch.reward]
	var sb: StyleBox = b.theme.get_stylebox("normal", &"WallPoster")
	var inner := POSTER.x - sb.content_margin_left - sb.content_margin_right
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.position = Vector2(sb.content_margin_left, sb.content_margin_top)
	v.size = Vector2(inner, POSTER.y - sb.content_margin_top - sb.content_margin_bottom)
	b.add_child(v)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"PortraitFrame"
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	var side: float = b.theme.get_stylebox("panel", &"PortraitFrame").content_margin_left
	var pic := UiKit.image(frame, portrait_for(i, open), PORTRAIT - Vector2(side, side) * 2)
	if not open and not Assets.has("portrait_wide/ch%d_locked" % i):
		pic.modulate = Color(0.45, 0.4, 0.38)
	var holder := Control.new()  # the squeezed name, centred in the column
	v.add_child(holder)
	var name := UiKit.text(holder, str(ch.poster_name).to_upper(), &"PosterBigName")
	var nfs := fit(name, inner / CONDENSE, b.theme)
	var nfont := b.theme.get_font("font", &"PosterBigName")
	var nsz := Vector2(nfont.get_string_size(name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x, nfont.get_height(nfs))  # measured from the theme: it isn't on screen yet
	name.size = nsz
	name.scale.x = CONDENSE
	name.position.x = (inner - nsz.x * CONDENSE) / 2
	holder.custom_minimum_size = Vector2(inner, nsz.y)
	UiKit.text(v, str(ch.title).to_upper(), &"PosterTitle")
	var banner_row := UiKit.row(v)
	var banner := PanelContainer.new()
	banner.theme_type_variation = &"RewardBanner"
	banner_row.add_child(banner)
	UiKit.text(banner, ch.reward, &"RewardLabel")
	var got := GameState.chapter_stars(pg, i) if open else 0
	if got > 0:  # started: small star progress under the banner
		var stars := UiKit.row(v)
		UiKit.image(stars, "ui/star_on", Vector2(20, 20))
		UiKit.text(stars, "%d / %d" % [got, GameState.levels_for(i).size() * 3], &"PosterStars")
	for at in TACKS:
		var t := UiKit.image(b, "poster/tack")
		t.position = at - Assets.anchor("poster/tack")  # centred on the paper's nail hole
	for c in b.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state != "open":
		var stamp: Control
		var tilt := -12.0
		match state:
			"captured":
				stamp = UiKit.image(b, "ui/stamp_captured", Vector2(POSTER.x * 0.8, POSTER.x * 0.44))
			"locked":
				stamp = UiKit.image(b, "ui/icon_lock", Vector2(84, 104))
				tilt = 0.0
			_:
				stamp = PanelContainer.new()
				stamp.theme_type_variation = &"StampFaded"
				stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				UiKit.text(stamp, "COMING SOON", &"StampFadedLabel")
				b.add_child(stamp)
		var sz := stamp.get_combined_minimum_size()
		stamp.size = sz
		stamp.position = Vector2((POSTER.x - sz.x) / 2, sb.content_margin_top + PORTRAIT.y / 2 - sz.y / 2)  # across the portrait
		stamp.pivot_offset = sz / 2
		stamp.rotation = deg_to_rad(tilt)
		b.set_meta("stamp", stamp)
	return b


## The wide portrait: J.R.'s silhouette until he can be hunted, then his face.
static func portrait_for(i: int, open: bool) -> String:
	var dark := "portrait_wide/ch%d_locked" % i
	return dark if not open and Assets.has(dark) else "portrait_wide/ch%d" % i


## Sizes a label's font so its text fits `width` on one line: the theme's size (as big as the poster's
## height allows) for short names, smaller for long ones. Measured with the theme, before it is on screen.
static func fit(l: Label, width: float, theme: Theme) -> int:
	var font := theme.get_font("font", l.theme_type_variation)
	var fs := theme.get_font_size("font_size", l.theme_type_variation)
	while fs > 22 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	return fs
