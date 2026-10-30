extends Node
## Screens and HUD around a Level: the level picker, intro card, win and fail
## cards with the Second Chance offer, and pause. The look comes from the
## shared theme (ui/theme.tres) and the asset manifest; nothing is drawn here.
##
## The game fills the screen: the 640×360 stage is centred and wide phones see
## more of the street's background layers at the sides. HUD controls follow the
## real screen edges, inside the safe area.

const BASE := Vector2(640, 360)

var level: Level
var ci := 0
var li := 0

var _world: Node2D
var _backdrop: Node2D
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


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	_backdrop = Node2D.new()
	_world.add_child(_backdrop)
	var art: Dictionary = Assets.scenes["main_street"]
	for layer in art.layers:
		AssetSprite.make(layer, _backdrop)
	var windows: Array = GameState.scenes.street.windows
	var ppu: float = GameState.geometry.pixels_per_unit
	for i in windows.size():
		AssetSprite.make(art.window_frames[i], _backdrop).position = Vector2(windows[i].x, windows[i].y) * ppu
	_build_hud()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_menu()


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
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := vis / win if win.x > 0 and win.y > 0 else Vector2.ONE
	var left := maxf(0, safe.position.x) * k.x if safe.size.x > 0 else 0.0
	var right := maxf(0, win.x - safe.end.x) * k.x if safe.size.x > 0 else 0.0
	_hud_box.add_theme_constant_override("margin_left", int(12 + left))
	_hud_box.add_theme_constant_override("margin_right", int(12 + right))


# ---------- input ----------

func _input(event: InputEvent) -> void:
	# Music never starts before the first tap (audio.md).
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		AudioManager.unlock()


func _unhandled_input(event: InputEvent) -> void:
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

func show_menu() -> void:
	_end_level()
	AudioManager.play("office")
	var card := _open_overlay()
	var ch: Dictionary = GameState.chapters[0]
	UiKit.text(card, ch.name, &"Heading")
	UiKit.text(card, "%s, %s. Gold levels are duels." % [ch.who, ch.reward], &"Hint")
	var grid := GridContainer.new()
	grid.columns = 5
	card.add_child(grid)
	var lvls: Array = GameState.levels_for(0)
	for i in lvls.size():
		var lv: Dictionary = lvls[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var duel_level: bool = lv.get("duel", false) or lv.get("eli", false)
		var b := UiKit.button(cell, str(i + 1), &"" if duel_level else &"GhostButton")
		b.custom_minimum_size = Vector2(88, 0)
		b.tooltip_text = lv.name
		b.disabled = not GameState.level_open(0, i)
		b.pressed.connect(show_intro.bind(0, i))
		UiKit.stars(cell, GameState.stars_in(GameState.progress, 0, i), 16)
	var settings := UiKit.row(card)
	var pt := UiKit.button(settings, "All levels open: " + ("on" if GameState.playtest() else "off"), &"SmallGhostButton")
	pt.pressed.connect(func():
		SaveManager.set_setting("playtest", not GameState.playtest())
		show_menu())
	var snd := UiKit.button(settings, "Sound: " + ("on" if AudioManager.sound_on else "off"), &"SmallGhostButton")
	snd.pressed.connect(func():
		AudioManager.set_sound(not AudioManager.sound_on)
		show_menu())
	var mus := UiKit.button(settings, "Music: " + ("on" if AudioManager.music_on else "off"), &"SmallGhostButton")
	mus.pressed.connect(func():
		AudioManager.set_music(not AudioManager.music_on)
		show_menu())


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
		UiKit.pill(pills, "%d outlaw%s" % [L.enemies.size(), "" if L.enemies.size() == 1 else "s"])
		if L.has("bottles"):
			UiKit.pill(pills, "%d bottles" % L.bottles.size())
		UiKit.pill(pills, "%d bullets" % int(L.bullets))
		UiKit.pill(pills, "Par %d" % int(L.par))
	if L.get("puzzle", false) and level.hint_lvl >= 1:
		UiKit.text(card, "Clue: " + L.hint, &"Tip", 420)
	else:
		UiKit.text(card, L.tip, &"Tip", 420)
	var buttons := UiKit.row(card)
	UiKit.button(buttons, "Face him" if L.get("duel", false) else "Draw").pressed.connect(_go)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_menu)


func _go() -> void:
	_close_overlay()
	level.go()


func restart() -> void:
	show_intro(ci, li)
	_go()


func _start_level() -> void:
	_end_level()
	_backdrop.visible = false
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
	_backdrop.visible = true
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
		UiKit.button(card, "Levels", &"GhostButton").pressed.connect(show_menu)


func _on_won(res: Dictionary) -> void:
	await get_tree().create_timer(0.35).timeout
	if level == null or level.state != "won":
		return
	var card := _open_overlay()
	UiKit.text(card, "Outlaw captured" if res.last else "Showdown won", &"Heading")
	UiKit.stars(card, res.stars, 40)
	if res.assisted:
		UiKit.text(card, "Assisted clear: two stars at most. Beat it on your own for the third.", &"Hint", 420)
	var line: String
	if level.duel != null:
		var taken := 3 - int(res.hearts)
		line = "Untouched" if taken == 0 else "%d hit%s taken" % [taken, "" if taken == 1 else "s"]
	else:
		line = "%d shot%s, par %d%s" % [res.used, "" if res.used == 1 else "s", int(level.L.par), "" if res.damaged else ", untouched"]
	UiKit.text(card, line, &"Tip")
	if res.pay:
		UiKit.text(card, "+$%d" % res.pay, &"Pay")
	var buttons := UiKit.row(card)
	if res.last:
		UiKit.button(buttons, "Back to the levels").pressed.connect(show_menu)
		return
	if GameState.level_open(ci, li + 1):
		UiKit.button(buttons, "Next showdown").pressed.connect(show_intro.bind(ci, li + 1))
	UiKit.button(buttons, "Retry", &"GhostButton").pressed.connect(restart)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_menu)


func _offer_text(offer: String) -> Array:
	match offer:
		"bullet":
			return ["OUT OF AMMO!", "One outlaw remains. Don’t let him escape!", "Watch ad: +1 bullet"]
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
		UiKit.text(card, o[1], &"", 420)
		if clue != "":
			UiKit.text(card, clue, &"Tip", 420)
		if AdsManager.available():
			UiKit.button(card, o[2]).pressed.connect(_use_offer.bind(offer, reason))
		else:
			UiKit.button(card, "No ad available right now").disabled = true
		UiKit.text(card, "Using this caps the clear at two stars.", &"Hint")
	else:
		UiKit.text(card, reason, &"Heading")
		UiKit.text(card, clue if clue != "" else L.tip, &"Hint", 420)
	var buttons := UiKit.row(card)
	var retry_label := "Try again"
	if offer != null:
		retry_label = "Start over, free" if L.get("eli", false) else "Retry level, free"
	UiKit.button(buttons, retry_label, &"GhostButton" if offer != null else &"").pressed.connect(restart)
	UiKit.button(buttons, "Levels", &"GhostButton").pressed.connect(show_menu)


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
	UiKit.text(card, level.L.hint, &"Tip", 420)
	if lvl >= 2:
		UiKit.text(card, "The key spot will glow while you play.", &"Hint")
	UiKit.button(card, "Try again with the clue").pressed.connect(restart)


# ---------- HUD ----------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	_hud_box = MarginContainer.new()
	_hud_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_box.add_theme_constant_override("margin_top", 10)
	_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_box)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_box.add_child(bar)
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 3)
	bar.add_child(hearts)
	for i in 3:
		_hearts.append(UiKit.image(hearts, "ui/heart_full"))
	_ammo = HBoxContainer.new()
	_ammo.add_theme_constant_override("separation", 3)
	bar.add_child(_ammo)
	_lvl_label = UiKit.text(bar, "", &"HudLabel")
	_lvl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
			UiKit.image(_ammo, "ui/bullet_full")
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
	return UiKit.card(UiKit.overlay(_overlay))


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
