extends SceneTree

## Headless tests for power-ups: data, every effect on a real player and its
## expiry, pickup by touch, the spawner mixing power-ups with weapons and bots
## walking to them.
## Run: godot --headless --path . -s scripts/powerups/test_powerups.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const POWER_UP_SCENE := preload("res://scenes/powerups/power_up_pickup.tscn")
const SPAWNER_SCENE := preload("res://scenes/items/weapon_spawner.tscn")
const MEDKIT := preload("res://scripts/powerups/data/medkit.tres")
const SPEED := preload("res://scripts/powerups/data/speed.tres")
const STRENGTH := preload("res://scripts/powerups/data/strength.tres")
const SHIELD := preload("res://scripts/powerups/data/shield.tres")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_data()
	await _test_medkit()
	await _test_speed_and_expiry()
	await _test_strength()
	await _test_shield()
	await _test_refresh_does_not_stack()
	await _test_death_clears_effects()
	await _test_pickup_by_touch()
	await _test_spawner_mixes_power_ups()
	await _test_bot_walks_to_power_up()
	print("OK: power-up data, medkit, speed + expiry, strength, shield, refresh, death, touch pickup, spawner mix and bots collecting verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Arena whose floor top is y = 0.
func _make_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(800, 20)
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


## Holds right for `ticks` physics frames.
func _run_right(ticks: int) -> ScriptedInputSource:
	var frames: Array[InputFrame] = []
	for i in ticks:
		frames.append(InputFrame.create(1.0, 0))
	return ScriptedInputSource.new(frames)


func _receiver(player: Node) -> PowerUpReceiver:
	return PowerUpReceiver.find_on(player)


## A copy with a short duration so expiry tests stay fast.
func _short(data: PowerUpData, seconds := 0.2) -> PowerUpData:
	var copy: PowerUpData = data.duplicate()
	copy.duration = seconds
	return copy


func _test_data() -> void:
	_check(MEDKIT.effect == PowerUpData.Effect.HEAL and MEDKIT.is_instant(), "medkit heals instantly")
	for data in [SPEED, STRENGTH, SHIELD]:
		_check(not data.is_instant() and data.duration > 0.0, "%s lasts a while" % data.id)
	_check(SPEED.amount > 1.0 and STRENGTH.amount > 1.0, "speed and strength multiply")


func _test_medkit() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var receiver := _receiver(player)
	_check(receiver != null, "players come with a PowerUpReceiver")
	_check(not receiver.apply(MEDKIT), "medkit is refused at full health")
	player.health.take_damage(60)
	_check(receiver.apply(MEDKIT), "medkit heals a hurt fighter")
	_check(player.health.current_health == 40 + int(MEDKIT.amount), "medkit restores its amount (got %d)" % player.health.current_health)
	player.health.take_damage(5)
	receiver.apply(MEDKIT)
	_check(player.health.current_health <= player.health.max_health, "heal never goes above max")
	arena.queue_free()
	await _frames(1)


func _test_speed_and_expiry() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var base: float = player.run_speed
	var receiver := _receiver(player)
	var expired := []
	receiver.power_up_expired.connect(func(data): expired.append(data))
	receiver.apply(_short(SPEED))
	_check(is_equal_approx(player.run_speed, base * SPEED.amount), "speed multiplies run speed")
	_check(receiver.is_active(PowerUpData.Effect.SPEED), "speed is active")

	# The boost is real movement, not just a number.
	player.is_controlled = true
	player.input_source = _run_right(120)
	await _frames(6)
	_check(player.velocity.x > base, "boosted player runs faster than normal (%.0f)" % player.velocity.x)
	player.is_controlled = false
	await _frames(12)
	_check(is_equal_approx(player.run_speed, base), "speed wears off")
	_check(not receiver.is_active(PowerUpData.Effect.SPEED) and expired.size() == 1, "expiry is reported once")
	arena.queue_free()
	await _frames(1)


func _test_strength() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var hitbox: Hitbox = player.get_node("Hitbox")
	var base_punch := hitbox.damage
	var receiver := _receiver(player)
	receiver.apply(_short(STRENGTH))
	_check(hitbox.damage == roundi(base_punch * STRENGTH.amount), "strength boosts punches")
	_check(is_equal_approx(player.weapons.damage_multiplier, STRENGTH.amount), "strength boosts weapons")

	# A pistol shot from a strong player hits harder.
	var target := _add_player(arena, 100)
	player.weapons.equip(PISTOL)
	await _frames(2)
	player.weapons.try_use()
	await _frames(15)
	var expected := 100 - roundi(PISTOL.damage * STRENGTH.amount)
	_check(target.health.current_health == expected, "boosted bullet damage (got %d, want %d)" % [target.health.current_health, expected])
	await _frames(10)
	_check(hitbox.damage == base_punch and player.weapons.damage_multiplier == 1.0, "strength wears off")
	arena.queue_free()
	await _frames(1)


func _test_shield() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var receiver := _receiver(player)
	receiver.apply(_short(SHIELD, 0.5))
	_check(player.health.shield == int(SHIELD.amount), "shield grants its points")
	player.health.take_damage(30)
	_check(player.health.current_health == 100, "shield soaks damage first")
	_check(player.health.shield == int(SHIELD.amount) - 30, "shield loses what it soaked")
	player.health.take_damage(30)
	_check(player.health.current_health == 100 - (30 - (int(SHIELD.amount) - 30)), "overflow reaches health")
	await _frames(2)
	_check(not receiver.is_active(PowerUpData.Effect.SHIELD), "a broken shield ends the effect")

	receiver.apply(_short(SHIELD))
	await _frames(20)
	_check(player.health.shield == 0, "an unbroken shield still expires")
	arena.queue_free()
	await _frames(1)


func _test_refresh_does_not_stack() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var base: float = player.run_speed
	var receiver := _receiver(player)
	receiver.apply(SPEED)
	await _frames(30)
	receiver.apply(SPEED)
	_check(is_equal_approx(player.run_speed, base * SPEED.amount), "a second speed doesn't stack")
	_check(receiver.time_left(PowerUpData.Effect.SPEED) > SPEED.duration - 0.05, "a second speed refreshes the timer")
	arena.queue_free()
	await _frames(1)


func _test_death_clears_effects() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	await _frames(2)
	var base: float = player.run_speed
	var receiver := _receiver(player)
	receiver.apply(SPEED)
	receiver.apply(STRENGTH)
	player.health.take_damage(1000)
	_check(not receiver.is_active(PowerUpData.Effect.SPEED) and not receiver.is_active(PowerUpData.Effect.STRENGTH), "death ends every effect")
	_check(is_equal_approx(player.run_speed, base), "death restores speed")
	_check(not receiver.apply(SPEED), "the dead can't pick power-ups")
	arena.queue_free()
	await _frames(1)


func _test_pickup_by_touch() -> void:
	var arena := _make_arena()
	var player := _add_player(arena, 0)
	var pickup: PowerUpPickup = POWER_UP_SCENE.instantiate()
	pickup.power_up = SPEED
	pickup.position = Vector2(80, -20)
	arena.add_child(pickup)
	await _frames(30)
	_check(is_instance_valid(pickup) and pickup.global_position.y > -10.0, "power-up falls onto the floor")
	_check(pickup in pickup.get_tree().get_nodes_in_group(PowerUpPickup.GROUP), "power-up is findable by group")

	var collected := []
	pickup.collected.connect(func(data, by): collected.append(by))
	player.is_controlled = true
	player.input_source = _run_right(120)
	await _frames(60)
	_check(collected == [player], "walking over it collects it")
	_check(_receiver(player).is_active(PowerUpData.Effect.SPEED), "collecting applies the effect")
	await _frames(1)
	_check(not is_instance_valid(pickup), "collected power-up leaves the map")

	# A medkit waits under a healthy fighter and is taken once they get hurt.
	var medkit: PowerUpPickup = POWER_UP_SCENE.instantiate()
	medkit.power_up = MEDKIT
	medkit.position = player.position + Vector2(0, -8)
	player.is_controlled = false
	arena.add_child(medkit)
	await _frames(20)
	_check(is_instance_valid(medkit), "medkit stays while at full health")
	player.health.take_damage(30)
	await _frames(20)
	var healed := mini(100 - 30 + int(MEDKIT.amount), 100)
	_check(not is_instance_valid(medkit) and player.health.current_health == healed,
			"medkit is taken once hurt (health %d)" % player.health.current_health)
	arena.queue_free()
	await _frames(1)


func _test_spawner_mixes_power_ups() -> void:
	var arena := _make_arena()
	var spawner: WeaponSpawner = SPAWNER_SCENE.instantiate()
	spawner.autostart = false
	spawner.rng_seed = 42
	spawner.max_active = 10
	for x in 6:
		var marker := Marker2D.new()
		marker.position = Vector2(x * 40, -40)
		spawner.add_child(marker)
	arena.add_child(spawner)
	await _frames(1)
	_check(not spawner.power_ups.is_empty(), "the default spawner carries power-ups")

	spawner.power_up_chance = 1.0
	_check(spawner.spawn_random() is PowerUpPickup, "chance 1 drops a power-up")
	spawner.power_up_chance = 0.0
	_check(spawner.spawn_random() is WeaponPickup, "chance 0 drops a weapon")
	var only_weapons: Array[PowerUpData] = []
	spawner.power_ups = only_weapons
	spawner.power_up_chance = 1.0
	_check(spawner.spawn_random() is WeaponPickup, "no power-ups means weapons only")

	# Power-ups share the spawn points and max_active with weapons.
	spawner.power_ups = [SHIELD]
	spawner.max_active = 3
	var power_up := spawner.spawn_power_up()
	_check(power_up == null, "power-ups respect max_active")
	arena.queue_free()
	await _frames(1)


func _test_bot_walks_to_power_up() -> void:
	var arena := _make_arena()
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.position = Vector2(-100, 0)
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.NORMAL, 7)
	arena.add_child(bot)
	var pickup: PowerUpPickup = POWER_UP_SCENE.instantiate()
	pickup.power_up = STRENGTH
	pickup.position = Vector2(20, -8)
	arena.add_child(pickup)
	var medkit: PowerUpPickup = POWER_UP_SCENE.instantiate()
	medkit.power_up = MEDKIT
	medkit.position = Vector2(-160, -8)
	arena.add_child(medkit)
	await _frames(180)
	_check(_receiver(bot).is_active(PowerUpData.Effect.STRENGTH), "bot walks over a power-up to collect it")
	_check(is_instance_valid(medkit), "a healthy bot leaves the medkit")
	arena.queue_free()
	await _frames(1)
