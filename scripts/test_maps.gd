extends SceneTree

## Headless tests for the map set (TASK-009): the catalog, every map loads with
## a 960x544 playfield the camera can frame, its own kill zone, four spawns on
## safe ground, weapon points on the floor, hazards and switches wired up,
## every spawn and weapon point reachable on foot, a bots-only match that
## ends in each map, and the menu's map choice.
## Run: godot --headless --path . -s scripts/test_maps.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const ARENA_PATH := "res://scenes/maps/test_arena.tscn"
## The big themed maps; the first arena predates them and keeps its size.
const BIG_MAPS := [
	"res://scenes/maps/factory.tscn",
	"res://scenes/maps/rooftop.tscn",
	"res://scenes/maps/lab.tscn",
	"res://scenes/maps/foundry.tscn",
]
## Every weapon in scripts/weapons/data/ drops in every map.
const ALL_WEAPONS := [&"pistol", &"shotgun", &"katana", &"grenade", &"assault_rifle", &"sawed_off", &"bat", &"bazooka", &"molotov"]
const TILE := 16
## Movement limits in tiles, from the player (~57 px jump, ~100 px long jump).
const JUMP_ROWS := 3
const JUMP_COLS := 3
const LEAP_COLS := 5
## Frames a bots-only match gets to crown a winner (one round wins it); the
## maps take 650-2700 (a round can end in a draw and be replayed: factory
## draws twice with the seeded drops), and the whole file must fit
## tools/run_tests.sh's 120 s.
const MATCH_FRAMES := 60 * 55
## Bots are seeded by id; seeding the weapon drops too makes each match replay
## the same way, so a rare stand-off can't make the test flaky.
const SPAWNER_SEED := 1

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_catalog()
	for path in BIG_MAPS:
		await _test_map_layout(path)
		await _test_spawns_are_safe(path)
		_test_reachable_on_foot(path)
	await _test_menu_map_choice()
	for path in BIG_MAPS:
		await _test_bots_finish_a_match(path)
	print("OK: map catalog, 960x544 maps with camera bounds and kill zone, safe spawns, weapon points, wired hazards and switches, reachable spawns, bots-only matches and menu map choice verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _gm() -> Node:
	return root.get_node("/root/GameManager")


func _map_name(path: String) -> String:
	return path.get_file().get_basename()


func _load_map(path: String) -> Node2D:
	var map: Node2D = load(path).instantiate()
	map.autostart = false
	map.get_node("TouchControls").visibility = TouchControls.Visibility.NEVER
	root.add_child(map)
	return map


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _test_catalog() -> void:
	_check(MapCatalog.size() >= 5, "catalog lists the arena and the four themed maps")
	var paths := []
	for i in MapCatalog.size():
		paths.append(MapCatalog.path(i))
		_check(ResourceLoader.exists(MapCatalog.path(i)), "%s exists" % MapCatalog.path(i))
		_check(MapCatalog.display_name(i) != "", "map %d has a name" % i)
	_check(ARENA_PATH in paths, "the first arena stays playable")
	for path in BIG_MAPS:
		_check(path in paths, "%s is in the catalog" % _map_name(path))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var picked := {}
	for i in 60:
		picked[MapCatalog.random_path(rng)] = true
	_check(picked.size() == MapCatalog.size(), "random choice covers every map (%d)" % picked.size())


func _test_map_layout(path: String) -> void:
	var name := _map_name(path)
	var map := _load_map(path)
	await process_frame
	var camera: SharedCamera = map.get_node("SharedCamera")
	var grid: DestructibleMap = map.get_node("DestructibleMap")
	_check(camera.bounds.size.x >= 960.0 and camera.bounds.size.y >= 540.0,
		"%s is big enough for the camera to zoom out (%s)" % [name, camera.bounds])
	_check(grid.block_count() > 100, "%s builds its tiles (%d)" % [name, grid.block_count()])
	for line in grid.layout:
		_check(line.length() * TILE <= camera.bounds.end.x, "%s layout fits the bounds" % name)
	_check(grid.layout.size() * TILE <= camera.bounds.end.y, "%s layout fits the bounds vertically" % name)
	_check(map.kill_zone_y > camera.bounds.end.y, "%s kill zone sits below the map (%.0f)" % [name, map.kill_zone_y])
	_check(map.get_node("Background").size == camera.bounds.size, "%s background covers the map" % name)

	var hazards := map.get_node("Hazards").get_children()
	var zones := hazards.filter(func(h): return h is HazardZone)
	_check(zones.size() >= 2, "%s has hazards (%d)" % [name, zones.size()])
	_check(zones.all(func(z): return z.is_in_group(HazardZone.GROUP)), "%s hazards are visible to bots" % name)
	var switches := hazards.filter(func(h): return h is TrapSwitch)
	_check(not switches.is_empty(), "%s has an actionable trap" % name)
	for switch in switches:
		_check(not switch.targets.is_empty(), "%s: %s has targets" % [name, switch.name])
		for target_path in switch.targets:
			var target: Node = switch.get_node_or_null(target_path)
			_check(target != null and target.has_method("trigger"), "%s: %s -> %s is a trap" % [name, switch.name, target_path])

	var spawner: WeaponSpawner = map.get_node("WeaponSpawner")
	_check(spawner.weapons.any(func(w): return w is GrenadeData), "%s spawns grenades" % name)
	for weapon_path in DirAccess.get_files_at("res://scripts/weapons/data"):
		var weapon := load("res://scripts/weapons/data/" + weapon_path.trim_suffix(".remap"))
		_check(weapon in spawner.weapons, "%s spawns %s" % [name, weapon_path.get_basename()])
	_check(not spawner.power_ups.is_empty(), "%s spawns power-ups" % name)
	var space := map.get_world_2d().direct_space_state
	for marker in spawner.get_children():
		if marker is Marker2D:
			var from: Vector2 = marker.global_position
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40), 1)
			var hit := space.intersect_ray(query)
			_check(not hit.is_empty(), "%s: weapon point %s sits over the floor" % [name, marker.name])
			_check(camera.bounds.has_point(from), "%s: weapon point %s is inside the map" % [name, marker.name])
	await _free(map)


func _test_spawns_are_safe(path: String) -> void:
	var name := _map_name(path)
	var map := _load_map(path)
	var spawns: Array = map.get_node("Spawns").get_children()
	_check(spawns.size() >= 4, "%s has a spawn per player (%d)" % [name, spawns.size()])
	var players := []
	for marker in spawns:
		var player = PLAYER_SCENE.instantiate()
		player.is_controlled = false
		player.position = marker.position
		map.get_node("Players").add_child(player)
		players.append(player)
	await _frames(90)
	for i in players.size():
		var player = players[i]
		var spot: Vector2 = spawns[i].position
		_check(player.is_on_floor(), "%s: spawn %d stands on the floor" % [name, i + 1])
		_check(player.global_position.distance_to(spot) < 4.0,
			"%s: spawn %d is where the marker is (%s vs %s)" % [name, i + 1, player.global_position, spot])
		_check(player.health.current_health == player.health.max_health, "%s: spawn %d is out of harm's way" % [name, i + 1])
	await _free(map)


## Walks the layout as a graph of tiles a fighter can stand on and checks
## every spawn and weapon point can be reached from the first spawn.
func _test_reachable_on_foot(path: String) -> void:
	var name := _map_name(path)
	var map: Node2D = load(path).instantiate()
	var layout: PackedStringArray = map.get_node("DestructibleMap").layout
	var danger: Array[Rect2] = []
	for hazard in map.get_node("Hazards").get_children():
		# Traps that switch off (timers, switches) can be crossed.
		if hazard is HazardZone and hazard.active and hazard.cycle_on <= 0.0:
			danger.append(Rect2(hazard.position, hazard.size))
	var stand := {}
	for row in layout.size():
		for col in layout[row].length():
			var cell := Vector2i(col, row)
			var feet := Vector2(col * TILE + TILE / 2.0, row * TILE - 2.0)
			if _tile(layout, cell) != "." and not _solid(layout, cell + Vector2i.UP) \
					and not _solid(layout, cell + Vector2i.UP * 2) and not danger.any(func(r): return r.has_point(feet)):
				stand[cell] = true
	var start := _cell_under(stand, map.get_node("Spawns").get_child(0).position)
	var reached := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var from: Vector2i = queue.pop_back()
		for to in stand:
			if not reached.has(to) and _can_move(from, to):
				reached[to] = true
				queue.append(to)
	var points: Array = map.get_node("Spawns").get_children()
	points.append_array(map.get_node("WeaponSpawner").get_children())
	for point in points:
		var cell := _cell_under(stand, point.position)
		_check(reached.has(cell), "%s: %s at %s is reachable on foot" % [name, point.name, point.position])
	# A fighter standing on a ledge right above a weapon can neither reach it
	# nor tell it is out of reach, so bots would wait there forever.
	for marker in map.get_node("WeaponSpawner").get_children():
		var cell := _cell_under(stand, marker.position)
		for rise in range(1, JUMP_ROWS + 1):
			for dx in [-1, 0, 1]:
				_check(not stand.has(cell + Vector2i(dx, -rise)),
					"%s: nothing to stand on right above weapon point %s" % [name, marker.name])
	map.free()


func _tile(layout: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return "."
	return layout[cell.y][cell.x]


## One-way planks let fighters jump through; the rest blocks them.
func _solid(layout: PackedStringArray, cell: Vector2i) -> bool:
	return not _tile(layout, cell) in [".", "="]


## First standable tile at or below a point (spawns sit on the surface).
func _cell_under(stand: Dictionary, point: Vector2) -> Vector2i:
	var col := floori(point.x / TILE)
	for row in range(ceili(point.y / TILE), 64):
		if stand.has(Vector2i(col, row)):
			return Vector2i(col, row)
	return Vector2i(-1, -1)


func _can_move(from: Vector2i, to: Vector2i) -> bool:
	var dx := absi(to.x - from.x)
	var rise := from.y - to.y
	if rise > 0:
		return rise <= JUMP_ROWS and dx <= JUMP_COLS
	return dx <= LEAP_COLS


func _test_menu_map_choice() -> void:
	var menu = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_counts(1, 1)
	menu.open_setup()
	menu.next()
	_check(menu.step == menu.Step.MAP, "the setup reaches the map step")
	_check(menu.get_node("%Content").get_child(0).get_child_count() == MapCatalog.size() + 1,
			"menu lists every map plus a random pick")
	for i in MapCatalog.size():
		menu.select_map(i + 1)
		menu.apply_selection()
		_check(menu.match_scene == MapCatalog.path(i), "menu option %d plays %s" % [i + 1, MapCatalog.path(i)])
	menu.select_map(0)
	var seen := {}
	for i in 40:
		menu.apply_selection()
		seen[menu.match_scene] = true
	_check(seen.size() > 1 and seen.keys().all(func(p): return p in BIG_MAPS or p == ARENA_PATH),
		"random pick changes between matches (%d maps)" % seen.size())
	await _free(menu)
	_gm().configure_bots(0, BotProfile.Difficulty.NORMAL)


func _test_bots_finish_a_match(path: String) -> void:
	var name := _map_name(path)
	var manager := _gm()
	var saved_rounds: int = manager.rounds_to_win
	manager.rounds_to_win = 1
	manager.configure_bots(4, BotProfile.Difficulty.HARD, 0)
	var map: Node2D = load(path).instantiate()
	map.get_node("TouchControls").visibility = TouchControls.Visibility.NEVER
	map.get_node("WeaponSpawner").rng_seed = SPAWNER_SEED
	root.add_child(map)
	var result := {"winner": -2, "rounds": 0}
	var on_end := func(winner: int) -> void: result.winner = winner
	var on_round := func(_winner: int) -> void: result.rounds += 1
	manager.match_ended.connect(on_end)
	manager.round_ended.connect(on_round)
	_check(manager.get_player_ids().size() == 4, "%s spawns four bots" % name)
	_check(is_equal_approx(manager.kill_zone_y, map.kill_zone_y), "%s hands its kill zone to the GameManager" % name)
	var frames := 0
	while result.winner == -2 and frames < MATCH_FRAMES:
		await physics_frame
		frames += 1
	_check(result.rounds >= 1, "%s: bots finish a round (%d frames)" % [name, frames])
	_check(result.winner >= 0, "%s: bots finish the match (%d frames, %d rounds)" % [name, frames, result.rounds])
	print("%s: bots match ended in %d frames (%d rounds)" % [name, frames, result.rounds])
	manager.match_ended.disconnect(on_end)
	manager.round_ended.disconnect(on_round)
	await _free(map)
	manager.rounds_to_win = saved_rounds
	manager.configure_bots(0, BotProfile.Difficulty.NORMAL)
