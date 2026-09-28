extends SceneTree

## Headless tests for the native-shape fighter (FighterRig, TASK-013 art):
## picking the animation from the fighter's state, the run cycle swinging
## legs and arms, every pose staying inside the 32x32 frame, the hit flash
## and the rig following a real player through run, jump, fall, crouch,
## punch, hurt and aiming a weapon.
## Run: godot --headless --path . -s scripts/test_fighter_rig.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const Anim := FighterRig.Anim
const FRAME := Rect2(-16, -32, 32, 32)

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_choose_anim()
	_test_run_cycle()
	_test_poses_fit_frame()
	_test_flash_and_color()
	await _test_follows_player()
	print("OK: animation choice, run cycle, 32x32 poses, hit flash and a live player's run/jump/fall/crouch/punch/hurt/aim verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _state(overrides := {}) -> Dictionary:
	var state := {"on_floor": true, "velocity": Vector2.ZERO, "crouching": false,
			"attacking": false, "hurt": false, "armed": false}
	state.merge(overrides, true)
	return state


func _test_choose_anim() -> void:
	_check(FighterRig.choose_anim(_state()) == Anim.IDLE, "standing still idles")
	_check(FighterRig.choose_anim(_state({"velocity": Vector2(140, 0)})) == Anim.RUN, "moving on the floor runs")
	_check(FighterRig.choose_anim(_state({"velocity": Vector2(5, 0)})) == Anim.IDLE, "drifting a few px/s still idles")
	_check(FighterRig.choose_anim(_state({"on_floor": false, "velocity": Vector2(0, -200)})) == Anim.JUMP, "rising jumps")
	_check(FighterRig.choose_anim(_state({"on_floor": false, "velocity": Vector2(0, 200)})) == Anim.FALL, "falling falls")
	_check(FighterRig.choose_anim(_state({"crouching": true})) == Anim.CROUCH, "crouching crouches")
	_check(FighterRig.choose_anim(_state({"attacking": true, "velocity": Vector2(140, 0)})) == Anim.ATTACK, "a punch wins over running")
	_check(FighterRig.choose_anim(_state({"hurt": true, "attacking": true})) == Anim.HURT, "getting hit wins over everything")
	_check(FighterRig.choose_anim(_state({"armed": true})) == Anim.AIM, "holding a weapon aims it")
	_check(FighterRig.choose_anim(_state({"armed": true, "velocity": Vector2(140, 0)})) == Anim.RUN, "armed fighters still run")


func _test_run_cycle() -> void:
	var a := FighterRig.pose(Anim.RUN, 0.1)
	var b := FighterRig.pose(Anim.RUN, 0.1 + FighterRig.RUN_PERIOD / 2.0)
	_check(signf(a.leg_front) == -signf(b.leg_front) and absf(a.leg_front) > 0.3, "legs swing back and forth (%.2f / %.2f)" % [a.leg_front, b.leg_front])
	_check(signf(a.arm_front) == -signf(a.leg_front), "arms swing against the legs")
	var idle_a := FighterRig.pose(Anim.IDLE, 0.0)
	var idle_b := FighterRig.pose(Anim.IDLE, 0.5)
	_check(idle_a.bob != idle_b.bob, "idle breathes")
	_check(FighterRig.pose(Anim.CROUCH, 0.0).hip_y > FighterRig.pose(Anim.IDLE, 0.0).hip_y, "crouching lowers the hips")
	_check(FighterRig.pose(Anim.ATTACK, 0.0).arm_front < -1.2, "a punch throws the front arm forward")
	var cheer := FighterRig.pose(Anim.VICTORY, 0.1)
	_check(cheer.arm_front < -2.0 and cheer.arm_back > 2.0, "a victory raises both arms")
	var hops := {}
	for i in 10:
		hops[FighterRig.pose(Anim.VICTORY, i * 0.05).bob] = true
	_check(hops.size() > 1, "a victory hops")
	_check(not Anim.VICTORY in [FighterRig.choose_anim(_state()), FighterRig.choose_anim(_state({"armed": true}))], "fighters only cheer when told to")


func _test_poses_fit_frame() -> void:
	for anim in Anim.values():
		for i in 24:
			var t := i * 0.05
			for part in FighterRig.parts(FighterRig.pose(anim, t), Color.RED):
				for point in part.points:
					if not FRAME.grow(0.01).has_point(point):
						_check(false, "%s at %.2f s: %s pokes out of the 32x32 frame at %s" % [Anim.keys()[anim], t, part.name, point])
						return
	var crouch_top := INF
	for part in FighterRig.parts(FighterRig.pose(Anim.CROUCH, 0.0), Color.RED):
		for point in part.points:
			crouch_top = minf(crouch_top, point.y)
	_check(crouch_top >= -20.0, "a crouching fighter is drawn low, like its hitbox (top %.1f)" % crouch_top)


func _test_flash_and_color() -> void:
	var rig := FighterRig.new()
	rig.color = Color("e43b44")
	var team := FighterRig.parts(FighterRig.pose(Anim.IDLE, 0.0), rig.color)
	_check(team.any(func(p): return p.color == rig.color), "the player colour is on the body")
	_check(team.any(func(p): return p.color != rig.color), "skin, pants and eye keep their own colours")
	var flashing := FighterRig.parts(FighterRig.pose(Anim.IDLE, 0.0), rig.color, true)
	_check(flashing.all(func(p): return p.color == Color.WHITE), "the hit flash whitens every part")
	rig.free()


func _player(frames: Array[InputFrame]) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(frames)
	return player


func _repeat(frames: Array[InputFrame], count: int, move := 0.0, buttons := 0) -> void:
	for i in count:
		frames.append(InputFrame.create(move, buttons))


func _test_follows_player() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(1200, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	stage.add_child(floor_body)

	var frames: Array[InputFrame] = []
	_repeat(frames, 20)
	_repeat(frames, 20, 1.0)
	_repeat(frames, 10, 0.0, InputFrame.JUMP)
	var player := _player(frames)
	stage.add_child(player)
	var rig: FighterRig = player.get_node("Visual")
	var seen := {}
	for i in 90:
		await process_frame
		await physics_frame
		seen[rig.anim] = true
	for anim in [Anim.IDLE, Anim.RUN, Anim.JUMP, Anim.FALL]:
		_check(seen.has(anim), "a live player goes through %s" % Anim.keys()[anim])

	frames = []
	_repeat(frames, 30, 0.0, InputFrame.CROUCH)
	player.input_source = ScriptedInputSource.new(frames)
	await _frames(10)
	_check(rig.anim == Anim.CROUCH, "holding down crouches the rig")
	await _frames(30)

	player.input_source = ScriptedInputSource.new([InputFrame.create(0.0, InputFrame.ATTACK)] as Array[InputFrame])
	await _frames(3)
	_check(rig.anim == Anim.ATTACK, "attacking swings the rig's arm")
	await _frames(30)

	player.get_node("Hurtbox").hit_received.emit(5, Vector2(-100, -50), null)
	await _frames(2)
	_check(rig.anim == Anim.HURT and rig.flash, "a hit flashes and staggers the rig")
	await _frames(40)
	_check(not rig.flash, "the flash ends with the invulnerability")

	player.weapons.equip(PISTOL)
	await _frames(20)
	_check(rig.anim == Anim.AIM, "holding a pistol aims it")
	stage.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame
