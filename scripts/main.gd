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
## The first launch's run through Main Street level 1: its result card leads to the office.
var tutorial := false
var _home_bar: CanvasLayer
var _home_box: MarginContainer
var _wallet: Button
var _hud: CanvasLayer
var _hud_box: MarginContainer
var _hearts: Array[TextureRect] = []
var _ammo: HBoxContainer
var _ammo_slots := -1
var _call_layer: CanvasLayer
var _call_label: Label
var _call_tween: Tween
var _call_token := 0
var _overlay_layer: CanvasLayer
var _overlay: Control
## The open overlay's card column.
var _card: VBoxContainer
## The Bounty board wall, while it is open.
var board: BountyWall
## Debug views (debug builds only): the whole screen in greyscale (G on a keyboard, or the pause menu),
## and every hit area drawn over the level (H, or the pause menu; Level.show_hit_areas).
static var greyscale := false
var _grey_layer: CanvasLayer
## The new feel's player hit: the red glow at the screen's edges.
var _vignette: ColorRect


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	_build_hud()
	_build_home_bar()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	_grey_layer = CanvasLayer.new()
	_grey_layer.layer = 1100  # above everything, the skins' final layer (1000) too
	var grey := ColorRect.new()
	grey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grey.material = ShaderMaterial.new()
	grey.material.shader = load("res://ui/debug_greyscale.gdshader")
	_grey_layer.add_child(grey)
	add_child(_grey_layer)
	set_greyscale(greyscale)
	get_viewport().size_changed.connect(_layout)
	CloudSync.merged.connect(func():
		if _screen is Office and _overlay == null:
			show_home())  # another device's progress arrived: refresh the office
	_layout()
	show_splash()


## The office's top bar: only the Bounty Dollars wallet, in the top left corner, clear of the GUNSMITH
## sign. (Music is in the pause menu and on each bounty's hunt screen.)
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
	_wallet = _wallet_button(bar)
	_home_bar.visible = false


func _refresh_home_bar() -> void:
	_wallet.text = _money(int(GameState.progress.bucks))


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
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			set_greyscale(not greyscale)
		elif event.keycode == KEY_S:
			FeedbackDirector.set_slow(not FeedbackDirector.slow)
		elif event.keycode == KEY_F:
			FeedbackDirector.force_old = not FeedbackDirector.force_old
		elif event.keycode == KEY_H:
			Level.show_hit_areas = not Level.show_hit_areas
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


## The new feel's player hit: the heart that has just emptied swells and settles, and the screen's edges
## glow red for a moment.
func _on_player_hurt(hearts_left: int) -> void:
	var F: FeelConfig = FeedbackDirector.feel
	if hearts_left >= 0 and hearts_left < _hearts.size():
		var h := _hearts[hearts_left]
		h.pivot_offset = h.size / 2
		FeedbackDirector.animate(h, "swell", Vector2.ONE, Vector2.ONE * F.heart_pulse_scale, F.heart_pulse_time * 0.3, func(v: Vector2): h.scale = v)
		FeedbackDirector.animate(h, "settle", Vector2.ONE * F.heart_pulse_scale, Vector2.ONE, F.heart_pulse_time * 0.7, func(v: Vector2): h.scale = v, F.heart_pulse_time * 0.3, "back")
	var m := _vignette.material as ShaderMaterial
	FeedbackDirector.animate(_vignette, "glow", F.vignette_alpha, 0.0, F.vignette_time, func(v: float): m.set_shader_parameter("amount", v))


func set_greyscale(on: bool) -> void:
	greyscale = on
	_grey_layer.visible = on


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


## The splash standoff; its second tap fades to the office. On the first launch (or after a reset) it
## goes straight into Main Street level 1 instead, and the office opens after that level's result.
func show_splash() -> void:
	_end_level()
	_home_bar.visible = false
	var s := Splash.new()
	_set_screen(s)
	s.finished.connect(func():
		if GameState.first_launch(GameState.progress):
			start_tutorial()
		else:
			show_home())


func start_tutorial() -> void:
	tutorial = true
	show_intro(0, 0)


## The sheriff's office (the prototype's home()).
func show_home() -> void:
	_end_level()
	tutorial = false
	if not GameState.progress.get("tutorialDone", false):  # the office has been reached: later launches come straight here
		GameState.progress.tutorialDone = true
		GameState.save()
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


## Continue the hunt: the next unfinished level of the current hunt; the Bounty board when no built
## bounty has levels left.
func hunt() -> void:
	var next: Variant = GameState.next_unfinished(GameState.progress, GameState.playtest())
	if next == null:
		show_board()
		return
	show_intro(next.ch, next.level)


## The HUD's cartridges: big enough to count at a glance on a phone.
const BULLET_SIZE := Vector2(24, 56)
const BULLET_GAP := 12
## The outlaw's wanted poster on his hunt screen (its height), and his face on his keepsake's label in
## the trophy cabinet.
const HUNT_POSTER := 104.0
const TROPHY_FACE := 48.0
## How long a replay's intro shows (s) before the showdown starts by itself.
const REPLAY_INTRO := 1.2
## The intro card is centred in this top fraction of the screen, clear of the outlaws on the street.
const INTRO_BAND := 0.6
## The result's stars above its card: the middle one, and the two beside it.
const STAR_BIG := 124.0
const STAR_SMALL := 96.0
## A boss's face on his intro card, and stamped CAPTURED on his capture card.
const BOSS_FACE := 96.0
const CAPTURE_FACE := 140.0


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
			b.icon = Assets.texture("ui/icon_lock_light")  # (cream, on a teal pill)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 30)
		b.pressed.connect(show_intro.bind(c, i))
		UiKit.stars(cell, GameState.stars_in(GameState.progress, c, i), 32)
	UiKit.button(UiKit.row(card), "Settings", &"SmallGhostButton").pressed.connect(show_settings.bind(c))


## Settings (from a bounty's level grid): sound, music, reduced shake, all levels open, and Reset progress.
func show_settings(c: int) -> void:
	_office_backdrop()
	var card := _open_overlay()
	UiKit.text(card, "Settings", &"Heading")
	var row1 := UiKit.row(card)
	var snd := UiKit.button(row1, "Sound: " + ("on" if AudioManager.sound_on else "off"), &"GhostButton")
	snd.pressed.connect(func():
		AudioManager.set_sound(not AudioManager.sound_on)
		show_settings(c))
	var mus := UiKit.button(row1, "Music: " + ("on" if AudioManager.music_on else "off"), &"GhostButton")
	mus.pressed.connect(func():
		AudioManager.set_music(not AudioManager.music_on)
		show_settings(c))
	var row2 := UiKit.row(card)
	var shk := UiKit.button(row2, "Screen shake: " + ("reduced" if FeedbackDirector.reduced_shake else "full"), &"GhostButton")
	shk.pressed.connect(func():
		FeedbackDirector.set_reduced_shake(not FeedbackDirector.reduced_shake)
		show_settings(c))
	var pt := UiKit.button(row2, "All levels open: " + ("on" if GameState.playtest() else "off"), &"GhostButton")
	pt.pressed.connect(func():
		SaveManager.set_setting("playtest", not GameState.playtest())
		show_settings(c))
	var row3 := UiKit.row(card)
	UiKit.button(row3, "Reset progress", &"SmallGhostButton").pressed.connect(_confirm_reset.bind(c))
	UiKit.button(row3, "Back", &"SmallGhostButton").pressed.connect(show_chapter.bind(c))


## Reset progress, after a confirmation: every star, capture, Bounty Dollar, gun and clue goes, here
## and in iCloud (sound and music stay), and the game starts again from the splash, as on the first launch.
func _confirm_reset(c: int) -> void:
	var card := _open_overlay()
	UiKit.text(card, "Reset progress?", &"Heading")
	UiKit.text(card, "This wipes every star, capture, Bounty Dollar, gun and clue, on this phone and in iCloud. Sound and music settings stay. It can’t be undone.", &"", 840)
	var buttons := UiKit.row(card)
	UiKit.button(buttons, "Keep my progress").pressed.connect(show_settings.bind(c))
	UiKit.button(buttons, "Reset everything", &"GhostButton").pressed.connect(reset_progress)


func reset_progress() -> void:
	SaveManager.reset_progress()
	_fresh_capture = null
	show_splash()


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
	if got.is_empty() and GameState.keepsakes_earned(pg).is_empty():
		UiKit.text(card, "The shelves are bare. Capture Iron Eli to win your first trophy.", &"", 840)
	elif got.is_empty():
		UiKit.text(card, "Capture Iron Eli to win the bounty's trophy.", &"Hint", 840)
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
	var keeps: Array = GameState.keepsakes_earned(pg)
	if not keeps.is_empty():  # the bosses' keepsakes, beside the bounties' trophies
		var shelf := UiKit.row(card)
		shelf.add_theme_constant_override("separation", 24)
		for k in keeps:
			var cell := VBoxContainer.new()
			shelf.add_child(cell)
			UiKit.image(cell, "keepsake/" + k.art, Vector2(48, 70))
			UiKit.text(cell, k.name, &"Hint")
	UiKit.button(UiKit.row(card), "Back", &"GhostButton").pressed.connect(show_home)


## A boss's portrait in its frame; on his capture card, stamped CAPTURED.
func _portrait(parent: Node, asset: String, size: float, captured: bool) -> void:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"PortraitFrame"
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(frame)
	var pic := UiKit.image(frame, asset, Vector2(size, size))
	if not captured:
		return
	var stamp := UiKit.image(pic, "ui/stamp_captured", Vector2(size * 0.9, size * 0.9 * 0.55))  # as on the posters (the art is tilted)
	stamp.size = stamp.custom_minimum_size
	stamp.position = Vector2(size * 0.05, size * 0.98 - stamp.size.y)  # low on his chest, clear of his eyes
	stamp.modulate.a = 0.92


## The Gunsmith and Profile screens are not part of this build yet.
func _not_yet(title: String, body: String) -> void:
	_office_backdrop()
	var card := _open_overlay()
	UiKit.text(card, title, &"Heading")
	UiKit.text(card, body, &"", 840)
	UiKit.button(UiKit.row(card), "Back", &"GhostButton").pressed.connect(show_home)


## The Bounty Dollars counter: the number on a paper tag, the coin breaking out of its left edge.
func _wallet_button(parent: Node) -> Button:
	var b := UiKit.button(parent, _money(int(GameState.progress.bucks)), &"Wallet")
	b.custom_minimum_size.y = UiKit.TAP
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin := TextureRect.new()
	coin.texture = Assets.texture("ui/coin")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.custom_minimum_size = Vector2(76, 79)
	UiKit.attach(b, coin, Vector2(0, 0.5), Vector2(28, -4))
	UiKit.tilt(b, -2)
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
	var card := _open_overlay(true)
	var panel := UiKit.panel_of(card)
	var badge := PanelContainer.new()  # the level number on a teal badge, breaking out of the top-left corner
	badge.theme_type_variation = &"Badge"
	badge.custom_minimum_size = Vector2(92, 98)
	var num := UiKit.text(badge, str(li + 1), &"BadgeLabel")
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.attach(panel, badge, Vector2(0, 0), Vector2(18, 14))
	UiKit.tilt(badge, -6)
	var tack := TextureRect.new()  # pinned
	tack.texture = Assets.texture("ui/tack")
	tack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tack.custom_minimum_size = Vector2(30, 30)
	UiKit.attach(panel, tack, Vector2(0.5, 0), Vector2(0, 14))
	var title_box: Node = card
	if L.has("portrait"):  # a boss: his face beside his name
		var head := UiKit.row(card)
		head.add_theme_constant_override("separation", 18)
		_portrait(head, L.portrait, BOSS_FACE, false)
		title_box = VBoxContainer.new()
		title_box.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(title_box)
	UiKit.text(title_box, L.name.to_upper(), &"Heading")
	_level_chips(title_box, L)
	if replay_intro(ci, li):  # a level already beaten: the title and chips for a moment, or a tap, then play
		_quick_start()
		return
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
	var levels: Array = [] if tutorial else [["ui/icon_levels", "Levels", show_chapter.bind(ci)]]
	_edge_buttons(card, "Face him!" if L.get("duel", false) else "Draw!", _go, levels, [])



## A level's facts as teal chips: its outlaws, bullets and par, or what kind of fight it is.
func _level_chips(parent: Node, L: Dictionary) -> HBoxContainer:
	var pills := UiKit.row(parent)
	if L.has("jack"):
		UiKit.pill(pills, "Boss")
		UiKit.pill(pills, "3 phases")
		UiKit.pill(pills, "%d bullets" % int(L.bullets))
		UiKit.pill(pills, "Par %d" % int(L.par))
	elif L.get("eli", false):
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
	return pills


## On a replay the intro is only a glance: it starts by itself after REPLAY_INTRO seconds, or at once on a tap.
func replay_intro(c: int, l: int) -> bool:
	return not tutorial and GameState.stars_in(GameState.progress, c, l) > 0


func _quick_start() -> void:
	UiKit.text(_card, "Tap to start", &"Hint")
	var shade: Control = _overlay.get_child(0)
	var card_overlay := _overlay
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and _overlay == card_overlay:
			get_viewport().set_input_as_handled()
			_go())
	get_tree().create_timer(REPLAY_INTRO).timeout.connect(func():
		if _overlay == card_overlay and level != null and level.state == "intro":
			_go())

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
		_hud.visible = true
	elif level.state == "play":
		level.pause()
		_pause_card()


## The pause menu: Resume (the main action), music and restart, levels and home; debug toggles in debug builds.
func _pause_card() -> void:
	var card := _open_overlay()
	_hud.visible = false  # the menu has the screen to itself, as in the mockup
	var shade: Control = _overlay.get_child(0)
	var title := UiKit.text(shade, "PAUSED", &"BigTitle")  # big, over the dimmed street
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 18
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UiKit.tilt(title, -2)
	UiKit.pop_in(title, 0.0, 0.8)
	# The level: its name, chips and best stars.
	UiKit.text(card, level.L.name.to_upper(), &"Heading")
	_level_chips(card, level.L)
	var best := UiKit.row(card)
	UiKit.text(best, "Your best", &"Hint")
	UiKit.stars(best, GameState.stars_in(GameState.progress, ci, li), 52)
	# The strip of round buttons down the left edge.
	var strip := PanelContainer.new()
	strip.theme_type_variation = &"Strip"
	shade.add_child(strip)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	strip.add_child(col)
	UiKit.round_button(col, "ui/icon_play", "Resume", "orange", 100).pressed.connect(_toggle_pause)
	UiKit.round_button(col, "ui/icon_restart", "Restart").pressed.connect(_confirm_restart)
	var snd := UiKit.round_button(col, _sound_icon(), "Sound")
	snd.pressed.connect(func():
		AudioManager.set_sound(not AudioManager.sound_on)
		snd.icon = Assets.texture(_sound_icon()))
	var mus := UiKit.round_button(col, _music_icon(), "Music")
	mus.pressed.connect(func():
		AudioManager.set_music(not AudioManager.music_on)
		mus.icon = Assets.texture(_music_icon()))
	var hap := UiKit.round_button(col, _haptics_icon(), "Haptics")
	hap.pressed.connect(func():
		Haptics.set_enabled(not Haptics.enabled)
		hap.icon = Assets.texture(_haptics_icon()))
	UiKit.round_button(col, "ui/icon_home", "Back to the office", "teal").pressed.connect(show_home)
	strip.size = strip.get_combined_minimum_size()
	strip.position = Vector2(_safe_lrb.x + 18, (shade.size.y - _safe_lrb.z - strip.size.y) / 2)
	UiKit.tilt(strip, 1)
	UiKit.pop_in(strip, 0.05, 0.85)
	if OS.is_debug_build():  # testing aids
		var dbg := UiKit.row(card)  # one row: greyscale, hit areas, 25% speed, old or new feel
		var g := UiKit.button(dbg, "Grey: " + ("on" if greyscale else "off"), &"SmallGhostButton")
		g.pressed.connect(func():
			set_greyscale(not greyscale)
			g.text = "Grey: " + ("on" if greyscale else "off"))
		var h := UiKit.button(dbg, "Hits: " + ("on" if Level.show_hit_areas else "off"), &"SmallGhostButton")
		h.pressed.connect(func():
			Level.show_hit_areas = not Level.show_hit_areas
			h.text = "Hits: " + ("on" if Level.show_hit_areas else "off"))
		var s := UiKit.button(dbg, "Slow: " + ("on" if FeedbackDirector.slow else "off"), &"SmallGhostButton")
		s.pressed.connect(func():
			FeedbackDirector.set_slow(not FeedbackDirector.slow)
			s.text = "Slow: " + ("on" if FeedbackDirector.slow else "off"))
		var f := UiKit.button(dbg, "Feel: " + ("old" if FeedbackDirector.force_old else "new"), &"SmallGhostButton")
		f.disabled = not level.L.get("feel", false)  # only flagged levels have the new feel to compare
		f.pressed.connect(func():
			FeedbackDirector.force_old = not FeedbackDirector.force_old
			f.text = "Feel: " + ("old" if FeedbackDirector.force_old else "new"))


func _sound_icon() -> String:
	return "ui/icon_sound_on" if AudioManager.sound_on else "ui/icon_sound_off"


func _music_icon() -> String:
	return "ui/icon_music" if AudioManager.music_on else "ui/icon_music_off"


func _haptics_icon() -> String:
	return "ui/icon_haptics" if Haptics.enabled else "ui/icon_haptics_off"


## Restart, from the pause menu: asked first, so a stray tap never throws a run away.
func _confirm_restart() -> void:
	var card := _open_overlay()
	UiKit.text(card, "RESTART?", &"Heading")
	UiKit.text(card, "You start again from the beginning, with every bullet back.", &"Hint", 600)
	var buttons := UiKit.row(card)
	UiKit.button(buttons, "Restart", &"PrimaryButton").pressed.connect(restart)
	UiKit.button(buttons, "Keep playing", &"GhostButton").pressed.connect(_pause_card)


func _on_won(res: Dictionary) -> void:
	await get_tree().create_timer(0.35).timeout
	if level == null or level.state != "won":
		return
	var card := _open_overlay()
	var boss: bool = level.L.has("portrait")
	if boss:  # the capture moment: his portrait stamped CAPTURED beside the stars
		var head := UiKit.row(card)
		head.add_theme_constant_override("separation", 22)
		_portrait(head, level.L.portrait, CAPTURE_FACE, true)
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(right)
		UiKit.text(right, "%s CAPTURED!" % level.L.name.to_upper(), &"Heading")
	else:
		UiKit.text(card, "OUTLAW CAPTURED!" if res.last else "SHOWDOWN WON!", &"Heading")
	_breakout_stars(card, res.stars)
	if res.assisted:
		UiKit.text(card, "Assisted clear: two stars at most. Beat it on your own for the third.", &"Hint", 840)
	var chips := UiKit.row(card)  # the result as chips
	if level.duel != null:
		var taken := 3 - int(res.hearts)
		UiKit.pill(chips, "Untouched" if taken == 0 else "%d hit%s taken" % [taken, "" if taken == 1 else "s"])
	else:
		UiKit.pill(chips, "%d shot%s" % [res.used, "" if res.used == 1 else "s"])
		UiKit.pill(chips, "Par %d" % int(level.L.par))
		if not res.damaged:
			UiKit.pill(chips, "Untouched")
	if level.L.has("story"):  # brief v2: the next story beat on the result screen
		UiKit.text(card, level.L.story.result, &"Hint", 840)
	var keep: Dictionary = GameState.keepsake_for(ci, li)
	if not (keep.is_empty() or Assets.has("keepsake/" + keep.art)):
		keep = {}  # its art arrives with its boss
	if res.pay or not keep.is_empty():
		var pay := UiKit.row(card)
		pay.add_theme_constant_override("separation", 14)
		if res.pay:
			UiKit.image(pay, "ui/coin", Vector2(56, 58))
			UiKit.text(pay, "+%s" % _money(res.pay), &"Pay")
		if not keep.is_empty() and Assets.has("keepsake/" + keep.art):  # his keepsake, for the trophy cabinet
			UiKit.image(pay, "keepsake/" + keep.art, Vector2(30, 44))
			UiKit.text(pay, "Keepsake: " + keep.name, &"Tip")
	# The main action, the largest (one tap on to the next showdown), with round teal Retry and Levels beside it.
	var retry := ["ui/icon_restart", "Retry", restart]
	if tutorial:  # the first launch's level: on to the office
		_edge_buttons(card, "On to the office", show_home, [retry], [])
		return
	if res.last:
		# The stamp lands on the poster when the office next opens (officeFresh).
		if res.get("captured", false):
			_fresh_capture = ci
		_edge_buttons(card, "Bounty board", show_board, [retry], [["ui/icon_home", "Back to the office", show_home]])
		return
	var levels := ["ui/icon_levels", "Levels", show_chapter.bind(ci)]
	if GameState.level_open(ci, li + 1):
		_edge_buttons(card, "Next showdown", show_intro.bind(ci, li + 1), [retry], [levels])
	else:
		_edge_buttons(card, "Retry", restart, [], [levels])


## The result's stars, breaking out above the card: the middle one bigger, each bouncing in after the last.
func _breakout_stars(card: VBoxContainer, count: int) -> void:
	var spacer := Control.new()  # room under them on the card
	spacer.custom_minimum_size.y = 40
	card.add_child(spacer)
	card.move_child(spacer, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for k in 3:
		var s := UiKit.image(row, "ui/star_on" if k < count else "ui/star_off", Vector2.ONE * (STAR_BIG if k == 1 else STAR_SMALL))
		s.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if k == 1 else Control.SIZE_SHRINK_CENTER
		UiKit.tilt(s, [-12.0, 0.0, 12.0][k])
		UiKit.pop_in(s, 0.2 + k * 0.14, 0.3)
	UiKit.attach(UiKit.panel_of(card), row, Vector2(0.5, 0), Vector2(0, -6))


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
		UiKit.text(card, o[0].to_upper(), &"HeadingDanger")
		UiKit.text(card, o[1], &"", 840)
		if clue != "":
			UiKit.text(card, clue, &"Tip", 840)
		if AdsManager.available():
			UiKit.button(UiKit.row(card), o[2]).pressed.connect(_use_offer.bind(offer, reason))
		else:
			UiKit.button(UiKit.row(card), "No ad available right now").disabled = true
		UiKit.text(card, "Using this caps the clear at two stars.", &"Hint")
	else:
		UiKit.text(card, reason.to_upper(), &"HeadingDanger")
		UiKit.text(card, clue if clue != "" else L.get("tip", "Watch them first, then try again."), &"Hint", 840)
	var retry_label := "Try again"
	if offer != null:
		retry_label = "Start over, free" if L.get("eli", false) else "Retry, free"
	var away: Array = ["ui/icon_home", "Sheriff’s office", show_home] if tutorial else ["ui/icon_levels", "Levels", show_chapter.bind(ci)]
	_edge_buttons(card, retry_label, restart, [], [away])


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
	_vignette = ColorRect.new()  # under the HUD, over the street
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = ShaderMaterial.new()
	_vignette.material.shader = load("res://ui/vignette.gdshader")
	_hud.add_child(_vignette)
	FeedbackDirector.player_hurt.connect(_on_player_hurt)
	add_child(_hud)
	_hud_box = MarginContainer.new()
	_hud_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_box.add_theme_constant_override("margin_top", 14)
	_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_box)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_box.add_child(bar)
	# Hearts and bullets straight over the scene (outlined, with their own hard shadows), and one round orange
	# pause button. The level's name, sound and restart are in the pause menu.
	var left := PanelContainer.new()
	left.theme_type_variation = &"HudPill"
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	UiKit.round_button(bar, "ui/icon_pause", "Pause").pressed.connect(_toggle_pause)
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

## An overlay with its card: centred in the safe area, or `top`: in the upper part of the screen (the
## intro, so the outlaws below stay in view).
func _open_overlay(top := false) -> VBoxContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay)
	var center := UiKit.overlay(_overlay)
	center.offset_bottom = -_safe_lrb.z  # centred in the safe area, above the home indicator
	if top:
		center.anchor_bottom = INTRO_BAND
		center.offset_bottom = 0
		center.offset_top = 46  # room for the badge breaking out above the card
	_card = UiKit.card(center)
	return _card


## The main action and its round companions on a card's bottom edge, breaking out of it (the mockup's
## DRAW! and NEXT SHOWDOWN). left and right: [[icon, label, Callable], ...] round teal buttons beside it.
## A spacer keeps the card's text clear of them.
func _edge_buttons(card: VBoxContainer, main_label: String, main_action: Callable, left: Array, right: Array) -> Button:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 34
	card.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for b in left:
		UiKit.round_button(row, b[0], b[1], "teal").pressed.connect(b[2])
	var big := UiKit.button(row, main_label.to_upper(), &"BigPrimaryButton")
	big.custom_minimum_size.x = 340
	big.pressed.connect(main_action)
	for b in right:
		UiKit.round_button(row, b[0], b[1], "teal").pressed.connect(b[2])
	UiKit.attach(UiKit.panel_of(card), row, Vector2(0.5, 1.0), Vector2(0, 6))
	UiKit.pop_in(big, 0.18)
	return big


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
