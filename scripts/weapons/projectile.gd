class_name Projectile
extends Node2D

## Bullet or pellet. Instead of an Area2D that can tunnel through thin walls
## at high speed, it ray-casts the segment it travels each physics frame and
## stops at the first world body or Hurtbox on that segment.

signal impacted(point: Vector2, collider: Object)

## Layer 1 (world) + layer 4 (hurtboxes).
const HIT_MASK := 1 | 8

var velocity := Vector2.ZERO
var damage := 10
var knockback := Vector2.ZERO
var max_distance := 400.0
var color := Color(1.0, 0.9, 0.5)
var shooter: Node

var _travelled := 0.0
var _exclude: Array[RID] = []


## `exclude` holds the shooter's own hurtboxes so a shot never hits its owner.
func setup(from: Vector2, direction: Vector2, weapon: WeaponData, source: Node, exclude: Array[RID]) -> void:
	global_position = from
	velocity = direction.normalized() * weapon.projectile_speed
	damage = weapon.damage
	knockback = Vector2(weapon.knockback.x * signf(direction.x), weapon.knockback.y)
	max_distance = weapon.projectile_range
	shooter = source
	_exclude = exclude
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var remaining := max_distance - _travelled
	if step.length() > remaining:
		step = step.normalized() * remaining

	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, HIT_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_impact(hit)
		return

	global_position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()


func _impact(hit: Dictionary) -> void:
	global_position = hit.position
	var hurtbox := hit.collider as Hurtbox
	if hurtbox != null:
		hurtbox.receive_hit(damage, knockback, shooter)
	impacted.emit(hit.position, hit.collider)
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-4, -1, 6, 2), color)
