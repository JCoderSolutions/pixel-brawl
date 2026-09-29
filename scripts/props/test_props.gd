extends SceneTree

## Headless tests for map props (Superfighters): an explosive barrel blows up
## after a few punches or a bullet, hurts and burns the fighters around it,
## sets off the barrels next to it and credits whoever hit it; supply crates
## fall from the sky, hurt whoever they land on and drop their weapon when
## broken; and a map puts its barrels back every round.
## Run: godot --headless --path . -s scripts/props/test_props.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const BARREL_SCENE := preload("res://scenes/props/explosive_barrel.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_punches_blow_up_a_barrel()
	await _test_bullet_sets_off_a_chain()
	await _test_crate_falls_and_breaks_open()
	await _test_crate_lands_on_a_head()
	await _test_map_resets_its_barrels()
	print("OK: barrels blow up from punches and bullets, burn, chain and credit the attacker; crates fall, crush and drop weapons; maps reset their barrels verified" if _ok else "FAILED")
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


func _fighter(stage: Node2D, at: Vector2, frames: Array[InputFrame] = []) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = at
	if frames.is_empty():
		player.is_controlled = false
	else:
		player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return player


## Flag set once `node` leaves the tree (a lambda can't hold a freed node).
func _gone(node: Node) -> Array:
	var flag := [false]
	node.tree_exited.connect(func(): flag[0] = true)
	return flag


func _barrel(stage: Node2D, x: float) -> ExplosiveBarrel:
	var barrel: ExplosiveBarrel = BARREL_SCENE.instantiate()
	barrel.position = Vector2(x, 0)
	stage.add_child(barrel)
	return barrel


func _test_punches_blow_up_a_barrel() -> void:
	var stage := _stage()
	var punches := _hold(5)
	for i in 5:
		punches += _hold(1, 0.0, InputFrame.ATTACK) + _hold(20)
	var puncher := _fighter(stage, Vector2(-20, 0), punches)
	var barrel := _barrel(stage, 0)
	var bystander := _fighter(stage, Vector2(30, 0))
	var credited := [null]
	barrel.broken.connect(func(source): credited[0] = source)
	var barrel_gone := _gone(barrel)
	var blew: bool = await _until(func(): return barrel_gone[0], 150)
	_check(blew, "a few punches set the barrel off")
	_check(credited[0] == puncher, "the one who hit it gets the credit")
	await _frames(2)
	_check(bystander.health.current_health < bystander.health.max_health - 20, "the blast hurts fighters nearby (hp %d)" % bystander.health.current_health)
	_check(Burning.of(bystander).is_burning() or bystander.health.is_dead(), "and sets the closest on fire")
	stage.queue_free()
	await process_frame


func _test_bullet_sets_off_a_chain() -> void:
	var stage := _stage()
	var shooter := _fighter(stage, Vector2(-120, 0))
	var first := _barrel(stage, 0)
	var second := _barrel(stage, 40)
	var far := _barrel(stage, 200)
	var first_gone := _gone(first)
	var second_gone := _gone(second)
	var far_gone := _gone(far)
	await _frames(10)
	var holder: WeaponHolder = shooter.weapons
	holder.equip(PISTOL)
	for i in 3:
		holder.try_use()
		await _frames(int(PISTOL.cooldown * 60) + 2)
	var chained: bool = await _until(func(): return first_gone[0] and second_gone[0], 60)
	_check(chained, "shots blow up a barrel and its blast sets off the next one")
	_check(not far_gone[0], "a barrel out of reach stays")
	stage.queue_free()
	await process_frame


func _test_crate_falls_and_breaks_open() -> void:
	var stage := _stage()
	var spawner := WeaponSpawner.new()
	spawner.weapons = [PISTOL] as Array[WeaponData]
	spawner.autostart = false
	spawner.position = Vector2(0, -2)
	stage.add_child(spawner)
	await _frames(2)
	var crate := spawner.drop_crate()
	_check(crate != null and crate.global_position.y < -150.0, "a crate appears high above the point")
	var landed: bool = await _until(func(): return crate.global_position.y > -1.0 and crate.is_on_floor(), 180)
	_check(landed, "and falls onto the floor (y %.1f)" % crate.global_position.y)
	spawner.max_crates = 1
	_check(spawner.drop_crate() == null, "no more than max_crates at once")
	crate.get_node("Hurtbox").receive_hit(25, Vector2.ZERO, null)
	await _frames(3)
	var pickups := stage.get_children().filter(func(n): return n is WeaponPickup)
	_check(not is_instance_valid(crate) and pickups.size() == 1 and pickups[0].weapon == PISTOL, "breaking it drops its weapon")
	stage.queue_free()
	await process_frame


func _test_crate_lands_on_a_head() -> void:
	var stage := _stage()
	var victim := _fighter(stage, Vector2(0, 0))
	var crate: SupplyCrate = preload("res://scenes/props/supply_crate.tscn").instantiate()
	crate.position = Vector2(0, -150)
	stage.add_child(crate)
	var hit: bool = await _until(func(): return victim.health.current_health < victim.health.max_health, 90)
	_check(hit and victim.health.current_health == victim.health.max_health - crate.crush_damage, "a falling crate hurts the fighter it lands on")
	stage.queue_free()
	await process_frame


func _test_map_resets_its_barrels() -> void:
	# Loaded at run time: map scripts use the GameManager autoload.
	var map: Node2D = load("res://scenes/maps/lab.tscn").instantiate()
	map.autostart = false
	root.add_child(map)
	await _frames(5)
	var barrels := func(): return map.get_tree().get_nodes_in_group(BreakableProp.GROUP).filter(func(p): return p is ExplosiveBarrel and not p.is_queued_for_deletion())
	var start: int = barrels.call().size()
	_check(start >= 2, "the lab has barrels (%d)" % start)
	var first: ExplosiveBarrel = barrels.call()[0]
	var spot := first.position
	first.get_node("Hurtbox").receive_hit(100, Vector2.ZERO, null)
	await _frames(5)
	_check(barrels.call().size() < start, "a barrel blows up")
	map.reset_props()
	await _frames(2)
	var after: Array = barrels.call()
	_check(after.size() == start, "a new round puts every barrel back (%d)" % after.size())
	_check(after.any(func(b): return b.position.distance_to(spot) < 1.0 and b.health.current_health == b.health.max_health), "in its place and whole")
	map.queue_free()
	await process_frame
