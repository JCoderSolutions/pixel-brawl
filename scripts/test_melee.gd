extends SceneTree

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_health_component()
	await _test_melee_hit()
	await _test_out_of_range()
	await _test_death()
	print("OK: health, melee hit, knockback, single hit per swing, range and death verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _test_health_component() -> void:
	var health := HealthComponent.new()
	health.max_health = 30
	root.add_child(health)
	var deaths := [0]
	health.died.connect(func(_s): deaths[0] += 1)
	health.take_damage(10)
	_check(health.current_health == 20, "damage reduces health")
	health.heal(50)
	_check(health.current_health == 30, "heal clamps to max")
	health.take_damage(100)
	health.take_damage(10)
	_check(health.current_health == 0, "health clamps at zero")
	_check(deaths[0] == 1, "died emits exactly once")
	health.queue_free()


## Builds a floor and two players `gap` pixels apart, attacker facing right.
func _spawn_duel(gap: float) -> Array:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(1000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 25)
	arena.add_child(floor_body)

	var scene: PackedScene = load("res://scenes/characters/player.tscn")
	var attacker = scene.instantiate()
	attacker.is_controlled = false
	arena.add_child(attacker)
	var target = scene.instantiate()
	target.is_controlled = false
	target.position = Vector2(gap, 0)
	arena.add_child(target)
	return [arena, attacker, target]


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _test_melee_hit() -> void:
	var duel := await _spawn_duel(20.0)
	var attacker = duel[1]
	var target = duel[2]
	await _frames(5)

	attacker.start_attack()
	await _frames(30)
	_check(target.health.current_health == 90, "target took one hit of 10 (got %d)" % target.health.current_health)
	_check(attacker.health.current_health == 100, "attacker did not hit itself")
	_check(target.velocity.x > 0.0 or target.position.x > 20.0, "knockback pushed target away")

	# Knockback carried the target out of reach; bring it back for a second
	# swing, which must land once invulnerability has expired.
	await _frames(20)
	target.position = Vector2(20, target.position.y)
	target.velocity = Vector2.ZERO
	await _frames(2)
	attacker.start_attack()
	await _frames(30)
	_check(target.health.current_health == 80, "second swing lands after i-frames (got %d)" % target.health.current_health)
	duel[0].queue_free()
	await _frames(1)


func _test_out_of_range() -> void:
	var duel := await _spawn_duel(80.0)
	await _frames(5)
	duel[1].start_attack()
	await _frames(30)
	_check(duel[2].health.current_health == 100, "target out of reach is not hit")
	duel[0].queue_free()
	await _frames(1)


func _test_death() -> void:
	var duel := await _spawn_duel(20.0)
	var attacker = duel[1]
	var target = duel[2]
	target.health.max_health = 10
	target.health.current_health = 10
	await _frames(5)
	attacker.start_attack()
	await _frames(30)
	_check(target.health.is_dead(), "target dies at zero health")
	target.start_attack()
	_check(not target.is_attacking(), "dead player cannot attack")
	duel[0].queue_free()
	await _frames(1)
