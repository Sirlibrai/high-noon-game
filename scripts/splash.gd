class_name Splash
extends Node2D
## The splash standoff (the prototype's titleScreen / enter / drawStandoff):
## "Tap to begin" wakes the town and starts the music; the clock's minute hand
## sweeps to noon and the bell tolls; "Tap to draw" fires, the rival falls and
## the scene fades to the sheriff's office. Every picture is a manifest asset.

signal finished

var PPU: float = GameState.geometry.pixels_per_unit

var _t0 := -1.0  # seconds since "begin"; -1 until the first tap
var _shot_at := -1.0
var _tolled := false
var _tumble_x := -20.0
var _now := 0.0
var _hand: AssetSprite
var _bell: AssetSprite
var _rival: AssetSprite
var _flash: AssetSprite
var _tumble: AssetSprite
var _white: TextureRect
var _black: TextureRect
var _begin: Control
var _title: Label
var _tap: Label


func _ready() -> void:
	for layer in Assets.scenes.splash.layers:
		AssetSprite.make(layer, self)
	_place(AssetSprite.make("splash/haze", self), Vector2(0, 108))
	_place(AssetSprite.make("splash/tower", self), Vector2(146, 20))
	_hand = AssetSprite.make("splash/minute_hand", self)
	_place(_hand, Vector2(160, 54))
	_bell = AssetSprite.make("splash/bell", self)
	_place(AssetSprite.make("splash/shadow", self), Vector2(44, 160))
	_place(AssetSprite.make("splash/shadow", self), Vector2(232, 160))
	_place(AssetSprite.make("splash/hero", self), Vector2(61, 160))
	_rival = AssetSprite.make("splash/rival", self)
	_place(_rival, Vector2(270, 160))
	_tumble = AssetSprite.make("prop/tumbleweed", self)
	_flash = AssetSprite.make("splash/muzzle_flash", self)
	_place(_flash, Vector2(80, 118))
	_flash.visible = false

	var ui := CanvasLayer.new()
	ui.layer = 7
	add_child(ui)
	_white = _screen(ui, "fx/screen_white")
	_black = _screen(ui, "fx/screen_black")
	_title = UiKit.text(ui, "HIGH NOON", &"InkTitle")
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.anchor_top = 0.47
	_title.anchor_bottom = 0.47
	_title.modulate.a = 0.0
	_title.rotation = deg_to_rad(-4)
	_tap = UiKit.text(ui, "TAP TO DRAW", &"TapPrompt")
	_tap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tap.anchor_top = 0.86
	_tap.anchor_bottom = 0.86
	_tap.modulate.a = 0.0
	_begin = UiKit.card(ui)
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


func _place(n: Node2D, at: Vector2) -> void:
	n.position = at * PPU


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
	var p := clampf((t - 0.6) / 2.6, 0, 1) if t >= 0 else 0.0
	var ease := 1 - pow(1 - p, 3)
	_hand.rotation = -PI + ease * PI / 2
	var sw := sin((t - 3.2) * 6) * maxf(0, 1.6 - (t - 3.2)) * 2 if t > 3.2 else 0.0
	_place(_bell, Vector2(157 + roundf(sw), 27))
	if t > 3.2 and not _tolled:
		_tolled = true
		AudioManager.sfx("bell")
	_tumble_x += 0.5 * 60 * get_process_delta_time()
	if _tumble_x > 340:
		_tumble_x = -20
	_place(_tumble, Vector2(roundf(_tumble_x) + 5, 164 - absf(roundf(sin(_tumble_x * 0.08) * 4))))
	var f := _now - _shot_at if _shot_at >= 0 else -1.0
	_rival.rotation = minf(1, f / 0.6) * 1.45 if f >= 0 else 0.0
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
