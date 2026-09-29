extends SceneTree

## Headless tests for fire (Superfighters): a burning fighter loses health
## until the flames die out, rolling puts them out, touching a burning
## fighter spreads them, a fire pit keeps you burning after you leave it, a
## molotov sets the fighter it hits on fire and leaves a burning puddle that
## burns out, and a burning bot dives to put itself out.
## Run: godot --headless --path . -s scripts/hazards/test_fire.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const MOLOTOV := preload("res://scripts/weapons/data/molotov.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_burning_hurts_then_dies_out()
	await _test_rolling_puts_it_out()
	await _test_fire_spreads_on_contact()
	await _test_fire_pit_keeps_burning()
	await _test_molotov_spills_fire()
	await _test_bot_rolls_out_of_fire()
	print("OK: burning damage, rolling out, spreading, fire pits, molotov puddles and bots putting out fire verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


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


## Floor top at y = 0.
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


func _fighter(stage: Node2D, x: float, frames: Array[InputFrame] = []) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	if frames.is_empty():
		player.is_controlled = false
	else:
		player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return player


func _fire_zones(stage: Node) -> Array:
	return stage.get_children().filter(func(n): return n is HazardZone and n.lifetime > 0.0)


func _test_burning_hurts_then_dies_out() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0)
	await _frames(5)
	var burning := Burning.of(player)
	_check(burning != null, "fighters can burn")
	burning.ignite(2.0)
	_check(burning.is_burning(), "ignite sets them on fire")
	await _frames(60)
	var lost: int = player.health.max_health - player.health.current_health
	_check(lost >= 7 and lost <= 9, "fire takes about 8 hp per second (%d)" % lost)
	var out: bool = await _until(func(): return not burning.is_burning(), 70)
	_check(out, "the flames die out after their time")
	var hp: int = player.health.current_health
	await _frames(30)
	_check(player.health.current_health == hp, "and stop hurting")
	stage.queue_free()
	await process_frame


func _test_rolling_puts_it_out() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0, _hold(10) + _hold(20, 1.0) + _hold(1, 1.0, InputFrame.CROUCH) + _hold(40, 1.0))
	await _frames(5)
	var burning := Burning.of(player)
	burning.ignite(5.0)
	var out: bool = await _until(func(): return not burning.is_burning(), 60)
	_check(out and (player.is_diving() or player.is_rolling()), "diving and rolling smother the flames")
	stage.queue_free()
	await process_frame


func _test_fire_spreads_on_contact() -> void:
	var stage := _stage()
	var torch := _fighter(stage, 0)
	var near := _fighter(stage, 10)
	var far := _fighter(stage, 120)
	await _frames(5)
	Burning.of(torch).ignite(4.0, torch)
	var caught: bool = await _until(func(): return Burning.of(near).is_burning(), 30)
	_check(caught, "a fighter touching a burning one catches fire")
	_check(Burning.of(near).time_left() < Burning.of(torch).time_left() + 0.01, "for less time than the source")
	_check(not Burning.of(far).is_burning(), "one far away doesn't")
	stage.queue_free()
	await process_frame


func _test_fire_pit_keeps_burning() -> void:
	var stage := _stage()
	var pit := HazardZone.new()
	pit.kind = HazardZone.Kind.FIRE
	pit.size = Vector2(32, 16)
	pit.position = Vector2(-16, -16)
	stage.add_child(pit)
	var player := _fighter(stage, 0, _hold(4) + _hold(60, 1.0))
	await _frames(40)
	_check(player.position.x > 40.0, "walked out of the pit (x %.0f)" % player.position.x)
	_check(Burning.of(player).is_burning(), "still burning after leaving the pit")
	stage.queue_free()
	await process_frame


func _test_molotov_spills_fire() -> void:
	var stage := _stage()
	var thrower := _fighter(stage, 0)
	var target := _fighter(stage, 70)
	await _frames(5)
	var holder: WeaponHolder = thrower.weapons
	holder.equip(MOLOTOV)
	_check(holder.try_use(), "the molotov is thrown")
	var hit: bool = await _until(func(): return not _fire_zones(stage).is_empty(), 90)
	_check(hit, "it shatters and leaves a burning puddle")
	if hit:
		var fire: HazardZone = _fire_zones(stage)[0]
		_check(absf(fire.global_position.y + fire.size.y) < 1.0, "the puddle lies on the floor (bottom %.1f)" % (fire.global_position.y + fire.size.y))
		_check(fire.is_in_group(HazardZone.GROUP), "bots see the puddle as a hazard")
		_check(fire.source == thrower, "the thrower gets the kills")
		await _frames(10)
		_check(Burning.of(target).is_burning(), "the fighter it hit is on fire")
		_check(not Burning.of(thrower).is_burning(), "the thrower isn't")
		var gone: bool = await _until(func(): return _fire_zones(stage).is_empty(), 60 * 6)
		_check(gone, "the puddle burns out")
	_check(not holder.has_weapon() or holder.ammo == MOLOTOV.max_ammo - 1, "a bottle leaves the hand when used")
	stage.queue_free()
	await process_frame


func _test_bot_rolls_out_of_fire() -> void:
	var stage := _stage()
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.position = Vector2(0, 0)
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.NORMAL, 3)
	stage.add_child(bot)
	await _frames(5)
	var burning := Burning.of(bot)
	burning.ignite(6.0)
	var dove := [false]
	var out: bool = await _until(func():
		dove[0] = dove[0] or bot.is_diving() or bot.is_rolling()
		return not burning.is_burning(), 120)
	_check(out and dove[0], "a burning bot dives to put itself out")
	stage.queue_free()
	await process_frame
