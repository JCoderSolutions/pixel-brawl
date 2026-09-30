extends SceneTree

## Headless tests for the art hooks: the native shapes stay as placeholders,
## and real art drops in without code. Tiles show a BlockMaterial strip
## frame by damage, fighters play a SpriteFrames sheet from their
## FighterLook (one animation per FighterRig.Anim) and weapons draw their
## WeaponData sprite.
## Run: godot --headless --path . -s scripts/test_art_hooks.gd

const BLOCK_SCENE := preload("res://scenes/maps/destructible_block.tscn")
const WOOD := preload("res://scenes/maps/materials/wood.tres")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_strip_frames()
	await _test_block_uses_the_strip()
	await _test_block_keeps_the_placeholder()
	await _test_rig_plays_sprite_frames()
	_test_character_sheet_path()
	await _test_weapon_sprite()
	print("OK: tile strips by damage, placeholder fallback, fighter sprite sheets per animation and weapon sprites verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _texture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _test_strip_frames() -> void:
	var strip := _texture(48, 16)
	_check(BlockMaterial.frame_count(strip) == 3, "a 48 px strip holds 3 tiles")
	_check(BlockMaterial.frame_for(strip, 1.0) == 0, "intact shows the first frame")
	_check(BlockMaterial.frame_for(strip, 0.5) == 1, "half health shows the middle frame")
	_check(BlockMaterial.frame_for(strip, 0.05) == 2, "about to break shows the last frame")
	_check(BlockMaterial.frame_for(_texture(16, 16), 0.2) == 0, "a single tile never changes")


func _test_block_uses_the_strip() -> void:
	var material: BlockMaterial = WOOD.duplicate()
	material.texture = _texture(48, 16)
	var block: DestructibleBlock = BLOCK_SCENE.instantiate()
	block.block_material = material
	root.add_child(block)
	await process_frame
	_check(block.art() == material.texture, "the tile draws the material's strip")
	_check(not block.get_node("Visual").visible, "and hides the placeholder rectangle")
	_check(block.art_frame() == 0, "starting intact")
	block.health.take_damage(16)
	_check(block.art_frame() == 1, "damage moves along the strip (frame %d)" % block.art_frame())
	var planks: BlockMaterial = WOOD.duplicate()
	planks.texture = material.texture
	planks.plank_texture = _texture(32, 16)
	var plank: DestructibleBlock = BLOCK_SCENE.instantiate()
	plank.block_material = planks
	plank.one_way = true
	root.add_child(plank)
	await process_frame
	_check(plank.art() == planks.plank_texture, "one-way planks use their own strip")
	block.queue_free()
	plank.queue_free()
	await process_frame


func _test_block_keeps_the_placeholder() -> void:
	var block: DestructibleBlock = BLOCK_SCENE.instantiate()
	root.add_child(block)
	await process_frame
	_check(block.art() == null and block.get_node("Visual").visible, "no strip: the colour placeholder stays")
	block.queue_free()
	await process_frame


func _test_rig_plays_sprite_frames() -> void:
	_check(FighterRig.anim_name(FighterRig.Anim.IDLE) == &"idle" and FighterRig.anim_name(FighterRig.Anim.BLOCK) == &"block",
			"animations are named after FighterRig.Anim")
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 5.0)
	frames.rename_animation(&"default", &"idle")
	var first := _texture(32, 32)
	var second := _texture(32, 32)
	frames.add_frame(&"idle", first)
	frames.add_frame(&"idle", second)
	var look := FighterLook.create("Prueba", Color.RED, Color.BLUE, Color.WHITE, Color.BLACK)
	look.frames = frames
	var rig := FighterRig.new()
	rig.look = look
	root.add_child(rig)
	rig.anim = FighterRig.Anim.IDLE
	rig.anim_time = 0.0
	_check(rig.sprite_frame() == first, "idle starts on its first frame")
	rig.anim_time = 0.25
	_check(rig.sprite_frame() == second, "and moves on at the animation's speed")
	rig.anim_time = 0.45
	_check(rig.sprite_frame() == first, "looping")
	rig.anim = FighterRig.Anim.RUN
	_check(rig.sprite_frame() == null, "an animation the sheet lacks falls back to native shapes")
	rig.look = FighterLook.at(0)
	rig.anim = FighterRig.Anim.IDLE
	_check(rig.sprite_frame() == null, "characters without a sheet keep native shapes")
	# Frames bigger than the fighter (48x64, room for swings): the team
	# marker sits over the drawn pixels, not over the frame's empty top.
	var tall := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	tall.fill_rect(Rect2i(16, 32, 16, 32), Color.WHITE)
	var tall_frame := ImageTexture.create_from_image(tall)
	_check(FighterRig.sprite_height(tall_frame) == 32.0, "a 32 px fighter in a 48x64 frame is 32 px tall")
	_check(FighterRig.sprite_height(_texture(32, 32)) == 32.0, "an empty frame counts its full height")
	await process_frame
	rig.queue_free()
	await process_frame


func _test_character_sheet_path() -> void:
	_check(FighterLook.sprite_path("Obrero") == "res://assets/sprites/characters/obrero.tres",
			"a character's sheet goes in assets/sprites/characters/<name>.tres")


func _test_weapon_sprite() -> void:
	var weapon: WeaponData = PISTOL.duplicate()
	_check(weapon.sprite == null, "weapons draw native shapes until they get a sprite")
	weapon.sprite = _texture(16, 8)
	weapon.sprite_grip = Vector2(4, 5)
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = weapon
	root.add_child(pickup)
	# Drawing with the sprite must not fall over.
	await process_frame
	await process_frame
	_check(is_instance_valid(pickup), "a pickup draws the weapon's sprite")
	pickup.queue_free()
	await process_frame
