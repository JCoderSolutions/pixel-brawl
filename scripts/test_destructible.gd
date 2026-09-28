extends SceneTree

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_block_takes_damage_and_breaks()
	await _test_indestructible_block()
	await _test_map_builds_grid()
	await _test_area_damage()
	await _test_melee_breaks_block()
	await _test_player_falls_through_hole()
	print("OK: block health, shading, breaking, indestructible cells, grid layout, area damage, melee breaks blocks and holes open the floor" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _spawn_map(layout: PackedStringArray) -> DestructibleMap:
	var map := DestructibleMap.new()
	map.layout = layout
	root.add_child(map)
	return map


func _test_block_takes_damage_and_breaks() -> void:
	var block: DestructibleBlock = load("res://scenes/maps/destructible_block.tscn").instantiate()
	root.add_child(block)
	await _frames(1)
	_check(block.collision_layer == 1, "block collides on the world layer")
	var hurtbox: Hurtbox = block.get_node("Hurtbox")
	_check(hurtbox.collision_layer == 8, "block hurtbox sits on the hurtbox layer")
	var start_color: Color = block.get_node("Visual").color
	var destroyed := [0]
	block.destroyed.connect(func(_b): destroyed[0] += 1)

	hurtbox.receive_hit(block.health.max_health / 2, Vector2.ZERO, null)
	_check(block.health.current_health == block.health.max_health - block.health.max_health / 2, "damage reaches block health")
	_check(block.get_node("Visual").color != start_color, "damaged block changes shade")
	_check(is_instance_valid(block) and not block.is_queued_for_deletion(), "damaged block survives")

	hurtbox.receive_hit(block.health.max_health, Vector2.ZERO, null)
	_check(destroyed[0] == 1, "destroyed emits once at zero health")
	_check(block.is_queued_for_deletion(), "broken block is freed")
	await _frames(1)


func _test_indestructible_block() -> void:
	var map := _spawn_map(PackedStringArray(["X"]))
	await _frames(1)
	var block := map.get_block(Vector2i(0, 0))
	_check(block != null and block.indestructible, "X builds an indestructible block")
	map.damage_area(block.global_position, 32.0, 999)
	await _frames(1)
	_check(is_instance_valid(block) and not block.is_queued_for_deletion(), "indestructible block survives any damage")
	map.queue_free()
	await _frames(1)


func _test_map_builds_grid() -> void:
	var map := _spawn_map(PackedStringArray([
		"#..#",
		"####",
	]))
	map.position = Vector2(100, 50)
	await _frames(1)
	_check(map.block_count() == 6, "one block per # cell (got %d)" % map.block_count())
	_check(map.get_block(Vector2i(1, 0)) == null, "dots leave empty cells")
	var block := map.get_block(Vector2i(3, 1))
	_check(block != null and block.position == Vector2(56, 24), "cell (3,1) is centred on its 16px tile (got %s)" % (block.position if block else "null"))
	_check(map.world_to_cell(Vector2(100 + 57, 50 + 20)) == Vector2i(3, 1), "world_to_cell maps back to the grid")
	map.queue_free()
	await _frames(1)


func _test_area_damage() -> void:
	var map := _spawn_map(PackedStringArray(["#####"]))
	await _frames(1)
	var hp: int = map.get_block(Vector2i(0, 0)).health.max_health
	var centre := map.cell_to_world(Vector2i(2, 0))
	# Neighbour edges are 8 px from the centre: a 6 px blast reaches only cell 2.
	map.damage_area(centre, 6.0, hp)
	await _frames(1)
	_check(map.get_block(Vector2i(2, 0)) == null, "centre block destroyed")
	_check(map.get_block(Vector2i(1, 0)).health.current_health == hp, "small blast spares neighbours")
	_check(map.block_count() == 4, "map forgets destroyed blocks (got %d)" % map.block_count())
	# A 12 px blast reaches cells 1 and 3 but not 0 and 4 (24 px away).
	map.damage_area(centre, 12.0, 5)
	await _frames(1)
	_check(map.get_block(Vector2i(1, 0)).health.current_health == hp - 5, "blast damages left neighbour")
	_check(map.get_block(Vector2i(3, 0)).health.current_health == hp - 5, "blast damages right neighbour")
	_check(map.get_block(Vector2i(0, 0)).health.current_health == hp, "blocks outside the radius are untouched")
	map.queue_free()
	await _frames(1)


## A player standing next to a block breaks it with melee swings.
func _test_melee_breaks_block() -> void:
	var map := _spawn_map(PackedStringArray([
		"...#",
		"XXXX",
	]))
	await _frames(1)
	var player = load("res://scenes/characters/player.tscn").instantiate()
	player.is_controlled = false
	player.position = map.cell_to_world(Vector2i(1, 1)) - Vector2(0, 8)
	root.add_child(player)
	await _frames(10)
	var block := map.get_block(Vector2i(3, 0))
	var hp: int = block.health.max_health
	var swings := 0
	while is_instance_valid(block) and not block.is_queued_for_deletion() and swings < 10:
		player.start_attack()
		await _frames(30)
		swings += 1
	_check(swings > 1, "block survives the first swing")
	_check(map.get_block(Vector2i(3, 0)) == null, "melee breaks the block after %d swings (hp %d)" % [swings, hp])
	_check(player.health.current_health == player.health.max_health, "player is not hurt by hitting blocks")
	player.queue_free()
	map.queue_free()
	await _frames(1)


func _test_player_falls_through_hole() -> void:
	var map := _spawn_map(PackedStringArray(["#####"]))
	map.position = Vector2(0, 100)
	await _frames(1)
	var centre := map.to_global(map.cell_to_world(Vector2i(2, 0)))
	var player = load("res://scenes/characters/player.tscn").instantiate()
	player.is_controlled = false
	player.position = centre - Vector2(0, 12)
	root.add_child(player)
	await _frames(20)
	_check(player.is_on_floor(), "player stands on the blocks")
	var y_on_floor: float = player.position.y
	# Open a three-tile hole under the 18 px wide player.
	map.damage_area(centre, 12.0, 999)
	await _frames(20)
	_check(player.position.y > y_on_floor + 16.0, "player falls through the broken tile")
	player.queue_free()
	map.queue_free()
	await _frames(1)
