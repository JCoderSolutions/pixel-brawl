class_name WeaponSpawner
extends Node2D

## Drops random weapons on the map. Spawn points are the Marker2D children
## (or the spawner itself if it has none); a point is reused only once its
## weapon has been taken, and at most `max_active` items wait on the map.
## Each tick drops a power-up instead of a weapon with `power_up_chance`.
## With `crate_interval` it also drops supply crates from the sky above a
## random point (Superfighters): break one to get the weapon inside.

signal weapon_spawned(pickup: WeaponPickup)
signal power_up_spawned(pickup: PowerUpPickup)
signal crate_dropped(crate: SupplyCrate)

const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const POWER_UP_SCENE := preload("res://scenes/powerups/power_up_pickup.tscn")
const CRATE_SCENE := preload("res://scenes/props/supply_crate.tscn")
## How high above its point a crate starts falling (px), unless a ceiling is
## lower.
const CRATE_DROP_HEIGHT := 220.0

@export var weapons: Array[WeaponData] = []
@export var power_ups: Array[PowerUpData] = []
@export_range(0.0, 1.0) var power_up_chance := 0.3
@export var spawn_interval := 8.0
@export var max_active := 3
@export var autostart := true
## 0 randomizes every match; any other value replays the same sequence.
@export var rng_seed := 0
## Seconds between supply crates; 0 = no crates.
@export var crate_interval := 0.0
## Unbroken crates allowed on the map at once.
@export var max_crates := 2

var _rng := RandomNumberGenerator.new()
var _occupied := {}
var _timer: Timer
var _crate_timer: Timer
var _crates: Array[SupplyCrate] = []


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(spawn_random)
	add_child(_timer)
	_crate_timer = Timer.new()
	_crate_timer.wait_time = maxf(crate_interval, 0.01)
	_crate_timer.timeout.connect(drop_crate)
	add_child(_crate_timer)
	if autostart:
		_timer.start()
		if crate_interval > 0.0:
			_crate_timer.start()


func pick_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[_rng.randi_range(0, weapons.size() - 1)]


func pick_power_up() -> PowerUpData:
	if power_ups.is_empty():
		return null
	return power_ups[_rng.randi_range(0, power_ups.size() - 1)]


## What the timer calls: a power-up with `power_up_chance`, else a weapon.
func spawn_random() -> Node2D:
	var wants_power_up := not power_ups.is_empty() \
			and (weapons.is_empty() or _rng.randf() < power_up_chance)
	return spawn_power_up() if wants_power_up else spawn_one()


## Spawns one random weapon at a free point. Returns null when full.
func spawn_one() -> WeaponPickup:
	var data := pick_weapon()
	if data == null:
		return null
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = data
	if not _place(pickup):
		return null
	weapon_spawned.emit(pickup)
	return pickup


## Spawns one random power-up at a free point. Returns null when full.
func spawn_power_up() -> PowerUpPickup:
	var data := pick_power_up()
	if data == null:
		return null
	var pickup: PowerUpPickup = POWER_UP_SCENE.instantiate()
	pickup.power_up = data
	if not _place(pickup):
		return null
	power_up_spawned.emit(pickup)
	return pickup


## Drops a crate holding a random weapon from above one of the points.
## Returns null when there are already `max_crates` waiting.
func drop_crate() -> SupplyCrate:
	_crates = _crates.filter(func(c): return is_instance_valid(c))
	var data := pick_weapon()
	if data == null or _crates.size() >= max_crates:
		return null
	var points: Array = get_children().filter(func(n): return n is Marker2D)
	var point: Node2D = self if points.is_empty() else points[_rng.randi_range(0, points.size() - 1)]
	var crate: SupplyCrate = CRATE_SCENE.instantiate()
	crate.weapon = data
	get_parent().add_child(crate)
	crate.global_position = _drop_start(point.global_position)
	_crates.append(crate)
	crate_dropped.emit(crate)
	return crate


## Where a crate for `ground` starts: high above it, below any ceiling.
func _drop_start(ground: Vector2) -> Vector2:
	var top := ground + Vector2(0, -CRATE_DROP_HEIGHT)
	var query := PhysicsRayQueryParameters2D.create(ground + Vector2(0, -20), top, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		top.y = minf(hit.position.y + 18.0, ground.y - 20.0)
	return top


func _place(item: Node2D) -> bool:
	var points := _free_points()
	if _occupied.size() >= max_active or points.is_empty():
		item.free()
		return false
	var point: Node2D = points[_rng.randi_range(0, points.size() - 1)]
	get_parent().add_child(item)
	item.global_position = point.global_position
	_occupied[point] = item
	item.tree_exiting.connect(func(): _occupied.erase(point))
	return true


func _free_points() -> Array:
	var points: Array = []
	for child in get_children():
		if child is Marker2D and not _occupied.has(child):
			points.append(child)
	if points.is_empty() and not _occupied.has(self) and not _has_markers():
		points.append(self)
	return points


func _has_markers() -> bool:
	for child in get_children():
		if child is Marker2D:
			return true
	return false
