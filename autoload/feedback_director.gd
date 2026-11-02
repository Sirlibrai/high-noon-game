extends Node
## Every shot's feedback, in one place: gameplay calls one function per event and the director plays
## the sound (pitch varied a little), the haptic pattern, the hit flash, knockback and squash, the
## hit-stop, the screen shake and the screen flashes, with every value from data/feel.tres.
##
## Levels opt in with "feel": true; the rest keep the prototype's feedback, played from here too
## (the legacy branch of each event). The "feel" debug toggle (force_old) plays a flagged level with the
## old feel, to compare the two back to back.
##
## Hit-stop drops Engine.time_scale for a moment, timed on the real clock here (Godot's timers and tweens
## that "ignore time scale" overshoot while it is low), and restores the scale that was active before it (the slow-motion debug view's, if that is on). A new hit-stop replaces
## the current one but never ends later than the current one's start plus its own length, so quick hits
## never chain into a long freeze. Taps are handled at once whatever the time scale.
##
## Shake is trauma-based: events add trauma (0..1) that decays fast; the offset is trauma squared times
## max_offset, from smooth noise. The reduced-shake setting scales it down.

signal player_hurt(hearts_left: int)

const CONFIG := "res://data/feel.tres"

var feel: FeelConfig
## The level being played (it attaches itself), or null.
var level: Level
## Debug: the slow-motion view, and playing a flagged level with the old feel.
var slow := false
var force_old := false
## The accessibility setting (saved): smaller shakes.
var reduced_shake := false
var trauma := 0.0
## The hit-stop in progress: its start (msec).
var stopping := false
var _stop_start := 0
## When the current hit-stop ends (msec).
var stop_ends := 0
var _noise := FastNoiseLite.new()
var _clock := 0.0
var _last_us := 0
## Real-time animations (the hit flash, knockback, squash, screen flash, the gun's turn and kick, the heart's
## pulse): {from, to, set (Callable), start, length (s), ease, owner}. They run on the real clock in
## _process, so hit-stops and slow motion never stretch or skip them.
var _anims: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	feel = load(CONFIG)
	reduced_shake = bool(SaveManager.get_setting("reduced_shake", false))
	_noise.frequency = 1.0
	_last_us = Time.get_ticks_usec()


## Called by a level as it starts (and as it leaves, with null).
func attach(lv: Level) -> void:
	level = lv
	trauma = 0.0


func detach(lv: Level) -> void:
	if level == lv:
		level = null
		trauma = 0.0
		if stopping:
			_end_stop()


## The new feel: the level is flagged, and the debug toggle isn't forcing the old one.
func new_feel() -> bool:
	return level != null and is_instance_valid(level) and bool(level.L.get("feel", false)) and not force_old


func set_reduced_shake(on: bool) -> void:
	reduced_shake = on
	SaveManager.set_setting("reduced_shake", on)


# ---------- time: hit-stop and the slow-motion debug view ----------

## The time scale when no hit-stop is running.
func base_scale() -> float:
	return feel.slow_motion if slow else 1.0


func set_slow(on: bool) -> void:
	slow = on
	Engine.time_scale = base_scale() * (feel.hit_stop_scale if stopping else 1.0)


func hit_stop(seconds: float) -> void:
	if seconds <= 0:
		return
	var now := Time.get_ticks_msec()
	var ends := now + int(seconds * 1000)
	if stopping:  # replace it, but never past its start plus this one's length
		ends = mini(ends, _stop_start + int(seconds * 1000))
	else:
		_stop_start = now
	stop_ends = ends
	stopping = true
	Engine.time_scale = base_scale() * feel.hit_stop_scale


func _end_stop() -> void:
	stopping = false
	Engine.time_scale = base_scale()


# ---------- shake ----------

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


## The shake right now, in gameplay units.
func shake_offset() -> Vector2:
	var k := trauma * trauma * feel.max_offset * (feel.reduced_shake if reduced_shake else 1.0)
	if k <= 0.0:
		return Vector2.ZERO
	var t := _clock * feel.shake_speed
	return Vector2(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t + 100.0)) * 2.0 * k


func _process(_delta: float) -> void:
	var us := Time.get_ticks_usec()
	var dt := (us - _last_us) / 1000000.0  # real time: shakes decay even during a hit-stop
	_last_us = us
	_clock += dt
	if stopping and Time.get_ticks_msec() >= stop_ends:  # on the real clock: a hit-stop always ends on time
		_end_stop()
	_step_anims()
	trauma = maxf(0.0, trauma - feel.trauma_decay * dt)


# ---------- real-time animations ----------

## Animates set.call(value) from `from` to `to` over `length` seconds of real time, after `delay`. ease:
## "linear", "out" (fast then slow), "in_out" or "back" (overshoots a little). owner: freeing it ends the
## animation; another animation with the same owner and key replaces it. Returns when it will end (s, real).
func animate(owner: Object, key: String, from: Variant, to: Variant, length: float, set: Callable, delay := 0.0, ease := "out") -> float:
	_anims = _anims.filter(func(a): return not (a.owner == owner and a.key == key))
	_anims.append({"owner": owner, "key": key, "from": from, "to": to, "len": maxf(length, 0.001), "start": _clock + delay, "set": set, "ease": ease})
	if delay <= 0.0:
		set.call(from)
	return _clock + delay + length


func stop_anims(owner: Object, key := "") -> void:
	_anims = _anims.filter(func(a): return not (a.owner == owner and (key == "" or a.key == key)))


func _step_anims() -> void:
	var done: Array = []
	for a in _anims:
		if not is_instance_valid(a.owner) or not (a.set as Callable).is_valid():
			done.append(a)
			continue
		if _clock < a.start:
			continue
		var t := clampf((_clock - a.start) / a.len, 0.0, 1.0)
		a.set.call(lerp(a.from, a.to, _ease(t, a.ease)))
		if t >= 1.0:
			done.append(a)
	for a in done:
		_anims.erase(a)


static func _ease(t: float, kind: String) -> float:
	match kind:
		"linear":
			return t
		"in_out":
			return 0.5 - cos(t * PI) * 0.5
		"back":
			var c := 1.7
			return 1.0 + (c + 1.0) * pow(t - 1.0, 3) + c * pow(t - 1.0, 2)
	return 1.0 - (1.0 - t) * (1.0 - t)


# ---------- the events ----------

func _sfx(name: String, pitch: Vector2, volume_db := 0.0) -> void:
	AudioManager.sfx(name, volume_db, randf_range(pitch.x, pitch.y))


## Every shot, in the frame of the tap: the gunshot and its tick of haptic, the muzzle flash, and the
## revolver turning toward the tap, kicking and settling.
func shot_fired(at: Vector2) -> void:
	if not new_feel():
		AudioManager.sfx("shot")
		level.recoil = 6
		level.kick = level.weapon.kick
		level.flash = 3
		level._muzzle_smoke()
		Haptics.shot()
		return
	_sfx("shot", feel.shot_pitch)
	Haptics.pattern(feel.shot_haptic)
	level.muzzle_until = Time.get_ticks_msec() + int(feel.muzzle_flash_time * 1000)
	level.aim_and_recoil(at)
	level._muzzle_smoke()
	add_trauma(feel.shot_trauma)


## A bullet finds an outlaw: a white flash, a knock back and a squash, hit-stop, a thud and a firm haptic
## knock just after the shot's tick. shot false: the blast or the sign took him (only the flash and squash;
## the explosion has its own feedback). bottle: a bottle shot (its glass is its sound; no knockback).
func enemy_hit(node: CanvasItem, at: Vector2, shot := true, bottle := false) -> void:
	if not new_feel():
		AudioManager.sfx("down")
		level.hit_stop = 3
		Haptics.hit()
		return
	if not shot:
		_react(node, at)
		return
	if not bottle:
		_sfx("hit", feel.hit_pitch)
		_react(node, at)
	Haptics.pattern(feel.hit_haptic)
	hit_stop(feel.hit_stop)
	add_trauma(feel.hit_trauma)


## A miss: into the open (a puff of dust) or off wood (a spark and a ricochet). Never silent.
func miss(at: Vector2, surface := "open") -> void:
	if not new_feel():
		AudioManager.sfx("miss" if surface == "open" else "thunk")
		if surface == "open":
			level.fx.burst(at.x, at.y, 4, "fx/dust_ground" if at.y > 134 else "fx/dust_wall", 0.8)
		return
	if surface == "open":
		_sfx("dust", feel.miss_pitch)
		level.fx.burst(at.x, at.y, feel.miss_dust, "fx/dust_ground" if at.y > 134 else "fx/dust_wall", 1.6, 1.3)
		for i in 2:  # a round puff you can't miss, wherever it lands
			level.fx.particle("fx/smoke_puff", 0, at.x + randf_range(-1.5, 1.5), at.y + randf_range(-1.5, 1.5), randf_range(-0.25, 0.25), randf_range(-0.35, -0.1), 30 + i * 8, true)
	else:
		_sfx("ricochet", feel.miss_pitch, -4.0)
		level.fx.burst(at.x, at.y, 6, "fx/splinter", 1.4)
		level.fx.burst(at.x, at.y, 5, "fx/ping", 1.6)
	Haptics.pattern(feel.miss_haptic)


## Cover, iron or armour took the bullet ("that didn't work"): sparks, a clank, a tiny shake, no hit-stop.
func blocked(at: Vector2, surface := "wood") -> void:
	if not new_feel():
		AudioManager.sfx("thunk" if surface == "wood" else "ping")
		level.fx.burst(at.x, at.y, 6, "fx/splinter" if surface == "wood" else "fx/ping", 1.0 if surface == "wood" else 1.2)
		return
	_sfx("clank", feel.blocked_pitch)
	if surface == "wood":
		_sfx("thunk", feel.blocked_pitch, -6.0)
		level.fx.burst(at.x, at.y, 6, "fx/splinter", 1.2)
	level.fx.burst(at.x, at.y, feel.blocked_sparks, "fx/ping", 1.8)
	Haptics.pattern(feel.blocked_haptic)
	add_trauma(feel.blocked_trauma)


## Powder going up: far bigger than any bullet. A white flash, debris, the strongest shake, a heavy haptic.
func explosion(at: Vector2) -> void:
	if not new_feel():
		AudioManager.sfx("boom")
		Haptics.explosion()
		level.shake = 18
		level.flash = 6
		return
	_sfx("boom", Vector2(0.92, 1.0))
	Haptics.pattern(feel.explosion_haptic)
	add_trauma(feel.explosion_trauma)
	level.screen_flash(feel.explosion_flash, feel.explosion_flash_time)
	level.fx.burst(at.x, at.y, feel.explosion_debris, "fx/debris", 3.6, 1.6)
	hit_stop(feel.explosion_hit_stop)


## Iron Eli's armour: a bullet rings off (cracked false), or the TNT or the sign cracks it (true).
func boss_hit_armoured(at: Vector2, cracked: bool) -> void:
	if not new_feel():
		if cracked:
			AudioManager.sfx("clank")
			Haptics.hit()
			level.hit_stop = 6
			level.shake = 10
		else:
			AudioManager.sfx("ping")
			level.fx.burst(at.x, at.y, 8, "fx/ping", 1.8)
		return
	if not cracked:
		_sfx("ping", feel.blocked_pitch)
		_sfx("clank", feel.blocked_pitch, -4.0)
		level.fx.burst(at.x, at.y, feel.blocked_sparks, "fx/ping", 2.0)
		Haptics.pattern(feel.blocked_haptic)
		add_trauma(feel.boss_armour_trauma)
		return
	_sfx("clank", Vector2(0.8, 0.9))
	Haptics.pattern(feel.boss_crack_haptic)
	add_trauma(feel.boss_crack_trauma)
	hit_stop(feel.boss_hit_stop)


## A boss hit where he can be hurt (Iron Eli without his armour, a duel round won).
func boss_hit_vulnerable(node: CanvasItem, at: Vector2) -> void:
	if not new_feel():
		AudioManager.sfx("down")
		Haptics.hit()
		level.hit_stop = 5
		return
	_sfx("hit", Vector2(0.8, 0.9))
	Haptics.pattern(feel.boss_hit_haptic)
	_react(node, at)
	hit_stop(feel.boss_hit_stop)
	add_trauma(feel.boss_hit_trauma)


## The boss's final shot: the longest hit-stop, a big shake and a long haptic.
func boss_defeated(node: CanvasItem, at: Vector2) -> void:
	if not new_feel():
		AudioManager.sfx("down")
		Haptics.hit()
		level.hit_stop = 5
		return
	_sfx("hit", Vector2(0.75, 0.82))
	_sfx("down", Vector2(0.9, 0.95), -3.0)
	Haptics.pattern(feel.boss_defeat_haptic)
	_react(node, at)
	hit_stop(feel.boss_final_hit_stop)
	add_trauma(feel.boss_defeat_trauma)


## The player is shot: the heart that empties pulses and the screen's edges flash red (Main shows both).
func player_hit() -> void:
	if not new_feel():
		level.hurt_flash = 14
		level.shake = 8
		AudioManager.sfx("enemy_shot")
		Haptics.hurt()
		return
	_sfx("enemy_shot", Vector2(0.95, 1.05))
	Haptics.pattern(feel.player_hit_haptic)
	add_trauma(feel.player_hit_trauma)
	player_hurt.emit(level.hearts)


## The hit reaction on a sprite: a white flash (the outline shader's flash), a knock away from the gun
## and a squash, all in real time (they play during the hit-stop). The level adds the knock and squash
## (meta fb_kick, in units, and fb_squash) where it places the sprite.
func _react(node: CanvasItem, at: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta("fb_squash", feel.squash)  # at the moment of impact
	node.set_meta("fb_kick", Vector2.ZERO)
	var m := node.material as ShaderMaterial
	if m != null:  # white at once, held, then fading
		m.set_shader_parameter("flash", 1.0)
		animate(node, "flash", 1.0, 0.0, feel.hit_flash_time * 0.5, func(v: float): m.set_shader_parameter("flash", v), feel.hit_flash_time * 0.5, "linear")
	var away := Vector2(signf(at.x - level._gun_pivot().x) if level != null else 1.0, -0.3).normalized()
	animate(node, "kick", Vector2.ZERO, away * feel.knockback, feel.knockback_time, func(v: Vector2): node.set_meta("fb_kick", v))
	animate(node, "squash", feel.squash, Vector2.ONE, feel.squash_time, func(v: Vector2): node.set_meta("fb_squash", v), 0.0, "back")
