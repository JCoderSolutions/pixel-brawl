extends SceneTree

## Headless tests for block materials (TASK-019): wood breaks from bullets
## and blasts; brick only from blasts; metal never; melee breaks none. Also checks the
## real match arena is built from tiles, so grenades crater its floor and
## platforms. Run: godot --headless --path . -s scripts/test_materials.gd

const WOOD := preload("res://scenes/maps/materials/wood.tres")
const BRICK := preload("res://scenes/maps/materials/brick.tres")
const METAL := preload("res://scenes/maps/materials/metal.tres")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const GRENADE := preload("res://scripts/weapons/data/grenade.tres")
const PROJECTILE_SCENE := preload("res://scenes/items/projectile.tscn")
const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const ARENA_PATH := "res://scenes/maps/test_arena.tscn"

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_material_data()
	await _test_layout_legend()
	await _test_bullets_break_wood_only()
	await _test_melee_leaves_the_map()
	await _test_blasts_break_wood_and_brick()
	await _test_planks_are_one_way()
	await _test_arena_is_built_from_tiles()
	await _test_grenade_craters_arena_floor()
	await _test_grenade_breaks_arena_platform()
	print("OK: material data, layout legend, bullets/melee/blasts per material, one-way planks, tile arena and grenade craters in the match arena verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _spawn_map(layout: PackedStringArray, at := Vector2.ZERO) -> DestructibleMap:
	var map := DestructibleMap.new()
	map.layout = layout
	map.position = at
	root.add_child(map)
	return map


func _alive(map: DestructibleMap, cell: Vector2i) -> bool:
	var block := map.get_block(cell)
	return block != null and not block.is_queued_for_deletion()


func _hurt(map: DestructibleMap, cell: Vector2i) -> bool:
	var block := map.get_block(cell)
	return block != null and block.health.current_health < block.health.max_health


func _fire(from: Vector2, direction: Vector2) -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	root.add_child(projectile)
	projectile.setup(from, direction, PISTOL, null, [])
	await _frames(4)


func _blast(at: Vector2) -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.configure(GRENADE)
	root.add_child(explosion)
	explosion.global_position = at
	explosion.detonate()
	await _frames(2)


func _test_material_data() -> void:
	_check(WOOD.breaks_from_hits and WOOD.breaks_from_blasts, "wood breaks from hits and blasts")
	_check(not BRICK.breaks_from_hits and BRICK.breaks_from_blasts, "brick only breaks from blasts")
	for material in [WOOD, BRICK, METAL]:
		_check(not material.breaks_from_melee, "%s shrugs off fists and blades" % material.display_name)
	_check(METAL.is_indestructible(), "metal never breaks")
	_check(WOOD.color != BRICK.color and BRICK.color != METAL.color and WOOD.color != METAL.color,
		"each material has its own colour")
	_check(BRICK.max_health <= GRENADE.block_damage, "one grenade breaks a brick next to it")


func _test_layout_legend() -> void:
	var map := _spawn_map(PackedStringArray(["#B X="]))
	await _frames(1)
	_check(map.get_block(Vector2i(0, 0)).block_material == WOOD, "# builds wood")
	_check(map.get_block(Vector2i(1, 0)).block_material == BRICK, "B builds brick")
	_check(map.get_block(Vector2i(2, 0)) == null, "spaces stay empty")
	_check(map.get_block(Vector2i(3, 0)).block_material == METAL and map.get_block(Vector2i(3, 0)).indestructible,
		"X builds indestructible metal")
	var plank := map.get_block(Vector2i(4, 0))
	_check(plank.block_material == WOOD and plank.one_way, "= builds a one-way wooden plank")
	_check(map.get_block(Vector2i(0, 0)).get_node("Visual").color == WOOD.color, "wood tile is drawn in the wood colour")
	_check(map.get_block(Vector2i(1, 0)).get_node("Visual").color == BRICK.color, "brick tile is drawn in the brick colour")
	map.queue_free()
	await _frames(1)


## Shoots a pistol bullet along the row into each material.
func _test_bullets_break_wood_only() -> void:
	var map := _spawn_map(PackedStringArray(["....#", "....B", "....X"]), Vector2(0, 100))
	await _frames(2)
	for row in 3:
		var cell := Vector2i(4, row)
		var from := map.to_global(map.cell_to_world(Vector2i(0, row)))
		await _fire(from, Vector2.RIGHT)
		_check(map.get_block(cell) != null, "bullet stops at the %s tile" % ["wood", "brick", "metal"][row])
	_check(_hurt(map, Vector2i(4, 0)), "bullets chip wood")
	_check(not _hurt(map, Vector2i(4, 1)), "bullets bounce off brick")
	_check(not _hurt(map, Vector2i(4, 2)), "bullets bounce off metal")
	var from := map.to_global(map.cell_to_world(Vector2i(0, 0)))
	for i in 5:
		await _fire(from, Vector2.RIGHT)
	_check(not _alive(map, Vector2i(4, 0)), "enough bullets break a wooden door")
	map.queue_free()
	await _frames(1)


## Fists don't dig through the map, whatever it is made of (Superfighters).
func _test_melee_leaves_the_map() -> void:
	for code in ["#", "B"]:
		var map := _spawn_map(PackedStringArray(["...%s" % code, "XXXX"]))
		await _frames(1)
		var player = PLAYER_SCENE.instantiate()
		player.is_controlled = false
		player.position = map.cell_to_world(Vector2i(1, 1)) - Vector2(0, 8)
		root.add_child(player)
		await _frames(10)
		for i in 6:
			player.start_attack()
			await _frames(30)
		var name: String = "wood" if code == "#" else "brick"
		_check(_alive(map, Vector2i(3, 0)) and not _hurt(map, Vector2i(3, 0)), "punches don't dent %s" % name)
		player.queue_free()
		map.queue_free()
		await _frames(1)


func _test_blasts_break_wood_and_brick() -> void:
	var map := _spawn_map(PackedStringArray(["#BX"]), Vector2(0, 100))
	await _frames(1)
	await _blast(map.to_global(map.cell_to_world(Vector2i(1, 0))))
	_check(not _alive(map, Vector2i(0, 0)), "blast breaks wood")
	_check(not _alive(map, Vector2i(1, 0)), "blast breaks brick")
	_check(_alive(map, Vector2i(2, 0)), "blast leaves metal standing")
	map.queue_free()
	await _frames(1)


## A fighter jumps up through a plank from below and then stands on it.
func _test_planks_are_one_way() -> void:
	var map := _spawn_map(PackedStringArray(["====", "", "", "XXXX"]), Vector2(0, 100))
	await _frames(1)
	var frames: Array[InputFrame] = []
	for i in 5:
		frames.append(InputFrame.create(0.0, 0))
	for i in 30:
		frames.append(InputFrame.create(0.0, InputFrame.JUMP))
	for i in 40:
		frames.append(InputFrame.create(0.0, 0))
	var player = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(frames)
	player.position = map.to_global(Vector2(32, 48))
	root.add_child(player)
	await _frames(80)
	var plank_top: float = map.global_position.y
	_check(player.is_on_floor() and absf(player.global_position.y - plank_top) < 1.0,
		"player jumps through the plank and lands on it (y = %.1f, top %.1f)" % [player.global_position.y, plank_top])
	player.queue_free()
	map.queue_free()
	await _frames(1)


func _arena() -> Node2D:
	var arena: Node2D = load(ARENA_PATH).instantiate()
	arena.autostart = false
	root.add_child(arena)
	return arena


## Floor and platforms are tiles now, not plain static bodies.
func _test_arena_is_built_from_tiles() -> void:
	var arena := _arena()
	await _frames(1)
	var bodies := arena.get_children().filter(func(n): return n is StaticBody2D)
	_check(bodies.is_empty(), "arena has no loose static bodies outside the tile map (found %s)" % [bodies])
	var map: DestructibleMap = arena.get_node("DestructibleMap")
	var floor_cell := map.world_to_cell(Vector2(240, 258))
	_check(map.get_block(floor_cell) != null and map.get_block(floor_cell).block_material == BRICK, "arena floor is brick")
	_check(map.get_block(floor_cell + Vector2i.DOWN) != null and map.get_block(floor_cell + Vector2i.DOWN).indestructible,
		"a metal bed under the floor keeps fighters in the map")
	arena.queue_free()
	await _frames(1)


## Jose's report: grenades thrown in the match left the arena untouched.
func _test_grenade_craters_arena_floor() -> void:
	var arena := _arena()
	await _frames(2)
	var map: DestructibleMap = arena.get_node("DestructibleMap")
	var before := map.block_count()
	var floor_cell := map.world_to_cell(Vector2(240, 258))
	await _blast(Vector2(240, 246))
	_check(map.get_block(floor_cell) == null, "grenade breaks the arena floor under it")
	_check(map.get_block(floor_cell + Vector2i.DOWN) != null, "metal bed survives the blast")
	_check(map.block_count() < before - 2, "grenade leaves a crater (%d -> %d)" % [before, map.block_count()])
	arena.queue_free()
	await _frames(1)


func _test_grenade_breaks_arena_platform() -> void:
	var arena := _arena()
	await _frames(2)
	var map: DestructibleMap = arena.get_node("DestructibleMap")
	var plank_cell := map.world_to_cell(Vector2(120, 206))
	_check(map.get_block(plank_cell) != null and map.get_block(plank_cell).one_way, "left platform is made of planks")
	await _blast(Vector2(120, 196))
	_check(map.get_block(plank_cell) == null, "grenade breaks the platform")
	arena.queue_free()
	await _frames(1)
