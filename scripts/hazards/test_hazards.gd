extends SceneTree

## Headless tests for map hazards (TASK-020): fall damage, bottomless drops,
## fire and acid pits, spikes, switchable and cycling flame jets, trap
## switches and crushing blocks, plus the hazards sandbox arena.
## Run: godot --headless --path . -s scripts/hazards/test_hazards.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const FIRE_PIT := preload("res://scenes/hazards/fire_pit.tscn")
const ACID_PIT := preload("res://scenes/hazards/acid_pit.tscn")
const VOID_ZONE := preload("res://scenes/hazards/void_zone.tscn")
const SPIKE_TRAP := preload("res://scenes/hazards/spike_trap.tscn")
const FLAME_JET := preload("res://scenes/hazards/flame_jet.tscn")
const FALLING_BLOCK := preload("res://scenes/hazards/falling_block.tscn")
const TRAP_SWITCH := preload("res://scenes/hazards/trap_switch.tscn")
const ARENA_PATH := "res://scenes/hazards/hazards_test_arena.tscn"
const FLOOR_Y := 160.0

var _ok := true
var _stage: Node2D


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_fall_damage_curve()
	await _test_short_drop_is_safe()
	await _test_long_drop_hurts()
	await _test_fire_pit_burns_and_launches()
	await _test_acid_pit_dissolves()
	await _test_void_and_spikes_kill()
	await _test_flame_jet_trigger()
	await _test_flame_jet_cycle()
	await _test_switch_hit_by_bullet_path()
	await _test_switch_by_melee()
	await _test_switch_cooldown_and_one_shot()
	await _test_falling_block_crushes_grounded_fighter()
	await _test_falling_block_rests_gently()
	await _test_falling_block_hurts_airborne_fighter()
	await _test_hazards_arena()
	print("OK: fall damage, void, fire, acid, spikes, flame jets, trap switches, crushing blocks and hazards arena verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Fresh stage with a metal floor whose top edge is FLOOR_Y.
func _new_stage() -> void:
	if _stage != null:
		_stage.queue_free()
		await process_frame
	_stage = Node2D.new()
	root.add_child(_stage)
	var map := DestructibleMap.new()
	map.layout = PackedStringArray(["XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"])
	map.position = Vector2(0, FLOOR_Y)
	_stage.add_child(map)


func _spawn_player(at: Vector2) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.is_controlled = false
	player.position = at
	_stage.add_child(player)
	return player


func _add(scene: PackedScene, at: Vector2) -> Node2D:
	var node: Node2D = scene.instantiate()
	node.position = at
	_stage.add_child(node)
	return node


func _test_fall_damage_curve() -> void:
	var fall := FallDamage.new()
	_check(fall.damage_for(320.0) == 0, "a normal jump landing (320 px/s) is harmless")
	_check(fall.damage_for(fall.safe_speed) == 0, "landing at the safe speed is harmless")
	_check(fall.damage_for(600.0) > 0, "landing at 600 px/s hurts")
	_check(fall.damage_for(800.0) > fall.damage_for(600.0), "faster landings hurt more")
	fall.free()


func _test_short_drop_is_safe() -> void:
	await _new_stage()
	var player := _spawn_player(Vector2(100, FLOOR_Y - 64))
	await _frames(60)
	_check(player.is_on_floor(), "player landed after a 4-tile drop")
	_check(player.health.current_health == 100, "4-tile drop is harmless (hp %d)" % player.health.current_health)


func _test_long_drop_hurts() -> void:
	await _new_stage()
	var player := _spawn_player(Vector2(100, FLOOR_Y - 240))
	var landings := []
	player.get_node("FallDamage").hard_landing.connect(func(speed, dmg): landings.append([speed, dmg]))
	await _frames(90)
	var hp: int = player.health.current_health
	_check(landings.size() == 1, "a 15-tile drop is one hard landing (%d)" % landings.size())
	_check(hp < 100 and hp > 0, "15-tile drop hurts without killing (hp %d)" % hp)
	await _frames(30)
	_check(player.health.current_health == hp, "standing still after landing costs nothing more")


func _test_fire_pit_burns_and_launches() -> void:
	await _new_stage()
	var pit: HazardZone = _add(FIRE_PIT, Vector2(80, FLOOR_Y - 16))
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	await _frames(3)
	_check(player.health.current_health < 100, "fire pit burns the fighter standing in it")
	_check(player.velocity.y < 0.0 or not player.is_on_floor(), "fire makes the fighter hop out")
	var hurt_by := []
	player.health.damaged.connect(func(_a, source): hurt_by.append(source))
	player.position = Vector2(100, FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _frames(20)
	_check(pit in hurt_by, "fire damage comes from the pit through HealthComponent")


func _test_acid_pit_dissolves() -> void:
	await _new_stage()
	_add(ACID_PIT, Vector2(80, FLOOR_Y - 16))
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	await _frames(60)
	var lost: int = 100 - player.health.current_health
	_check(lost >= 70 and lost <= 85, "acid deals ~80 hp per second (lost %d)" % lost)
	await _frames(30)
	_check(player.health.is_dead(), "staying in acid kills")


func _test_void_and_spikes_kill() -> void:
	await _new_stage()
	_add(VOID_ZONE, Vector2(0, FLOOR_Y - 16))
	var player := _spawn_player(Vector2(20, FLOOR_Y))
	await _frames(3)
	_check(player.health.is_dead(), "falling into the void kills at once")
	var spikes := _add(SPIKE_TRAP, Vector2(160, FLOOR_Y - 8))
	var other := _spawn_player(Vector2(180, FLOOR_Y - 60))
	await _frames(40)
	_check(other.health.is_dead(), "landing on spikes kills")
	_check(spikes.active, "spikes are always armed")


func _test_flame_jet_trigger() -> void:
	await _new_stage()
	var jet: HazardZone = _add(FLAME_JET, Vector2(92, FLOOR_Y - 48))
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	await _frames(20)
	_check(player.health.current_health == 100, "a dormant flame jet is harmless")
	jet.trigger()
	await _frames(10)
	_check(player.health.current_health < 100, "a triggered flame jet burns")
	await _frames(roundi(jet.trigger_duration * 60.0) + 5)
	_check(not jet.active, "the flame jet shuts off after its duration")


func _test_flame_jet_cycle() -> void:
	await _new_stage()
	var jet: HazardZone = FLAME_JET.instantiate()
	jet.cycle_on = 0.2
	jet.cycle_off = 0.3
	_stage.add_child(jet)
	var states := []
	jet.activated.connect(func(): states.append(true))
	jet.deactivated.connect(func(): states.append(false))
	await _frames(65)
	_check(states.size() >= 3 and states[0] == true, "cycling jet pulses on and off (%s)" % [states])


func _test_switch_hit_by_bullet_path() -> void:
	await _new_stage()
	var block: FallingBlock = _add(FALLING_BLOCK, Vector2(40, 40))
	var jet: HazardZone = _add(FLAME_JET, Vector2(200, FLOOR_Y - 48))
	var switch: TrapSwitch = _add(TRAP_SWITCH, Vector2(120, 100))
	switch.targets = [switch.get_path_to(block), switch.get_path_to(jet)]
	# Bullets and blasts land through Hurtbox.receive_hit.
	switch.get_node("Hurtbox").receive_hit(10, Vector2.ZERO, null)
	_check(not block.held, "a hit on the switch releases the block")
	_check(jet.active, "a hit on the switch fires the flame jet")
	_check(switch.get_node("HealthComponent").current_health == 100000, "the switch never wears out")
	await _frames(60)
	_check(block.position.y > 100.0, "the released block falls (y %.0f)" % block.position.y)


func _test_switch_by_melee() -> void:
	await _new_stage()
	var jet: HazardZone = _add(FLAME_JET, Vector2(300, FLOOR_Y - 48))
	var switch: TrapSwitch = _add(TRAP_SWITCH, Vector2(116, FLOOR_Y - 17))
	switch.targets = [switch.get_path_to(jet)]
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	await _frames(5)
	player.start_attack()
	await _frames(20)
	_check(jet.active, "punching the switch fires its trap")


func _test_switch_cooldown_and_one_shot() -> void:
	await _new_stage()
	var switch: TrapSwitch = _add(TRAP_SWITCH, Vector2(100, 100))
	var count := [0]
	switch.switched.connect(func(_by): count[0] += 1)
	switch.activate()
	switch.activate()
	_check(count[0] == 1, "a switch recharging ignores hits")
	await _frames(roundi(switch.cooldown * 60.0) + 2)
	switch.activate()
	_check(count[0] == 2, "a recharged switch fires again")
	var once: TrapSwitch = _add(TRAP_SWITCH, Vector2(200, 100))
	once.one_shot = true
	once.cooldown = 0.0
	once.activate()
	await _frames(2)
	once.activate()
	_check(not once.can_activate(), "a one-shot switch stays down")


func _test_falling_block_crushes_grounded_fighter() -> void:
	await _new_stage()
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	var block: FallingBlock = _add(FALLING_BLOCK, Vector2(84, FLOOR_Y - 140))
	var crushed := []
	block.crushed.connect(func(body): crushed.append(body))
	var killer := []
	player.health.died.connect(func(source): killer.append(source))
	await _frames(5)
	block.trigger()
	await _frames(60)
	_check(player.health.is_dead(), "a block falling on a grounded fighter crushes it")
	_check(killer == [block], "the crush kill is credited to the block")
	_check(crushed == [player], "the block reports the crush")
	_check(absf(block.position.y + block.size.y - FLOOR_Y) < 0.5, "the block ends on the floor (bottom %.1f)" % (block.position.y + block.size.y))
	_check(_stage.get_child(0).block_count() == 30, "the block doesn't break the tiles it lands on")


func _test_falling_block_rests_gently() -> void:
	await _new_stage()
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	# Two pixels above the head: too slow to hurt when it touches.
	var block: FallingBlock = _add(FALLING_BLOCK, Vector2(84, FLOOR_Y - 30 - 16 - 2))
	await _frames(5)
	block.trigger()
	await _frames(30)
	_check(player.health.current_health == 100, "a block settling on a head is harmless")


func _test_falling_block_hurts_airborne_fighter() -> void:
	await _new_stage()
	var player := _spawn_player(Vector2(100, FLOOR_Y))
	var block: FallingBlock = _add(FALLING_BLOCK, Vector2(84, FLOOR_Y - 200))
	block.held = false
	await _frames(18)
	# Jump into the block as it comes down.
	player.velocity.y = player.jump_velocity
	var hits := []
	player.health.damaged.connect(func(amount, source): hits.append([amount, source]))
	await _frames(40)
	_check(hits.size() >= 1 and hits[0][1] == block, "a block hitting a fighter in mid-air hurts it (%s)" % [hits])


func _test_hazards_arena() -> void:
	if _stage != null:
		_stage.queue_free()
		_stage = null
	var arena: Node2D = load(ARENA_PATH).instantiate()
	arena.autostart = false
	root.add_child(arena)
	await _frames(2)
	var kinds := {}
	for zone in arena.find_children("*", "HazardZone", true, false):
		kinds[zone.kind] = true
		_check(zone.is_in_group(HazardZone.GROUP), "%s is in the hazards group for bots" % zone.name)
	_check(kinds.has(HazardZone.Kind.VOID) and kinds.has(HazardZone.Kind.FIRE) and kinds.has(HazardZone.Kind.ACID), "arena has void, fire and acid")
	var switches := arena.find_children("*", "TrapSwitch", true, false)
	_check(switches.size() >= 2, "arena has trap switches (%d)" % switches.size())
	for switch: TrapSwitch in switches:
		for path in switch.targets:
			var target := switch.get_node_or_null(path)
			_check(target != null and target.has_method("trigger"), "switch %s target %s is wired" % [switch.name, path])
	_check(arena.find_children("*", "FallingBlock", true, false).size() >= 1, "arena has a falling block")
	# A fighter (18x30, origin at the feet) must not spawn inside a hazard.
	for marker: Marker2D in arena.get_node("Spawns").get_children():
		var body := Rect2(marker.global_position - Vector2(9, 30), Vector2(18, 30))
		for zone: HazardZone in arena.find_children("*", "HazardZone", true, false):
			var zone_rect := Rect2(zone.global_position, zone.size)
			_check(not body.intersects(zone_rect), "spawn %s is clear of %s" % [marker.name, zone.name])
	arena.queue_free()
