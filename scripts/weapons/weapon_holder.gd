class_name WeaponHolder
extends Node2D

## Hand of a fighter. Add it as a child of any body (player, bot, remote peer)
## at hand height and drive it with `facing`, `try_use()`, `try_pick_up()`,
## `switch_next()` and `drop()`. Ranged weapons spawn Projectiles, grenades
## are thrown as Grenade bodies and melee weapons reuse the same Hitbox as
## punches, so every hit goes through Hurtbox -> HealthComponent.
##
## Inventory (Superfighters): one weapon per WeaponData.Slot (melee, handgun,
## rifle, throwable). `weapon` and `ammo` are the ones in hand; the rest are
## carried until switched to. When the weapon in hand leaves it (dropped,
## thrown, used up) the best carried one is drawn.

signal weapon_equipped(weapon: WeaponData, ammo: int)
signal weapon_dropped(weapon: WeaponData, ammo: int)
signal weapon_spent(weapon: WeaponData)
signal ammo_changed(ammo: int)
signal fired(weapon: WeaponData, projectile_count: int)
## The trigger was pulled on an empty gun: it only clicks.
signal dry_fired(weapon: WeaponData)
signal weapon_thrown(weapon: WeaponData)
## Another carried weapon (or the fists, null) was drawn.
signal weapon_switched(weapon: WeaponData)
## Anything carried changed: picked up, dropped, used up or switched.
signal inventory_changed

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
		_pose()
		queue_redraw()

## The weapon in hand; null means fists.
var weapon: WeaponData:
	get:
		return _carried[active_slot] if active_slot >= 0 else null
## Uses left of the weapon in hand (-1 with nothing in hand).
var ammo: int:
	get:
		return _ammo_left[active_slot] if active_slot >= 0 else -1
	set(value):
		if active_slot >= 0:
			_ammo_left[active_slot] = value
## WeaponData.Slot in hand, or -1 for the fists.
var active_slot := -1
## Scales bullet and blade damage (strength power-up); 1 = normal.
var damage_multiplier := 1.0
## Manual aim (Superfighters): radians off the facing side, negative = up.
## Guns, grenades and rockets leave along it and the weapon is drawn
## turned to it.
var aim_angle := 0.0:
	set(value):
		aim_angle = clampf(value, -MAX_AIM, MAX_AIM)
		_pose()
		queue_redraw()
## Draws a laser sight along the aim while the owner is aiming.
var aiming := false:
	set(value):
		aiming = value
		queue_redraw()

const MAX_AIM := PI * 0.45
const SIGHT_LENGTH := 90.0
const SLOT_COUNT := 4
## Seconds a freshly drawn weapon takes before it can be used.
const SWITCH_TIME := 0.15
## What gets drawn when the hand empties: the heaviest firepower first.
const DRAW_ORDER := [WeaponData.Slot.RIFLE, WeaponData.Slot.HANDGUN,
		WeaponData.Slot.MELEE, WeaponData.Slot.THROWABLE]

var _carried: Array[WeaponData] = [null, null, null, null]
var _ammo_left: Array[int] = [-1, -1, -1, -1]

## Recoil: pixels the gun is pushed back along the aim; springs back.
var kick := 0.0
## Gun rise per pixel of kick (rad): the muzzle tips up on each shot.
const KICK_CLIMB := 0.04
## How fast the gun comes back after a shot (px/s).
const KICK_RETURN := 28.0

var _cooldown := 0.0
var _swing_timer := 0.0
## Where the owner placed the hand; recoil moves the gun off it and back.
var _rest_position := Vector2.ZERO
## Seeded, so the same inputs give the same shots (replays, online sync).
var _rng := RandomNumberGenerator.new()
var _melee_hitbox: Hitbox
var _melee_shape: RectangleShape2D


func _ready() -> void:
	_rest_position = position
	_rng.seed = 1
	_build_melee_hitbox()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_swing(delta)
	if kick > 0.0:
		kick = move_toward(kick, 0.0, KICK_RETURN * delta)
		_pose()


## Turns the gun to the aim, tipped up and pushed back by the recoil. Only
## the drawing moves: shots leave along aim_direction().
func _pose() -> void:
	rotation = (aim_angle - kick * KICK_CLIMB) * facing
	if is_inside_tree():
		position = _rest_position - aim_direction() * kick


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
		return data.is_rocket()
	return data.is_ranged()


## Puts `data` in its slot (replacing what was there) and in hand.
## `with_ammo` < 0 means a fresh weapon with full ammo.
func equip(data: WeaponData, with_ammo := -1) -> void:
	_carried[data.slot] = data
	_ammo_left[data.slot] = data.max_ammo if with_ammo < 0 or data.has_unlimited_ammo() else with_ammo
	_select(data.slot)
	_cooldown = 0.0
	weapon_equipped.emit(weapon, ammo)
	ammo_changed.emit(ammo)


## The weapon carried in `slot` (WeaponData.Slot), in hand or not.
func carried(slot: int) -> WeaponData:
	return _carried[slot]


func ammo_in(slot: int) -> int:
	return _ammo_left[slot]


func carried_count() -> int:
	return SLOT_COUNT - _carried.count(null)


## Draws the next carried weapon, cycling fists -> melee -> handgun -> rifle
## -> throwable. Returns false if there is nothing else to draw.
func switch_next() -> bool:
	for step in range(1, SLOT_COUNT + 1):
		var slot := (active_slot + 1 + step) % (SLOT_COUNT + 1) - 1
		if slot == -1 or _carried[slot] != null:
			_select(slot)
			_cooldown = SWITCH_TIME
			weapon_switched.emit(weapon)
			ammo_changed.emit(ammo)
			return true
	return false


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
				_draw_best()
			weapon_spent.emit(used)
	return true


## Grabs the nearest pickup in reach into its slot and draws it. The same
## weapon tops up the ammo of the one carried; a different one swaps it out
## (dropped where the fighter stands).
func try_pick_up() -> bool:
	var pickup := _nearest_pickup()
	if pickup == null:
		return false
	var data := pickup.weapon
	var mine := _carried[data.slot]
	if mine != null and mine.id == data.id and not data.has_unlimited_ammo() \
			and _ammo_left[data.slot] < data.max_ammo:
		var extra: int = pickup.take()[1]
		_ammo_left[data.slot] = mini(_ammo_left[data.slot] + (data.max_ammo if extra < 0 else extra), data.max_ammo)
		_select(data.slot)
		weapon_equipped.emit(weapon, ammo)
		ammo_changed.emit(ammo)
		return true
	var taken := pickup.take()
	if mine != null:
		var swapped := _release(data.slot, Vector2(drop_velocity.x * facing, drop_velocity.y))
		weapon_dropped.emit(swapped.weapon, swapped.ammo)
	equip(taken[0], taken[1])
	return true


## Throws the weapon in hand into the world with its remaining ammo and
## draws the next carried one.
func drop() -> WeaponPickup:
	if not has_weapon():
		return null
	var pickup := _release(active_slot, Vector2(drop_velocity.x * facing, drop_velocity.y))
	_draw_best()
	weapon_dropped.emit(pickup.weapon, pickup.ammo)
	return pickup


## Lets go of everything carried (a fighter going down), fanned out a bit so
## the pickups don't stack.
func drop_all() -> Array[WeaponPickup]:
	var dropped: Array[WeaponPickup] = []
	for slot in SLOT_COUNT:
		if _carried[slot] == null:
			continue
		var spread := 0.5 + 0.35 * dropped.size()
		var pickup := _release(slot, Vector2(drop_velocity.x * facing * spread, drop_velocity.y))
		dropped.append(pickup)
		weapon_dropped.emit(pickup.weapon, pickup.ammo)
	return dropped


## Throws the weapon in hand at whoever stands in front: it flies fast and
## hurts the first fighter it hits for `throw_damage`, never the thrower.
func throw_weapon() -> WeaponPickup:
	if not has_weapon():
		return null
	var pickup := _release(active_slot, Vector2(throw_velocity.x * facing, throw_velocity.y))
	var thrown := pickup.weapon
	pickup.start_throw(_wielder(), roundi(thrown.throw_damage * damage_multiplier), facing)
	_draw_best()
	weapon_thrown.emit(thrown)
	return pickup


## Where the weapon points, in world space.
func aim_direction() -> Vector2:
	return Vector2(facing * cos(aim_angle), sin(aim_angle))


func _fire(data: WeaponData) -> void:
	var forward := aim_direction()
	var muzzle := global_position + forward * data.muzzle_offset
	var exclude := _own_hurtbox_rids()
	var angles := data.spread_angles()
	var jitter := _rng.randf_range(-data.jitter_degrees, data.jitter_degrees)
	for angle in angles:
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		_world().add_child(projectile)
		projectile.setup(muzzle, forward.rotated(deg_to_rad(angle + jitter)), data, _wielder(), exclude)
		projectile.damage = roundi(projectile.damage * damage_multiplier)
	kick = data.recoil
	_pose()
	fired.emit(data, angles.size())


func _throw(data: GrenadeData) -> void:
	var grenade: Grenade = GRENADE_SCENE.instantiate()
	_world().add_child(grenade)
	var from := global_position + aim_direction() * data.muzzle_offset
	var launch := data.throw_velocity.rotated(aim_angle)
	launch.x *= facing
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


## Empties the slot in hand; the fists are left until something is drawn.
func _clear() -> void:
	if active_slot >= 0:
		_carried[active_slot] = null
		_ammo_left[active_slot] = -1
	_select(-1)


func _select(slot: int) -> void:
	active_slot = slot
	_cancel_swing()
	queue_redraw()
	inventory_changed.emit()


## Draws the best carried weapon, or leaves the fists.
func _draw_best() -> void:
	for slot in DRAW_ORDER:
		if _carried[slot] != null:
			_select(slot)
			_cooldown = SWITCH_TIME
			weapon_switched.emit(weapon)
			ammo_changed.emit(ammo)
			return
	_select(-1)


## Takes the weapon out of `slot` and into the world as a pickup flying at
## `launch`. Doesn't draw anything else.
func _release(slot: int, launch: Vector2) -> WeaponPickup:
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = _carried[slot]
	pickup.ammo = _ammo_left[slot]
	pickup.linear_velocity = launch
	_world().add_child(pickup)
	pickup.global_position = global_position
	_carried[slot] = null
	_ammo_left[slot] = -1
	if slot == active_slot:
		_select(-1)
	else:
		inventory_changed.emit()
	return pickup


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
	if aiming:
		# Laser sight, dashed, in local space: the node is already rotated.
		var step := 6.0
		var from := weapon.muzzle_offset
		while from < SIGHT_LENGTH:
			draw_line(Vector2(from * facing, 0.0), Vector2(minf(from + step / 2.0, SIGHT_LENGTH) * facing, 0.0), Color(1, 0.2, 0.2, 0.7), 1.0)
			from += step
