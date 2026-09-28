class_name WeaponSpawner
extends Node2D

## Drops random weapons on the map. Spawn points are the Marker2D children
## (or the spawner itself if it has none); a point is reused only once its
## weapon has been taken, and at most `max_active` items wait on the map.
## Each tick drops a power-up instead of a weapon with `power_up_chance`.

signal weapon_spawned(pickup: WeaponPickup)
signal power_up_spawned(pickup: PowerUpPickup)

const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")
const POWER_UP_SCENE := preload("res://scenes/powerups/power_up_pickup.tscn")

@export var weapons: Array[WeaponData] = []
@export var power_ups: Array[PowerUpData] = []
@export_range(0.0, 1.0) var power_up_chance := 0.3
@export var spawn_interval := 8.0
@export var max_active := 3
@export var autostart := true
## 0 randomizes every match; any other value replays the same sequence.
@export var rng_seed := 0

var _rng := RandomNumberGenerator.new()
var _occupied := {}
var _timer: Timer


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(spawn_random)
	add_child(_timer)
	if autostart:
		_timer.start()


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
