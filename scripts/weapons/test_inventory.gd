extends SceneTree

## Headless tests for the weapon inventory (Superfighters): one weapon per
## slot (melee, handgun, rifle, throwable), the switch button cycles through
## them and the fists, the same weapon tops up ammo, the best carried weapon
## is drawn when the hand empties, a fighter going down drops everything,
## the HUD lists what's carried and bots draw their gun for a distant rival.
## Run: godot --headless --path . -s scripts/weapons/test_inventory.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const HUD_SCRIPT := preload("res://scenes/ui/hud.gd")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const RIFLE := preload("res://scripts/weapons/data/assault_rifle.tres")
const BAT := preload("res://scripts/weapons/data/bat.tres")
const GRENADE := preload("res://scripts/weapons/data/grenade.tres")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_slots()
	await _test_switch_cycles()
	await _test_switch_button()
	await _test_same_weapon_tops_up()
	await _test_draws_best_when_hand_empties()
	await _test_death_drops_everything()
	_test_hud_lists_carried()
	await _test_bot_draws_gun()
	print("OK: slots, switch cycle and button, ammo top-up, drawing the best weapon, dropping everything on death, HUD line and bot switching verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _hold(count: int, move := 0.0, buttons := 0) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(move, buttons))
	return frames


func _stage() -> Node2D:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(2000, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	stage.add_child(floor_body)
	return stage


func _fighter(stage: Node2D, x: float, frames: Array[InputFrame] = []) -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = Vector2(x, 0)
	player.input_source = ScriptedInputSource.new(_hold(20) + frames)
	stage.add_child(player)
	return player


func _pickups(stage: Node) -> Array:
	return stage.get_children().filter(func(n): return n is WeaponPickup and not n.is_queued_for_deletion())


func _add_pickup(stage: Node2D, data: WeaponData, at: Vector2, ammo := -1) -> WeaponPickup:
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = data
	pickup.ammo = ammo
	pickup.position = at
	stage.add_child(pickup)
	return pickup


func _test_slots() -> void:
	_check(BAT.slot == WeaponData.Slot.MELEE and PISTOL.slot == WeaponData.Slot.HANDGUN \
			and RIFLE.slot == WeaponData.Slot.RIFLE and GRENADE.slot == WeaponData.Slot.THROWABLE,
			"each weapon names its slot")


func _test_switch_cycles() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0.0)
	await _frames(2)
	var holder: WeaponHolder = player.weapons
	holder.equip(PISTOL)
	holder.equip(BAT)
	holder.equip(GRENADE)
	_check(holder.carried_count() == 3 and holder.weapon == GRENADE, "three slots carried, the last one in hand")
	var seen: Array = []
	for i in 4:
		holder.switch_next()
		seen.append(holder.weapon)
	_check(seen == [null, BAT, PISTOL, GRENADE], "switch cycles fists -> melee -> handgun -> throwable (%s)" % [seen])
	_check(holder.ammo_in(WeaponData.Slot.HANDGUN) == PISTOL.max_ammo, "carried weapons keep their ammo")
	_check(not holder.is_ready(), "a freshly drawn weapon needs a moment")
	holder.drop_all()
	_check(not holder.switch_next(), "with nothing carried the fists stay")
	stage.queue_free()
	await process_frame


func _test_switch_button() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0.0, _hold(1, 0.0, InputFrame.SWITCH) + _hold(3) + _hold(1, 0.0, InputFrame.SWITCH) + _hold(30))
	await _frames(2)
	player.weapons.equip(PISTOL)
	player.weapons.equip(BAT)
	var seen: Array = []
	player.weapons.weapon_switched.connect(func(w: WeaponData) -> void: seen.append(w))
	await _frames(40)
	_check(seen == [PISTOL, null], "each press of switch draws the next one: the gun, then the fists (%s)" % [seen])
	stage.queue_free()
	await process_frame


func _test_same_weapon_tops_up() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0.0)
	await _frames(20)
	var holder: WeaponHolder = player.weapons
	holder.equip(PISTOL, 3)
	holder.equip(BAT)
	var pickup := _add_pickup(stage, PISTOL, Vector2(0, -4), 5)
	await _frames(2)
	_check(holder.try_pick_up(), "the same weapon is picked up")
	_check(holder.weapon == PISTOL and holder.ammo == 8, "into its slot, adding the ammo (%d)" % holder.ammo)
	_check(holder.carried(WeaponData.Slot.MELEE) == BAT, "the bat stays carried")
	await _frames(1)
	_check(not is_instance_valid(pickup) and _pickups(stage).is_empty(), "nothing is dropped")
	_add_pickup(stage, PISTOL, Vector2(0, -4))
	await _frames(2)
	holder.try_pick_up()
	_check(holder.ammo == PISTOL.max_ammo, "ammo caps at the weapon's max (%d)" % holder.ammo)
	stage.queue_free()
	await process_frame


func _test_draws_best_when_hand_empties() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0.0)
	await _frames(20)
	var holder: WeaponHolder = player.weapons
	holder.equip(BAT)
	holder.equip(PISTOL)
	holder.equip(GRENADE, 1)
	holder.try_use()
	_check(holder.weapon == PISTOL, "the last grenade gone, the gun is drawn (%s)" % holder.weapon)
	_check(holder.carried(WeaponData.Slot.THROWABLE) == null, "and the throwable slot is free")
	holder.throw_weapon()
	_check(holder.weapon == BAT, "throwing the gun draws the bat")
	holder.drop()
	_check(holder.weapon == null and holder.carried_count() == 0, "dropping the last one leaves the fists")
	stage.queue_free()
	await process_frame


func _test_death_drops_everything() -> void:
	var stage := _stage()
	var player := _fighter(stage, 0.0)
	await _frames(20)
	player.weapons.equip(BAT)
	player.weapons.equip(PISTOL)
	player.weapons.equip(RIFLE)
	player.health.take_damage(1000)
	await _frames(3)
	var dropped := _pickups(stage)
	_check(dropped.size() == 3 and player.weapons.carried_count() == 0,
			"going down drops every carried weapon (%d)" % dropped.size())
	stage.queue_free()
	await process_frame


func _test_hud_lists_carried() -> void:
	var holder := WeaponHolder.new()
	holder.equip(BAT)
	holder.equip(GRENADE, 2)
	holder.equip(PISTOL)
	var hud: CanvasLayer = HUD_SCRIPT.new()
	_check(hud.weapon_line(holder) == "%s %d" % [PISTOL.display_name, PISTOL.max_ammo], "HUD shows the weapon in hand")
	var line: String = hud.carried_line(holder)
	_check(line == "%s · %s 2" % [BAT.display_name, GRENADE.display_name], "and the rest carried (%s)" % line)
	hud.free()
	holder.free()


func _test_bot_draws_gun() -> void:
	var stage := _stage()
	var bot: CharacterBody2D = PLAYER_SCENE.instantiate()
	bot.input_source = BotInputSource.new(bot, BotProfile.Difficulty.HARD, 0)
	stage.add_child(bot)
	var rival: CharacterBody2D = PLAYER_SCENE.instantiate()
	rival.is_controlled = false
	rival.position = Vector2(220, 0)
	stage.add_child(rival)
	await _frames(2)
	bot.weapons.equip(PISTOL)
	bot.weapons.equip(BAT)
	var drew: bool = false
	for i in 90:
		await physics_frame
		if bot.weapons.weapon == PISTOL:
			drew = true
			break
	_check(drew, "a bot with a bat draws its gun for a distant rival")
	stage.queue_free()
	await process_frame
