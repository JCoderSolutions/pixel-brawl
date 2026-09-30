extends SceneTree

## Saves a PNG of every menu screen at the window size (960x540, the base
## 480x270 at 2x) so UI changes can be reviewed in PRs. Needs a display and a
## GPU driver; on a headless machine use tools/ui_screenshots.sh (Xvfb).
##   godot --rendering-driver opengl3 --path . -s tools/ui_screenshots.gd -- <out_dir>

var _out := "user://ui_screenshots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _snap(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _run() -> void:
	root.size = Vector2i(960, 540)
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _snap("01_titulo")
	menu.set_counts(1, 0)
	menu.open_setup()
	await _snap("02_luchadores_solo")
	menu.add_bot()
	menu.join(ControlSchemes.Scheme.ARROWS)
	menu._show(menu.Step.FIGHTERS)
	await _snap("03_luchadores_2_y_bot")
	menu.set_counts(2, 2)
	menu.set_control(1, ControlSchemes.Scheme.PAD_1)
	menu.set_bot_level(1, BotProfile.Difficulty.HARD)
	menu.set_team(0, 1)
	menu.set_team(1, 3)
	menu._show(menu.Step.FIGHTERS)
	await _snap("04_luchadores_llenas")
	menu._show(menu.Step.MAP)
	await _snap("05_mapa")
	menu._show(menu.Step.ROUNDS)
	await _snap("06_rondas")
	menu._show(menu.Step.TITLE)
	menu._options.open()
	await _snap("07_opciones")
	print("OK: screenshots in %s" % ProjectSettings.globalize_path(_out))
	quit()
