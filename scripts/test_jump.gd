extends SceneTree

## Headless tests for the jump feel (Superfighters style): holding jump goes
## the full height, letting go early cuts it short, falling is faster than
## rising, knockback launches are never cut, a 6-tile drop stays harmless and
## bots hold the button so their jumps keep full height.
## Run: godot --headless --path . -s scripts/test_jump.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const FLOOR_Y := 0.0

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var full := await _jump(30)
	var tap := await _jump(3)
	_check(full.apex >= 50.0, "holding jump reaches full height (%.1f px)" % full.apex)
	_check(tap.apex < full.apex * 0.6, "a tapped jump is a short hop (%.1f vs %.1f px)" % [tap.apex, full.apex])
	_check(tap.apex >= 12.0, "a tapped jump still leaves the ground (%.1f px)" % tap.apex)
	_check(full.fall_frames < full.rise_frames * 0.9,
			"falling is faster than rising (%d vs %d frames)" % [full.fall_frames, full.rise_frames])
	await _test_launch_is_not_cut()
	await _test_six_tile_drop_is_safe()
	print("OK: full and short jumps, faster fall, uncut launches and safe 6-tile drop verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _stage() -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(800, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, FLOOR_Y + 10)
	stage.add_child(floor_body)
	return stage


func _settle(player: CharacterBody2D) -> void:
	for i in 30:
		await physics_frame
	_check(player.is_on_floor(), "player starts on the floor")


## Jumps holding the button for `hold` frames; returns the apex height and
## how many frames the rise and the fall took.
func _jump(hold: int) -> Dictionary:
	var stage := _stage()
	var frames: Array[InputFrame] = []
	for i in 30:
		frames.append(InputFrame.new())
	for i in hold:
		frames.append(InputFrame.create(0.0, InputFrame.JUMP))
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	await _settle(player)
	var ground := player.position.y
	var top := ground
	var rise := 0
	var fall := 0
	for i in 120:
		await physics_frame
		if player.velocity.y < 0.0:
			rise += 1
		elif not player.is_on_floor():
			fall += 1
		top = minf(top, player.position.y)
		if i > 5 and player.is_on_floor():
			break
	stage.queue_free()
	await process_frame
	return {"apex": ground - top, "rise_frames": rise, "fall_frames": fall}


## Explosions and hits set velocity directly: letting go of jump (or never
## pressing it) must not shorten them.
func _test_launch_is_not_cut() -> void:
	var stage := _stage()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.is_controlled = false
	stage.add_child(player)
	await _settle(player)
	var ground := player.position.y
	player.velocity.y = -400.0
	var top := ground
	for i in 90:
		await physics_frame
		top = minf(top, player.position.y)
	var expected: float = 400.0 * 400.0 / (2.0 * player.gravity)
	_check(ground - top > expected * 0.9, "a launch keeps its height (%.1f of %.1f px)" % [ground - top, expected])
	stage.queue_free()
	await process_frame


## Maps and bots rely on drops of up to 6 tiles (96 px) being free.
func _test_six_tile_drop_is_safe() -> void:
	var stage := _stage()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.is_controlled = false
	player.position = Vector2(0, FLOOR_Y - 96)
	stage.add_child(player)
	for i in 60:
		await physics_frame
	_check(player.is_on_floor(), "player lands after a 6-tile drop")
	_check(player.health.current_health == player.health.max_health,
			"a 6-tile drop is harmless (hp %d)" % player.health.current_health)
	stage.queue_free()
	await process_frame
