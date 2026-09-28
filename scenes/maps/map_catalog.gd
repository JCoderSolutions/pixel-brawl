class_name MapCatalog
extends RefCounted

## Every playable map, in menu order. Each one is a scene run by
## arena_match.gd: a DestructibleMap layout, its hazards, four spawn points
## and a WeaponSpawner.

const MAPS: Array[Dictionary] = [
	{"name": "Arena", "path": "res://scenes/maps/test_arena.tscn"},
	{"name": "Fábrica", "path": "res://scenes/maps/factory.tscn"},
	{"name": "Obra en la azotea", "path": "res://scenes/maps/rooftop.tscn"},
	{"name": "Laboratorio", "path": "res://scenes/maps/lab.tscn"},
	{"name": "Fundición", "path": "res://scenes/maps/foundry.tscn"},
]


static func size() -> int:
	return MAPS.size()


static func display_name(index: int) -> String:
	return MAPS[index]["name"]


static func path(index: int) -> String:
	return MAPS[index]["path"]


static func random_path(rng: RandomNumberGenerator = null) -> String:
	var index := rng.randi_range(0, MAPS.size() - 1) if rng != null else randi_range(0, MAPS.size() - 1)
	return path(index)
