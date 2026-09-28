extends Node

## Match flow: spawns players, runs rounds and decides winners.
## Registered as the `GameManager` autoload; the UI only listens to its
## signals, so HUD, winner screen and future netcode never poke at players.
##
## Round rules (Superfighters style): last player standing wins the round,
## first to `rounds_to_win` wins the match. With `lives_per_round > 1` a dead
## player respawns at its spawn point until its lives run out.

signal match_started
signal round_started(round_number: int)
signal fight_started
signal round_ended(winner_id: int)
signal match_ended(winner_id: int)
signal player_spawned(id: int, player: Node)
signal player_died(id: int, lives_left: int)
signal scores_changed(scores: Array)

enum State { IDLE, ROUND_STARTING, FIGHTING, ROUND_OVER, MATCH_OVER }

const NO_WINNER := -1
const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.545, 0.8),
	Color(0.894, 0.231, 0.267),
	Color(0.388, 0.78, 0.302),
	Color(0.996, 0.906, 0.38),
]

@export var player_scene: PackedScene = preload("res://scenes/characters/player.tscn")
@export var rounds_to_win := 3
@export var lives_per_round := 1
@export var round_start_delay := 1.5
## Time after the second-to-last death before the round is decided, so
## simultaneous knockouts end in a draw instead of a coin flip.
@export var round_end_grace := 0.5
@export var round_end_delay := 2.5
@export var respawn_delay := 1.5
## Players below this Y (fell off the map) die instantly.
@export var kill_zone_y := 400.0
## Players whose input is read locally; the rest are dummies until
## local 2P (TASK-008) or netcode assign them a controller.
@export var controlled_ids: Array[int] = [0]

var state := State.IDLE
var current_round := 0
var scores: Array[int] = []
var lives: Array[int] = []

var _arena: Node
var _spawn_points: Array[Vector2] = []
var _players := {}
var _respawn_timers := {}
var _state_timer := 0.0
var _grace_timer := -1.0


func _process(delta: float) -> void:
	advance(delta)


## Binds the manager to the scene that owns the players. One player is
## spawned per spawn point.
func setup(arena: Node, spawn_points: Array[Vector2]) -> void:
	teardown()
	_arena = arena
	_spawn_points = spawn_points
	if not arena.tree_exiting.is_connected(teardown):
		arena.tree_exiting.connect(teardown)


## Forgets the arena and its players (scene change, back to menu).
func teardown() -> void:
	if _arena != null and is_instance_valid(_arena) and _arena.tree_exiting.is_connected(teardown):
		_arena.tree_exiting.disconnect(teardown)
	_clear_players()
	_arena = null
	state = State.IDLE
	current_round = 0


func start_match() -> void:
	assert(_arena != null, "call setup() before start_match()")
	scores.clear()
	scores.resize(_spawn_points.size())
	scores.fill(0)
	current_round = 0
	match_started.emit()
	scores_changed.emit(scores)
	_start_round()


func get_player(id: int) -> Node:
	var p = _players.get(id)
	return p if is_instance_valid(p) else null


func get_player_ids() -> Array:
	var ids := _players.keys()
	ids.sort()
	return ids


func player_count() -> int:
	return _spawn_points.size()


## Frame step, public so tests can drive the match deterministically.
func advance(delta: float) -> void:
	match state:
		State.ROUND_STARTING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.FIGHTING
				fight_started.emit()
		State.FIGHTING:
			_check_kill_zone()
			_tick_respawns(delta)
			if _grace_timer >= 0.0:
				_grace_timer -= delta
				if _grace_timer < 0.0:
					_end_round()
		State.ROUND_OVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_start_round()


func _start_round() -> void:
	_clear_players()
	current_round += 1
	lives.resize(_spawn_points.size())
	lives.fill(lives_per_round)
	_grace_timer = -1.0
	for id in _spawn_points.size():
		_spawn(id)
	state = State.ROUND_STARTING
	_state_timer = round_start_delay
	round_started.emit(current_round)


## Players are re-instanced instead of revived: a fresh scene resets every
## piece of state (health, hitstun, colors) without the manager knowing it.
func _spawn(id: int) -> void:
	var old = _players.get(id)
	if is_instance_valid(old):
		old.queue_free()
	var player := player_scene.instantiate()
	player.name = "P%d" % (id + 1)
	player.position = _spawn_points[id]
	player.is_controlled = id in controlled_ids
	player.get_node("Visual").color = PLAYER_COLORS[id % PLAYER_COLORS.size()]
	_arena.add_child(player)
	player.health.died.connect(_on_player_died.bind(id), CONNECT_ONE_SHOT)
	_players[id] = player
	player_spawned.emit(id, player)


func _on_player_died(_source: Node, id: int) -> void:
	if state != State.FIGHTING:
		return
	lives[id] = max(lives[id] - 1, 0)
	player_died.emit(id, lives[id])
	if lives[id] > 0:
		_respawn_timers[id] = respawn_delay
	elif _grace_timer < 0.0 and _players_in_play() <= 1:
		_grace_timer = round_end_grace


func _tick_respawns(delta: float) -> void:
	for id in _respawn_timers.keys():
		_respawn_timers[id] -= delta
		if _respawn_timers[id] <= 0.0:
			_respawn_timers.erase(id)
			_spawn(id)


func _check_kill_zone() -> void:
	for id in _players:
		var p = _players[id]
		if is_instance_valid(p) and not p.health.is_dead() and p.global_position.y > kill_zone_y:
			p.health.take_damage(p.health.current_health)


## Players still alive or waiting to respawn.
func _players_in_play() -> int:
	var count := 0
	for id in lives.size():
		if lives[id] > 0:
			count += 1
	return count


func _end_round() -> void:
	_respawn_timers.clear()
	var winner := NO_WINNER
	for id in lives.size():
		if lives[id] > 0:
			winner = id
	if _players_in_play() > 1:
		winner = NO_WINNER
	if winner != NO_WINNER:
		scores[winner] += 1
		scores_changed.emit(scores)
	round_ended.emit(winner)
	if winner != NO_WINNER and scores[winner] >= rounds_to_win:
		state = State.MATCH_OVER
		match_ended.emit(winner)
	else:
		state = State.ROUND_OVER
		_state_timer = round_end_delay


func _clear_players() -> void:
	for p in _players.values():
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_respawn_timers.clear()
