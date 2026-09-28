extends SceneTree

## Headless tests for GameFeel + ImpactBurst (TASK-012): every gameplay
## signal plays the right sound and particles, hit-stop bends and restores
## Engine.time_scale in real time, and fighters' jumps/landings are detected
## without touching player.gd.
## Run: godot --headless --path . -s scripts/audio/test_game_feel.gd

const GameFeelScript := preload("res://scenes/effects/game_feel.gd")
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const DUMMY_SCENE := preload("res://scenes/items/target_dummy.tscn")
const BLOCK_SCENE := preload("res://scenes/maps/destructible_block.tscn")
const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const SHOTGUN := preload("res://scripts/weapons/data/shotgun.tres")
const KATANA := preload("res://scripts/weapons/data/katana.tres")
const GRENADE := preload("res://scripts/weapons/data/grenade.tres")

var _ok := true
var _played: Array[StringName] = []
var _feel: Node


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var audio := root.get_node("AudioManager")
	audio.min_interval = 0.0
	audio.sfx_played.connect(func(n: StringName) -> void: _played.append(n))
	_feel = GameFeelScript.new()
	_feel.auto_wire = false
	root.add_child(_feel)
	_feel.auto_wire = true
	get_tree_node_added()

	_test_bursts()
	await _test_melee_hit_and_hit_stop()
	await _test_hit_on_block()
	await _test_projectile_impacts()
	await _test_weapon_sounds()
	await _test_explosion_breaks_blocks()
	await _test_player_death()
	await _test_jump_and_land()
	_test_wire_once()
	print("OK: impact bursts, melee hit + hit-stop, block thud, projectile flesh/ricochet, weapon sounds, explosion + debris, death, jump/landing and single wiring verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Headless GameFeel doesn't auto-wire; wire new nodes the same way it would.
func get_tree_node_added() -> void:
	node_added.connect(_feel.wire)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _bursts(kind: int) -> int:
	var count := 0
	for child in _feel.get_children():
		if child is ImpactBurst and child.kind == kind:
			count += 1
	return count


func _reset() -> void:
	_played.clear()
	for child in _feel.get_children():
		child.free()
	_feel.advance_real(10.0)


func _arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(2000, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)
	return arena


func _test_bursts() -> void:
	for kind in ImpactBurst.Kind.values():
		var burst := ImpactBurst.spawn(root, kind, Vector2(10, 20), Vector2.RIGHT)
		_check(burst.emitting and burst.one_shot, "burst %d emits once" % kind)
		_check(burst.amount > 0 and burst.lifetime > 0.0, "burst %d has particles" % kind)
		_check(burst.global_position == Vector2(10, 20), "burst %d spawns where asked" % kind)
		_check(burst.direction == Vector2.RIGHT, "burst %d follows the direction" % kind)
		burst._process(burst.lifetime + 0.2)
		_check(burst.is_queued_for_deletion(), "burst %d frees itself after its lifetime" % kind)


func _test_melee_hit_and_hit_stop() -> void:
	_reset()
	var arena := _arena()
	var dummy: Node2D = DUMMY_SCENE.instantiate()
	arena.add_child(dummy)
	var hitbox := Hitbox.new()
	arena.add_child(hitbox)
	hitbox.hit_landed.emit(dummy.get_node("Hurtbox"))
	_check(_played == [&"punch"], "melee hit plays punch (got %s)" % [_played])
	_check(_bursts(ImpactBurst.Kind.HIT) == 1, "melee hit spawns a hit burst")
	_check(_feel.is_hit_stopped() and is_equal_approx(Engine.time_scale, _feel.hit_stop_scale), "melee hit starts a hit-stop")
	_feel.hit_stop(0.01)
	_feel.advance_real(_feel.melee_hit_stop * 0.5)
	_check(_feel.is_hit_stopped(), "a shorter request doesn't cut the running hit-stop")
	_feel.advance_real(_feel.melee_hit_stop)
	_check(not _feel.is_hit_stopped() and Engine.time_scale == 1.0, "hit-stop ends and restores time_scale")
	_feel.hit_stop_enabled = false
	_feel.hit_stop(0.5)
	_check(Engine.time_scale == 1.0, "hit-stop can be switched off")
	_feel.hit_stop_enabled = true
	# Real frames: _process must count down in real time even while slowed.
	_feel.hit_stop(0.05)
	await create_timer(0.3, true, false, true).timeout
	_check(Engine.time_scale == 1.0, "hit-stop recovers on its own through _process")
	arena.queue_free()
	await process_frame


func _test_hit_on_block() -> void:
	_reset()
	var arena := _arena()
	var block: DestructibleBlock = BLOCK_SCENE.instantiate()
	arena.add_child(block)
	var hitbox := Hitbox.new()
	arena.add_child(hitbox)
	hitbox.hit_landed.emit(block.get_node("Hurtbox"))
	_check(_played == [&"block_hit"], "hitting a tile plays a thud")
	_check(_bursts(ImpactBurst.Kind.DUST) == 1, "hitting a tile raises dust")
	_check(not _feel.is_hit_stopped(), "tiles don't trigger hit-stop")
	arena.queue_free()
	await process_frame


func _test_projectile_impacts() -> void:
	_reset()
	var arena := _arena()
	var dummy: Node2D = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(100, 0)
	arena.add_child(dummy)
	var at_dummy: Projectile = preload("res://scenes/items/projectile.tscn").instantiate()
	arena.add_child(at_dummy)
	at_dummy.setup(Vector2(0, -12), Vector2.RIGHT, PISTOL, null, [])
	var at_floor: Projectile = preload("res://scenes/items/projectile.tscn").instantiate()
	arena.add_child(at_floor)
	at_floor.setup(Vector2(-200, -30), Vector2(0.2, 1.0), PISTOL, null, [])
	await _frames(10)
	_check(&"hit" in _played, "bullet into a fighter/prop plays hit (got %s)" % [_played])
	_check(&"ricochet" in _played, "bullet into the floor ricochets (got %s)" % [_played])
	_check(_bursts(ImpactBurst.Kind.HIT) >= 1 and _bursts(ImpactBurst.Kind.SPARK) >= 1, "bullets spawn hit and spark bursts")
	arena.queue_free()
	await process_frame


func _test_weapon_sounds() -> void:
	_reset()
	var arena := _arena()
	var holder := WeaponHolder.new()
	arena.add_child(holder)
	holder.equip(PISTOL)
	_check(_played == [&"pickup"], "equipping plays pickup (got %s)" % [_played])
	var expected := {PISTOL: &"shot", SHOTGUN: &"shotgun", KATANA: &"swing", GRENADE: &"throw"}
	for data in expected:
		_played.clear()
		holder.fired.emit(data, 0 if data == KATANA else data.projectiles_per_shot)
		_check(_played == [expected[data]], "%s plays %s (got %s)" % [data.id, expected[data], _played])
	_check(_bursts(ImpactBurst.Kind.SPARK) == 2, "guns flash at the muzzle, melee and throws don't")
	arena.queue_free()
	await process_frame


func _test_explosion_breaks_blocks() -> void:
	_reset()
	var arena := _arena()
	var map := DestructibleMap.new()
	map.layout = PackedStringArray(["##", "##"])
	map.position = Vector2(0, -40)
	arena.add_child(map)
	await _frames(2)
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	arena.add_child(explosion)
	explosion.global_position = map.cell_to_world(Vector2i(1, 1))
	explosion.block_damage = 100
	explosion.detonate()
	await process_frame
	_check(_played.count(&"explosion") == 1, "explosion plays once (got %s)" % [_played])
	_check(_played.count(&"block_break") >= 1, "broken tiles crunch (got %s)" % [_played])
	_check(not &"death" in _played, "tiles dying don't play the death jingle")
	_check(_bursts(ImpactBurst.Kind.EXPLOSION) == 1, "explosion spawns a blast burst")
	var broken := 4 - map.block_count()
	_check(broken > 0 and _bursts(ImpactBurst.Kind.DEBRIS) == broken, "each broken tile spawns debris (%d broken, %d bursts)" % [broken, _bursts(ImpactBurst.Kind.DEBRIS)])
	_check(_feel.is_hit_stopped(), "explosions trigger a hit-stop")
	_feel.advance_real(1.0)
	arena.queue_free()
	await process_frame


func _test_player_death() -> void:
	_reset()
	var arena := _arena()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.is_controlled = false
	arena.add_child(player)
	player.health.take_damage(9999)
	_check(&"death" in _played, "a fighter dying plays death (got %s)" % [_played])
	arena.queue_free()
	await _frames(2)


func _test_jump_and_land() -> void:
	_reset()
	var arena := _arena()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	var frames: Array[InputFrame] = []
	for i in 30:
		frames.append(InputFrame.new())
	# Held for a full jump: a tapped jump is a short hop that lands softly.
	for i in 25:
		frames.append(InputFrame.create(0.0, InputFrame.JUMP))
	player.input_source = ScriptedInputSource.new(frames)
	player.position = Vector2(0, -60)
	arena.add_child(player)
	# The feel's own _physics_process (priority 100) runs the detector after
	# the player has moved each tick.
	var landed_first := false
	var jumped := false
	var landed_again := false
	var dust_seen := 0
	for i in 120:
		await physics_frame
		dust_seen = maxi(dust_seen, _bursts(ImpactBurst.Kind.DUST))
		if &"land" in _played and not landed_first:
			landed_first = true
			_played.clear()
		elif landed_first and &"jump" in _played and not jumped:
			jumped = true
			_played.clear()
			_check(_bursts(ImpactBurst.Kind.DUST) >= 1, "jumping kicks up dust")
		elif jumped and &"land" in _played:
			landed_again = true
			break
	_check(landed_first, "dropping onto the floor plays land")
	_check(jumped, "a scripted jump plays jump")
	_check(landed_again, "coming back down plays land again")
	_check(dust_seen >= 1, "landing kicks up dust")
	arena.queue_free()
	await process_frame


func _test_wire_once() -> void:
	var node := Explosion.new()
	_feel.wire(node)
	_feel.wire(node)
	_check(node.exploded.get_connections().size() == 1, "wiring the same node twice connects once")
	node.free()
