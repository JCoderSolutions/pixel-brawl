extends Node2D

## Runs a local 2P match in this arena: hands the spawn markers and the
## Players node to the GameManager, reads both players from their own slots,
## points the shared camera at them and clears the previous round's loose
## weapons and corpses. Props (barrels) blown up last round come back and
## crates still lying around are cleared.

## Tests turn this off to use the arena as a plain map.
@export var autostart := true
@export var controlled_ids: Array[int] = [0, 1]
## Fighters below this Y fell off the map and die (handed to the GameManager,
## so each map sets its own: big maps sit lower than the first arena).
@export var kill_zone_y := 400.0

@onready var _players: Node2D = $Players
@onready var _map: DestructibleMap = $DestructibleMap
@onready var _camera: SharedCamera = $SharedCamera

## [scene path, parent, position] of every prop the map starts with.
var _props: Array = []


func _ready() -> void:
	for prop in get_tree().get_nodes_in_group(BreakableProp.GROUP):
		if is_ancestor_of(prop) and prop.scene_file_path != "":
			_props.append([prop.scene_file_path, prop.get_parent(), prop.position])
	if not autostart:
		return
	add_child(PauseMenu.new())
	var spawns: Array[Vector2] = []
	for marker in $Spawns.get_children():
		spawns.append(marker.position)
	GameManager.controlled_ids = controlled_ids
	GameManager.kill_zone_y = kill_zone_y
	# Letterbox strips (upright phones) take the map's own background colour.
	RenderingServer.set_default_clear_color($Background.color)
	GameManager.round_started.connect(_on_round_started)
	GameManager.player_spawned.connect(_on_player_spawned)
	GameManager.setup(_players, spawns)
	GameManager.start_match()
	AudioManager.play_track(&"battle")


## Top edge of the metal-capped bridge (the first layout row holding `X`).
func bridge_top() -> float:
	return _row_top("X")


## Top edge of the side plank platforms (the layout row holding `=`).
func platform_top() -> float:
	return _row_top("=")


func _row_top(code: String) -> float:
	for row in _map.layout.size():
		if code in _map.layout[row]:
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
	reset_props()
	_camera.snap()


## Puts every prop back where the map had it (fresh health) and removes
## the ones dropped during the round (supply crates).
func reset_props() -> void:
	for prop in get_tree().get_nodes_in_group(BreakableProp.GROUP):
		if is_ancestor_of(prop):
			prop.remove_from_group(BreakableProp.GROUP)
			prop.queue_free()
	for entry in _props:
		var prop: Node2D = load(entry[0]).instantiate()
		prop.position = entry[2]
		entry[1].add_child(prop)
