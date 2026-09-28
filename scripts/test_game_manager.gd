extends SceneTree

## Headless tests for the match flow: rounds, respawn, kill zone, draws,
## match end, HUD bindings, winner screen and main menu.
## Run: godot --headless --path . -s scripts/test_game_manager.gd

const GameManagerScript := preload("res://scripts/autoload/game_manager.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const WinnerScene := preload("res://scenes/ui/winner_screen.tscn")
const MenuScene := preload("res://scenes/ui/main_menu.tscn")

const SPAWNS: Array[Vector2] = [Vector2(-100, 0), Vector2(100, 0)]

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_match_starts_with_spawned_players()
	await _test_round_win_and_next_round()
	await _test_match_end()
	await _test_draw()
	await _test_respawn_with_lives()
	await _test_kill_zone()
	await _test_rematch_resets_scores()
	await _test_hud_and_winner_screen()
	await _test_main_menu()
	print("OK: match start, rounds, next round respawn, match end, draw, lives respawn, kill zone, rematch, HUD, winner screen and menu verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


## Arena with a floor and a manager driven manually through `advance()`,
## with short delays so every transition is deterministic.
func _make_match(lives := 1, rounds_to_win := 2) -> Array:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(1000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)

	var manager = GameManagerScript.new()
	manager.set_process(false)
	manager.round_start_delay = 0.1
	manager.round_end_grace = 0.1
	manager.round_end_delay = 0.1
	manager.respawn_delay = 0.1
	manager.lives_per_round = lives
	manager.rounds_to_win = rounds_to_win
	manager.kill_zone_y = 500.0
	root.add_child(manager)
	manager.setup(arena, SPAWNS)
	return [arena, manager]


func _teardown(m: Array) -> void:
	m[1].teardown()
	m[1].queue_free()
	m[0].queue_free()
	await process_frame


func _step(manager, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		manager.advance(0.05)
		t += 0.05


func _kill(manager, id: int) -> void:
	var p = manager.get_player(id)
	p.health.take_damage(p.health.current_health)


func _test_match_starts_with_spawned_players() -> void:
	var m := _make_match()
	var manager = m[1]
	var started := [0]
	manager.round_started.connect(func(_n): started[0] += 1)
	manager.start_match()
	_check(manager.get_player_ids() == [0, 1], "two players spawned")
	_check(manager.get_player(0).position == SPAWNS[0], "P1 at its spawn point")
	_check(manager.get_player(1).position == SPAWNS[1], "P2 at its spawn point")
	_check(manager.get_player(0).is_controlled, "P1 reads input")
	_check(not manager.get_player(1).is_controlled, "P2 is a dummy until local 2P lands")
	_check(manager.state == manager.State.ROUND_STARTING, "round begins with a countdown")
	_check(manager.current_round == 1, "first round is 1")
	_step(manager, 0.2)
	_check(manager.state == manager.State.FIGHTING, "countdown ends in FIGHTING")
	_check(started[0] == 1, "round_started emitted once")
	await _teardown(m)


func _test_round_win_and_next_round() -> void:
	var m := _make_match()
	var manager = m[1]
	var winners := []
	manager.round_ended.connect(func(w): winners.append(w))
	manager.start_match()
	_step(manager, 0.2)
	var old_p2 = manager.get_player(1)
	old_p2.position = Vector2(300, 0)
	_kill(manager, 1)
	_check(manager.state == manager.State.FIGHTING, "grace window lets trades resolve before ending")
	_step(manager, 0.2)
	_check(winners == [0], "P1 wins the round (got %s)" % [winners])
	_check(manager.scores[0] == 1 and manager.scores[1] == 0, "score 1-0")
	_check(manager.state == manager.State.ROUND_OVER, "round over pause")
	_step(manager, 0.2)
	await process_frame
	_check(manager.current_round == 2, "second round started")
	var new_p2 = manager.get_player(1)
	_check(not is_instance_valid(old_p2), "dead body cleared on new round")
	_check(new_p2.health.current_health == new_p2.health.max_health, "P2 back at full health")
	_check(new_p2.position == SPAWNS[1], "P2 back at spawn")
	await _teardown(m)


func _test_match_end() -> void:
	var m := _make_match()
	var manager = m[1]
	var match_winner := [-99]
	manager.match_ended.connect(func(w): match_winner[0] = w)
	manager.start_match()
	for i in 2:
		_step(manager, 0.2)
		_kill(manager, 1)
		_step(manager, 0.2)
		if i == 0:
			_step(manager, 0.2)
	_check(match_winner[0] == 0, "P1 wins the match at 2 rounds (got %d)" % match_winner[0])
	_check(manager.state == manager.State.MATCH_OVER, "state MATCH_OVER")
	_step(manager, 1.0)
	_check(manager.current_round == 2, "no further rounds after the match ends")
	await _teardown(m)


func _test_draw() -> void:
	var m := _make_match()
	var manager = m[1]
	var winners := []
	manager.round_ended.connect(func(w): winners.append(w))
	manager.start_match()
	_step(manager, 0.2)
	_kill(manager, 0)
	_step(manager, 0.05)
	_kill(manager, 1)
	_step(manager, 0.2)
	_check(winners == [manager.NO_WINNER], "a trade inside the grace window is a draw (got %s)" % [winners])
	_check(manager.scores[0] == 0 and manager.scores[1] == 0, "draw scores nobody")
	await _teardown(m)


func _test_respawn_with_lives() -> void:
	var m := _make_match(2)
	var manager = m[1]
	var respawned := []
	manager.player_spawned.connect(func(id, _p): respawned.append(id))
	manager.start_match()
	_step(manager, 0.2)
	respawned.clear()
	var first = manager.get_player(1)
	_kill(manager, 1)
	_check(manager.lives[1] == 1, "losing a life leaves one")
	_step(manager, 0.2)
	await process_frame
	_check(manager.state == manager.State.FIGHTING, "round continues while lives remain")
	_check(respawned == [1], "P2 respawned once (got %s)" % [respawned])
	var second = manager.get_player(1)
	_check(second != first and not second.health.is_dead(), "fresh P2 instance is alive")
	_check(second.position == SPAWNS[1], "respawn uses the spawn point")
	_kill(manager, 1)
	_step(manager, 0.2)
	_check(manager.state == manager.State.ROUND_OVER, "out of lives ends the round")
	_check(manager.scores[0] == 1, "P1 scores")
	await _teardown(m)


func _test_kill_zone() -> void:
	var m := _make_match()
	var manager = m[1]
	manager.start_match()
	_step(manager, 0.2)
	manager.get_player(1).position = Vector2(0, 600)
	_step(manager, 0.05)
	_check(manager.get_player(1).health.is_dead(), "falling below kill_zone_y kills")
	await _teardown(m)


func _test_rematch_resets_scores() -> void:
	var m := _make_match(1, 1)
	var manager = m[1]
	manager.start_match()
	_step(manager, 0.2)
	_kill(manager, 1)
	_step(manager, 0.2)
	_check(manager.state == manager.State.MATCH_OVER, "one-round match ends")
	manager.start_match()
	await process_frame
	_check(manager.scores == [0, 0], "rematch resets scores")
	_check(manager.current_round == 1, "rematch restarts at round 1")
	_check(manager.get_player_ids() == [0, 1], "rematch respawns both players")
	await _teardown(m)


func _test_hud_and_winner_screen() -> void:
	var m := _make_match(1, 1)
	var manager = m[1]
	var hud = HudScene.instantiate()
	var winner = WinnerScene.instantiate()
	hud.manager = manager
	winner.manager = manager
	root.add_child(hud)
	root.add_child(winner)
	manager.start_match()
	await process_frame
	_check(hud.get_bar(0) != null and hud.get_bar(1) != null, "HUD shows one bar per player")
	_check(hud.get_bar(1).value == 100.0, "bar starts full")
	_check(not winner.visible, "winner screen hidden during play")
	_check(hud.banner_text() == "RONDA 1", "banner announces the round (got '%s')" % hud.banner_text())
	_step(manager, 0.2)
	manager.get_player(1).health.take_damage(30)
	_check(hud.get_bar(1).value == 70.0, "bar follows damage (got %s)" % hud.get_bar(1).value)
	_kill(manager, 1)
	_step(manager, 0.2)
	_check(hud.score_text(0) == "1", "HUD score updates (got '%s')" % hud.score_text(0))
	_check(winner.visible, "winner screen appears on match end")
	_check(winner.title_text() == "¡P1 GANA!", "winner screen names P1 (got '%s')" % winner.title_text())
	var rig: FighterRig = winner.get_node("%WinnerRig")
	_check(rig.anim == FighterRig.Anim.VICTORY, "the winner cheers on the winner screen")
	_check(rig.color == manager.PLAYER_COLORS[0], "in the winner's colour")
	var cheer_time := rig.anim_time
	await process_frame
	await process_frame
	_check(rig.anim_time > cheer_time, "the cheer is animated")
	winner.rematch()
	await process_frame
	_check(not winner.visible, "rematch hides the winner screen")
	_check(manager.state == manager.State.ROUND_STARTING, "rematch starts a new match")
	_check(hud.get_bar(1).value == 100.0, "HUD rebinds to the respawned player")
	hud.queue_free()
	winner.queue_free()
	await _teardown(m)


func _test_main_menu() -> void:
	var menu = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("%PlayButton") is Button, "menu has a Play button")
	_check(menu.get_node("%QuitButton") is Button, "menu has a Quit button")
	_check(ResourceLoader.exists(menu.match_scene), "Play points to an existing match scene")
	menu.queue_free()
	await process_frame
