class_name Splash
extends Node2D
## The splash standoff on the painted clocktower: "Tap to begin" wakes the town and starts the music;
## the clock's hands sweep to noon on the face's centre pin and the bell swings as it tolls; heat haze
## shimmers over the street between two dark figures; "Tap to draw" fires, the rival falls and the scene
## fades to the sheriff's office. The painting covers the screen (trimmed at the sides on wide phones);
## everything on it is placed in its pixels. Every picture is a manifest asset.

signal finished

const ART_SIZE := Vector2(1915, 821)
const CLOCK_PIN := Vector2(958, 288)  # the face's centre pin
const CLOCK_R := 57.0  # the face's radius, to its brass rim
const BELL_AT := Vector2(958, 126)  # the top of the bell's yoke, where it hangs
const HERO_AT := Vector2(440, 804)  # the figures' feet
const RIVAL_AT := Vector2(1475, 804)
const FIGURE_SCALE := 2.1
const HAZE := Rect2(0, 430, 1915, 230)  # the street from the far buildings to the middle distance
const TUMBLE_Y := 792
const TITLE_TOP := 0.435  # of the screen's height: between the clock face and the figures' hats

var _t0 := -1.0  # seconds since "begin"; -1 until the first tap
var _shot_at := -1.0
var _tolled := false
var _tumble_x := -60.0
var _now := 0.0
var _art: Node2D
var _minute: AssetSprite
var _hour: AssetSprite
var _bell: AssetSprite
var _hero: AssetSprite
var _rival: AssetSprite
var _flash: AssetSprite
var _tumble: AssetSprite
var _white: TextureRect
var _black: TextureRect
var _begin: Control
var _title: Label
var _tap: Label


func _ready() -> void:
	var vis := get_viewport().get_visible_rect().size
	var k := maxf(vis.y / ART_SIZE.y, vis.x / ART_SIZE.x)  # cover the screen
	_art = Node2D.new()
	_art.scale = Vector2.ONE * k
	_art.position = (vis - ART_SIZE * k) / 2
	add_child(_art)
	for layer in Assets.scenes.splash.layers:
		AssetSprite.make(layer, _art)
	var haze := ColorRect.new()
	haze.material = ShaderMaterial.new()
	haze.material.shader = load("res://ui/heat_haze.gdshader")
	haze.position = HAZE.position
	haze.size = HAZE.size
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(haze)
	_bell = _at(AssetSprite.make("splash/bell", _art), BELL_AT)
	_hour = _at(AssetSprite.make("splash/hour", _art), CLOCK_PIN)
	_minute = _at(AssetSprite.make("splash/minute", _art), CLOCK_PIN)
	_tumble = AssetSprite.make("prop/tumbleweed", _art)
	_tumble.extra_scale = Vector2.ONE * 1.4
	_hero = _at(AssetSprite.make("splash/hero", _art), HERO_AT)
	_hero.extra_scale = Vector2.ONE * FIGURE_SCALE
	_rival = _at(AssetSprite.make("splash/rival", _art), RIVAL_AT)
	_rival.extra_scale = Vector2(-FIGURE_SCALE, FIGURE_SCALE)  # facing the hero
	_flash = _at(AssetSprite.make("fx/muzzle_flash", _art), HERO_AT + Vector2(80, -140))
	_flash.extra_scale = Vector2.ONE * 1.6
	_flash.visible = false

	var ui := CanvasLayer.new()
	ui.layer = 7
	add_child(ui)
	_white = _screen(ui, "fx/screen_white")
	_black = _screen(ui, "fx/screen_black")
	_title = UiKit.text(ui, "HIGH NOON", &"InkTitle")
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.anchor_top = TITLE_TOP
	_title.anchor_bottom = TITLE_TOP
	_title.modulate.a = 0.0
	_title.rotation = deg_to_rad(-4)
	_tap = UiKit.text(ui, "TAP TO DRAW", &"TapPrompt")
	_tap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tap.anchor_top = 0.86
	_tap.anchor_bottom = 0.86
	_tap.modulate.a = 0.0
	_begin = VBoxContainer.new()  # a plain column over the scene, not a card
	_begin.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(_begin)
	_begin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_begin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.text(_begin, "TAP TO BEGIN", &"Heading")
	UiKit.text(_begin, "Best with sound on", &"Hint")
	_update_scene()


func _screen(parent: Node, asset: String) -> TextureRect:
	var r := UiKit.image(parent, asset)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r


## Puts a sprite's anchor on a pixel of the painting.
func _at(n: AssetSprite, p: Vector2) -> AssetSprite:
	n.position = p
	return n


## Taps go: begin, then draw.
func tap() -> void:
	if _shot_at >= 0:
		return
	if _t0 < 0:
		_t0 = _now
		_begin.visible = false
		AudioManager.unlock()
		AudioManager.play("splash")
		return
	_shot_at = _now
	AudioManager.sfx("shot")
	Haptics.hit()
	AudioManager.stop()
	if not _tolled:  # drawing before noon skips straight to the end of the standoff
		_tolled = true
		_t0 = _now - 4.0
	get_tree().create_timer(0.25).timeout.connect(func(): AudioManager.sfx("down"))
	get_tree().create_timer(1.0).timeout.connect(func():
		var tw := create_tween()
		tw.tween_property(_black, "modulate:a", 1.0, 0.4))
	get_tree().create_timer(1.45).timeout.connect(func(): finished.emit())


func _process(delta: float) -> void:
	_now += delta
	_update_scene()


func _update_scene() -> void:
	var t := _now - _t0 if _t0 >= 0 else -1.0
	# A quarter to noon, then the hands sweep to twelve; the bell tolls as they arrive.
	var p := clampf((t - 0.6) / 2.6, 0, 1) if t >= 0 else 0.0
	var ease := 1 - pow(1 - p, 3)
	_minute.rotation = (ease - 1) * PI / 2
	_hour.rotation = (ease - 1) * PI / 24
	var since := t - 3.2
	_bell.rotation = sin(since * 6) * maxf(0, 1.6 - since) * 0.09 if since > 0 else 0.0
	if t > 3.2 and not _tolled:
		_tolled = true
		AudioManager.sfx("bell")
	_tumble_x += 60 * get_process_delta_time()
	if _tumble_x > ART_SIZE.x + 60:
		_tumble_x = -60
	_tumble.position = Vector2(_tumble_x, TUMBLE_Y - absf(sin(_tumble_x * 0.02)) * 14)
	_tumble.rotation = _tumble_x * 0.03
	var f := _now - _shot_at if _shot_at >= 0 else -1.0
	_rival.rotation = -minf(1, f / 0.6) * 1.45 if f >= 0 else 0.0  # falls back, away from the hero
	_flash.visible = f >= 0 and f < 0.12
	_white.modulate.a = maxf(0, 0.7 - f * 2.8) if f >= 0 and f < 0.25 else 0.0
	if f < 0.9:  # the closing fade is a tween once the shot has landed
		_black.modulate.a = 0.92 if t < 0 else (minf(0.92, 1 - t / 0.8) if t < 0.8 else 0.0)
	# The title stamps in at noon; "Tap to draw" fades in, then blinks.
	_title.modulate.a = clampf((t - 3.2) / 0.35, 0, 1) if t >= 0 else 0.0
	_title.scale = Vector2.ONE * (1 + 1.6 * (1 - _title.modulate.a))
	_title.pivot_offset = _title.size / 2
	if f >= 0:
		_tap.modulate.a = 0.0
	elif t > 4.4:
		_tap.modulate.a = 1.0 - 0.75 * (0.5 - 0.5 * cos((t - 4.4) / 1.2 * TAU))
	else:
		_tap.modulate.a = clampf((t - 3.8) / 0.5, 0, 1) if t >= 0 else 0.0
