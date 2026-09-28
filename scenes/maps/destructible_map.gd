class_name DestructibleMap
extends Node2D

## Builds a grid of DestructibleBlock tiles from a text layout and routes area
## damage (explosions, TASK-006) to the tiles it overlaps.
##
## Layout legend: `#` destructible block, `X` indestructible block, anything
## else is empty. Row 0 is the top; cell (0, 0) starts at this node's origin.

const TILE_SIZE := 16
const BLOCK_SCENE := preload("res://scenes/maps/destructible_block.tscn")

@export var layout := PackedStringArray()

var _blocks := {}


func _ready() -> void:
	for row in layout.size():
		var line: String = layout[row]
		for column in line.length():
			match line[column]:
				"#":
					_spawn_block(Vector2i(column, row), false)
				"X":
					_spawn_block(Vector2i(column, row), true)


func get_block(cell: Vector2i) -> DestructibleBlock:
	return _blocks.get(cell)


func block_count() -> int:
	return _blocks.size()


## Centre of `cell` in this node's local space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE


## Cell containing a global position.
func world_to_cell(global_point: Vector2) -> Vector2i:
	return Vector2i((to_local(global_point) / TILE_SIZE).floor())


## Damages every block whose tile overlaps the circle (global coordinates).
func damage_area(global_center: Vector2, radius: float, amount: int, source: Node = null) -> void:
	var center := to_local(global_center)
	var half := Vector2(TILE_SIZE, TILE_SIZE) / 2.0
	# Snapshot: destroyed blocks leave the dictionary while we iterate.
	for block: DestructibleBlock in _blocks.values():
		var closest := center.clamp(block.position - half, block.position + half)
		if closest.distance_to(center) <= radius:
			var hurtbox: Hurtbox = block.get_node("Hurtbox")
			hurtbox.receive_hit(amount, Vector2.ZERO, source)


func _spawn_block(cell: Vector2i, indestructible: bool) -> void:
	var block: DestructibleBlock = BLOCK_SCENE.instantiate()
	block.indestructible = indestructible
	block.position = cell_to_world(cell)
	block.destroyed.connect(func(_b): _blocks.erase(cell))
	_blocks[cell] = block
	add_child(block)
