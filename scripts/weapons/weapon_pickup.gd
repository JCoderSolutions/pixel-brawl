class_name WeaponPickup
extends RigidBody2D

## A weapon lying in the world. Falls and bounces on the map (mask 1) but
## never blocks players or bullets (layer 0). WeaponHolder finds it through
## the "weapon_pickups" group, so no extra physics layer is needed.

const GROUP := &"weapon_pickups"
## A thrown weapon stops hurting below this speed (px/s).
const THROW_MIN_SPEED := 110.0
## Seconds an empty thrown gun lies on the floor before it goes.
const SPENT_LIFETIME := 1.5
const THROW_KNOCKBACK := Vector2(180.0, -90.0)

@export var weapon: WeaponData:
	set(value):
		weapon = value
		_refresh_visual()
## Remaining uses; -1 fills it to the weapon's max ammo on pickup.
@export var ammo := -1

var _throw_hitbox: Hitbox
var _throw_time := 0.0
var _spent := false
var _spent_time := 0.0


func _ready() -> void:
	if not _spent:
		add_to_group(GROUP)
	_refresh_visual()


## Turns this pickup into a thrown weapon: until it slows down it hurts the
## first fighter it touches (never `thrower`). An empty gun can't be picked
## up again and fades out once it lands.
func start_throw(thrower: Node, damage: int, facing: int) -> void:
	_throw_hitbox = Hitbox.new()
	_throw_hitbox.collision_layer = 4
	_throw_hitbox.collision_mask = 8
	_throw_hitbox.damage = damage
	_throw_hitbox.knockback = THROW_KNOCKBACK
	_throw_hitbox.direction = facing
	_throw_hitbox.exclude = thrower
	var collider := CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	collider.shape.size = Vector2(16, 10)
	_throw_hitbox.add_child(collider)
	add_child(_throw_hitbox)
	_throw_hitbox.hit_landed.connect(func(_target: Hurtbox) -> void:
		linear_velocity *= 0.25
		_end_throw())
	_throw_hitbox.activate()
	_throw_time = 0.0
	if weapon != null and not weapon.has_unlimited_ammo() and ammo == 0:
		_spent = true
		remove_from_group(GROUP)


func is_thrown() -> bool:
	return _throw_hitbox != null and _throw_hitbox.is_active()


func _physics_process(delta: float) -> void:
	if _throw_hitbox != null:
		_throw_time += delta
		if _throw_time > 0.1 and linear_velocity.length() < THROW_MIN_SPEED:
			_end_throw()
	if _spent and not is_thrown():
		_spent_time += delta
		modulate.a = clampf(1.0 - (_spent_time - SPENT_LIFETIME * 0.5) / (SPENT_LIFETIME * 0.5), 0.0, 1.0)
		if _spent_time >= SPENT_LIFETIME:
			queue_free()


func _end_throw() -> void:
	if _throw_hitbox != null and _throw_hitbox.is_active():
		_throw_hitbox.deactivate()


## Hands the weapon over and removes the pickup from the world.
func take() -> Array:
	remove_from_group(GROUP)
	queue_free()
	return [weapon, ammo]


## The weapon's art (WeaponArt), centred on the pickup.
func art_shapes() -> Array[Dictionary]:
	if weapon == null:
		return []
	return WeaponArt.shapes(weapon, 1, true)


func _refresh_visual() -> void:
	queue_redraw()


func _draw() -> void:
	if weapon != null:
		WeaponArt.draw(self, weapon, 1, true)
