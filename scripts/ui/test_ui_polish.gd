extends SceneTree

## Headless tests for the UI polish (TASK-024 Fase 5): menu sounds and the
## 1 px focus hop (UiFeedback), the pixel icons on the fighter cards, the
## weapon drawn in the HUD, the pause menu and its touch button.
## Run: godot --headless --path . -s scripts/ui/test_ui_polish.gd

const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")

var _ok := true
var _sounds: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	root.get_node("AudioManager").sfx_played.connect(func(sfx: StringName) -> void: _sounds.append(sfx))
	await _test_menu_sounds_and_hop()
	await _test_card_icons()
	await _test_match_hud_and_pause()
	print("OK: menu sounds, focus hop, device and bot icons, HUD weapon icon, pause menu and its touch button verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## AudioManager skips a sound repeated within its min_interval, in real time
## (the game clock runs ahead with --fixed-fps).
func _quiet() -> void:
	OS.delay_msec(150)
	await process_frame


func _test_menu_sounds_and_hop() -> void:
	for sfx in [&"ui_move", &"ui_confirm", &"ui_back"]:
		_check(root.get_node("AudioManager").has_sfx(sfx), "the %s sound exists" % sfx)
	var menu: Control = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await _frames(3)
	var options: Button = menu.get_node("%OptionsButton")
	var rest := options.position.y
	await _quiet()
	_sounds.clear()
	options.grab_focus()
	_check(&"ui_move" in _sounds, "moving the focus ticks (%s)" % [_sounds])
	await process_frame
	_check(is_equal_approx(options.position.y, rest - 1.0), "and the focused button hops 1 px")
	await _frames(12)
	_check(is_equal_approx(options.position.y, rest), "then settles back (%.1f -> %.1f)" % [rest, options.position.y])
	await _quiet()
	_sounds.clear()
	menu.get_node("%PlayButton").pressed.emit()
	_check(&"ui_confirm" in _sounds, "pressing a button confirms")
	await _quiet()
	_sounds.clear()
	menu.back()
	_check(&"ui_back" in _sounds and not &"ui_confirm" in _sounds, "going back plays the back sound only (%s)" % [_sounds])
	menu.queue_free()
	await _frames(1)


func _test_card_icons() -> void:
	_check(UiIcons.texture(UiIcons.KEYBOARD).get_size() == Vector2(8, 8), "icons are 8x8")
	_check(UiIcons.for_scheme(ControlSchemes.Scheme.PAD_2) == UiIcons.PAD and UiIcons.for_scheme(ControlSchemes.Scheme.ARROWS) == UiIcons.KEYBOARD,
			"pads get the pad icon, keyboard halves the keyboard")
	var menu: Control = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await _frames(1)
	menu.set_counts(2, 1)
	menu.set_control(1, ControlSchemes.Scheme.PAD_1)
	menu.open_setup()
	var cards: Node = menu.get_node("%Content").get_node("Cards")
	var icon := func(slot: int) -> Texture2D: return (cards.get_child(slot).find_child("Icon", true, false) as TextureRect).texture
	_check(icon.call(0) == UiIcons.texture(UiIcons.KEYBOARD), "P1's card shows a keyboard")
	_check(icon.call(1) == UiIcons.texture(UiIcons.PAD), "P2 on a pad shows a pad")
	_check(icon.call(2) == UiIcons.texture(UiIcons.BOT), "the bot shows a bot")
	menu.set_counts(1, 1)
	menu.queue_free()
	await _frames(1)


func _test_match_hud_and_pause() -> void:
	var manager := root.get_node("GameManager")
	manager.configure_match(1, 1)
	var arena: Node = load(MapCatalog.path(0)).instantiate()
	arena.get_node("TouchControls").visibility = TouchControls.Visibility.ALWAYS
	root.add_child(arena)
	await _frames(3)
	manager.get_player(0).weapons.equip(PISTOL)
	_check(arena.get_node("HUD").weapon_icon(0) == PISTOL, "the HUD draws the weapon in hand")

	var pause: PauseMenu = arena.get_node("PauseMenu")
	_check(pause != null and not pause.visible, "the arena has a hidden pause menu")
	var touch: TouchControls = arena.get_node("TouchControls")
	var pause_button: TouchActionButton = touch.buttons["Pause"]
	_check(pause_button.action == "pause", "the touch II button presses pause")
	var screen := touch.get_viewport().get_visible_rect().size
	_check(absf(pause_button.position.x + pause_button.size.x / 2.0 - screen.x / 2.0) < 1.0 and pause_button.position.y < screen.y * 0.2,
			"at the top centre, away from the thumbs")
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	_check(paused and pause.visible, "pause freezes the match and shows the menu")
	var time_left: float = manager.get("_state_timer")
	await _frames(5)
	_check(manager.get("_state_timer") == time_left, "the match clock stops")
	Input.action_press("pause")
	await _frames(2)
	Input.action_release("pause")
	_check(not paused and not pause.visible, "pause again resumes")
	arena.get_node("WinnerScreen").show()
	_check(not pause.pause() and not paused, "no pause once the match is over")
	arena.get_node("WinnerScreen").hide()
	pause.pause()
	await _frames(12)
	var box: Control = pause.get_child(1).get_child(0)
	_check(box.get_child(1).position.y > box.get_child(0).position.y + box.get_child(0).size.y - 1.0,
			"the focused Seguir stays under the PAUSA title")
	pause.restart()
	_check(not paused and not pause.visible, "Reiniciar starts over unpaused")
	arena.queue_free()
	await _frames(1)
	manager.teardown()
	manager.configure_bots(0, BotProfile.Difficulty.NORMAL)
