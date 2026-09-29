extends SceneTree

## Headless tests for the match setup in the main menu (Superfighters-style
## sequence): mode -> how many -> character and team per fighter -> map ->
## difficulty (only with bots) -> rounds, with "Atrás" going back a step, and
## the GameManager getting the whole setup when the match starts.
## Run: godot --headless --path . -s scripts/test_main_menu.gd

const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const HARD := BotProfile.Difficulty.HARD

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_steps_with_bots()
	await _test_steps_local_players()
	await _test_counts_are_clamped()
	await _test_fighter_rows()
	await _test_teams_need_a_rival()
	await _test_setup_reaches_the_manager()
	await _test_bots_match_spawns_the_setup()
	print("OK: the menu walks mode, count, fighters, map, difficulty and rounds, goes back, clamps counts, validates teams and hands the setup to the GameManager verified" if _ok else "FAILED")
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


func _test_steps_with_bots() -> void:
	var menu := await _menu()
	var steps = menu.Step
	_check(menu.step == steps.TITLE and menu.get_node("%TitleBox").visible, "starts on the title")
	menu.get_node("%PlayButton").pressed.emit()
	_check(menu.step == steps.MODE and menu.get_node("%SetupBox").visible and not menu.get_node("%TitleBox").visible,
			"Jugar opens the setup at the mode step")
	# Mode buttons pick and move on at once.
	menu.get_node("%Content").get_child(0).pressed.emit()
	_check(menu.is_vs_bots() and menu.step == steps.COUNT, "Contra bots -> how many")
	for expected in [steps.FIGHTERS, steps.MAP, steps.DIFFICULTY, steps.ROUNDS]:
		menu.next()
		_check(menu.step == expected, "next reaches step %d (at %d)" % [expected, menu.step])
	_check(menu.get_node("%NextButton").text == "¡A pelear!", "the last step starts the fight")
	for expected in [steps.DIFFICULTY, steps.MAP, steps.FIGHTERS, steps.COUNT, steps.MODE, steps.TITLE]:
		menu.back()
		_check(menu.step == expected, "back returns to step %d (at %d)" % [expected, menu.step])
	await _free(menu)


func _test_steps_local_players() -> void:
	var menu := await _menu()
	var steps = menu.Step
	menu.open_setup()
	menu.get_node("%Content").get_child(1).pressed.emit()
	_check(not menu.is_vs_bots() and menu.bots() == 0 and menu.humans() >= 2, "Jugadores locales: no bots, 2+ players")
	menu.next()
	menu.next()
	_check(menu.step == steps.MAP, "at the map")
	menu.get_node("%Content").get_child(0).get_child(2).pressed.emit()
	_check(menu.map_choice() == 2 and menu.step == steps.ROUNDS, "picking a map skips the difficulty without bots")
	menu.back()
	_check(menu.step == steps.MAP, "and back skips it too")
	await _free(menu)


func _test_counts_are_clamped() -> void:
	var menu := await _menu()
	menu.choose_mode(false)
	menu.set_counts(1, 3)
	_check(menu.humans() == 2 and menu.bots() == 0, "local players: at least 2, no bots")
	menu.set_counts(9, 0)
	_check(menu.humans() == 4, "at most 4 players")
	menu.choose_mode(true)
	_check(menu.humans() == 3 and menu.bots() == 1, "with bots: up to 3 humans and at least one bot")
	menu.set_counts(1, 9)
	_check(menu.humans() == 1 and menu.bots() == 3, "never more than 4 fighters")
	menu.set_counts(0, 0)
	_check(menu.humans() == 1 and menu.bots() == 1, "at least one human and one bot")
	# The count step's arrows move the numbers through the same rules.
	menu.open_setup()
	menu.next()
	var bots_row: Control = menu.get_node("%Content").get_child(1)
	bots_row.get_child(1).pressed.emit()
	_check(menu.bots() == 1, "the < arrow can't go under one bot")
	bots_row.get_child(3).pressed.emit()
	_check(menu.bots() == 2 and bots_row.get_child(2).text == "2", "the > arrow adds a bot and shows it")
	await _free(menu)


func _test_fighter_rows() -> void:
	var menu := await _menu()
	menu.choose_mode(true)
	menu.set_counts(2, 1)
	for slot in 3:
		menu.set_look(slot, slot)
		menu.set_team(slot, 0)
	menu.open_setup()
	menu.next()
	menu.next()
	var rows: Array = menu.get_node("%Content").get_children()
	_check(rows.size() == 3, "one row per fighter (%d)" % rows.size())
	_check(rows[0].get_child(0).text == "P1" and rows[2].get_child(0).text == "BOT 1", "humans first, then bots")
	rows[1].get_child(4).pressed.emit()
	_check(menu.look(1) == 2 and rows[1].get_child(3).text == FighterLook.at(2).name, "> shows the next character")
	_check(rows[1].get_child(2).look == FighterLook.at(2), "and the preview wears it")
	rows[0].get_child(1).pressed.emit()
	_check(menu.look(0) == FighterLook.presets().size() - 1, "< wraps around the roster")
	rows[2].get_child(5).pressed.emit()
	_check(menu.team(2) == 1 and rows[2].get_child(5).text == "Rojo", "the team button cycles the teams")
	_check(rows[2].get_child(2).team_color == GameManager.TEAM_COLORS[1], "and marks the preview")
	await _free(menu)


func _test_teams_need_a_rival() -> void:
	var menu := await _menu()
	menu.choose_mode(false)
	menu.set_counts(2, 0)
	menu.set_team(0, 2)
	menu.set_team(1, 2)
	_check(not menu.teams_valid(), "everybody on one team leaves nobody to fight")
	menu.open_setup()
	menu.next()
	menu.next()
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
	menu.choose_mode(true)
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
	menu.choose_mode(false)
	menu.set_counts(3, 0)
	menu.set_rounds(3)
	for slot in 4:
		menu.set_team(slot, 0)
	menu.apply_selection()
	_check(gm.bot_difficulties.is_empty() and gm.match_size == 3 and gm.looks.size() == 3, "3 local players, no bots")
	_check(gm.teams == [0, 0, 0], "each on their own")
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
