extends SceneTree

## The test arena must keep every fighter inside the 480x270 view.

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_player_cannot_leave(-1.0)
	await _test_player_cannot_leave(1.0)
	print("OK: arena walls keep players inside the view on both sides" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _test_player_cannot_leave(direction: float) -> void:
	var arena: Node2D = load("res://scenes/maps/test_arena.tscn").instantiate()
	var player = arena.get_node("Player")
	var frames: Array[InputFrame] = []
	for i in 300:
		# Keep running and hop now and then, like a player trying to escape.
		frames.append(InputFrame.create(direction, InputFrame.JUMP if i % 40 < 20 else 0))
	player.input_source = ScriptedInputSource.new(frames)
	root.add_child(arena)
	for i in 300:
		await physics_frame
	var view_width: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var half_width := 9.0
	var x: float = player.global_position.x
	_check(x >= half_width - 0.5 and x <= view_width - half_width + 0.5,
		"player ran %s and stayed in view (x = %.1f)" % ["left" if direction < 0 else "right", x])
	_check(player.global_position.y < 270.0, "player did not fall out of the arena")
	arena.queue_free()
	await physics_frame
