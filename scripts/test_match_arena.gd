extends SceneTree

## Headless tests for the playable match: the real player picks up, fires and
## drops weapons from its own slot, dies into a ragdoll, can climb the arena,
## and the game boots into the menu, whose Play button runs a 2P match in
## the arena.
## Run: godot --headless --path . -s scripts/test_match_arena.gd

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const ARENA_PATH := "res://scenes/maps/test_arena.tscn"
const MENU_PATH := "res://scenes/ui/main_menu.tscn"

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_weapon_buttons_per_slot()
	await _test_pick_up_and_fire()
	await _test_semi_auto_needs_repress()
	await _test_pickup_button_drops_weapon()
	await _test_weapon_faces_with_player()
	await _test_death_drops_weapon_and_ragdolls()
	await _test_jump_clears_platform_step()
	await _test_arena_platforms_reachable()
	await _test_game_boots_into_menu()
	await _test_arena_runs_two_player_match()
	_test_display_is_pixel_perfect_and_responsive()
	_test_body_fits_32px_sprite()
	await _test_arena_camera_centres_the_map()
	await _test_arena_spawns_grenades()
	await _test_arena_has_touch_controls()
	print("OK: weapon buttons per slot, pick up/fire/drop, semi-auto, facing, death drop + ragdoll, jump height, reachable platforms, menu boot, 2P arena match, pixel-perfect responsive display, 32x32 body, shared camera, grenades and touch controls verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## `count` copies of the same frame.
func _hold(frames: Array[InputFrame], count: int, move := 0.0, buttons := 0) -> void:
	for i in count:
		frames.append(InputFrame.create(move, buttons))


## Floor at y = 0 with a scripted P1 at the origin and an idle P2 target.
func _make_duel(frames: Array[InputFrame], target_x := 80.0) -> Dictionary:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(2000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 10)
	arena.add_child(floor_body)

	var player = PLAYER_SCENE.instantiate()
	player.input_source = ScriptedInputSource.new(frames)
	arena.add_child(player)
	var target = PLAYER_SCENE.instantiate()
	target.is_controlled = false
	target.position = Vector2(target_x, 0)
	arena.add_child(target)
	return {"arena": arena, "player": player, "target": target}


func _drop_pistol(arena: Node, at: Vector2) -> WeaponPickup:
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = PISTOL
	arena.add_child(pickup)
	pickup.global_position = at
	return pickup


func _pickups_in(node: Node) -> Array:
	return node.get_children().filter(func(n): return n is WeaponPickup and not n.is_queued_for_deletion())


func _test_weapon_buttons_per_slot() -> void:
	_check(InputFrame.FIRE != 0 and InputFrame.PICKUP != 0, "frames carry fire and pickup buttons")
	var all_bits := [InputFrame.JUMP, InputFrame.CROUCH, InputFrame.ATTACK, InputFrame.FIRE, InputFrame.PICKUP]
	var mask := 0
	for bit in all_bits:
		_check(mask & bit == 0, "button bit %d is unique" % bit)
		mask |= bit
	_check(mask <= 0xFF, "buttons still fit the 16-bit frame encoding")
	var frame := InputFrame.create(0.0, InputFrame.FIRE | InputFrame.PICKUP)
	_check(InputFrame.decode(frame.encode()).equals(frame), "fire/pickup survive encode/decode")

	for slot in range(1, 5):
		for action in ["fire", "pickup"]:
			var name := "p%d_%s" % [slot, action]
			_check(InputMap.has_action(name) and not InputMap.action_get_events(name).is_empty(),
				"%s is bound" % name)

	Input.action_press("p2_fire")
	Input.action_press("p2_pickup")
	var p2 := DeviceInputSource.new(2).sample()
	var p1 := DeviceInputSource.new(1).sample()
	Input.action_release("p2_fire")
	Input.action_release("p2_pickup")
	_check(p2.is_held(InputFrame.FIRE) and p2.is_held(InputFrame.PICKUP), "slot 2 reads its fire/pickup")
	_check(not p1.is_held(InputFrame.FIRE) and not p1.is_held(InputFrame.PICKUP), "slot 1 ignores slot 2 buttons")


func _test_pick_up_and_fire() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 1, 0.0, InputFrame.PICKUP)
	_hold(frames, 5)
	_hold(frames, 1, 0.0, InputFrame.FIRE)
	var d := _make_duel(frames)
	var player = d.player
	var pickup := _drop_pistol(d.arena, Vector2(0, -8))
	_check(player.weapons is WeaponHolder, "player carries a WeaponHolder")
	await _frames(14)
	_check(player.weapons.has_weapon() and player.weapons.weapon == PISTOL, "pickup button grabs the pistol")
	_check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "pickup left the floor")
	var hp: int = d.target.health.current_health
	await _frames(40)
	_check(d.target.health.current_health == hp - PISTOL.damage,
		"fire button shoots the other player (hp %d -> %d)" % [hp, d.target.health.current_health])
	_check(player.weapons.ammo == PISTOL.max_ammo - 1, "one shot spends one bullet")
	_check(player.health.current_health == player.health.max_health, "shooter is unharmed")
	d.arena.queue_free()
	await process_frame


func _test_semi_auto_needs_repress() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 5)
	_hold(frames, 90, 0.0, InputFrame.FIRE)
	var d := _make_duel(frames, 400.0)
	d.player.weapons.equip(PISTOL)
	await _frames(100)
	_check(d.player.weapons.ammo == PISTOL.max_ammo - 1,
		"holding fire with a pistol shoots once (ammo %d)" % d.player.weapons.ammo)
	d.arena.queue_free()
	await process_frame


func _test_pickup_button_drops_weapon() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 5)
	_hold(frames, 1, 0.0, InputFrame.PICKUP)
	var d := _make_duel(frames, 400.0)
	d.player.weapons.equip(PISTOL, 4)
	await _frames(10)
	_check(not d.player.weapons.has_weapon(), "pickup with nothing in reach drops the weapon")
	var dropped := _pickups_in(d.arena)
	_check(dropped.size() == 1 and dropped[0].ammo == 4, "dropped weapon keeps its ammo")
	d.arena.queue_free()
	await process_frame


func _test_weapon_faces_with_player() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10, -1.0)
	var d := _make_duel(frames, 400.0)
	await _frames(12)
	_check(d.player.weapons.facing == -1, "weapon turns left with the player")
	d.arena.queue_free()
	await process_frame


func _test_death_drops_weapon_and_ragdolls() -> void:
	var frames: Array[InputFrame] = []
	var d := _make_duel(frames, 400.0)
	var player = d.player
	await _frames(5)
	player.weapons.equip(PISTOL, 5)
	_check(player.get_node_or_null("RagdollOnDeath") is RagdollOnDeath, "player has the ragdoll hook")
	player.health.take_damage(player.health.current_health)
	await _frames(3)
	_check(not player.weapons.has_weapon(), "dying lets go of the weapon")
	_check(_pickups_in(d.arena).size() == 1, "the weapon falls to the floor")
	var ragdolls: Array = d.arena.get_children().filter(func(n): return n is Ragdoll)
	_check(ragdolls.size() == 1, "death spawns a ragdoll")
	_check(not player.get_node("Visual").visible, "ragdoll replaces the body visual")
	d.arena.queue_free()
	await process_frame


## The arena's steps are 50 px (floor -> platform) and 46 px (platform ->
## bridge); the current jump (~57 px) must clear them with room to spare.
func _test_jump_clears_platform_step() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 5)
	_hold(frames, 5, 0.0, InputFrame.JUMP)
	var d := _make_duel(frames, 400.0)
	await _frames(5)
	var floor_y: float = d.player.global_position.y
	var top := floor_y
	for i in 60:
		await physics_frame
		top = minf(top, d.player.global_position.y)
	_check(floor_y - top >= 55.0, "jump rises at least 55 px (got %.1f)" % (floor_y - top))
	d.arena.queue_free()
	await process_frame


## Climbs floor -> Platform -> bridge and floor -> Platform2 -> bridge.
func _test_arena_platforms_reachable() -> void:
	for side in [-1.0, 1.0]:
		var arena: Node2D = load(ARENA_PATH).instantiate()
		arena.autostart = false
		root.add_child(arena)
		var platform: Node2D = arena.get_node("Platform" if side < 0 else "Platform2")
		var platform_top := platform.global_position.y - 6.0
		var bridge_top: float = arena.bridge_top()
		# Start on the floor just inside the arena centre, facing the platform.
		var frames: Array[InputFrame] = []
		_hold(frames, 10)
		_hold(frames, 40, side, InputFrame.JUMP)
		_hold(frames, 30)
		var player = PLAYER_SCENE.instantiate()
		player.position = Vector2(240.0 + side * 40.0, 250.0)
		player.input_source = ScriptedInputSource.new(frames)
		arena.get_node("Players").add_child(player)
		await _frames(85)
		_check(player.is_on_floor() and absf(player.global_position.y - platform_top) < 1.0,
			"%s platform reachable from the floor (y = %.1f, top %.1f)" % ["left" if side < 0 else "right", player.global_position.y, platform_top])
		# From the platform's inner edge, jump back towards the centre bridge.
		player.global_position.x = 240.0 + side * 70.0
		frames = []
		_hold(frames, 5)
		_hold(frames, 40, -side, InputFrame.JUMP)
		_hold(frames, 30)
		player.input_source = ScriptedInputSource.new(frames)
		await _frames(80)
		_check(player.is_on_floor() and absf(player.global_position.y - bridge_top) < 1.0,
			"bridge reachable from the %s platform (y = %.1f, top %.1f)" % ["left" if side < 0 else "right", player.global_position.y, bridge_top])
		arena.queue_free()
		await process_frame


func _test_game_boots_into_menu() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == MENU_PATH, "game starts at the menu")
	var menu = load(MENU_PATH).instantiate()
	_check(menu.match_scene == ARENA_PATH, "Play loads the arena (got %s)" % menu.match_scene)
	menu.free()
	await process_frame


func _test_arena_runs_two_player_match() -> void:
	var manager = root.get_node("GameManager")
	var arena: Node2D = load(ARENA_PATH).instantiate()
	root.add_child(arena)
	await process_frame
	_check(manager.get_player_ids() == [0, 1], "arena spawns two players")
	var p1 = manager.get_player(0)
	var p2 = manager.get_player(1)
	_check(p1.is_controlled and p2.is_controlled, "both players are human-controlled")
	_check(p1.player_slot == 1 and p2.player_slot == 2, "each player reads its own slot")
	_check(arena.get_node_or_null("HUD") != null and arena.get_node_or_null("WinnerScreen") != null, "arena has HUD and winner screen")
	_check(arena.find_children("*", "WeaponSpawner", true, false).size() == 1, "arena spawns weapons")

	p1.weapons.equip(PISTOL)
	_check(arena.get_node("HUD").weapon_text(0) == "%s %d" % [PISTOL.display_name, PISTOL.max_ammo],
		"HUD shows P1's weapon and ammo (got '%s')" % arena.get_node("HUD").weapon_text(0))
	p1.weapons.drop()
	_check(arena.get_node("HUD").weapon_text(0) == "", "HUD clears the weapon once dropped")

	await _frames(10)
	var p1_x: float = p1.global_position.x
	var p2_x: float = p2.global_position.x
	Input.action_press("p2_move_left")
	await _frames(20)
	Input.action_release("p2_move_left")
	_check(p2.global_position.x < p2_x - 10.0, "P2 keys move P2")
	_check(absf(p1.global_position.x - p1_x) < 0.5, "P2 keys leave P1 alone")

	# Loose weapons and corpses from one round don't carry into the next.
	var ragdoll := preload("res://scenes/effects/ragdoll.tscn").instantiate()
	arena.get_node("Players").add_child(ragdoll)
	_drop_pistol(arena.get_node("Players"), Vector2(240, 100))
	manager.round_started.emit(manager.current_round + 1)
	await process_frame
	_check(not is_instance_valid(ragdoll), "new round clears corpses")
	_check(_pickups_in(arena.get_node("Players")).is_empty(), "new round clears loose weapons")

	arena.queue_free()
	await process_frame
	_check(manager.state == manager.State.IDLE, "leaving the arena tears the match down")


## Pixel art is upscaled from the 480x270 base by whole numbers only, and
## any spare room (phones, portrait, ultrawide) shows more world instead of
## black bars.
func _test_display_is_pixel_perfect_and_responsive() -> void:
	var setting := func(key: String): return ProjectSettings.get_setting(key)
	# canvas_items draws at screen resolution, so the shared camera can zoom
	# out in whole screen-pixel steps; "viewport" would lock it at zoom >= 1.
	_check(setting.call("display/window/stretch/mode") == "canvas_items", "draws at screen resolution so the camera can zoom out")
	_check(setting.call("display/window/stretch/aspect") == "expand", "extra screen space extends the view")
	_check(setting.call("display/window/stretch/scale_mode") == 1, "upscale by whole numbers only")
	_check(setting.call("rendering/2d/snap/snap_2d_transforms_to_pixel") == true, "sprites snap to whole pixels")
	_check(setting.call("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR, "phones rotate freely")
	_check(setting.call("rendering/textures/canvas_textures/default_texture_filter") == 0, "nearest filtering keeps pixels sharp")


## Sprites will be 32x32 frames anchored at the feet (origin at the bottom
## centre); every body shape has to fit inside that frame.
func _test_body_fits_32px_sprite() -> void:
	var player = PLAYER_SCENE.instantiate()
	var frame := Rect2(-16, -32, 32, 32)
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D"]:
		var collider: CollisionShape2D = player.get_node(path)
		var size: Vector2 = collider.shape.size
		var rect := Rect2(collider.position - size / 2.0, size)
		_check(frame.encloses(rect), "%s %s fits the 32x32 sprite frame" % [path, rect])
	var visual: Control = player.get_node("Visual")
	_check(frame.encloses(Rect2(visual.position, visual.size)), "placeholder visual fits the 32x32 frame")
	player.free()


func _test_arena_camera_centres_the_map() -> void:
	var manager = root.get_node("GameManager")
	var arena: Node2D = load(ARENA_PATH).instantiate()
	root.add_child(arena)
	await process_frame
	var camera := arena.get_node_or_null("SharedCamera") as SharedCamera
	_check(camera != null, "arena uses the shared camera")
	if camera != null:
		_check(camera.bounds == Rect2(0, 0, 480, 270), "camera stays inside the 480x270 map")
		var targets := camera.get_targets()
		_check(targets.has(manager.get_player(0)) and targets.has(manager.get_player(1)),
			"camera follows both spawned players")
		# Players are re-spawned every round; the camera must follow the new ones.
		manager._start_round()
		await process_frame
		targets = camera.get_targets()
		_check(targets.has(manager.get_player(0)) and targets.has(manager.get_player(1)),
			"camera follows the players of the next round")
		_check(targets.size() == 2, "freed players leave the camera (got %d targets)" % targets.size())
		# Blasts rattle the view.
		camera.trauma = 0.0
		var explosion: Explosion = preload("res://scenes/items/explosion.tscn").instantiate()
		arena.add_child(explosion)
		explosion.global_position = Vector2(240, 60)
		explosion.detonate()
		_check(camera.trauma >= 0.5, "an explosion shakes the camera (trauma %.2f)" % camera.trauma)
	var background: ColorRect = arena.get_node("Background")
	_check(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color") == background.color,
		"space beyond the map uses the arena background colour")
	arena.queue_free()
	await process_frame


func _test_arena_spawns_grenades() -> void:
	var arena: Node2D = load(ARENA_PATH).instantiate()
	arena.autostart = false
	var spawner: WeaponSpawner = arena.get_node("WeaponSpawner")
	_check(spawner.weapons.any(func(w): return w is GrenadeData), "grenades are in the arena's weapon pool")
	arena.free()
	await process_frame


func _test_arena_has_touch_controls() -> void:
	var arena: Node2D = load(ARENA_PATH).instantiate()
	arena.autostart = false
	root.add_child(arena)
	var touch := arena.get_node_or_null("TouchControls") as TouchControls
	_check(touch != null and touch.slot == 1, "arena has touch controls for P1")
	if touch != null:
		_check(touch.visibility == TouchControls.Visibility.AUTO, "touch controls show only on touch screens")
	arena.queue_free()
	await process_frame
