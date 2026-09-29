class_name SupplyCrate
extends BreakableProp

## Wooden crate dropped from the sky (Superfighters): it falls onto the map,
## hurts whoever it lands on, and breaking it (punches, bullets, blasts)
## leaves its weapon on the floor for whoever gets there first.

const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")

## Players only (layer 2).
const FIGHTER_MASK := 2
## Falling faster than this (px/s) hurts the fighter it lands on.
const CRUSH_SPEED := 160.0

## What's inside; the spawner picks it.
var weapon: WeaponData
@export var crush_damage := 20

var _crushed := {}


var _was_on_floor := false


func _physics_process(delta: float) -> void:
	_check_crush()
	super(delta)
	if is_on_floor() and not _was_on_floor:
		SharedCamera.shake(self, 0.2)
	_was_on_floor = is_on_floor()


func _check_crush() -> void:
	# Fighters are not in the crate's mask (they'd stand on a falling crate),
	# so landing on a head is checked by hand below the crate.
	if velocity.y < CRUSH_SPEED:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 4)
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0, 2))
	query.collision_mask = FIGHTER_MASK
	for result in get_world_2d().direct_space_state.intersect_shape(query, 4):
		var body: Node = result.collider
		var target := HazardZone.health_of(body)
		if target == null or target.is_dead() or _crushed.has(body):
			continue
		_crushed[body] = true
		target.take_damage(crush_damage, self)
		if "velocity" in body:
			body.velocity.y = maxf(body.velocity.y, 120.0)
		velocity.y = -80.0


func _break() -> void:
	if weapon == null:
		return
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = weapon
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector2(0, -4)


## Placeholder look until the art pass: planks with a cross brace and a
## small parachute-less label in the weapon's colour.
func _draw() -> void:
	var wood := Color.WHITE if is_flashing() else Color("b86f50")
	draw_rect(Rect2(-8, -16, 16, 16), wood)
	draw_rect(Rect2(-8, -16, 16, 2), Color("733e39"))
	draw_rect(Rect2(-8, -2, 16, 2), Color("733e39"))
	draw_line(Vector2(-7, -14), Vector2(7, -2), Color("733e39"), 1.5)
	draw_rect(Rect2(-3, -10, 6, 4), weapon.color if weapon != null else Color("feae34"))
