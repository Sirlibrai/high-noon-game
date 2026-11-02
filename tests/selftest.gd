extends Node
## The prototype's self-tests (specs/expected_results.md, reference function
## `selftest`), run headless:
##   Godot --headless --path . res://tests/selftest.tscn
## Exits with code 0 when every check passes.

var results: Array = []
const POSES := ["idle", "aim", "hit", "crouch", "lean", "run_left", "run_right", "fall"]


func ok(name: String, cond: bool, detail := "") -> void:
	results.append([name, cond, detail])


func fresh() -> Dictionary:
	return SaveManager.fresh_progress()


func _ready() -> void:
	var G := GameState

	# progression and payouts
	var pg := fresh()
	var r: Dictionary = G.apply_win(pg, 0, 0, 2, o10(1000))
	ok("Winning level 1 unlocks level 2", pg.ch[0].unlocked == 2)
	ok("Two stars pay $40", r.pay == 40, "paid %d" % r.pay)
	r = G.apply_win(pg, 0, 0, 3, o10(1000))
	ok("Improving to three stars pays only the $20 difference", r.pay == 20, "paid %d" % r.pay)
	r = G.apply_win(pg, 0, 0, 1, o10(1000))
	ok("A worse replay pays nothing and keeps three stars", r.pay == 0 and G.stars_in(pg, 0, 0) == 3)
	ok("Perfect clears counted once", pg.stats.perfect == 1)
	r = G.apply_win(pg, 0, 9, 1, o10(1000, true, true))
	ok("Capturing Iron Eli pays the $1,000 poster reward plus boss pay", r.pay == 1040 and r.capture_now, "paid %d" % r.pay)
	r = G.apply_win(pg, 0, 9, 2, o10(1000, true, true))
	ok("The poster reward is never paid twice", r.pay == 40, "paid %d" % r.pay)
	ok("Earnings ledger matches the wallet", pg.stats.earned == pg.bucks)

	# production unlocks
	var pg2 := fresh()
	ok("Production: the train is locked before Iron Eli is captured", not G.chapter_open_for(pg2, 1, false))
	G.apply_win(pg2, 0, 9, 1, o10(1000, true, true))
	ok("Production: capturing Iron Eli opens the train", G.chapter_open_for(pg2, 1, false))
	ok("Production: posters without levels stay locked", not G.chapter_open_for(pg2, 2, false) and not G.chapter_open_for(pg2, 2, true))

	# campaign status
	var hs := fresh()
	var st: Dictionary = G.hunt_status_for(hs, false)
	ok("New save: Continue hunt goes to Iron Eli", st.ch == 0)
	G.apply_win(hs, 0, 9, 1, o10(1000, true, true))
	st = G.hunt_status_for(hs, false)
	ok("Iron Eli captured: Continue hunt goes to the Coal Gang", st.ch == 1)
	G.apply_win(hs, 1, 9, 1, o10(1500, true, true))
	st = G.hunt_status_for(hs, false)
	ok("Both captured: all bounties captured, nothing to continue", st.done and st.ch == null)
	ok("Both captured: Digger McCall is next, coming soon", st.next == 2 and G.levels_for(2) == null)
	ok("Both captured: playtest mode agrees", G.hunt_status_for(hs, true).ch == null)
	ok("Captured bounties stay replayable from the board", G.chapter_open_for(hs, 0, false) and G.chapter_open_for(hs, 1, false))
	var hs2 := fresh()
	G.apply_win(hs2, 1, 9, 1, o10(1500, true, true))
	ok("Playtest: train captured first still sends you to Iron Eli", G.hunt_status_for(hs2, true).ch == 0)

	# inventory and saving
	var pg3 := fresh()
	pg3.bucks = 600
	ok("Cannot buy what you cannot afford", not G.buy_item(pg3, 900, func(p): p.inv.guns.legend = true) and pg3.bucks == 600)
	ok("Buying deducts the price", G.buy_item(pg3, 500, func(p): p.inv.guns.quickdraw = true) and pg3.bucks == 100)
	pg3.avatar = {"name": "Test", "hat": 2}
	pg3.hints = {"0:1": 2}
	var back: Dictionary = JSON.parse_string(JSON.stringify(pg3))
	ok("Owned guns survive a save and reload", back.inv.guns.quickdraw == true and back.bucks == 100)
	ok("Avatar and unlocked hints survive a save and reload", back.avatar.hat == 2 and back.hints["0:1"] == 2)

	# second chance rules
	var arcade := {}
	var puzzle := {"puzzle": true}
	var boss_l := {"duel": true}
	var bullet_offers: Array = []
	for l in G.levels_for(0):
		for reason in ["ammo", "shot", "hostage"]:
			for left in [1, 2]:
				if G.offer_for(l, reason, left, false) == "bullet":
					bullet_offers.append(l.name)
	ok("No +1 bullet offer anywhere in the campaign, legacy levels included (brief v2)", bullet_offers.is_empty() and G.offer_for(arcade, "ammo", 1, false) == null, str(bullet_offers))
	ok("Puzzle levels never offer bullets, only clues", G.offer_for(puzzle, "ammo", 1, false) == "hint")
	ok("Single-stage duels offer to keep your rounds", G.offer_for(boss_l, "shot", 0, false) == "continue")
	ok("Iron Eli, lost in stage 1: no ad offer", G.offer_for({"eli": true}, "shot", 1, false, 1) == null)
	ok("Iron Eli, lost in stage 2 or 3: retry from that stage", G.offer_for({"eli": true}, "shot", 1, false, 2) == "checkpoint" and G.offer_for({"eli": true, "duel": true}, "shot", 0, false, 3) == "checkpoint")
	ok("Stars: a clear is one, no heart lost is two, par unassisted is three", G.stars_for({"par": 3}, {"used": 3, "damaged": false}) == 3 and G.stars_for({"duel": true}, {"hearts": 3}) == 3)
	ok("Stars: no heart lost but over par is two", G.stars_for({"par": 2}, {"used": 3, "damaged": false}) == 2)
	ok("Stars: at par but a heart lost is two", G.stars_for({"par": 2}, {"used": 2, "damaged": true}) == 2)
	ok("Stars: over par and a heart lost is one", G.stars_for({"par": 2}, {"used": 3, "damaged": true}) == 1)
	ok("Any assistance caps a clear at two stars", G.stars_for({"par": 3}, {"used": 3, "damaged": false, "assisted": true}) == 2 and G.stars_for({"duel": true}, {"hearts": 3, "assisted": true}) == 2)
	ok("An assisted clear at par with a heart lost is one star: par only counts unassisted", G.stars_for({"par": 3}, {"used": 3, "damaged": true, "assisted": true}) == 1)
	ok("Shooting a hostage in an arcade level offers nothing", G.offer_for(arcade, "hostage", 1, false) == null)
	ok("Only one offer per attempt", G.offer_for(arcade, "ammo", 1, true) == null)

	# level data
	for c in 2:
		var sc: Dictionary = G.scene_for(c)
		var lvls: Array = G.levels_for(c)
		for i in lvls.size():
			var l: Dictionary = lvls[i]
			var name := "%s %d, %s" % ["Train" if c else "Main Street", i + 1, l.name]
			if l.get("duel", false):
				ok(name + ": duel set up", G.BOSS_SPRITES.has(l.boss) and l.react.size() >= 1)
				continue
			if int(l.get("v", 1)) >= 2:
				ok(name + ": v2 data valid", _v2_problems(l, sc).is_empty(), ", ".join(_v2_problems(l, sc)))
				continue
			var problems: Array = []
			var n: int = l.enemies.size() + l.get("bottles", []).size()
			if l.bullets < l.par:
				problems.append("par above bullets")
			if not l.get("puzzle", false) and not l.get("eli", false) and l.bullets < n:
				problems.append("fewer bullets than targets")
			for d in l.enemies:
				if d.has("w") and int(d.w) >= sc.windows.size():
					problems.append("bad window")
				if d.has("c") and int(d.c) >= l.covers.size():
					problems.append("bad cover")
			for cv in l.covers:
				if cv[1] < 0 or cv[1] + G.kit_cover_sizes[cv[0]][0] > 270:  # the prototype's own data check, in its sizes
					problems.append(cv[0] + " behind the gun")
			if l.get("puzzle", false) and not (l.has("hint") and l.has("hintTarget")):
				problems.append("puzzle without hint")
			ok(name + ": data valid", problems.is_empty(), ", ".join(problems))

	# replaceable art: one manifest, image files only
	ok("Manifest: every file exists and every theme slot resolves", Assets.errors.is_empty(), "; ".join(Assets.errors))
	var missing: Array = []
	for c in 2:
		for l in G.levels_for(c):
			var needed: Array = []
			for cv in l.get("covers", []):
				var kind: String = cv.type if cv is Dictionary else cv[0]
				if not Assets.has("prop/" + kind):
					missing.append("prop/" + kind)
			if l.has("bucket"):
				needed.append_array(["prop/bucket", "prop/hook"])
			if l.has("bucket") or l.has("sign"):
				needed.append_array(["prop/signpost", "prop/bracket", "prop/chain"])
			if c == 0 and l.get("duel", false):
				for pose in ["idle", "aim", "hit", "fall"]:
					needed.append(G.BOSS_SPRITES[l.boss] + "/" + pose)
			if c == 0 and l.get("eli", false):
				needed.append_array(["iron_eli_armour/intact", "iron_eli_armour/cracked", "fx/dynamite", "fx/fuse_spark", "fx/ping", "fx/armour"])
				for pose in POSES:
					needed.append("iron_eli/" + pose)
			if c == 0 and l.get("puzzle", false):
				needed.append("fx/hint_glow")
			for n in needed:
				if not Assets.has(n):
					missing.append(n)
	ok("Manifest: every Main Street prop, boss, effect and Iron Eli stage has art", missing.is_empty(), ", ".join(missing))

	# Pose-based characters: the painted outlaw's eight poses, each anchored at the soles.
	var pose_gaps: Array = []
	for pose in POSES:
		var n: String = "outlaw/" + pose
		if not Assets.has(n):
			pose_gaps.append(n + " missing")
		elif absf(Assets.anchor(n).y - Assets.texture(n).get_height()) > 4:
			pose_gaps.append("%s anchored %d px above its soles" % [n, Assets.texture(n).get_height() - Assets.anchor(n).y])
	ok("Outlaw poses: idle, aim, hit, crouch, run left and right, lean and fall, each anchored at the feet", pose_gaps.is_empty(), ", ".join(pose_gaps))
	ok("The falling hat is its own sprite", Assets.has("fx/hat") and Assets.texture("fx/hat").resource_path.contains("painted"))
	var painted_props: Array = ["prop/barrel", "prop/crate", "prop/tnt", "prop/wagon", "prop/trough", "prop/sign", "prop/tumbleweed"].filter(
		func(n): return not Assets.texture(n).resource_path.contains("painted"))
	ok("Main Street's props are the painted ones", painted_props.is_empty(), ", ".join(painted_props))
	_poses_and_scale()

	# The painted street: centred background, windows matched to the painting, chains on the INN sign.
	var bg := "main_street/painted"
	var bg_scale: float = Assets.meta(bg, "scale", 1.0)
	var bg_w: float = Assets.texture(bg).get_width() * bg_scale
	ok("Main Street's painting fills the 720-pixel height, centred on the play area",
		absf(Assets.texture(bg).get_height() * bg_scale - 720) < 1 and absf(Assets.anchor(bg).x + 640 / bg_scale - Assets.texture(bg).get_width() / 2.0) < 2)
	ok("Main Street's painting covers 16:9 and 19.5:9 screens", bg_w >= 720 * 19.5 / 9.0, "%d px wide" % bg_w)
	var street: Dictionary = G.scene_for(0)
	ok("Main Street's ground line comes from the painted street (geometry.json)", int(street.GY) == int(G.geometry.scenes.street.GY))
	var hud_bottom := 22.0  # units: the hearts, bullets and buttons
	var win_gaps: Array = []
	for aspect in [16.0 / 9.0, 19.5 / 9.0]:
		var half: float = (720 * aspect / 4.0) / 2.0  # visible half-width in units
		for w in street.windows:
			if w.x < 160 - half or w.x + w.w > 160 + half:
				win_gaps.append("window at %s off a %.2f screen" % [w.x, aspect])
			if w.y < hud_bottom:
				win_gaps.append("window at %s under the HUD" % w.x)
	ok("Every window outlaw is on screen at 16:9 and 19.5:9, and clear of the HUD", win_gaps.is_empty(), ", ".join(win_gaps))
	ok("The clue for Hang 'em high says chains", G.levels_for(0)[6].hint.contains("chains") and not G.levels_for(0)[6].hint.contains("rope"))
	for side in [0, 1]:
		var lv := Level.new()
		add_child(lv)
		lv.setup(0, 6)  # Hang 'em high
		lv.go()
		lv.shoot(lv.chain_rects()[side].get_center(), true)
		ok("A shot at the INN sign's %s chain drops it" % ["left", "right"][side], lv.hang_sign.state == "fall")
		remove_child(lv)
		lv.free()
	var lv2 := Level.new()
	add_child(lv2)
	lv2.setup(0, 6)
	lv2.go()
	lv2.shoot(Vector2(lv2.hang_sign.x + lv2.hang_sign.w / 2.0, lv2.hang_sign.y + lv2.hang_sign.h - 1), true)  # the board's lower edge, clear of the chains
	ok("A shot at the INN board only swings it", lv2.hang_sign.state == "hang")
	remove_child(lv2)
	lv2.free()

	# The 1.7x gameplay plane: bigger cover, spread to fit, every target inside the safe area.
	var LY: Dictionary = G.geometry.layout
	var lay_gaps: Array = []
	var spreads: Array = []
	for li in G.levels_for(0).size():
		var lv := Level.new()
		add_child(lv)
		lv.setup(0, li)
		spreads.append(snappedf(lv._spread.p, 0.01))
		var xs: Array = lv.covers.map(func(c): return [c.x, c.x + c.w])
		xs.sort_custom(func(a, b): return a[0] < b[0])
		for k in xs.size():
			if xs[k][0] < LY.safe[0] - 0.01 or xs[k][1] > LY.safe[1] + 0.01:
				lay_gaps.append("%s: cover outside the safe area" % lv.L.name)
			if k + 1 < xs.size() and xs[k][1] > xs[k + 1][0]:
				lay_gaps.append("%s: cover overlaps" % lv.L.name)
		for e in lv.enemies:
			if e.kind == "hostage" and (e.hx < LY.safe[0] or e.hx > LY.safe[1]):
				lay_gaps.append("%s: hostage outside" % lv.L.name)
		if lv.hang_sign != null and (lv.hang_sign.x < LY.safe[0] or lv.hang_sign.x + lv.hang_sign.w > LY.safe[1]):
			lay_gaps.append("%s: sign outside" % lv.L.name)
		for b in lv.bottles:
			if b.x < LY.safe[0] or b.x > LY.safe[1]:
				lay_gaps.append("%s: bottle outside" % lv.L.name)
		remove_child(lv)
		lv.free()
	ok("Every Main Street level's cover is apart and inside the safe area", lay_gaps.is_empty(), ", ".join(lay_gaps))
	ok("Puzzle-first levels are laid out as authored (no spreading)", range(4).all(func(i): return spreads[i] == 1.0), str(spreads))

	# The painted HUD: wooden panels, a licensed Western font, painted hearts and bullets, glowing rings.
	var theme: Theme = load("res://ui/theme.tres")
	var hud_font: Font = theme.get_font("font", "HudLabel")
	ok("The HUD uses Rye, a Western display font under the SIL Open Font License",
		hud_font != null and hud_font.resource_path.ends_with("Rye-Regular.ttf") and FileAccess.get_file_as_string("res://ui/fonts/OFL.txt").contains("SIL Open Font License"))
	# The presentation pass: no pixel font or pixel UI art left on any card, list or menu.
	var body: Font = theme.default_font
	ok("Body text is Lora (SIL Open Font License), set once in the theme; no pixel font anywhere",
		body is FontVariation and body.base_font.resource_path.ends_with("Lora-Variable.ttf") and not FileAccess.get_file_as_string("res://ui/theme.tres").contains("Pixelify")
		and FileAccess.get_file_as_string("res://ui/fonts/OFL-Lora.txt").contains("SIL Open Font License"))
	ok("Titles and headings are Rye", ["Heading", "Title", "Logo", "Callout", "InkTitle", "PosterWanted"].all(
		func(t): return theme.get_font("font", t).resource_path.ends_with("Rye-Regular.ttf")))
	var pixel_ui: Array = ["ui/card", "ui/button", "ui/button_pressed", "ui/button_ghost", "ui/button_ghost_pressed", "ui/pill", "ui/star_on", "ui/star_off",
		"ui/icon_pause", "ui/icon_restart", "ui/icon_sound_on", "ui/icon_sound_off", "ui/icon_music", "ui/icon_music_off", "ui/icon_lock",
		"ui/plaque", "ui/plaque_soon", "ui/wallet", "ui/desk_plaque", "ui/poster_paper", "ui/telegram", "ui/stamp_box", "portrait/ch0"].filter(
		func(n): return not Assets.texture(n).resource_path.contains("painted/"))
	ok("Cards, buttons, tags, stars, icons, plates and posters use the painted UI art", pixel_ui.is_empty(), ", ".join(pixel_ui))
	ok("Every overlay screen sits on the painted wooden card", theme.get_stylebox("panel", "Card") is StyleBoxTexture and UiKit.card(Control.new()).get_parent().theme_type_variation == &"Card")
	ok("The HUD's panel and round buttons are the painted wood, the level name on the brass plaque", theme.get_stylebox("panel", "HudPanel") is StyleBoxTexture
		and Assets.texture("ui/hud_panel").resource_path.ends_with("painted/ui_panel_small.png") and Assets.texture("ui/icon_button").resource_path.ends_with("painted/ui_button_round.png")
		and Assets.texture("ui/hud_plaque").resource_path.ends_with("painted/ui_plaque.png"))
	ok("Hearts, bullets and draw rings are the painted versions",
		["ui/heart_full", "ui/heart_empty", "ui/bullet_full", "ui/bullet_empty", "fx/draw_ring", "fx/draw_ring_urgent"].all(
			func(n): return Assets.texture(n).resource_path.contains("painted/")))

	# Bank job at the brief v2 scale: the hostage-taker leaning left overlaps the TNT barrel, and stands in front of it.
	for case in ["captor", "barrel"]:
		var bj := Level.new()
		add_child(bj)
		bj.setup(0, 8)
		bj.go()
		var cap: Dictionary = bj.enemies[0]
		cap.merge({"state": "aim", "exp": 1.0, "lean": -1, "t": 5.0}, true)
		var tnt: Dictionary = bj.covers[0]
		var cap_rect := bj.rect_of(cap)
		var tnt_rect := bj.cover_rect(tnt)
		if case == "captor":
			bj.shoot(cap_rect.intersection(tnt_rect).get_center(), true)
			ok("Bank job: a tap on the hostage-taker in front of the TNT takes him down, not the barrel",
				cap_rect.intersects(tnt_rect) and not cap.alive and tnt.alive and bj.state == "play")
		else:
			cap.merge({"state": "hidden", "exp": 0.0}, true)  # leaning out at this scale he covers the whole barrel
			cap_rect = bj.rect_of(cap)
			bj.shoot(Vector2(tnt_rect.end.x - 2 if cap_rect.get_center().x < tnt_rect.get_center().x else tnt_rect.position.x + 2, tnt_rect.end.y - 2), true)  # the side clear of him
			ok("Bank job: shooting the TNT itself still costs the hostage", bj.state == "lost" and bj.events.has("lost:hostage"), "%s %s tnt %s captor %s hostage x %.1f" % [bj.state, bj.events, tnt_rect, cap_rect, cap.hx])
		remove_child(bj)
		bj.free()

	# Painted look: a 1280×720 base with smooth filtering, gameplay geometry unchanged.
	ok("Base resolution is 1280×720 with linear texture filtering",
		ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720
		and ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 1)
	ok("Gameplay units still map the 320×180 stage onto the 1280×720 base", float(G.geometry.pixels_per_unit) * G.geometry.stage.width == 1280.0)
	# The revolver stays small in the bottom-right corner at every tilt (style guide: about the bottom-right eighth).
	var gun := Assets.texture("gun_peacemaker_0/idle")
	var gun_scale: float = Assets.meta("gun_peacemaker_0/idle", "scale", 1.0)
	var ppu: float = G.geometry.pixels_per_unit
	var anchor := Assets.anchor("gun_peacemaker_0/idle")
	var g: Dictionary = G.geometry.gun
	var worst := Vector2(320, 180)
	for ang in [g.reload_angle, g.angle_range[0], g.rest_angle, g.angle_range[1], g.angle_range[1] + 0.85 * g.kick_tilt]:  # the strongest kick (Coach Gun)
		var pivot := Vector2(320 - g.pivot_from_corner[0] + g.kick_offset[0], 180 - g.pivot_from_corner[1])
		for corner in [Vector2.ZERO, Vector2(gun.get_width(), 0), Vector2(0, gun.get_height()), gun.get_size()]:
			var p: Vector2 = pivot + ((corner - anchor) * gun_scale / ppu).rotated(ang)
			worst = Vector2(minf(worst.x, p.x), minf(worst.y, p.y))
	ok("The revolver stays in the bottom-right corner at every tilt", worst.x >= 320 * 0.75 and worst.y >= 180 * 0.5, "reaches x %.0f, y %.0f" % [worst.x, worst.y])
	ok("The Peacemaker is the painted gloved hand and gun, with a small tilt",
		gun.resource_path.contains("painted") and absf(g.angle_range[1] - g.angle_range[0]) <= 0.2 and absf(g.reload_angle) <= 0.3)
	var gun_gaps: Array = []
	for w in G.weapons:
		for f in w.fins.size():
			var n := "gun_%s_%d/idle" % [w.id, f]
			if not Assets.has(n) or not Assets.has("gun_%s_%d/reload" % [w.id, f]) or Assets.point(n, "muzzle") == Vector2.ZERO:
				gun_gaps.append(n)
	ok("Manifest: every gun finish has idle and reload art with a muzzle point", gun_gaps.is_empty(), ", ".join(gun_gaps))
	var drawing: Array = []
	var draw_call := RegEx.create_from_string("\\bdraw_(rect|arc|line|lines|polyline|polygon|colored_polygon|circle|texture\\w*|string\\w*|set_transform\\w*|primitive|mesh|style_box|char)\\(|func _draw\\(|StyleBoxFlat")
	for dir in ["res://scripts/", "res://autoload/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and draw_call.search(FileAccess.get_file_as_string(dir + f)) != null:
				drawing.append(f)
	ok("No game script draws in code", drawing.is_empty(), ", ".join(drawing))

	_campaign_status()
	_saves()
	_skins()

	# Playthrough checks (expected_results.md), with the scripted player on a fresh, unsaved progress.
	SaveManager.persist = false
	SaveManager.data.progress = fresh()
	_playthroughs()
	_puzzle_first()
	_office()
	_batch1()
	_scale_guide()
	_portraits()
	_bounty_wall()
	_iron_eli_rules()

	var passed := results.filter(func(x): return x[1]).size()
	for x in results:
		print(("PASS " if x[1] else "FAIL ") + x[0] + ("" if x[1] or x[2] == "" else " (" + x[2] + ")"))
	print("Self-tests: %d of %d passed" % [passed, results.size()])
	get_tree().quit(0 if passed == results.size() else 1)


## Plays a Main Street level with the scripted player; tries a few seeds, as timings are random.
func run_level(li: int, foul_rounds := [], tries := 5, prepare := Callable(), taps := [], max_seconds := 300.0) -> Dictionary:
	var out := {}
	for attempt in tries:
		seed(1000 + li * 17 + attempt)
		var lv := Level.new()
		add_child(lv)
		lv.setup(0, li)
		var box := {"stars": 0, "offer": null}
		lv.won.connect(func(res): box.stars = res.stars)
		lv.lost.connect(func(_r, o): box.offer = o)
		if prepare.is_valid():
			prepare.call(lv)
		else:
			lv.go()
		var bot := AutoPlayer.new()
		bot.foul_rounds = foul_rounds.duplicate()
		bot.taps = taps
		AutoPlayer.play(lv, bot, max_seconds)
		out = {"state": lv.state, "used": lv.used, "hearts": lv.hearts, "events": lv.events.duplicate(),
			"stars": box.stars, "offer": box.offer, "clock": lv.clock, "bullets": lv.bullets, "damaged": lv.damaged, "tnt_left": lv.covers.filter(func(c): return c.type == "tnt" and c.alive).size(),
			"attempts": attempt + 1}
		remove_child(lv)
		lv.free()
		if out.state == "won":
			break
	return out


func count(events: Array, e: String) -> int:
	return events.filter(func(x): return x == e).size()


func _playthroughs() -> void:
	var lvls: Array = GameState.levels_for(0)
	var at_par: Array = []
	for i in lvls.size():
		var l: Dictionary = lvls[i]
		var r := run_level(i, [1] if l.get("eli", false) else [])
		var name := "Main Street %d, %s" % [i + 1, l.name]
		var detail := "%s after %d tries, %d shots (par %s), %d hearts" % [r.state, r.attempts, r.used, l.get("par", "-"), r.hearts]
		if l.get("duel", false):
			ok(name + ": the duel can be won", r.state == "won", detail)
		elif l.get("eli", false):
			var ev: Array = r.events
			ok("Iron Eli: both armour cracks (TNT and sign)", ev.has("crack:tnt") and ev.has("crack:sign"), str(ev))
			ok("Iron Eli: three chase hits, with reinforcements and dynamite", count(ev, "eli_hit") == 3 and ev.has("reinforcements") and ev.has("throw"), str(ev))
			ok("Iron Eli: best-of-three duel with the double-bell last stand", ev.has("stage:3") and ev.has("bell1") and r.state == "won", detail)
		else:
			ok(name + ": won at par with its bullets", r.state == "won" and r.used <= int(l.par), detail)
			if r.state != "won" or r.used > int(l.par):
				at_par.append(l.name)
		match l.name:
			"Hang ’em high", "Bank job":
				ok("Puzzle: %s is solved by shooting a sign chain" % l.name, r.state == "won" and r.events.has("kill:sign"), str(r.events))
	ok("Every Main Street level can be won at par with its allotted bullets", at_par.is_empty(), ", ".join(at_par))


func _iron_eli_rules() -> void:
	var eli_li := 9
	# Stage 1 loss: no offer.
	var r := run_level(eli_li, [], 1, func(lv):
		lv.go()
		for k in 3:
			lv.hurt())
	ok("Iron Eli, lost in stage 1: no ad offer", r.state == "lost" and r.offer == null, str(r))
	# Stage 2 and 3 losses offer the checkpoint.
	for stage in [2, 3]:
		r = run_level(eli_li, [], 1, func(lv):
			lv.go()
			lv.eli_stage(stage)
			for k in 3:
				lv.hurt())
		ok("Iron Eli, lost in stage %d: offers a retry from stage %d" % [stage, stage], r.offer == "checkpoint", str(r.offer))
	# A free retry starts a fresh Iron Eli at stage 1.
	var lv := Level.new()
	add_child(lv)
	lv.setup(0, eli_li)
	ok("Losing anywhere in Iron Eli restarts at stage 1 (free)", lv.eli_ck == 1 and lv._eli().armor and lv.duel == null)
	remove_child(lv)
	lv.free()
	# The ad offer resumes the stage reached, with full hearts, and caps the clear at two stars.
	var resumed := {}
	r = run_level(eli_li, [], 5, func(l2):
		l2.hearts = 1
		l2.resume_from_stage(2)
		resumed.merge({"stage": l2.eli_ck, "hearts": l2.hearts}, true))
	ok("Iron Eli checkpoint resumes the stage reached with full hearts", resumed.get("stage") == 2 and resumed.get("hearts") == 3, str(resumed))
	ok("Iron Eli checkpoint clear is capped at two stars", r.state == "won" and r.stars <= 2, "%s, %d stars" % [r.state, r.stars])


## The desk ledger, the posters and the office board (rules.md §9).
func _campaign_status() -> void:
	var G := GameState
	var states := func(pg, pt): return range(5).map(func(i): return G.poster_state(pg, i, pt))
	var pg := fresh()
	var d: Dictionary = G.desk_status(pg, false)
	ok("Desk, new save: Continue hunt, Level 1: Target Practice, 0 of 5, $1,000",
		d.hunting and d.ch == 0 and d.subtitle == "Level 1: Target Practice" and d.caught == 0 and d.reward == "$2,500", str(d))
	ok("Posters, new save: Iron Eli open, the train locked, three coming soon",
		states.call(pg, false) == ["open", "locked", "soon", "soon", "soon"], str(states.call(pg, false)))
	ok("Office board, new save: Iron Eli's poster is in the middle", G.current_hunt(pg, false) == 0)
	for l in 3:
		G.apply_win(pg, 0, l, 3, o10(1000))
	d = G.desk_status(pg, false)
	ok("Desk continues at the furthest unlocked level (Level 4: Chain Reaction)", d.subtitle == "Level 4: Chain Reaction", str(d))
	G.apply_win(pg, 0, 9, 2, o10(1000, true, true))
	d = G.desk_status(pg, false)
	ok("Desk, Iron Eli captured: Continue hunt goes to the train, 1 of 5, $3,500",
		d.hunting and d.ch == 1 and d.subtitle == "Level 1: All aboard" and d.caught == 1 and d.reward == "$3,500", str(d))
	ok("Posters, Iron Eli captured: his poster stamped, the train open",
		states.call(pg, false) == ["captured", "open", "soon", "soon", "soon"], str(states.call(pg, false)))
	ok("Office board, Iron Eli captured: the train's poster moves to the middle", G.current_hunt(pg, false) == 1)
	G.apply_win(pg, 1, 9, 1, o10(1500, true, true))
	d = G.desk_status(pg, false)
	ok("Desk, both captured: all available bounties captured, Digger McCall arrives soon, 2 of 5",
		not d.hunting and d.title == "All available bounties captured" and d.subtitle == "Digger McCall arrives soon" and d.caught == 2, str(d))
	ok("Desk never falls back to the first bounty once it is captured", d.ch != 0)
	ok("Posters, both captured: two stamped, three coming soon",
		states.call(pg, false) == ["captured", "captured", "soon", "soon", "soon"], str(states.call(pg, false)))
	ok("Office board, both captured: the next outlaw's poster is in the middle", G.current_hunt(pg, false) == 2)
	var pt := fresh()
	G.apply_win(pt, 1, 9, 1, o10(1500, true, true))
	d = G.desk_status(pt, true)
	ok("Playtest: train captured first, the desk still sends you to Iron Eli", d.hunting and d.ch == 0, str(d))
	ok("Playtest: every bounty with levels is open on the board", states.call(fresh(), true) == ["open", "open", "soon", "soon", "soon"])
	ok("Trophy cabinet: one trophy per captured bounty", range(5).filter(func(i): return G.collected_in(pg, i)) == [0, 1])


## Saving and restoring: restarts, damaged files, older saves, and iCloud merges.
func _saves() -> void:
	var dir := "user://selftest_saves"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var SM: GDScript = load("res://autoload/save_manager.gd")
	var a: Node = SM.new()
	a.path = dir.path_join("save.json")
	a.load_game()
	var p: Dictionary = a.data.progress
	GameState.apply_win(p, 0, 0, 3, o10(1000))
	GameState.apply_win(p, 0, 9, 2, o10(1000, true, true))
	p.inv.guns.quickdraw = true
	p.inv.fins["quickdraw:0"] = true
	p.inv.equip = {"gun": "quickdraw", "fin": 0}
	p.bucks -= 500
	p.avatar = {"name": "Dusty", "hat": 2, "hatCol": 3, "skin": 1, "bandana": 0, "coat": 4, "face": 2}
	p.avOwned = {"hat:2": true}
	p.hints = {"0:1": 2}
	p.seenOffice = true
	a.data.settings.music = false
	a._notification(NOTIFICATION_APPLICATION_PAUSED)  # going to the background saves
	var expected: Dictionary = SM.normalised(JSON.parse_string(JSON.stringify(a.data)))
	var b: Node = SM.new()  # a fresh start of the app
	b.path = a.path
	b.load_game()
	var q: Dictionary = b.data.progress
	ok("Save survives a restart: stars and unlocks", GameState.stars_in(q, 0, 0) == 3 and GameState.stars_in(q, 0, 9) == 2 and int(q.ch[0].unlocked) == 10)
	ok("Save survives a restart: Bounty Dollars", int(q.bucks) == int(p.bucks) and int(q.bucks) == 60 + 1080 - 500, str(q.bucks))
	ok("Save survives a restart: guns, finishes and the equipped gun", q.inv.guns.quickdraw and q.inv.fins["quickdraw:0"] and q.inv.equip.gun == "quickdraw")
	ok("Save survives a restart: avatar, bought parts, clues and the office telegram",
		q.avatar.name == "Dusty" and int(q.avatar.hat) == 2 and q.avOwned["hat:2"] and int(q.hints["0:1"]) == 2 and q.seenOffice)
	ok("Save survives a restart: settings", b.data.settings.music == false)
	ok("Save survives a restart: everything matches", JSON.stringify(b.data.progress) == JSON.stringify(expected.progress))
	a.save_game()  # a later save keeps the previous one as the backup
	FileAccess.open(a.path, FileAccess.WRITE).store_string("{\"progress\": {\"bucks\": 12")  # torn mid-write
	a.data.progress.bucks = 999
	var c: Node = SM.new()
	c.path = a.path
	c.load_game()
	ok("A damaged save falls back to the previous one", GameState.stars_in(c.data.progress, 0, 9) == 2, str(c.data.progress.bucks))
	FileAccess.open(a.path, FileAccess.WRITE).store_string(JSON.stringify({"progress": {"bucks": 40, "ch": [{"unlocked": 2, "stars": {"0": 2}}]}}))
	c.load_game()
	ok("An older save without newer fields loads, filling in defaults",
		int(c.data.progress.bucks) == 40 and c.data.progress.avatar.name == "The Stranger" and c.data.progress.inv.guns.peacemaker, str(c.data.progress))
	for n in [a, b, c]:
		n.free()

	# iCloud merges: nothing earned on either device is lost.
	var phone := fresh()
	GameState.apply_win(phone, 0, 0, 3, o10(1000))
	GameState.apply_win(phone, 0, 1, 1, o10(1000))
	phone.inv.guns.quickdraw = true
	phone.bucks -= 50
	phone.avatar.name = "Phone"
	var ipad := fresh()
	GameState.apply_win(ipad, 0, 0, 1, o10(1000))
	GameState.apply_win(ipad, 0, 1, 3, o10(1000))
	GameState.apply_win(ipad, 0, 2, 2, o10(1000))
	ipad.inv.guns.longbarrel = true
	ipad.hints = {"0:3": 1}
	ipad.avatar.name = "iPad"
	var m: Dictionary = SaveManager.merge_progress(phone, 100.0, ipad, 200.0)
	ok("iCloud merge keeps the best stars and furthest unlock from each device",
		GameState.stars_in(m, 0, 0) == 3 and GameState.stars_in(m, 0, 1) == 3 and GameState.stars_in(m, 0, 2) == 2 and int(m.ch[0].unlocked) == 4)
	ok("iCloud merge keeps every purchase and clue", m.inv.guns.quickdraw and m.inv.guns.longbarrel and int(m.hints["0:3"]) == 1)
	ok("iCloud merge takes the avatar from the newer save", m.avatar.name == "iPad")
	ok("iCloud merge keeps the wallet honest: earned minus spent", int(m.bucks) == int(m.stats.earned) - 50 and int(m.bucks) >= 0, "%s of %s" % [m.bucks, m.stats.earned])
	var again: Dictionary = SaveManager.merge_progress(m, 300.0, m.duplicate(true), 300.0)
	ok("iCloud merge of a save with itself changes nothing", JSON.stringify(again) == JSON.stringify(SaveManager.merge_progress(m, 300.0, m, 300.0)) and int(again.bucks) == int(m.bucks))

	# The iCloud file bridge the iOS plugin uses (cloud_out.json up, cloud_in.json down).
	var keep: Dictionary = SaveManager.data
	SaveManager.persist = false
	SaveManager.data = SaveManager.fresh_data()
	SaveManager.data.saved_at = 100.0
	var cs: Node = load("res://autoload/cloud_sync.gd").new()
	cs.dir = ProjectSettings.globalize_path(dir)
	ok("iCloud sync stays off until the plugin is running", not cs.available())
	FileAccess.open(dir.path_join("cloud_status.json"), FileAccess.WRITE).store_string("{\"running\": true}")
	cs.push(SaveManager.data)
	ok("iCloud sync hands each save to the plugin", FileAccess.file_exists(dir.path_join("cloud_out.json")))
	FileAccess.open(dir.path_join("cloud_in.json"), FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "saved_at": 200.0, "progress": ipad}))
	var pulled: bool = cs.pull()
	ok("iCloud sync merges in another device's progress", pulled and GameState.stars_in(SaveManager.data.progress, 0, 1) == 3 and SaveManager.data.progress.inv.guns.longbarrel)
	ok("iCloud sync ignores a copy it has already merged", not cs.pull())
	cs.free()
	SaveManager.data = keep


## Every art name's image file and anchor, to compare skins against the standard art.
func art_snapshot() -> Dictionary:
	var out := {}
	for n in Assets.names():
		out[n] = [Assets.texture(n).resource_path, Assets.anchor(n), Assets.frame_count(n)]
	return out


## Everything a tap can hit on every Main Street level, with each outlaw fully out.
func hitbox_snapshot() -> String:
	var out: Array = [JSON.stringify(GameState.geometry), JSON.stringify(GameState.cover_sizes)]
	for li in GameState.levels_for(0).size():
		var lv := Level.new()
		add_child(lv)
		lv.setup(0, li)
		if lv.duel != null:
			out.append(lv.duel_zone())
		for c in lv.covers:
			out.append(lv.cover_rect(c))
		for b in lv.bottles:
			out.append(lv.bottle_rect(b))
		for e in lv.enemies:
			e.exp = 1.0
			e.state = "aim"
			out.append(lv.rect_of(e))
			if e.kind == "hostage":
				out.append(lv.hostage_rect(e))
		remove_child(lv)
		lv.free()
	return str(out)


## Optional skins: the data, the manifest lookup, the final shader layer, and the save.
func _skins() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skins.json"))
	var only: Array = data.skins
	ok("Skins data lists only Standard: free, no shader, no overrides",
		only.size() == 1 and only[0].id == "standard" and only[0].name == "Standard" and int(only[0].price) == 0
		and only[0].shader == null and only[0].overrides.is_empty())
	var fresh_skins: Dictionary = fresh().skins
	ok("A new save has Standard active and owned", fresh_skins.active == "standard" and fresh_skins.owned.standard == true)
	var standard: Dictionary = Skins.get_skin("standard")
	Assets.set_skin({})
	var plain := art_snapshot()
	var plain_hits := hitbox_snapshot()
	Skins.apply(standard)
	ok("The Standard skin changes no art", art_snapshot() == plain and Assets.skin_fallbacks.is_empty())
	ok("The Standard skin leaves the final screen layer off (no shader)", Skins.final_material() == null)

	var test_skin := {"id": "test", "name": "Test", "price": 0, "shader": "res://tests/fixtures/test_skin.gdshader", "overrides": {
		"prop/barrel": "placeholder/props/hostage.png",
		"prop/tnt": "placeholder/props/no_such_file.png",
		"no_such/name": "placeholder/props/hostage.png",
		"outlaw/aim": {"frames": ["placeholder/props/hostage.png"]}}}
	Skins.apply(test_skin)
	ok("A skin's override is used first", Assets.texture("prop/barrel").resource_path.ends_with("placeholder/props/hostage.png")
		and Assets.texture("outlaw/aim").resource_path.ends_with("placeholder/props/hostage.png"))
	ok("A missing override falls back to the standard art",
		Assets.texture("prop/tnt").resource_path == plain["prop/tnt"][0] and Assets.skin_fallbacks.has("prop/tnt")
		and Assets.skin_fallbacks.has("no_such/name (not in the manifest)"))
	ok("Names a skin does not override keep the standard art",
		Assets.texture("prop/crate").resource_path == plain["prop/crate"][0] and Assets.texture("fx/blood").resource_path == plain["fx/blood"][0])
	ok("A skin's shader goes on the final full-screen layer", Skins.final_material() != null)
	ok("Switching skins never changes geometry or hit areas", hitbox_snapshot() == plain_hits)
	var skinned := AssetSprite.make("outlaw/aim", self)
	ok("Skinned poses still build", skinned.sprite_frames != null and skinned.sprite_frames.has_animation("aim"))
	skinned.free()
	Skins.apply(standard)
	ok("Switching back to Standard restores every image", art_snapshot() == plain and Skins.final_material() == null)
	ok("Hit areas match the standard skin after switching back", hitbox_snapshot() == plain_hits)

	# The save: active and owned skins, kept across restarts and devices.
	var keep: Dictionary = SaveManager.data
	SaveManager.persist = false
	SaveManager.data = SaveManager.fresh_data()
	ok("You can't switch to a skin you don't own", not Skins.set_active("test") and Skins.active_id() == "standard")
	SaveManager.data.progress.skins = {"active": "gold_rush", "owned": {"standard": true, "gold_rush": true}}
	var back: Dictionary = SaveManager.normalised(JSON.parse_string(JSON.stringify(SaveManager.data)))
	ok("Active and owned skins survive a save and reload", back.progress.skins.active == "gold_rush" and back.progress.skins.owned.gold_rush)
	ok("A saved skin that no longer exists falls back to Standard", Skins.active_id() == "standard")
	var older := fresh()
	older.skins.owned["dust_storm"] = true
	var m: Dictionary = SaveManager.merge_progress(SaveManager.data.progress, 200.0, older, 100.0)
	ok("iCloud merge keeps skins bought on either device", m.skins.owned.gold_rush and m.skins.owned.dust_storm and m.skins.active == "gold_rush")
	SaveManager.data = keep


func o10(bounty: int, boss := false, last := false) -> Dictionary:
	return {"boss": boss, "last": last, "bounty": bounty, "count": 10}


## A puzzle-first level's data (brief v2 §11): par within bullets, story lines, two-step hints,
## an authored solution within par, an obvious wrong approach, and everything placed on screen.
func _v2_problems(l: Dictionary, sc: Dictionary) -> Array:
	var p: Array = []
	var LY: Dictionary = GameState.geometry.layout
	if int(l.bullets) < int(l.par):
		p.append("par above bullets")
	if not (l.has("story") and l.story.has("intro") and l.story.has("result")):
		p.append("no story lines")
	if not (l.has("hint") and l.has("hintTarget")):
		p.append("no two-step hint")
	if not l.get("objective", "") in ["eliminate_all", "bottles", "targets"]:
		p.append("unknown objective")
	if l.get("solution", []).size() > int(l.par):
		p.append("solution over par")
	if not (l.has("wrong") and l.wrong.has("taps") and l.wrong.has("expect")):
		p.append("no wrong approach")
	for cv in l.get("covers", []):
		var hw: float = GameState.cover_sizes[cv.type][0] / 2.0
		if cv.x - hw < LY.safe[0] or cv.x + hw > LY.safe[1]:
			p.append(cv.type + " outside the safe area")
	for d in l.enemies:
		if d.has("w") and int(d.w) >= sc.windows.size():
			p.append("bad window")
		if d.has("c") and int(d.c) >= l.get("covers", []).size():
			p.append("bad cover")
		var xs: Array = [d.stand] if d.has("stand") else (d.route.map(func(pt): return pt.x) if d.has("route") else [])
		for x in xs:
			if x - 14 < LY.safe[0] or x + 14 > LY.safe[1]:
				p.append("outlaw outside the safe area")
	return p


## The brief v2 scale guide, and how outlaws look: relaxed before the first shot, alert after.
func _poses_and_scale() -> void:
	var G := GameState
	var screen_h := 720.0
	var drawn := func(n: String) -> float: return Assets.texture(n).get_height() * float(Assets.meta(n, "scale", 1.0)) / screen_h
	ok("Scale: a standing outlaw is about 22% of the screen height", absf(drawn.call("outlaw/idle") - 0.22) < 0.01 and absf(G.geometry.outlaw.hitbox[1] / 180.0 - 0.21) < 0.015,
		"%.3f drawn, %.3f hit area" % [drawn.call("outlaw/idle"), G.geometry.outlaw.hitbox[1] / 180.0])
	ok("Scale: a barrel is about 13% of the screen height", absf(drawn.call("prop/barrel") - 0.13) < 0.01 and absf(G.cover_sizes.barrel[1] / 180.0 - 0.13) < 0.01,
		"%.3f drawn" % drawn.call("prop/barrel"))
	ok("Scale: the revolver is about 20% of the screen height", absf(drawn.call("gun_peacemaker_0/idle") - 0.2) < 0.03, "%.3f" % drawn.call("gun_peacemaker_0/idle"))
	var lv := Level.new()
	add_child(lv)
	lv.setup(0, 2)  # Crossfire: a window, a barrel and a walker
	lv.go()
	var win: Dictionary = lv.enemies[0]
	var peek: Dictionary = lv.enemies[1]
	var walker: Dictionary = lv.enemies[2]
	for e in [win, peek]:
		e.state = "look"
		e.exp = 1.0
	var shown := func() -> Array:
		var out: Array = []
		for e in lv.enemies:
			lv._sync_enemy(e)
			out.append(e.node.asset.get_slice("/", 1))
		return out
	ok("Observation start: every outlaw stands relaxed (idle) before the first shot", shown.call() == ["idle", "idle", "idle"] and lv.observing, str(shown.call()))
	lv._alert()
	lv._step_v2_enemy(walker, 0.0)
	lv._sync_rings()
	ok("The first shot turns them alert: those in view draw (aim) with a draw ring and an alert mark",
		shown.call() == ["aim", "aim", "aim"] and lv.enemies.all(func(e): return e.ring.visible and e.alert.visible), str(shown.call()))
	var cover: Dictionary = lv.covers[peek.c]
	var above: float = (lv.GY - cover.h) - lv.rect_of(peek).position.y
	ok("Behind cover only head, hat and gun show, drawn behind the cover",
		peek.node.get_parent() == lv._actors and lv._actors.get_index() < lv._cover_layer.get_index()
		and above > lv._hitbox.y * 0.25 and above <= lv._hitbox.y * 0.36, "%.1f of %.0f units show" % [above, lv._hitbox.y])
	var w: Dictionary = lv.SC.windows[win.w]
	var opening := Rect2(w.x, w.y, w.w, w.h)
	var fig_w: float = Assets.texture("outlaw/aim").get_width() * win.node.scale.x / lv.PPU
	var share: float = lv.rect_of(win).get_area() / opening.get_area()
	ok("A window outlaw fills about 70% of the window, upper body only, cropped at the sill",
		win.node.get_parent() is Control and win.node.get_parent().clip_contents and absf(share - 0.7) < 0.06 and fig_w < opening.size.x * 1.25,
		"%.0f%% of the window, figure %.1f units wide in a %.1f-unit window" % [share * 100, fig_w, opening.size.x])
	ok("Contact shadows under the cover and the outlaw on the street, none in windows",
		lv.covers.all(func(c): return c.shadow.visible) and walker.shadow.visible and not peek.shadow.visible and not win.has("shadow"))
	remove_child(lv)
	lv.free()


func _new_level(li: int) -> Level:
	var lv := Level.new()
	add_child(lv)
	lv.setup(0, li)
	lv.go()
	return lv


func _drop(lv: Level) -> void:
	remove_child(lv)
	lv.free()


## Brief v2 §11 tests for levels 1 to 4: the intended solution wins at par, the same taps always
## give the same result, the obvious wrong approach doesn't win (at par), triggers fire, cover blocks
## shots, and the observation start holds until the first shot.
func _puzzle_first() -> void:
	var lvls: Array = GameState.levels_for(0)
	for i in 4:
		var l: Dictionary = lvls[i]
		var name := "%d. %s" % [i + 1, l.name]
		var a := run_level(i, [], 1, Callable(), [], 60.0)
		ok(name + ": the intended solution wins at par, untouched, for three stars",
			a.state == "won" and a.used <= int(l.par) and a.hearts == 3 and a.stars == 3, "%s, %d shots, %d hearts, %d stars, %s" % [a.state, a.used, a.hearts, a.stars, a.events])
		var b := run_level(i, [], 1, Callable(), [], 60.0)
		ok(name + ": deterministic: the same taps give the same result, step for step",
			a.events == b.events and a.clock == b.clock and a.used == b.used and a.hearts == b.hearts, "%s at %.3f vs %s at %.3f" % [a.events, a.clock, b.events, b.clock])
		var wr := run_level(i, [], 1, Callable(), l.wrong.taps, 60.0)
		var as_expected: bool = wr.state == "lost" if l.wrong.expect == "lost" else (wr.state == "won" and wr.stars < 3)
		ok(name + ": the obvious wrong approach doesn't win: " + l.wrong.about, as_expected,
			"%s, %d shots, %d stars, %s" % [wr.state, wr.used, wr.stars, wr.events])
		if wr.state == "lost":
			ok(name + ": losing offers a clue, never a bullet", wr.offer == "hint", str(wr.offer))
		match i:
			0:
				ok("Target Practice: the bucket drops onto two bottles at once", count(a.events, "bottle:bucket") == 2 and a.events.has("bucket_drop"), str(a.events))
			1:
				ok("Powder Keg: one shot at the TNT takes both outlaws", count(a.events, "kill:tnt") == 2, str(a.events))
				ok("Powder Keg: shooting one outlaw directly spends the only bullet and fails", count(wr.events, "kill:shot") == 1 and wr.events.has("lost:ammo"), str(wr.events))
			3:
				ok("Chain Reaction: the chain drops the sign onto the TNT; sign and blast clear all three",
					a.events.has("sign_on_tnt") and count(a.events, "kill:sign") + count(a.events, "kill:tnt") == 3 and a.tnt_left == 0, str(a.events))
				ok("Chain Reaction: the TNT shot directly clears only two, never all three", count(wr.events, "kill:tnt") == 2 and wr.state == "lost", str(wr.events))
	# The observation start: nobody draws or fires until the first shot, however long you watch.
	for i in [1, 2, 3]:
		var lv := _new_level(i)
		var drew := false
		for f in 60 * 20:
			lv._step(1.0 / 60.0)
			drew = drew or lv.enemies.any(func(e): return e.state == "aim")
		ok("%s: 20 seconds of watching: no draw, no hearts lost" % lv.L.name, not drew and lv.hearts == 3 and lv.observing and lv.state == "play")
		_drop(lv)
	var lv3 := _new_level(2)
	for f in 30:
		lv3._step(1.0 / 60.0)
	lv3.shoot(Vector2(160, 20), true)  # a shot into the sky
	ok("The first shot, even a miss, ends the observation start", not lv3.observing and lv3.events.has("alert"))
	for f in 60 * 8:
		lv3._step(1.0 / 60.0)
	ok("Once alert, Crossfire's outlaws draw and fire on their fixed timings", lv3.hearts < 3, "%d hearts" % lv3.hearts)
	_drop(lv3)
	# Cover blocks shots: a tap on the barrel while its outlaw is down hits the wood.
	var lv4 := _new_level(2)
	for f in 30:
		lv4._step(1.0 / 60.0)
	var hid: Dictionary = lv4.enemies[1]
	lv4.shoot(lv4.cover_rect(lv4.covers[0]).get_center(), true)
	ok("Cover blocks shots: the barrel takes the bullet, the outlaw behind it is unhurt", hid.alive and lv4.covers[0].holes.size() == 1)
	_drop(lv4)
	# A ducked window outlaw can't be hit.
	var lv5 := _new_level(2)
	var wdw: Dictionary = lv5.enemies[0]
	var opening: Dictionary = lv5.SC.windows[wdw.w]
	lv5.shoot(Vector2(opening.x + opening.w / 2, opening.y + opening.h / 2), true)
	ok("A window outlaw below the sill can't be hit", wdw.alive and wdw.state == "hidden")
	_drop(lv5)
	# Intro cards: observation levels say so; prototype levels say they're already shooting.
	var obs: Array = []
	for i in lvls.size():
		var lv := Level.new()
		add_child(lv)
		lv.setup(0, i)
		obs.append(lv.observing)
		_drop(lv)
	ok("Levels 1 to 4 start in observation; the prototype levels 5 to 10 keep their old timing", obs == [true, true, true, true, false, false, false, false, false, false], str(obs))


## The painted sheriff's office: its layers, hotspots over their painted objects, and the gunsmith.
func _office() -> void:
	var G := GameState
	var keep: Dictionary = G.progress
	SaveManager.data.progress = fresh()
	var pg: Dictionary = G.progress
	ok("The office is the painted one, with the painted gunsmith; no pixel office art is left",
		Assets.texture("office/painted").resource_path.contains("painted/office")
		and ["gunsmith/polish", "gunsmith/hammer", "gunsmith/tip"].all(func(n): return Assets.texture(n).resource_path.contains("painted/gunsmith"))
		and not Assets.names().any(func(n): return Assets.has(n) and Assets.texture(n).resource_path.contains("placeholder/office")))
	var o := Office.new()
	add_child(o)
	var art := Rect2(Vector2.ZERO, Office.ART_SIZE)
	var spots := {}
	for s in Office.SPOTS:
		spots[s.act] = Rect2(s.box[0], s.box[1], s.box[2], s.box[3])
	# Each hotspot covers its painted object (centres measured on assets/painted/office.png).
	var objects := {"duelsoon": Vector2(205, 300), "daily": Vector2(428, 368), "survival": Vector2(428, 481), "board": Vector2(805, 320),
		"profile": Vector2(1215, 226), "trophies": Vector2(800, 665), "gunsmith": Vector2(1498, 430)}
	ok("Every hotspot sits on its painted object: window, calendar, target, board, frame, cabinet, doorway",
		objects.keys().all(func(a): return spots.has(a) and spots[a].has_point(objects[a]) and art.encloses(spots[a])), str(spots.keys()))
	ok("The parchment on the desk is the Continue Hunt hotspot", Office.PARCHMENT.has_point(Vector2(835, 836)) and Office.PARCHMENT.encloses(Office.WRITING)
		and not spots.values().any(func(b): return b.intersects(Office.PARCHMENT)))
	var boxes: Array = spots.values()
	var overlaps := 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				overlaps += 1
	ok("No two office hotspots overlap", overlaps == 0, "%d overlaps" % overlaps)
	var tags_ok := true
	for t in o.plates:  # in painting pixels: beside its own object, over none
		var r := Rect2((t.position + o.global_position - o._origin) / o._k, t.size / o._k)
		var own: Rect2 = t.get_meta("box")
		tags_ok = tags_ok and not boxes.any(func(b): return b.intersects(r)) and not r.intersects(Office.PARCHMENT) and own.grow(70).intersects(r)
	ok("Each object has a small tag beside it, covering no object", o.plates.size() == Office.SPOTS.size() and tags_ok
		and o.plates.all(func(t): return t.theme_type_variation in [&"OfficeTag", &"OfficeTagSoon"] and t.size.y <= 30))
	ok("Locked destinations show a padlock on their tag; open ones don't", o.plates.all(func(t): return (t.icon == Assets.texture("ui/icon_lock")) == (t.theme_type_variation == &"OfficeTagSoon"))
		and o.plates.filter(func(t): return t.icon != null).map(func(t): return t.text) == ["Duel", "Daily Bounty", "Survival"])
	var hung: Array = o._art.get_children().filter(func(c): return c is Button and c.has_meta("art"))
	var cork := Rect2(622, 140, 340, 385)  # the cork's clear middle, between the painted maps and notes
	var poster_boxes: Array = hung.map(func(p): return Rect2(p.position + p.size / 2 - p.size * p.scale / 2, p.size * p.scale).grow(absf(p.rotation) * p.size.y * p.scale.y / 2))
	var apart := true
	for i in poster_boxes.size():
		for j in range(i + 1, poster_boxes.size()):
			apart = apart and not poster_boxes[i].intersects(poster_boxes[j])
	ok("Five painted wanted posters pinned in the cork's clear middle, none overlapping, the current hunt's big in the centre",
		hung.size() == 5 and apart and poster_boxes.all(func(b): return cork.encloses(b))
		and hung.all(func(b): return (b.get_meta("art") as TextureRect).texture.resource_path.contains("painted/poster_ch"))
		and (hung[4].get_meta("art") as TextureRect).texture == Assets.texture("poster/ch0") and hung[4].get_meta("hunt")
		and absf(poster_boxes[4].get_center().x - spots.board.get_center().x) < 4, str(poster_boxes))
	ok("The new save's office: no trophies, the Peacemaker alone on the rack, the gunsmith polishing",
		_art_named(o, "trophy_office/").is_empty() and _art_named(o, "rack/") == ["rack/peacemaker"] and o._smith.asset.begins_with("gunsmith/"))
	var pic: TextureRect = o._art.get_node("Portrait")
	ok("The hunter's portrait fills the gilt frame's canvas", pic.position == Office.FRAME_IN.position and pic.size == Office.FRAME_IN.size
		and pic.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED and spots.profile.encloses(Office.FRAME_IN))
	var kids: Array = o._art.get_children()
	var front: Node = kids.filter(func(c): return c is AssetSprite and c.asset == "office/doorway_front")[0]
	var smith_k: float = Assets.meta("gunsmith/polish", "scale", 1.0)
	var stool_h: float = preload("res://tools/import_office.gd").SMITH_K * 197.0 * smith_k  # his stool, drawn: its sheet height scaled
	var seated: float = Assets.texture("gunsmith/polish").get_height() * smith_k
	ok("The gunsmith sits on his stool over the painted one, behind the doorframe, crate and barrel",
		o._smith.position == Office.STOOL_FOOT and Office.DOORWAY.has_point(Office.STOOL_FOOT) and kids.find(front) > kids.find(o._smith)
		and stool_h >= 0.85 * 124 and stool_h <= 124 and seated > Office.DOORWAY.size.y * 0.55 and seated < Office.DOORWAY.size.y * 0.7, "stool %.0f, seated %.0f" % [stool_h, seated])
	var fp := Image.load_from_file(ProjectSettings.globalize_path("res://assets/painted/office_doorway_front.png"))
	ok("The doorway's front layer is clear in the opening and solid on the frame, crate and barrel",
		fp.get_pixelv(Vector2i(1500, 400) - Vector2i(Office.DOOR_AT)).a == 0 and fp.get_pixelv(Vector2i(1330, 400) - Vector2i(Office.DOOR_AT)).a == 1
		and fp.get_pixelv(Vector2i(1375, 700) - Vector2i(Office.DOOR_AT)).a == 1 and fp.get_pixelv(Vector2i(1640, 680) - Vector2i(Office.DOOR_AT)).a == 1)
	var ink: Array = o.ledger.find_children("*", "Label", true, false).map(func(l): return l.text)
	ok("Continue Hunt is written on the parchment: the next level's name and the bounty's reward",
		ink == ["CONTINUE THE HUNT", "Level 1: Target Practice", "BOUNTY", "$2,500"] and o.ledger.find_children("*", "Label", true, false)[1].theme_type_variation == &"ParchmentTitle", str(ink))
	var writing := Rect2(o._to_local_px(Office.PARCHMENT.position), Office.PARCHMENT.size * o._k)
	ok("The writing stays on the parchment", writing.encloses(o.ledger.get_rect()), str(o.ledger.get_rect()))
	ok("The office light only adds a light vignette and the chosen glow; the room isn't dimmed",
		(o._shade.material as ShaderMaterial).shader.code.contains("vignette") and not (o._shade.material as ShaderMaterial).shader.code.contains("uniform float dim"))
	o._smith_t = Office.IDLE_POSE_TIME + 0.1
	o._physics_process(0.0)
	var idle2: String = o._smith.asset
	var fired: Array = []
	o.act.connect(func(n): fired.append(n))
	o._on_act("gunsmith", spots.gunsmith)
	o._on_act("board", spots.board)  # a second tap while the first is on its way does nothing
	ok("The gunsmith's idle loop moves from polishing to hammering, and he tips his cap when called",
		idle2 == "gunsmith/hammer" and o._smith.asset == "gunsmith/tip" and o._lit.name == "gunsmith")
	ok("One tap lights the chosen object; a second tap meanwhile is ignored", o._lit.t >= 0 and o._lit.name == "gunsmith" and fired.is_empty())
	remove_child(o)
	o.free()
	for c in 2:
		G.chapter_progress(pg, c).stars[str(G.levels_for(c).size() - 1)] = 3
	for w in G.weapons:
		pg.inv.guns[w.id] = true
	var o2 := Office.new()
	add_child(o2)
	ok("Captured bounties put trophies in the cabinet; owned guns go on the rack",
		_art_named(o2, "trophy_office/") == ["trophy_office/ch0", "trophy_office/ch1"] and _art_named(o2, "rack/").size() == G.weapons.size())
	var note: Array = o2.ledger.find_children("*", "Label", true, false).map(func(l): return l.text)
	var sheet: Button = o2.get_children().filter(func(c): return c is Button and c.size.is_equal_approx(Office.PARCHMENT.size * o2._k))[0]
	sheet.pressed.emit()
	ok("Nothing left to hunt: the parchment says so, names the next outlaw, and opens the Bounty board",
		note == ["All available bounties captured", "DIGGER MCCALL ARRIVES SOON"] and o2._lit.name == "board", str(note))
	remove_child(o2)
	o2.free()
	SaveManager.data.progress = keep


func _art_named(o: Office, prefix: String) -> Array:
	return o._art.get_children().filter(func(c): return c is AssetSprite and c.asset.begins_with(prefix)).map(func(c): return c.asset)


## Art batch 1: the painted splash, the walk cycle, Target Practice's bottles and bench, the hanging
## hardware and the painted UI kit. Art only: hit areas stay where geometry.json puts them.
func _batch1() -> void:
	var G := GameState
	# The splash: the painted clocktower, hands on the centre pin sweeping to twelve, the bell swinging.
	var sp := Splash.new()
	add_child(sp)
	ok("The splash is the painted clocktower, not pixel art", Assets.scenes.splash.layers == ["splash/painted"]
		and ["splash/painted", "splash/bell", "splash/minute", "splash/hour", "splash/hero"].all(func(n): return Assets.texture(n).resource_path.contains("assets/painted/")))
	ok("The clock's hands pivot on the face's centre pin", sp._minute.position == Splash.CLOCK_PIN and sp._hour.position == Splash.CLOCK_PIN
		and sp._minute.rotation < -1.0)
	sp.tap()
	sp._now += 4.0
	sp._update_scene()
	ok("The hands sweep to twelve as the bell tolls, and the bell swings", absf(sp._minute.rotation) < 0.01 and absf(sp._hour.rotation) < 0.01
		and sp._tolled and absf(sp._bell.rotation) > 0.01)
	# The title's text, tilted and growing as it stamps in, never reaches the clock face.
	var highest := INF
	var t0: float = sp._t0
	for dt in [3.2, 3.3, 3.4, 3.6, 5.0]:
		sp._now = t0 + dt
		sp._update_scene()
		var l: Label = sp._title
		var w: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		var x0: float = (l.size.x - w) / 2
		for c in [Vector2(x0, 0), Vector2(x0 + w, 0)]:
			highest = minf(highest, (l.get_global_transform() * c).y)
	ok("The HIGH NOON title stays clear of the clock face, tilted and stamping in", highest > sp.face_bottom(), "title top %d, face to %d" % [highest, sp.face_bottom()])
	ok("Two dark figures face each other across the street", sp._hero.scale.x > 0 and sp._rival.scale.x < 0 and sp._hero.position.x < Splash.CLOCK_PIN.x and sp._rival.position.x > Splash.CLOCK_PIN.x)
	sp.tap()
	ok("Tap to draw fires", sp._shot_at >= 0)
	remove_child(sp)
	sp.free()

	# The walk: two frames each way, one per stride, bobbing mid-step.
	var lv := _new_level(2)  # Crossfire's walker
	var w: Dictionary = lv.enemies.filter(func(e): return e.kind == "walker")[0]
	var step: float = G.geometry.walker.frame_step
	w.state = "walk"
	w.dir = 1.0
	w.x = step * 8  # the start of a step: no bob
	lv._sync_view()
	var f0: int = w.run_node.frame
	var y0: float = w.run_node.position.y
	w.x = step * 10  # mid-step
	lv._sync_view()
	ok("A walker walks: an 8-frame cycle each way, paced by the distance walked", w.run_node.asset == "outlaw/walk_right" and f0 == 0 and w.run_node.frame == 2
		and Assets.frame_count("outlaw/walk_left") == 8 and Assets.frame_count("outlaw/walk_right") == 8)
	ok("The walk bobs slightly mid-step", w.run_node.position.y < y0 and y0 - w.run_node.position.y <= float(G.geometry.walker.bob) * 4 + 0.5)
	w.dir = -1.0
	lv._sync_view()
	ok("He faces the way he walks", w.run_node.asset == "outlaw/walk_left")
	_drop(lv)

	# Target Practice: bottles on benches, shattering in place; the bucket on a chain and hook from a signpost.
	lv = _new_level(0)
	ok("The bottles stand on painted benches", lv._benches.size() >= 1 and lv.bottles.all(func(b): return lv._benches.any(
		func(r): return bottle_x(lv, b) > r.position.x and bottle_x(lv, b) < r.end.x and absf(r.position.y - b.y) < 0.01)))
	ok("Each bottle is a painted bottle", lv.bottles.all(func(b): return b.node.asset.begins_with("bottle/whole")))
	var bt: Dictionary = lv.bottles[2]
	lv.shoot(lv.bottle_rect(bt).get_center(), true)
	lv._sync_view()
	ok("A hit bottle swaps to its shattered base and throws painted glass shards", bt.node.asset.begins_with("bottle/broken") and bt.node.visible
		and lv.fx.parts.any(func(q): return q.node.asset == "fx/glass") and Assets.texture("fx/glass").resource_path.contains("assets/painted/"))
	var cx: float = lv.bucket.x + lv.bucket.w / 2
	var rope: Rect2 = lv.bucket_rects()[1]
	var chain: Sprite2D = lv._sign_nodes.bucket_chain
	ok("The bucket hangs from a signpost by a chain of repeated links and a hook", lv._posts.size() == 1 and chain.region_enabled
		and chain.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED and lv._sign_nodes.hook.asset == "prop/hook")
	ok("The chain is inside its hit area, which is unchanged (the bucket and the chain above it)",
		absf(chain.position.y / lv.PPU - rope.position.y) < 0.01 and absf(chain.position.x / lv.PPU - rope.get_center().x) < 2.0
		and rope == Rect2(cx - G.geometry.bucket.rope_width / 2.0, G.geometry.bucket.rope_top, G.geometry.bucket.rope_width, G.geometry.bucket.hang_y - G.geometry.bucket.rope_top))
	ok("The signpost's arm reaches over the bucket", _arm_covers(lv, [cx]))
	ok("The signpost stands clear of the benches", lv._benches.all(func(r): return lv._posts[0] < r.position.x or lv._posts[0] > r.end.x))
	_drop(lv)

	# Every hanging sign: two chains at the hit areas' points, from a signpost's arm, inside the screen.
	for li in [3, 6, 8]:
		lv = _new_level(li)
		var xs: Array = lv.chain_rects().map(func(r): return r.get_center().x)
		var chains: Array = lv._sign_nodes.chains
		ok("%s: the INN sign hangs by two chains of links from a signpost" % G.levels_for(0)[li].name, chains.size() == 2
			and absf(chains[0].position.x / lv.PPU - xs[0]) < 0.01 and absf(chains[1].position.x / lv.PPU - xs[1]) < 0.01
			and lv._posts.size() == 1 and _arm_covers(lv, xs) and lv._posts[0] > G.geometry.hanging.post_room[0] and lv._posts[0] < G.geometry.hanging.post_room[1])
		_drop(lv)

	# The UI kit: off states are slashed versions, and a padlock marks locked levels.
	ok("Sound and music off are the painted icons with a slash", Assets.texture("ui/icon_sound_off").resource_path.ends_with("ui_icon_sound_off.png")
		and Assets.texture("ui/icon_music_off").resource_path.ends_with("ui_icon_music_off.png"))
	var locked := BountyWall.poster(1, "locked", GameState.progress)
	var captured := BountyWall.poster(0, "captured", GameState.progress)
	ok("Locked posters are faded and can't be tapped; captured ones carry the painted CAPTURED stamp", locked.disabled and locked.get_meta("art").material != null
		and (captured.get_meta("stamp") as TextureRect).texture == Assets.texture("ui/stamp_captured"))
	locked.free()
	captured.free()


func bottle_x(lv: Level, b: Dictionary) -> float:
	return lv.bottle_rect(b).get_center().x


## Whether the level's signpost arm (between its brace and its end) is over every x.
func _arm_covers(lv: Level, xs: Array) -> bool:
	var post: AssetSprite = lv._back_props.get_children().filter(func(c): return c is AssetSprite and c.asset == "prop/signpost")[0]
	var k: float = post.scale.x
	var a: float = lv._posts[0] + Assets.point("prop/signpost", "arm_from").x * k / lv.PPU
	var b: float = lv._posts[0] + Assets.point("prop/signpost", "arm_to").x * k / lv.PPU
	return xs.all(func(x): return x >= minf(a, b) - 0.01 and x <= maxf(a, b) + 0.01)


## On-screen size of a sprite, in pixels of the 720-pixel-tall screen: its opaque pixels, through its
## transform, cut to the screen (0 to 720 down) and to its clip (a window's opening). `below` cuts it
## at a height too (the top of the cover a peeker hides behind).
static func screen_rect(s: AssetSprite, below := INF) -> Rect2:
	var t: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	var used := t.get_image().get_used_rect()
	var xf := s.get_global_transform()
	var local := Rect2(s.offset + Vector2(used.position), Vector2(used.size))
	if s.flip_h:
		local.position.x = -s.offset.x - used.end.x if s.centered else s.offset.x + t.get_width() - used.end.x
	var r := Rect2(xf * local.position, Vector2.ZERO)
	for c in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		r = r.expand(xf * c)
	var cut := Rect2(-10000, 0, 20000, minf(720, below))
	var p := s.get_parent()
	if p is Control and p.clip_contents:
		cut = cut.intersection(Rect2(p.global_position, p.size))
	return r.intersection(cut)


## The brief v2 scale guide, measured as each sprite's opaque pixels on the 720-pixel-tall screen
## (what the phone shows: the art is never scaled to the screen's width), and every prop's art
## against its own hit area, so art swaps can't quietly shrink or grow the gameplay plane.
func _scale_guide() -> void:
	var G := GameState
	var ppu: float = G.geometry.pixels_per_unit
	var pct := func(px: float) -> float: return px / 7.2
	var problems: Array = []
	var check := func(what: String, got: float, want: float, tol: float) -> void:
		if absf(got - want) > tol:
			problems.append("%s %.1f%% (want %.0f%% ± %.0f)" % [what, got, want, tol])
	for li in [2, 3]:  # Crossfire: a window, a peeker, a walker, a barrel; Chain Reaction: three standing, the TNT, the sign
		var lv := _new_level(li)
		lv.observing = false
		for e in lv.enemies:
			e.exp = 1.0
			e.state = "aim"
		lv._sync_view()
		for e in lv.enemies:
			match e.kind:
				"stand", "walker":
					check.call("standing outlaw", pct.call(screen_rect(e.node).size.y), 22, 1.5)
				"window":
					var wh: float = lv.SC.windows[e.w].h * ppu
					check.call("window outlaw (of his window)", screen_rect(e.node).size.y / wh * 100, 70, 8)
					if screen_rect(e.node).end.y > (lv.SC.windows[e.w].y + lv.SC.windows[e.w].h) * ppu + 0.5:
						problems.append("window outlaw shows below the sill")
				"cover":  # only head, hat and gun over the cover: about a third of him
					var top: float = (lv.GY - lv.covers[e.c].h) * ppu
					var full: float = screen_rect(e.node).size.y
					check.call("peeker over cover (of his height)", screen_rect(e.node, top).size.y / full * 100, 38, 10)
		_drop(lv)
	var art := func(n: String) -> Vector2:  # drawn size in units
		var used := Assets.texture(n).get_image().get_used_rect().size
		return Vector2(used) * float(Assets.meta(n, "scale", 1.0)) / ppu
	check.call("barrel", art.call("prop/barrel").y * ppu / 7.2, 13, 1.5)
	var gun: Vector2 = art.call("gun_peacemaker_0/idle")
	check.call("revolver", gun.y * ppu / 7.2, 20, 2)
	# Every other prop in proportion: its art against its hit area.
	var sizes: Dictionary = G.geometry.cover_sizes
	for t in ["barrel", "crate", "tnt", "wagon", "trough"]:
		var hide: float = sizes[t][1]
		check.call("prop/%s (of its cover height)" % t, art.call("prop/" + t).y / hide * 100, 100, 30)
	check.call("tall bottle (of its hit height)", art.call("bottle/whole0").y / G.geometry.bottle.hitbox[1] * 100, 100, 12)
	check.call("bench (from the bottles' rail to the street)", art.call("prop/bench").y / (G.geometry.scenes.street.GY - G.geometry.bottle.rail_y) * 100, 100, 15)
	check.call("INN sign (of its board width)", art.call("prop/sign").x / G.geometry.sign.board[0] * 100, 100, 15)
	check.call("bucket (of its hit width)", art.call("prop/bucket").x / G.geometry.bucket.size[0] * 100, 100, 15)
	var main_s: Script = load("res://scripts/main.gd")
	ok("HUD bullets are big and spaced out, so they're easy to count", main_s.BULLET_SIZE.y >= 52 and main_s.BULLET_GAP >= 10)
	ok("Scale guide: standing outlaws 22%, barrels 13%, window outlaws 70% of the window, peekers head and hat only, revolver 20%, props in proportion",
		problems.is_empty(), "; ".join(problems))


## The bounty portraits and painted wanted posters: J.R.'s is a silhouette until his bounty can be hunted.
func _portraits() -> void:
	var squares := true
	for i in 5:
		var t := Assets.texture("portrait/ch%d" % i)
		squares = squares and t.resource_path.contains("assets/painted/") and t.get_width() == t.get_height()
	ok("Each bounty has its own square painted portrait (for the trophy labels)", squares)
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/incoming/Vintage Western Wanted Poster Collection.png"))
	var cut := true
	for i in 5:
		var t := Assets.texture("poster/ch%d" % i)
		var im := Image.load_from_file(ProjectSettings.globalize_path(t.resource_path))  # the file itself, not its compressed import
		cut = cut and (t.resource_path.ends_with("painted/poster_ch%d.png" % i) and im.get_width() > 400 and im.get_height() > 690
			and im.get_pixel(0, 0).a < 0.1 and im.get_pixel(im.get_width() / 2, im.get_height() / 2).a > 0.95)
	ok("Each bounty's wanted poster is cut from the painted sheet, on real transparency", cut and sheet.detect_alpha() != Image.ALPHA_NONE)
	var jr := Image.load_from_file(ProjectSettings.globalize_path("res://assets/painted/poster_ch4.png"))
	var dark := Image.load_from_file(ProjectSettings.globalize_path("res://assets/painted/poster_ch4_locked.png"))
	var win := Rect2i(Vector2i(0, roundi(jr.get_height() * BountyWall.WINDOW_TOP)), Vector2i(jr.get_width(), roundi(jr.get_height() * (BountyWall.WINDOW_BOTTOM - BountyWall.WINDOW_TOP))))
	var same_out := true
	var inked := 0
	var figure := 0
	for y in range(0, jr.get_height(), 3):
		for x in range(0, jr.get_width(), 3):
			var a := jr.get_pixel(x, y)
			var b := dark.get_pixel(x, y)
			if not win.grow(2).has_point(Vector2i(x, y)):
				same_out = same_out and a.is_equal_approx(b)
			elif not a.is_equal_approx(b):
				figure += 1
				inked += 1 if b.get_luminance() < 0.12 else 0
	var share := float(figure) / (win.get_area() / 9.0)
	ok("J.R.'s locked poster: the same paper and lettering, only his figure inked into a dark silhouette",
		same_out and inked > figure * 0.95 and share > 0.3 and share < 0.75, "figure %.2f of the window, %d of %d dark" % [share, inked, figure])
	var open_jr := BountyWall.poster(4, "open", fresh())
	var shut_jr := BountyWall.poster(4, "soon", fresh())
	ok("J.R.'s poster shows his silhouette until he can be hunted, then his face",
		(shut_jr.get_meta("art") as TextureRect).texture == Assets.texture("poster/ch4_locked") and (open_jr.get_meta("art") as TextureRect).texture == Assets.texture("poster/ch4")
		and (BountyWall.poster(1, "soon", fresh()).get_meta("art") as TextureRect).texture == Assets.texture("poster/ch1"))
	open_jr.free()
	shut_jr.free()


## The Bounty board wall: big posters pinned to the cork, swiping with snapping between its ends,
## opening on the current hunt, and a tap opening a hunt.
func _bounty_wall() -> void:
	var G := GameState
	var keep: Dictionary = SaveManager.data.progress
	var was_pt: bool = SaveManager.data.settings.get("playtest", false)
	SaveManager.data.settings.playtest = false
	var pg := fresh()
	G.chapter_progress(pg, 0).stars[str(G.levels_for(0).size() - 1)] = 3  # Iron Eli captured: the hunt moves on
	SaveManager.data.progress = pg
	ok("Iron Eli's reward is $2,500, as in the brief", G.chapters[0].reward == "$2,500" and int(G.chapters[0].bounty) == 2500)
	var made: Array = []
	for safe in [Vector3.ZERO, Vector3(108, 108, 38)]:  # 16:9, and an iPhone's 19.5:9 with its safe area
		var w := BountyWall.new()
		w.safe_lrb = safe
		add_child(w)
		w.size = Vector2(1280 if safe.x == 0 else 1560, 720)
		w.show_poster(G.current_hunt(pg, false))
		made.append(w)
	for w in made:
		var tag := "16:9" if w.safe_lrb.x == 0 else "19.5:9"
		var first_left: float = w.size.x / 2 - BountyWall.POSTER.x / 2 - w.scroll_range().x
		var last_right: float = w.size.x / 2 + BountyWall.POSTER.x / 2 + (w.posters.size() - 1) * BountyWall.step() - w.scroll_range().y
		ok("%s: no bare cork before the first poster or after the last" % tag, first_left <= w.safe_lrb.x + BountyWall.EDGE + 0.5
			and last_right >= w.size.x - w.safe_lrb.y - BountyWall.EDGE - 0.5)
		var cur := G.current_hunt(pg, false)
		var centre_x: float = w.size.x / 2 - w.scroll + cur * BountyWall.step()
		ok("%s: the board opens on the current hunt, as near the middle as the ends allow" % tag, w.centred() == cur or absf(centre_x - w.size.x / 2) < BountyWall.step() / 2)
		w.show_poster(0)
		var s: Array[float] = w.stops()
		var drag := func(dx: float, speed: float) -> void:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = w.size / 2
			w._gui_input(press)
			for k in 4:
				var m := InputEventMouseMotion.new()
				m.position = w.size / 2 + Vector2(dx * (k + 1) / 4.0, 0)
				m.velocity = Vector2(speed, 0)
				w._gui_input(m)
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.position = w.size / 2 + Vector2(dx, 0)
			w._gui_input(up)
			for k in 60:
				w._process(1.0 / 60)
		drag.call(-(s[1] - s[0]) * 0.6, -200)
		ok("%s: swiping along the board snaps to the next stop" % tag, w.scroll == s[1])
		drag.call((s[1] - s[0]) * 0.2, 150)
		ok("%s: a short, slow swipe settles back where it was" % tag, w.scroll == s[1])
		drag.call(-60, -1500)
		ok("%s: a flick moves on one stop" % tag, w.scroll == s[2])
		drag.call(-BountyWall.step() * 3, -300)
		ok("%s: the board stops at its far end" % tag, w.scroll == s[-1])
	var w: BountyWall = made[0]
	ok("Posters are 75 to 80% of the screen tall, side by side, each its painted poster filling it",
		BountyWall.POSTER.y / 720.0 >= 0.75 and BountyWall.POSTER.y / 720.0 <= 0.8
		and w.posters.size() == G.chapters.size() and w.posters[1].position.x - w.posters[0].position.x == BountyWall.step()
		and range(4).all(func(i): return ((w.posters[i].get_meta("art") as TextureRect).texture == Assets.texture("poster/ch%d" % i)
			and (w.posters[i].get_meta("art") as TextureRect).size == BountyWall.POSTER)))
	var aspect := Assets.texture("poster/ch0").get_size()
	ok("The poster's size keeps the painting's shape", absf(BountyWall.POSTER.x / BountyWall.POSTER.y - aspect.x / aspect.y) < 0.02)
	ok("Nothing is lettered over the paintings: the posters carry their own names, titles and rewards",
		w.posters.all(func(p): return p.find_children("*", "Label", true, false).all(func(l): return l.theme_type_variation in [&"PosterStars", &"StampFadedLabel"])))
	var rewards := ["$2,500", "$3,500", "$5,000", "$7,500", "$10,000"]
	ok("Bounty rewards match the posters: $2,500, $3,500, $5,000, $7,500, $10,000",
		range(5).all(func(i): return G.chapters[i].reward == rewards[i] and int(G.chapters[i].bounty) == int(rewards[i].replace("$", "").replace(",", ""))))
	ok("Every bounty has its poster name and title", G.chapters.all(func(c): return c.has("poster_name") and c.has("title"))
		and G.chapters[1].poster_name == "Cole Haggerty" and G.chapters[4].title == "Name Unknown")
	var stamp_of := func(i: int) -> Variant: return w.posters[i].get_meta("stamp") if w.posters[i].has_meta("stamp") else null
	var cap: TextureRect = stamp_of.call(0)
	ok("CAPTURED is stamped low across the portrait, smaller and a little see-through, so the face shows",
		cap.texture == Assets.texture("ui/stamp_captured") and cap.size.x * cap.scale.x <= BountyWall.POSTER.x * 0.7 and cap.modulate.a < 1
		and cap.position.y >= BountyWall.POSTER.y * (BountyWall.WINDOW_TOP + BountyWall.WINDOW_BOTTOM) / 2 - 4
		and cap.position.y + cap.size.y <= BountyWall.POSTER.y * BountyWall.WINDOW_BOTTOM + 2, str(cap.get_rect()))
	var soon: PanelContainer = stamp_of.call(2)
	var ink: Color = soon.get_child(0).get_theme_color("font_color")
	ok("COMING SOON is stamped in clear dark brown ink, on a faded poster", soon.theme_type_variation == &"StampFaded" and ink.a == 1.0 and ink.get_luminance() < 0.2 and ink.r > ink.b
		and (w.posters[2].get_meta("art").material as ShaderMaterial).shader.resource_path.ends_with("poster_faded.gdshader")
		and w.posters[0].get_meta("art").material == null and w.posters[1].get_meta("art").material == null)
	ok("J.R. is coming soon: his poster shows his silhouette", (w.posters[4].get_meta("art") as TextureRect).texture == Assets.texture("poster/ch4_locked"))
	ok("Star progress shows on started bounties only", w.posters[0].has_meta("stars") and not w.posters[1].has_meta("stars") and not w.posters[2].has_meta("stars"))
	for m in made:
		var row: Control = m.posters[0].get_meta("stars")
		var bottom: float = m._strip.position.y + row.position.y + row.size.y
		ok("%s: the stars sit on the cork just below the poster, above the frame's bottom rail" % ("16:9" if m.safe_lrb.x == 0 else "19.5:9"),
			row.position.y >= BountyWall.POSTER.y and row.position.y <= BountyWall.POSTER.y + 12 and bottom <= 720 - BountyWall.RAIL_H - 4
			and m._strip.position.y >= BountyWall.RAIL_H + 4, "%.0f to %.0f" % [m._strip.position.y, bottom])
	ok("A lantern's light pool and vignette lie over the board", w._light.material is ShaderMaterial and (w._light.material as ShaderMaterial).shader.resource_path.ends_with("board_light.gdshader"))
	var opened: Array = []
	w.chosen.connect(func(i): opened.append(i))
	for i in [1, 2]:  # Cole Haggerty can be hunted; Digger McCall is coming soon
		w.scroll = i * BountyWall.step()
		w.target = w.scroll
		w._place()
		var at: Vector2 = w.size / 2
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = at
		w._gui_input(press)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.position = at
		w._gui_input(up)
	ok("Tapping a poster that can be hunted opens its hunt screen; others do nothing", opened == [1])
	# J.R. unlocked: the first time his poster shows his face, the shadow lifts away from the portrait.
	var persist: bool = SaveManager.persist
	SaveManager.persist = false
	var jr := BountyWall.poster(4, "open", pg)
	w._strip.add_child(jr)
	var veil: TextureRect = jr.get_meta("veil")
	ok("J.R. unlocked: his silhouette poster lies over his face, ready to lift", veil.texture == Assets.texture("poster/ch4_locked")
		and (veil.material as ShaderMaterial).shader.resource_path.ends_with("poster_veil.gdshader") and (jr.get_meta("art") as TextureRect).texture == Assets.texture("poster/ch4"))
	w._lift_veil(4, veil)
	var tw: Tween = w.get_tree().get_processed_tweens().back()
	tw.custom_step(0.6 + 0.9)
	var half: float = veil.get_meta("lift")
	tw.custom_step(1.0)
	ok("The shadow lifts away over a couple of seconds, once: afterwards his face shows for good", half > 0.3 and half < 0.7
		and veil.is_queued_for_deletion() and pg.revealed.has("4") and not BountyWall.poster(4, "open", pg).has_meta("veil")
		and not BountyWall.poster(4, "open", fresh(), Vector2(120, 200), false, false).has_meta("veil"), "halfway %.2f" % half)
	SaveManager.persist = persist
	jr.free()
	for m in made:
		remove_child(m)
		m.free()
	SaveManager.data.progress = keep
	SaveManager.data.settings.playtest = was_pt
