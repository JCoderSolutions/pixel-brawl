extends "res://scripts/weapons/weapons_demo.gd"

## Grenade sandbox (TASK-006): same controls as the weapons demo, starting
## with grenades in hand and more spawning on the map. Throw them at the
## crate wall or the dummies behind it.

const GRENADE := preload("res://scripts/weapons/data/grenade.tres")


func _ready() -> void:
	super()
	holder.equip(GRENADE)
