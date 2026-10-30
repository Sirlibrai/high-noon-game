extends Node
## The prototype's self-tests (specs/expected_results.md, reference function
## `selftest`), run headless:
##   Godot --headless --path . res://tests/selftest.tscn
## Exits with code 0 when every check passes.

var results: Array = []


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
	ok("Arcade, out of ammo with one outlaw left: +1 bullet", G.offer_for(arcade, "ammo", 1, false) == "bullet")
	ok("Arcade, two outlaws left: no ad offer", G.offer_for(arcade, "ammo", 2, false) == null)
	ok("Puzzle levels never offer bullets, only clues", G.offer_for(puzzle, "ammo", 1, false) == "hint")
	ok("Single-stage duels offer to keep your rounds", G.offer_for(boss_l, "shot", 0, false) == "continue")
	ok("Iron Eli, lost in stage 1: no ad offer", G.offer_for({"eli": true}, "shot", 1, false, 1) == null)
	ok("Iron Eli, lost in stage 2 or 3: retry from that stage", G.offer_for({"eli": true}, "shot", 1, false, 2) == "checkpoint" and G.offer_for({"eli": true, "duel": true}, "shot", 0, false, 3) == "checkpoint")
	ok("A clean perfect run earns three stars", G.stars_for({"par": 3}, {"used": 3, "damaged": false}) == 3 and G.stars_for({"duel": true}, {"hearts": 3}) == 3)
	ok("Any assistance caps a clear at two stars", G.stars_for({"par": 3}, {"used": 3, "damaged": false, "assisted": true}) == 2 and G.stars_for({"duel": true}, {"hearts": 3, "assisted": true}) == 2)
	ok("Assistance never lowers a one-star clear", G.stars_for({"par": 3}, {"used": 9, "damaged": true, "assisted": true}) == 1)
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
				if cv[1] < 0 or cv[1] + G.cover_sizes[cv[0]][0] > 270:
					problems.append(cv[0] + " behind the gun")
			if l.get("puzzle", false) and not (l.has("hint") and l.has("hintTarget")):
				problems.append("puzzle without hint")
			ok(name + ": data valid", problems.is_empty(), ", ".join(problems))

	# replaceable art: one manifest, image files only
	ok("Manifest: every file exists and every theme slot resolves", Assets.errors.is_empty(), "; ".join(Assets.errors))
	var missing: Array = []
	for c in 2:
		for l in G.levels_for(c):
			for cv in l.get("covers", []):
				if not Assets.has("prop/" + cv[0]):
					missing.append("prop/" + cv[0])
			var needed: Array = []
			if c == 0 and l.get("duel", false) and not Assets.rigs.has(G.BOSS_SPRITES[l.boss]):
				missing.append("rig " + G.BOSS_SPRITES[l.boss])
			if c == 0 and l.get("eli", false):
				needed = ["iron_eli_parts/armour", "iron_eli_parts/armour_cracked", "fx/dynamite", "fx/fuse_spark", "fx/ping", "fx/armour"]
				if not Assets.rigs.has("iron_eli"):
					missing.append("rig iron_eli")
			if c == 0 and l.get("puzzle", false):
				needed.append("fx/hint_glow")
			for n in needed:
				if not Assets.has(n):
					missing.append(n)
	ok("Manifest: every Main Street prop, boss, effect and Iron Eli stage has art", missing.is_empty(), ", ".join(missing))

	# Cut-out characters: every outlaw is built from parts and has the gameplay clips.
	var rig_gaps: Array = []
	for rig_name in ["outlaw", "iron_eli", "black_jack"]:
		if not Assets.rigs.has(rig_name):
			rig_gaps.append(rig_name + ": missing")
			continue
		var def: Dictionary = Assets.rigs[rig_name]
		var names: Array = def.parts.map(func(p): return p.name)
		for part in ["head", "torso", "arm_back", "arm_front", "gun_hand", "legs"]:
			if not names.has(part):
				rig_gaps.append("%s: no %s" % [rig_name, part])
		for p in def.parts:
			if not Assets.has(p.asset):
				rig_gaps.append("%s: no art %s" % [rig_name, p.asset])
		for clip in ["idle", "pop_up", "aim", "flinch", "fall", "run"]:
			if not Assets.rig_animations.get(def.animations, {}).has(clip):
				rig_gaps.append("%s: no %s clip" % [rig_name, clip])
	ok("Rigs: outlaw, Iron Eli and Black Jack each have head, torso, arms, gun hand and legs, and every clip", rig_gaps.is_empty(), ", ".join(rig_gaps))
	var rig := CutoutRig.make("iron_eli", self)
	var played: Array = []
	for clip in ["pop_up", "aim", "flinch", "fall", "run", "idle"]:
		rig.pose(clip)
		rig._player.advance(0.1)
		if rig.current == clip and rig._player.current_animation == clip:
			played.append(clip)
	var aiming_shows_gun: bool
	rig.pose("aim")
	rig._player.advance(0.05)
	aiming_shows_gun = rig.parts.gun_hand.visible and not rig.parts.arm_front.visible
	rig.pose("idle")
	ok("Rigs build from the manifest and play every clip", played.size() == 6, str(played))
	ok("Rigs: aiming swaps the arms for the gun hand, idle swaps back", aiming_shows_gun and not rig.parts.gun_hand.visible and rig.parts.arm_front.visible)
	rig.free()

	# Painted look: a 1280×720 base with smooth filtering, gameplay geometry unchanged.
	ok("Base resolution is 1280×720 with linear texture filtering",
		ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720
		and ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 1)
	ok("Gameplay units still map the 320×180 stage onto the 1280×720 base", float(G.geometry.pixels_per_unit) * G.geometry.stage.width == 1280.0)
	# The revolver stays small in the bottom-right corner at every tilt (style guide: about the bottom-right eighth).
	var gun := Assets.texture("gun_peacemaker_0/idle")
	var gun_scale: float = G.geometry.gun.scale
	var ppu: float = G.geometry.pixels_per_unit
	var anchor := Assets.anchor("gun_peacemaker_0/idle")
	var g: Dictionary = G.geometry.gun
	var worst := Vector2(320, 180)
	for ang in [g.reload_angle, g.angle_range[0], g.rest_angle, g.angle_range[1]]:
		var pivot := Vector2(320 - g.pivot_from_corner[0] + g.kick_offset[0], 180 - g.pivot_from_corner[1])
		for corner in [Vector2.ZERO, Vector2(gun.get_width(), 0), Vector2(0, gun.get_height()), gun.get_size()]:
			var p: Vector2 = pivot + ((corner - anchor) * gun_scale / ppu).rotated(ang)
			worst = Vector2(minf(worst.x, p.x), minf(worst.y, p.y))
	ok("The revolver stays in the bottom-right corner at every tilt", worst.x >= 320 * 0.75 and worst.y >= 180 * 0.5, "reaches x %.0f, y %.0f" % [worst.x, worst.y])
	var gun_gaps: Array = []
	for w in G.weapons:
		for f in w.fins.size():
			var n := "gun_%s_%d/idle" % [w.id, f]
			if not Assets.has(n) or not Assets.has("gun_%s_%d/reload" % [w.id, f]) or Assets.point(n, "muzzle") == Vector2.ZERO:
				gun_gaps.append(n)
	ok("Manifest: every gun finish has idle and reload art with a muzzle point", gun_gaps.is_empty(), ", ".join(gun_gaps))
	var street_art: Dictionary = Assets.scenes.main_street
	var narrow: Array = street_art.layers.filter(func(n): return Assets.texture(n).get_width() <= 640)
	ok("Main Street background layers are wider than 640 px", narrow.is_empty(), ", ".join(narrow))
	ok("Main Street has a frame for every window", street_art.window_frames.size() == G.scenes.street.windows.size())
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
	_iron_eli_rules()

	var passed := results.filter(func(x): return x[1]).size()
	for x in results:
		print(("PASS " if x[1] else "FAIL ") + x[0] + ("" if x[1] or x[2] == "" else " (" + x[2] + ")"))
	print("Self-tests: %d of %d passed" % [passed, results.size()])
	get_tree().quit(0 if passed == results.size() else 1)


## Plays a Main Street level with the scripted player; tries a few seeds, as timings are random.
func run_level(li: int, foul_rounds := [], tries := 5, prepare := Callable()) -> Dictionary:
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
		AutoPlayer.play(lv, bot)
		out = {"state": lv.state, "used": lv.used, "hearts": lv.hearts, "events": lv.events.duplicate(),
			"stars": box.stars, "offer": box.offer, "tnt_left": lv.covers.filter(func(c): return c.type == "tnt" and c.alive).size(),
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
			"Powder keg":
				ok("Puzzle: Powder keg is solved by shooting the TNT", r.state == "won" and r.used == 1 and count(r.events, "kill:tnt") == 3, str(r.events))
			"Chain reaction":
				ok("Puzzle: Chain reaction, one TNT sets off the other", r.state == "won" and r.tnt_left == 0 and count(r.events, "kill:tnt") >= 2, str(r.events))
			"Hang ’em high", "Bank job":
				ok("Puzzle: %s is solved by shooting the sign rope" % l.name, r.state == "won" and r.events.has("kill:sign"), str(r.events))
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
	ok("Desk, new save: Continue hunt, Level 1: Target practice, 0 of 5, $1,000",
		d.hunting and d.ch == 0 and d.subtitle == "Level 1: Target practice" and d.caught == 0 and d.reward == "$1,000", str(d))
	ok("Posters, new save: Iron Eli open, the train locked, three coming soon",
		states.call(pg, false) == ["open", "locked", "soon", "soon", "soon"], str(states.call(pg, false)))
	ok("Office board, new save: Iron Eli's poster is in the middle", G.current_hunt(pg, false) == 0)
	for l in 3:
		G.apply_win(pg, 0, l, 3, o10(1000))
	d = G.desk_status(pg, false)
	ok("Desk continues at the furthest unlocked level (Level 4: Chain reaction)", d.subtitle == "Level 4: Chain reaction", str(d))
	G.apply_win(pg, 0, 9, 2, o10(1000, true, true))
	d = G.desk_status(pg, false)
	ok("Desk, Iron Eli captured: Continue hunt goes to the train, 1 of 5, $1,500",
		d.hunting and d.ch == 1 and d.subtitle == "Level 1: All aboard" and d.caught == 1 and d.reward == "$1,500", str(d))
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
		"prop/barrel": "placeholder/props/crate.png",
		"prop/tnt": "placeholder/props/no_such_file.png",
		"no_such/name": "placeholder/props/crate.png",
		"outlaw_parts/head": {"frames": ["placeholder/props/bottle.png"]}}}
	Skins.apply(test_skin)
	ok("A skin's override is used first", Assets.texture("prop/barrel").resource_path.ends_with("placeholder/props/crate.png")
		and Assets.texture("outlaw_parts/head").resource_path.ends_with("placeholder/props/bottle.png"))
	ok("A missing override falls back to the standard art",
		Assets.texture("prop/tnt").resource_path == plain["prop/tnt"][0] and Assets.skin_fallbacks.has("prop/tnt")
		and Assets.skin_fallbacks.has("no_such/name (not in the manifest)"))
	ok("Names a skin does not override keep the standard art",
		Assets.texture("prop/crate").resource_path == plain["prop/crate"][0] and Assets.texture("fx/blood").resource_path == plain["fx/blood"][0])
	ok("A skin's shader goes on the final full-screen layer", Skins.final_material() != null)
	ok("Switching skins never changes geometry or hit areas", hitbox_snapshot() == plain_hits)
	var rig := CutoutRig.make("outlaw", self)
	ok("Skinned rig parts still build", rig.parts.head.sprite_frames != null and rig.parts.has("gun_hand"))
	rig.free()
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
