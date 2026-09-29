extends SceneTree

## Headless tests for Superfighters movement: double-tapping a direction
## sprints, falling into a wall at hand height hangs from its edge (jump
## climbs, pushing away lets go), and crouching just before a hard landing
## rolls out of it without fall damage.
## Run: godot --headless --path . -s scripts/test_mobility.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_double_tap_sprints()
	await _test_hang_and_climb()
	await _test_push_away_lets_go()
	await _test_recovery_roll()
	print("OK: double-tap sprint, ledge hang and climb, letting go, and recovery roll verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _until(condition: Callable, limit := 60) -> bool:
	for i in limit:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _hold(count: int, move := 0.0, buttons := 0) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(move, buttons))
	return frames


func _box(stage: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	body.position = rect.get_center()
	stage.add_child(body)


## Floor top at y = 0; `wall` (optional) is another solid box.
func _stage(wall := Rect2()) -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	_box(stage, Rect2(-1000, 0, 2000, 20))
	if wall.has_area():
		_box(stage, wall)
	return stage


func _fighter(stage: Node2D, at: Vector2, frames: Array[InputFrame]) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = at
	player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return player


func _top_speed(player: CharacterBody2D, frames: int) -> float:
	var top := 0.0
	for i in frames:
		await physics_frame
		top = maxf(top, absf(player.velocity.x))
	return top


func _test_double_tap_sprints() -> void:
	var stage := _stage()
	var walker := _fighter(stage, Vector2(0, 0), _hold(10) + _hold(40, 1.0))
	var sprinter := _fighter(stage, Vector2(0, 0), _hold(10) + _hold(4, 1.0) + _hold(4) + _hold(80, 1.0))
	var speeds := [await _top_speed(walker, 60)]
	_check(not walker.is_sprinting() and speeds[0] <= walker.run_speed + 1.0, "holding a direction runs (%.0f)" % speeds[0])
	_check(sprinter.velocity.x > sprinter.run_speed * 1.3, "a double tap sprints (%.0f)" % sprinter.velocity.x)
	stage.queue_free()
	await process_frame


## A 70 px high block from x 60, too high to jump onto: jumping against its
## face catches the edge on the way down.
func _test_hang_and_climb() -> void:
	var stage := _stage(Rect2(60, -70, 80, 70))
	var player := _fighter(stage, Vector2(30, 0), _hold(10, 1.0) + _hold(20, 1.0, InputFrame.JUMP) + _hold(30, 1.0) \
			+ _hold(1, 1.0, InputFrame.JUMP) + _hold(60, 1.0))
	var hung: bool = await _until(func(): return player.is_hanging(), 60)
	_check(hung, "falling into a wall at hand height hangs from its edge")
	if hung:
		_check(absf(player.position.y - (-70.0 + player.HANG_REACH)) < 1.0, "the hands sit on the edge (feet at %.1f)" % player.position.y)
		var y := player.position.y
		await _frames(10)
		_check(player.is_hanging() and absf(player.position.y - y) < 0.1, "and stays there")
		await process_frame
		_check(player.get_node("Visual").anim == FighterRig.Anim.HANG, "the rig hangs")
	var climbed: bool = await _until(func(): return player.is_on_floor() and player.position.y < -69.0, 80)
	_check(climbed and player.position.x > 60.0, "jump climbs onto the block (%s)" % player.position)
	stage.queue_free()
	await process_frame


func _test_push_away_lets_go() -> void:
	var stage := _stage(Rect2(60, -70, 80, 70))
	var player := _fighter(stage, Vector2(30, 0), _hold(10, 1.0) + _hold(20, 1.0, InputFrame.JUMP) + _hold(30, 1.0) + _hold(40, -1.0))
	await _until(func(): return player.is_hanging(), 60)
	var let_go: bool = await _until(func(): return not player.is_hanging(), 30)
	_check(let_go, "pushing away lets go")
	await _frames(30)
	_check(player.is_on_floor() and absf(player.position.y) < 1.0, "and drops to the floor (%s)" % player.position)
	stage.queue_free()
	await process_frame


## Falling 200 px lands at ~710 px/s: that hurts, unless crouch was pressed
## right before touching down.
func _test_recovery_roll() -> void:
	for roll in [false, true]:
		var stage := _stage()
		var frames := _hold(30)
		frames += _hold(10, 0.0, InputFrame.CROUCH) if roll else _hold(10)
		var player := _fighter(stage, Vector2(0, -200), frames + _hold(40))
		var rolled := false
		for i in 60:
			await physics_frame
			rolled = rolled or player.is_rolling()
		var hurt: bool = player.health.current_health < player.health.max_health
		if roll:
			_check(rolled and not hurt, "crouch before landing rolls out of the fall (rolled %s, hp %d)" % [rolled, player.health.current_health])
		else:
			_check(hurt and not rolled, "the same fall hurts without it (hp %d)" % player.health.current_health)
		stage.queue_free()
		await process_frame
