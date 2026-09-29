extends SceneTree

## Headless tests for manual aim (Superfighters): holding block with a gun
## plants the fighter and aims, jump turns the aim up and crouch down,
## left/right picks the side, shots and rockets leave along the aim, and
## letting go of block resets it. Melee weapons still block.
## Run: godot --headless --path . -s scripts/weapons/test_aim.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const BAZOOKA := preload("res://scripts/weapons/data/bazooka.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_aim_up_and_shoot()
	await _test_aim_down_and_turn()
	await _test_release_resets()
	await _test_rocket_follows_aim()
	await _test_blade_still_blocks()
	print("OK: aim mode with guns, up/down/side aiming, shots and rockets along the aim, reset on release and blades still blocking verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


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


## A fighter holding `weapon`, playing `frames` after 20 idle frames.
func _fighter(stage: Node2D, weapon: WeaponData, frames: Array[InputFrame]) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(_hold(20) + frames)
	stage.add_child(player)
	await _frames(1)
	if weapon != null:
		player.weapons.equip(weapon)
	return player


func _projectiles(stage: Node) -> Array:
	return stage.find_children("*", "Projectile", true, false)


func _test_aim_up_and_shoot() -> void:
	var stage := _stage()
	var player: CharacterBody2D = await _fighter(stage, PISTOL, _hold(20, 0.0, InputFrame.BLOCK | InputFrame.JUMP)
			+ _hold(1, 0.0, InputFrame.BLOCK) + _hold(1, 0.0, InputFrame.BLOCK | InputFrame.ATTACK) + _hold(10, 0.0, InputFrame.BLOCK))
	await _frames(40)
	_check(player.is_aiming(), "block with a gun aims")
	_check(player.aim_angle() < -0.6, "jump turns the aim up (%.2f)" % player.aim_angle())
	_check(player.is_on_floor() and absf(player.velocity.y) < 1.0, "and doesn't jump")
	await process_frame
	_check(player.get_node("Visual").anim == FighterRig.Anim.AIM, "the rig aims")
	await _frames(3)
	var shots := _projectiles(stage)
	_check(shots.size() == 1, "attack fires while aiming (%d shots)" % shots.size())
	if shots.size() == 1:
		var v: Vector2 = shots[0].velocity
		_check(v.x > 0.0 and v.y < 0.0 and absf(v.angle() - player.aim_angle()) < 0.05,
				"the bullet leaves along the aim (%.2f vs %.2f)" % [v.angle(), player.aim_angle()])
	stage.queue_free()
	await process_frame


func _test_aim_down_and_turn() -> void:
	var stage := _stage()
	var player: CharacterBody2D = await _fighter(stage, PISTOL, _hold(15, 0.0, InputFrame.BLOCK | InputFrame.CROUCH)
			+ _hold(3, -1.0, InputFrame.BLOCK) + _hold(10, 0.0, InputFrame.BLOCK))
	var x := player.position.x
	await _frames(45)
	_check(player.aim_angle() > 0.4, "crouch turns the aim down (%.2f)" % player.aim_angle())
	_check(player.weapons.facing == -1, "left picks the left side")
	_check(absf(player.position.x - x) < 1.0 and not player.is_crouching(), "without walking or crouching")
	_check(player.weapons.aim_direction().x < 0.0 and player.weapons.aim_direction().y > 0.0,
			"so the weapon points down and left (%s)" % player.weapons.aim_direction())
	stage.queue_free()
	await process_frame


func _test_release_resets() -> void:
	var stage := _stage()
	var player: CharacterBody2D = await _fighter(stage, PISTOL, _hold(15, 0.0, InputFrame.BLOCK | InputFrame.JUMP)
			+ _hold(5) + _hold(10, 0.0, InputFrame.JUMP))
	await _frames(37)
	_check(not player.is_aiming() and player.aim_angle() == 0.0, "letting go of block stops aiming and resets the aim")
	await _frames(5)
	_check(not player.is_on_floor(), "and the fighter can jump again")
	stage.queue_free()
	await process_frame


func _test_rocket_follows_aim() -> void:
	var stage := _stage()
	var player: CharacterBody2D = await _fighter(stage, BAZOOKA, _hold(20, 0.0, InputFrame.BLOCK | InputFrame.JUMP)
			+ _hold(1, 0.0, InputFrame.BLOCK | InputFrame.ATTACK) + _hold(5, 0.0, InputFrame.BLOCK))
	await _frames(44)
	var rockets := stage.find_children("*", "Grenade", true, false)
	_check(rockets.size() == 1, "the bazooka fires while aiming")
	if rockets.size() == 1:
		var v: Vector2 = rockets[0].linear_velocity
		_check(v.y < -100.0 and v.x > 0.0, "the rocket flies up along the aim (%s)" % v)
	stage.queue_free()
	await process_frame


func _test_blade_still_blocks() -> void:
	var stage := _stage()
	var player: CharacterBody2D = await _fighter(stage, KATANA, _hold(20, 0.0, InputFrame.BLOCK))
	await _frames(35)
	_check(player.is_blocking() and not player.is_aiming(), "with a blade the button still blocks")
	stage.queue_free()
	await process_frame
