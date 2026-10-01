class_name Hurtbox
extends Area2D

## Area that can be struck by a Hitbox. Forwards damage to its HealthComponent
## and re-emits the hit so the owner can react (knockback, flash, sound).

signal hit_received(damage: int, knockback: Vector2, source: Node)
## A hit stopped by the owner's guard (`kind`: &"melee", or &"bullet" for a
## bullet sent back by a parry).
signal blocked(kind: StringName)

@export var health: HealthComponent
## Melee (Hitbox) swings land (hit_landed, sounds) but deal no damage: map
## blocks that only bullets and blasts can break.
@export var melee_proof := false
## Set by the owner during a dodge (dive, roll): bullets fly through. Melee
## already misses then because the owner turns `monitorable` off, but
## bullets are rays and don't look at it.
var dodging := false


## `kind` and `from` (where the hit comes from, global) let the owner block
## it: an owner with `guard(kind, from, damage, source) -> bool` returning
## true takes nothing more (it may take chip damage itself).
func receive_hit(damage: int, knockback: Vector2, source: Node, kind := &"hit", from := Vector2.INF) -> void:
	if health == null or health.is_dead():
		return
	if owner != null and owner.has_method("guard") and owner.guard(kind, from, damage, source):
		blocked.emit(kind)
		return
	health.take_damage(damage, source)
	hit_received.emit(damage, knockback, source)


## A bullet arriving from `from`: true if the owner parries it back.
func try_deflect(from: Vector2) -> bool:
	if owner == null or not owner.has_method("parry") or not owner.parry(from):
		return false
	blocked.emit(&"bullet")
	return true
