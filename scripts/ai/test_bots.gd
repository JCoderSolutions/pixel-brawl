extends SceneTree

## Headless tests for the computer-controlled fighters: difficulty profiles,
## punching, grabbing and firing weapons, ledges, gaps, hazards, grenades,
## determinism, GameManager bot slots, the menu option and a bots-only match
## in the real arena.
## Run: godot --headless --path . -s scripts/ai/test_bots.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const GRENADE_SCENE := preload("res://scenes/items/grenade.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const GRENADE := preload("res://scripts/weapons/data/grenade.tres")
const GameManagerScript := preload("res://scripts/autoload/game_manager.gd")
const ARENA_PATH := "res://scenes/maps/test_arena.tscn"
const MENU_PATH := "res://scenes/ui/main_menu.tscn"

const EASY := BotProfile.Difficulty.EASY
const NORMAL := BotProfile.Difficulty.NORMAL
const HARD := BotProfile.Difficulty.HARD

var _ok := true


## Records every frame the wrapped source hands the player.
class RecordingSource:
	extends InputSource
	var inner: InputSource
	var log: Array[int] = []

	func _init(source: InputSource) -> void:
		inner = source

	func sample() -> InputFrame:
		var frame := inner.sample()
		log.append(frame.encode())
		return frame


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_profiles()
	await _test_bot_punches_player()
	await _test_bot_grabs_weapon_and_shoots()
	await _test_bot_stops_at_ledge()
	await _test_bot_jumps_small_gap()
	await _test_bot_avoids_hazard()
	await _test_grenade_awareness_by_difficulty()
	await _test_same_seed_same_frames()
	await _test_game_manager_bot_slots()
	await _test_menu_bot_option()
	await _test_bots_fight_in_arena()
	print("OK: difficulty profiles, punching, weapon pickup + shooting, ledges, gap jumps, hazards, grenade dodging by difficulty, determinism, GameManager bot slots, menu bot option and bots-only arena match verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Arena whose floor top is y = 0, built from [left, right] x spans.
func _make_arena(spans: Array) -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	for span in spans:
		var floor_body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(span[1] - span[0], 20)
		floor_body.add_child(shape)
		floor_body.position = Vector2((span[0] + span[1]) * 0.5, 10)
		arena.add_child(floor_body)
	return arena


func _add_bot(arena: Node2D, x: float, level := NORMAL, seed_value := 0) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	player.input_source = BotInputSource.new(player, level, seed_value)
	arena.add_child(player)
	return player


func _add_dummy(arena: Node2D, x: float) -> CharacterBody2D:
	var dummy: CharacterBody2D = PLAYER_SCENE.instantiate()
	dummy.is_controlled = false
	dummy.position = Vector2(x, 0)
	arena.add_child(dummy)
	return dummy


func _free(arena: Node) -> void:
	arena.queue_free()
	await process_frame


func _test_profiles() -> void:
	var easy := BotProfile.create(EASY)
	var normal := BotProfile.create(NORMAL)
	var hard := BotProfile.create(HARD)
	_check(easy.think_interval > normal.think_interval and normal.think_interval > hard.think_interval,
			"harder bots decide faster")
	_check(easy.aggression < normal.aggression and normal.aggression <= hard.aggression,
			"harder bots strike more often")
	_check(easy.grenade_awareness == 0.0 and hard.grenade_awareness > normal.grenade_awareness,
			"easy ignores grenades, hard sees them sooner")
	_check(BotProfile.display_name(HARD) == "Difícil", "difficulty names for the menu")


func _test_bot_punches_player() -> void:
	var arena := _make_arena([[-300, 300]])
	var bot := _add_bot(arena, -60)
	var dummy := _add_dummy(arena, 60)
	await _frames(180)
	_check(dummy.health.current_health < dummy.health.max_health, "bot walks up and punches")
	_check(bot.input_source.current_target() == dummy, "bot targets the only opponent")
	await _free(arena)


func _test_bot_grabs_weapon_and_shoots() -> void:
	var arena := _make_arena([[-300, 400]])
	var bot := _add_bot(arena, -100, HARD)
	var dummy := _add_dummy(arena, 250)
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = PISTOL
	pickup.position = Vector2(-60, -8)
	arena.add_child(pickup)
	var min_gap := INF
	for i in 240:
		await physics_frame
		min_gap = minf(min_gap, absf(dummy.position.x - bot.position.x))
	_check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "bot picks up the pistol")
	_check(bot.weapons.has_weapon() and bot.weapons.ammo < PISTOL.max_ammo, "bot fires the pistol")
	_check(dummy.health.current_health < dummy.health.max_health, "bullets hit the opponent")
	_check(min_gap > BotInputSource.PUNCH_RANGE * 2.0, "armed bot keeps its distance")
	await _free(arena)


func _test_bot_stops_at_ledge() -> void:
	# Floor ends at x = 40, the opponent waits across a pit it cannot jump.
	var arena := _make_arena([[-300, 40], [260, 500]])
	var bot := _add_bot(arena, -100, HARD)
	_add_dummy(arena, 320)
	await _frames(180)
	_check(bot.is_on_floor() and absf(bot.position.y) < 1.0, "bot does not fall into the pit")
	_check(bot.position.x > 0.0 and bot.position.x <= 40.0, "bot waits at the edge")
	await _free(arena)


func _test_bot_jumps_small_gap() -> void:
	var arena := _make_arena([[-300, 40], [80, 500]])
	var bot := _add_bot(arena, -60, HARD)
	var dummy := _add_dummy(arena, 200)
	await _frames(300)
	_check(bot.position.x > 80.0 and absf(bot.position.y) < 1.0, "bot jumps across a narrow gap")
	_check(dummy.health.current_health < dummy.health.max_health, "and reaches the opponent")
	await _free(arena)


func _test_bot_avoids_hazard() -> void:
	var arena := _make_arena([[-300, 500]])
	var bot := _add_bot(arena, -100, HARD)
	_add_dummy(arena, 300)
	# An acid pool on the floor: an Area2D in the hazards group.
	var acid := Area2D.new()
	acid.add_to_group(BotInputSource.HAZARD_GROUP)
	acid.collision_layer = 1 << 5
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(160, 8)
	acid.add_child(shape)
	acid.position = Vector2(140, -4)
	arena.add_child(acid)
	await _frames(180)
	_check(bot.position.x < 60.0, "bot stops before an acid pool it cannot jump")
	await _free(arena)


## A grenade with a 1 s fuse lands at the bot's feet.
func _grenade_survival(level: int) -> int:
	var arena := _make_arena([[-400, 400]])
	var bot := _add_bot(arena, 0, level)
	var data: GrenadeData = GRENADE.duplicate()
	data.fuse_time = 1.0
	var grenade: Grenade = GRENADE_SCENE.instantiate()
	arena.add_child(grenade)
	grenade.setup(data, Vector2(4, -6), Vector2.ZERO, null)
	await _frames(90)
	var health: int = bot.health.current_health
	await _free(arena)
	return health


func _test_grenade_awareness_by_difficulty() -> void:
	var easy := await _grenade_survival(EASY)
	var normal := await _grenade_survival(NORMAL)
	var hard := await _grenade_survival(HARD)
	_check(easy < 100, "easy bot ignores the grenade (%d hp)" % easy)
	_check(normal == 100, "normal bot runs from the grenade (%d hp)" % normal)
	_check(hard == 100, "hard bot runs from the grenade (%d hp)" % hard)


func _record_duel(seed_value: int) -> Array[int]:
	var arena := _make_arena([[-300, 300]])
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.position = Vector2(-80, 0)
	var recorder := RecordingSource.new(BotInputSource.new(bot, EASY, seed_value))
	bot.input_source = recorder
	arena.add_child(bot)
	_add_dummy(arena, 60)
	await _frames(150)
	await _free(arena)
	return recorder.log


func _test_same_seed_same_frames() -> void:
	var first := await _record_duel(7)
	var second := await _record_duel(7)
	_check(first.size() >= 150 and first == second, "same seed and world give the same InputFrames")
	var buttons := 0
	for bits in first:
		buttons |= InputFrame.decode(bits).buttons
	_check(buttons & InputFrame.ATTACK, "recorded duel includes punches")


func _test_game_manager_bot_slots() -> void:
	var spawns: Array[Vector2] = [Vector2(80, 0), Vector2(400, 0)]
	var spread := GameManagerScript.spread_spawns(spawns, 4)
	_check(spread.size() == 4 and spread[0] == spawns[0] and spread[1] == spawns[1]
			and spread[2].is_equal_approx(Vector2(80 + 320.0 / 3.0, 0))
			and spread[3].is_equal_approx(Vector2(80 + 640.0 / 3.0, 0)),
			"extra spawns are spread between the first and last marker")
	_check(GameManagerScript.spread_spawns(spawns, 2) == spawns, "no extra spawns when markers suffice")

	var arena := _make_arena([[-100, 600]])
	var manager = GameManagerScript.new()
	manager.set_process(false)
	root.add_child(manager)
	manager.controlled_ids.assign([0, 1])
	manager.configure_bots(3, HARD)
	manager.setup(arena, spawns)
	manager.start_match()
	_check(manager.get_player_ids() == [0, 1, 2, 3], "one human plus three bots spawn")
	_check(manager.get_player(0).input_source is DeviceInputSource, "P1 stays on its keyboard/pad")
	for id in [1, 2, 3]:
		var source = manager.get_player(id).input_source
		_check(source is BotInputSource and source.profile.difficulty == HARD, "P%d is a hard bot" % (id + 1))
	_check(manager.is_bot(1) and not manager.is_bot(0), "is_bot reports the computer slots")

	manager.configure_bots(0, HARD)
	manager.controlled_ids.assign([0, 1])
	manager.setup(arena, spawns)
	manager.start_match()
	_check(manager.get_player_ids() == [0, 1], "0 bots is the local 2P match again")
	_check(manager.get_player(1).input_source is DeviceInputSource, "P2 back on its keys")
	manager.teardown()
	manager.queue_free()
	await _free(arena)


func _test_menu_bot_option() -> void:
	var menu = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	menu.select(2, HARD)
	menu.apply_selection()
	_check(_gm().bot_difficulties == [HARD, HARD] and _gm().human_players == 1,
			"menu configures 1 human vs 2 hard bots")
	menu.select(0, NORMAL)
	menu.apply_selection()
	_check(_gm().bot_difficulties.is_empty(), "menu 2P option clears the bots")
	menu.queue_free()
	await process_frame


func _test_bots_fight_in_arena() -> void:
	_gm().configure_bots(3, HARD, 0)
	var arena = load(ARENA_PATH).instantiate()
	root.size = Vector2i(960, 540)
	arena.get_node("TouchControls").visibility = TouchControls.Visibility.NEVER
	root.add_child(arena)
	var hurt := {}
	for i in 600:
		await physics_frame
		for id in _gm().get_player_ids():
			var player = _gm().get_player(id)
			if player != null and player.health.current_health < player.health.max_health:
				hurt[id] = true
	_check(_gm().get_player_ids().size() == 3 or _gm().current_round > 1, "three bots fight in the arena")
	_check(hurt.size() >= 2 or _gm().current_round > 1, "bots hurt each other (%d hurt)" % hurt.size())
	arena.queue_free()
	await process_frame
	_gm().configure_bots(0, NORMAL)


## The autoload, looked up at run time (SceneTree scripts compile before it exists).
func _gm() -> Node:
	return root.get_node("/root/GameManager")
