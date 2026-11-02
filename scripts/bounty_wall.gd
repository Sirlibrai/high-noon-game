class_name BountyWall
extends Control
## The Bounty board: the office notice board's cork filling the screen, its wooden frame along the
## top and bottom, with the painted wanted posters nailed to it side by side, about three quarters of
## the screen tall, each started bounty's star progress on the cork below it. A lantern's warm pool of light falls on the middle of the screen and the edges fade
## into shadow, so the centred poster is the brightest. Swipe sideways along the board; it snaps to a
## poster, and never shows bare cork before the first poster or after the last. It opens with the
## current hunt centred (as near as those ends allow). Tapping a poster that can be hunted emits
## `chosen`. Main adds the Home button and the Bounty Dollars in the corners.

signal chosen(index: int)

## Poster size and spacing, in screen pixels (720 tall). The painted posters are about 0.6 as wide as tall.
const POSTER := Vector2(328, 548)
const GAP := 72.0
## Each painted poster's portrait window, as fractions of its height (its stamps go across it).
const WINDOW_TOP := 0.225
const WINDOW_BOTTOM := 0.695
## The star progress on the cork under a started bounty's poster: its gap below the poster, and height.
const STARS_GAP := 8.0
const STARS_H := 28.0
const TILTS := [-1.2, 0.8, -0.6, 1.1, -0.9]
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
	for i in posters.size():  # a portrait shown for the first time: its shadow lifts away
		if posters[i].has_meta("veil"):
			_lift_veil(i, posters[i].get_meta("veil"))


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
	_strip.position = Vector2(vis.x / 2 - POSTER.x / 2 - scroll, RAIL_H + (vis.y - RAIL_H * 2 - POSTER.y - STARS_GAP - STARS_H) / 2)
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




## The shadow lifting off a newly revealed portrait (J.R.'s, when his bounty unlocks), once.
func _lift_veil(i: int, veil: TextureRect) -> void:
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_method(func(v: float):
		veil.set_meta("lift", v)
		veil.material.set_shader_parameter("lift", v), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		veil.queue_free()
		GameState.progress.revealed[str(i)] = true
		GameState.save())


## One painted wanted poster, `size` pixels (the Bounty board's, or smaller on the office's cork board
## and the hunt screen). On top of the painting only: the CAPTURED stamp, small and a little see-through
## so the face shows; COMING SOON in dark brown ink, on a faded poster; and, with `stars`, a started
## bounty's star progress on the cork just below. J.R.'s poster shows his silhouette until he can be
## hunted; with `reveal`, the first time it shows his face the silhouette is laid over it in the "veil"
## meta, for the board to lift away. The stamp is in the "stamp" meta.
static func poster(i: int, state: String, pg: Dictionary, size := POSTER, stars := true, reveal := true) -> Button:
	var ch: Dictionary = GameState.chapters[i]
	var open := state == "open" or state == "captured"
	var b := Button.new()
	b.theme = load(Assets.THEME)
	b.theme_type_variation = &"Hotspot"  # no frame: the painting is the poster
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the board takes the taps (and tells a tap from a swipe)
	b.disabled = not open
	b.size = size
	b.custom_minimum_size = size
	b.tooltip_text = "%s, %s, %s" % [ch.poster_name, ch.title, ch.reward]
	var art := _painting(b, image_for(i, open), size)
	b.set_meta("art", art)
	if not open:  # coming soon (or not yet reachable): washed out
		art.material = ShaderMaterial.new()
		art.material.shader = load("res://ui/poster_faded.gdshader")
	var dark := "poster/ch%d_locked" % i
	if reveal and open and Assets.has(dark) and not pg.get("revealed", {}).has(str(i)):
		var veil := _painting(b, dark, size)
		veil.material = ShaderMaterial.new()
		veil.material.shader = load("res://ui/poster_veil.gdshader")
		b.set_meta("veil", veil)
	var got := GameState.chapter_stars(pg, i) if open else 0
	if stars and got > 0:  # started: star progress on the cork, under the poster
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(0, size.y + STARS_GAP)
		row.size = Vector2(size.x, STARS_H)
		b.add_child(row)
		UiKit.image(row, "ui/star_on", Vector2(STARS_H, STARS_H) - Vector2(4, 4))
		UiKit.text(row, "%d / %d" % [got, GameState.levels_for(i).size() * 3], &"PosterStars")
		b.set_meta("stars", row)
	var stamp: Control = null
	match state:
		"captured":
			stamp = UiKit.image(b, "ui/stamp_captured", Vector2(size.x * 0.68, size.x * 0.375))
			stamp.modulate.a = 0.9
		"soon":
			stamp = PanelContainer.new()
			stamp.theme_type_variation = &"StampFaded"
			stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UiKit.text(stamp, "COMING SOON", &"StampFadedLabel")
			b.add_child(stamp)
	if stamp != null:
		var sz := stamp.get_combined_minimum_size()
		var k := minf(1.0, size.x * 0.86 / sz.x)  # smaller posters, smaller stamps
		stamp.size = sz
		stamp.pivot_offset = sz / 2
		stamp.scale = Vector2.ONE * k
		var captured := state == "captured"  # CAPTURED goes low across the portrait, on the chest, so the face shows
		var y := lerpf(WINDOW_TOP, WINDOW_BOTTOM, 0.74 if captured else 0.5)
		stamp.position = Vector2(size.x / 2, size.y * y) - sz / 2
		stamp.rotation = deg_to_rad(0.0 if captured else -12.0)  # the CAPTURED art is already tilted
		b.set_meta("stamp", stamp)
	for c in b.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func _painting(parent: Control, asset: String, size: Vector2) -> TextureRect:
	var t := UiKit.image(parent, asset, size)
	t.size = size
	return t


## The poster's painting: J.R.'s silhouette until he can be hunted, then his face.
static func image_for(i: int, open: bool) -> String:
	var dark := "poster/ch%d_locked" % i
	return dark if not open and Assets.has(dark) else "poster/ch%d" % i
