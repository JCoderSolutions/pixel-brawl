class_name Hurtbox
extends Area2D

## Area that can be struck by a Hitbox. Forwards damage to its HealthComponent
## and re-emits the hit so the owner can react (knockback, flash, sound).

signal hit_received(damage: int, knockback: Vector2, source: Node)

@export var health: HealthComponent


func receive_hit(damage: int, knockback: Vector2, source: Node) -> void:
	if health == null or health.is_dead():
		return
	health.take_damage(damage, source)
	hit_received.emit(damage, knockback, source)
