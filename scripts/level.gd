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
## Puzzle-first levels (brief v2, "v": 2 in data/levels): fixed timings and routes, objectives,
## triggers and the observation start. Prototype levels keep their old, random behaviour.
var v2 := false
## The observation start: outlaws idle and follow their routines, but nobody draws until the first shot.
var observing := false
## Seconds of play since the level started (the authored solutions are timed by it).
var clock := 0.0
## Target Practice's hanging bucket (v2), like hang_sign.
var bucket: Variant = null
## Tutorial prompts waiting to show: [{text, ms, t, if}].
var _prompt_q: Array = []

var fx: FxLayer
var _hitbox := Vector2(14, 19)
## This level's cover layout (see _layout): old and new cover centres, and the spread p.
var _spread := {"p": 1.0, "old": [160.0], "new": [160.0]}
var _decal_layer: Node2D
var _shadow_layer: Node2D
var _tumble_shadow: AssetSprite
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
## Where the benches and signposts stand (units), so a new signpost finds clear ground.
var _benches: Array[Rect2] = []
var _posts: Array[float] = []
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
	v2 = int(L.get("v", 1)) >= 2
	if L.get("tutorial", false):
		tut = {"step": 0}
	if L.get("duel", false):
		_start_duel()
	elif v2:
		_setup_v2()
	else:
		bullets = int(L.bullets)
		cyl = mini(int(weapon.cyl), bullets)
		_spread = _layout()
		for cv in L.covers:
			var size: Array = GameState.cover_sizes[cv[0]]
			var old_w: float = GameState.kit_cover_sizes[cv[0]][0]
			var centre := spread_x(float(cv[1]) + old_w / 2)
			covers.append({"type": cv[0], "x": centre - float(size[0]) / 2, "w": float(size[0]), "h": float(size[1]), "alive": true, "holes": []})
		var bottle_w: float = G.bottle.hitbox[0]
		for x in L.get("bottles", []):  # levels.json gives the left edge of a 4-unit bottle
			bottles.append({"x": spread_x(float(x) + 2) - bottle_w / 2, "y": float(G.bottle.rail_y), "alive": true})
		if L.has("sign"):
			var board_w: float = G.sign.board[0]  # levels.json gives the left edge of a 22-unit board
			hang_sign = _make_sign(spread_x(float(L["sign"]) + 11) - board_w / 2)
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
				e.merge({"kind": "hostage", "hx": spread_x(float(d.hostage))})
			elif d.get("eli", false):
				e.merge({"kind": "runner", "c": int(d.from), "from": int(d.from), "to": int(d.to), "run_p": 0.0, "side": "up",
					"eli": true, "armor": true, "cracks": [], "hp": 3, "spot": -1, "wait": float(G.iron_eli.first_wait)})
			enemies.append(e)
	_build_view()


## A puzzle-first level (data/levels, brief v2): positions are centres in world units, as placed.
func _setup_v2() -> void:
	bullets = int(L.bullets)
	cyl = mini(int(weapon.cyl), bullets)
	observing = L.get("observation", true)
	_spread = {"p": 1.0, "old": [0.0], "new": [0.0]}  # no spreading: v2 levels are laid out at this scale
	for cv in L.get("covers", []):
		var size: Array = GameState.cover_sizes[cv.type]
		covers.append({"type": cv.type, "x": float(cv.x) - float(size[0]) / 2, "w": float(size[0]), "h": float(size[1]), "alive": true, "holes": []})
	var bottle_w: float = G.bottle.hitbox[0]
	for b in L.get("bottles", []):
		bottles.append({"x": float(b.x) - bottle_w / 2, "y": float(G.bottle.rail_y), "alive": true})
	if L.has("sign"):
		var k := float(L.sign.get("scale", 1.0))
		hang_sign = _make_sign(float(L.sign.x) - float(G.sign.board[0]) * k / 2, k)
	if L.has("bucket"):
		var B: Dictionary = G.bucket
		bucket = {"x": float(L.bucket.x) - float(B.size[0]) / 2, "y": float(B.hang_y), "w": float(B.size[0]), "h": float(B.size[1]),
			"rope_top": float(B.rope_top), "state": "hang", "vy": 0.0, "broke": false}
	for d in L.enemies:
		var e := {"id": d.get("id", ""), "state": "hidden", "t": 0.0, "wait": float(d.get("first", 0.0)), "exp": 0.0, "alive": true,
			"fall": 0.0, "lean": 1, "aim_max": 0.0, "up": float(d.get("up", 2.0)), "down": float(d.get("down", 2.0)), "alert_t": 0.0}
		if d.has("c"):
			e.merge({"kind": "cover", "c": int(d.c), "side": d.get("side", "up")}, true)
		elif d.has("w"):
			e.merge({"kind": "window", "w": int(d.w)}, true)
		elif d.has("stand"):
			e.merge({"kind": "stand", "x": float(d.stand), "state": "look", "exp": 1.0}, true)
		elif d.has("route"):
			var route: Array = d.route
			e.merge({"kind": "walker", "route": route, "speed": float(d.speed), "leg": 0, "x": float(route[0].x), "dir": 1.0,
				"state": "pause", "t": float(route[0].wait), "exp": 1.0, "aimed": false}, true)
		enemies.append(e)


## A hanging sign, its board's left edge at x. scale makes the board and its chains bigger
## (Chain Reaction's long sign); the beam it hangs from is at the chains' top.
func _make_sign(x: float, k := 1.0) -> Dictionary:
	var S: Dictionary = G.sign
	var hang_y := float(S.hang_y)
	var top := hang_y - (hang_y - float(S.chain_top)) * k
	return {"x": x, "y": hang_y, "w": float(S.board[0]) * k, "h": float(S.board[1]) * k, "chain_top": top, "beam_y": top,
		"state": "hang", "vy": 0.0, "swing": 0.0, "scale": k}


func _start_duel() -> void:
	boss_set = GameState.BOSS_SPRITES[L.boss]  # the boss's cut-out rig
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
	else:
		_queue_prompts()


## Tutorial prompts (data "prompts"): each shows once the player has fired after_shots bullets,
## delay seconds later, if its condition still holds.
func _queue_prompts() -> void:
	for pr in L.get("prompts", []):
		if int(pr.after_shots) == used:
			_prompt_q.append({"text": pr.text, "ms": int(pr.get("ms", 0)), "t": float(pr.get("delay", 0.0)), "if": pr.get("if", "")})


func _prompt_holds(cond: String) -> bool:
	match cond:
		"bucket_can_break_2":
			return bucket != null and bucket.state == "hang" and _under_bucket().size() >= 2
	return true


func _step_prompts(dt: float) -> void:
	for pr in _prompt_q.duplicate():
		pr.t -= dt
		if pr.t <= 0:
			_prompt_q.erase(pr)
			if _prompt_holds(pr["if"]):
				callout.emit(pr.text, true, pr.ms)


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
	if type == "continue":  # bullets are never given (brief v2 §3)
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

## This level's layout (geometry.json "layout"): the cover is 1.7x the prototype's size, so it is
## spread about its own middle just enough not to overlap (factor p). If that no longer fits the
## safe area, only the wide empty gaps shrink (tight groups keep their spacing), then the whole
## row slides inside. Blast radii use p, so every puzzle reaches exactly what it did before.
func _layout() -> Dictionary:
	var LY: Dictionary = G.layout
	var lo := float(LY.safe[0])
	var hi := float(LY.safe[1])
	var cs: Array = []
	for cv in L.get("covers", []):
		cs.append([float(cv[1]) + float(GameState.kit_cover_sizes[cv[0]][0]) / 2, float(GameState.cover_sizes[cv[0]][0])])
	if cs.is_empty():
		return {"p": 1.0, "old": [160.0], "new": [160.0]}
	cs.sort_custom(func(a, b): return a[0] < b[0])
	var p := 1.0
	for k in cs.size() - 1:
		p = maxf(p, ((cs[k][1] + cs[k + 1][1]) / 2 + float(LY.gap)) / (cs[k + 1][0] - cs[k][0]))
	var mid: float = (cs[0][0] + cs[-1][0]) / 2
	var old: Array = cs.map(func(c): return c[0])
	var new: Array = cs.map(func(c): return mid + (c[0] - mid) * p)
	var width: float = (new[-1] + cs[-1][1] / 2) - (new[0] - cs[0][1] / 2)
	if width > hi - lo:  # too wide: take the excess out of the gaps that have room to spare
		var slack: Array = []
		var total := 0.0
		for k in cs.size() - 1:
			var s: float = (new[k + 1] - new[k]) - ((cs[k][1] + cs[k + 1][1]) / 2 + float(LY.gap))
			slack.append(s)
			total += s
		var take: float = minf(1.0, (width - (hi - lo)) / maxf(total, 0.001))
		var shift := 0.0
		for k in cs.size() - 1:
			shift += slack[k] * take
			new[k + 1] -= shift
	var left: float = new[0] - cs[0][1] / 2
	var right: float = new[-1] + cs[-1][1] / 2
	var slide := 0.0
	if left < lo:
		slide = lo - left
	elif right > hi:
		slide = hi - right
	return {"p": p, "old": old, "new": new.map(func(x): return x + slide)}


## Where a position from levels.json lands in this level's layout: between two covers it keeps
## its place between their new centres; beyond the ends it moves with the spread.
func spread_x(x: float) -> float:
	var o: Array = _spread.old
	var n: Array = _spread.new
	if x <= o[0] or o.size() == 1:
		return n[0] + (x - o[0]) * _spread.p
	if x >= o[-1]:
		return n[-1] + (x - o[-1]) * _spread.p
	for k in o.size() - 1:
		if x <= o[k + 1]:
			return lerpf(n[k], n[k + 1], (x - o[k]) / (o[k + 1] - o[k]))
	return x


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
	if e.kind == "stand" or e.kind == "walker":  # in the open, on the street
		return {"x": e.x - hw, "y": GY - _hitbox.y, "clip": null, "running": e.kind == "walker" and e.state == "walk"}
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


## The part of an outlaw you can see (and hit): his hit area above the top of the cover he hides behind.
func visible_rect(e: Dictionary) -> Rect2:
	var r := rect_of(e)
	if (e.kind == "cover" or (e.kind == "runner" and e.state != "run")) and covers[e.c].alive:
		var top: float = GY - covers[e.c].h
		if r.end.y > top:
			r.size.y = maxf(0, top - r.position.y)
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


## The hanging sign's two chains, as hit areas.
func chain_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if hang_sign == null:
		return out
	var k: float = hang_sign.scale
	var cw: float = G.sign.chain_width * k
	for cx in G.sign.chains_x:
		out.append(Rect2(hang_sign.x + cx * k - cw / 2, hang_sign.chain_top, cw, hang_sign.y - hang_sign.chain_top))
	return out


## The hanging bucket's hit areas: its body and the rope above it.
func bucket_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if bucket == null:
		return out
	out.append(Rect2(bucket.x, bucket.y, bucket.w, bucket.h))
	if bucket.state == "hang":
		var rw: float = G.bucket.rope_width
		out.append(Rect2(bucket.x + bucket.w / 2 - rw / 2, bucket.rope_top, rw, bucket.y - bucket.rope_top))
	return out


## The bottles the bucket would land on.
func _under_bucket() -> Array:
	var m: float = G.bucket.break_margin
	return bottles.filter(func(b): return b.alive and bottle_rect(b).get_center().x > bucket.x - m and bottle_rect(b).get_center().x < bucket.x + bucket.w + m)


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
		e.flinch = 0.25
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
	e.flinch = 0.25
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
			hang_sign.merge({"state": "hang", "y": float(G.sign.hang_y), "chain_top": float(G.sign.chain_top), "vy": 0.0, "landed": false}, true)
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
			if absf(e.hx - cx) < T.hostage_radius * _spread.p:
				fail("The blast caught the hostage.", "hostage")
				return
			continue
		var r := geo(e)
		if Vector2(r.x + _hitbox.x / 2 - cx, r.y + _hitbox.y / 2 - cy).length() < T.kill_radius * _spread.p and e.kind != "window":
			kill(e, "tnt")
	for o in covers:
		if o.alive and not is_same(o, c) and absf(o.x + o.w / 2.0 - cx) < T.cover_radius * _spread.p:
			if o.type == "tnt":
				pending_blasts.append({"c": o, "t": float(T.chain_delay)})
			elif o.type != "wagon":
				o.alive = false
				fx.burst(o.x + o.w / 2.0, GY - o.h / 2.0, 14, "fx/debris", 2)
	for b in bottles:
		if b.alive and absf(b.x - cx) < T.bottle_radius * _spread.p:
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
	won.emit({"stars": stars, "pay": res.pay, "captured": res.capture_now, "hearts": hearts, "used": used, "damaged": damaged, "assisted": assisted_win, "last": last})


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
	if observing:
		_alert()
	if not L.get("prompts", []).is_empty():
		_prompt_q.clear()
		callout_cleared.emit()
		_queue_prompts()
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
	# A hostage-taker leaning out stands in front of any cover beside him (at 1.7x he can overlap
	# Bank job's TNT barrel), so a tap on his body hits him before the cover behind.
	for e in enemies:
		if e.kind == "hostage" and e.alive and e.state in ["rise", "aim", "drop"] and e.exp >= G.hostage.exposed_min and in_r(p, rect_of(e)):
			kill(e)
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
		for chain in chain_rects():  # the sign hangs from two chains; a shot at either drops it
			if in_r(p, chain, pad(G.sign.chain_pad)):
				hang_sign.state = "fall"
				AudioManager.sfx("clank")
				fx.burst(chain.get_center().x, hang_sign.chain_top + 2, 5, "fx/chain")
				return
		if in_r(p, Rect2(hang_sign.x, hang_sign.y, hang_sign.w, hang_sign.h)):
			hang_sign.swing = 1.0
			AudioManager.sfx("thunk")
			return
	if bucket != null and bucket.state == "hang":
		for r in bucket_rects():  # the bucket or its rope: either drops it
			if in_r(p, r, pad(G.bucket.hit_pad)):
				bucket.state = "fall"
				events.append("bucket_drop")
				AudioManager.sfx("clank")
				fx.burst(bucket.x + bucket.w / 2, bucket.rope_top + 3, 5, "fx/chain")
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
			_break_bottle(b, "shot")
			return
	# A miss: dust, a ricochet and a red crosshair.
	decals.append({"x": roundf(p.x), "y": roundf(p.y), "life": 90})
	AudioManager.sfx("miss")
	aim_pt.miss = true
	fx.burst(p.x, p.y, 4, "fx/dust_ground" if p.y > 134 else "fx/dust_wall", 0.8)


func _break_bottle(b: Dictionary, how: String) -> void:
	b.alive = false
	events.append("bottle:" + how)
	AudioManager.sfx("glass")
	Haptics.hit()
	var r := bottle_rect(b)
	fx.burst(r.get_center().x, r.get_center().y, 10, "fx/glass", 1.4)


## The first shot ends the observation start: every outlaw left turns alert, and those in view draw.
func _alert() -> void:
	observing = false
	events.append("alert")
	for e in enemies:
		if e.alive:
			e.alert_t = float(G.outlaw.alert_mark_time)
			if e.state == "look":
				_start_aim(e)


func _start_aim(e: Dictionary) -> void:
	e.state = "aim"
	e.aim_max = float(L.aim)
	e.t = e.aim_max


## A v2 outlaw's fixed routine (brief v2: deterministic). Over cover or in a window he is hidden
## for `down` seconds (`first` at the start) and shows for `up`; in the open he stands; on a route
## he walks between points at `speed` and pauses `wait` at each. While the level is in observation
## he only looks; once alert, each time he shows (or pauses) he draws, and fires when his ring runs out.
func _step_v2_enemy(e: Dictionary, dt: float) -> void:
	var O: Dictionary = G.outlaw
	if e.alert_t > 0:
		e.alert_t -= dt
	if e.kind == "cover" and not covers[e.c].alive:  # his cover is gone: he stands in the open
		e.merge({"kind": "stand", "x": covers[e.c].x + covers[e.c].w / 2.0, "exp": 1.0, "state": "look"}, true)
		if not observing:
			_start_aim(e)
	match e.state:
		"hidden":
			e.wait -= dt
			if e.wait <= 0:
				e.state = "rise"
		"rise":
			e.exp = minf(1, e.exp + dt / O.rise_time)
			if e.exp >= 1:
				if observing:
					e.state = "look"
					e.t = e.up
				else:
					_start_aim(e)
		"look":
			if e.kind == "cover" or e.kind == "window":
				e.t -= dt
				if e.t <= 0:
					e.state = "drop"
		"aim":
			e.t -= dt
			if e.t <= 0:
				hurt()
				if state != "play":
					return
				match e.kind:
					"stand":
						e.state = "rest"
						e.t = float(O.rest_time)
					"walker":
						e.aimed = true
						e.state = "pause"
						e.t = 0.3
					_:
						e.state = "drop"
		"rest":
			e.t -= dt
			if e.t <= 0:
				_start_aim(e)
		"drop":
			e.exp = maxf(0, e.exp - dt / O.drop_time)
			if e.exp <= 0:
				e.state = "hidden"
				e.wait = e.down
		"pause":
			if not observing and not e.aimed:
				_start_aim(e)
				return
			e.t -= dt
			if e.t <= 0:
				e.leg = (e.leg + 1) % e.route.size()
				e.state = "walk"
				e.aimed = false
		"walk":
			var target := float(e.route[e.leg].x)
			var stride: float = e.speed * dt
			if absf(target - e.x) <= stride:
				e.x = target
				e.state = "pause"
				e.t = float(e.route[e.leg].wait)
			else:
				e.dir = signf(target - e.x)
				e.x += stride * e.dir


func _objective_met() -> bool:
	match L.get("objective", "eliminate_all"):
		"bottles":
			return bottles.all(func(b): return not b.alive)
		"targets":
			return enemies.filter(func(e): return L.targets.has(e.id)).all(func(e): return not e.alive)
	return enemies.all(func(e): return not e.alive)


func _update_bucket() -> void:
	var b: Dictionary = bucket
	if b.state != "fall":
		return
	b.vy += G.bucket.gravity
	b.y += b.vy
	var top_of_bottles: float = G.bottle.rail_y - G.bottle.hitbox[1]
	if not b.broke and b.y + b.h >= top_of_bottles:  # it comes down on the bottles under it
		b.broke = true
		for bt in _under_bucket():
			_break_bottle(bt, "bucket")
	if b.y + b.h >= G.bottle.rail_y:
		b.y = G.bottle.rail_y - b.h
		b.state = "down"
		AudioManager.sfx("crash")
		shake = 4


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
	clock += dt
	if duel != null:
		_duel_update(dt)
		return
	if v2:
		_step_prompts(dt)
		_step_v2(dt)
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
		if e.get("flinch", 0.0) > 0:  # Iron Eli reels when hit
			e.flinch -= dt
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


## A puzzle-first level's step: routines, falling objects, then the objective (brief v2 §3).
func _step_v2(dt: float) -> void:
	for e in enemies:
		if e.state == "dead":
			e.fall += dt
			continue
		_step_v2_enemy(e, dt)
		if state != "play":
			return
	if hang_sign != null:
		_update_sign()
	if bucket != null:
		_update_bucket()
	if _objective_met():
		end_timer += dt
		if end_timer > 0.7:
			win()
		return
	var falling: bool = (hang_sign != null and hang_sign.state == "fall") or (bucket != null and bucket.state == "fall")
	if bullets <= 0 and not falling and fx.booms.is_empty() and pending_blasts.is_empty():
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
	s.chain_top += s.vy * 0.2
	# It lands on the wagon (and in v2 levels on any cover, setting off TNT it lands on).
	var support: Variant = null
	for c in covers:
		if c.alive and (c.type == "wagon" or v2) and s.x + s.w > c.x and s.x < c.x + c.w and (support == null or c.h > support.h):
			support = c
	var floor_y: float = GY - (support.h if support != null else 0) - s.h
	if s.y >= floor_y:
		s.y = floor_y
		s.state = "down"
		if s.get("landed", false):  # settling after the TNT under it went off
			return
		s.landed = true
		AudioManager.sfx("crash")
		Haptics.explosion()
		shake = 8
		fx.burst(s.x + s.w / 2.0, floor_y + s.h, 16, "fx/sign_dust", 2)
		var m: float = G.sign.crush_margin_v2 if v2 else G.sign.crush_margin
		for e in enemies:
			if e.alive and e.kind != "window" and e.kind != "hostage":
				var cx: float = geo(e).x + _hitbox.x / 2
				if cx > s.x - m and cx < s.x + s.w + m:
					kill(e, "sign")
		if v2 and support != null and support.type == "tnt":  # brief v2 trigger: a falling object sets off TNT
			events.append("sign_on_tnt")
			explode(support)
			s.state = "fall"


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


## The gun's tilt: its aim plus a little of the recoil (kick_tilt keeps the kick a nod, not a flip).
func _gun_tilt() -> float:
	return gun_ang + kick * float(G.gun.kick_tilt)


## Where the muzzle is, from the gun art's "muzzle" point in the manifest.
func _muzzle() -> Vector2:
	var art := gun_asset + "/idle"
	return _gun_pivot() + (Assets.point(art, "muzzle") * float(Assets.meta(art, "scale", 1.0)) / PPU).rotated(_gun_tilt())


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
		# The art already points its barrel up-left by barrel_angle; the gun only nods from there.
		var barrel: float = Assets.meta(gun_asset + "/idle", "barrel_angle", 0.0)
		want = clampf(atan2(-(t.y - p.y), -(t.x - p.x)) - barrel, g.angle_range[0], g.angle_range[1])
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


## A soft contact shadow, `width` units across, centred at x on the ground line y.
func _cast(x: float, y: float, width: float) -> AssetSprite:
	var s := AssetSprite.make("fx/contact_shadow", _shadow_layer)
	s.extra_scale = Vector2.ONE * width * PPU / Assets.texture("fx/contact_shadow").get_width()
	_place(s, Vector2(x, y))
	return s


## What a hanging object hangs from (brief v2 §10): the painted signpost standing on the street beside
## it, scaled so the underside of its arm is at beam_y, placed so the arm reaches over every hang point
## (xs). It stands on the left of what it holds, or mirrored on the right when that would leave the
## screen or stand on a bench or another post. If no signpost fits, a wall bracket holds the first point.
func _hanger(beam_y: float, xs: Array) -> void:
	var H: Dictionary = G.hanging
	var arm_from := Assets.point("prop/signpost", "arm_from")
	var arm_to := Assets.point("prop/signpost", "arm_to")
	var k := (GY - beam_y) * PPU / -arm_to.y
	var near_reach := arm_from.x * k / PPU
	var far_reach := arm_to.x * k / PPU
	var lo: float = xs.min()
	var hi: float = xs.max()
	for side in [-1.0, 1.0]:
		for f in [0.95, 0.75, 0.55]:  # the furthest hang point this far along the arm
			var reach: float = near_reach + (far_reach - near_reach) * f
			var post_x: float = hi - reach if side < 0 else lo + reach
			if (lo - post_x if side < 0 else post_x - hi) < near_reach:
				continue  # the nearest point would be over the post's brace
			if post_x < H.post_room[0] or post_x > H.post_room[1] or _post_blocked(post_x):
				continue
			var post := AssetSprite.make("prop/signpost", _back_props)
			post.extra_scale = Vector2(-side * k, k)  # the art's arm points right
			_place(post, Vector2(post_x, GY))
			_cast(post_x, GY, 12)
			_posts.append(post_x)
			return
	var bracket := AssetSprite.make("prop/bracket", _back_props)
	bracket.extra_scale = Vector2.ONE * float(H.bracket_scale)
	_place(bracket, Vector2(xs[0], beam_y))


func _post_blocked(x: float) -> bool:
	var half: float = G.hanging.post_width / 2.0
	for r in _benches:
		if x + half > r.position.x and x - half < r.end.x:
			return true
	return _posts.any(func(p): return absf(p - x) < half * 3)


## A chain of repeated links hanging straight down at x, from top to bottom (units).
func _chain(x: float, top: float, bottom: float) -> Sprite2D:
	var c := Sprite2D.new()
	c.texture = Assets.texture("prop/chain")
	c.centered = false
	c.region_enabled = true
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.scale = Vector2.ONE * float(Assets.meta("prop/chain", "scale", 1.0))
	c.offset.x = -Assets.anchor("prop/chain").x
	_back_props.add_child(c)
	_set_chain(c, x, top, bottom)
	return c


func _set_chain(c: Sprite2D, x: float, top: float, bottom: float) -> void:
	c.region_rect = Rect2(0, 0, c.texture.get_width(), maxf(0, bottom - top) * PPU / c.scale.y)
	c.position = Vector2(x, top) * PPU


## The benches the bottles stand on: one under each group of nearby bottles, its top at the rail,
## narrowed to the group (never wider than the painting) so the bottles aren't lost on it.
func _build_benches() -> void:
	var xs: Array = bottles.map(func(b): return bottle_rect(b).get_center().x)
	var w := Assets.texture("prop/bench").get_width() * float(Assets.meta("prop/bench", "scale", 1.0)) / PPU
	var i := 0
	while i < xs.size():
		var j := i
		while j + 1 < xs.size() and xs[j + 1] - xs[j] < w * 0.4:
			j += 1
		var mid: float = (xs[i] + xs[j]) / 2
		var bw := minf(w, maxf(float(G.bottle.bench_min_width), xs[j] - xs[i] + float(G.bottle.bench_min_width) * 0.6))
		var bench := AssetSprite.make("prop/bench", _back_props)
		bench.extra_scale = Vector2(bw / w, 1)
		_place(bench, Vector2(mid, float(G.bottle.rail_y)))
		_cast(mid, GY, bw * 0.9)
		_benches.append(Rect2(mid - bw / 2, G.bottle.rail_y, bw, GY - G.bottle.rail_y))
		i = j + 1


## Iron Eli's last stage swaps the street for a duel: start the view again.
func _rebuild_view() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_window_clips.clear()
	_sign_nodes = {}
	_benches.clear()
	_posts.clear()
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
	_shadow_layer = _layer()  # soft contact shadows, on the street behind everything standing on it
	for i in SC.windows.size():
		var w: Dictionary = SC.windows[i]
		_window_clips.append(_clip(Rect2(w.x, w.y, w.w, w.h)))
	var frames := _layer()
	for i in art.get("window_frames", []).size():  # painted streets have their window frames in the painting
		_place(AssetSprite.make(art.window_frames[i], frames), Vector2(SC.windows[i].x, SC.windows[i].y))
	_back_props = _layer()
	_build_benches()
	for i in bottles.size():  # the bottles take turns: tall, round, tall
		var b: Dictionary = bottles[i]
		b.look = i % 3
		b.node = AssetSprite.make("bottle/whole%d" % b.look, _back_props)
		b.shadow = _cast(bottle_rect(b).get_center().x, b.y, bottle_rect(b).size.x * 1.6)
		_place(b.node, Vector2(bottle_rect(b).get_center().x, b.y))
	if tut != null:
		_arrow = AssetSprite.make("fx/tutorial_arrow", _back_props)
	if hang_sign != null:  # the board hangs by two chains, at the points the hit areas use
		var k: float = hang_sign.scale
		var xs: Array = G.sign.chains_x.map(func(cx): return hang_sign.x + float(cx) * k)
		_hanger(hang_sign.beam_y, xs)
		_sign_nodes.chains = xs.map(func(x): return _chain(x, hang_sign.beam_y, hang_sign.y))
		_sign_nodes.board = AssetSprite.make("prop/sign", _back_props)
		_sign_nodes.board.extra_scale = Vector2.ONE * k
	if bucket != null:  # the bucket's bail on a hook, on a chain from the arm
		var H: Dictionary = G.hanging
		var cx: float = bucket.x + bucket.w / 2
		_hanger(bucket.rope_top, [cx])
		var bk := float(Assets.meta("prop/bucket", "scale", 1.0))
		var bail_y: float = bucket.y + Assets.point("prop/bucket", "bail").y * bk / PPU
		var catch := Assets.point("prop/hook", "catch") * float(Assets.meta("prop/hook", "scale", 1.0)) / PPU
		var hk := minf(1.0, (bail_y - bucket.rope_top - float(H.hook_min_chain)) / catch.y)  # smaller if the drop is short
		var eye := Vector2(cx - catch.x * hk, bail_y - catch.y * hk)
		_sign_nodes.bucket_chain = _chain(eye.x, bucket.rope_top, eye.y + 0.5)
		_sign_nodes.hook = AssetSprite.make("prop/hook", _back_props)
		_sign_nodes.hook.extra_scale = Vector2.ONE * hk
		_place(_sign_nodes.hook, eye)
		_sign_nodes.bucket = AssetSprite.make("prop/bucket", _back_props)
	# Street outlaws are clipped at the ground line, so they sink behind cover as they drop.
	_actors = _clip(Rect2(-1000, -1000, 3000, 1000 + GY))
	_cover_layer = _layer()
	for c in covers:
		c.node = AssetSprite.make("prop/" + c.type, _cover_layer)
		c.shadow = _cast(c.x + c.w / 2.0, GY, c.w * 1.15)
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
		dn.boss.extra_scale = Vector2.ONE * float(G.duel.boss_scale)  # duel bosses stand closer
		dn.twitch = AssetSprite.make("duel/twitch", _duel_layer)
		if L.get("cards", false):
			dn.box = AssetSprite.make("duel/card_box", _duel_layer)
			dn.card = AssetSprite.make("card/A", _duel_layer)
		dn.smoke = _layer(_duel_layer)
		dn.shadow = _cast(SC.duelX, GY, 28.0 * float(G.duel.boss_scale) * 0.6)
		dn.pips = []
		for i in int(L.hp):
			dn.pips.append(AssetSprite.make("duel/pip_full", _duel_layer))
		_duel_nodes = dn
	_tumble = AssetSprite.make("prop/tumbleweed", self)
	_tumble_shadow = _cast(0, GY, 16)
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
	for b in bottles:  # a broken bottle leaves its shattered base on the bench
		b.node.show_asset("bottle/%s%d" % ["whole" if b.alive else "broken", b.look])
	if _arrow != null:
		var first: Variant = null
		for b in bottles:
			if b.alive:
				first = b
				break
		_arrow.visible = tut.step == 0 and first != null
		if first != null:
			_place(_arrow, Vector2(first.x, first.y - 20 + roundf(absf(sin(frame * 0.12)) * -3)))
	if hang_sign != null or bucket != null:
		_sync_sign()
	for c in covers:
		c.node.visible = c.alive
		c.shadow.visible = c.alive
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
		_place(_tumble_shadow, Vector2(roundf(tumble.x) + 5, GY - float(T.above_ground)))
	_tumble_shadow.visible = tumble.on
	_gun.show_asset(gun_asset + ("/reload" if reload_t > 0 else "/idle"))
	_place(_gun, _gun_pivot().round())
	_gun.rotation = _gun_tilt()
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
	var s: Variant = hang_sign
	if s != null:
		var sway := roundf(sin(frame * 0.2) * s.swing * 2)
		_place(_sign_nodes.board, Vector2(s.x + sway, roundf(s.y)))
		var xs: Array = G.sign.chains_x
		for i in xs.size():  # the chains follow the board; once it drops, snapped ends hang from the arm
			var x: float = s.x + float(xs[i]) * s.scale
			var low: float = s.y if s.state == "hang" else s.beam_y + (G.sign.hang_y - G.sign.chain_top) * s.scale * 0.45
			_set_chain(_sign_nodes.chains[i], x + (sway if s.state == "hang" else 0.0), s.beam_y, low)
	if bucket != null:
		_place(_sign_nodes.bucket, Vector2(bucket.x + bucket.w / 2, roundf(bucket.y)))


## The layer that holds (and clips) an enemy.
func _enemy_parent(e: Dictionary) -> Node:
	if e.kind == "window":
		return _window_clips[e.w]
	if e.kind == "hostage":
		return _hostage_layer
	return _actors


func _ensure_enemy_nodes(e: Dictionary) -> void:
	var who := "iron_eli" if e.get("eli", false) else "outlaw"
	if not e.has("node"):
		e.node = AssetSprite.make(who + "/idle", _enemy_parent(e))
		if e.kind != "window":
			e.shadow = _cast(0, GY, _hitbox.x * 1.1)
		if e.kind == "hostage":
			e.hostage_node = AssetSprite.make("hostage/idle", _hostage_layer)
			e.hostage_shadow = _cast(e.hx, GY, _hitbox.x * 1.1)
		if e.kind == "runner" or e.kind == "walker":  # in the open he is drawn in front of the cover
			e.run_node = AssetSprite.make(who + "/run_right", _front)
			e.run_shadow = _cast(0, GY, _hitbox.x * 1.1)
		if e.get("eli", false):  # his breastplate rides on whichever sprite shows him
			e.armour_node = AssetSprite.make("iron_eli_armour/intact", e.node)
			e.run_armour_node = AssetSprite.make("iron_eli_armour/intact", e.run_node)
	var parent := _enemy_parent(e)
	if e.node.get_parent() != parent:  # Iron Eli moves between windows and cover in the chase
		e.node.reparent(parent, false)


## The pose an outlaw shows: [pose, mirrored, placed by the top of his hit area].
## Over cover and in windows he aims, rising behind the cover or the sill (both drawn in
## front of him); he leans round a cover's side or a hostage; with his cover gone he stands and aims.
func _pose(e: Dictionary) -> Array:
	var pose := "aim"
	var flip := false
	var by_top: bool = e.kind == "window"  # he shows from the top of the opening down, cropped at the sill
	match e.kind:
		"window", "stand", "walker":
			pose = "aim"
		"hostage":
			pose = "lean"
			flip = e.lean > 0
		_:
			var cover_gone: bool = not covers[e.c].alive
			if cover_gone:
				pose = "aim"
			elif e.get("side") == "left" or e.get("side") == "right":
				pose = "lean"
				flip = e.side == "right"  # the art leans out to the left of its cover
			else:  # rising behind his cover, which hides him below the chest
				pose = "aim"
	if v2 and pose == "aim" and not (e.state == "aim" or (not observing and e.state in ["rise", "drop", "rest"])):
		pose = "idle"  # relaxed: the observation start, or a walker between stops
	if e.state == "dead":
		pose = "hit" if e.fall < float(G.outlaw.hit_pose_time) else "fall"
	elif e.get("flinch", 0.0) > 0:  # Iron Eli reels when hit
		pose = "hit"
	return [pose, flip, by_top]


## Shows each outlaw's pose and places it: at his feet, or for a crouch so his
## head sits at the top of his hit area. Art never changes where he can be hit.
func _sync_enemy(e: Dictionary) -> void:
	_ensure_enemy_nodes(e)
	var O: Dictionary = G.outlaw
	var who := "iron_eli/" if e.get("eli", false) else "outlaw/"
	var gm := geo(e)
	var n: AssetSprite = e.node
	var running: bool = gm.get("running", false)
	if e.has("run_node"):
		e.run_node.visible = running
		if running:
			var to_right: bool = e.dir > 0 if e.kind == "walker" else covers[e.to].x > covers[e.from].x
			var at := Vector2(gm.x + _hitbox.x / 2, gm.y + _hitbox.y)
			if e.kind == "walker" and Assets.has(who + "walk_right"):
				# The walk cycle (two steps), one frame per frame_step units walked so it keeps pace with his speed;
				# a slight bob mid-step.
				var W: Dictionary = G.walker
				var anim: String = who + ("walk_right" if to_right else "walk_left")
				var frames := Assets.frame_count(anim)
				var f := absf(e.x) / float(W.frame_step)
				e.run_node.show_asset(anim)
				e.run_node.show_frame(int(f) % frames)
				at.y -= sin(fposmod(f / (frames / 2.0), 1.0) * PI) * float(W.bob)
			else:
				e.run_node.show_asset(who + ("run_right" if to_right else "run_left"))
			_place(e.run_node, at)
			_place(e.run_shadow, Vector2(gm.x + _hitbox.x / 2, GY))
		e.run_shadow.visible = running
	n.visible = not running
	n.rotation = 0.0
	n.modulate.a = 1.0
	var p := _pose(e)
	n.show_asset(who + p[0])
	n.flip_h = p[1]
	var fig: float = float(G.window_outlaw.figure_scale) if e.kind == "window" else 1.0  # upstairs is further away
	if n.extra_scale.x != fig:
		n.extra_scale = Vector2.ONE * fig
	var feet := Vector2(gm.x + _hitbox.x / 2, gm.y + _hitbox.y)
	if p[2]:
		feet.y = gm.y + Assets.anchor(who + p[0]).y * n.scale.y / PPU
	if e.state == "dead":
		if e.fall > O.fall_time:
			n.visible = false
		else:
			n.modulate.a = maxf(0, 1 - e.fall / O.fall_time)
			feet.y += e.fall * O.fall_drop
			if e.kind != "window":
				n.rotation = minf(O.fall_max_angle, e.fall * O.fall_spin)
	_place(n, feet)
	if e.has("shadow"):  # only when his feet are on the street (peekers stand behind their cover)
		e.shadow.visible = n.visible and feet.y >= GY - 3 and not (e.kind == "cover" and covers[e.c].alive)
		e.shadow.modulate.a = n.modulate.a
		_place(e.shadow, Vector2(feet.x, GY))
	if e.get("eli", false):
		var plate := "iron_eli_armour/" + ("cracked" if not e.cracks.is_empty() else "intact")
		for a in [e.armour_node, e.run_armour_node]:
			a.show_asset(plate)
			a.visible = e.armor
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
		var r := geo(e)
		var marked: bool = e.alive and e.get("alert_t", 0.0) > 0  # the first shot: he's alert now
		e.alert.visible = marked
		if marked:
			_place(e.alert, Vector2(r.x + _hitbox.x / 2 - 1, r.y - 6))
		if not on:
			continue
		var center := Vector2(r.x + _hitbox.x / 2, r.y + _hitbox.y * 0.45)
		var k := minf(1.0, e.t / (e.aim_max if e.aim_max > 0 else L.aim))
		var urgent := k < 0.35
		var tex := Assets.texture("fx/draw_ring_urgent" if urgent else "fx/draw_ring")
		e.ring.texture_progress = tex
		e.ring.size = tex.get_size()
		e.ring.position = center * PPU - Assets.anchor("fx/draw_ring")
		e.ring.value = k
		if not marked:
			e.alert.visible = urgent and (frame >> 2) % 2 == 1
			_place(e.alert, Vector2(center.x - 1, center.y - Assets.texture("fx/draw_ring").get_height() / PPU / 2 - 4))


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
		r = Rect2(hang_sign.x - 2, hang_sign.chain_top, hang_sign.w + 4, hang_sign.y - hang_sign.chain_top + 3)  # both chains
	if t.get("bucket", false) and bucket != null and bucket.state == "hang":
		r = Rect2(bucket.x, bucket.rope_top, bucket.w, bucket.y + bucket.h - bucket.rope_top)
	if t.has("spot"):  # where a walker stops
		r = Rect2(float(t.spot) - _hitbox.x / 2, GY - _hitbox.y, _hitbox.x, _hitbox.y)
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
	boss.show_asset(boss_set + "/" + ("fall" if d.fall else ("aim" if d.pose == "aim" else ("hit" if d.pose == "hit" else "idle"))))
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
	var hp := int(L.hp)
	for i in hp:
		dn.pips[i].show_asset("duel/pip_full" if i < d.hp else "duel/pip_empty")
		_place(dn.pips[i], Vector2(DX - hp * D.pip_spacing / 2.0 + i * D.pip_spacing, GY - float(D.pips_above_ground)))
