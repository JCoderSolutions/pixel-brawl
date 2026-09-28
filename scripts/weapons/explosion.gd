class_name Explosion
extends Node2D

## One blast. `detonate()` hits every Hurtbox inside the radius once, with
## damage and knockback falling off towards the edge, and hands map damage to
## DestructibleMap.damage_area() so tiles break through their own pipeline.
## Then it draws a short flash and frees itself.

signal exploded(center: Vector2, radius: float, hits: int)

## Layer 4 (hurtboxes).
const HURTBOX_MASK := 8
const FLASH_TIME := 0.3
## Trauma added to the cameras that see the blast.
const SHAKE := 0.8

@export var radius := 40.0
@export var damage := 45
@export_range(0.0, 1.0) var min_damage_ratio := 0.35
@export var knockback := 320.0
@export var lift := 120.0
@export var block_damage := 30

var _flash := 0.0


func configure(data: GrenadeData) -> void:
	radius = data.explosion_radius
	damage = data.damage
	min_damage_ratio = data.min_damage_ratio
	knockback = data.explosion_knockback
	lift = data.explosion_lift
	block_damage = data.block_damage


## Applies the blast at the current global position. Returns how many
## fighters/props (not map tiles) were hit.
func detonate(source: Node = null) -> int:
	var hits := 0
	var seen := {}
	for hurtbox in _hurtboxes_in_range():
		# Tiles take damage through their map below, not per hurtbox.
		if hurtbox.get_parent() is DestructibleBlock:
			continue
		# One hit per health pool even if a body has several hurtboxes.
		var key: Object = hurtbox.health if hurtbox.health != null else hurtbox
		if seen.has(key):
			continue
		seen[key] = true
		var target := _hurtbox_center(hurtbox)
		var falloff := clampf(global_position.distance_to(target) / radius, 0.0, 1.0)
		var amount := roundi(damage * lerpf(1.0, min_damage_ratio, falloff))
		hurtbox.receive_hit(amount, knockback_at(target), source)
		hits += 1
	for map: DestructibleMap in get_tree().root.find_children("*", "DestructibleMap", true, false):
		map.damage_area(global_position, radius, block_damage, source)
	SharedCamera.shake(self, SHAKE)
	_flash = FLASH_TIME
	queue_redraw()
	exploded.emit(global_position, radius, hits)
	return hits


## Push for a target at `target` (global): away from the centre, fading with
## distance, plus a lift so fighters get launched.
func knockback_at(target: Vector2) -> Vector2:
	var offset := target - global_position
	var direction := offset.normalized() if offset.length() > 0.5 else Vector2.UP
	var falloff := clampf(offset.length() / radius, 0.0, 1.0)
	var strength := knockback * lerpf(1.0, 0.5, falloff)
	return direction * strength + Vector2(0.0, -lift)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	queue_redraw()
	if _flash <= 0.0:
		queue_free()


func _hurtboxes_in_range() -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var hurtbox := result.collider as Hurtbox
		if hurtbox != null:
			found.append(hurtbox)
	return found


func _hurtbox_center(hurtbox: Hurtbox) -> Vector2:
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			return (child as CollisionShape2D).global_position
	return hurtbox.global_position


## Placeholder flash until the art pass: an orange disc that shrinks and fades.
func _draw() -> void:
	if _flash <= 0.0:
		return
	var t := _flash / FLASH_TIME
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * t), Color(0.996, 0.682, 0.204, 0.55 * t))
	draw_circle(Vector2.ZERO, radius * 0.45 * t, Color(1.0, 0.96, 0.8, 0.9 * t))
