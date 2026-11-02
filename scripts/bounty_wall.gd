class_name BountyWall
extends Control
## The Bounty board: a full-screen plank wall with the wanted posters nailed straight onto it, side
## by side, about 80% of the screen tall. Swipe sideways along the wall; it snaps to the nearest
## poster, and opens on the current hunt, centred. Tapping a poster that can be hunted emits `chosen`.
## Main adds the Home button and the Bounty Dollars in the corners.

signal chosen(index: int)

## Poster size and spacing, in screen pixels (720 tall).
const POSTER := Vector2(372, 568)
const GAP := 64.0
const PORTRAIT := 214.0
const TILTS := [-1.2, 0.8, -0.6, 1.1, -0.9]
## How far (pixels) a finger may move and still count as a tap, and how hard a flick must be
## (pixels a second) to move on a poster without dragging halfway.
const TAP_SLOP := 14.0
const FLICK := 700.0

var posters: Array[Button] = []
var scroll := 0.0  # the wall's offset: poster i is centred when scroll is i * step()
var target := 0.0
var _wall: TextureRect
var _strip: Control
var _drag := {"on": false, "from": Vector2.ZERO, "scroll": 0.0, "moved": false, "v": 0.0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_wall = TextureRect.new()
	_wall.texture = Assets.texture("wall/planks")
	_wall.stretch_mode = TextureRect.STRETCH_TILE
	_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wall)
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
	for i in GameState.chapters.size():
		var p := poster(i, GameState.poster_state(pg, i, pt), pg)
		p.position = Vector2(i * step(), 0)
		p.pivot_offset = POSTER / 2
		p.rotation = deg_to_rad(TILTS[i % TILTS.size()])
		_strip.add_child(p)
		posters.append(p)
	scroll = GameState.current_hunt(pg, pt) * step()
	target = scroll
	_place()


static func step() -> float:
	return POSTER.x + GAP


func centred() -> int:
	return clampi(roundi(scroll / step()), 0, posters.size() - 1)


func _place() -> void:
	var vis := size if size.x > 0 else get_viewport_rect().size
	_strip.position = Vector2(vis.x / 2 - POSTER.x / 2 - scroll, vis.y * 0.535 - POSTER.y / 2)
	var tile := float(_wall.texture.get_width())
	_wall.position = Vector2(-fposmod(scroll, tile), 0)  # the planks move with the posters nailed to them
	_wall.size = Vector2(vis.x + tile * 2, vis.y)


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
		var last := (posters.size() - 1) * step()
		if want < 0:  # a little give past either end
			want *= 0.35
		elif want > last:
			want = last + (want - last) * 0.35
		scroll = want
		accept_event()


## Lets go of the wall: it settles on the nearest poster, or the next one along after a flick.
func snap(velocity := 0.0) -> void:
	var i := roundi(scroll / step())
	if absf(velocity) > FLICK:
		i = roundi(_drag.scroll / step()) + (-1 if velocity > 0 else 1)
	target = clampi(i, 0, posters.size() - 1) * step()


func _tap(at: Vector2) -> void:
	for i in posters.size():
		var p := posters[i]
		if p.get_global_rect().has_point(get_global_transform() * at) and not p.disabled:
			chosen.emit(i)
			return


## Moves the wall to centre poster i at once (for tests and for coming back from a hunt screen).
func show_poster(i: int) -> void:
	scroll = clampi(i, 0, posters.size() - 1) * step()
	target = scroll
	_place()


## One wanted poster: WANTED (in the art), a large portrait, the outlaw's name in big Rye lettering,
## a one-line title, and the reward on a red banner, with small star progress under it once the
## bounty is started. Stamps: CAPTURED in red across the portrait, a padlock while locked, COMING
## SOON in dark faded ink. J.R. shows his silhouette until he can be hunted.
static func poster(i: int, state: String, pg: Dictionary) -> Button:
	var ch: Dictionary = GameState.chapters[i]
	var open := state == "open" or state == "captured"
	var b := Button.new()
	b.theme = load(Assets.THEME)
	b.theme_type_variation = &"WallPoster"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the wall takes the taps (and tells a tap from a swipe)
	b.disabled = not open
	b.size = POSTER
	b.custom_minimum_size = POSTER
	b.tooltip_text = "%s, %s, %s" % [ch.poster_name, ch.title, ch.reward]
	var sb: StyleBox = b.theme.get_stylebox("normal", &"WallPoster")
	var inner := POSTER.x - sb.content_margin_left - sb.content_margin_right
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	v.position = Vector2(sb.content_margin_left, sb.content_margin_top)
	v.size = Vector2(inner, POSTER.y - sb.content_margin_top - sb.content_margin_bottom)
	b.add_child(v)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"PortraitFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	var pic := UiKit.image(frame, Office.portrait_for(i, open), Vector2(PORTRAIT, PORTRAIT))
	if not open and not Assets.has("portrait/ch%d_locked" % i):
		pic.modulate = Color(0.45, 0.4, 0.38)
	var name := UiKit.text(v, ch.poster_name, &"PosterBigName")
	_fit(name, inner)
	UiKit.text(v, "— %s —" % str(ch.title).to_upper(), &"PosterTitle")
	var banner_row := UiKit.row(v)
	var banner := PanelContainer.new()
	banner.theme_type_variation = &"RewardBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_row.add_child(banner)
	UiKit.text(banner, ch.reward, &"RewardLabel")
	var got := GameState.chapter_stars(pg, i) if open else 0
	if got > 0:  # started: small star progress under the banner
		var stars := UiKit.row(v)
		UiKit.image(stars, "ui/star_on", Vector2(20, 20))
		UiKit.text(stars, "%d / %d" % [got, GameState.levels_for(i).size() * 3], &"PosterStars")
	for c in v.find_children("*", "Control", true, false):
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
		stamp.position = Vector2((POSTER.x - sz.x) / 2, sb.content_margin_top + (PORTRAIT + 8) / 2 - sz.y / 2)  # across the portrait
		stamp.pivot_offset = sz / 2
		stamp.rotation = deg_to_rad(tilt)
		b.set_meta("stamp", stamp)
	return b


## Shrinks a label's font until its text fits on one line in `width`.
static func _fit(l: Label, width: float) -> void:
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	while fs > 22 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 2
	l.add_theme_font_size_override("font_size", fs)
