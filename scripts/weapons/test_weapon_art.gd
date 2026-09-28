extends SceneTree

## Headless tests for the native-shape weapon art (WeaponArt): every weapon in
## scripts/weapons/data has its own drawing, guns end at their muzzle, the
## drawing mirrors with the wielder, pickups on the floor show the same
## weapon, and armed fighters keep the gun arm up while running and jumping.
## Run: godot --headless --path . -s scripts/weapons/test_weapon_art.gd

const DATA_DIR := "res://scripts/weapons/data/"
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_every_weapon_has_art()
	_test_mirroring()
	await _test_pickup_shows_the_weapon()
	_test_armed_arm_stays_up()
	print("OK: art for every weapon, muzzle-length guns, mirroring, pickups and armed poses verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _weapons() -> Array[WeaponData]:
	var found: Array[WeaponData] = []
	for file in DirAccess.get_files_at(DATA_DIR):
		var weapon := load(DATA_DIR + file.trim_suffix(".remap")) as WeaponData
		if weapon != null:
			found.append(weapon)
	return found


func _bounds(shapes: Array[Dictionary]) -> Rect2:
	var rect := Rect2(shapes[0].points[0], Vector2.ZERO)
	for shape in shapes:
		for point in shape.points:
			rect = rect.expand(point)
	return rect


func _test_every_weapon_has_art() -> void:
	var weapons := _weapons()
	_check(weapons.size() >= 8, "found the weapon data files (%d)" % weapons.size())
	var looks := {}
	for weapon in weapons:
		_check(WeaponArt.has_art(weapon.id), "%s has its own drawing" % weapon.id)
		var shapes := WeaponArt.shapes(weapon)
		_check(shapes.size() >= 2, "%s is more than a bar (%d shapes)" % [weapon.id, shapes.size()])
		var box := _bounds(shapes)
		_check(box.size.x <= 24.0 and box.size.y <= 10.0, "%s fits in the hand (%s)" % [weapon.id, box.size])
		if weapon.is_ranged() and not weapon is GrenadeData:
			_check(absf(box.end.x - weapon.muzzle_offset) <= 3.0,
					"%s's barrel ends at the muzzle (%.1f vs %.1f)" % [weapon.id, box.end.x, weapon.muzzle_offset])
		looks[str(shapes.map(func(s): return s.points))] = true
	_check(looks.size() == weapons.size(), "every weapon looks different")
	var unknown := WeaponData.new()
	unknown.id = &"mystery"
	_check(not WeaponArt.has_art(unknown.id) and WeaponArt.shapes(unknown).size() == 1,
			"a weapon without art falls back to a bar in its colour")


func _test_mirroring() -> void:
	var pistol: WeaponData = load(DATA_DIR + "pistol.tres")
	var right := _bounds(WeaponArt.shapes(pistol, 1))
	var left := _bounds(WeaponArt.shapes(pistol, -1))
	_check(is_equal_approx(left.position.x, -right.end.x) and is_equal_approx(left.end.x, -right.position.x),
			"facing left mirrors the drawing (%s / %s)" % [right, left])


func _test_pickup_shows_the_weapon() -> void:
	var bazooka: WeaponData = load(DATA_DIR + "bazooka.tres")
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = bazooka
	root.add_child(pickup)
	await process_frame
	var shapes := pickup.art_shapes()
	_check(shapes == WeaponArt.shapes(bazooka, 1, true), "a pickup draws its weapon's art, centred")
	var box := _bounds(shapes)
	_check(absf(box.get_center().x) <= 0.5, "the drawing is centred on the pickup (%s)" % box)
	pickup.queue_free()
	await process_frame


func _test_armed_arm_stays_up() -> void:
	for anim in [FighterRig.Anim.RUN, FighterRig.Anim.JUMP, FighterRig.Anim.FALL, FighterRig.Anim.AIM]:
		var p := FighterRig.pose(anim, 0.2, true)
		_check(is_equal_approx(p.arm_front, -PI / 2.0), "an armed fighter keeps the gun arm up while %s" % FighterRig.Anim.keys()[anim])
	_check(not is_equal_approx(FighterRig.pose(FighterRig.Anim.RUN, 0.2).arm_front, -PI / 2.0), "unarmed fighters still swing their arms")
	_check(FighterRig.pose(FighterRig.Anim.HURT, 0.2, true).arm_front > 0.0, "a hit still flings the arm back")
