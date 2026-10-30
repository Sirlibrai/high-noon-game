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
			if c == 0 and l.get("duel", false):
				needed = ["idle", "aim", "hit"].map(func(p): return G.BOSS_SPRITES[l.boss] + "_duel/" + p)
			if c == 0 and l.get("eli", false):
				needed = ["iron_eli/idle", "iron_eli/aim", "iron_eli/run", "iron_eli_armour/intact", "iron_eli_armour/cracked",
					"iron_eli_duel/idle", "iron_eli_duel/aim", "iron_eli_duel/hit", "fx/dynamite", "fx/fuse_spark", "fx/ping", "fx/armour"]
			if c == 0 and l.get("puzzle", false):
				needed.append("fx/hint_glow")
			for n in needed:
				if not Assets.has(n):
					missing.append(n)
	ok("Manifest: every Main Street prop, boss, effect and Iron Eli stage has art", missing.is_empty(), ", ".join(missing))
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


func o10(bounty: int, boss := false, last := false) -> Dictionary:
	return {"boss": boss, "last": last, "bounty": bounty, "count": 10}
