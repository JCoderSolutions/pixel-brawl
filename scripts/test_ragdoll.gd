extends SceneTree

const FLOOR_TOP := 15.0

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_ragdoll_builds_from_parts()
	await _test_ragdoll_launch_and_settle()
	await _test_ragdoll_ignores_players()
	await _test_ragdoll_lifetime()
	await _test_death_spawns_ragdoll_away_from_killer()
	await _test_restore_brings_player_back()
	print("OK: ragdoll parts, joints, launch, floor rest, player pass-through, lifetime, spawn on death and restore verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Floor whose top surface sits at y = FLOOR_TOP, wide enough for any launch.
func _spawn_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(4000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, FLOOR_TOP + 10.0)
	arena.add_child(floor_body)
	return arena


func _spawn_ragdoll(arena: Node2D, at: Vector2) -> Ragdoll:
	var ragdoll: Ragdoll = load("res://scenes/effects/ragdoll.tscn").instantiate()
	ragdoll.lifetime = 0.0
	ragdoll.position = at
	arena.add_child(ragdoll)
	return ragdoll


func _spawn_player(arena: Node2D, at: Vector2, with_hook := true) -> Node:
	var player = load("res://scenes/characters/player.tscn").instantiate()
	player.is_controlled = false
	player.position = at
	if with_hook:
		var hook: RagdollOnDeath = load("res://scenes/effects/ragdoll_on_death.tscn").instantiate()
		hook.name = "RagdollOnDeath"
		player.add_child(hook)
	arena.add_child(player)
	return player


func _find_ragdoll(arena: Node) -> Ragdoll:
	for child in arena.get_children():
		if child is Ragdoll:
			return child
	return null


func _test_ragdoll_builds_from_parts() -> void:
	var arena := _spawn_arena()
	var ragdoll := _spawn_ragdoll(arena, Vector2(0, 0))
	var parts := ragdoll.get_parts()
	_check(parts.size() == 6, "ragdoll has head, torso, two arms and two legs (got %d)" % parts.size())
	var joints := ragdoll.find_children("*", "PinJoint2D")
	_check(joints.size() == 5, "every limb is pinned to the torso (got %d joints)" % joints.size())
	for part in parts:
		_check(part.collision_mask == 1, "%s only collides with the world" % part.name)
		_check(part.global_position.y < 0.0 and part.global_position.y > -32.0,
				"%s starts inside the player's silhouette" % part.name)
	ragdoll.set_color(Color.RED)
	for part in parts:
		var visual: ColorRect = part.get_node("Visual")
		_check(visual.color.r > visual.color.g, "%s is tinted with the player colour" % part.name)
	arena.queue_free()
	await _frames(1)


func _test_ragdoll_launch_and_settle() -> void:
	var arena := _spawn_arena()
	var ragdoll := _spawn_ragdoll(arena, Vector2(0, FLOOR_TOP))
	await _frames(1)
	ragdoll.launch(Vector2(300, -200))
	await _frames(10)
	var torso := ragdoll.get_torso()
	_check(torso.global_position.x > 10.0, "launch sends the body flying (x=%s)" % torso.global_position.x)
	await _frames(240)
	for part in ragdoll.get_parts():
		_check(part.global_position.y <= FLOOR_TOP + 1.0, "%s rests on the floor (y=%s)" % [part.name, part.global_position.y])
		_check(part.global_position.distance_to(torso.global_position) < 24.0,
				"%s stays attached to the torso" % part.name)
	_check(torso.linear_velocity.length() < 20.0, "ragdoll settles (v=%s)" % torso.linear_velocity.length())
	arena.queue_free()
	await _frames(1)


## Bodies must not trip or push living players; they only land on the map.
func _test_ragdoll_ignores_players() -> void:
	var arena := _spawn_arena()
	var player = _spawn_player(arena, Vector2(30, FLOOR_TOP), false)
	await _frames(20)
	var start_x: float = player.position.x
	var ragdoll := _spawn_ragdoll(arena, Vector2(0, FLOOR_TOP))
	ragdoll.launch(Vector2(400, 0))
	await _frames(30)
	_check(absf(player.position.x - start_x) < 0.5, "ragdoll passes through players")
	arena.queue_free()
	await _frames(1)


func _test_ragdoll_lifetime() -> void:
	var arena := _spawn_arena()
	var ragdoll: Ragdoll = load("res://scenes/effects/ragdoll.tscn").instantiate()
	ragdoll.lifetime = 0.2
	ragdoll.fade_time = 0.1
	arena.add_child(ragdoll)
	await _frames(40)
	_check(not is_instance_valid(ragdoll), "ragdoll frees itself after its lifetime")

	var persistent := _spawn_ragdoll(arena, Vector2.ZERO)
	await _frames(40)
	_check(is_instance_valid(persistent), "lifetime 0 keeps the ragdoll")
	arena.queue_free()
	await _frames(1)


func _test_death_spawns_ragdoll_away_from_killer() -> void:
	var arena := _spawn_arena()
	var attacker = _spawn_player(arena, Vector2(0, FLOOR_TOP))
	var target = _spawn_player(arena, Vector2(20, FLOOR_TOP))
	target.health.max_health = 10
	target.health.current_health = 10
	var spawned := [null]
	target.get_node("RagdollOnDeath").ragdoll_spawned.connect(func(r): spawned[0] = r)
	await _frames(5)

	attacker.start_attack()
	await _frames(30)
	_check(target.health.is_dead(), "target died")
	var ragdoll := _find_ragdoll(arena)
	_check(ragdoll != null, "death spawns a ragdoll next to the player")
	_check(spawned[0] == ragdoll, "ragdoll_spawned reports the new ragdoll")
	_check(not target.get_node("Visual").visible, "dead player's sprite is hidden behind the ragdoll")
	_check(_find_ragdoll(attacker) == null and attacker.get_node("Visual").visible, "killer keeps its body")
	if ragdoll != null:
		_check(ragdoll.get_torso().global_position.x > 25.0,
				"ragdoll flies away from the killer (x=%s)" % ragdoll.get_torso().global_position.x)
	arena.queue_free()
	await _frames(1)


func _test_restore_brings_player_back() -> void:
	var arena := _spawn_arena()
	var player = _spawn_player(arena, Vector2(0, FLOOR_TOP))
	await _frames(2)
	player.health.take_damage(1000)
	await _frames(2)
	var hook: RagdollOnDeath = player.get_node("RagdollOnDeath")
	var ragdoll := _find_ragdoll(arena)
	_check(ragdoll != null and hook.ragdoll == ragdoll, "hook tracks the ragdoll it spawned")
	hook.restore()
	await _frames(1)
	_check(not is_instance_valid(ragdoll), "restore removes the ragdoll")
	_check(player.get_node("Visual").visible, "restore shows the player again")
	arena.queue_free()
	await _frames(1)
