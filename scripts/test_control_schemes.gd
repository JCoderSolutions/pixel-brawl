extends SceneTree

## Headless tests for ControlSchemes: each local player can take a keyboard
## half or any gamepad, whatever order the pads were plugged in; defaults
## follow the players and pads available, clashes are caught, and reset()
## brings back the shipped bindings.
## Run: godot --headless --path . -s scripts/test_control_schemes.gd

const S := ControlSchemes.Scheme

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_defaults()
	_test_clashes()
	_test_apply_rebinds_slots()
	await _test_menu_and_manager()
	print("OK: control defaults, clashes, rebinding slots to keyboard halves and any pad, reset and the menu's control picker verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


func _pad_button(device: int, button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func _test_defaults() -> void:
	_check(ControlSchemes.defaults(1, 0) == [S.KEYS_OR_PAD], "alone: keyboard or the first pad, both work")
	_check(ControlSchemes.defaults(2, 0) == [S.WASD, S.ARROWS], "2 players, no pads: the two keyboard halves")
	_check(ControlSchemes.defaults(2, 2) == [S.PAD_1, S.PAD_2], "2 players, 2 pads: one pad each")
	_check(ControlSchemes.defaults(4, 2) == [S.WASD, S.ARROWS, S.PAD_1, S.PAD_2],
			"4 players, 2 pads: keyboards for P1 and P2, pads 1 and 2 for P3 and P4")
	_check(ControlSchemes.defaults(3, 1) == [S.WASD, S.ARROWS, S.PAD_1], "3 players, 1 pad")


func _test_clashes() -> void:
	_check(ControlSchemes.clash(S.KEYS_OR_PAD, S.WASD), "keyboard-or-pad takes WASD")
	_check(ControlSchemes.clash(S.KEYS_OR_PAD, S.PAD_1), "and the first pad")
	_check(not ControlSchemes.clash(S.KEYS_OR_PAD, S.ARROWS), "but not the arrows")
	_check(not ControlSchemes.all_distinct([S.PAD_2, S.PAD_2]), "one pad can't drive two players")
	_check(ControlSchemes.all_distinct([S.WASD, S.ARROWS, S.PAD_1, S.PAD_2]), "a full table is fine")


func _test_apply_rebinds_slots() -> void:
	var a := _key(KEY_A)
	var left := _key(KEY_LEFT)
	ControlSchemes.apply([S.ARROWS, S.PAD_3, S.WASD, S.PAD_1])
	_check(InputMap.event_is_action(left, "p1_move_left") and not InputMap.event_is_action(a, "p1_move_left"),
			"P1 on the arrows")
	_check(InputMap.event_is_action(_pad_button(2, JOY_BUTTON_A), "p2_jump") and not InputMap.event_is_action(left, "p2_move_left"),
			"P2 on the third pad only")
	_check(InputMap.event_is_action(a, "p3_move_left"), "P3 on WASD")
	_check(InputMap.event_is_action(_pad_button(0, JOY_BUTTON_X), "p4_attack") and not InputMap.event_is_action(_pad_button(0, JOY_BUTTON_X), "p1_attack"),
			"P4 on the first pad, which P1 no longer reads")
	ControlSchemes.apply([S.KEYS_OR_PAD])
	_check(InputMap.event_is_action(a, "p1_move_left") and InputMap.event_is_action(_pad_button(0, JOY_BUTTON_A), "p1_jump"),
			"keyboard-or-pad: WASD and the first pad")
	ControlSchemes.reset()
	_check(InputMap.event_is_action(a, "p1_move_left") and InputMap.event_is_action(_pad_button(0, JOY_BUTTON_A), "p1_jump")
			and InputMap.event_is_action(left, "p2_move_left") and InputMap.event_is_action(_pad_button(2, JOY_BUTTON_A), "p3_jump")
			and not InputMap.event_is_action(a, "p3_move_left"),
			"reset brings back the shipped bindings")


func _card(menu: Control, slot: int) -> Control:
	return menu.get_node("%Content").get_node("Cards").get_child(slot)


func _test_menu_and_manager() -> void:
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_counts(3, 0)
	menu.set_counts(4, 0)
	# Headless: no pads plugged in.
	_check([menu.control(0), menu.control(1), menu.control(2), menu.control(3)] == [S.WASD, S.ARROWS, S.PAD_1, S.PAD_2],
			"a lineup set directly starts from the defaults")
	menu.set_counts(1, 0)
	menu.open_setup()
	_check(menu.control(0) == S.KEYS_OR_PAD, "P1 alone: keyboard or the first pad")
	# "Apretá para unirte": attack/block/pickup/switch keys of a free keyboard
	# half, or any button of a free pad, take the next card.
	_check(not menu.try_join(_key(KEY_J)), "P1's own keys don't join again")
	_check(not menu.try_join(_pad_button(0, JOY_BUTTON_A)), "nor P1's pad")
	_check(not menu.try_join(_key(KEY_ENTER)), "Enter confirms in the menu, it doesn't join")
	_check(not menu.try_join(_key(KEY_RIGHT)), "moving through the menu doesn't join")
	_check(menu.try_join(_key(KEY_PERIOD)) and menu.humans() == 2 and menu.control(1) == S.ARROWS, "the arrows half joins as P2")
	_check(menu.try_join(_pad_button(1, JOY_BUTTON_B)) and menu.control(2) == S.PAD_2, "the second pad joins as P3")
	_check(not menu.try_join(_pad_button(1, JOY_BUTTON_A)), "a pad already in doesn't take a second card")
	var device: Control = _card(menu, 1).find_child("Device", true, false)
	(device.get_node("Next") as Button).pressed.emit()
	_check(menu.control(1) == S.PAD_3 and (device.get_node("Value") as Label).text == "Mando 3",
			"the device arrows skip the ones taken (%d)" % menu.control(1))
	(_card(menu, 1).find_child("Remove", true, false) as Button).pressed.emit()
	_check(menu.humans() == 2 and menu.control(1) == S.PAD_2, "× lets P2 go and P3 moves up")
	_check(menu.try_join(_key(KEY_COMMA)) and menu.control(2) == S.ARROWS, "and someone else can join")
	_check(menu.controls_valid() and not menu.get_node("%NextButton").disabled, "three players on three devices can start")
	menu.apply_selection()
	var gm := root.get_node("GameManager")
	_check(gm.controls == [S.KEYS_OR_PAD, S.PAD_2, S.ARROWS], "the GameManager gets them (%s)" % [gm.controls])
	menu.set_counts(1, 1)
	menu.queue_free()
	await process_frame
	gm.controls.clear()
	gm.configure_bots(0, BotProfile.Difficulty.NORMAL)
	ControlSchemes.reset()
