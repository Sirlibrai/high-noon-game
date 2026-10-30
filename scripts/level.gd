class_name Level
extends Node2D
## One showdown: an arcade level or a duel. The gameplay is a port of the
## prototype's loadLevel / update / shoot / duelUpdate, in its 320×180 units so
## levels.json and rules.md apply as written. Every hitbox, peek distance and
## radius comes from data/geometry.json; nothing depends on sprite sizes.
##
## The view is made only of AssetSprites named in assets/manifest.json. Each
## frame _sync_view() places them from the gameplay state, at
## geometry.pixels_per_unit (2) pixels per unit. Characters are anchored at
## their feet and props at their base.
##
## Covers all of Main Street: cover, window, runner and hostage-taking
## outlaws, bottles and the tutorial, TNT chains, the hanging sign, puzzle
## clues, duels, and Iron Eli's three stages (rules.md §8). The train's
## coupling pin, flatcar and tunnels come with the train chapter.

signal callout(msg: String, small: bool, ms: int)
signal callout_cleared
signal won(result: Dictionary)
signal lost(reason: String, offer: Variant)

var W := 320
var H := 180
var PPU := 2.0
var G: Dictionary  # data/geometry.json
## The visible stage in units; wider than 0..320 on wide phones. Set by Main.
var view_left := 0.0
var view_right := 320.0

var ci := 0
var li := 0
var L: Dictionary
var SC: Dictionary
var GY := 160
var state := "intro"  # intro, play, pause, won, lost
var frame := 0
var hearts := 3
var bullets := 0
var used := 0
var damaged := false
var covers: Array = []
var enemies: Array = []
var bottles: Array = []
var hang_sign: Variant = null
var decals: Array = []
var pending_blasts: Array = []
var recoil := 0
var flash := 0
var hurt_flash := 0
var shake := 0
var aim_pt: Variant = null
var mouse: Variant = null
var end_timer := 0.0
var out_of_ammo_t := 0.0
var duel: Variant = null
var tumble := {"x": -20.0, "on": false}
var tut: Variant = null
var sc_used := false
var assisted := false
var gun_ang := 0.35
var kick := 0.0
var cyl := 6
var reload_t := 0.0
var hit_stop := 0
var last_aim: Variant = null
var touch := false
var weapon: Dictionary
var gun_asset := ""
var boss_set := ""
var hint_lvl := 0
## Iron Eli: the stage reached (for the checkpoint offer), a pending stage change, thrown dynamite.
var eli_ck := 1
var eli_pend := 0
var eli_pend_t := 0.0
var throws: Array = []
## What happened, for the scripted-player tests: "crack:tnt", "kill:sign", "stage:2", "throw"...
var events: Array[String] = []

var fx: FxLayer
var _hitbox := Vector2(14, 19)
var _decal_layer: Node2D
var _window_clips: Array[Control] = []
var _back_props: Node2D
var _actors: Control
var _cover_layer: Node2D
var _front: Node2D
var _hostage_layer: Node2D
var _ring_layer: Node2D
var _throw_layer: Node2D
var _hint_glow: NinePatchRect
var _duel_layer: Node2D
var _tumble: AssetSprite
var _arrow: AssetSprite
var _sign_nodes := {}
var _duel_nodes := {}
var _gun: AssetSprite
var _muzzle_flash: AssetSprite
var _cross: AssetSprite
var _hurt: TextureRect


func setup(chapter: int, index: int) -> void:
	ci = chapter
	li = index
	G = GameState.geometry
	PPU = float(G.pixels_per_unit)
	W = int(G.stage.width)
	H = int(G.stage.height)
	_hitbox = _vec(G.outlaw.hitbox)
	L = GameState.level(ci, li).duplicate(true)  # Iron Eli's last stage turns his level into a duel
	hint_lvl = GameState.hint_level(ci, li)
	SC = GameState.scene_for(ci)
	GY = int(SC.GY)
	touch = GameState.touch_mode
	weapon = GameState.equipped_weapon()
	var eq: Dictionary = GameState.progress.inv.equip
	gun_asset = "gun_%s_%d" % [eq.gun, int(eq.fin)]
	hearts = 3
	used = 0
	damaged = false
	if L.get("tutorial", false):
		tut = {"step": 0}
	if L.get("duel", false):
		_start_duel()
	else:
		bullets = int(L.bullets)
		cyl = mini(int(weapon.cyl), bullets)
		for cv in L.covers:
			var size: Array = GameState.cover_sizes[cv[0]]
			covers.append({"type": cv[0], "x": float(cv[1]), "w": int(size[0]), "h": int(size[1]), "alive": true, "holes": []})
		for x in L.get("bottles", []):
			bottles.append({"x": float(x), "y": float(G.bottle.rail_y), "alive": true})
		if L.has("sign"):
			hang_sign = {"x": float(L["sign"]), "y": float(G.sign.hang_y), "w": int(G.sign.board[0]), "h": int(G.sign.board[1]),
				"rope_top": float(G.sign.rope_top), "state": "hang", "vy": 0.0, "swing": 0.0}
		for k in L.enemies.size():
			var d: Dictionary = L.enemies[k]
			var e := {"state": "hidden", "t": 0.0, "wait": 0.7 + k * 0.55 + randf() * 0.8, "exp": 0.0, "alive": true, "fall": 0.0, "lean": 1, "aim_max": 0.0}
			if d.has("c"):
				e.merge({"kind": "cover", "c": int(d.c), "side": d.side})
			elif d.has("w"):
				e.merge({"kind": "window", "w": int(d.w)})
			elif d.has("run"):
				e.merge({"kind": "runner", "c": int(d.run[0]), "from": int(d.run[0]), "to": int(d.run[1]), "run_p": 0.0, "side": "up"})
			elif d.has("hostage"):
				e.merge({"kind": "hostage", "hx": float(d.hostage)})
			elif d.get("eli", false):
				e.merge({"kind": "runner", "c": int(d.from), "from": int(d.from), "to": int(d.to), "run_p": 0.0, "side": "up",
					"eli": true, "armor": true, "cracks": [], "hp": 3, "spot": -1, "wait": float(G.iron_eli.first_wait)})
			enemies.append(e)
	_build_view()


func _start_duel() -> void:
	boss_set = GameState.BOSS_SPRITES[L.boss] + "_duel"
	duel = {"hp": int(L.hp), "round": 0, "phase": "intro", "t": 0.0, "wait": 0.0, "fake_at": [], "twitch": 0.0,
		"pose": "idle", "fall": 0.0, "smoke": [], "card": null, "card_t": 0.0, "bell1": false}
	tumble = {"x": -20.0, "on": true}


func go() -> void:
	state = "play"
	AudioManager.duck(1.0)
	AudioManager.play(level_cue())
	if duel != null:
		duel.phase = "intro"
		duel.t = 0.0
		callout.emit("Round 1", true, 900)
	elif tut != null and tut.step == 0:
		callout.emit("Tap a bottle.", true, 0)
	elif L.get("puzzle", false) and hint_lvl >= 1:
		callout.emit("Clue: " + L.hint, true, 2600)


## The Second Chance checkpoint: Iron Eli from the stage reached, with full hearts (rules.md §8, §11).
func resume_from_stage(n: int) -> void:
	assisted = true
	sc_used = true
	go()
	eli_stage(n)
	hearts = 3
	callout.emit("Stage %d: full hearts" % n, true, 1200)


func level_cue() -> String:
	return "boss" if L.get("duel", false) or L.get("eli", false) else ("train" if ci == 1 else "street")


func pause() -> void:
	if state == "play":
		state = "pause"
		AudioManager.duck(0.3)


func resume() -> void:
	if state == "pause":
		state = "play"
		AudioManager.duck(0.35 if duel != null and duel.phase == "wait" else 1.0)


## Second Chance rewards (rules.md §11), granted after the ad or the Sheriff's Pass.
func grant_offer(type: String) -> void:
	assisted = true
	sc_used = true
	AudioManager.play(level_cue())
	if type == "bullet":
		bullets += 1
		cyl = mini(int(weapon.cyl), bullets)
		reload_t = 0.0
		out_of_ammo_t = 0.0
		state = "play"
		callout.emit("One more bullet.", true, 1000)
	elif type == "continue":
		hearts = 2
		hurt_flash = 0
		state = "play"
		if duel != null:
			duel.merge({"phase": "intro", "t": 0.0, "pose": "idle", "fall": 0.0, "card": null, "bell1": false}, true)
		for e in enemies:
			if e.alive and e.state == "aim":
				e.state = "drop"
		callout.emit("Back up!", true, 900)


# ---------- geometry (all from data/geometry.json and cover_sizes.json) ----------

static func _vec(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


func pad(d: Dictionary) -> float:
	return float(d.touch if touch else d.mouse)


## An outlaw's hitbox position (top-left) and the clip that hides him.
func geo(e: Dictionary) -> Dictionary:
	var hw := _hitbox.x / 2.0
	if e.kind == "window":
		var w: Dictionary = SC.windows[e.w]
		var top_h: float = w.y + w.h + G.window_outlaw.hidden_below_sill
		var top_e: float = w.y + G.window_outlaw.exposed_from_top
		return {"x": w.x + w.w / 2.0 - hw, "y": roundf(top_h + (top_e - top_h) * e.exp), "clip": Rect2(w.x, w.y, w.w, w.h)}
	if e.kind == "hostage":
		return {"x": e.hx - hw + roundf(e.lean * e.exp * G.hostage.lean), "y": GY - float(G.hostage.captor_top_above_ground), "clip": null}
	if e.kind == "runner" and e.state == "run":
		var a: Dictionary = covers[e.from]
		var b: Dictionary = covers[e.to]
		var ax: float = a.x + a.w / 2.0 - hw
		var bx: float = b.x + b.w / 2.0 - hw
		return {"x": roundf(ax + (bx - ax) * e.run_p), "y": GY - _hitbox.y, "clip": null, "running": true}
	var c: Dictionary = covers[e.c]
	var cx: float = c.x + c.w / 2.0 - hw
	if not c.alive:
		return {"x": cx, "y": GY - _hitbox.y, "clip": null}
	var hid_top: float = GY - c.h - G.outlaw.hide_gap
	var ground := Rect2(-1000, -1000, 3000, 1000 + GY)
	if e.side == "left" or e.side == "right":
		var dx: float = (-1 if e.side == "left" else 1) * roundf((c.w / 2.0 + G.outlaw.peek_side_extra) * e.exp)
		return {"x": cx + dx, "y": maxf(GY - _hitbox.y, hid_top), "clip": ground}
	return {"x": cx, "y": roundf(hid_top - G.outlaw.peek_up * e.exp), "clip": ground}


func rect_of(e: Dictionary) -> Rect2:
	var gm := geo(e)
	var r := Rect2(gm.x, gm.y, _hitbox.x, _hitbox.y)
	if gm.clip != null:
		r = r.intersection(gm.clip)
	return r


static func in_r(p: Vector2, r: Rect2, extra := 0.0) -> bool:
	return r.size.x > 0 and p.x >= r.position.x - extra and p.x < r.end.x + extra and p.y >= r.position.y - extra and p.y < r.end.y + extra


func cover_rect(c: Dictionary) -> Rect2:
	return Rect2(c.x, GY - c.h, c.w, c.h)


func hostage_rect(e: Dictionary) -> Rect2:
	var body := _vec(G.hostage.body)
	return Rect2(e.hx - body.x / 2, GY - float(G.hostage.body_top_above_ground), body.x, body.y)


func bottle_rect(b: Dictionary) -> Rect2:
	var hb := _vec(G.bottle.hitbox)
	return Rect2(b.x, b.y - hb.y, hb.x, hb.y)


func duel_zone() -> Rect2:
	var z := _vec(G.duel.zone)
	return Rect2(SC.duelX - z.x / 2, GY + float(G.duel.zone_below_ground) - z.y, z.x, z.y)


func _stats() -> Dictionary:
	return GameState.progress.stats


# ---------- Iron Eli (rules.md §8; the prototype's eliStage / eliHit / eliNextSpot) ----------

func _eli() -> Variant:
	for e in enemies:
		if e.get("eli", false):
			return e
	return null


func eli_next_spot(e: Dictionary) -> void:
	var spots: Array = G.iron_eli.chase_spots
	e.spot = (e.spot + 1) % spots.size()
	var sp: Dictionary = spots[e.spot]
	if sp.has("w"):
		e.merge({"kind": "window", "w": int(sp.w)}, true)
	else:
		e.merge({"kind": "cover", "c": int(sp.c), "side": "up"}, true)
	e.state = "hidden"
	e.exp = 0.0
	e.wait = float(G.iron_eli.spot_wait)


func eli_stage(n: int) -> void:
	eli_ck = n
	events.append("stage:%d" % n)
	var e: Variant = _eli()
	if n >= 2 and e != null:
		e.merge({"armor": false, "stage2": true, "hp": 3, "spot": -1}, true)
		throws.clear()
		for h in enemies:
			if not h.get("eli", false) and h.alive:
				h.alive = false
				h.state = "dead"
				h.fall = 5.0
		bullets = maxi(bullets, int(G.iron_eli.chase_bullets))
		cyl = mini(int(weapon.cyl), bullets)
		reload_t = 0.0
		eli_next_spot(e)
		if n == 2:
			callout.emit("Stage 2: run him down", true, 1300)
	if n == 3:
		L.merge(G.iron_eli.duel, true)
		L.duel = true
		enemies.clear()
		covers.clear()
		hang_sign = null
		throws.clear()
		_start_duel()
		_rebuild_view()
		callout.emit("Stage 3: best of three", true, 1100)


func eli_hit(e: Dictionary, how: String) -> void:
	var r := geo(e)
	var cx: float = r.x + _hitbox.x / 2
	if e.armor:
		if how != "tnt" and how != "sign":
			AudioManager.sfx("ping")
			fx.burst(cx, r.y + 11, 8, "fx/ping", 1.8)
			if not e.get("pinged", false):
				e.pinged = true
				callout.emit("PING! Use the street.", true, 1100)
			return
		if e.cracks.has(how):  # the same tool twice does nothing
			AudioManager.sfx("ping")
			callout.emit("Powder won’t finish it. Try the sign." if how == "tnt" else "Try the powder this time.", true, 1400)
			return
		e.cracks.append(how)
		events.append("crack:" + how)
		AudioManager.sfx("clank")
		Haptics.hit()
		hit_stop = 6
		shake = 10
		fx.burst(cx, r.y + 10, 10, "fx/armour", 2)
		if e.cracks.size() < 2:
			callout.emit("Cracked! Now drop the sign on him." if how == "tnt" else "Cracked! Now the powder.", true, 1600)
			return
		e.armor = false
		e.state = "hidden"
		e.exp = 0.0
		fx.burst(cx, r.y + 10, 16, "fx/armour", 2.6)
		callout.emit("His armour’s off!", true, 1200)
		eli_pend = 2
		eli_pend_t = float(G.iron_eli.armour_off_delay)
		return
	e.hp -= 1
	events.append("eli_hit")
	hit_stop = 5
	AudioManager.sfx("down")
	Haptics.hit()
	_stats().hits += 1
	fx.burst(cx, r.y + 8, 10, "fx/blood", 1.4)
	e.state = "hidden"
	e.exp = 0.0
	if e.hp <= 0:
		callout.emit("Final draw…", true, 1300)
		eli_pend = 3
		eli_pend_t = float(G.iron_eli.final_draw_delay)
		throws.clear()
	elif e.hp == 2:
		callout.emit("Hit! He’s calling for help.", true, 1200)
		eli_next_spot(e)
		e.wait = float(G.iron_eli.wait_after_first_hit)
		events.append("reinforcements")
		var rw: Array = G.iron_eli.reinforcement_wait
		for d in G.iron_eli.reinforcements:
			var h := {"state": "hidden", "t": 0.0, "wait": randf_range(rw[0], rw[1]), "exp": 0.0, "alive": true, "fall": 0.0, "lean": 1, "aim_max": 0.0}
			h.merge({"kind": "window", "w": int(d.w)} if d.has("w") else {"kind": "cover", "c": int(d.c), "side": "up"})
			enemies.append(h)
	else:
		callout.emit("Hit! Watch for dynamite!", true, 1200)
		eli_next_spot(e)
		e.wait = float(G.iron_eli.wait_after_second_hit)


## A thrown stick's position and scale: it flies towards the player on an arc and grows.
func throw_pos(th: Dictionary) -> Dictionary:
	var D: Dictionary = G.dynamite
	var p: float = th.p
	return {"x": th.x0 + (D.target[0] - th.x0) * p, "y": th.y0 + (D.target[1] - th.y0) * p - sin(PI * p) * D.arc_height,
		"s": 1 + p * D.grow}


func _update_eli(dt: float) -> void:
	var el: Variant = _eli()
	if el == null or not el.armor:
		return
	var reset: float = G.iron_eli.tool_reset_time
	for t in covers:
		if t.type == "tnt" and not t.alive:  # a used keg is replaced
			t.respawn = t.get("respawn", reset) - dt
			if t.respawn <= 0:
				t.alive = true
				t.holes.clear()
				t.erase("respawn")
				callout.emit("Another keg!", true, 900)
			break
	if hang_sign != null and hang_sign.state == "down" and not el.cracks.has("sign"):
		hang_sign.reset = hang_sign.get("reset", reset) - dt
		if hang_sign.reset <= 0:
			hang_sign.merge({"state": "hang", "y": float(G.sign.hang_y), "rope_top": float(G.sign.rope_top), "vy": 0.0}, true)
			hang_sign.erase("reset")
			callout.emit("They hang the sign back up.", true, 1000)


# ---------- outcomes ----------

func kill(e: Dictionary, how := "") -> void:
	if not e.alive:
		return
	if e.get("eli", false):
		eli_hit(e, how)
		return
	events.append("kill:" + (how if how != "" else "shot"))
	_stats().kills += 1
	if how == "":
		_stats().hits += 1
	e.alive = false
	e.state = "dead"
	e.fall = 0.0
	AudioManager.sfx("down")
	hit_stop = 3
	Haptics.hit()
	var r := geo(e)
	fx.particle("fx/hat", 0, r.x + 3, r.y, (randf() - 0.5) * 1.4, -2.6, 42)  # the hat flies off
	fx.burst(r.x + _hitbox.x / 2, r.y + 8, 8, "fx/blood", 1.2)


func explode(c: Dictionary) -> void:
	var T: Dictionary = G.tnt
	c.alive = false
	AudioManager.sfx("boom")
	Haptics.explosion()
	shake = 18
	flash = 6
	var cx: float = c.x + c.w / 2.0
	var cy: float = GY - c.h / 2.0
	fx.explosion(cx, cy)
	fx.burst(cx, cy, 40, "fx/blast", 3.2, 1.5)
	for e in enemies:
		if not e.alive:
			continue
		if e.kind == "hostage":
			if absf(e.hx - cx) < T.hostage_radius:
				fail("The blast caught the hostage.", "hostage")
				return
			continue
		var r := geo(e)
		if Vector2(r.x + _hitbox.x / 2 - cx, r.y + 10 - cy).length() < T.kill_radius and e.kind != "window":
			kill(e, "tnt")
	for o in covers:
		if o.alive and not is_same(o, c) and absf(o.x + o.w / 2.0 - cx) < T.cover_radius:
			if o.type == "tnt":
				pending_blasts.append({"c": o, "t": float(T.chain_delay)})
			elif o.type != "wagon":
				o.alive = false
				fx.burst(o.x + o.w / 2.0, GY - o.h / 2.0, 14, "fx/debris", 2)
	for b in bottles:
		if b.alive and absf(b.x - cx) < T.bottle_radius:
			b.alive = false


func hurt(msg := "") -> void:
	hearts -= 1
	damaged = true
	hurt_flash = 14
	shake = 8
	AudioManager.sfx("enemy_shot")
	Haptics.hurt()
	if hearts <= 0:
		fail(msg if msg != "" else "You’ve been shot.")


func win() -> void:
	state = "won"
	callout_cleared.emit()
	AudioManager.sting("victory")
	var assisted_win: bool = assisted or (L.get("puzzle", false) and hint_lvl >= 1)
	var stars := GameState.stars_for(L, {"hearts": hearts, "used": used, "damaged": damaged, "assisted": assisted_win})
	var lvls: Array = GameState.levels_for(ci)
	var last := li == lvls.size() - 1
	var res := GameState.apply_win(GameState.progress, ci, li, stars, {"boss": L.get("duel", false) or L.get("eli", false),
		"last": last, "bounty": GameState.chapters[ci].bounty, "count": lvls.size()})
	GameState.save()
	won.emit({"stars": stars, "pay": res.pay, "hearts": hearts, "used": used, "damaged": damaged, "assisted": assisted_win, "last": last})


func fail(reason: String, kind := "shot") -> void:
	if state != "play":
		return
	state = "lost"
	callout_cleared.emit()
	AudioManager.stop()
	AudioManager.sfx("lose")
	GameState.save()
	var alive := enemies.filter(func(e): return e.alive).size()
	var offer: Variant = GameState.offer_for(L, kind, alive, sc_used, eli_ck if L.get("eli", false) else 1)
	if offer == "hint" and hint_lvl >= 2:
		offer = null
	events.append("lost:" + kind)
	lost.emit(reason, offer)


# ---------- shooting ----------

func _fire_fx() -> void:
	AudioManager.sfx("shot")
	recoil = 6
	kick = weapon.kick
	flash = 3
	_muzzle_smoke()
	Haptics.shot()


func shoot(p: Vector2, from_touch: bool) -> void:
	touch = from_touch
	if state != "play":
		return
	if duel != null:
		_duel_shot(p)
		return
	if bullets <= 0:
		AudioManager.sfx("thunk")
		callout.emit("Click.", true, 600)
		return
	if reload_t > 0:
		callout.emit("Reloading…", true, 450)
		return
	last_aim = p
	bullets -= 1
	used += 1
	cyl -= 1
	_stats().shots += 1
	if cyl <= 0 and bullets > 0:
		reload_t = weapon.reload
		AudioManager.sfx("tick")
		var brass := _gun_pivot() + _vec(G.gun.brass_from_pivot)
		for i in mini(int(weapon.cyl), used):
			fx.particle("fx/brass", 0, brass.x, brass.y, -0.5 - randf(), -1.5 - randf(), 40)
	_fire_fx()
	aim_pt = {"x": p.x, "y": p.y, "t": 10, "miss": false}
	# Front to back (rules.md §5).
	for e in enemies:
		if e.kind == "hostage" and in_r(p, hostage_rect(e), pad(G.hostage.body_pad)):
			fail("You hit the hostage.", "hostage")
			return
	var D: Dictionary = G.dynamite
	for th in throws:  # Iron Eli's dynamite can be shot out of the air
		var q := throw_pos(th)
		if p.distance_to(Vector2(q.x, q.y)) < q.s * D.hit_radius_per_scale + pad(D.hit_pad):
			throws.erase(th)
			events.append("throw_shot")
			fx.explosion(q.x, q.y)
			AudioManager.sfx("boom")
			fx.burst(q.x, q.y, 18, "fx/dynamite_blast", 2.4)
			callout.emit("Nice shooting!", true, 800)
			return
	for e in enemies:
		if e.alive and e.state == "run" and in_r(p, rect_of(e), pad(G.runner.hit_pad)):
			kill(e)
			return
	for c in covers:
		if c.alive and in_r(p, cover_rect(c)):
			if c.type == "tnt":
				explode(c)
				return
			c.holes.append(Vector2(roundf(p.x) - 1, roundf(p.y) - 1))
			AudioManager.sfx("thunk")
			if not (tut != null and tut.step >= 1 and tut.step < 3):
				callout.emit("Wasted bullet.", true, 700)
			fx.burst(p.x, p.y, 6, "fx/splinter", 1)
			return
	if hang_sign != null and hang_sign.state == "hang":
		var rw: float = G.sign.rope_width
		var rope := Rect2(hang_sign.x + hang_sign.w / 2.0 - rw / 2, hang_sign.rope_top, rw, hang_sign.y - hang_sign.rope_top)
		if in_r(p, rope, pad(G.sign.rope_pad)):
			hang_sign.state = "fall"
			AudioManager.sfx("thunk")
			fx.burst(hang_sign.x + hang_sign.w / 2.0, hang_sign.rope_top + 2, 5, "fx/rope")
			return
		if in_r(p, Rect2(hang_sign.x, hang_sign.y, hang_sign.w, hang_sign.h)):
			hang_sign.swing = 1.0
			AudioManager.sfx("thunk")
			return
	var live := enemies.filter(func(e): return e.alive and e.state != "dead" and e.state != "hidden")
	for pd in [0.0, pad(G.outlaw.hit_pad)]:
		for e in live:
			var r := rect_of(e)
			if r.size.x < 1 or r.size.y < 1:
				continue
			if e.kind == "hostage" and e.exp < G.hostage.exposed_min:
				continue
			if in_r(p, r, pd):
				kill(e)
				return
	for b in bottles:
		if b.alive and in_r(p, bottle_rect(b), pad(G.bottle.hit_pad)):
			b.alive = false
			AudioManager.sfx("glass")
			Haptics.hit()
			var r := bottle_rect(b)
			fx.burst(r.get_center().x, r.get_center().y, 10, "fx/glass", 1.4)
			return
	# A miss: dust, a ricochet and a red crosshair.
	decals.append({"x": roundf(p.x), "y": roundf(p.y), "life": 90})
	AudioManager.sfx("miss")
	aim_pt.miss = true
	fx.burst(p.x, p.y, 4, "fx/dust_ground" if p.y > 134 else "fx/dust_wall", 0.8)


func _duel_shot(p: Vector2) -> void:
	var d: Dictionary = duel
	if d.phase == "intro":
		callout.emit("Wait for the bell…", true, 700)
		return
	if d.phase == "wait":
		_fire_fx()
		callout_cleared.emit()
		callout.emit("That wasn’t the ace!" if L.get("cards", false) and d.card != null else "Too early!", true, 900)
		d.phase = "out"
		d.t = 0.0
		hurt("You drew too early.")
		return
	if d.phase == "draw":
		last_aim = p
		if not in_r(p, duel_zone(), pad(G.duel.zone_pad)):
			_fire_fx()
			AudioManager.sfx("miss")
			aim_pt = {"x": p.x, "y": p.y, "t": 12, "miss": true}
			callout.emit("Missed! Shoot him!", true, 600)
			return
		_fire_fx()
		Haptics.hit()
		callout_cleared.emit()
		d.hp -= 1
		d.phase = "out"
		d.t = 0.0
		d.fall = 0.01 if d.hp <= 0 else 0.0
		d.pose = "hit"
		hit_stop = 3
		fx.burst(SC.duelX, GY - 38, 10, "fx/blood", 1.4)
		callout.emit("He’s down!" if d.hp <= 0 else "Hit!", true, 900)


# ---------- update (60 steps a second, like the prototype) ----------

func _physics_process(_delta: float) -> void:
	if hit_stop > 0:
		hit_stop -= 1
		frame += 1
	else:
		_step(1.0 / 60.0)


func _process(_delta: float) -> void:
	position = Vector2(randi_range(-2, 1), randi_range(-2, 1)) * PPU if shake > 0 else Vector2.ZERO
	_sync_view()


func _step(dt: float) -> void:
	frame += 1
	fx.step()
	for dc in decals:
		dc.life -= 1
	if recoil:
		recoil -= 1
	kick *= 0.78
	if kick < 0.01:
		kick = 0.0
	if flash:
		flash -= 1
	if hurt_flash:
		hurt_flash -= 1
	if shake:
		shake -= 1
	if aim_pt != null:
		aim_pt.t -= 1
		if aim_pt.t <= 0:
			aim_pt = null
	if tumble.on:
		tumble.x += G.tumbleweed.speed
		if tumble.x > view_right + 20:
			tumble.x = view_left - 20 - randf() * 200
	_aim_gun()
	for pb in pending_blasts.duplicate():
		pb.t -= dt
		if pb.t <= 0 and pb.c.alive:
			explode(pb.c)
	pending_blasts = pending_blasts.filter(func(pb): return pb.t > 0)
	if state != "play":
		return
	if not throws.is_empty():
		var D: Dictionary = G.dynamite
		for th in throws.duplicate():
			th.p += dt / D.flight_time
			if th.p >= 1:  # it lands at the player's feet
				throws.erase(th)
				events.append("throw_landed")
				fx.explosion(D.lands_at[0], D.lands_at[1])
				AudioManager.sfx("boom")
				shake = 12
				hurt("The dynamite got you.")
				if state != "play":
					return
	if reload_t > 0:
		reload_t -= dt
		if reload_t <= 0:
			reload_t = 0.0
			cyl = mini(int(weapon.cyl), bullets)
			AudioManager.sfx("cock")
	if duel != null:
		_duel_update(dt)
		return

	if tut != null and tut.step == 0 and bottles.all(func(b): return not b.alive):
		tut.step = 1
		for e in enemies:
			e.wait = 0.9
		callout.emit("Wait for him to pop up.", true, 0)
	if tut != null and tut.step >= 1 and tut.step < 3 and enemies.all(func(e): return not e.alive):
		tut.step = 3
		callout_cleared.emit()
	if eli_pend_t > 0:
		eli_pend_t -= dt
		if eli_pend_t <= 0:
			eli_stage(eli_pend)
			if duel != null:
				return
	if L.get("eli", false):
		_update_eli(dt)

	var O: Dictionary = G.outlaw
	for e in enemies:
		if e.state == "dead":
			e.fall += dt
			continue
		if tut != null and tut.step == 0:
			continue
		var is_eli: bool = e.get("eli", false)
		if is_eli and eli_pend_t > 0:
			continue
		var cover_gone: bool = (e.kind == "cover" or e.kind == "runner") and not covers[e.c].alive
		match e.state:
			"hidden":
				if e.get("side") == "hide" and not cover_gone:
					continue
				e.wait -= dt
				if e.wait <= 0:
					# Iron Eli always moves when his wait ends; other runners sometimes.
					if e.kind == "runner" and randf() < (1.0 if is_eli else G.runner.dash_chance) and covers[e.to].alive:
						e.state = "run"
						e.run_p = 0.0
						e.exp = 1.0
					else:
						e.state = "rise"
						if e.kind == "hostage":
							e.lean = -1 if randf() < 0.5 else 1
			"run":
				e.run_p += dt / G.runner.run_time
				if e.run_p >= 1:
					e.c = e.to
					var f: int = e.from
					e.from = e.to
					e.to = f
					e.state = "hidden"
					e.exp = 0.0
					e.wait = 0.4 + randf() * 0.6
			"rise":
				e.exp = minf(1, e.exp + dt / O.rise_time)
				if e.exp >= 1:
					if is_eli and e.get("stage2", false) and e.hp == 1:  # he throws dynamite instead of firing
						var gm := geo(e)
						throws.append({"x0": gm.x + _hitbox.x / 2, "y0": gm.y + 6, "p": 0.0})
						events.append("throw")
						AudioManager.sfx("tick")
						e.threw = true
					e.state = "aim"
					var mult := 1.0
					if e.kind == "hostage":
						mult = G.hostage.aim_multiplier
					elif is_eli and not e.armor:
						mult = G.iron_eli.chase_aim["hp%d" % e.hp]
					e.aim_max = L.aim * mult
					e.t = e.aim_max
					if tut != null and tut.step == 1:
						tut.step = 2
						callout.emit("Now! Shoot!", true, 0)
			"aim":
				e.t -= dt
				if e.t <= 0 and e.get("threw", false):
					e.threw = false
					e.state = "drop"
				elif e.t <= 0:
					hurt()
					e.state = "drop"
					if state != "play":
						return
					if tut != null and tut.step == 2:
						tut.step = 1
						callout.emit("Too slow. Wait again.", true, 0)
			"drop":
				e.exp = maxf(1.0 if cover_gone else 0.0, e.exp - dt / O.drop_time)
				if is_eli and e.get("stage2", false) and e.exp <= 0:  # in the chase he moves on after each appearance
					eli_next_spot(e)
					continue
				if e.exp <= 0 or cover_gone:
					e.state = "hidden"
					e.wait = (0.8 + randf() * 1.4) * L.pace
					if cover_gone:
						e.state = "aim"
						e.aim_max = L.aim * 1.2
						e.t = e.aim_max
	if hang_sign != null:
		_update_sign()
	# Win and lose checks.
	var left := enemies.filter(func(e): return e.alive).size() + bottles.filter(func(b): return b.alive).size()
	if left == 0:
		end_timer += dt
		if end_timer > 0.7:
			win()
		return
	var sign_falling: bool = hang_sign != null and hang_sign.state == "fall"
	if bullets <= 0 and not sign_falling and fx.booms.is_empty() and pending_blasts.is_empty():
		out_of_ammo_t += dt
		if out_of_ammo_t > 0.9:
			fail("Out of bullets.", "ammo")


func _update_sign() -> void:
	var s: Dictionary = hang_sign
	if s.swing:
		s.swing *= 0.95
	if s.state != "fall":
		return
	s.vy += G.sign.gravity
	s.y += s.vy
	s.rope_top += s.vy * 0.2
	var wagon: Variant = null
	for c in covers:
		if c.alive and c.type == "wagon" and s.x + s.w > c.x and s.x < c.x + c.w:
			wagon = c
	var floor_y: float = GY - (wagon.h if wagon != null else 0) - s.h
	if s.y >= floor_y:
		s.y = floor_y
		s.state = "down"
		AudioManager.sfx("crash")
		Haptics.explosion()
		shake = 8
		fx.burst(s.x + s.w / 2.0, floor_y + s.h, 16, "fx/sign_dust", 2)
		var m: float = G.sign.crush_margin
		for e in enemies:
			if e.alive and e.kind != "window" and e.kind != "hostage":
				var cx: float = geo(e).x + _hitbox.x / 2
				if cx > s.x - m and cx < s.x + s.w + m:
					kill(e, "sign")


func _duel_update(dt: float) -> void:
	var d: Dictionary = duel
	d.t += dt
	if L.get("smoke", false):
		if frame % 22 == 0:
			d.smoke.append({"x": view_left - 24, "y": 92 + randf() * 40, "r": 9 + randf() * 8, "a": 0.55})
		for s in d.smoke:
			s.x += 1.7
			s.r += 0.04
			s.a = maxf(0, s.a - 0.0015)
		d.smoke = d.smoke.filter(func(s): return s.x < view_right + 30)
	if d.twitch > 0:
		d.twitch -= dt
	var last_stand: bool = L.get("lastStand", false) and d.round >= 2
	match d.phase:
		"intro":
			if d.t > 1.1:
				d.phase = "wait"
				d.t = 0.0
				d.wait = 1.5 + randf() * 2.4
				d.pose = "idle"
				AudioManager.duck(0.35)
				d.card = null
				d.card_t = 0.7
				callout.emit("Wait for the ace…" if L.get("cards", false) else ("Last stand: wait for the second bell" if last_stand else "Steady…"), true, 0)
				d.fake_at = []
				if L.get("fakes", false) and randf() < 0.75:
					d.fake_at = [0.5 + randf() * (d.wait - 0.8)]
		"wait":
			if not d.fake_at.is_empty() and d.t > d.fake_at[0]:
				d.fake_at.pop_front()
				d.twitch = 0.28
				AudioManager.sfx("twitch")
			if L.get("cards", false):
				d.card_t -= dt
				if d.card_t <= 0:
					AudioManager.sfx("card")
					if d.t >= d.wait:
						d.card = "A"
						_ring_bell()
					else:
						var deck := ["K", "Q", "J", "9", "7", "5", "3"].filter(func(c): return c != d.card)
						d.card = deck[randi() % deck.size()]
						d.card_t = 0.55 + randf() * 0.5
			elif last_stand and not d.bell1 and d.t >= d.wait:
				d.bell1 = true
				events.append("bell1")
				AudioManager.sfx("bell")
				callout.emit("Not yet…", true, 0)
				d.wait = d.t + 0.6 + randf() * 0.9
			elif d.t >= d.wait:
				_ring_bell()
		"draw":
			var react: Array = L.react
			# Touch gets a little longer to aim (rules.md §7).
			if d.t >= float(react[mini(d.round, react.size() - 1)]) + pad(G.duel.aim_bonus):
				AudioManager.sfx("enemy_shot")
				callout_cleared.emit()
				d.phase = "out"
				d.t = 0.0
				callout.emit("Too slow.", true, 900)
				hurt("He was faster.")
		"out":
			if d.fall:
				d.fall += dt
			if d.t > 1.3:
				if d.hp <= 0:
					win()
					return
				d.round += 1
				d.phase = "intro"
				d.t = 0.0
				d.pose = "idle"
				d.fall = 0.0
				d.bell1 = false
				AudioManager.duck(1.0)
				var ls: bool = L.get("lastStand", false) and d.round >= 2
				callout.emit("Last stand: wait for the second bell" if ls else "Round %d" % (d.round + 1), true, 1300)


func _ring_bell() -> void:
	duel.phase = "draw"
	duel.t = 0.0
	duel.pose = "aim"
	AudioManager.sfx("bell")
	callout.emit("DRAW!", false, 0)


# ---------- the gun ----------

func _gun_pivot() -> Vector2:
	var g: Dictionary = G.gun
	return Vector2(view_right - g.pivot_from_corner[0] + kick * g.kick_offset[0],
		H - g.pivot_from_corner[1] + kick * g.kick_offset[1] + (g.reload_drop if reload_t > 0 else 0))


## Where the muzzle is, from the gun art's "muzzle" point in the manifest.
func _muzzle() -> Vector2:
	return _gun_pivot() + (Assets.point(gun_asset + "/idle", "muzzle") / PPU).rotated(gun_ang + kick)


func _muzzle_smoke() -> void:
	var m := _muzzle()
	for i in 5:
		fx.particle("fx/smoke", i % 2, m.x, m.y, -0.4 - randf() * 0.5, -0.3 - randf() * 0.4, 26 + randi() % 16, true)


func _aim_gun() -> void:
	var g: Dictionary = G.gun
	var t: Variant = last_aim if last_aim != null else mouse
	var want: float = g.rest_angle
	if t != null and duel == null:
		var p := _gun_pivot()
		want = clampf(atan2(-(t.y - p.y), -(t.x - p.x)), g.angle_range[0], g.angle_range[1])
	if reload_t > 0:
		want = g.reload_angle
	gun_ang += (want - gun_ang) * 0.25


# ---------- the view: sprites only, placed from the state above ----------

func _layer(parent: Node = self) -> Node2D:
	var n := Node2D.new()
	parent.add_child(n)
	return n


func _clip(rect_units: Rect2, parent: Node = self) -> Control:
	var c := Control.new()
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = rect_units.position * PPU
	c.size = rect_units.size * PPU
	parent.add_child(c)
	return c


## Puts a sprite's anchor at a point given in gameplay units.
func _place(n: Node2D, at: Vector2) -> void:
	var parent := n.get_parent()
	n.position = at * PPU - (parent.position if parent is Control else Vector2.ZERO)


## Iron Eli's last stage swaps the street for a duel: start the view again.
func _rebuild_view() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_window_clips.clear()
	_sign_nodes = {}
	_duel_nodes = {}
	_arrow = null
	_hint_glow = null
	decals.clear()
	_build_view()


func _build_view() -> void:
	var scene_key: String = GameState.SCENE_LEVEL_KEY[GameState.chapters[ci].scene]
	var art: Dictionary = Assets.scenes[scene_key]
	var bg := _layer()
	for layer in art.layers:
		AssetSprite.make(layer, bg)
	_decal_layer = _layer()
	for i in SC.windows.size():
		var w: Dictionary = SC.windows[i]
		_window_clips.append(_clip(Rect2(w.x, w.y, w.w, w.h)))
	var frames := _layer()
	for i in SC.windows.size():
		_place(AssetSprite.make(art.window_frames[i], frames), Vector2(SC.windows[i].x, SC.windows[i].y))
	_back_props = _layer()
	for b in bottles:
		b.node = AssetSprite.make("prop/bottle", _back_props)
		_place(b.node, Vector2(bottle_rect(b).get_center().x, b.y))
	if tut != null:
		_arrow = AssetSprite.make("fx/tutorial_arrow", _back_props)
	if hang_sign != null:
		_sign_nodes = {"beam": AssetSprite.make("prop/sign_beam", _back_props), "rope": AssetSprite.make("prop/sign_rope", _back_props),
			"board": AssetSprite.make("prop/sign", _back_props)}
	# Street outlaws are clipped at the ground line, so they sink behind cover as they drop.
	_actors = _clip(Rect2(-1000, -1000, 3000, 1000 + GY))
	_cover_layer = _layer()
	for c in covers:
		c.node = AssetSprite.make("prop/" + c.type, _cover_layer)
		_place(c.node, Vector2(c.x + c.w / 2.0, GY))
	_front = _layer()
	if L.get("puzzle", false) and L.has("hintTarget") and hint_lvl >= 2:
		_hint_glow = NinePatchRect.new()
		_hint_glow.texture = Assets.texture("fx/hint_glow")
		var m: int = Assets.meta("fx/hint_glow", "nine_patch", 2)
		_hint_glow.patch_margin_left = m
		_hint_glow.patch_margin_top = m
		_hint_glow.patch_margin_right = m
		_hint_glow.patch_margin_bottom = m
		_hint_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.add_child(_hint_glow)
	_hostage_layer = _layer()
	_ring_layer = _layer()
	_throw_layer = _layer()
	if duel != null:
		_duel_layer = _layer()
		var dn := {}
		dn.boss = AssetSprite.make(boss_set + "/idle", _duel_layer)
		dn.twitch = AssetSprite.make("duel/twitch", _duel_layer)
		if L.get("cards", false):
			dn.box = AssetSprite.make("duel/card_box", _duel_layer)
			dn.card = AssetSprite.make("card/A", _duel_layer)
		dn.smoke = _layer(_duel_layer)
		dn.shadow = AssetSprite.make("duel/shadow", _duel_layer)
		dn.pips = []
		for i in int(L.hp):
			dn.pips.append(AssetSprite.make("duel/pip_full", _duel_layer))
		_duel_nodes = dn
	_tumble = AssetSprite.make("prop/tumbleweed", self)
	fx = FxLayer.new()
	fx.ppu = PPU
	add_child(fx)
	_gun = AssetSprite.make(gun_asset + "/idle", self)
	_muzzle_flash = AssetSprite.make("fx/muzzle_flash", self)
	_cross = AssetSprite.make("crosshair/hit", self)
	var overlay := CanvasLayer.new()
	overlay.layer = 4
	add_child(overlay)
	_hurt = TextureRect.new()
	_hurt.texture = Assets.texture("fx/hurt_flash")
	_hurt.stretch_mode = TextureRect.STRETCH_SCALE
	_hurt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_hurt)
	_sync_view()


func _sync_view() -> void:
	for dc in decals:
		if not dc.has("node"):
			dc.node = AssetSprite.make("fx/miss_mark", _decal_layer)
			_place(dc.node, Vector2(dc.x, dc.y))
		if dc.life <= 0:
			dc.node.queue_free()
	decals = decals.filter(func(dc): return dc.life > 0)
	for b in bottles:
		b.node.visible = b.alive
	if _arrow != null:
		var first: Variant = null
		for b in bottles:
			if b.alive:
				first = b
				break
		_arrow.visible = tut.step == 0 and first != null
		if first != null:
			_place(_arrow, Vector2(first.x, first.y - 20 + roundf(absf(sin(frame * 0.12)) * -3)))
	if hang_sign != null:
		_sync_sign()
	for c in covers:
		c.node.visible = c.alive
		if c.node.get_child_count() > c.holes.size():  # a replaced TNT keg has no holes
			for hole in c.node.get_children():
				hole.queue_free()
				c.node.remove_child(hole)
		while c.node.get_child_count() < c.holes.size():
			var h: Vector2 = c.holes[c.node.get_child_count()]
			var hole := AssetSprite.make("fx/bullet_hole", c.node)
			hole.position = h * PPU - c.node.position
	for e in enemies:
		_sync_enemy(e)
	_sync_rings()
	_sync_throws()
	if _hint_glow != null:
		_sync_hint_glow()
	if duel != null:
		_sync_duel()
	_tumble.visible = tumble.on
	if tumble.on:
		var T: Dictionary = G.tumbleweed
		_place(_tumble, Vector2(roundf(tumble.x) + 5, GY - float(T.above_ground) - absf(roundf(sin(tumble.x * 0.08) * T.bounce))))
	_gun.show_asset(gun_asset + ("/reload" if reload_t > 0 else "/idle"))
	_place(_gun, _gun_pivot().round())
	_gun.rotation = gun_ang + kick
	_muzzle_flash.visible = flash > 0
	if flash:
		_place(_muzzle_flash, _muzzle().round())
	var ch: Variant = aim_pt if aim_pt != null else mouse
	_cross.visible = ch != null and state == "play"
	if _cross.visible:
		_cross.show_asset("crosshair/" + ("hover" if aim_pt == null else ("miss" if aim_pt.miss else "hit")))
		_place(_cross, Vector2(roundf(ch.x), roundf(ch.y)))
	_hurt.visible = hurt_flash > 0
	_hurt.modulate.a = hurt_flash / 30.0


func _sync_sign() -> void:
	var s: Dictionary = hang_sign
	var S: Dictionary = G.sign
	var hanging: bool = s.state == "hang"
	_place(_sign_nodes.beam, Vector2(s.x - S.beam_overhang, s.rope_top - 2 if hanging else float(S.fallen_beam_y)))
	_sign_nodes.rope.visible = hanging
	if hanging:
		_place(_sign_nodes.rope, Vector2(s.x + s.w / 2.0, s.rope_top))
		_sign_nodes.rope.scale.y = (s.y - s.rope_top) * PPU / Assets.texture("prop/sign_rope").get_height()
	_place(_sign_nodes.board, Vector2(s.x + roundf(sin(frame * 0.2) * s.swing * 2), roundf(s.y)))


## The sprite set an enemy is drawn with, and the layer that clips him.
func _enemy_parent(e: Dictionary) -> Node:
	if e.kind == "window":
		return _window_clips[e.w]
	if e.kind == "hostage":
		return _hostage_layer
	return _actors


func _ensure_enemy_nodes(e: Dictionary) -> void:
	var set_name := "iron_eli" if e.get("eli", false) else "outlaw"
	if not e.has("node"):
		e.node = AssetSprite.make(set_name + "/idle", _enemy_parent(e))
		if e.kind == "hostage":
			e.hostage_node = AssetSprite.make("hostage/idle", _hostage_layer)
		if e.kind == "runner":
			e.run_node = AssetSprite.make(set_name + "/run", _front)
		if e.get("eli", false):
			e.armour_node = AssetSprite.make("iron_eli_armour/intact", e.node.get_parent())
			e.run_armour_node = AssetSprite.make("iron_eli_armour/intact", _front)
	var parent := _enemy_parent(e)
	if e.node.get_parent() != parent:  # Iron Eli moves between windows and cover in the chase
		e.node.reparent(parent, false)
		if e.has("armour_node"):
			e.armour_node.reparent(parent, false)


func _sync_enemy(e: Dictionary) -> void:
	_ensure_enemy_nodes(e)
	var O: Dictionary = G.outlaw
	var is_eli: bool = e.get("eli", false)
	var set_name := "iron_eli/" if is_eli else "outlaw/"
	var gm := geo(e)
	var feet := Vector2(gm.x + _hitbox.x / 2, gm.y + _hitbox.y)
	var n: AssetSprite = e.node
	var running: bool = gm.get("running", false)
	if e.has("run_node"):
		e.run_node.visible = running
		if running:
			_place(e.run_node, feet)
	n.visible = not running
	n.rotation = 0.0
	n.modulate.a = 1.0
	if is_eli:
		n.show_asset(set_name + ("aim" if e.state == "aim" else "idle"))
		_place(n, feet)
		var plate := "iron_eli_armour/" + ("cracked" if not e.cracks.is_empty() else "intact")
		for a in [e.armour_node, e.run_armour_node]:
			a.show_asset(plate)
			_place(a, feet)
		e.armour_node.visible = e.armor and not running
		e.run_armour_node.visible = e.armor and running
		return
	if e.state == "dead":
		if e.fall > O.fall_time:
			n.visible = false
		elif e.fall < O.hit_flash_time:
			n.show_asset("outlaw/hit")  # the white hit flash
		else:
			n.show_asset("outlaw/dead")
			n.modulate.a = maxf(0, 1 - e.fall / O.fall_time)
			feet.y += e.fall * O.fall_drop
			if e.kind != "window":
				n.rotation = minf(O.fall_max_angle, e.fall * O.fall_spin)
	else:
		n.show_asset("outlaw/aim" if e.state == "aim" else "outlaw/idle")
	_place(n, feet)
	if e.has("hostage_node"):
		var body := hostage_rect(e)
		_place(e.hostage_node, Vector2(e.hx, body.end.y))


func _sync_rings() -> void:
	for e in enemies:
		if not e.has("ring"):
			var ring := TextureProgressBar.new()
			ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
			ring.max_value = 1.0
			ring.step = 0.0
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ring_layer.add_child(ring)
			e.ring = ring
			e.alert = AssetSprite.make("fx/alert", _ring_layer)
		var on: bool = e.alive and e.state == "aim"
		e.ring.visible = on
		e.alert.visible = false
		if not on:
			continue
		var r := geo(e)
		var center := Vector2(r.x + _hitbox.x / 2, r.y + 9)
		var k := minf(1.0, e.t / (e.aim_max if e.aim_max > 0 else L.aim))
		var urgent := k < 0.35
		var tex := Assets.texture("fx/draw_ring_urgent" if urgent else "fx/draw_ring")
		e.ring.texture_progress = tex
		e.ring.size = tex.get_size()
		e.ring.position = center * PPU - Assets.anchor("fx/draw_ring")
		e.ring.value = k
		e.alert.visible = urgent and (frame >> 2) % 2 == 1
		_place(e.alert, Vector2(center.x - 1, r.y - 8))


func _sync_throws() -> void:
	var D: Dictionary = G.dynamite
	for th in throws:
		if not th.has("node"):
			th.node = AssetSprite.make("fx/dynamite", _throw_layer)
			th.spark = AssetSprite.make("fx/fuse_spark", _throw_layer)
		var q := throw_pos(th)
		var ang: float = th.p * D.spin
		_place(th.node, Vector2(roundf(q.x), roundf(q.y)))
		th.node.rotation = ang
		th.node.scale = Vector2.ONE * q.s
		th.spark.visible = (frame >> 1) % 2 == 1
		_place(th.spark, Vector2(roundf(q.x + cos(ang) * 6 * q.s), roundf(q.y + sin(ang) * 6 * q.s)))
	for n in _throw_layer.get_children():
		if not throws.any(func(th): return th.get("node") == n or th.get("spark") == n):
			n.queue_free()
			_throw_layer.remove_child(n)


## The clue glow around a puzzle's key prop, once the second clue is unlocked.
func _sync_hint_glow() -> void:
	var t: Dictionary = L.hintTarget
	var r: Variant = null
	if t.has("cover") and int(t.cover) < covers.size() and covers[int(t.cover)].alive:
		r = cover_rect(covers[int(t.cover)])
	if t.get("sign", false) and hang_sign != null and hang_sign.state == "hang":
		r = Rect2(hang_sign.x + hang_sign.w / 2.0 - 4, hang_sign.rope_top, 8, hang_sign.y - hang_sign.rope_top + 3)
	_hint_glow.visible = r != null
	if r != null:
		var grown: Rect2 = r.grow(2.5)
		_hint_glow.position = grown.position * PPU
		_hint_glow.size = grown.size * PPU
		_hint_glow.modulate.a = 0.5 + 0.5 * sin(frame * 0.15)


func _sync_duel() -> void:
	var d: Dictionary = duel
	var dn := _duel_nodes
	var D: Dictionary = G.duel
	var DX: float = SC.duelX
	var dx := (1 if (frame >> 1) % 2 else -1) if d.twitch > 0 else 0
	var boss: AssetSprite = dn.boss
	boss.show_asset(boss_set + "/" + ("aim" if d.pose == "aim" else ("hit" if d.pose == "hit" else "idle")))
	var jitter := float(frame % 4 - 2) if d.pose == "hit" and not d.fall else 0.0
	_place(boss, Vector2(DX + dx + jitter, GY))
	boss.rotation = minf(1.4, d.fall * 2.5) if d.fall else 0.0
	boss.modulate.a = maxf(0, 1 - d.fall / 1.5) if d.fall else 1.0
	dn.twitch.visible = d.twitch > 0
	_place(dn.twitch, Vector2(DX + dx + D.twitch_spark[0], GY + D.twitch_spark[1]))
	if dn.has("box"):
		_place(dn.box, Vector2(DX + D.card_box_from_boss, GY))
		dn.card.visible = d.card != null
		if d.card != null:
			dn.card.show_asset("card/" + d.card)
			_place(dn.card, Vector2(DX + D.card_box_from_boss, GY - float(D.card_above_ground)))
	for s in d.smoke:
		if not s.has("node"):
			s.node = AssetSprite.make("fx/smoke_puff", dn.smoke)
		var base_r := Assets.texture("fx/smoke_puff").get_width() / PPU / 2.0
		s.node.scale = Vector2.ONE * s.r / base_r
		s.node.modulate.a = s.a / 0.55
		_place(s.node, Vector2(s.x, s.y))
	for node in dn.smoke.get_children():
		if not d.smoke.any(func(s): return s.get("node") == node):
			node.queue_free()
	_place(dn.shadow, Vector2(DX, GY))
	var hp := int(L.hp)
	for i in hp:
		dn.pips[i].show_asset("duel/pip_full" if i < d.hp else "duel/pip_empty")
		_place(dn.pips[i], Vector2(DX - hp * D.pip_spacing / 2.0 + i * D.pip_spacing, GY - float(D.pips_above_ground)))
