extends SceneTree

## Headless tests for characters and teams (Superfighters Versus): the
## character presets, a spawned fighter wearing its look and team, rounds
## decided by the last team standing (every member scores), free-for-all
## unchanged, labels for the HUD and winner screen, and bots that leave
## their teammates alone.
## Run: godot --headless --path . -s scripts/test_teams.gd

const GameManagerScript := preload("res://scripts/autoload/game_manager.gd")
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const SPAWNS: Array[Vector2] = [Vector2(-150, 0), Vector2(-50, 0), Vector2(50, 0), Vector2(150, 0)]

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_presets()
	await _test_spawn_wears_look_and_team()
	await _test_last_team_standing_wins()
	await _test_free_for_all_unchanged()
	await _test_bots_spare_teammates()
	print("OK: character presets, looks and teams on spawn, last team standing, free-for-all, labels and bots sparing teammates verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _test_presets() -> void:
	var presets := FighterLook.presets()
	_check(presets.size() >= 8, "at least 8 characters to pick (%d)" % presets.size())
	var names := {}
	var shirts := {}
	for look in presets:
		names[look.name] = true
		shirts[look.shirt.to_html()] = true
	_check(names.size() == presets.size() and shirts.size() == presets.size(), "every character has its own name and shirt")
	for id in 4:
		_check(presets[id].shirt == GameManagerScript.PLAYER_COLORS[id], "character %d keeps P%d's classic colour" % [id, id + 1])


func _match(teams: Array[int], looks: Array[int] = []) -> Array:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(1000, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)
	var manager = GameManagerScript.new()
	manager.set_process(false)
	manager.round_start_delay = 0.1
	manager.round_end_grace = 0.1
	manager.round_end_delay = 0.1
	manager.rounds_to_win = 2
	manager.teams = teams
	manager.looks = looks
	root.add_child(manager)
	manager.setup(arena, SPAWNS)
	manager.start_match()
	_step(manager, 0.2)
	return [arena, manager]


func _step(manager, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		manager.advance(0.05)
		t += 0.05


func _kill(manager, id: int) -> void:
	var p = manager.get_player(id)
	p.health.take_damage(p.health.current_health)


func _done(m: Array) -> void:
	m[1].teardown()
	m[1].queue_free()
	m[0].queue_free()
	await process_frame


func _test_spawn_wears_look_and_team() -> void:
	var m := _match([1, 1, 2, 2], [4, 5, 6, 7])
	var manager = m[1]
	var p2 = manager.get_player(1)
	var rig: FighterRig = p2.get_node("Visual")
	_check(p2.team == 1, "a spawned fighter knows its team")
	_check(rig.look == FighterLook.presets()[5], "and wears the chosen character")
	_check(rig.color == FighterLook.presets()[5].shirt, "in that character's shirt")
	_check(rig.team_color == GameManagerScript.TEAM_COLORS[1], "with its team's marker")
	_check(manager.player_color(1) == FighterLook.presets()[5].shirt, "the HUD colour follows the character")
	_check(manager.side_label(1) == "EQUIPO ROJO" and manager.side_label(3) == "EQUIPO AZUL", "teams read by colour name")
	await _done(m)


func _test_last_team_standing_wins() -> void:
	var m := _match([1, 1, 2, 2])
	var manager = m[1]
	var winners := []
	manager.round_ended.connect(func(w): winners.append(w))
	_kill(manager, 0)
	_step(manager, 0.3)
	_check(winners.is_empty(), "one fighter down on each side... not yet: both teams still stand")
	_kill(manager, 2)
	_step(manager, 0.3)
	_check(winners.is_empty(), "one left per team: the round goes on")
	_kill(manager, 3)
	_step(manager, 0.3)
	_check(winners.size() == 1 and manager.team_of(winners[0]) == 1, "the last team standing wins the round")
	_check(manager.scores[0] == 1 and manager.scores[1] == 1, "every member scores, the fallen one too (%s)" % [manager.scores])
	_check(manager.scores[2] == 0 and manager.scores[3] == 0, "the losing team doesn't")
	await _done(m)


func _test_free_for_all_unchanged() -> void:
	var m := _match([])
	var manager = m[1]
	var winners := []
	manager.round_ended.connect(func(w): winners.append(w))
	for id in [0, 1, 2]:
		_kill(manager, id)
		_step(manager, 0.3)
	_check(winners == [3], "without teams the last fighter standing wins (%s)" % [winners])
	_check(manager.scores[3] == 1 and manager.scores[0] == 0, "and only they score")
	_check(manager.side_label(3) == "P4", "labelled by player")
	await _done(m)


func _test_bots_spare_teammates() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.team = 1
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.HARD, 1)
	arena.add_child(bot)
	var mate: CharacterBody2D = PLAYER_SCENE.instantiate()
	mate.is_controlled = false
	mate.team = 1
	mate.position = Vector2(30, 0)
	arena.add_child(mate)
	var foe: CharacterBody2D = PLAYER_SCENE.instantiate()
	foe.is_controlled = false
	foe.team = 2
	foe.position = Vector2(200, 0)
	arena.add_child(foe)
	var targets: Array = bot.input_source.opponents_provider.call()
	_check(foe in targets and not mate in targets, "a bot fights the other team and spares its teammate")
	arena.queue_free()
	await process_frame
