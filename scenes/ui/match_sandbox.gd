extends Node2D

## Playable match for the round flow: hands the arena and its spawn markers
## to the GameManager and starts a match. P1 is controlled, P2 is a dummy
## until local 2P (TASK-008).


func _ready() -> void:
	var spawns: Array[Vector2] = []
	for marker in $Spawns.get_children():
		spawns.append(marker.position)
	GameManager.setup($Players, spawns)
	GameManager.start_match()
