extends Node
## Visual playthrough: the scripted player (AutoPlayer) plays every Main Street
## level through the real main scene, in real time at double speed, and saves
## screenshots. Needs a window (not --headless); never touches the player's save:
##   Godot --path . res://tests/drive.tscn -- <output dir>

const SPEED := 2.0
const EVENT_SHOTS := ["crack:tnt", "crack:sign", "throw", "stage:2", "stage:3", "bell1"]

var main: Node
var out_dir := "user://drive"
var bot: AutoPlayer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.persist = false
	SaveManager.data.progress = SaveManager.fresh_progress()
	SaveManager.data.settings.playtest = true
	Engine.time_scale = SPEED
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	await _shot("00_menu")
	var lvls: Array = GameState.levels_for(0)
	for i in lvls.size():
		var tag := "%02d" % (i + 1)
		main.show_intro(0, i)
		await _wait(0.3)
		await _shot(tag + "_a_intro")
		main._go()
		bot = AutoPlayer.new()
		if lvls[i].get("eli", false):
			bot.foul_rounds = [1]
		var lv: Level = main.level
		var t := 0.0
		var mid := false
		var seen := {}
		while is_instance_valid(lv) and lv.state == "play" and t < 300.0:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if not mid and t > 2.5:
				mid = true
				await _shot(tag + "_b_play")
			for ev in EVENT_SHOTS:
				if not seen.has(ev) and lv.events.has(ev):
					seen[ev] = true
					await _wait(0.15)
					await _shot("%s_c_%s" % [tag, ev.replace(":", "_")])
		await _wait(1.0)
		await _shot(tag + "_d_end")
		print("%s %s: %s, %d shots, %d hearts, events %s" % [tag, lvls[i].name, lv.state, lv.used, lv.hearts, lv.events])
		bot = null
	await _wait(0.3)
	main.show_home()
	await _wait(0.3)
	await _shot("11_menu_after")
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	if bot != null and main != null and main.level != null:
		var p: Variant = bot.decide(main.level)
		if p != null:
			main.level.shoot(p, true)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
