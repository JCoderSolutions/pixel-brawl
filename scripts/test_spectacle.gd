extends SceneTree

## Headless tests for the round's spectacle: the manager counts kills,
## deaths and deaths by the map, the round-deciding death is announced as a
## final blow, GameFeel slows time for it (a hit-stop inside doesn't cut it
## short), the camera closes in on it, and the standings show between rounds
## and on the winner screen.
## Run: godot --headless --path . -s scripts/test_spectacle.gd

const GameManagerScript := preload("res://scripts/autoload/game_manager.gd")
const GameFeelScript := preload("res://scenes/effects/game_feel.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const WinnerScene := preload("res://scenes/ui/winner_screen.tscn")

const SPAWNS: Array[Vector2] = [Vector2(-100, 0), Vector2(0, 0), Vector2(100, 0)]

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_kills_and_deaths()
	await _test_final_blow()
	await _test_slow_motion()
	await _test_camera_close_up()
	await _test_scoreboard_between_rounds()
	print("OK: kills, deaths and map kills counted, final blow announced, slow motion with hit-stop, camera close-up and standings between rounds and at the end verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _make_match(rounds_to_win := 2) -> Array:
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


func _kill(manager, id: int, by: int = -1) -> void:
	var p = manager.get_player(id)
	var source = manager.get_player(by) if by >= 0 else null
	p.health.take_damage(p.health.current_health, source)


func _fight(manager) -> void:
	manager.start_match()
	_step(manager, 0.2)


func _test_kills_and_deaths() -> void:
	var m := _make_match()
	var manager = m[1]
	var changes := [0]
	manager.stats_changed.connect(func(): changes[0] += 1)
	_fight(manager)
	_kill(manager, 1, 0)
	_kill(manager, 2)
	_check(manager.kills == [1, 0, 0], "P1 gets the kill (%s)" % [manager.kills])
	_check(manager.deaths == [0, 1, 1], "both victims count a death (%s)" % [manager.deaths])
	_check(manager.environment_kills == 1, "a death with no killer goes to the map")
	_check(changes[0] == 2, "each death reports the stats")
	_step(manager, 0.5)
	_kill(manager, 0, 0)
	_check(manager.environment_kills == 2 and manager.kills[0] == 1, "killing yourself is a map kill, not a kill")
	manager.start_match()
	_check(manager.kills == [0, 0, 0] and manager.deaths == [0, 0, 0] and manager.environment_kills == 0, "a rematch clears the stats")
	await _teardown(m)


func _test_final_blow() -> void:
	var m := _make_match()
	var manager = m[1]
	var blows := []
	manager.final_blow.connect(func(victim, killer, at): blows.append([victim, killer, at]))
	_fight(manager)
	_kill(manager, 1, 2)
	_check(blows.is_empty(), "a death with two sides left isn't the final blow")
	var at: Vector2 = manager.get_player(2).global_position
	_kill(manager, 2, 0)
	_check(blows.size() == 1 and blows[0][0] == 2 and blows[0][1] == 0, "the round-deciding kill is the final blow (%s)" % [blows])
	_check(blows.size() == 1 and blows[0][2] == at, "at the victim's position")
	await _teardown(m)


func _test_slow_motion() -> void:
	var feel = GameFeelScript.new()
	root.add_child(feel)
	feel.final_blow(Vector2.ZERO)
	_check(feel.is_slow_motion() and is_equal_approx(Engine.time_scale, feel.final_blow_scale), "the final blow slows time")
	feel.hit_stop(0.05)
	_check(is_equal_approx(Engine.time_scale, feel.hit_stop_scale), "a hit-stop freezes harder")
	feel.advance_real(0.06)
	_check(is_equal_approx(Engine.time_scale, feel.final_blow_scale), "and hands back to the slow motion")
	feel.advance_real(feel.final_blow_time)
	_check(not feel.is_slow_motion() and Engine.time_scale == 1.0, "normal speed once it's over")
	feel.final_blow(Vector2.ZERO)
	feel.queue_free()
	await process_frame
	_check(Engine.time_scale == 1.0, "leaving the tree never leaves time slowed")


func _test_camera_close_up() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var camera := SharedCamera.new()
	camera.bounds = Rect2(-1000, -1000, 2000, 2000)
	camera.pixel_perfect_zoom = false
	stage.add_child(camera)
	var a := Node2D.new()
	a.position = Vector2(-150, 0)
	var b := Node2D.new()
	b.position = Vector2(150, 0)
	stage.add_child(a)
	stage.add_child(b)
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	var wide: float = camera.zoom.x
	camera.focus_on(b.position, 1.6, 0.3)
	for i in 12:
		camera.advance(1.0 / 60.0)
	_check(camera.zoom.x > wide * 1.3, "the close-up zooms in (%.2f -> %.2f)" % [wide, camera.zoom.x])
	_check(camera.global_position.distance_to(b.position + camera.focus_offset) < 20.0, "on the victim (%s)" % camera.global_position)
	for i in 180:
		camera.advance(1.0 / 60.0)
	_check(not camera.is_focusing() and absf(camera.zoom.x - wide) < 0.05, "then goes back to framing everyone (%.2f)" % camera.zoom.x)
	stage.queue_free()
	await process_frame


func _test_scoreboard_between_rounds() -> void:
	var m := _make_match(1)
	var manager = m[1]
	var hud = HudScene.instantiate()
	hud.manager = manager
	root.add_child(hud)
	var winner = WinnerScene.instantiate()
	winner.manager = manager
	root.add_child(winner)
	manager.rounds_to_win = 2
	_fight(manager)
	_check(not hud.scoreboard.visible, "no standings while fighting")
	_kill(manager, 0, 2)
	_kill(manager, 1, 2)
	_step(manager, 0.15)
	var board: Scoreboard = hud.scoreboard
	_check(board.visible, "the standings show when the round ends")
	_check(board.cell_text(0, 2) == "KILLS", "with a kills column")
	_check(board.cell_text(1, 0) == "1. P3" and board.cell_text(1, 1) == "1" and board.cell_text(1, 2) == "2",
			"the round winner leads with their kills (%s %s %s)" % [board.cell_text(1, 0), board.cell_text(1, 1), board.cell_text(1, 2)])
	_step(manager, 0.2)
	_check(not board.visible, "and hide when the next round starts")
	_kill(manager, 0)
	_kill(manager, 1, 2)
	_step(manager, 0.15)
	_check(winner.visible and winner.scoreboard.cell_text(1, 0) == "1. P3", "the winner screen shows the final standings")
	_check(winner.scoreboard.footer_text().contains("1"), "with the deaths by the map (%s)" % winner.scoreboard.footer_text())
	hud.queue_free()
	winner.queue_free()
	await _teardown(m)
