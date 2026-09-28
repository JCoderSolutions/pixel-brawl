extends SceneTree

## Headless tests for grenades and explosions (TASK-006): throw, bounce,
## fuse, damage falloff, knockback and map destruction. Run with:
## godot --headless --path . -s scripts/weapons/test_grenades.gd

const GRENADE := preload("res://scripts/weapons/data/grenade.tres")
const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")
const DUMMY_SCENE := preload("res://scenes/items/target_dummy.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_grenade_data()
	await _test_throw_direction_and_ammo()
	await _test_fuse()
	await _test_bounces_off_walls()
	await _test_damage_falloff_and_knockback()
	await _test_breaks_map_blocks()
	await _test_hurts_and_launches_player()
	await _test_thrown_grenade_opens_a_hole()
	print("OK: grenade data, throw, fuse, bounce, damage falloff, knockback, block destruction, player launch and full throw-to-hole verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(time: float) -> void:
	await _frames(ceili(time * Engine.physics_ticks_per_second))


## Floor with its top at y = 0 plus a thrower body holding grenades.
func _spawn_range() -> Dictionary:
	var arena := Node2D.new()
	root.add_child(arena)
	_add_wall(arena, Vector2(0, 10), Vector2(2000, 20))
	var thrower := CharacterBody2D.new()
	thrower.collision_layer = 2
	thrower.collision_mask = 1
	arena.add_child(thrower)
	var holder := WeaponHolder.new()
	holder.position = Vector2(0, -17)
	thrower.add_child(holder)
	return {"arena": arena, "thrower": thrower, "holder": holder}


func _add_wall(arena: Node2D, center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	wall.add_child(shape)
	wall.position = center
	arena.add_child(wall)


func _add_dummy(arena: Node2D, x: float) -> TargetDummy:
	var dummy: TargetDummy = DUMMY_SCENE.instantiate()
	dummy.respawn_delay = 0.0
	dummy.position = Vector2(x, 0)
	arena.add_child(dummy)
	return dummy


func _blast(arena: Node2D, at: Vector2) -> Explosion:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.configure(GRENADE)
	arena.add_child(explosion)
	explosion.global_position = at
	return explosion


func _grenades(arena: Node) -> Array:
	return arena.get_children().filter(func(n): return n is Grenade and not n.is_queued_for_deletion())


func _free(setup: Dictionary) -> void:
	setup.arena.queue_free()
	await _frames(1)


func _test_grenade_data() -> void:
	_check(GRENADE is GrenadeData, "grenade.tres is GrenadeData")
	_check(not GRENADE.has_unlimited_ammo(), "grenades run out")
	_check(GRENADE.fuse_time > 0.0 and GRENADE.explosion_radius > 0.0, "grenade has a fuse and a blast radius")


func _test_throw_direction_and_ammo() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	holder.equip(GRENADE)
	await _frames(3)
	_check(holder.try_use(), "grenade is thrown")
	_check(holder.ammo == GRENADE.max_ammo - 1, "throw spends one grenade")
	var thrown := _grenades(setup.arena)
	_check(thrown.size() == 1, "one grenade per throw (got %d)" % thrown.size())
	_check(thrown[0].linear_velocity.x > 0.0 and thrown[0].linear_velocity.y < 0.0, "facing right throws up and to the right")
	_check(_check_no_projectiles(setup.arena), "throwing spawns no bullets")

	await _seconds(GRENADE.cooldown)
	holder.facing = -1
	_check(holder.try_use(), "second grenade is thrown")
	thrown = _grenades(setup.arena)
	_check(thrown.size() == 2 and thrown[1].linear_velocity.x < 0.0, "facing left throws to the left")
	await _free(setup)


func _check_no_projectiles(arena: Node) -> bool:
	return arena.get_children().all(func(n): return not n is Projectile)


func _test_fuse() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	holder.equip(GRENADE)
	await _frames(3)
	holder.try_use()
	var grenade: Grenade = _grenades(setup.arena)[0]
	var blasts := [0]
	grenade.exploded.connect(func(_e): blasts[0] += 1)
	await _seconds(GRENADE.fuse_time - 0.2)
	_check(is_instance_valid(grenade) and blasts[0] == 0, "grenade waits for its fuse")
	await _seconds(0.3)
	_check(blasts[0] == 1, "grenade explodes once when the fuse runs out")
	_check(not is_instance_valid(grenade) or grenade.is_queued_for_deletion(), "exploded grenade leaves the world")
	await _free(setup)


func _test_bounces_off_walls() -> void:
	var setup := _spawn_range()
	_add_wall(setup.arena, Vector2(50, -40), Vector2(8, 80))
	var holder: WeaponHolder = setup.holder
	var slow: GrenadeData = GRENADE.duplicate()
	slow.fuse_time = 10.0
	holder.equip(slow)
	await _frames(3)
	holder.try_use()
	var grenade: Grenade = _grenades(setup.arena)[0]
	await _seconds(0.5)
	_check(grenade.global_position.x < 46.0, "grenade does not pass through walls (x=%.1f)" % grenade.global_position.x)
	await _seconds(2.0)
	_check(grenade.global_position.x < 46.0, "grenade bounced back off the wall")
	_check(absf(grenade.global_position.y) < 6.0, "grenade settles on the floor (y=%.1f)" % grenade.global_position.y)
	await _free(setup)


func _test_damage_falloff_and_knockback() -> void:
	var setup := _spawn_range()
	var near := _add_dummy(setup.arena, 10.0)
	var edge := _add_dummy(setup.arena, -34.0)
	var far := _add_dummy(setup.arena, 120.0)
	await _frames(3)
	var explosion := _blast(setup.arena, Vector2(0, -10))
	var hits := explosion.detonate()
	var near_taken: int = 100 - near.health.current_health
	var edge_taken: int = 100 - edge.health.current_health
	_check(hits == 2, "blast hits the two dummies in range (got %d)" % hits)
	_check(near_taken > edge_taken and edge_taken > 0, "damage falls off with distance (near %d, edge %d)" % [near_taken, edge_taken])
	_check(near_taken <= GRENADE.damage, "damage never exceeds the grenade's")
	_check(far.health.current_health == 100, "dummy out of range is untouched")
	_check(near.last_knockback.x > 0.0 and edge.last_knockback.x < 0.0, "knockback pushes away from the centre")
	_check(near.last_knockback.y < 0.0 and edge.last_knockback.y < 0.0, "knockback lifts targets")
	await _free(setup)


func _test_breaks_map_blocks() -> void:
	var setup := _spawn_range()
	var map := DestructibleMap.new()
	map.layout = PackedStringArray([
		"##########",
		"####X#####",
	])
	map.position = Vector2(0, -200)
	setup.arena.add_child(map)
	await _frames(3)
	var before := map.block_count()
	var center: Vector2 = map.to_global(map.cell_to_world(Vector2i(4, 1)))
	_blast(setup.arena, center).detonate()
	await _frames(2)
	_check(map.get_block(Vector2i(3, 1)) == null and map.get_block(Vector2i(5, 1)) == null, "blocks next to the blast break")
	_check(map.get_block(Vector2i(4, 0)) == null, "block above the blast breaks")
	_check(map.get_block(Vector2i(4, 1)) != null, "indestructible block survives")
	_check(map.get_block(Vector2i(0, 0)) != null and map.get_block(Vector2i(9, 1)) != null, "blocks out of range survive")
	_check(map.block_count() < before - 4, "blast opens a hole (%d -> %d)" % [before, map.block_count()])
	await _free(setup)


func _test_hurts_and_launches_player() -> void:
	var setup := _spawn_range()
	var player = load("res://scenes/characters/player.tscn").instantiate()
	player.is_controlled = false
	player.position = Vector2(20, 0)
	setup.arena.add_child(player)
	await _frames(10)
	_blast(setup.arena, Vector2(0, -4)).detonate(setup.thrower)
	_check(player.health.current_health < 100, "blast damages a real player (hp %d)" % player.health.current_health)
	_check(player.velocity.x > 0.0 and player.velocity.y < 0.0, "blast launches the player up and away (v=%s)" % player.velocity)
	await _frames(5)
	_check(player.position.y < -1.0, "player leaves the floor")
	await _free(setup)


## End to end: thrown at a crate wall, the grenade bounces, blows up and
## leaves a hole in the map.
func _test_thrown_grenade_opens_a_hole() -> void:
	var setup := _spawn_range()
	var map := DestructibleMap.new()
	map.layout = PackedStringArray(["#", "#", "#", "#"])
	map.position = Vector2(60, -64)
	setup.arena.add_child(map)
	var holder: WeaponHolder = setup.holder
	holder.equip(GRENADE)
	await _frames(3)
	holder.try_use()
	await _seconds(GRENADE.fuse_time + 0.2)
	_check(map.block_count() < 4, "thrown grenade breaks the crate wall (%d left)" % map.block_count())
	await _free(setup)
