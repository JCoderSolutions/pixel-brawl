class_name WeaponPickup
extends RigidBody2D

## A weapon lying in the world. Falls and bounces on the map (mask 1) but
## never blocks players or bullets (layer 0). WeaponHolder finds it through
## the "weapon_pickups" group, so no extra physics layer is needed.

const GROUP := &"weapon_pickups"

@export var weapon: WeaponData:
	set(value):
		weapon = value
		_refresh_visual()
## Remaining uses; -1 fills it to the weapon's max ammo on pickup.
@export var ammo := -1

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	_refresh_visual()


## Hands the weapon over and removes the pickup from the world.
func take() -> Array:
	remove_from_group(GROUP)
	queue_free()
	return [weapon, ammo]


func _refresh_visual() -> void:
	if _visual != null and weapon != null:
		_visual.color = weapon.color
