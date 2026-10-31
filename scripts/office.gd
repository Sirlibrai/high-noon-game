class_name Office
extends Node2D
## The sheriff's office home screen: the painted office (assets/painted/office.png) with the parts
## that change laid over it, each placed in the painting's own pixels:
##   - the wanted posters pinned to the empty cork board, the current hunt big in the middle;
##   - the bounty hunter's portrait in the empty gilt frame;
##   - a trophy on the cabinet's top shelf for each captured bounty;
##   - the owned guns resting across the pegs of the rack inside the gunsmith's doorway;
##   - the gunsmith on the stool at his workbench, polishing and hammering, tipping his cap when called;
##   - lamp glow, dust in the window light, and the Continue Hunt ledger on the desk.
## The painting covers the screen (16:9 shows all of it; wider phones trim a little ceiling and desk).
## The room is softly dim; a tapped object lights up warmly for a moment before its screen opens
## (one tap, no hover). Emits `act`: board, hunt, gunsmith, profile, trophies, daily, survival, duelsoon.

signal act(name: String)

const ART_SIZE := Vector2(1672, 941)
## Hotspots in painting pixels: the box you tap (its painted object), and where its brass plate hangs
## (top centre). Plates are kept inside the safe area.
const SPOTS := [
	{"act": "duelsoon", "label": "Duel", "box": [28, 72, 220, 430], "plate": [137, 452], "soon": true},
	{"act": "daily", "label": "Daily Bounty", "box": [300, 172, 146, 196], "plate": [372, 314], "soon": true},
	{"act": "survival", "label": "Survival", "box": [312, 376, 136, 130], "plate": [380, 470], "soon": true},
	{"act": "board", "label": "Bounty board", "box": [498, 116, 578, 344], "plate": [786, 428]},
	{"act": "profile", "label": "Profile", "box": [1096, 174, 180, 252], "plate": [1186, 398]},
	{"act": "trophies", "label": "Trophies", "box": [490, 484, 604, 224], "plate": [786, 590]},
	{"act": "gunsmith", "label": "Gunsmith", "box": [1298, 84, 346, 622], "plate": [1470, 640]},
]
## The cork board: the big poster in the middle, two small ones each side ([x, y] centre, tilt).
const BIG_SPOT := [787, 290, -0.02]
const SMALL_SPOTS := [[620, 218, -0.07], [620, 352, 0.05], [955, 218, 0.06], [955, 352, -0.04]]
const BIG_W := 136.0
const SMALL_W := 96.0
## The gilt frame's empty canvas, the cabinet's top shelf (trophy bases), the rack's pegs.
const FRAME_IN := Rect2(1129, 206, 113, 186)
const TROPHY_AT := [Vector2(590, 566), Vector2(655, 566), Vector2(720, 566), Vector2(885, 566), Vector2(980, 566)]
const RACK_AT := {"repeater": Vector2(1475, 338), "coach": Vector2(1475, 362), "peacemaker": Vector2(1438, 386),
	"quickdraw": Vector2(1504, 386), "longbarrel": Vector2(1440, 410), "legend": Vector2(1508, 410)}
const RACK_SCALE := 1.0
## The gunsmith's stool: the foot of its front-left leg, and the doorway he is seen through.
const STOOL_FOOT := Vector2(1465, 634)
const DOORWAY := Rect2(1356, 200, 282, 505)
const LAMPS := [[Vector2(808, 98), 2.4], [Vector2(1475, 262), 1.1]]
const IDLE_POSE_TIME := 2.6

## The safe area's insets in screen pixels (left, right, bottom), set by Main on phones.
var safe_lrb := Vector3.ZERO
## A chapter just captured: its stamp lands with a thump when the office opens.
var fresh_capture: Variant = null
## The brass plates and the ledger, for the layout tests.
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
var _hunt_glow: NinePatchRect
var _stamp_anim: Variant = null
var _shake := 0
var _coach: Control


func _ready() -> void:
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
	_status = GameState.desk_status(pg, pt)
	var vis := get_viewport().get_visible_rect().size
	_k = maxf(vis.y / ART_SIZE.y, vis.x / ART_SIZE.x)  # cover the screen
	_origin = (vis - ART_SIZE * _k) / 2
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
	var portrait := AssetSprite.make("office/portrait", _art)
	portrait.position = FRAME_IN.position
	portrait.extra_scale = FRAME_IN.size / Assets.texture("office/portrait").get_size()
	for k in 5:  # the trophy cabinet: one trophy per captured bounty
		if GameState.collected_in(pg, k):
			var t := AssetSprite.make("trophy_office/ch%d" % k, _art)
			t.position = TROPHY_AT[k]
			t.modulate = Color(0.92, 0.88, 0.8)  # seen through the cabinet glass
	_build_rack(pg)
	var clip := Control.new()  # the gunsmith is seen through the doorway, behind its posts
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = DOORWAY.position
	clip.size = DOORWAY.size
	_art.add_child(clip)
	_smith = AssetSprite.make("gunsmith/polish", clip)
	_smith.position = STOOL_FOOT - DOORWAY.position
	for i in 9:
		_motes.append(AssetSprite.make("office/mote", _art))
	_shade = ColorRect.new()  # the room is softly dim; a chosen object lights up
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.material = ShaderMaterial.new()
	_shade.material.shader = load("res://ui/office_light.gdshader")
	_shade.size = vis
	add_child(_shade)
	_shade.global_position = Vector2.ZERO
	_hunt_glow = NinePatchRect.new()
	_hunt_glow.texture = Assets.texture("fx/hint_glow")
	var m: int = Assets.meta("fx/hint_glow", "nine_patch", 2)
	_hunt_glow.patch_margin_left = m
	_hunt_glow.patch_margin_top = m
	_hunt_glow.patch_margin_right = m
	_hunt_glow.patch_margin_bottom = m
	_hunt_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunt_glow.visible = _status.hunting
	var big := _big_rect()
	_hunt_glow.position = _to_local_px(big.position) - Vector2(6, 6)
	_hunt_glow.size = big.size * _k + Vector2(12, 12)
	add_child(_hunt_glow)
	_build_hotspots()
	_build_ledger()
	if not pg.get("seenOffice", false):
		_build_coach()
	if fresh_capture != null and _poster_stamps.has(fresh_capture):
		_stamp_anim = {"ch": fresh_capture, "t": -0.5, "thud": false}
		_poster_stamps[fresh_capture].visible = false


## A painting pixel in this node's coordinates (for the unscaled plates and ledger).
func _to_local_px(p: Vector2) -> Vector2:
	return _origin + p * _k - global_position


func _big_rect() -> Rect2:
	var h := BIG_W * 1.75
	return Rect2(BIG_SPOT[0] - BIG_W / 2, BIG_SPOT[1] - h / 2, BIG_W, h)


## A wanted poster as the Bounty board shows it, designed `width` pixels wide. The compact one
## (small on the office's cork board) keeps only WANTED, the portrait and the reward. Its stamp
## (captured, locked, coming soon) is in its "stamp" meta.
static func wanted_poster(i: int, state: String, width: float, compact := false) -> Button:
	var ch: Dictionary = GameState.chapters[i]
	var pg: Dictionary = GameState.progress
	var open := state == "open" or state == "captured"
	var b := Button.new()
	b.theme_type_variation = &"Poster"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 0)
	b.disabled = not open
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	UiKit.text(v, "WANTED", &"PosterWanted")
	var pic := UiKit.image(v, "portrait/ch%d" % i, Vector2(100, 92))
	if not open:
		pic.modulate = Color(0, 0, 0, 0.75)
	if not compact:
		UiKit.text(v, ch.who, &"PosterName", width - 24)
		UiKit.text(v, ch.crime, &"PosterCrime", width - 20)
	UiKit.text(v, ch.reward, &"PosterReward")
	if not compact:
		if open:
			UiKit.text(v, "★ %d/%d" % [GameState.chapter_stars(pg, i), GameState.levels_for(i).size() * 3], &"PosterCrime")
		else:
			UiKit.text(v, ch.name, &"PosterCrime")
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 16
	b.custom_minimum_size.y = v.get_combined_minimum_size().y + 32
	if state != "open":
		var stamp := PanelContainer.new()
		stamp.theme_type_variation = &"Stamp"
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.text(stamp, {"captured": "CAPTURED", "locked": "LOCKED", "soon": "COMING SOON"}[state], &"StampLabel")
		b.add_child(stamp)
		var sz := stamp.get_combined_minimum_size()
		stamp.size = sz
		stamp.position = Vector2((width - sz.x) / 2, 66)  # across the portrait, clear of the name
		stamp.pivot_offset = sz / 2
		stamp.rotation = deg_to_rad(-14)
		b.set_meta("stamp", stamp)
	return b


func _build_posters(pg: Dictionary, pt: bool) -> void:
	var cur := GameState.current_hunt(pg, pt)
	var others := range(5).filter(func(i): return i != cur)
	for k in others.size():
		_hang(others[k], SMALL_SPOTS[k], SMALL_W, true, pg, pt)
	_hang(cur, BIG_SPOT, BIG_W, false, pg, pt)


func _hang(c: int, spot: Array, w: float, compact: bool, pg: Dictionary, pt: bool) -> void:
	var design := 200.0
	var p := wanted_poster(c, GameState.poster_state(pg, c, pt), design, compact)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the board's hotspot takes the tap
	_art.add_child(p)
	p.size = p.custom_minimum_size
	var s := w / design
	p.scale = Vector2.ONE * s
	p.pivot_offset = Vector2.ZERO
	p.position = Vector2(spot[0], spot[1]) - p.size * s / 2
	p.rotation = spot[2]
	if p.has_meta("stamp"):
		_poster_stamps[c] = p.get_meta("stamp")
	var pin := AssetSprite.make("poster/pin", _art)
	pin.position = Vector2(spot[0], spot[1] - p.size.y * s / 2 + 5)


func _build_rack(pg: Dictionary) -> void:
	for w in GameState.weapons:
		if not pg.inv.guns.get(w.id, false) or not RACK_AT.has(w.id):
			continue  # an empty place shows the painted pegs
		if pg.inv.equip.gun == w.id:  # the gun in use glows softly
			var g := AssetSprite.make("office/glow", _art)
			g.position = RACK_AT[w.id]
			g.scale = Vector2(0.9, 0.35)
			g.modulate.a = 0.6
		var gun := AssetSprite.make("rack/" + w.id, _art)
		gun.position = RACK_AT[w.id]
		gun.scale = Vector2.ONE * RACK_SCALE
		gun.modulate = Color(1.0, 0.84, 0.66)  # in the workshop's lamplight


func _build_hotspots() -> void:
	var vis := get_viewport().get_visible_rect().size
	for s in SPOTS:
		var box := Rect2(s.box[0], s.box[1], s.box[2], s.box[3])
		var b := Button.new()
		b.theme_type_variation = &"Hotspot"
		b.focus_mode = Control.FOCUS_NONE
		b.position = _to_local_px(box.position)
		b.size = box.size * _k
		b.tooltip_text = s.label + (", coming soon" if s.get("soon", false) else "")
		b.pressed.connect(_on_act.bind(s.act, box))
		add_child(b)
		var plate := Button.new()
		plate.theme_type_variation = &"PlaqueSoon" if s.get("soon", false) else &"Plaque"
		plate.focus_mode = Control.FOCUS_NONE
		plate.text = s.label + ("" if s.get("soon", false) else "  ›")
		if s.get("soon", false):
			plate.icon = Assets.texture("ui/icon_lock")
		plate.pressed.connect(_on_act.bind(s.act, box))
		add_child(plate)
		var sz := plate.get_combined_minimum_size()
		plate.size = sz
		var at := _origin + Vector2(s.plate[0], s.plate[1]) * _k - Vector2(sz.x / 2, 0)
		at.x = clampf(at.x, safe_lrb.x + 8, vis.x - safe_lrb.y - 8 - sz.x)  # inside the safe area
		plate.position = at - global_position
		plates.append(plate)
	if _status.hunting:  # the big poster continues the hunt
		var big := _big_rect()
		var h := Button.new()
		h.theme_type_variation = &"Hotspot"
		h.focus_mode = Control.FOCUS_NONE
		h.position = _to_local_px(big.position)
		h.size = big.size * _k
		h.pressed.connect(_on_act.bind("hunt", big))
		add_child(h)


## The desk ledger: continue the hunt, or every available bounty captured. It sits on the clear
## middle of the desk, above the bottom of the safe area.
func _build_ledger() -> void:
	var box: Control
	if _status.hunting:
		var btn := Button.new()
		btn.theme_type_variation = &"DeskPlaque"
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_act.bind("hunt", Rect2(600, 740, 540, 150)))
		box = btn
	else:
		box = PanelContainer.new()
		box.theme_type_variation = &"DeskLedger"
	add_child(box)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0 if box is PanelContainer else 12)
	box.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	UiKit.image(row, "ui/star_on", Vector2(44, 44))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	UiKit.text(text, _status.title, &"DeskTitle").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.text(text, _status.subtitle, &"DeskSub").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tally := VBoxContainer.new()
	tally.add_theme_constant_override("separation", 0)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tally)
	UiKit.text(tally, "CAPTURED", &"DeskKey")
	UiKit.text(tally, "%d of 5" % _status.caught, &"DeskValue")
	if _status.reward != null:
		UiKit.text(tally, "BOUNTY", &"DeskKey")
		UiKit.text(tally, _status.reward, &"DeskValue")
	for c in [text, tally, row]:
		for l in c.get_children():
			if l is Control:
				l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := box.get_combined_minimum_size()
	if box is Button:  # a Button does not size itself to child controls
		sz = margin.get_combined_minimum_size()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.size = sz
	var vis := get_viewport().get_visible_rect().size
	var x := _origin.x + 870 * _k - sz.x / 2
	var y := minf(_origin.y + 760 * _k, vis.y - safe_lrb.z - 12 - sz.y)
	box.position = Vector2(x, y) - global_position
	ledger = box


## The first visit's telegram: "Tap anything with a brass plate."
func _build_coach() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Telegram"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	UiKit.text(v, "TELEGRAM", &"DeskKey")
	UiKit.text(v, "Welcome, partner. Tap anything with a brass plate.", &"TelegramText", 440)
	add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = _to_local_px(Vector2(787, 132)) - Vector2(sz.x / 2, 0)
	p.rotation = deg_to_rad(-1.2)
	_coach = p


## One tap: the chosen object lights up warmly, then its screen opens. The gunsmith tips his cap first.
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
	# The lamps flicker a little.
	for i in _glows.size():
		_glows[i].modulate.a = 0.85 + sin(_frame * (0.013 + i * 0.004) + i) * 0.12
	# Dust drifts down through the light from the window.
	for i in _motes.size():
		var h := _hash(i * 31)
		var t2 := fmod(_frame * 0.25 * (1 + i % 3) + h % 400, 400.0)
		_motes[i].position = Vector2(170 + t2 * 0.7 + h % 60, 140 + t2 * 1.1 + sin(_frame * 0.02 + i) * 6)
		_motes[i].modulate.a = sin(t2 / 400.0 * PI) * 0.8
	# The gunsmith works away: polishing, then hammering, slowly.
	if not _tipping:
		_smith_t += delta
		_smith.show_asset("gunsmith/polish" if int(_smith_t / IDLE_POSE_TIME) % 2 == 0 else "gunsmith/hammer")
	# A chosen object lights up.
	var lit := 0.0
	if _lit.t >= 0:
		_lit.t += delta
		lit = minf(1.0, _lit.t / 0.15)
	_shade.material.set_shader_parameter("lit", lit)
	_hunt_glow.modulate.a = 0.35 + sin(_frame * 0.06) * 0.25
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
