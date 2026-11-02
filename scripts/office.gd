class_name Office
extends Node2D
## The sheriff's office home screen: the painted office (assets/painted/office.png) with the parts
## that change laid over it, each placed in the painting's own pixels:
##   - the wanted posters pinned to the cork board, side by side, the current hunt's in the middle;
##   - the bounty hunter's portrait in the empty gilt frame;
##   - a trophy on the cabinet's shelf for each captured bounty;
##   - the owned guns on the rack in the workshop;
##   - the gunsmith on the stool at his bench, seen through the doorway (its frame, the crate and the
##     barrel are drawn over him), polishing and hammering, tipping his cap when called;
##   - the next hunt written on the blank parchment on the desk;
##   - a gentle lamp flicker, dust in the window light, and a light vignette.
## The painting covers the screen (16:9 shows all of it; wider phones trim some ceiling and a little
## desk). Each object has a small tag beside it (a padlock on locked ones); a tapped object glows
## warmly for a moment before its screen opens (one tap, no hover).
## Emits `act`: board, hunt, gunsmith, profile, trophies, daily, survival, duelsoon.

signal act(name: String)

const ART_SIZE := Vector2(1672, 941)
## On screens wider than the painting, how much of the trimmed height comes off the top (the rest off
## the bottom): mostly ceiling, so the parchment on the desk stays in view.
const CROP_TOP := 0.55
## Hotspots in painting pixels: the box you tap (its painted object), and the centre of its tag, beside
## the object and never over it. Tags are kept inside the safe area.
const SPOTS := [
	{"act": "duelsoon", "label": "Duel", "box": [92, 88, 225, 447], "tag": [205, 588], "soon": true},
	{"act": "daily", "label": "Daily Bounty", "box": [376, 315, 106, 109], "tag": [403, 294], "soon": true},
	{"act": "survival", "label": "Survival", "box": [374, 425, 108, 112], "tag": [420, 556], "soon": true},
	{"act": "board", "label": "Bounty board", "box": [490, 82, 635, 478], "tag": [805, 582]},
	{"act": "profile", "label": "Profile", "box": [1133, 125, 165, 203], "tag": [1215, 346]},
	{"act": "trophies", "label": "Trophies", "box": [495, 603, 610, 129], "tag": [1170, 714]},
	{"act": "gunsmith", "label": "Gunsmith", "box": [1351, 127, 294, 613], "tag": [1372, 762]},
]
## The blank parchment on the desk (Continue Hunt), and the part of it the writing stays within.
const PARCHMENT := Rect2(515, 750, 645, 172)
const WRITING := Rect2(625, 764, 410, 144)
## The cork board's clear middle (between the painted maps and notes): the current hunt's poster in
## the centre, two smaller ones each side, none overlapping ([x, y] centre, tilt).
const BIG_SPOT := [805, 330, -0.02]
const SMALL_SPOTS := [[694, 250, -0.03], [694, 410, 0.025], [915, 250, 0.03], [915, 410, -0.025]]
const BIG_W := 116.0
const SMALL_W := 88.0
## The gilt frame's empty canvas, the cabinet's middle shelf (trophy bases), the rack's hooks.
const FRAME_IN := Rect2(1158, 150, 117, 152)
const TROPHY_AT := [Vector2(565, 663), Vector2(640, 663), Vector2(715, 663), Vector2(910, 663), Vector2(1010, 663)]
const RACK_AT := {"repeater": Vector2(1585, 380), "coach": Vector2(1585, 400), "peacemaker": Vector2(1560, 420),
	"quickdraw": Vector2(1614, 420), "longbarrel": Vector2(1566, 440), "legend": Vector2(1612, 440)}
const RACK_SCALE := 0.8
## The gunsmith's stool: the foot of its front-left leg, over the painted stool's. The doorway's front
## layer (frame, crate, barrel) is drawn over him from DOOR_AT.
const STOOL_FOOT := Vector2(1404, 673)
const DOORWAY := Rect2(1351, 127, 294, 613)
const DOOR_AT := Vector2(1290, 76)
## The lamps (flame or bulb, glow size): ceiling, wall lantern, desk lantern, workshop.
const LAMPS := [[Vector2(832, 118), 1.8], [Vector2(427, 223), 0.9], [Vector2(322, 690), 1.2], [Vector2(1502, 318), 0.7]]
const IDLE_POSE_TIME := 2.6

## The safe area's insets in screen pixels (left, right, bottom), set by Main on phones.
var safe_lrb := Vector3.ZERO
## A chapter just captured: its stamp lands with a thump when the office opens.
var fresh_capture: Variant = null
## The tags and the parchment's writing, for the layout tests.
var plates: Array[Control] = []
var ledger: Control

var _k := 1.0
var _origin := Vector2.ZERO
var _art: Node2D
var _frame := 0
var _status: Dictionary
var _poster_stamps := {}
var _motes: Array[AssetSprite] = []
var _glows: Array[AssetSprite] = []
var _smith: AssetSprite
var _smith_t := 0.0
var _tipping := false
var _shade: ColorRect
var _lit := {"t": -1.0, "name": ""}
var _stamp_anim: Variant = null
var _shake := 0
var _coach: Control


func _ready() -> void:
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
	_status = GameState.desk_status(pg, pt)
	var vis := get_viewport().get_visible_rect().size
	_k = maxf(vis.y / ART_SIZE.y, vis.x / ART_SIZE.x)  # cover the screen
	var spare := vis - ART_SIZE * _k
	_origin = Vector2(spare.x / 2, spare.y * CROP_TOP)
	_art = Node2D.new()
	_art.scale = Vector2.ONE * _k
	add_child(_art)
	_art.global_position = _origin
	for layer in Assets.scenes.office.layers:
		AssetSprite.make(layer, _art)
	for lamp in LAMPS:
		var g := AssetSprite.make("office/glow", _art)
		g.position = lamp[0]
		g.scale = Vector2.ONE * lamp[1]
		_glows.append(g)
	_build_posters(pg, pt)
	var portrait := TextureRect.new()  # the hunter's portrait fills the canvas, cropped to its shape
	portrait.texture = Assets.texture("office/portrait")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = FRAME_IN.position
	portrait.size = FRAME_IN.size
	portrait.name = "Portrait"
	_art.add_child(portrait)
	for k in 5:  # the trophy cabinet: one trophy per captured bounty
		if GameState.collected_in(pg, k):
			var t := AssetSprite.make("trophy_office/ch%d" % k, _art)
			t.position = TROPHY_AT[k]
			t.modulate = Color(0.92, 0.88, 0.8)  # seen through the cabinet glass
	_build_rack(pg)
	_smith = AssetSprite.make("gunsmith/polish", _art)
	_smith.position = STOOL_FOOT
	_smith.modulate = Color(0.96, 0.9, 0.82)  # in the workshop's lamplight
	AssetSprite.make("office/doorway_front", _art).position = DOOR_AT  # the doorframe in front of him
	for i in 9:
		_motes.append(AssetSprite.make("office/mote", _art))
	_shade = ColorRect.new()  # a light vignette; a chosen object glows
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.material = ShaderMaterial.new()
	_shade.material.shader = load("res://ui/office_light.gdshader")
	_shade.material.set_shader_parameter("screen", vis)
	_shade.size = vis
	add_child(_shade)
	_shade.global_position = Vector2.ZERO
	_build_hotspots()
	_build_parchment()
	if not pg.get("seenOffice", false):
		_build_coach()
	if fresh_capture != null and _poster_stamps.has(fresh_capture):
		_stamp_anim = {"ch": fresh_capture, "t": -0.5, "thud": false}
		_poster_stamps[fresh_capture].visible = false


## A painting pixel in this node's coordinates (for the unscaled tags and writing).
func _to_local_px(p: Vector2) -> Vector2:
	return _origin + p * _k - global_position


## The part of the screen inside the safe area, in this node's coordinates.
func _safe_rect() -> Rect2:
	var vis := get_viewport().get_visible_rect().size
	return Rect2(Vector2(safe_lrb.x, 0) - global_position, Vector2(vis.x - safe_lrb.x - safe_lrb.y, vis.y - safe_lrb.z))


func _build_posters(pg: Dictionary, pt: bool) -> void:
	var cur := GameState.current_hunt(pg, pt)
	var others := range(5).filter(func(i): return i != cur)
	for k in others.size():
		_hang(others[k], SMALL_SPOTS[k], SMALL_W, pg, pt)
	_hang(cur, BIG_SPOT, BIG_W, pg, pt)


func _hang(c: int, spot: Array, w: float, pg: Dictionary, pt: bool) -> void:
	var design := 200.0  # the painted poster, as on the Bounty board, scaled down
	var p := BountyWall.poster(c, GameState.poster_state(pg, c, pt), pg, Vector2(design, design * BountyWall.POSTER.y / BountyWall.POSTER.x), false, false)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the board's hotspot takes the tap
	_art.add_child(p)
	p.size = p.custom_minimum_size
	var s := w / design
	p.scale = Vector2.ONE * s
	p.pivot_offset = p.size / 2
	p.position = Vector2(spot[0], spot[1]) - p.size / 2
	p.rotation = spot[2]
	p.set_meta("hunt", w == BIG_W)
	if p.has_meta("stamp"):
		_poster_stamps[c] = p.get_meta("stamp")


func _build_rack(pg: Dictionary) -> void:
	for w in GameState.weapons:
		if not pg.inv.guns.get(w.id, false) or not RACK_AT.has(w.id):
			continue  # an empty place shows the painted hooks
		var gun := AssetSprite.make("rack/" + w.id, _art)
		gun.position = RACK_AT[w.id]
		gun.scale = Vector2.ONE * RACK_SCALE
		gun.modulate = Color(1.0, 0.86, 0.7) if pg.inv.equip.gun == w.id else Color(0.9, 0.76, 0.62)  # the gun in use catches the lamp


func _build_hotspots() -> void:
	var safe := _safe_rect()
	for s in SPOTS:
		var box := Rect2(s.box[0], s.box[1], s.box[2], s.box[3])
		var soon: bool = s.get("soon", false)
		var b := Button.new()
		b.theme_type_variation = &"Hotspot"
		b.focus_mode = Control.FOCUS_NONE
		b.position = _to_local_px(box.position)
		b.size = box.size * _k
		b.tooltip_text = s.label + (", coming soon" if soon else "")
		b.pressed.connect(_on_act.bind(s.act, box))
		add_child(b)
		var tag := Button.new()  # a small tag beside the object; a padlock if it is locked
		tag.theme_type_variation = &"OfficeTagSoon" if soon else &"OfficeTag"
		tag.focus_mode = Control.FOCUS_NONE
		tag.text = s.label
		tag.tooltip_text = b.tooltip_text
		if soon:
			tag.icon = Assets.texture("ui/icon_lock")
		tag.pressed.connect(_on_act.bind(s.act, box))
		add_child(tag)
		var sz := tag.get_combined_minimum_size()
		tag.size = sz
		var at := _to_local_px(Vector2(s.tag[0], s.tag[1])) - sz / 2
		at.x = clampf(at.x, safe.position.x + 6, safe.end.x - 6 - sz.x)
		at.y = clampf(at.y, safe.position.y + 6, safe.end.y - 6 - sz.y)
		tag.position = at
		tag.set_meta("box", box)
		plates.append(tag)


## Continue Hunt, written in ink on the blank parchment: the next level's name and the bounty's
## reward. When every available bounty is captured: that, and the next outlaw's name, opening the
## Bounty board. The whole parchment is the button; the writing is kept on it and inside the safe area.
func _build_parchment() -> void:
	var name := "hunt" if _status.hunting else "board"
	var b := Button.new()
	b.theme_type_variation = &"Hotspot"
	b.focus_mode = Control.FOCUS_NONE
	b.position = _to_local_px(PARCHMENT.position)
	b.size = PARCHMENT.size * _k
	b.tooltip_text = "Continue hunt" if _status.hunting else "Bounty board"
	b.pressed.connect(_on_act.bind(name, PARCHMENT))
	add_child(b)
	var ink := HBoxContainer.new()
	ink.alignment = BoxContainer.ALIGNMENT_CENTER
	ink.add_theme_constant_override("separation", 26)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ink)
	var lines: Array[Label] = []
	if _status.hunting:
		var left := _ink_column(ink)
		UiKit.text(left, "CONTINUE THE HUNT", &"ParchmentKey")
		lines.append(UiKit.text(left, _status.subtitle, &"ParchmentTitle"))
		var right := _ink_column(ink)
		UiKit.text(right, "BOUNTY", &"ParchmentKey")
		lines.append(UiKit.text(right, _status.reward, &"ParchmentValue"))
	else:
		var only := _ink_column(ink)
		lines.append(UiKit.text(only, _status.title, &"ParchmentTitle"))
		UiKit.text(only, _status.subtitle.to_upper(), &"ParchmentKey")
	for l in ink.find_children("*", "Control", true, false):
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# As big as the parchment allows: smaller type for a long level name.
	var room := WRITING.size * _k
	var size := 26
	while size > 15 and ink.get_combined_minimum_size().x > room.x:
		size -= 1
		for l in lines:
			l.add_theme_font_size_override("font_size", size)
	var sz := ink.get_combined_minimum_size()
	ink.size = sz
	var safe := _safe_rect()
	var top := _to_local_px(WRITING.position).y
	var at := _to_local_px(WRITING.get_center()) - sz / 2
	at.y = clampf(at.y, top, maxf(top, safe.end.y - 6 - sz.y))  # on the parchment, above the home indicator
	ink.position = at
	ledger = ink


func _ink_column(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v


## The first visit's telegram: "Tap anything with a tag."
func _build_coach() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Telegram"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	UiKit.text(v, "TELEGRAM", &"DeskKey")
	UiKit.text(v, "Welcome, partner. Tap the board, the doorway, or anything with a tag.", &"TelegramText", 300)  # wrapped, so the parchment keeps about its own proportions
	add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = _to_local_px(Vector2(805, 603)) - Vector2(sz.x / 2, 0)  # over the cabinet, clear of the posters
	p.rotation = deg_to_rad(-1.2)
	_coach = p


## One tap: the chosen object glows warmly, then its screen opens. The gunsmith turns and tips his
## cap first.
func _on_act(name: String, box: Rect2) -> void:
	if _lit.t >= 0:
		return  # already on its way
	if _coach != null:  # the first tap anywhere dismisses the telegram for good
		_coach.queue_free()
		_coach = null
		GameState.progress.seenOffice = true
		GameState.save()
	_lit = {"t": 0.0, "name": name}
	var r := Rect2(_origin + box.position * _k, box.size * _k)
	_shade.material.set_shader_parameter("spot", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	var wait := 0.3
	if name == "gunsmith":
		_tipping = true
		_smith.show_asset("gunsmith/tip")
		AudioManager.sfx("creak")
		wait = 0.6
	get_tree().create_timer(wait).timeout.connect(func():
		act.emit(name)
		get_tree().create_timer(0.8).timeout.connect(_settle))


## Back to the quiet room (when the chosen screen is an overlay on top of it).
func _settle() -> void:
	if not is_inside_tree():
		return
	_lit = {"t": -1.0, "name": ""}
	_tipping = false


static func _hash(n: int) -> int:
	const M := 0xFFFFFFFF
	n = ((n ^ 61) ^ (n >> 16)) & M
	n = (n * 9) & M
	n = (n ^ (n >> 4)) & M
	n = (n * 0x27d4eb2d) & M
	return (n ^ (n >> 15)) & M


func _physics_process(delta: float) -> void:
	_frame += 1
	# The lamps flicker gently.
	for i in _glows.size():
		_glows[i].modulate.a = 0.5 + sin(_frame * (0.05 + i * 0.013) + i) * 0.05 + sin(_frame * (0.17 + i * 0.02)) * 0.03
	# Dust drifts down through the light from the window.
	for i in _motes.size():
		var h := _hash(i * 31)
		var t2 := fmod(_frame * 0.25 * (1 + i % 3) + h % 400, 400.0)
		_motes[i].position = Vector2(110 + t2 * 0.35 + h % 70, 110 + t2 * 1.0 + sin(_frame * 0.02 + i) * 6)
		_motes[i].modulate.a = sin(t2 / 400.0 * PI) * 0.7
	# The gunsmith works away: polishing, then hammering, slowly.
	if not _tipping:
		_smith_t += delta
		_smith.show_asset("gunsmith/polish" if int(_smith_t / IDLE_POSE_TIME) % 2 == 0 else "gunsmith/hammer")
	# A chosen object glows.
	var lit := 0.0
	if _lit.t >= 0:
		_lit.t += delta
		lit = minf(1.0, _lit.t / 0.15)
	_shade.material.set_shader_parameter("lit", lit)
	if _stamp_anim != null:
		_step_stamp()
	position = Vector2(randi_range(-4, 4), randi_range(-4, 4)) if _shake > 0 else Vector2.ZERO
	_shake = maxi(0, _shake - 1)


func _step_stamp() -> void:
	var s: Dictionary = _stamp_anim
	s.t += 1.0 / 60.0
	var node: Control = _poster_stamps[s.ch]
	if s.t < 0:
		return
	var f := minf(1, s.t / 0.45)
	node.visible = true
	node.scale = Vector2.ONE * (1 + (1 - f) * 1.6)
	if f >= 1 and not s.thud:
		s.thud = true
		AudioManager.sfx("thump")
		Haptics.hit()
		_shake = 4
		_stamp_anim = null
