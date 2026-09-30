extends SceneTree

## Headless tests for the match setup in the main menu: title -> fighters
## (a lobby of four cards, like Superfighters' open slots: players join with
## a button, "+ Bot" adds bots, each with its own difficulty) -> map ->
## rounds, with "Atrás" going back a step, and the GameManager getting the
## whole setup when the match starts.
## Run: godot --headless --path . -s scripts/test_main_menu.gd

const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const HARD := BotProfile.Difficulty.HARD
const EASY := BotProfile.Difficulty.EASY
const NORMAL := BotProfile.Difficulty.NORMAL

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_steps()
	await _test_bots_from_the_cards()
	await _test_players_join_on_the_cards()
	await _test_fighter_cards()
	await _test_teams_need_a_rival()
	await _test_setup_reaches_the_manager()
	await _test_bots_match_spawns_the_setup()
	print("OK: the menu walks fighters, map and rounds, adds and removes bots with their own difficulty from the cards, lets players join and leave, validates teams and hands the setup to the GameManager verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _gm() -> Node:
	return root.get_node("GameManager")


func _menu() -> Control:
	var menu: Control = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	return menu


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _card(menu: Control, slot: int) -> Control:
	return menu.get_node("%Content").get_node("Cards").get_child(slot)


func _press(menu: Control, slot: int, path: String) -> void:
	(_card(menu, slot).find_child(path, true, false) as Button).pressed.emit()


func _test_steps() -> void:
	var menu := await _menu()
	var steps = menu.Step
	menu.set_counts(1, 1)
	_check(menu.step == steps.TITLE and menu.get_node("%TitleBox").visible, "starts on the title")
	menu.get_node("%PlayButton").pressed.emit()
	_check(menu.step == steps.FIGHTERS and menu.get_node("%SetupBox").visible and not menu.get_node("%TitleBox").visible,
			"Jugar opens the fighters cards")
	for expected in [steps.MAP, steps.ROUNDS]:
		menu.next()
		_check(menu.step == expected, "next reaches step %d (at %d)" % [expected, menu.step])
	_check(menu.get_node("%NextButton").text == "¡A pelear!", "the last step starts the fight")
	for expected in [steps.MAP, steps.FIGHTERS, steps.TITLE]:
		menu.back()
		_check(menu.step == expected, "back returns to step %d (at %d)" % [expected, menu.step])
	menu.open_setup()
	menu.next()
	menu.get_node("%Content").get_child(0).get_child(2).pressed.emit()
	_check(menu.map_choice() == 2 and menu.step == steps.ROUNDS, "picking a map goes on to the rounds")
	await _free(menu)


func _test_bots_from_the_cards() -> void:
	var menu := await _menu()
	menu.set_counts(1, 0)
	menu.open_setup()
	_check(menu.get_node("%NextButton").disabled, "alone there is nobody to fight")
	_check(_card(menu, 1).find_child("AddBot", true, false) != null and _card(menu, 3).find_child("AddBot", true, false) != null,
			"every free card offers + Bot")
	_press(menu, 1, "AddBot")
	_check(menu.bots() == 1 and not menu.get_node("%NextButton").disabled, "+ Bot adds a bot and the match can start")
	_check((_card(menu, 1).find_child("Tag", true, false) as Label).text == "BOT 1", "on the next card")
	var level: Control = _card(menu, 1).find_child("Level", true, false)
	level.get_node("Next").pressed.emit()
	_check(menu.bot_level(0) == HARD and (level.get_node("Value") as Label).text == BotProfile.display_name(HARD),
			"the card's arrows set that bot's difficulty")
	_press(menu, 2, "AddBot")
	_check(menu.bot_level(1) == HARD, "a new bot starts at the last bot's difficulty")
	var second: Control = _card(menu, 2).find_child("Level", true, false)
	second.get_node("Prev").pressed.emit()
	second.get_node("Prev").pressed.emit()
	_check(menu.bot_level(1) == EASY and menu.bot_level(0) == HARD, "each bot keeps its own difficulty")
	_press(menu, 3, "AddBot")
	_check(menu.fighters() == 4 and _card(menu, 3).find_child("AddBot", true, false) == null, "four cards, none free")
	_check(not menu.add_bot(), "no fifth fighter")
	_press(menu, 1, "Remove")
	_check(menu.bots() == 2 and menu.bot_level(0) == EASY, "× takes BOT 1 out and the others move up")
	menu.apply_selection()
	_check(_gm().bot_difficulties == [EASY, EASY], "the GameManager gets each bot's difficulty (%s)" % [_gm().bot_difficulties])
	await _free(menu)


func _test_players_join_on_the_cards() -> void:
	var menu := await _menu()
	menu.set_counts(1, 2)
	menu.set_difficulty(HARD)
	menu.set_look(1, 5)
	menu.open_setup()
	_check(menu.control(0) == ControlSchemes.Scheme.KEYS_OR_PAD, "P1 alone plays with the keyboard or any pad")
	_check(menu.join(ControlSchemes.Scheme.PAD_2), "a free pad joins")
	_check(menu.humans() == 2 and menu.bots() == 2 and menu.look(2) == 5, "as P2, the bots move one card over")
	_check(not menu.join(ControlSchemes.Scheme.PAD_2), "the same pad can't join twice")
	_check(menu.join(ControlSchemes.Scheme.ARROWS) and menu.humans() == 3 and menu.bots() == 1,
			"with every card taken, the last bot makes room")
	menu.leave(1)
	_check(menu.humans() == 2 and menu.control(1) == ControlSchemes.Scheme.ARROWS, "P2 leaves and P3 moves up")
	menu.leave(0)
	_check(menu.humans() == 2, "P1 can't leave")
	menu.open_setup()
	_press(menu, 3, "Join")
	_check(menu.humans() == 3 and not menu.scheme_taken(menu.control(2), 2), "Unirse joins with a free device (touch, mouse)")
	await _free(menu)


func _test_fighter_cards() -> void:
	var menu := await _menu()
	menu.set_counts(2, 1)
	for slot in 3:
		menu.set_look(slot, slot)
		menu.set_team(slot, 0)
	menu.open_setup()
	var tag := func(slot: int) -> String: return (_card(menu, slot).find_child("Tag", true, false) as Label).text
	_check(tag.call(0) == "P1" and tag.call(1) == "P2" and tag.call(2) == "BOT 1", "humans first, then bots")
	_check(_card(menu, 3).find_child("AddBot", true, false) != null, "and a free card")
	var pick: Node = _card(menu, 1).find_child("Pick", true, false)
	pick.get_node("Next").pressed.emit()
	_check(menu.look(1) == 2 and pick.get_node("Value").text == FighterLook.at(2).name, "› shows the next character")
	_check(_card(menu, 1).find_child("Rig", true, false).look == FighterLook.at(2), "and the preview wears it")
	_card(menu, 0).find_child("Pick", true, false).get_node("Prev").pressed.emit()
	_check(menu.look(0) == FighterLook.presets().size() - 1, "‹ wraps around the roster")
	var team_button: Button = _card(menu, 2).find_child("Team", true, false)
	team_button.pressed.emit()
	_check(menu.team(2) == 1 and team_button.text == "Rojo", "the team button cycles the teams")
	_check(_card(menu, 2).find_child("Rig", true, false).team_color == GameManager.TEAM_COLORS[1], "and marks the preview")
	await process_frame
	var width := _card(menu, 0).size.x
	_check(_card(menu, 1).size.x == width and _card(menu, 2).size.x == width and _card(menu, 3).size.x == width,
			"every card has the same width whatever it says (%.0f)" % width)
	menu.set_team(2, 0)
	await _free(menu)


func _test_teams_need_a_rival() -> void:
	var menu := await _menu()
	menu.set_counts(2, 0)
	menu.set_team(0, 2)
	menu.set_team(1, 2)
	_check(not menu.teams_valid(), "everybody on one team leaves nobody to fight")
	menu.open_setup()
	_check(menu.get_node("%NextButton").disabled, "so the fighters step won't go on")
	menu.next()
	_check(menu.step == menu.Step.FIGHTERS, "not even when forced")
	menu.set_team(1, 1)
	_check(menu.teams_valid(), "two teams are fine")
	menu.set_team(0, 0)
	menu.set_team(1, 0)
	await _free(menu)


func _test_setup_reaches_the_manager() -> void:
	var menu := await _menu()
	menu.set_counts(2, 2)
	for slot in 4:
		menu.set_look(slot, 7 - slot)
		menu.set_team(slot, 1 if slot % 2 == 0 else 2)
	menu.select_map(1)
	menu.set_difficulty(HARD)
	menu.set_rounds(5)
	menu.apply_selection()
	var gm := _gm()
	_check(gm.human_players == 2 and gm.bot_difficulties == [HARD, HARD] and gm.match_size == 4,
			"2 humans and 2 hard bots")
	_check(gm.looks == [7, 6, 5, 4], "the characters (%s)" % [gm.looks])
	_check(gm.teams == [1, 2, 1, 2], "the teams (%s)" % [gm.teams])
	_check(gm.rounds_to_win == 5, "the rounds")
	_check(menu.match_scene == MapCatalog.path(0), "the map")
	menu.set_counts(3, 0)
	menu.set_rounds(3)
	for slot in 4:
		menu.set_team(slot, 0)
	menu.apply_selection()
	_check(gm.bot_difficulties.is_empty() and gm.match_size == 3 and gm.looks.size() == 3, "3 local players, no bots")
	_check(gm.teams == [0, 0, 0], "each on their own")
	menu.set_counts(1, 1)
	menu.set_difficulty(NORMAL)
	await _free(menu)


func _test_bots_match_spawns_the_setup() -> void:
	var gm := _gm()
	gm.configure_match(3, 0)
	gm.looks.assign([4, 5, 6])
	gm.teams.assign([1, 1, 2])
	var arena: Node2D = load(MapCatalog.path(0)).instantiate()
	arena.get_node("TouchControls").visibility = TouchControls.Visibility.NEVER
	root.add_child(arena)
	await process_frame
	_check(gm.get_player_ids() == [0, 1, 2], "3 local players spawn (%s)" % [gm.get_player_ids()])
	for id in 3:
		var player = gm.get_player(id)
		_check(player.input_source is DeviceInputSource and player.player_slot == id + 1, "P%d reads its own slot" % (id + 1))
		_check(player.get_node("Visual").look == FighterLook.at(4 + id), "P%d wears its character" % (id + 1))
	_check(gm.get_player(1).team == 1 and gm.get_player(2).team == 2, "and plays for its team")
	await _free(arena)
	gm.configure_bots(0, BotProfile.Difficulty.NORMAL)
	gm.looks.clear()
	gm.teams.clear()
	gm.rounds_to_win = 3
