class_name WeaponSpawner
extends Node2D

## Drops random weapons on the map. Spawn points are the Marker2D children
## (or the spawner itself if it has none); a point is reused only once its
## weapon has been taken, and at most `max_active` weapons wait on the map.

signal weapon_spawned(pickup: WeaponPickup)

const PICKUP_SCENE := preload("res://scenes/items/weapon_pickup.tscn")

@export var weapons: Array[WeaponData] = []
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
	_timer.timeout.connect(spawn_one)
	add_child(_timer)
	if autostart:
		_timer.start()


func pick_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[_rng.randi_range(0, weapons.size() - 1)]


## Spawns one random weapon at a free point. Returns null when full.
func spawn_one() -> WeaponPickup:
	if _occupied.size() >= max_active:
		return null
	var points := _free_points()
	var data := pick_weapon()
	if points.is_empty() or data == null:
		return null
	var point: Node2D = points[_rng.randi_range(0, points.size() - 1)]
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.weapon = data
	get_parent().add_child(pickup)
	pickup.global_position = point.global_position
	_occupied[point] = pickup
	pickup.tree_exiting.connect(func(): _occupied.erase(point))
	weapon_spawned.emit(pickup)
	return pickup


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
