extends SceneTree

## Headless tests for the attack button (Superfighters style): unarmed it
## punches, with a gun it shoots (held for automatic weapons), with a blade
## or a bat it swings the weapon instead of punching; the old fire button
## still works.
## Run: godot --headless --path . -s scripts/test_controls.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const RIFLE := preload("res://scripts/weapons/data/assault_rifle.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_unarmed_attack_punches()
	await _test_attack_fires_a_gun()
	await _test_attack_holds_automatic_fire()
	await _test_attack_swings_a_blade()
	await _test_fire_button_still_fires()
	print("OK: attack punches unarmed, fires guns (held for automatics), swings blades, and fire still fires verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


## A player on a floor that plays `frames` after settling, holding `weapon`.
func _player(weapon: WeaponData, frames: Array[InputFrame]) -> CharacterBody2D:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(1000, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	stage.add_child(floor_body)
	var settle: Array[InputFrame] = []
	for i in 10:
		settle.append(InputFrame.new())
	settle.append_array(frames)
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(settle)
	stage.add_child(player)
	if weapon != null:
		player.weapons.equip(weapon)
	return player


func _press(button: int, count := 1) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(0.0, button))
	return frames


func _run(player: CharacterBody2D, count: int) -> Dictionary:
	var seen := {"shots": 0, "punched": false, "swung": false}
	player.weapons.fired.connect(func(weapon: WeaponData, _n: int) -> void:
		if weapon.is_ranged():
			seen.shots += 1
		else:
			seen.swung = true)
	for i in count:
		await physics_frame
		if player.is_attacking():
			seen.punched = true
	return seen


func _done(player: CharacterBody2D) -> void:
	player.get_parent().queue_free()
	await process_frame


func _test_unarmed_attack_punches() -> void:
	var player := _player(null, _press(InputFrame.ATTACK))
	var seen := await _run(player, 20)
	_check(seen.punched, "attack punches with empty hands")
	await _done(player)


func _test_attack_fires_a_gun() -> void:
	var player := _player(PISTOL, _press(InputFrame.ATTACK))
	var ammo: int = player.weapons.ammo
	var seen := await _run(player, 20)
	_check(seen.shots == 1, "attack shoots the pistol (%d shots)" % seen.shots)
	_check(player.weapons.ammo == ammo - 1, "and spends a bullet")
	_check(not seen.punched, "no punch while holding a gun")
	await _done(player)


func _test_attack_holds_automatic_fire() -> void:
	var player := _player(RIFLE, _press(InputFrame.ATTACK, 40))
	var seen := await _run(player, 55)
	_check(seen.shots >= 4, "holding attack keeps the rifle firing (%d shots)" % seen.shots)
	await _done(player)


func _test_attack_swings_a_blade() -> void:
	var player := _player(KATANA, _press(InputFrame.ATTACK))
	var seen := await _run(player, 20)
	_check(seen.swung, "attack swings the katana")
	_check(not seen.punched, "instead of punching")
	await _done(player)


func _test_fire_button_still_fires() -> void:
	var player := _player(PISTOL, _press(InputFrame.FIRE))
	var seen := await _run(player, 20)
	_check(seen.shots == 1, "the fire button still shoots")
	await _done(player)
