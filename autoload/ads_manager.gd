extends Node
## Rewarded ads. For now this is the prototype's stand-in: a five-second
## "SIMULATED AD" card that never shows a real advert. A real SDK (AdMob,
## AppLovin) replaces show_rewarded() later; callers only see `available()`
## and a callback that reports whether the reward was earned.

const AD_SECONDS := 5

var _layer: CanvasLayer


func available() -> bool:
	return true


## Calls on_done(granted: bool) when the player collects the reward or skips.
func show_rewarded(type: String, on_done: Callable) -> void:
	_close()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var ui := UiKit.overlay(_layer)
	var card := UiKit.card(ui)
	UiKit.text(card, "SIMULATED AD", &"AdTag")
	UiKit.text(card, "Your reward is on its way", &"Heading")
	UiKit.text(card, "This stands in for a rewarded video (%s). No real advert is shown." % type, &"Hint", 840)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(520, 20)
	bar.show_percentage = false
	bar.max_value = AD_SECONDS
	card.add_child(bar)
	var skip := UiKit.button(card, "Skip (no reward)", &"GhostButton")
	skip.pressed.connect(func(): _close(); on_done.call(false))
	var left := AD_SECONDS
	while left > 0:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(bar):
			return
		left -= 1
		bar.value = AD_SECONDS - left
	skip.queue_free()
	var collect := UiKit.button(card, "Collect reward")
	collect.pressed.connect(func(): _close(); on_done.call(true))


func _close() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
