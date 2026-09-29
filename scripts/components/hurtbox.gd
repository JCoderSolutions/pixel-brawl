class_name Hurtbox
extends Area2D

## Area that can be struck by a Hitbox. Forwards damage to its HealthComponent
## and re-emits the hit so the owner can react (knockback, flash, sound).

signal hit_received(damage: int, knockback: Vector2, source: Node)

@export var health: HealthComponent
## Melee (Hitbox) swings land (hit_landed, sounds) but deal no damage: map
## blocks that only bullets and blasts can break.
@export var melee_proof := false


func receive_hit(damage: int, knockback: Vector2, source: Node) -> void:
	if health == null or health.is_dead():
		return
	health.take_damage(damage, source)
	hit_received.emit(damage, knockback, source)
