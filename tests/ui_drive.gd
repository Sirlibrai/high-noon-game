extends Node
## Visual check of every overlay screen (intro and result cards, level list, Bounty board,
## Gunsmith, Profile, pause, Second Chance and ad offers, coming soon) at 16:9 and at an
## iPhone's 19.5:9. Saves screenshots and prints each card's rect against the safe area a
## notched iPhone leaves in landscape. Never touches the player's save:
##   Godot --path . res://tests/ui_drive.tscn -- <output dir>

## An iPhone in landscape (852 x 393 points) keeps 59 points clear at each side and 21 at the bottom.
const PHONE := Vector2(852, 393)
const INSET := Vector4(59, 0, 59, 21)  # left, top, right, bottom

var main: Node
var out_dir := "user://ui_drive"
var problems: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.persist = false
	SaveManager.data.progress = SaveManager.fresh_progress()
	SaveManager.data.settings.playtest = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.4)
	for aspect in [["16x9", Vector2i(1280, 720)], ["19x9", Vector2i(1560, 720)]]:
		get_window().size = aspect[1]
		get_window().content_scale_size = Vector2i(1280, 720)
		await _wait(0.3)
		var k: float = get_viewport().get_visible_rect().size.y / PHONE.y
		main.safe_override = Vector3.ZERO if aspect[0] == "16x9" else Vector3(INSET.x * k, INSET.z * k, INSET.w * k)
		main._layout()
		await _screens(aspect[0])
	print("UI drive: %d screens over the safe area" % problems.size())
	for p in problems:
		print("  " + p)
	get_tree().quit()


func _screens(tag: String) -> void:
	main.show_board()
	await _check_board(tag, "board")
	main.board.show_poster(4)  # swiped along to J.R.'s silhouette
	await _check_board(tag, "board_jr")
	main.show_chapter(0)
	await _check(tag, "levels")
	main.show_intro(0, 0)
	await _check(tag, "intro_l1")
	main.show_intro(0, 4)
	await _check(tag, "intro_l5")
	main.show_intro(0, 1)
	main._go()
	main.level.state = "won"
	main._on_won({"stars": 2, "pay": 40, "captured": false, "hearts": 3, "used": 1, "damaged": false, "assisted": true, "last": false})
	await _wait(0.5)
	await _check(tag, "won")
	main.level.state = "lost"
	main._show_fail("Out of bullets.", "hint")
	await _check(tag, "second_chance_hint")
	main.show_intro(0, 4)
	main._go()
	main.level.state = "lost"
	main._show_fail("You’ve been shot.", "continue")
	await _check(tag, "second_chance_duel")
	main.show_intro(0, 2)
	main._go()
	main._toggle_pause()
	await _check(tag, "pause")
	main._on_office_act("gunsmith")
	await _check(tag, "gunsmith")
	main._on_office_act("profile")
	await _check(tag, "profile")
	main.soon("daily")
	await _check(tag, "daily_soon")
	main.show_trophies()
	await _check(tag, "trophies")
	main.show_home()
	await _wait(0.5)
	await _shot(tag + "_office")
	_check_office(tag)
	var o: Office = main._screen
	o._on_act("gunsmith", Rect2(1298, 84, 346, 622))
	await _wait(0.3)
	await _shot(tag + "_office_gunsmith_lit")
	await _wait(0.6)
	# Later in the campaign: two bounties captured (trophies, stamps) and every gun owned (the rack).
	var pg: Dictionary = GameState.progress
	var keep := pg.duplicate(true)
	for c in 2:
		GameState.chapter_progress(pg, c).stars[str(GameState.levels_for(c).size() - 1)] = 3
	for w in GameState.weapons:
		pg.inv.guns[w.id] = true
	pg.seenOffice = true
	main.show_home()
	await _wait(0.5)
	await _shot(tag + "_office_later")
	_check_office(tag + " later")
	main.show_trophies()  # the keepsakes, labelled with their outlaws' faces
	await _check(tag, "trophies_later")
	SaveManager.data.progress = keep


## The office: every plate and the ledger inside the safe area, none overlapping, every hotspot
## at least 44 points each way.
func _check_office(tag: String) -> void:
	var o: Office = main._screen
	var vis := get_viewport().get_visible_rect().size
	var k := vis.y / PHONE.y
	var s: Vector3 = main._safe_lrb
	var safe := Rect2(s.x, 0, vis.x - s.x - s.y, vis.y - s.z)
	var boxes: Array = o.plates.map(func(p): return [p.text.strip_edges(), p.get_global_rect()])
	boxes.append(["ledger", o.ledger.get_global_rect()])
	for b in boxes:
		if not safe.encloses(b[1]):
			problems.append("%s office: %s %s outside %s" % [tag, b[0], b[1], safe])
		for c in boxes:
			if b[0] < c[0] and b[1].intersects(c[1]):
				problems.append("%s office: %s overlaps %s" % [tag, b[0], c[0]])
	var sheet := Rect2(o._to_local_px(Office.PARCHMENT.position) + o.global_position, Office.PARCHMENT.size * o._k)
	if not sheet.encloses(o.ledger.get_global_rect()):
		problems.append("%s office: the writing %s is off the parchment %s" % [tag, o.ledger.get_global_rect(), sheet])
	for p in o.plates:  # tags beside their objects, never over one
		for sp in Office.SPOTS:
			var box := Rect2(o._to_local_px(Vector2(sp.box[0], sp.box[1])) + o.global_position, Vector2(sp.box[2], sp.box[3]) * o._k)
			if box.intersects(p.get_global_rect()):
				problems.append("%s office: the %s tag covers the %s" % [tag, p.text, sp.label])
	var top: Array = main._home_box.find_children("*", "Control", true, false).filter(func(c): return c.visible and (c is Label or c is Button))
	if top.size() != 1 or top[0] != main._wallet:
		problems.append("%s office: the top bar has more than the wallet: %s" % [tag, top])
	for h in o.get_children():
		if h is Button and h.theme_type_variation == &"Hotspot" and (h.size.x < 44 * k or h.size.y < 44 * k):
			problems.append("%s office: hotspot %s is %s, under 44 points" % [tag, h.tooltip_text, h.size / k])
	print("%s office: %d plates and the ledger checked" % [tag, o.plates.size()])


## Saves the screen and checks the card fits inside the phone's safe area.
func _check(tag: String, name: String) -> void:
	await _wait(0.25)
	await _shot("%s_%s" % [tag, name])
	var card: Control = _find_card(main._overlay)
	if card == null:
		problems.append("%s %s: no card" % [tag, name])
		return
	var vis := get_viewport().get_visible_rect().size
	var k := vis.y / PHONE.y  # base pixels per point
	var safe := Rect2(INSET.x * k, INSET.y * k, vis.x - (INSET.x + INSET.z) * k, vis.y - (INSET.y + INSET.w) * k)
	if tag == "16x9":  # older iPhones (no notch) and iPads: the whole screen
		safe = Rect2(Vector2.ZERO, vis)
	var r := card.get_global_rect()
	var fits := safe.encloses(r)
	print("%s %-20s card %s %s" % [tag, name, r, "fits" if fits else "OVER " + str(safe)])
	if not fits:
		problems.append("%s %s: card %s outside %s" % [tag, name, r, safe])


## The Bounty board wall: no card. The centred poster is 75 to 80% of the screen tall and inside the
## safe area, and the Home button and the Bounty Dollars sit in the top corners inside it.
func _check_board(tag: String, name: String) -> void:
	await _wait(0.4)
	await _shot("%s_%s" % [tag, name])
	var vis := get_viewport().get_visible_rect().size
	var k := vis.y / PHONE.y
	var safe := Rect2(INSET.x * k, INSET.y * k, vis.x - (INSET.x + INSET.z) * k, vis.y - (INSET.y + INSET.w) * k)
	if tag == "16x9":
		safe = Rect2(Vector2.ZERO, vis)
	var b: BountyWall = main.board
	var p: Button = b.posters[b.centred()]
	var r := Rect2(p.get_global_transform() * Vector2.ZERO, Vector2.ZERO).expand(p.get_global_transform() * p.size)
	var share := p.size.y / vis.y
	if share < 0.75 or share > 0.8:
		problems.append("%s %s: poster %.0f%% of the screen tall" % [tag, name, share * 100])
	if not safe.grow(2).encloses(r):
		problems.append("%s %s: centred poster %s outside %s" % [tag, name, r, safe])
	for c in main._overlay.find_children("*", "Button", true, false):
		if c is Button and not c in b.posters and not safe.encloses(c.get_global_rect()):
			problems.append("%s %s: %s %s outside %s" % [tag, name, c.text, c.get_global_rect(), safe])
	print("%s %-20s poster %d, %.0f%% tall, %s" % [tag, name, b.centred(), share * 100, r])


func _find_card(n: Node) -> Control:
	if n == null:
		return null
	if n is PanelContainer and n.theme_type_variation == &"Card":
		return n
	for c in n.get_children():
		var f := _find_card(c)
		if f != null:
			return f
	return null


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
