class_name WeaponIcon
extends Control

## The weapon's own art (sprite or WeaponArt shapes), centred in a small box:
## the HUD shows it next to the weapon's name. Empty when `weapon` is null.

var weapon: WeaponData:
	set(value):
		weapon = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if weapon == null:
		return
	var center := (size / 2.0).floor()
	if weapon.sprite != null:
		draw_texture(weapon.sprite, center - (weapon.sprite.get_size() / 2.0).floor())
		return
	for part in WeaponArt.shapes(weapon, 1, true):
		var points: PackedVector2Array = part.points
		for i in points.size():
			points[i] += center
		draw_colored_polygon(points, part.color)
