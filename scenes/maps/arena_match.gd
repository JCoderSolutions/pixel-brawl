extends Node2D

## Runs a local 2P match in this arena: hands the spawn markers and the
## Players node to the GameManager, reads both players from their own slots,
## points the shared camera at them and clears the previous round's loose
## weapons and corpses.

## Tests turn this off to use the arena as a plain map.
@export var autostart := true
@export var controlled_ids: Array[int] = [0, 1]

@onready var _players: Node2D = $Players
@onready var _map: DestructibleMap = $DestructibleMap
@onready var _camera: SharedCamera = $SharedCamera


func _ready() -> void:
	if not autostart:
		return
	var spawns: Array[Vector2] = []
	for marker in $Spawns.get_children():
		spawns.append(marker.position)
	GameManager.controlled_ids = controlled_ids
	GameManager.round_started.connect(_on_round_started)
	GameManager.player_spawned.connect(_on_player_spawned)
	GameManager.setup(_players, spawns)
	GameManager.start_match()


## Top edge of the indestructible bridge (the layout row holding `X`).
func bridge_top() -> float:
	for row in _map.layout.size():
		if "X" in _map.layout[row]:
			return _map.global_position.y + row * DestructibleMap.TILE_SIZE
	return INF


## Freed players drop out of the camera by themselves; respawns join here.
func _on_player_spawned(_id: int, player: Node) -> void:
	_camera.add_target(player)


func _on_round_started(_round_number: int) -> void:
	for pickup in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		if is_ancestor_of(pickup):
			pickup.queue_free()
	for child in _players.get_children():
		if child is Ragdoll:
			child.queue_free()
	_camera.snap()
