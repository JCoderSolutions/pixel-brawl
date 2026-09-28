class_name HealthComponent
extends Node

## Reusable hit points container. Owners listen to its signals instead of
## tracking health themselves, so players, props and destructible tiles can
## share the same damage pipeline.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal died(source: Node)

@export var max_health := 100

var current_health: int


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or is_dead():
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
