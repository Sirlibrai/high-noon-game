extends Node
## The game's flow, as in the prototype: the splash standoff, the sheriff's
## office (home), the Bounty board, each bounty's level grid, the coming-soon
## cards, and around a Level its HUD, intro card, win and fail cards with the
## Second Chance offer, and pause. The look comes from the shared theme
## (ui/theme.tres) and the asset manifest; nothing is drawn here.
##
## The game fills the screen: the 640×360 stage is centred and wide phones see
## more of the street's background layers at the sides. HUD controls follow the
## real screen edges, inside the safe area.

const BASE := Vector2(1280, 720)

var level: Level
var ci := 0
var li := 0

var _world: Node2D
## The safe area's insets in base pixels (left, right, bottom); tests can set safe_override to a phone's.
var _safe_lrb := Vector3.ZERO
var safe_override: Variant = null
var _screen: Node2D  # the splash or the office, when no level is running
var _fresh_capture: Variant = null
var _home_bar: CanvasLayer
var _home_box: MarginContainer
var _wallet: Button
var _hud: CanvasLayer
var _hud_box: MarginContainer
var _hearts: Array[TextureRect] = []
var _ammo: HBoxContainer
var _ammo_slots := -1
var _lvl_label: Label
var _sound_btn: Button
var _call_layer: CanvasLayer
var _call_label: Label
var _call_tween: Tween
var _call_token := 0
var _overlay_layer: CanvasLayer
var _overlay: Control
## The Bounty board wall, while it is open.
var board: BountyWall


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	_build_hud()
	_build_home_bar()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	get_viewport().size_changed.connect(_layout)
	CloudSync.merged.connect(func():
		if _screen is Office and _overlay == null:
			show_home())  # another device's progress arrived: refresh the office
	_layout()
	show_splash()


## The office's top bar: only the Bounty Dollars wallet, in the top right corner. (Music is in the pause
## menu and on each bounty's hunt screen.)
func _build_home_bar() -> void:
	_home_bar = CanvasLayer.new()
	_home_bar.layer = 5
	add_child(_home_bar)
	_home_box = MarginContainer.new()
	_home_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_home_box.add_theme_constant_override("margin_top", 16)
	_home_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_bar.add_child(_home_box)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_box.add_child(bar)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	_wallet = _wallet_button(bar)
	_home_bar.visible = false


func _refresh_home_bar() -> void:
	_wallet.text = "%s  ›" % _money(int(GameState.progress.bucks))


## Centres the stage and keeps the HUD inside the safe area (notch, Dynamic Island).
func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	var off := ((vis - BASE) / 2).floor()
	_world.position = off
	if level != null:
		var ppu: float = GameState.geometry.pixels_per_unit
		level.view_left = -off.x / ppu
		level.view_right = BASE.x / ppu + off.x / ppu
	var win := Vector2(DisplayServer.window_get_size())
	# The safe area (notch, Dynamic Island, rounded corners) matters on phones, where the game fills the screen;
	# on a desktop it would only measure the menu bar.
	var safe := Rect2(DisplayServer.get_display_safe_area()) if OS.has_feature("mobile") else Rect2()
	var k := vis / win if win.x > 0 and win.y > 0 else Vector2.ONE
	var left := maxf(0, safe.position.x) * k.x if safe.size.x > 0 else 0.0
	var right := maxf(0, win.x - safe.end.x) * k.x if safe.size.x > 0 else 0.0
	var top := maxf(0, safe.position.y) * k.y if safe.size.y > 0 else 0.0
	var bottom := maxf(0, win.y - safe.end.y) * k.y if safe.size.y > 0 else 0.0
	_safe_lrb = safe_override if safe_override != null else Vector3(left, right, bottom)
	_hud_box.add_theme_constant_override("margin_top", int(14 + top))
	for box in [_hud_box, _home_box]:
		box.add_theme_constant_override("margin_left", int(12 + left))
		box.add_theme_constant_override("margin_right", int(12 + right))


# ---------- input ----------

func _input(event: InputEvent) -> void:
	# Music never starts before the first tap (audio.md).
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		AudioManager.unlock()


func _unhandled_input(event: InputEvent) -> void:
	if _screen is Splash:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]):
			(_screen as Splash).tap()
		return
	if level == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Touches arrive as emulated mouse events, which carry the emulation device id.
		var from_touch: bool = event.device == InputEvent.DEVICE_ID_EMULATION
		GameState.touch_mode = from_touch
		level.shoot(_to_units(event), from_touch)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		level.mouse = _to_units(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				_toggle_pause()
			KEY_R:
				if level.state in ["play", "pause", "won", "lost"]:
					restart()
			KEY_SPACE, KEY_ENTER:
				if level.state == "play" and level.duel != null:
					level.shoot(Vector2(level.SC.duelX, level.GY - 22), false)


## A tap in gameplay units (the level node itself is shaken, so use its parent).
func _to_units(event: InputEvent) -> Vector2:
	return _world.make_input_local(event).position / float(GameState.geometry.pixels_per_unit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if level != null and level.state == "play":
			_toggle_pause()


# ---------- flow ----------

func _set_screen(node: Node2D) -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = node
	if node != null:
		_world.add_child(node)


## The splash standoff; its second tap fades to the office.
func show_splash() -> void:
	_end_level()
	_home_bar.visible = false
	var s := Splash.new()
	_set_screen(s)
	s.finished.connect(func(): show_home())


## The sheriff's office (the prototype's home()).
func show_home() -> void:
	_end_level()
	var o := Office.new()  # rebuilt each visit, so posters, rack and cabinet show the latest progress
	o.safe_lrb = _safe_lrb
	o.fresh_capture = _fresh_capture
	_fresh_capture = null
	_set_screen(o)
	o.act.connect(_on_office_act)
	AudioManager.duck(1.0)
	AudioManager.play("office")
	_home_bar.visible = true
	_refresh_home_bar()


func _office_backdrop() -> void:
	_end_level()
	if not _screen is Office:
		var o := Office.new()
		o.safe_lrb = _safe_lrb
		_set_screen(o)
		(_screen as Office).act.connect(_on_office_act)
	AudioManager.play("office")
	_home_bar.visible = false


func _on_office_act(name: String) -> void:
	match name:
		"board":
			AudioManager.sfx("rustle")
			show_board()
		"hunt":
			AudioManager.sfx("rustle")
			hunt()
		"profile":
			AudioManager.sfx("tick2")
			_not_yet("Profile", "Your own wanted poster, rank, trophy shelf and ledger arrive with the next build.")
		"trophies":
			AudioManager.sfx("tick2")
			show_trophies()
		"gunsmith":
			_not_yet("Gunsmith", "Buying guns and finishes with Bounty Dollars arrives with the next build.")
		"daily":
			AudioManager.sfx("flip")
			soon(name)
		"survival":
			AudioManager.sfx("tick2")
			soon(name)
		"duelsoon":
			AudioManager.sfx("bell")
			soon(name)


## Continue the hunt: the next uncaptured bounty, at its furthest unlocked level.
func hunt() -> void:
	var st := GameState.desk_status(GameState.progress, GameState.playtest())
	if not st.hunting:
		return
	if not GameState.is_built(st.ch, st.level):
		_not_yet(GameState.chapters[st.ch].name, "%s’s levels arrive with the next build." % GameState.chapters[st.ch].who)
		return
	show_intro(st.ch, st.level)


## The HUD's cartridges: big enough to count at a glance on a phone.
const BULLET_SIZE := Vector2(34, 56)
const BULLET_GAP := 12
## The outlaw's wanted poster on his hunt screen (its height), and his face on his keepsake's label in
## the trophy cabinet.
const HUNT_POSTER := 168.0
const TROPHY_FACE := 48.0


## The Bounty board: all five posters, open, captured, locked or coming soon.
## `focus`: the poster to centre (the bounty just looked at); otherwise the current hunt.
func show_board(focus := -1) -> void:
	_office_backdrop()
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay)
	board = BountyWall.new()
	board.safe_lrb = _safe_lrb
	_overlay.add_child(board)
	board.chosen.connect(show_chapter)
	if focus >= 0:
		board.show_poster(focus)
	# Only a small Home button and the Bounty Dollars, in the top corners inside the safe area.
	var corners := MarginContainer.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.add_theme_constant_override("margin_left", int(12 + _safe_lrb.x))
	corners.add_theme_constant_override("margin_right", int(12 + _safe_lrb.y))
	corners.add_theme_constant_override("margin_top", 10)
	_overlay.add_child(corners)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.add_child(bar)
	UiKit.button(bar, "‹ Home", &"SmallGhostButton").pressed.connect(show_home)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	_wallet_button(bar)


## One bounty's levels (the prototype's menu(c)).
func show_chapter(c: int) -> void:
	_office_backdrop()
	ci = c
	var card := _open_overlay()
	var top := UiKit.row(card)
	UiKit.button(top, "‹ Bounty board", &"SmallGhostButton").pressed.connect(show_board.bind(c))
	_wallet_button(top)
	var ch: Dictionary = GameState.chapters[c]
	var head := UiKit.row(card)  # the outlaw's wanted poster beside the bounty's name
	head.add_theme_constant_override("separation", 20)
	var pg: Dictionary = GameState.progress
	var sz := Vector2(HUNT_POSTER * BountyWall.POSTER.x / BountyWall.POSTER.y, HUNT_POSTER)
	var wanted := BountyWall.poster(c, GameState.poster_state(pg, c, GameState.playtest()), pg, sz, false, false)
	wanted.pivot_offset = sz / 2
	wanted.rotation = deg_to_rad(-1.5)
	head.add_child(wanted)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	UiKit.text(names, ch.name, &"Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var built := GameState.is_built(c, 0)
	UiKit.text(names, ("%s, %s. Gold levels are duels." % [ch.who, ch.reward]) if built else "%s’s levels arrive with the next build." % ch.who, &"Hint").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var grid := GridContainer.new()
	grid.columns = 5
	card.add_child(grid)
	var lvls: Array = GameState.levels_for(c)
	for i in lvls.size():
		var lv: Dictionary = lvls[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var duel_level: bool = lv.get("duel", false) or lv.get("eli", false)
		var b := UiKit.button(cell, str(i + 1), &"" if duel_level else &"GhostButton")
		b.custom_minimum_size = Vector2(176, 0)
		b.tooltip_text = lv.name
		b.disabled = not GameState.level_open(c, i)
		if b.disabled:
			b.text = ""
			b.icon = Assets.texture("ui/icon_lock")
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 30)
		b.pressed.connect(show_intro.bind(c, i))
		UiKit.stars(cell, GameState.stars_in(GameState.progress, c, i), 32)
	var settings := UiKit.row(card)
	var pt := UiKit.button(settings, "All levels open: " + ("on" if GameState.playtest() else "off"), &"SmallGhostButton")
	pt.pressed.connect(func():
		SaveManager.set_setting("playtest", not GameState.playtest())
		show_chapter(c))
	var snd := UiKit.button(settings, "Sound: " + ("on" if AudioManager.sound_on else "off"), &"SmallGhostButton")
	snd.pressed.connect(func():
		AudioManager.set_sound(not AudioManager.sound_on)
		show_chapter(c))
	var mus := UiKit.button(settings, "Music: " + ("on" if AudioManager.music_on else "off"), &"SmallGhostButton")
	mus.pressed.connect(func():
		AudioManager.set_music(not AudioManager.music_on)
		show_chapter(c))


const SOON := {
	"daily": ["Daily Bounty", "One hand-picked challenge every day, the same for every bounty hunter. Keep your streak going and share your results."],
	"survival": ["Survival", "Endless waves of outlaws that keep getting faster. Chain your hits for combos and chase your best score."],
	"duelsoon": ["Duel at High Noon", "Think you’re the fastest gun in the West? Soon you’ll be able to challenge your friends to real-time quickdraw duels."],
}


## Daily Bounty, Survival and the Duel teaser: marked as coming soon, like the prototype.
func soon(kind: String) -> void:
	_office_backdrop()
	var card := _open_overlay()
	UiKit.button(UiKit.row(card), "‹ Home", &"SmallGhostButton").pressed.connect(show_home)
	UiKit.text(card, SOON[kind][0], &"Heading")
	UiKit.text(card, SOON[kind][1], &"", 840)
	var stamp := PanelContainer.new()
	stamp.theme_type_variation = &"Stamp"
	UiKit.text(stamp, "COMING SOON", &"StampLabel")
	var holder := CenterContainer.new()
	holder.add_child(stamp)
	card.add_child(holder)
	UiKit.button(UiKit.row(card), "Back", &"GhostButton").pressed.connect(show_home)


## The trophy cabinet: one trophy for each bounty captured.
func show_trophies() -> void:
	_office_backdrop()
	var card := _open_overlay()
	UiKit.text(card, "Trophy cabinet", &"Heading")
	var pg: Dictionary = GameState.progress
	var got := range(GameState.chapters.size()).filter(func(i): return GameState.collected_in(pg, i))
	if got.is_empty():
		UiKit.text(card, "The shelves are bare. Capture Iron Eli to win your first trophy.", &"", 840)
	else:
		var shelf := UiKit.row(card)
		for i in got:
			var cell := VBoxContainer.new()
			shelf.add_child(cell)
			UiKit.image(cell, "trophy_office/ch%d" % i, Vector2(72, 84))
			var label := UiKit.row(cell)  # each keepsake's label: the outlaw's face and name
			var frame := PanelContainer.new()
			frame.theme_type_variation = &"PortraitFrame"
			label.add_child(frame)
			UiKit.image(frame, "portrait/ch%d" % i, Vector2(TROPHY_FACE, TROPHY_FACE))
			UiKit.text(label, GameState.chapters[i].who, &"Hint")
		UiKit.text(card, "%d of %d outlaws captured" % [got.size(), GameState.chapters.size()], &"Tip")
	UiKit.button(UiKit.row(card), "Back", &"GhostButton").pressed.connect(show_home)


## The Gunsmith and Profile screens are not part of this build yet.
func _not_yet(title: String, body: String) -> void:
	_office_backdrop()
	var card := _open_overlay()
	UiKit.text(card, title, &"Heading")
	UiKit.text(card, body, &"", 840)
	UiKit.button(UiKit.row(card), "Back", &"GhostButton").pressed.connect(show_home)


func _wallet_button(parent: Node) -> Button:
	var b := UiKit.button(parent, "%s  ›" % _money(int(GameState.progress.bucks)), &"Wallet")
	b.icon = Assets.texture("ui/coin")  # Bounty Dollars
	b.tooltip_text = "Bounty Dollars. Spend them at the Gunsmith."
	b.pressed.connect(_on_office_act.bind("gunsmith"))
	return b


static func _money(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func show_intro(chapter: int, index: int) -> void:
	ci = chapter
	li = index
	_start_level()
	var L := level.L
	var card := _open_overlay()
	UiKit.text(card, "%d. %s" % [li + 1, L.name], &"Heading")
	var pills := UiKit.row(card)
	if L.get("eli", false):
		UiKit.pill(pills, "Boss")
		UiKit.pill(pills, "3 stages")
	elif L.get("duel", false):
		UiKit.pill(pills, "Duel")
		UiKit.pill(pills, "%d hits" % int(L.hp))
	else:
		if not L.enemies.is_empty():
			UiKit.pill(pills, "%d outlaw%s" % [L.enemies.size(), "" if L.enemies.size() == 1 else "s"])
		if L.has("bottles"):
			UiKit.pill(pills, "%d bottles" % L.bottles.size())
		UiKit.pill(pills, "%d bullet%s" % [int(L.bullets), "" if int(L.bullets) == 1 else "s"])
		UiKit.pill(pills, "Par %d" % int(L.par))
	if L.has("story"):  # brief v2: one story line on the intro card
		UiKit.text(card, L.story.intro, &"Tip", 840)
	if L.get("puzzle", false) and level.hint_lvl >= 1:
		UiKit.text(card, "Clue: " + L.hint, &"Tip", 840)
	elif L.has("tip"):
		UiKit.text(card, L.tip, &"Tip", 840)
	# Say how the level starts: observation levels wait for your first shot, the rest don't.
	if level.observing:
		UiKit.text(card, "Take your time. Nobody draws until you fire.", &"Hint", 840)
	elif not L.get("duel", false):
		UiKit.text(card, "They're already shooting.", &"Hint", 840)
	var buttons := UiKit.row(card)
	UiKit.button(buttons, "Face him" if L.get("duel", false) else "Draw").pressed.connect(_go)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_chapter.bind(ci))


func _go() -> void:
	_close_overlay()
	level.go()


func restart() -> void:
	show_intro(ci, li)
	_go()


func _start_level() -> void:
	_end_level()
	_set_screen(null)
	_home_bar.visible = false
	level = Level.new()
	_world.add_child(level)
	level.setup(ci, li)
	level.callout.connect(_callout)
	level.callout_cleared.connect(_clear_callout)
	level.won.connect(_on_won)
	level.lost.connect(_on_lost)
	_layout()
	_hud.visible = true
	_lvl_label.text = "%d. %s" % [li + 1, level.L.name]
	_ammo_slots = -1


func _end_level() -> void:
	_clear_callout()
	_close_overlay()
	if level != null:
		level.queue_free()
		level = null
	_hud.visible = false


func _toggle_pause() -> void:
	if level == null:
		return
	if level.state == "pause":
		_close_overlay()
		level.resume()
	elif level.state == "play":
		level.pause()
		var card := _open_overlay()
		UiKit.text(card, "Paused", &"Heading")
		UiKit.button(card, "Resume").pressed.connect(_toggle_pause)
		var mus := UiKit.button(card, "Music: " + ("on" if AudioManager.music_on else "off"), &"GhostButton")
		mus.pressed.connect(func():
			AudioManager.set_music(not AudioManager.music_on)
			mus.text = "Music: " + ("on" if AudioManager.music_on else "off"))
		UiKit.button(card, "Levels", &"GhostButton").pressed.connect(show_chapter.bind(ci))
		UiKit.button(card, "Home", &"GhostButton").pressed.connect(show_home)


func _on_won(res: Dictionary) -> void:
	await get_tree().create_timer(0.35).timeout
	if level == null or level.state != "won":
		return
	var card := _open_overlay()
	UiKit.text(card, "Outlaw captured" if res.last else "Showdown won", &"Heading")
	UiKit.stars(card, res.stars, 80)
	if res.assisted:
		UiKit.text(card, "Assisted clear: two stars at most. Beat it on your own for the third.", &"Hint", 840)
	var line: String
	if level.duel != null:
		var taken := 3 - int(res.hearts)
		line = "Untouched" if taken == 0 else "%d hit%s taken" % [taken, "" if taken == 1 else "s"]
	else:
		line = "%d shot%s, par %d%s" % [res.used, "" if res.used == 1 else "s", int(level.L.par), "" if res.damaged else ", untouched"]
	UiKit.text(card, line, &"Tip")
	if level.L.has("story"):  # brief v2: the next story beat on the result screen
		UiKit.text(card, level.L.story.result, &"Hint", 840)
	if res.pay:
		var pay := UiKit.row(card)
		UiKit.image(pay, "ui/coin", Vector2(40, 40))
		UiKit.text(pay, "+%s" % _money(res.pay), &"Pay")
	var buttons := UiKit.row(card)
	if res.last:
		# The stamp lands on the poster when the office next opens (officeFresh).
		if res.get("captured", false):
			_fresh_capture = ci
		UiKit.button(buttons, "See the bounty board").pressed.connect(show_board)
		UiKit.button(buttons, "Home", &"GhostButton").pressed.connect(show_home)
		return
	if GameState.level_open(ci, li + 1):
		UiKit.button(buttons, "Next showdown").pressed.connect(show_intro.bind(ci, li + 1))
	UiKit.button(buttons, "Retry", &"GhostButton").pressed.connect(restart)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_chapter.bind(ci))


func _offer_text(offer: String) -> Array:
	match offer:
		"hint":
			return ["STUCK, PARTNER?", "There’s more than one way to take down an outlaw.",
				"Watch ad: show me where to look" if level.hint_lvl >= 1 else "Watch ad: reveal a clue"]
		"continue":
			return ["NOT DEAD YET!", "Keep the rounds you’ve won and replay this one.", "Watch ad: keep your rounds"]
		"checkpoint":
			return ["NOT DEAD YET!", "You reached stage %d. Pick up from there with full hearts." % level.eli_ck,
				"Watch ad: retry from stage %d" % level.eli_ck]
	return []


func _on_lost(reason: String, offer: Variant) -> void:
	await get_tree().create_timer(0.45).timeout
	if level == null or level.state != "lost":
		return
	_show_fail(reason, offer)


func _show_fail(reason: String, offer: Variant) -> void:
	var card := _open_overlay()
	var L := level.L
	var clue := ""
	if L.get("puzzle", false) and level.hint_lvl >= 1:
		clue = "Clue: " + L.hint + (" The key spot now glows when you play." if level.hint_lvl >= 2 else "")
	if offer != null:
		var o := _offer_text(offer)
		UiKit.text(card, o[0], &"Heading")
		UiKit.text(card, o[1], &"", 840)
		if clue != "":
			UiKit.text(card, clue, &"Tip", 840)
		if AdsManager.available():
			UiKit.button(UiKit.row(card), o[2]).pressed.connect(_use_offer.bind(offer, reason))
		else:
			UiKit.button(UiKit.row(card), "No ad available right now").disabled = true
		UiKit.text(card, "Using this caps the clear at two stars.", &"Hint")
	else:
		UiKit.text(card, reason, &"Heading")
		UiKit.text(card, clue if clue != "" else L.get("tip", "Watch them first, then try again."), &"Hint", 840)
	var buttons := UiKit.row(card)
	var retry_label := "Try again"
	if offer != null:
		retry_label = "Start over, free" if L.get("eli", false) else "Retry level, free"
	UiKit.button(buttons, retry_label, &"GhostButton").pressed.connect(restart)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_chapter.bind(ci))


func _use_offer(offer: String, reason: String) -> void:
	_close_overlay()
	AdsManager.show_rewarded(offer, func(granted: bool):
		if level == null:
			return
		if not granted:
			_show_fail(reason, offer)
		elif offer == "hint":
			_grant_hint()
		elif offer == "checkpoint":
			var n := level.eli_ck
			show_intro(ci, li)  # no checkpoints: a fresh Iron Eli, moved on to the stage reached
			_close_overlay()
			level.resume_from_stage(n)
		else:
			level.grant_offer(offer))


func _grant_hint() -> void:
	GameState.raise_hint_level(ci, li)
	var lvl := GameState.hint_level(ci, li)
	var card := _open_overlay()
	UiKit.text(card, "Here’s your clue", &"Heading")
	UiKit.text(card, level.L.hint, &"Tip", 840)
	if lvl >= 2:
		UiKit.text(card, "The key spot will glow while you play.", &"Hint")
	UiKit.button(UiKit.row(card), "Try again with the clue").pressed.connect(restart)


# ---------- HUD ----------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	_hud_box = MarginContainer.new()
	_hud_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_box.add_theme_constant_override("margin_top", 14)
	_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_box)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_box.add_child(bar)
	# Hearts and bullets on a wooden panel (theme "HudPanel"), the level name on a brass plaque ("HudPlaque").
	var left := PanelContainer.new()
	left.theme_type_variation = &"HudPanel"
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(left)
	var stock := HBoxContainer.new()
	stock.add_theme_constant_override("separation", 16)
	left.add_child(stock)
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 4)
	hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	stock.add_child(hearts)
	for i in 3:
		_hearts.append(UiKit.image(hearts, "ui/heart_full"))
	_ammo = HBoxContainer.new()
	_ammo.add_theme_constant_override("separation", BULLET_GAP)  # clear gaps, so they're easy to count
	_ammo.alignment = BoxContainer.ALIGNMENT_CENTER
	stock.add_child(_ammo)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	var name_panel := PanelContainer.new()
	name_panel.theme_type_variation = &"HudPlaque"
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.add_child(name_panel)
	_lvl_label = UiKit.text(name_panel, "", &"HudPlaqueLabel")
	_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lvl_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # always one line
	_sound_btn = UiKit.icon_button(bar, "ui/icon_sound_on")
	_sound_btn.pressed.connect(func():
		AudioManager.set_sound(not AudioManager.sound_on)
		_sound_btn.icon = Assets.texture("ui/icon_sound_on" if AudioManager.sound_on else "ui/icon_sound_off"))
	UiKit.icon_button(bar, "ui/icon_restart").pressed.connect(func():
		if level != null and level.state in ["play", "pause", "won", "lost"]:
			restart())
	UiKit.icon_button(bar, "ui/icon_pause").pressed.connect(_toggle_pause)
	_hud.visible = false

	_call_layer = CanvasLayer.new()
	_call_layer.layer = 6
	add_child(_call_layer)
	_call_label = UiKit.text(_call_layer, "", &"Callout")
	_call_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_call_label.anchor_top = 0.26
	_call_label.anchor_bottom = 0.26
	_call_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call_label.modulate.a = 0.0


func _process(_delta: float) -> void:
	if level == null:
		return
	for i in 3:
		_hearts[i].texture = Assets.texture("ui/heart_full" if i < level.hearts else "ui/heart_empty")
	# Iron Eli's chase tops bullets up past the level's count; duels show none.
	var want := 0 if level.duel != null else maxi(int(level.L.get("bullets", 0)), level.bullets)
	if want != _ammo_slots:
		_ammo_slots = want
		for c in _ammo.get_children():
			c.queue_free()
			_ammo.remove_child(c)
		for i in want:
			UiKit.image(_ammo, "ui/bullet_full", BULLET_SIZE)
	var slots := _ammo.get_children()
	for i in slots.size():
		slots[i].texture = Assets.texture("ui/bullet_full" if i < level.bullets else "ui/bullet_empty")


func _callout(msg: String, small: bool, ms: int) -> void:
	_call_token += 1
	var token := _call_token
	_call_label.text = msg
	_call_label.theme_type_variation = &"CalloutSmall" if small else &"Callout"
	_call_label.pivot_offset = _call_label.size / 2
	if _call_tween:
		_call_tween.kill()
	_call_label.scale = Vector2(0.9, 0.9)
	_call_tween = create_tween().set_parallel()
	_call_tween.tween_property(_call_label, "modulate:a", 1.0, 0.12)
	_call_tween.tween_property(_call_label, "scale", Vector2.ONE, 0.12)
	if ms > 0:
		await get_tree().create_timer(ms / 1000.0).timeout
		if token == _call_token:
			_clear_callout()


func _clear_callout() -> void:
	_call_token += 1
	if _call_tween:
		_call_tween.kill()
	_call_tween = create_tween()
	_call_tween.tween_property(_call_label, "modulate:a", 0.0, 0.12)


# ---------- overlays ----------

func _open_overlay() -> VBoxContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay)
	var center := UiKit.overlay(_overlay)
	center.offset_bottom = -_safe_lrb.z  # centred in the safe area, above the home indicator
	return UiKit.card(center)


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
