extends SceneTree

## Headless tests for weapons: data, projectiles, melee, ammo, pickup/drop
## and the random spawner. Run with:
## godot --headless --path . -s scripts/weapons/test_weapons.gd

const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const SHOTGUN := preload("res://scripts/weapons/data/shotgun.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")
const SAWED_OFF := preload("res://scripts/weapons/data/sawed_off.tres")
const DUMMY_SCENE := preload("res://scenes/items/target_dummy.tscn")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const SPAWNER_SCENE := preload("res://scenes/items/weapon_spawner.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_weapon_data()
	await _test_pistol_hits_target()
	await _test_projectile_ignores_shooter()
	await _test_projectile_blocked_by_wall()
	await _test_projectile_range()
	await _test_shotgun_pellets()
	await _test_katana_reach()
	await _test_ammo_runs_out()
	await _test_pickup_and_swap()
	await _test_drop_keeps_ammo()
	await _test_pistol_hits_player()
	await _test_spawner()
	print("OK: weapon data, projectiles, walls, range, shotgun spread, katana, ammo, pickup/drop, player hit and spawner verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Floor at y = 0 plus a wielder body with a WeaponHolder at hand height.
func _spawn_range() -> Dictionary:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(2000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)

	var wielder := CharacterBody2D.new()
	wielder.collision_layer = 2
	wielder.collision_mask = 1
	arena.add_child(wielder)
	# The wielder gets its own hurtbox, as a player would, to prove shots and
	# swings never hit their owner.
	var own_health := HealthComponent.new()
	wielder.add_child(own_health)
	var own_hurtbox := _make_hurtbox(own_health)
	wielder.add_child(own_hurtbox)
	own_hurtbox.owner = wielder

	var holder := WeaponHolder.new()
	holder.position = Vector2(0, -17)
	wielder.add_child(holder)
	return {"arena": arena, "wielder": wielder, "holder": holder, "own_health": own_health}


func _make_hurtbox(health: HealthComponent) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 28)
	shape.position = Vector2(0, -15)
	hurtbox.add_child(shape)
	return hurtbox


func _add_dummy(arena: Node2D, x: float) -> TargetDummy:
	var dummy: TargetDummy = DUMMY_SCENE.instantiate()
	dummy.respawn_delay = 0.0
	dummy.position = Vector2(x, 0)
	arena.add_child(dummy)
	return dummy


func _add_wall(arena: Node2D, x: float) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(4, 80)
	wall.add_child(shape)
	wall.position = Vector2(x, -40)
	arena.add_child(wall)


func _free(setup: Dictionary) -> void:
	setup.arena.queue_free()
	await _frames(1)


func _test_weapon_data() -> void:
	_check(PISTOL.is_ranged() and not PISTOL.has_unlimited_ammo(), "pistol is a ranged gun with ammo")
	_check(not KATANA.is_ranged() and KATANA.has_unlimited_ammo(), "katana is melee with unlimited uses")
	var angles := SHOTGUN.spread_angles()
	_check(angles.size() == SHOTGUN.projectiles_per_shot, "one angle per pellet")
	_check(is_equal_approx(angles[0], -SHOTGUN.spread_degrees / 2.0) and is_equal_approx(angles[-1], SHOTGUN.spread_degrees / 2.0), "pellets span the full cone")
	_check(PISTOL.spread_angles() == [0.0], "single shot flies straight")


func _test_pistol_hits_target() -> void:
	var setup := _spawn_range()
	var dummy := _add_dummy(setup.arena, 150.0)
	var holder: WeaponHolder = setup.holder
	holder.equip(PISTOL)
	await _frames(3)

	_check(holder.try_use(), "pistol fires when ready")
	_check(holder.ammo == PISTOL.max_ammo - 1, "shot spends one bullet")
	_check(not holder.try_use(), "cooldown blocks an immediate second shot")
	await _frames(20)
	_check(dummy.health.current_health == 100 - PISTOL.damage, "bullet deals pistol damage (got %d)" % dummy.health.current_health)
	_check(dummy.last_knockback.x > 0.0, "knockback pushes away from the shooter")
	_check(holder.try_use(), "pistol fires again after cooldown")

	await _frames(20)
	var before := dummy.health.current_health
	await _frames(20)
	# Facing left shoots left: the dummy on the right stays untouched.
	holder.facing = -1
	_check(holder.try_use(), "pistol fires facing left")
	await _frames(20)
	_check(dummy.health.current_health == before, "shot aimed left misses target on the right")
	await _free(setup)


func _test_projectile_ignores_shooter() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	# Muzzle behind the shooter: every pellet has to cross its own hurtbox.
	var gun: WeaponData = SHOTGUN.duplicate()
	gun.muzzle_offset = -20.0
	holder.equip(gun)
	await _frames(3)
	holder.try_use()
	await _frames(20)
	_check(setup.own_health.current_health == 100, "shooter is never hit by its own shots")
	await _free(setup)


func _test_projectile_blocked_by_wall() -> void:
	var setup := _spawn_range()
	_add_wall(setup.arena, 60.0)
	var dummy := _add_dummy(setup.arena, 120.0)
	var holder: WeaponHolder = setup.holder
	holder.equip(PISTOL)
	await _frames(3)
	holder.try_use()
	await _frames(20)
	_check(dummy.health.current_health == 100, "walls stop bullets")
	_check(_projectile_count(setup.arena) == 0, "bullet is freed on impact")
	await _free(setup)


func _test_projectile_range() -> void:
	var setup := _spawn_range()
	var dummy := _add_dummy(setup.arena, SHOTGUN.projectile_range + 60.0)
	var holder: WeaponHolder = setup.holder
	holder.equip(SHOTGUN)
	await _frames(3)
	holder.try_use()
	await _frames(40)
	_check(dummy.health.current_health == 100, "pellets vanish at max range")
	_check(_projectile_count(setup.arena) == 0, "expired pellets are freed")
	await _free(setup)


func _test_shotgun_pellets() -> void:
	var setup := _spawn_range()
	var dummy := _add_dummy(setup.arena, 40.0)
	var holder: WeaponHolder = setup.holder
	var fired := [0]
	holder.fired.connect(func(_w, count): fired[0] = count)
	holder.equip(SHOTGUN)
	await _frames(3)
	holder.try_use()
	_check(fired[0] == SHOTGUN.projectiles_per_shot, "one blast spawns every pellet")
	await _frames(20)
	var taken: int = 100 - dummy.health.current_health
	_check(taken > SHOTGUN.damage, "point-blank blast lands several pellets (took %d)" % taken)
	await _free(setup)


func _test_katana_reach() -> void:
	var setup := _spawn_range()
	var near := _add_dummy(setup.arena, 22.0)
	var far := _add_dummy(setup.arena, 90.0)
	var holder: WeaponHolder = setup.holder
	holder.equip(KATANA)
	await _frames(3)
	_check(holder.try_use(), "katana swings")
	await _frames(20)
	_check(near.health.current_health == 100 - KATANA.damage, "katana hits once in reach (got %d)" % near.health.current_health)
	_check(far.health.current_health == 100, "katana misses out of reach")
	_check(setup.own_health.current_health == 100, "katana never cuts its wielder")
	_check(holder.ammo == -1 and holder.has_weapon(), "katana is never spent")
	await _free(setup)


func _test_ammo_runs_out() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	var spent := [null]
	holder.weapon_spent.connect(func(w): spent[0] = w)
	holder.equip(PISTOL, 1)
	await _frames(3)
	_check(holder.try_use(), "last bullet fires")
	_check(holder.has_weapon() and holder.is_empty(), "the empty gun stays in hand (throw it with pickup)")
	_check(spent[0] == PISTOL, "weapon_spent reports the empty gun")
	_check(not holder.try_use(), "an empty gun cannot fire")
	await _free(setup)


func _test_pickup_and_swap() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	var far_pickup := _add_pickup(setup.arena, KATANA, Vector2(200, -4))
	await _frames(3)
	_check(not holder.try_pick_up(), "pickups out of reach are ignored")

	var pistol_pickup := _add_pickup(setup.arena, PISTOL, Vector2(10, -4))
	await _frames(3)
	_check(holder.try_pick_up(), "nearby pickup is grabbed")
	_check(holder.weapon == PISTOL and holder.ammo == PISTOL.max_ammo, "grabbed weapon comes with full ammo")
	await _frames(1)
	_check(not is_instance_valid(pistol_pickup), "grabbed pickup leaves the world")

	far_pickup.queue_free()
	_add_pickup(setup.arena, KATANA, Vector2(8, -4))
	await _frames(3)
	_check(holder.try_pick_up(), "second pickup is grabbed")
	_check(holder.weapon == KATANA and holder.carried(WeaponData.Slot.HANDGUN) == PISTOL,
			"a weapon for another slot is drawn and the gun stays carried")
	await _frames(1)
	_check(_pickups(setup.arena).is_empty(), "nothing is dropped")

	_add_pickup(setup.arena, SAWED_OFF, Vector2(8, -4))
	await _frames(3)
	_check(holder.try_pick_up() and holder.weapon == SAWED_OFF, "a weapon for a taken slot is grabbed")
	await _frames(1)
	var dropped := _pickups(setup.arena)
	_check(dropped.size() == 1 and dropped[0].weapon == PISTOL, "and swaps out the one in that slot as a pickup")
	await _free(setup)


func _test_drop_keeps_ammo() -> void:
	var setup := _spawn_range()
	var holder: WeaponHolder = setup.holder
	holder.equip(SHOTGUN, 2)
	var pickup := holder.drop()
	_check(not holder.has_weapon(), "drop empties the hands")
	_check(pickup != null and pickup.weapon == SHOTGUN and pickup.ammo == 2, "dropped pickup keeps remaining ammo")
	await _frames(60)
	_check(pickup.global_position.y < 1.0 and pickup.global_position.y > -20.0, "dropped weapon falls and rests on the floor (y=%.1f)" % pickup.global_position.y)
	_check(holder.drop() == null, "nothing to drop with empty hands")
	await _free(setup)


## Weapons plug into the existing player: a bullet goes through the player's
## own Hurtbox, so health, knockback and i-frames from TASK-003 all apply.
func _test_pistol_hits_player() -> void:
	var setup := _spawn_range()
	var player = load("res://scenes/characters/player.tscn").instantiate()
	player.is_controlled = false
	player.position = Vector2(120, 0)
	setup.arena.add_child(player)
	var holder: WeaponHolder = setup.holder
	holder.equip(PISTOL)
	await _frames(10)
	holder.try_use()
	await _frames(15)
	_check(player.health.current_health == 100 - PISTOL.damage, "bullet damages a real player (got %d)" % player.health.current_health)
	_check(player.velocity.x > 0.0 or player.position.x > 120.0, "bullet knocks the player back")
	await _free(setup)


func _test_spawner() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var spawner: WeaponSpawner = SPAWNER_SCENE.instantiate()
	spawner.autostart = false
	spawner.rng_seed = 1234
	spawner.max_active = 2
	spawner.weapons = [PISTOL, SHOTGUN, KATANA]
	for x in [0.0, 100.0, 200.0]:
		var marker := Marker2D.new()
		marker.position = Vector2(x, 0)
		spawner.add_child(marker)
	arena.add_child(spawner)
	await _frames(1)

	var first := spawner.spawn_one()
	var second := spawner.spawn_one()
	_check(first != null and second != null, "spawner drops weapons")
	_check(first.weapon in [PISTOL, SHOTGUN, KATANA], "spawned weapon comes from the pool")
	_check(first.global_position != second.global_position, "active pickups use different spawn points")
	_check(spawner.spawn_one() == null, "spawner respects max_active")
	first.queue_free()
	await _frames(1)
	_check(spawner.spawn_one() != null, "a taken weapon frees a slot")

	var picks := {}
	for i in 30:
		picks[spawner.pick_weapon()] = true
	_check(picks.size() == 3, "random picks cover the whole pool")
	arena.queue_free()
	await _frames(1)


func _add_pickup(arena: Node2D, data: WeaponData, at: Vector2) -> WeaponPickup:
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = data
	pickup.position = at
	arena.add_child(pickup)
	return pickup


func _pickups(arena: Node) -> Array:
	return arena.find_children("*", "WeaponPickup", true, false)


func _projectile_count(arena: Node) -> int:
	return arena.find_children("*", "Projectile", true, false).size()
