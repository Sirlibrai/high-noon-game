class_name AutoPlayer
extends RefCounted
## A scripted player for the self-tests and the visual playthrough, like the
## prototype's playtest bot. It taps like a careful player on a phone: bottles
## first, a puzzle's key prop first, outlaws only once they are out and drawing,
## runners in the open, dynamite in the air, and Iron Eli's armour only with
## the TNT or the sign while he stands in reach.

## Duel rounds (0-based) to fire early in, to reach Iron Eli's last stand.
var foul_rounds: Array = []
var _cooldown := 0
var _key_done := false


## Timed taps to play instead of choosing ([{at, tap}], from a v2 level's "solution" or "wrong"). Instead of
## a time a tap can wait for a moment: "ace" (Black Jack's ace is showing) or "card" (another card is).
var taps: Array = []
var _next := 0


func decide(lv: Level) -> Variant:
	if lv.state != "play":
		return null
	if taps.is_empty() and lv.v2 and _next == 0:
		taps = lv.L.get("solution", [])
	if not taps.is_empty():
		if _next < taps.size() and _due(lv, taps[_next]):
			_next += 1
			return target(lv, taps[_next - 1].tap)
		return null
	if _cooldown > 0:
		_cooldown -= 1
		return null
	var p: Variant = _choose(lv)
	if p != null:
		_cooldown = 6
	return p


static func _due(lv: Level, tp: Dictionary) -> bool:
	if tp.has("at"):
		return lv.clock >= float(tp.at)
	var j: Variant = lv._jack
	if j == null or j.state != "cards" or j.card == "" or j.flip_t > 0:
		return false
	return (j.card == "A") == (tp.when == "ace")


## Runs a level headless at 60 steps a second until it is won or lost.
static func play(lv: Level, bot: AutoPlayer, max_seconds := 300.0) -> void:
	for i in int(max_seconds * 60):
		if lv.state != "play":
			return
		var p: Variant = bot.decide(lv)
		if p != null:
			lv.shoot(p, true)
		if lv.hit_stop > 0:
			lv.hit_stop -= 1
			lv.frame += 1
		else:
			lv._step(1.0 / 60.0)


func _choose(lv: Level) -> Variant:
	if lv.duel != null:
		var d: Dictionary = lv.duel
		if d.phase == "draw":
			return lv.duel_zone().get_center()
		if d.phase == "wait" and foul_rounds.has(d.round) and d.t > 0.3 and lv.hearts >= 2:
			foul_rounds.erase(d.round)
			return lv.duel_zone().get_center()
		return null
	if lv.reload_t > 0 or lv.bullets <= 0:
		return null
	for th in lv.throws:
		if th.p > 0.15:
			var q := lv.throw_pos(th)
			return Vector2(q.x, q.y)
	for b in lv.bottles:
		if b.alive:
			return lv.bottle_rect(b).get_center()
	var eli: Variant = lv._eli()
	if eli != null and eli.armor:
		var tool: Variant = _eli_tool(lv, eli)
		if tool != null:
			return tool
	if lv.L.get("puzzle", false) and not _key_done:
		_key_done = true
		return _key(lv)
	for e in lv.enemies:
		if not e.alive or (e.get("eli", false) and e.armor):
			continue
		if e.state == "run" and e.run_p > 0.2 and e.run_p < 0.8:
			return lv.rect_of(e).get_center()
		if e.state == "aim":  # tap what shows above his cover, like a player would
			return lv.visible_rect(e).get_center()
	return null


## Where a scripted tap lands: "bucket", "chain", "strongbox" (its chain), "jack" (what of him shows),
## "bottle:i", "cover:i" or "enemy:i" (the part of him showing).
static func target(lv: Level, tap: String) -> Vector2:
	var i := int(tap.get_slice(":", 1))
	match tap.get_slice(":", 0):
		"bucket":
			return lv.bucket_rects()[0].get_center()
		"chain":
			return lv.chain_rects()[0].get_center()
		"strongbox":
			return lv.strongbox_chain_rect().get_center()
		"jack":
			return lv.jack_rect().get_center()
		"bottle":
			return lv.bottle_rect(lv.bottles[i]).get_center()
		"cover":
			return lv.cover_rect(lv.covers[i]).get_center()
		"enemy":
			return lv.visible_rect(lv.enemies[i]).get_center()
	return Vector2.ZERO


## The middle of the INN sign's left chain.
func _chain(lv: Level) -> Vector2:
	return lv.chain_rects()[0].get_center()


func _key(lv: Level) -> Variant:
	var t: Dictionary = lv.L.hintTarget
	if t.has("cover"):
		return lv.cover_rect(lv.covers[int(t.cover)]).get_center()
	if t.get("sign", false) and lv.hang_sign != null:
		return _chain(lv)
	return null


func _eli_tool(lv: Level, eli: Dictionary) -> Variant:
	if eli.state == "run":
		return null
	var r := lv.geo(eli)
	var centre := Vector2(r.x + lv._hitbox.x / 2, r.y + lv._hitbox.y / 2)  # as Level.explode measures
	if not eli.cracks.has("tnt"):
		for c in lv.covers:
			if c.type == "tnt" and c.alive and centre.distance_to(lv.cover_rect(c).get_center()) < float(lv.G.tnt.kill_radius) * lv._spread.p - 0.5:
				return lv.cover_rect(c).get_center()
	var s: Variant = lv.hang_sign
	if not eli.cracks.has("sign") and s != null and s.state == "hang":
		var m: float = lv.G.sign.crush_margin - 2
		if centre.x > s.x - m and centre.x < s.x + s.w + m and (eli.state != "hidden" or eli.wait > 0.35):
			return _chain(lv)
	return null
