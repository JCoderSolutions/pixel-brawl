extends SceneTree

## Headless tests for rocket riding (Superfighters): a bazooka rocket that
## hits a fighter carries them away instead of exploding, the rider steers it
## with left/right, and when it finally hits a wall or another fighter it
## blows up, killing the rider and hurting whoever is close; it never picks
## up its shooter and a ride that hits nothing ends on its own.
## Run: godot --headless --path . -s scripts/weapons/test_rocket_ride.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const BAZOOKA := preload("res://scripts/weapons/data/bazooka.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_hit_mounts_the_target()
	await _test_rider_steers()
	await _test_ride_ends_in_a_blast()
	await _test_ride_times_out()
	await _test_bot_rider_turns_on_the_shooter()
	print("OK: rocket hits mount the target, riders steer, rides end in a lethal blast and time out, and a bot rider turns it on the shooter verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _stage(wall_x := INF) -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	_body(stage, Rect2(-600, 0, 2400, 20))
	if wall_x != INF:
		_body(stage, Rect2(wall_x, -200, 16, 200))
	return stage


func _body(stage: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	body.position = rect.get_center()
	stage.add_child(body)


func _fighter(stage: Node2D, x: float, frames: Array[InputFrame] = []) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	if frames.is_empty():
		player.is_controlled = false
	else:
		player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return player


func _fire(shooter: CharacterBody2D) -> Array:
	var rockets := []
	shooter.get_parent().child_entered_tree.connect(func(node):
		if node is Grenade:
			rockets.append(node))
	shooter.weapons.equip(BAZOOKA)
	shooter.weapons.try_use()
	return rockets


func _test_hit_mounts_the_target() -> void:
	var stage := _stage()
	var shooter := _fighter(stage, 0)
	var target := _fighter(stage, 150)
	await _frames(3)
	var rockets := _fire(shooter)
	# ~20 frames to cover the gap at 420 px/s, then 20 more of riding.
	await _frames(40)
	_check(rockets.size() == 1 and is_instance_valid(rockets[0]), "a direct hit doesn't blow the rocket up")
	_check(target.is_riding(), "it carries the target away")
	_check(target.global_position.x > 200.0, "the rider moves with the rocket (x %.0f)" % target.global_position.x)
	_check(not shooter.is_riding(), "the shooter never mounts their own rocket")
	await process_frame
	_check(target.get_node("Visual").anim == FighterRig.Anim.RIDE, "the rig rides it")
	stage.queue_free()
	await process_frame


func _test_rider_steers() -> void:
	var stage := _stage()
	var shooter := _fighter(stage, 0)
	var steer: Array[InputFrame] = []
	for i in 120:
		steer.append(InputFrame.create(1.0 if i > 20 else 0.0, 0))
	var target := _fighter(stage, 150, steer)
	await _frames(3)
	var rockets := _fire(shooter)
	for i in 60:
		await physics_frame
		if target.is_riding():
			break
	_check(target.is_riding() and rockets.size() == 1 and is_instance_valid(rockets[0]), "riding")
	# 8 frames at 3 rad/s: about 0.4 rad, before it dives into the floor.
	await _frames(8)
	if rockets.size() == 1 and is_instance_valid(rockets[0]):
		var angle: float = rockets[0].linear_velocity.angle()
		_check(angle > 0.25, "holding right turns the rocket clockwise (%.2f rad)" % angle)
	stage.queue_free()
	await process_frame


func _test_ride_ends_in_a_blast() -> void:
	var stage := _stage(420.0)
	var shooter := _fighter(stage, 0)
	var target := _fighter(stage, 150)
	var bystander := _fighter(stage, 395)
	await _frames(3)
	var blasts := []
	stage.child_entered_tree.connect(func(node):
		if node is Explosion:
			blasts.append(node))
	_fire(shooter)
	await _frames(90)
	_check(blasts.size() == 1, "the ride ends in one explosion (%d)" % blasts.size())
	_check(target.health.is_dead(), "the rider doesn't survive it")
	_check(not target.is_riding(), "and is off the rocket")
	_check(bystander.health.current_health < bystander.health.max_health, "whoever is close gets caught in the blast")
	_check(shooter.health.current_health == shooter.health.max_health, "the shooter far away is fine")
	stage.queue_free()
	await process_frame


func _test_bot_rider_turns_on_the_shooter() -> void:
	var stage := _stage()
	var shooter := _fighter(stage, 0)
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.position = Vector2(150, 0)
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.HARD, 3)
	stage.add_child(bot)
	await _frames(3)
	_fire(shooter)
	await _frames(35)
	_check(bot.is_riding(), "the bot got hit and rides")
	await _frames(150)
	# The blast tops out at the bazooka's damage: it hurts, it doesn't one-shot.
	_check(shooter.health.current_health <= shooter.health.max_health - 30,
			"a riding bot turns the rocket back into its shooter (hp %d)" % shooter.health.current_health)
	_check(bot.health.is_dead(), "and goes down with it")
	stage.queue_free()
	await process_frame


func _test_ride_times_out() -> void:
	var stage := _stage()
	var shooter := _fighter(stage, 0)
	var target := _fighter(stage, 150)
	await _frames(3)
	var rockets := _fire(shooter)
	await _frames(35)
	_check(target.is_riding(), "riding into open space")
	await _frames(roundi(Grenade.RIDE_TIME * 60.0) + 20)
	_check(rockets.is_empty() or not is_instance_valid(rockets[0]), "a ride that hits nothing ends on its own")
	_check(target.health.is_dead(), "with a bang")
	stage.queue_free()
	await process_frame
