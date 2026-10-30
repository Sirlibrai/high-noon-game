class_name Office
extends Node2D
## The sheriff's office home screen (the prototype's buildOffice / drawOffice /
## home). Built only from manifest assets, in the prototype's 320×180 units at
## 2 pixels per unit, like the levels:
##   - the bounty board with five wanted posters, the current hunt big in the
##     middle, each poster open, captured (stamped), locked or coming soon;
##   - the bounty hunter's portrait, the gunsmith's doorway and gun rack, the
##     trophy cabinet that fills as outlaws are captured;
##   - life outside the window, drifting dust, the gunsmith at his bench;
##   - brass-plaque hotspots, and the desk ledger with the campaign status.
## Emits `act` with the prototype's action names: board, hunt, gunsmith,
## profile, daily, survival, duelsoon.

signal act(name: String)

const PPU := 2.0
## OFFICE_SPOTS: hotspot boxes in units, as in the prototype.
const SPOTS := [
	{"act": "board", "label": "Bounty board", "box": [106, 12, 108, 88]},
	{"act": "gunsmith", "label": "Gunsmith", "box": [256, 4, 60, 138]},
	{"act": "daily", "label": "Daily Bounty", "box": [76, 17, 26, 34], "soon": true},
	{"act": "survival", "label": "Survival", "box": [76, 66, 26, 26], "soon": true},
	{"act": "profile", "label": "Profile", "box": [220, 16, 34, 62]},
	{"act": "duelsoon", "label": "Duel", "box": [8, 22, 64, 72], "soon": true},
]
const SMALL_SPOTS := [[125, 34, -0.07], [125, 75, 0.05], [195, 34, 0.06], [195, 75, -0.04]]
const BIG_SPOT := [160, 47, -0.02]

## A chapter just captured: its stamp lands with a thump when the office opens.
var fresh_capture: Variant = null

var _frame := 0
var _status: Dictionary
var _poster_nodes := {}
var _window_clip: Control
var _window_ev: Variant = null
var _window_next := 300
var _motes: Array[AssetSprite] = []
var _paper_t := 0
var _flap: AssetSprite
var _light: AssetSprite
var _glint: NinePatchRect
var _hunt_glow: NinePatchRect
var _door: AssetSprite
var _door_glow: AssetSprite
var _door_t := -1.0
var _stamp_anim: Variant = null
var _shake := 0
var _coach: Control


func _ready() -> void:
	var pg: Dictionary = GameState.progress
	var pt := GameState.playtest()
	_status = GameState.desk_status(pg, pt)
	for layer in Assets.scenes.office.layers:
		AssetSprite.make(layer, self)
	_build_posters(pg, pt)
	_place(AssetSprite.make("office/portrait", self), Vector2(223, 32))
	_build_rack(pg)
	for k in 5:  # the trophy cabinet: one trophy per captured bounty
		var got := GameState.collected_in(pg, k)
		_place(AssetSprite.make("trophy_office/ch%d" % k if got else "trophy_office/empty", self), Vector2(20 + k * 12, 114))
	_place(AssetSprite.make("office/cabinet_glass", self), Vector2(18, 112))
	_window_clip = Control.new()
	_window_clip.clip_contents = true
	_window_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_clip.position = Vector2(12, 26) * PPU
	_window_clip.size = Vector2(56, 64) * PPU
	add_child(_window_clip)
	_place(AssetSprite.make("office/window_front", self), Vector2(12, 26))
	_light = AssetSprite.make("office/light", self)
	for i in 9:
		_motes.append(AssetSprite.make("office/mote", self))
	_flap = AssetSprite.make("office/paper_flap", self)
	_flap.visible = false
	_glint = _nine("office/glint")
	_hunt_glow = _nine("office/glint")
	_hunt_glow.position = Vector2(139.5, 19.5) * PPU
	_hunt_glow.size = Vector2(41, 57) * PPU
	_hunt_glow.visible = _status.hunting
	_place(AssetSprite.make("office/smith", self), Vector2(288, 86))
	_door_glow = AssetSprite.make("office/door_glow", self)
	_place(_door_glow, Vector2(262, 22))
	_door_glow.modulate.a = 0.0
	_door = AssetSprite.make("office/door", self)
	_place(_door, Vector2(262, 22))
	_build_hotspots()
	_build_ledger()
	if not pg.get("seenOffice", false):
		_build_coach()
	if fresh_capture != null and _poster_nodes.has(fresh_capture):
		_stamp_anim = {"ch": fresh_capture, "t": -0.5, "thud": false}
		_poster_nodes[fresh_capture].stamp.visible = false


func _place(n: Node2D, at: Vector2) -> void:
	n.position = at * PPU


func _nine(asset: String) -> NinePatchRect:
	var r := NinePatchRect.new()
	r.texture = Assets.texture(asset)
	var m: int = Assets.meta(asset, "nine_patch", 2)
	r.patch_margin_left = m
	r.patch_margin_top = m
	r.patch_margin_right = m
	r.patch_margin_bottom = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	add_child(r)
	return r


func _build_posters(pg: Dictionary, pt: bool) -> void:
	var cur := GameState.current_hunt(pg, pt)
	var others := range(5).filter(func(i): return i != cur)
	for k in others.size():
		_hang(others[k], SMALL_SPOTS[k], false, pg, pt)
	_hang(cur, BIG_SPOT, true, pg, pt)


func _hang(c: int, spot: Array, big: bool, pg: Dictionary, pt: bool) -> void:
	var size := "big" if big else "small"
	var state := GameState.poster_state(pg, c, pt)
	var art := "open" if state == "captured" else state
	var at := Vector2(spot[0], spot[1])
	var shadow := AssetSprite.make("poster/shadow_" + size, self)
	_place(shadow, at + Vector2(2, 2))
	shadow.rotation = spot[2]
	var poster := AssetSprite.make("poster_ch%d/%s_%s" % [c, art, size], self)
	_place(poster, at)
	poster.rotation = spot[2]
	var stamp := AssetSprite.make("poster/stamp_" + size, self)
	_place(stamp, at + Vector2(0, 6 if big else 3))
	stamp.rotation = -0.32
	stamp.visible = state == "captured"
	var h := Assets.texture("poster_ch%d/%s_%s" % [c, art, size]).get_height() / PPU
	_place(AssetSprite.make("poster/pin", self), Vector2(roundf(at.x), roundf(at.y - h / 2)))
	_poster_nodes[c] = {"stamp": stamp, "big": big}


func _build_rack(pg: Dictionary) -> void:
	var guns: Array = GameState.weapons
	for k in guns.size():
		var w: Dictionary = guns[k]
		var own: bool = pg.inv.guns.get(w.id, false)
		var gx := 273 + k * 5
		_place(AssetSprite.make("rack/%s%s" % [w.id, "" if own else "_empty"], self), Vector2(gx - 1, 39))
		if own and pg.inv.equip.gun == w.id:
			_place(AssetSprite.make("office/rack_equipped", self), Vector2(gx, 37))


func _build_hotspots() -> void:
	for s in SPOTS:
		_hotspot(s.act, Rect2(s.box[0], s.box[1], s.box[2], s.box[3]), s.label, s.get("soon", false))
	if _status.hunting:  # the centre poster continues the hunt
		_hotspot("hunt", Rect2(139, 19, 42, 58), "", false)


func _hotspot(name: String, box: Rect2, label: String, soon: bool) -> void:
	var b := Button.new()
	b.theme_type_variation = &"Hotspot"
	b.focus_mode = Control.FOCUS_NONE
	b.position = box.position * PPU
	b.size = box.size * PPU
	b.tooltip_text = label + (", coming soon" if soon else "")
	b.pressed.connect(_on_act.bind(name))
	add_child(b)
	if label == "":
		return
	var plaque := Button.new()
	plaque.theme_type_variation = &"PlaqueSoon" if soon else &"Plaque"
	plaque.focus_mode = Control.FOCUS_NONE
	plaque.text = label + ("" if soon else "  ›")
	if soon:
		plaque.icon = Assets.texture("ui/icon_lock")
	plaque.pressed.connect(_on_act.bind(name))
	add_child(plaque)
	# Like the prototype's plaque: centred under the box, hanging half below its bottom edge.
	var sz := plaque.get_combined_minimum_size()
	plaque.size = sz
	plaque.position = Vector2(b.position.x + (b.size.x - sz.x) / 2, b.position.y + b.size.y - sz.y * 0.45)


## The desk ledger: continue the hunt, or every available bounty captured.
func _build_ledger() -> void:
	var box: Control
	if _status.hunting:
		var btn := Button.new()
		btn.theme_type_variation = &"DeskPlaque"
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_act.bind("hunt"))
		box = btn
	else:
		box = PanelContainer.new()
		box.theme_type_variation = &"DeskLedger"
	add_child(box)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0 if box is PanelContainer else 6)
	box.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	UiKit.image(row, "ui/star_on", Vector2(22, 22))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	UiKit.text(text, _status.title, &"DeskTitle").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.text(text, _status.subtitle, &"DeskSub").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var ledger := VBoxContainer.new()
	ledger.add_theme_constant_override("separation", 0)
	ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ledger)
	UiKit.text(ledger, "CAPTURED", &"DeskKey")
	UiKit.text(ledger, "%d of 5" % _status.caught, &"DeskValue")
	if _status.reward != null:
		UiKit.text(ledger, "BOUNTY", &"DeskKey")
		UiKit.text(ledger, _status.reward, &"DeskValue")
	for c in [text, ledger, row]:
		for l in c.get_children():
			if l is Control:
				l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := box.get_combined_minimum_size()
	if box is Button:  # a Button does not size itself to child controls
		sz = margin.get_combined_minimum_size()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.size = sz
	box.position = Vector2(161 * PPU - sz.x / 2, 113 * PPU)


## The first visit's telegram: "Tap anything with a brass plate."
func _build_coach() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Telegram"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	UiKit.text(v, "TELEGRAM", &"DeskKey")
	UiKit.text(v, "Welcome, partner. Tap anything with a brass plate.", &"TelegramText", 220)
	add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = Vector2(160 * PPU - sz.x / 2, 28)
	p.rotation = deg_to_rad(-1.2)
	_coach = p


func _on_act(name: String) -> void:
	if _coach != null:  # the first tap anywhere dismisses the telegram for good
		_coach.queue_free()
		_coach = null
		GameState.progress.seenOffice = true
		GameState.save()
	if name == "gunsmith":
		_door_t = 0.0
		AudioManager.sfx("creak")
		get_tree().create_timer(0.23).timeout.connect(func(): act.emit(name))
		return
	act.emit(name)


static func _hash(n: int) -> int:
	const M := 0xFFFFFFFF
	n = ((n ^ 61) ^ (n >> 16)) & M
	n = (n * 9) & M
	n = (n ^ (n >> 4)) & M
	n = (n * 0x27d4eb2d) & M
	return (n ^ (n >> 15)) & M


func _physics_process(_delta: float) -> void:
	_frame += 1
	_step_window()
	# Warm light flickers a little.
	_light.modulate.a = 1.0 + sin(_frame * 0.013) * 0.17
	for i in _motes.size():
		var h := _hash(i * 31)
		var t2 := fmod(_frame * 0.18 * (1 + i % 3) + h % 200, 200.0)
		_place(_motes[i], Vector2(roundf(20 + t2 * 0.6 + h % 30), roundf(40 + t2 * 0.55 + sin(_frame * 0.02 + i) * 3)))
	# A note on the board lifts in a passing draught.
	_paper_t -= 1
	if _paper_t < 0:
		_paper_t = 540 + randi() % 360
	_flap.visible = _paper_t < 40
	if _flap.visible:
		var lift := roundf(sin(_paper_t / 40.0 * PI) * 3)
		_place(_flap, Vector2(178, 93))
		_flap.scale.y = (lift + 1) / 4.0
	# The attract glint moves between the board, the gunsmith and the portrait.
	var cyc := _frame / 150.0
	var spot: Dictionary = [SPOTS[0], SPOTS[1], SPOTS[4]][int(cyc) % 3]
	var a2 := sin(minf(1, fmod(cyc, 1.0) * 1.6) * PI) * 0.7
	_glint.position = (Vector2(spot.box[0], spot.box[1]) - Vector2(1.5, 1.5)) * PPU
	_glint.size = (Vector2(spot.box[2], spot.box[3]) + Vector2(3, 3)) * PPU
	_glint.modulate.a = maxf(0, a2)
	_hunt_glow.modulate.a = 0.35 + sin(_frame * 0.06) * 0.25
	# The gunsmith's door swings open when tapped.
	if _door_t >= 0:
		_door_t += 1.0 / 60.0
		var f := minf(1, _door_t / 0.22)
		_door.scale.x = maxf(3, roundf(16 - 13 * f)) / 16.0
		_door_glow.modulate.a = f
	if _stamp_anim != null:
		_step_stamp()
	position = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * PPU if _shake > 0 else Vector2.ZERO
	_shake = maxi(0, _shake - 1)


func _step_stamp() -> void:
	var s: Dictionary = _stamp_anim
	s.t += 1.0 / 60.0
	var node: AssetSprite = _poster_nodes[s.ch].stamp
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


## Life outside the window: now and then a dog, a walker or a rider passes.
func _step_window() -> void:
	if _window_ev == null:
		_window_next -= 1
		if _window_next <= 0:
			var k := randi() % 3
			var kind: String = ["dog", "walker", "horse"][k]
			var s := AssetSprite.make("office/" + kind, _window_clip)
			_window_ev = {"k": k, "x": -6.0 if k == 0 else 72.0, "v": [0.35, -0.12, -0.45][k], "t": 0, "node": s}
		return
	var e: Dictionary = _window_ev
	e.x += e.v
	e.t += 1
	var X := roundf(e.x)
	var top := Vector2.ZERO
	match e.k:
		0:
			top = Vector2(X - 1, 84 - absf(roundf(sin(e.t * 0.12) * 3)))
		1:
			top = Vector2(X - 1, 66)
		2:
			top = Vector2(X - 2, 66)
	e.node.position = (top - Vector2(12, 26)) * PPU
	if e.x < -12 or e.x > 82:
		e.node.queue_free()
		_window_ev = null
		_window_next = 420 + randi() % 480
