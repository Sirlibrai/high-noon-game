class_name Office
extends Node2D
## The sheriff's office home screen: the painted office (assets/painted/office.png, with the gunsmith
## at his bench in the workshop and CONTINUE HUNT on the parchment painted in) and the parts that
## change laid over it, each placed in the painting's own pixels:
##   - the wanted posters pinned to the cork board, side by side, the current hunt's in the middle;
##   - the bounty hunter's portrait in the empty gilt frame;
##   - a trophy on the cabinet's shelf for each captured bounty;
##   - the owned guns across the workshop's rack;
##   - a small spark now and then at the gunsmith's bench, the lamps flickering gently (the workshop's
##     a little more), dust in the window light, and a light vignette.
## The painting covers the screen (16:9 shows all of it; wider phones trim some ceiling and a little
## desk). Most objects have a small tag beside them (a padlock on locked ones); a tapped object glows
## warmly for a moment before its screen opens (one tap, no hover).
## Emits `act`: board, hunt, gunsmith, profile, trophies, daily, survival, duelsoon.

signal act(name: String)

const ART_SIZE := Vector2(1671, 941)
## On screens wider than the painting, how much of the trimmed height comes off the top (the rest off
## the bottom): mostly ceiling, so the parchment's painted CONTINUE HUNT stays above the home indicator.
const CROP_TOP := 0.72
## Hotspots in painting pixels: the box you tap (its painted object), and the centre of its tag, beside
## the object and never over it. Tags are kept inside the safe area. The cabinet has no tag, and the
## doorway's is the painted GUNSMITH sign.
const SPOTS := [
	{"act": "duelsoon", "label": "Duel", "box": [92, 88, 225, 447], "tag": [205, 588], "soon": true},
	{"act": "daily", "label": "Daily Bounty", "box": [376, 315, 106, 109], "tag": [403, 294], "soon": true},
	{"act": "survival", "label": "Survival", "box": [374, 425, 108, 112], "tag": [420, 556], "soon": true},
	{"act": "board", "label": "Bounty board", "box": [490, 82, 635, 478], "tag": [805, 582]},
	{"act": "profile", "label": "Profile", "box": [1132, 125, 166, 203], "tag": [1215, 346]},
	{"act": "trophies", "label": "Trophies", "box": [500, 603, 600, 127]},
	{"act": "gunsmith", "label": "Gunsmith", "box": [1350, 120, 300, 620]},
]
## The parchment on the desk (the Continue Hunt hotspot), and its painted lettering.
const PARCHMENT := Rect2(520, 752, 640, 165)
const LETTERING := Rect2(627, 798, 436, 46)
## The cork board's clear middle (between the painted maps and notes): the current hunt's poster in
## the centre, two smaller ones each side, none overlapping ([x, y] centre, tilt).
const BIG_SPOT := [805, 330, -0.02]
const SMALL_SPOTS := [[694, 250, -0.03], [694, 410, 0.025], [915, 250, 0.03], [915, 410, -0.025]]
const BIG_W := 116.0
const SMALL_W := 88.0
## The gilt frame's empty canvas, the cabinet's middle shelf (trophy bases).
const FRAME_IN := Rect2(1162, 157, 110, 141)
const TROPHY_AT := [Vector2(565, 663), Vector2(640, 663), Vector2(715, 663), Vector2(910, 663), Vector2(1010, 663)]
## The workshop rack: four rods between two rails (x 1535 to 1640), right of the gunsmith's cap. The
## guns lie across the rods, two to a row, the bottom row resting on the hooks.
const RACK_AT := {"repeater": Vector2(1567, 376), "quickdraw": Vector2(1621, 376), "coach": Vector2(1565, 399),
	"peacemaker": Vector2(1618, 399), "longbarrel": Vector2(1561, 421), "legend": Vector2(1614, 421)}
const RACK_SCALE := 0.6
const DOORWAY := Rect2(1350, 120, 300, 620)
## The lamps (flame or bulb, glow size): ceiling, wall lantern, desk lantern, workshop.
const LAMPS := [[Vector2(832, 116), 1.8], [Vector2(427, 222), 0.9], [Vector2(322, 690), 1.2], [Vector2(1505, 320), 0.7]]
const WORKSHOP_LAMP := 3
## The gunsmith's bench: the little anvil's face, where a spark flies now and then (every few seconds).
const SPARK_AT := Vector2(1624, 500)
const SPARK_EVERY := Vector2(3.5, 7.0)
const SPARK_BITS := 5

## The safe area's insets in screen pixels (left, right, bottom), set by Main on phones.
var safe_lrb := Vector3.ZERO
## A chapter just captured: its stamp lands with a thump when the office opens.
var fresh_capture: Variant = null
## The tags, for the layout tests.
var plates: Array[Control] = []

var _k := 1.0
var _origin := Vector2.ZERO
var _art: Node2D
var _frame := 0
var _poster_stamps := {}
var _motes: Array[AssetSprite] = []
var _glows: Array[AssetSprite] = []
## The bench's spark: a quick flash and a few bits flying off, then quiet for a few seconds.
var _spark_flash: AssetSprite
var _spark_bits: Array[AssetSprite] = []
var _spark_vel: Array[Vector2] = []
var _spark_t := 0.0
var _spark_next := 2.0
var _sparks := 0
var _shade: ColorRect
var _lit := {"t": -1.0, "name": ""}
var _stamp_anim: Variant = null
var _shake := 0
var _coach: Control


func _ready() -> void:
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
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
	_spark_flash = AssetSprite.make("office/glow", _art)
	_spark_flash.position = SPARK_AT
	_spark_flash.scale = Vector2.ONE * 0.25
	_spark_flash.visible = false
	for i in SPARK_BITS:
		var bit := AssetSprite.make("office/mote", _art)
		bit.modulate = Color(1.6, 1.15, 0.5)  # a hot yellow-white fleck
		bit.scale = Vector2.ONE * 0.6
		bit.visible = false
		_spark_bits.append(bit)
		_spark_vel.append(Vector2.ZERO)
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
		gun.modulate = Color(1.1, 1.0, 0.86) if pg.inv.equip.gun == w.id else Color(1.0, 0.9, 0.78)  # the gun in use catches the lamp


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
		if not s.has("tag"):
			continue
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


## The parchment with CONTINUE HUNT painted on it is the button: it starts the next unfinished level of
## the current hunt, or opens the Bounty board when no built bounty has levels left (Main decides).
func _build_parchment() -> void:
	var b := Button.new()
	b.theme_type_variation = &"Hotspot"
	b.focus_mode = Control.FOCUS_NONE
	b.position = _to_local_px(PARCHMENT.position)
	b.size = PARCHMENT.size * _k
	b.tooltip_text = "Continue hunt"
	b.pressed.connect(_on_act.bind("hunt", PARCHMENT))
	add_child(b)


## The parchment's painted lettering on screen, in this node's coordinates (for the layout tests).
func lettering_rect() -> Rect2:
	return Rect2(_to_local_px(LETTERING.position), LETTERING.size * _k)


## The first visit's telegram, over the cabinet: where to start.
func _build_coach() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Telegram"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	UiKit.text(v, "TELEGRAM", &"DeskKey")
	UiKit.text(v, "Welcome, partner. Tap the parchment to start the hunt.", &"TelegramText", 460)  # wrapped, so the parchment keeps about its own proportions
	add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = _to_local_px(Vector2(805, 600)) - Vector2(sz.x / 2, 0)  # over the cabinet, clear of the posters and the parchment's lettering
	p.rotation = deg_to_rad(-1.2)
	_coach = p


## One tap: the chosen object glows warmly, then its screen opens.
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
	if name == "gunsmith":
		AudioManager.sfx("creak")
	get_tree().create_timer(0.3).timeout.connect(func():
		act.emit(name)
		get_tree().create_timer(0.8).timeout.connect(_settle))


## Back to the quiet room (when the chosen screen is an overlay on top of it).
func _settle() -> void:
	if not is_inside_tree():
		return
	_lit = {"t": -1.0, "name": ""}


static func _hash(n: int) -> int:
	const M := 0xFFFFFFFF
	n = ((n ^ 61) ^ (n >> 16)) & M
	n = (n * 9) & M
	n = (n ^ (n >> 4)) & M
	n = (n * 0x27d4eb2d) & M
	return (n ^ (n >> 15)) & M


func _physics_process(delta: float) -> void:
	_frame += 1
	# The lamps flicker gently; the workshop's oil lamp a little more, with a soft dip now and then.
	for i in _glows.size():
		var a := 0.5 + sin(_frame * (0.05 + i * 0.013) + i) * 0.05 + sin(_frame * (0.17 + i * 0.02)) * 0.03
		if i == WORKSHOP_LAMP:
			a += sin(_frame * 0.31) * 0.04 + sin(_frame * 0.53 + 1.7) * 0.03 - pow(maxf(0.0, sin(_frame * 0.023)), 12.0) * 0.15
		_glows[i].modulate.a = a
	# Dust drifts down through the light from the window.
	for i in _motes.size():
		var h := _hash(i * 31)
		var t2 := fmod(_frame * 0.25 * (1 + i % 3) + h % 400, 400.0)
		_motes[i].position = Vector2(110 + t2 * 0.35 + h % 70, 110 + t2 * 1.0 + sin(_frame * 0.02 + i) * 6)
		_motes[i].modulate.a = sin(t2 / 400.0 * PI) * 0.7
	_step_spark(delta)
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


## Every few seconds a spark flies off the gunsmith's anvil: a quick flash and a few flecks that arc
## out and fall, fading in half a second.
func _step_spark(delta: float) -> void:
	_spark_t += delta
	if _spark_t >= _spark_next:
		_spark_t = 0.0
		_sparks += 1
		var h := _hash(_sparks * 97)
		_spark_next = lerpf(SPARK_EVERY.x, SPARK_EVERY.y, (h % 1000) / 1000.0)
		for i in SPARK_BITS:
			var hb := _hash(_sparks * 131 + i * 7)
			_spark_bits[i].position = SPARK_AT
			_spark_vel[i] = Vector2(lerpf(-70, 70, (hb % 100) / 100.0), lerpf(-120, -50, ((hb >> 8) % 100) / 100.0))
	var age := _spark_t if _sparks > 0 else 9.0
	_spark_flash.visible = age < 0.12
	_spark_flash.modulate.a = 0.9 * (1.0 - age / 0.12)
	for i in SPARK_BITS:
		var bit := _spark_bits[i]
		bit.visible = age < 0.5
		if bit.visible:
			_spark_vel[i].y += 400 * delta  # they fall
			bit.position += _spark_vel[i] * delta
			bit.modulate.a = 1.0 - age / 0.5


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
