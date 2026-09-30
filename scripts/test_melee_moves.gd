extends SceneTree

## Headless tests for the Superfighters melee moves: three presses chain
## jab -> cross -> uppercut (the finisher launches), crouch + attack kicks,
## attack in the air kicks without breaking the jump, and pickup with empty hands grabs a rival
## who can be kneed, thrown (towards a held direction) or mash free.
## Run: godot --headless --path . -s scripts/test_melee_moves.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_combo_chains_into_uppercut()
	await _test_slow_presses_restart_the_combo()
	await _test_crouch_attack_kicks()
	await _test_air_attack_kicks()
	await _test_grab_knee_and_throw()
	await _test_throw_backwards()
	await _test_mash_free()
	print("OK: jab-cross-uppercut combo, combo reset, kick, air kick, grab with knees and throws, and breaking free verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Waits up to `limit` physics frames for `condition` to hold.
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


func _stage() -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(2000, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	stage.add_child(floor_body)
	return stage


## A fighter at `x` playing `frames` after 20 idle frames (to land).
## `face_left` turns it around first.
func _fighter(stage: Node2D, x: float, frames: Array[InputFrame], face_left := false) -> CharacterBody2D:
	var all := _hold(20)
	if face_left:
		all += _hold(1, -1.0) + _hold(1)
	all += frames
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	player.input_source = ScriptedInputSource.new(all)
	stage.add_child(player)
	return player


func _moves_seen(player: CharacterBody2D, frames: int) -> Array:
	var seen := []
	for i in frames:
		await physics_frame
		if player.is_attacking() and not player.attack_move() in seen:
			seen.append(player.attack_move())
	return seen


func _test_combo_chains_into_uppercut() -> void:
	var stage := _stage()
	var presses := _hold(1, 0.0, InputFrame.ATTACK) + _hold(9) + _hold(1, 0.0, InputFrame.ATTACK) \
			+ _hold(9) + _hold(1, 0.0, InputFrame.ATTACK) + _hold(60)
	var attacker := _fighter(stage, 0, presses)
	var target := _fighter(stage, 20, _hold(200))
	await _frames(20)
	var hits := [0]
	target.get_node("Hurtbox").hit_received.connect(func(_d, _k, _s): hits[0] += 1)
	var launch := [0.0]
	target.get_node("Hurtbox").hit_received.connect(func(_d, k, _s): launch[0] = minf(launch[0], k.y))
	var seen: Array = await _moves_seen(attacker, 80)
	_check(seen == [&"jab", &"cross", &"uppercut"], "three presses chain jab, cross, uppercut (%s)" % [seen])
	_check(hits[0] == 3, "every punch of the combo lands (%d)" % hits[0])
	_check(launch[0] <= -300.0, "the uppercut launches the rival (%.0f)" % launch[0])
	var lost: int = target.health.max_health - target.health.current_health
	_check(lost > 30, "the combo hits harder than three jabs (%d)" % lost)
	stage.queue_free()
	await process_frame


func _test_slow_presses_restart_the_combo() -> void:
	var stage := _stage()
	var presses := _hold(1, 0.0, InputFrame.ATTACK) + _hold(60) + _hold(1, 0.0, InputFrame.ATTACK) + _hold(40)
	var attacker := _fighter(stage, 0, presses)
	await _frames(20)
	var seen: Array = await _moves_seen(attacker, 100)
	_check(seen == [&"jab"], "a press after the combo window is a new jab (%s)" % [seen])
	stage.queue_free()
	await process_frame


func _test_crouch_attack_kicks() -> void:
	var stage := _stage()
	var attacker := _fighter(stage, 0, _hold(4, 0.0, InputFrame.CROUCH) + _hold(1, 0.0, InputFrame.CROUCH | InputFrame.ATTACK) + _hold(40, 0.0, InputFrame.CROUCH))
	var target := _fighter(stage, 22, _hold(100))
	await _frames(20)
	var push := [0.0]
	target.get_node("Hurtbox").hit_received.connect(func(_d, k, _s): push[0] = k.x)
	var seen: Array = await _moves_seen(attacker, 40)
	_check(seen == [&"kick"], "crouch + attack kicks (%s)" % [seen])
	_check(push[0] >= 250.0, "the kick shoves the rival away (%.0f)" % push[0])
	await process_frame
	stage.queue_free()
	await process_frame


func _test_air_attack_kicks() -> void:
	var stage := _stage()
	var attacker := _fighter(stage, 0, _hold(6, 0.0, InputFrame.JUMP) + _hold(1, 0.0, InputFrame.ATTACK) + _hold(60))
	var kicked: bool = await _until(func(): return attacker.is_attacking(), 40)
	_check(kicked and not attacker.is_on_floor() and attacker.attack_move() == &"air_kick", "attack in the air kicks")
	await _frames(3)
	_check(absf(attacker.velocity.x) < 1.0 and attacker.velocity.y < 0.0,
			"without lunging: the jump keeps rising in place (%s)" % attacker.velocity)
	stage.queue_free()
	await process_frame


func _test_grab_knee_and_throw() -> void:
	var stage := _stage()
	var knees := _hold(1, 0.0, InputFrame.ATTACK) + _hold(20)
	var grabber := _fighter(stage, 0, _hold(1, 0.0, InputFrame.PICKUP) + _hold(10) + knees + knees + _hold(1, 0.0, InputFrame.PICKUP) + _hold(60))
	var victim := _fighter(stage, 20, _hold(200))
	var grabbed: bool = await _until(func(): return grabber.is_grabbing(), 30)
	_check(grabbed and victim.is_held(), "pickup with empty hands grabs the rival in front")
	await process_frame
	_check(victim.get_node("Visual").anim == FighterRig.Anim.HELD and grabber.get_node("Visual").anim == FighterRig.Anim.GRAB,
			"the rig shows the grab")
	var hp: int = victim.health.current_health
	await _frames(40)
	_check(grabber.is_grabbing(), "still holding after two knees")
	_check(victim.health.current_health < hp, "knees hurt the held rival (%d -> %d)" % [hp, victim.health.current_health])
	var thrown: bool = await _until(func(): return not grabber.is_grabbing(), 20)
	_check(thrown and not victim.is_held(), "pickup throws the rival")
	_check(victim.velocity.x > 200.0 and victim.velocity.y < 0.0, "forward and up (%s)" % victim.velocity)
	await _frames(40)
	_check(victim.position.x - grabber.position.x > 60.0, "the rival lands far away (%.0f px)" % (victim.position.x - grabber.position.x))
	stage.queue_free()
	await process_frame


func _test_throw_backwards() -> void:
	var stage := _stage()
	var grabber := _fighter(stage, 0, _hold(1, 0.0, InputFrame.PICKUP) + _hold(5) + _hold(1, -1.0, InputFrame.PICKUP) + _hold(40))
	var victim := _fighter(stage, 20, _hold(200))
	await _until(func(): return grabber.is_grabbing(), 30)
	await _until(func(): return not grabber.is_grabbing(), 30)
	_check(victim.velocity.x < -200.0, "holding back while throwing throws behind (%s)" % victim.velocity)
	stage.queue_free()
	await process_frame


func _test_mash_free() -> void:
	var stage := _stage()
	var grabber := _fighter(stage, 0, _hold(1, 0.0, InputFrame.PICKUP) + _hold(120))
	var mash: Array[InputFrame] = _hold(2)
	for i in 8:
		mash += _hold(1, 0.0, InputFrame.JUMP) + _hold(1)
	var victim := _fighter(stage, 20, mash + _hold(100))
	var grabbed: bool = await _until(func(): return victim.is_held(), 30)
	_check(grabbed, "grabbed")
	var free: bool = await _until(func(): return not victim.is_held(), 30)
	_check(free and not grabber.is_grabbing(), "mashing buttons breaks free")
	_check(grabber.is_in_hitstun(), "and leaves the grabber reeling")
	stage.queue_free()
	await process_frame
