class_name WeaponHolder
extends Node2D

## Hand of a fighter. Add it as a child of any body (player, bot, remote peer)
## at hand height and drive it with `facing`, `try_use()`, `try_pick_up()`
## and `drop()`. Ranged weapons spawn Projectiles, grenades are thrown as
## Grenade bodies and melee weapons reuse the same Hitbox as punches, so every
## hit goes through Hurtbox -> HealthComponent.

signal weapon_equipped(weapon: WeaponData, ammo: int)
signal weapon_dropped(weapon: WeaponData, ammo: int)
signal weapon_spent(weapon: WeaponData)
signal ammo_changed(ammo: int)
signal fired(weapon: WeaponData, projectile_count: int)
## The trigger was pulled on an empty gun: it only clicks.
signal dry_fired(weapon: WeaponData)
signal weapon_thrown(weapon: WeaponData)

const PROJECTILE_SCENE := preload("res://scenes/items/projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const GRENADE_SCENE := preload("res://scenes/items/grenade.tscn")

@export var pickup_radius := 28.0
@export var drop_velocity := Vector2(90.0, -160.0)
@export var throw_velocity := Vector2(380.0, -70.0)
## Where projectiles and dropped weapons go; defaults to the wielder's parent
## so they stay in the world when the wielder moves or dies.
@export var world: Node

## 1 = right, -1 = left. The owner keeps this in sync with its own facing.
var facing := 1:
	set(value):
		facing = 1 if value >= 0 else -1
		queue_redraw()

var weapon: WeaponData
var ammo := -1
## Scales bullet and blade damage (strength power-up); 1 = normal.
var damage_multiplier := 1.0

var _cooldown := 0.0
var _swing_timer := 0.0
var _melee_hitbox: Hitbox
var _melee_shape: RectangleShape2D


func _ready() -> void:
	_build_melee_hitbox()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_swing(delta)


func has_weapon() -> bool:
	return weapon != null


func is_ready() -> bool:
	return has_weapon() and _cooldown == 0.0 and _swing_timer == 0.0


## A gun with no ammo left, still in hand: throw it (Superfighters).
func is_empty() -> bool:
	return has_weapon() and not weapon.has_unlimited_ammo() and ammo <= 0


## Guns (and the bazooka tube) stay in hand when empty; a hand grenade is
## the ammo itself, so the last one leaves the hand empty.
static func keeps_when_empty(data: WeaponData) -> bool:
	if data is GrenadeData:
		return data.explode_on_contact
	return data.is_ranged()


## Equips `data`. `with_ammo` < 0 means a fresh weapon with full ammo.
func equip(data: WeaponData, with_ammo := -1) -> void:
	weapon = data
	ammo = data.max_ammo if with_ammo < 0 or data.has_unlimited_ammo() else with_ammo
	_cooldown = 0.0
	_cancel_swing()
	weapon_equipped.emit(weapon, ammo)
	ammo_changed.emit(ammo)
	queue_redraw()


## Fires or swings the current weapon. Returns false if nothing happened.
func try_use() -> bool:
	if not is_ready():
		return false
	if is_empty():
		_cooldown = weapon.cooldown
		dry_fired.emit(weapon)
		return false
	var used := weapon
	_cooldown = used.cooldown
	if used is GrenadeData:
		_throw(used)
	elif used.is_ranged():
		_fire(used)
	else:
		_start_swing(used)
	if not used.has_unlimited_ammo():
		ammo -= 1
		ammo_changed.emit(ammo)
		if ammo <= 0:
			if not keeps_when_empty(used):
				_clear()
			weapon_spent.emit(used)
	return true


## Grabs the nearest pickup in reach, dropping the current weapon first.
func try_pick_up() -> bool:
	var pickup := _nearest_pickup()
	if pickup == null:
		return false
	var taken := pickup.take()
	drop()
	equip(taken[0], taken[1])
	return true


## Throws the current weapon into the world with its remaining ammo.
func drop() -> WeaponPickup:
	if not has_weapon():
		return null
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = weapon
	pickup.ammo = ammo
	pickup.linear_velocity = Vector2(drop_velocity.x * facing, drop_velocity.y)
	_world().add_child(pickup)
	pickup.global_position = global_position
	var dropped := weapon
	var left := ammo
	_clear()
	weapon_dropped.emit(dropped, left)
	return pickup


## Throws the weapon in hand at whoever stands in front: it flies fast and
## hurts the first fighter it hits for `throw_damage`, never the thrower.
func throw_weapon() -> WeaponPickup:
	if not has_weapon():
		return null
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = weapon
	pickup.ammo = ammo
	pickup.linear_velocity = Vector2(throw_velocity.x * facing, throw_velocity.y)
	_world().add_child(pickup)
	pickup.global_position = global_position
	var thrown := weapon
	pickup.start_throw(_wielder(), roundi(thrown.throw_damage * damage_multiplier), facing)
	_clear()
	weapon_thrown.emit(thrown)
	return pickup


func _fire(data: WeaponData) -> void:
	var muzzle := global_position + Vector2(data.muzzle_offset * facing, 0.0)
	var forward := Vector2(facing, 0.0)
	var exclude := _own_hurtbox_rids()
	var angles := data.spread_angles()
	for angle in angles:
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_world().add_child(projectile)
		projectile.setup(muzzle, forward.rotated(deg_to_rad(angle)), data, _wielder(), exclude)
		projectile.damage = roundi(projectile.damage * damage_multiplier)
	fired.emit(data, angles.size())


func _throw(data: GrenadeData) -> void:
	var grenade: Grenade = GRENADE_SCENE.instantiate()
	_world().add_child(grenade)
	var from := global_position + Vector2(data.muzzle_offset * facing, 0.0)
	var launch := Vector2(data.throw_velocity.x * facing, data.throw_velocity.y)
	grenade.setup(data, from, launch, _wielder())
	fired.emit(data, 1)


func _start_swing(data: WeaponData) -> void:
	_melee_hitbox.damage = roundi(data.damage * damage_multiplier)
	_melee_hitbox.knockback = data.knockback
	_melee_hitbox.direction = facing
	_melee_hitbox.position = Vector2(data.melee_offset * facing, 0.0)
	_melee_shape.size = data.reach
	_swing_timer = data.melee_startup + data.melee_active
	fired.emit(data, 0)


## Same wind-up -> strike shape as the player's punch: the Hitbox opens after
## startup and stays open for the active window.
func _update_swing(delta: float) -> void:
	if _swing_timer == 0.0:
		return
	_swing_timer = maxf(_swing_timer - delta, 0.0)
	var active_window := weapon != null and _swing_timer > 0.0 and _swing_timer <= weapon.melee_active
	if active_window and not _melee_hitbox.is_active():
		_melee_hitbox.activate()
	elif not active_window and _melee_hitbox.is_active():
		_melee_hitbox.deactivate()


func _cancel_swing() -> void:
	_swing_timer = 0.0
	if _melee_hitbox != null and _melee_hitbox.is_active():
		_melee_hitbox.deactivate()


func _clear() -> void:
	weapon = null
	ammo = -1
	_cancel_swing()
	queue_redraw()


func _build_melee_hitbox() -> void:
	_melee_hitbox = Hitbox.new()
	_melee_hitbox.name = "MeleeHitbox"
	_melee_hitbox.collision_layer = 4
	_melee_hitbox.collision_mask = 8
	var collider := CollisionShape2D.new()
	_melee_shape = RectangleShape2D.new()
	collider.shape = _melee_shape
	_melee_hitbox.add_child(collider)
	add_child(_melee_hitbox)
	# Hitbox skips hurtboxes that share its owner; owning it by the wielder
	# keeps the blade from cutting whoever holds it.
	_melee_hitbox.owner = _wielder()


func _nearest_pickup() -> WeaponPickup:
	var best: WeaponPickup = null
	var best_distance := pickup_radius
	for node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		var distance := global_position.distance_to(pickup.global_position)
		if distance <= best_distance:
			best = pickup
			best_distance = distance
	return best


func _own_hurtbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for node in _wielder().find_children("*", "Hurtbox", true, false):
		rids.append((node as Hurtbox).get_rid())
	return rids


func _wielder() -> Node:
	return get_parent()


func _world() -> Node:
	if world != null:
		return world
	var wielder := _wielder()
	return wielder.get_parent() if wielder.get_parent() != null else wielder


## The weapon's sprite, or its native-shape art (WeaponArt) without one.
func _draw() -> void:
	if weapon == null:
		return
	WeaponArt.draw(self, weapon, facing)
