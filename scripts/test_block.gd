extends SceneTree

## Headless tests for blocking (Superfighters): the block button (the old
## fire button) plants the fighter, stops hits from the front but not from
## behind, doesn't stop bullets, and with a metal blade (katana) a block
## started right before a bullet lands sends it back at the shooter.
## Run: godot --headless --path . -s scripts/test_block.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")
const BAT := preload("res://scripts/weapons/data/bat.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_block_plants_and_poses()
	await _test_block_stops_front_hits_only()
	await _test_block_does_not_stop_bullets()
	await _test_katana_parry_returns_bullets()
	await _test_late_or_wooden_blocks_do_not_parry()
	print("OK: block plants the fighter, stops front hits only, not bullets, and a timely katana block returns bullets verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _stage() -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(1200, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	stage.add_child(floor_body)
	return stage


## `frames`: what the fighter does after 10 idle frames. `face_left` turns it
## around first (one frame of walking left).
func _fighter(stage: Node2D, x: float, frames: Array[InputFrame], face_left := false) -> CharacterBody2D:
	var all: Array[InputFrame] = []
	for i in 10:
		all.append(InputFrame.new())
	if face_left:
		all.append(InputFrame.create(-1.0, 0))
		all.append(InputFrame.new())
	all.append_array(frames)
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	player.input_source = ScriptedInputSource.new(all)
	stage.add_child(player)
	return player


func _hold(count: int, move := 0.0, buttons := 0) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(move, buttons))
	return frames


func _test_block_plants_and_poses() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0, _hold(40, 1.0, InputFrame.BLOCK))
	await _frames(20)
	player.weapons.equip(PISTOL)
	var ammo: int = player.weapons.ammo
	var x := player.position.x
	await _frames(20)
	_check(player.is_blocking(), "holding the block button blocks")
	_check(absf(player.position.x - x) < 2.0, "a blocking fighter stands still (moved %.1f)" % (player.position.x - x))
	_check(player.weapons.ammo == ammo, "the block button doesn't shoot any more")
	await process_frame
	_check(player.get_node("Visual").anim == FighterRig.Anim.BLOCK, "the rig raises its guard")
	stage.queue_free()
	await process_frame


## A punch from the front bounces off the guard; the same punch in the back hurts.
func _test_block_stops_front_hits_only() -> void:
	for from_front in [true, false]:
		var stage := _stage()
		var blocker := _fighter(stage, 0, _hold(60, 0.0, InputFrame.BLOCK), not from_front)
		var attacker := _fighter(stage, 22, _hold(8) + _hold(1, 0.0, InputFrame.ATTACK) + _hold(30), true)
		var blocked := [0]
		blocker.get_node("Hurtbox").blocked.connect(func(_kind): blocked[0] += 1)
		await _frames(60)
		var hurt: bool = blocker.health.current_health < blocker.health.max_health
		if from_front:
			_check(not hurt and blocked[0] == 1, "a punch from the front is blocked (hp %d)" % blocker.health.current_health)
		else:
			_check(hurt and blocked[0] == 0, "a punch in the back still hurts (hp %d)" % blocker.health.current_health)
		stage.queue_free()
		await process_frame


func _shoot_at(stage: Node2D, from_x: float, target: CharacterBody2D) -> CharacterBody2D:
	var shooter := _fighter(stage, from_x, _hold(12) + _hold(1, 0.0, InputFrame.ATTACK) + _hold(60), true)
	await _frames(1)
	shooter.weapons.equip(PISTOL)
	return shooter


func _test_block_does_not_stop_bullets() -> void:
	var stage := _stage()
	var blocker := _fighter(stage, 0, _hold(80, 0.0, InputFrame.BLOCK))
	await _shoot_at(stage, 150, blocker)
	await _frames(60)
	_check(blocker.health.current_health == blocker.health.max_health - PISTOL.damage,
			"bullets go through an empty-handed guard (hp %d)" % blocker.health.current_health)
	stage.queue_free()
	await process_frame


## The shooter fires on frame ~25 (10 idle, 2 to turn around, 12 more) and
## the pistol bullet (700 px/s) needs ~11 frames to cover the gap, so a
## block pressed on frame 30 is ~6 frames old when it lands.
func _test_katana_parry_returns_bullets() -> void:
	var stage := _stage()
	var blocker := _fighter(stage, 0, _hold(20) + _hold(40, 0.0, InputFrame.BLOCK))
	var shooter := await _shoot_at(stage, 150, blocker)
	blocker.weapons.equip(KATANA)
	var deflected := [0]
	blocker.get_node("Hurtbox").blocked.connect(func(kind): if kind == &"bullet": deflected[0] += 1)
	await _frames(70)
	_check(deflected[0] == 1, "a fresh katana block deflects the bullet")
	_check(blocker.health.current_health == blocker.health.max_health, "the blocker is unharmed (hp %d)" % blocker.health.current_health)
	_check(shooter.health.current_health == shooter.health.max_health - PISTOL.damage,
			"the bullet goes back into the shooter (hp %d)" % shooter.health.current_health)
	stage.queue_free()
	await process_frame


func _test_late_or_wooden_blocks_do_not_parry() -> void:
	for case in ["late katana", "bat"]:
		var stage := _stage()
		var frames := _hold(80, 0.0, InputFrame.BLOCK) if case == "late katana" else _hold(20) + _hold(40, 0.0, InputFrame.BLOCK)
		var blocker := _fighter(stage, 0, frames)
		var shooter := await _shoot_at(stage, 150, blocker)
		blocker.weapons.equip(KATANA if case == "late katana" else BAT)
		await _frames(70)
		_check(blocker.health.current_health == blocker.health.max_health - PISTOL.damage,
				"%s: the bullet hits (hp %d)" % [case, blocker.health.current_health])
		_check(shooter.health.current_health == shooter.health.max_health, "%s: nothing comes back" % case)
		stage.queue_free()
		await process_frame
