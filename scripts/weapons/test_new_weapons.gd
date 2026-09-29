extends SceneTree

## Headless tests for the second batch of weapons: assault rifle (automatic),
## sawed-off shotgun, bat and bazooka (rocket that blows up on contact and
## breaks the map), plus WeaponHolder.damage_multiplier.
## Run: godot --headless --path . -s scripts/weapons/test_new_weapons.gd

const RIFLE := preload("res://scripts/weapons/data/assault_rifle.tres")
const SAWED_OFF := preload("res://scripts/weapons/data/sawed_off.tres")
const SHOTGUN := preload("res://scripts/weapons/data/shotgun.tres")
const BAT := preload("res://scripts/weapons/data/bat.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")
const BAZOOKA := preload("res://scripts/weapons/data/bazooka.tres")
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const SPAWNER_SCENE := preload("res://scenes/items/weapon_spawner.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_data()
	await _test_rifle_is_automatic()
	await _test_sawed_off_blast()
	await _test_bat_launches()
	await _test_bazooka_hits_fighter()
	await _test_bazooka_hits_wall()
	await _test_bazooka_ignores_shooter()
	await _test_damage_multiplier()
	print("OK: new weapon data, automatic rifle, sawed-off, bat, bazooka on fighters/walls/shooter and damage multiplier verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Floor top at y = 0.
func _make_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(1200, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)
	return arena


func _add_player(arena: Node2D, x: float) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.is_controlled = false
	player.position = Vector2(x, 0)
	arena.add_child(player)
	return player


func _hold_fire(ticks: int) -> ScriptedInputSource:
	var frames: Array[InputFrame] = []
	for i in ticks:
		frames.append(InputFrame.create(0.0, InputFrame.ATTACK))
	return ScriptedInputSource.new(frames)


func _test_data() -> void:
	_check(RIFLE.automatic and RIFLE.is_ranged() and RIFLE.max_ammo >= 20, "rifle: automatic with a big magazine")
	_check(SAWED_OFF.projectiles_per_shot > SHOTGUN.projectiles_per_shot and SAWED_OFF.projectile_range < SHOTGUN.projectile_range,
			"sawed-off: more pellets, shorter reach than the shotgun")
	_check(not BAT.is_ranged() and BAT.knockback.length() > KATANA.knockback.length() and BAT.damage < KATANA.damage,
			"bat: melee that hits softer but launches harder than the katana")
	_check(BAZOOKA is GrenadeData and BAZOOKA.explode_on_contact and BAZOOKA.gravity_scale == 0.0, "bazooka: straight rocket")
	var spawner: WeaponSpawner = SPAWNER_SCENE.instantiate()
	for data in [RIFLE, SAWED_OFF, BAT, BAZOOKA]:
		_check(data in spawner.weapons, "%s is in the default spawner pool" % data.id)
	spawner.free()


func _test_rifle_is_automatic() -> void:
	var arena := _make_arena()
	var shooter := _add_player(arena, 0)
	var target := _add_player(arena, 150)
	shooter.weapons.equip(RIFLE)
	await _frames(2)
	var shots := [0]
	shooter.weapons.fired.connect(func(_data, _count): shots[0] += 1)
	shooter.is_controlled = true
	shooter.input_source = _hold_fire(30)
	await _frames(40)
	# 0.5 s held at 0.1 s cooldown: about five shots from one press.
	_check(shots[0] >= 4, "holding fire keeps shooting (%d shots)" % shots[0])
	_check(shooter.weapons.ammo == RIFLE.max_ammo - shots[0], "every shot spends a bullet")
	_check(target.health.current_health < 100, "rifle bullets land")
	arena.queue_free()
	await _frames(1)


func _test_sawed_off_blast() -> void:
	var arena := _make_arena()
	var shooter := _add_player(arena, 0)
	var near := _add_player(arena, 40)
	shooter.weapons.equip(SAWED_OFF)
	await _frames(2)
	shooter.weapons.try_use()
	await _frames(10)
	# One pellet per hit window: the target is invulnerable right after the first.
	_check(near.health.current_health < 100, "sawed-off hits up close")
	_check(near.velocity.x > 100.0, "sawed-off shoves hard")
	await _frames(40)
	shooter.weapons.try_use()
	_check(not shooter.weapons.has_weapon(), "two shells and it's spent")
	arena.queue_free()
	await _frames(1)


func _test_bat_launches() -> void:
	var arena := _make_arena()
	var batter := _add_player(arena, 0)
	var target := _add_player(arena, 18)
	batter.weapons.equip(BAT)
	await _frames(2)
	var knockbacks := []
	target.get_node("Hurtbox").hit_received.connect(func(_damage, knockback, _source): knockbacks.append(knockback))
	batter.weapons.try_use()
	await _frames(12)
	_check(target.health.current_health == 100 - BAT.damage, "bat deals its damage (got %d)" % target.health.current_health)
	_check(knockbacks.size() == 1 and knockbacks[0] == BAT.knockback, "bat sends the target flying up and away")
	arena.queue_free()
	await _frames(1)


func _test_bazooka_hits_fighter() -> void:
	var arena := _make_arena()
	var shooter := _add_player(arena, 0)
	var target := _add_player(arena, 150)
	shooter.weapons.equip(BAZOOKA)
	await _frames(2)
	var exploded := []
	arena.child_entered_tree.connect(func(node):
		if node is Grenade:
			node.exploded.connect(func(_e): exploded.append(node.fuse_left)))
	shooter.weapons.try_use()
	await _frames(30)
	_check(exploded.size() == 1, "rocket explodes")
	_check(not exploded.is_empty() and exploded[0] > BAZOOKA.fuse_time - 0.6, "rocket blows up on impact, not on the fuse")
	_check(target.health.current_health <= 100 - roundi(BAZOOKA.damage * BAZOOKA.min_damage_ratio), "rocket blast hurts the target (got %d)" % target.health.current_health)
	_check(shooter.health.current_health == 100, "shooter out of the blast is fine")
	arena.queue_free()
	await _frames(1)


func _test_bazooka_hits_wall() -> void:
	var arena := _make_arena()
	var shooter := _add_player(arena, 0)
	# A brick column (only explosions break brick) at x 112..128, y -48..0.
	var map := DestructibleMap.new()
	map.layout = PackedStringArray(["B", "B", "B"])
	map.position = Vector2(112, -48)
	arena.add_child(map)
	shooter.weapons.equip(BAZOOKA)
	await _frames(2)
	var blasts := []
	arena.child_entered_tree.connect(func(node):
		if node is Explosion:
			blasts.append(node))
	shooter.weapons.try_use()
	await _frames(30)
	_check(blasts.size() == 1, "rocket explodes against a wall")
	if blasts.size() == 1:
		_check(absf(blasts[0].global_position.x - 112.0) < 8.0, "blast happens at the wall (x %.0f)" % blasts[0].global_position.x)
	_check(map.block_count() < 3, "rocket breaks brick (%d blocks left)" % map.block_count())
	arena.queue_free()
	await _frames(1)


func _test_bazooka_ignores_shooter() -> void:
	var arena := _make_arena()
	var shooter := _add_player(arena, 0)
	shooter.weapons.equip(BAZOOKA)
	await _frames(2)
	var rockets := []
	arena.child_entered_tree.connect(func(node):
		if node is Grenade:
			rockets.append(node))
	shooter.weapons.try_use()
	await _frames(5)
	_check(rockets.size() == 1 and is_instance_valid(rockets[0]), "rocket leaves the barrel without hitting its shooter")
	_check(shooter.health.current_health == 100, "shooter is unhurt at launch")
	arena.queue_free()
	await _frames(1)


func _test_damage_multiplier() -> void:
	var arena := _make_arena()
	var batter := _add_player(arena, 0)
	var target := _add_player(arena, 18)
	batter.weapons.damage_multiplier = 2.0
	batter.weapons.equip(BAT)
	await _frames(2)
	batter.weapons.try_use()
	await _frames(12)
	_check(target.health.current_health == 100 - BAT.damage * 2, "multiplier doubles melee damage (got %d)" % target.health.current_health)
	arena.queue_free()
	await _frames(1)
