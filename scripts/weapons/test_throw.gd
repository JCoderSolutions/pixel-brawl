extends SceneTree

## Headless tests for empty guns and thrown weapons (Superfighters): a gun
## out of ammo stays in hand and only clicks, a spent grenade leaves the hand
## empty, pickup throws the weapon in hand at whoever is in front (never the
## thrower), thrown empty guns vanish after landing while loaded ones stay,
## and bots throw their empty guns.
## Run: godot --headless --path . -s scripts/weapons/test_throw.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")
const GRENADE := preload("res://scripts/weapons/data/grenade.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_empty_gun_stays_and_clicks()
	await _test_spent_grenade_leaves_the_hand()
	await _test_throw_hits_the_one_in_front()
	await _test_thrown_empty_gun_vanishes()
	await _test_bot_throws_empty_gun()
	print("OK: empty guns stay and click, spent grenades, thrown weapons hurt, empty throws vanish and bots throw empty guns verified" if _ok else "FAILED")
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


func _fighter(stage: Node2D, x: float, frames: Array[InputFrame] = []) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	if frames.is_empty():
		player.is_controlled = false
	else:
		player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return player


func _pickups(stage: Node) -> Array:
	return stage.get_children().filter(func(n): return n is WeaponPickup)


func _test_empty_gun_stays_and_clicks() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0)
	await _frames(5)
	var holder: WeaponHolder = player.weapons
	holder.equip(PISTOL, 1)
	var clicks := [0]
	holder.dry_fired.connect(func(_w): clicks[0] += 1)
	_check(holder.try_use(), "the last bullet fires")
	await _frames(30)
	_check(holder.has_weapon() and holder.weapon == PISTOL, "an empty pistol stays in hand")
	_check(holder.is_empty(), "and reads as empty")
	_check(not holder.try_use(), "pulling the trigger does nothing")
	_check(clicks[0] == 1, "but clicks (%d)" % clicks[0])
	stage.queue_free()
	await process_frame


func _test_spent_grenade_leaves_the_hand() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0)
	await _frames(5)
	player.weapons.equip(GRENADE, 1)
	player.weapons.try_use()
	_check(not player.weapons.has_weapon(), "the last grenade leaves the hand empty")
	stage.queue_free()
	await process_frame


func _test_throw_hits_the_one_in_front() -> void:
	var stage := _stage()
	var frames: Array[InputFrame] = []
	for i in 10:
		frames.append(InputFrame.new())
	frames.append(InputFrame.create(0.0, InputFrame.PICKUP))
	var thrower := _fighter(stage, 0, frames)
	var target := _fighter(stage, 90)
	await _frames(2)
	thrower.weapons.equip(KATANA)
	await _frames(40)
	_check(not thrower.weapons.has_weapon(), "pickup with nothing around throws the weapon")
	_check(target.health.current_health == target.health.max_health - KATANA.throw_damage,
			"the thrown katana hits the one in front for %d (hp %d)" % [KATANA.throw_damage, target.health.current_health])
	_check(thrower.health.current_health == thrower.health.max_health, "never the thrower")
	var lying := _pickups(stage)
	_check(lying.size() == 1 and lying[0].weapon == KATANA, "the katana ends up on the floor to grab again")
	await _frames(120)
	_check(_pickups(stage).size() == 1 and lying[0].is_in_group(WeaponPickup.GROUP), "and stays there")
	stage.queue_free()
	await process_frame


func _test_thrown_empty_gun_vanishes() -> void:
	var stage := _stage()
	var frames: Array[InputFrame] = []
	for i in 10:
		frames.append(InputFrame.new())
	frames.append(InputFrame.create(0.0, InputFrame.PICKUP))
	var thrower := _fighter(stage, 0, frames)
	await _frames(2)
	thrower.weapons.equip(PISTOL, 0)
	await _frames(20)
	var lying := _pickups(stage)
	_check(lying.size() == 1 and not lying[0].is_in_group(WeaponPickup.GROUP), "an empty gun can't be picked up again")
	await _frames(240)
	_check(_pickups(stage).is_empty(), "and vanishes after it lands")
	stage.queue_free()
	await process_frame


func _test_bot_throws_empty_gun() -> void:
	var stage := _stage()
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.HARD, 1)
	stage.add_child(bot)
	var target := _fighter(stage, 120)
	await _frames(2)
	bot.weapons.equip(PISTOL, 0)
	await _frames(90)
	_check(not bot.weapons.has_weapon(), "a bot throws its empty gun")
	_check(target.health.current_health < target.health.max_health, "at its opponent")
	stage.queue_free()
	await process_frame
