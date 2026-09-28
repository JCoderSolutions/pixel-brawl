class_name DestructibleMap
extends Node2D

## Builds a grid of DestructibleBlock tiles from a text layout and routes area
## damage (explosions, TASK-006) to the tiles it overlaps.
##
## Layout legend (see LEGEND), anything else is empty:
##   `#` wood (crates, doors): bullets, melee and explosions break it
##   `=` wooden plank: one-way platform, breaks like wood
##   `B` brick: only explosions break it
##   `X` metal: indestructible
## Row 0 is the top; cell (0, 0) starts at this node's origin.

const TILE_SIZE := 16
const BLOCK_SCENE := preload("res://scenes/maps/destructible_block.tscn")
const WOOD := preload("res://scenes/maps/materials/wood.tres")
const BRICK := preload("res://scenes/maps/materials/brick.tres")
const METAL := preload("res://scenes/maps/materials/metal.tres")
## Layout character -> [material, one-way].
const LEGEND := {
	"#": [WOOD, false],
	"=": [WOOD, true],
	"B": [BRICK, false],
	"X": [METAL, false],
}

@export var layout := PackedStringArray()

var _blocks := {}


func _ready() -> void:
	for row in layout.size():
		var line: String = layout[row]
		for column in line.length():
			var tile: Array = LEGEND.get(line[column], [])
			if not tile.is_empty():
				_spawn_block(Vector2i(column, row), tile[0], tile[1])


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


## Blasts every block whose tile overlaps the circle (global coordinates);
## each material decides whether explosions break it.
func damage_area(global_center: Vector2, radius: float, amount: int, source: Node = null) -> void:
	var center := to_local(global_center)
	var half := Vector2(TILE_SIZE, TILE_SIZE) / 2.0
	# Snapshot: destroyed blocks leave the dictionary while we iterate.
	for block: DestructibleBlock in _blocks.values():
		var closest := center.clamp(block.position - half, block.position + half)
		if closest.distance_to(center) <= radius:
			block.take_blast(amount, source)


func _spawn_block(cell: Vector2i, block_material: BlockMaterial, one_way: bool) -> void:
	var block: DestructibleBlock = BLOCK_SCENE.instantiate()
	block.block_material = block_material
	block.one_way = one_way
	block.position = cell_to_world(cell)
	block.destroyed.connect(func(_b): _blocks.erase(cell))
	_blocks[cell] = block
	add_child(block)
