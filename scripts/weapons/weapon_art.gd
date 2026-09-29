class_name WeaponArt
extends RefCounted

## Native-shape drawings of the weapons, until sprites land. One function
## feeds both the weapon in hand (WeaponHolder) and the one lying on the floor
## (WeaponPickup), so what you grab is what you see.
##
## Shapes are in the holder's space: origin at the body's centre line at hand
## height, barrel along +x (the facing side), +y down. Guns end at their
## `muzzle_offset`, where bullets appear; the grip sits near x = 6..9, where
## FighterRig draws the hand.

## Endesga 32 swatches shared by several weapons.
const DARK := Color("181425")
const STEEL := Color("5a6988")
const LIGHT_STEEL := Color("8b9bb4")
const BLADE := Color("c0cbdc")
const WOOD := Color("b86f50")
const DARK_WOOD := Color("733e39")
const GOLD := Color("feae34")

## Weapon id -> [[shape, part colour or null for the weapon's own colour]].
## A shape is a Rect2 or a PackedVector2Array polygon (not a constant
## expression, hence a static var).
static var art := {
	&"pistol": [
		[Rect2(5, 1, 2, 3), DARK],
		[Rect2(5, -2, 7, 3), null],
	],
	&"assault_rifle": [
		[Rect2(-2, -1, 4, 3), DARK],
		[Rect2(7, 1, 2, 4), DARK],
		[Rect2(2, -2, 9, 3), null],
		[Rect2(11, -1.5, 5, 1.5), DARK],
	],
	&"shotgun": [
		[Rect2(-2, -1, 6, 3), null],
		[Rect2(4, -2, 10, 2), STEEL],
		[Rect2(7, 0, 4, 2), DARK_WOOD],
	],
	&"sawed_off": [
		[Rect2(1, -1, 4, 3), null],
		[Rect2(5, -2, 5, 1.5), LIGHT_STEEL],
		[Rect2(5, -0.5, 5, 1.5), STEEL],
	],
	&"bazooka": [
		[Rect2(2, 1.5, 2, 3), DARK],
		[Rect2(-6, -2.5, 18, 4), null],
		[Rect2(12, -3, 2, 5), DARK],
	],
	&"grenade": [
		[PackedVector2Array([Vector2(5, -2), Vector2(7, -3), Vector2(9, -2), Vector2(10, 0), Vector2(9, 2), Vector2(7, 3), Vector2(5, 2), Vector2(4, 0)]), null],
		[Rect2(6, -5, 2, 2), LIGHT_STEEL],
	],
	&"molotov": [
		[PackedVector2Array([Vector2(4, -1), Vector2(6, -3), Vector2(10, -3), Vector2(10, 3), Vector2(6, 3), Vector2(4, 1)]), null],
		[Rect2(1, -1, 3, 2), WOOD],
		[Rect2(0, -2, 1, 1), GOLD],
	],
	&"katana": [
		[Rect2(4, -1, 4, 2), DARK],
		[PackedVector2Array([Vector2(9, -1), Vector2(20, -1), Vector2(22, 0.5), Vector2(9, 1)]), null],
		[Rect2(8, -2.5, 1, 5), GOLD],
	],
	&"bat": [
		[PackedVector2Array([Vector2(4, -1), Vector2(18, -2.5), Vector2(18, 2.5), Vector2(4, 1)]), null],
		[Rect2(4, -1, 3, 2), DARK],
	],
}


## Draws `weapon` on `canvas`: its sprite when it has one (grip on the
## origin, mirrored for `facing` -1, centred for pickups), else its shapes.
static func draw(canvas: CanvasItem, weapon: WeaponData, facing := 1, centered := false) -> void:
	if weapon.sprite != null:
		var corner := -weapon.sprite.get_size() / 2.0 if centered else -weapon.sprite_grip
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
		canvas.draw_texture(weapon.sprite, corner)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	for part in shapes(weapon, facing, centered):
		canvas.draw_colored_polygon(part.points, part.color)


static func has_art(weapon_id: StringName) -> bool:
	return art.has(weapon_id)


## Coloured polygons for `weapon`, mirrored when `facing` is -1. `centered`
## moves the drawing's middle to the origin (pickups lying on the floor).
static func shapes(weapon: WeaponData, facing := 1, centered := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_art(weapon.id):
		for entry in art[weapon.id]:
			var part_color: Color = weapon.color if entry[1] == null else entry[1]
			out.append({"points": _points(entry[0]), "color": part_color})
	else:
		var length := weapon.muzzle_offset if weapon.is_ranged() else weapon.melee_offset
		out.append({"points": _points(Rect2(0, -1.5, length, 3)), "color": weapon.color})
	var shift := Vector2.ZERO
	if centered:
		var box := Rect2(out[0].points[0], Vector2.ZERO)
		for part in out:
			for point in part.points:
				box = box.expand(point)
		shift = -box.get_center()
	for part in out:
		var points: PackedVector2Array = part.points
		for i in points.size():
			points[i] = Vector2((points[i].x + shift.x) * facing, points[i].y + shift.y)
		part.points = points
	return out


static func _points(shape) -> PackedVector2Array:
	if shape is PackedVector2Array:
		return shape.duplicate()
	var rect: Rect2 = shape
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
