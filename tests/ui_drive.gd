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
		await _screens(aspect[0])
	print("UI drive: %d screens over the safe area" % problems.size())
	for p in problems:
		print("  " + p)
	get_tree().quit()


func _screens(tag: String) -> void:
	main.show_board()
	await _check(tag, "board")
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
	main.show_home()
	await _wait(0.3)
	await _shot(tag + "_office")


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
