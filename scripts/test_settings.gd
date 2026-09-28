extends SceneTree

## Headless tests for the options (TASK-012/TASK-015): GameSettings saves and
## loads music/effects volume, fullscreen and the touch controls mode, applies
## the volumes to the audio buses, the touch controls follow the saved mode,
## and the main menu's "Opciones" panel edits and stores them.
## Run: godot --headless --path . -s scripts/test_settings.gd

const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const TOUCH_SCENE := preload("res://scenes/ui/touch/touch_controls.tscn")
const TEST_PATH := "user://test_settings.cfg"

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	GameSettings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_test_defaults_and_round_trip()
	_test_volumes_reach_the_buses()
	await _test_touch_mode()
	await _test_options_panel()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameSettings.reset()
	GameSettings.apply()
	print("OK: settings defaults, save/load, bus volumes, touch controls mode and the options panel verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _audio() -> Node:
	return root.get_node("/root/AudioManager")


func _test_defaults_and_round_trip() -> void:
	GameSettings.reset()
	_check(GameSettings.music_volume == 1.0 and GameSettings.sfx_volume == 1.0, "volumes start full")
	_check(not GameSettings.fullscreen, "windowed by default")
	_check(GameSettings.touch_mode == TouchControls.Visibility.AUTO, "touch controls on touch screens by default")
	GameSettings.load_saved()
	_check(GameSettings.music_volume == 1.0, "a missing file keeps the defaults")

	GameSettings.music_volume = 0.25
	GameSettings.sfx_volume = 0.6
	GameSettings.fullscreen = true
	GameSettings.touch_mode = TouchControls.Visibility.ALWAYS
	GameSettings.save()
	GameSettings.reset()
	GameSettings.load_saved()
	_check(is_equal_approx(GameSettings.music_volume, 0.25), "music volume survives a restart")
	_check(is_equal_approx(GameSettings.sfx_volume, 0.6), "effects volume survives a restart")
	_check(GameSettings.fullscreen, "fullscreen survives a restart")
	_check(GameSettings.touch_mode == TouchControls.Visibility.ALWAYS, "touch mode survives a restart")

	var file := ConfigFile.new()
	file.set_value("audio", "music", 7.0)
	file.set_value("display", "touch_mode", 99)
	file.save(TEST_PATH)
	GameSettings.load_saved()
	_check(GameSettings.music_volume == 1.0, "out-of-range volumes are clamped")
	_check(GameSettings.touch_mode == TouchControls.Visibility.AUTO, "unknown touch modes fall back to auto")
	GameSettings.reset()


func _test_volumes_reach_the_buses() -> void:
	GameSettings.music_volume = 0.5
	GameSettings.sfx_volume = 0.0
	GameSettings.apply()
	_check(absf(_audio().get_bus_volume(&"Music") - 0.5) < 0.01, "music volume drives the Music bus")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "zero effects volume mutes the SFX bus")
	GameSettings.reset()
	GameSettings.apply()
	_check(absf(_audio().get_bus_volume(&"SFX") - 1.0) < 0.01, "effects come back at full volume")


func _test_touch_mode() -> void:
	for mode in [TouchControls.Visibility.ALWAYS, TouchControls.Visibility.NEVER]:
		GameSettings.touch_mode = mode
		var touch: TouchControls = TOUCH_SCENE.instantiate()
		root.add_child(touch)
		await process_frame
		_check(touch.visible == (mode == TouchControls.Visibility.ALWAYS),
				"touch controls follow the saved mode %s" % TouchControls.Visibility.keys()[mode])
		touch.queue_free()
		await process_frame
	GameSettings.reset()


func _test_options_panel() -> void:
	var menu: Control = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	var options: OptionsMenu = menu.get_node("%Options")
	_check(not options.visible, "the options panel starts hidden")
	var button: Button = menu.get_node("%OptionsButton")
	button.pressed.emit()
	_check(options.visible, "Opciones opens the panel")
	_check(options.get_node("%Music").has_focus(), "the music slider takes the focus (keyboard and pads)")

	options.get_node("%Music").value = 0.3
	options.get_node("%Effects").value = 0.7
	options.get_node("%Touch").select(2)
	options.get_node("%Touch").item_selected.emit(2)
	_check(is_equal_approx(GameSettings.music_volume, 0.3), "the music slider sets the music volume")
	_check(absf(_audio().get_bus_volume(&"Music") - 0.3) < 0.01, "and applies it right away")
	_check(is_equal_approx(GameSettings.sfx_volume, 0.7), "the effects slider sets the effects volume")
	_check(GameSettings.touch_mode == TouchControls.Visibility.NEVER, "the touch option sets the mode")
	var saved := ConfigFile.new()
	_check(saved.load(TEST_PATH) == OK and is_equal_approx(saved.get_value("audio", "music", 0.0), 0.3),
			"every change is saved")

	options.get_node("%Back").pressed.emit()
	_check(not options.visible, "Volver closes the panel")
	_check(button.has_focus(), "focus goes back to Opciones")

	menu.queue_free()
	await process_frame
	menu = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	options = menu.get_node("%Options")
	options.open()
	_check(is_equal_approx(options.get_node("%Music").value, 0.3), "the panel shows the stored music volume")
	_check(options.get_node("%Touch").selected == 2, "the panel shows the stored touch mode")
	menu.queue_free()
	await process_frame
