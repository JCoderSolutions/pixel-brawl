extends SceneTree

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_frame_encoding()
	_test_device_sources_are_isolated()
	_test_every_slot_has_bindings()
	await _test_players_read_own_slot()
	await _test_held_button_triggers_once()
	await _test_same_inputs_same_result()
	await _test_uncontrolled_ignores_source()
	print("OK: input frames, per-slot devices, per-player input, edge detection and determinism verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _test_frame_encoding() -> void:
	var frame := InputFrame.create(-0.5, InputFrame.JUMP | InputFrame.ATTACK)
	var decoded := InputFrame.decode(frame.encode())
	_check(decoded.equals(frame), "encode/decode round trip keeps axis and buttons")
	_check(decoded.is_held(InputFrame.JUMP) and decoded.is_held(InputFrame.ATTACK), "decoded buttons held")
	_check(not decoded.is_held(InputFrame.CROUCH), "crouch not held")
	_check(absf(decoded.move_x() + 0.5) < 0.01, "axis survives quantization (got %s)" % decoded.move_x())
	_check(InputFrame.create(3.0, 0).move_x() == 1.0, "axis clamps to 1")
	_check(InputFrame.decode(InputFrame.create(-1.0, InputFrame.CROUCH).encode()).move_x() == -1.0, "full left round trips")
	_check(InputFrame.new().encode() == 0, "neutral frame encodes to zero")


func _test_device_sources_are_isolated() -> void:
	var p1 := DeviceInputSource.new(1)
	var p2 := DeviceInputSource.new(2)
	Input.action_press("p2_move_right")
	Input.action_press("p2_attack")
	var f1 := p1.sample()
	var f2 := p2.sample()
	Input.action_release("p2_move_right")
	Input.action_release("p2_attack")
	_check(f1.move_x() == 0.0 and f1.buttons == 0, "slot 1 ignores slot 2 actions")
	_check(f2.move_x() == 1.0, "slot 2 reads its own move axis")
	_check(f2.is_held(InputFrame.ATTACK), "slot 2 reads its own attack")


func _test_every_slot_has_bindings() -> void:
	for slot in range(1, DeviceInputSource.MAX_SLOTS + 1):
		for action in DeviceInputSource.ACTIONS:
			var name := "p%d_%s" % [slot, action]
			_check(InputMap.has_action(name), "action %s exists" % name)
			if InputMap.has_action(name):
				_check(not InputMap.action_get_events(name).is_empty(), "action %s has bindings" % name)


## Builds a floor and `count` players side by side, each with a scripted source.
func _spawn_players(count: int) -> Array:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(4000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 25)
	arena.add_child(floor_body)

	var scene: PackedScene = load("res://scenes/characters/player.tscn")
	var players := []
	for i in count:
		var player = scene.instantiate()
		player.player_slot = i + 1
		player.position = Vector2(i * 400, 0)
		arena.add_child(player)
		players.append(player)
	return [arena] + players


func _test_players_read_own_slot() -> void:
	var spawned := _spawn_players(2)
	var p1 = spawned[1]
	var p2 = spawned[2]
	_check(p1.input_source is DeviceInputSource, "controlled player gets a device source by default")
	await _frames(5)
	var start1: float = p1.position.x
	var start2: float = p2.position.x

	Input.action_press("p1_move_right")
	await _frames(20)
	Input.action_release("p1_move_right")

	_check(p1.position.x > start1 + 10.0, "player 1 moved right (dx %s)" % (p1.position.x - start1))
	_check(is_equal_approx(p2.position.x, start2), "player 2 stayed put (dx %s)" % (p2.position.x - start2))
	spawned[0].queue_free()


func _test_held_button_triggers_once() -> void:
	var spawned := _spawn_players(1)
	var player = spawned[1]
	var held: Array[InputFrame] = []
	for i in 60:
		held.append(InputFrame.create(0.0, InputFrame.ATTACK))
	player.input_source = ScriptedInputSource.new(held)
	await _frames(3)
	_check(player.is_attacking(), "fresh attack press starts a swing")
	await _frames(40)
	_check(not player.is_attacking(), "holding attack does not chain swings")
	spawned[0].queue_free()


func _test_same_inputs_same_result() -> void:
	var script: Array[InputFrame] = []
	for i in 10:
		script.append(InputFrame.new())
	for i in 20:
		script.append(InputFrame.create(1.0, 0))
	for i in 3:
		script.append(InputFrame.create(1.0, InputFrame.JUMP))
	for i in 20:
		script.append(InputFrame.create(-0.4, 0))

	var spawned := _spawn_players(2)
	var a = spawned[1]
	var b = spawned[2]
	a.input_source = ScriptedInputSource.new(script)
	b.input_source = ScriptedInputSource.new(script)
	var origin_a: Vector2 = a.position
	var origin_b: Vector2 = b.position
	await _frames(script.size())

	var moved_a: Vector2 = a.position - origin_a
	var moved_b: Vector2 = b.position - origin_b
	_check(moved_a.x > 10.0, "scripted input moved the player (dx %s)" % moved_a.x)
	_check(moved_a.is_equal_approx(moved_b), "same inputs give same displacement (%s vs %s)" % [moved_a, moved_b])
	_check(a.velocity.is_equal_approx(b.velocity), "same inputs give same velocity")
	spawned[0].queue_free()


func _test_uncontrolled_ignores_source() -> void:
	var spawned := _spawn_players(1)
	var player = spawned[1]
	player.is_controlled = false
	var script: Array[InputFrame] = []
	for i in 20:
		script.append(InputFrame.create(1.0, InputFrame.ATTACK))
	player.input_source = ScriptedInputSource.new(script)
	await _frames(5)
	var start: float = player.position.x
	await _frames(15)
	_check(is_equal_approx(player.position.x, start), "uncontrolled player ignores input")
	_check(not player.is_attacking(), "uncontrolled player does not attack")
	spawned[0].queue_free()
