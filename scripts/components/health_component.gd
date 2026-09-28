class_name HealthComponent
extends Node

## Reusable hit points container. Owners listen to its signals instead of
## tracking health themselves, so players, props and destructible tiles can
## share the same damage pipeline.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal died(source: Node)
signal shield_changed(shield: int)

@export var max_health := 100

var current_health: int
## Points soaked up before health (shield power-up). Knockback still lands.
var shield := 0:
	set(value):
		shield = maxi(value, 0)
		shield_changed.emit(shield)


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or is_dead():
		return
	if shield > 0:
		var absorbed := mini(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount == 0:
			return
	current_health = max(current_health - amount, 0)
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit(source)


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
