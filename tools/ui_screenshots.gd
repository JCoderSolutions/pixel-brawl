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


## In a match: the HUD with weapons, the touch buttons, the standings between
## rounds and the winner screen.
func _snap_match() -> void:
	var manager := root.get_node("GameManager")
	manager.configure_match(1, 1)
	var arena: Node = load(MapCatalog.path(0)).instantiate()
	arena.get_node("TouchControls").visibility = TouchControls.Visibility.ALWAYS
	root.add_child(arena)
	for i in 90:
		await physics_frame
	var holder: WeaponHolder = manager.get_player(0).weapons
	holder.equip(load("res://scripts/weapons/data/bat.tres"))
	holder.equip(load("res://scripts/weapons/data/grenade.tres"), 2)
	holder.equip(load("res://scripts/weapons/data/pistol.tres"))
	await _snap("08_partida")
	var hud := arena.get_node("HUD")
	hud.scoreboard.refresh(manager)
	hud.scoreboard.show()
	await _snap("09_entre_rondas")
	hud.scoreboard.hide()
	manager.match_ended.emit(0)
	await _snap("10_ganador")


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
	menu.queue_free()
	await process_frame
	await _snap_match()
	print("OK: screenshots in %s" % ProjectSettings.globalize_path(_out))
	quit()
