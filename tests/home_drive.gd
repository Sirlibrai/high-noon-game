extends Node
## Visual check of the home flow: the splash standoff, the office at three
## campaign points (new save, Iron Eli captured, everything captured), the
## Bounty board, a level grid and a coming-soon card. Saves screenshots and
## never touches the player's save:
##   Godot --path . res://tests/home_drive.tscn -- <output dir>

var main: Node
var out_dir := "user://home_drive"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.persist = false
	SaveManager.data.progress = SaveManager.fresh_progress()
	SaveManager.data.settings.playtest = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.4)
	await _shot("01_splash_begin")
	main._screen.tap()
	await _wait(1.0)
	await _shot("02_splash_fading_in")
	await _wait(3.6)
	await _shot("03_splash_noon")
	main._screen.tap()
	await _wait(0.08)
	await _shot("04_splash_draw")
	await _wait(1.8)
	await _shot("05_office_new_save")
	main.show_board()
	await _wait(0.3)
	await _shot("06_board_new_save")
	main.show_chapter(0)
	await _wait(0.3)
	await _shot("07_main_street_levels")
	main.soon("daily")
	await _wait(0.3)
	await _shot("08_daily_soon")

	# Iron Eli captured (a 2-star win on level 10, after levels 1 to 9).
	var pg: Dictionary = GameState.progress
	for l in 9:
		GameState.apply_win(pg, 0, l, 3, {"boss": false, "last": false, "bounty": 1000, "count": 10})
	GameState.apply_win(pg, 0, 9, 2, {"boss": true, "last": true, "bounty": 1000, "count": 10})
	main._fresh_capture = 0
	main.show_home()
	await _wait(0.3)
	await _shot("09_office_eli_stamp_landing")
	await _wait(1.0)
	await _shot("10_office_eli_captured")
	main.show_board()
	await _wait(0.3)
	await _shot("11_board_eli_captured")

	# Both playable bounties captured.
	GameState.apply_win(pg, 1, 9, 1, {"boss": true, "last": true, "bounty": 1500, "count": 10})
	main.show_home()
	await _wait(0.4)
	await _shot("12_office_all_captured")
	main.show_board()
	await _wait(0.3)
	await _shot("13_board_all_captured")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
