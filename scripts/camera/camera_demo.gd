extends Node2D

## Sandbox for the shared camera: a map twice the screen size, player 1 on the
## keyboard and three wandering bots. X blasts the tiles around player 1 and
## shakes the view, K kills a bot so the camera re-frames, R restarts.

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const SPAWNS := [Vector2(100, 518), Vector2(380, 518), Vector2(580, 518), Vector2(860, 518)]
const COLORS := [Color("e43b44"), Color("0099db"), Color("63c74d"), Color("feae34")]
const BOT_FRAMES := 3600

## Seed for the bots' wandering, so headless checks are repeatable.
@export var bot_seed := 1234
## When false every fighter is a bot (headless checks).
@export var human_player_one := true

@onready var _map: DestructibleMap = $DestructibleMap
@onready var _fighters: Node2D = $Fighters
@onready var _camera: SharedCamera = $SharedCamera


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bot_seed
	for i in SPAWNS.size():
		var fighter: CharacterBody2D = PLAYER_SCENE.instantiate()
		fighter.name = "Player%d" % (i + 1)
		fighter.player_slot = i + 1
		fighter.position = SPAWNS[i]
		fighter.get_node("Visual").color = COLORS[i]
		if i > 0 or not human_player_one:
			fighter.input_source = ScriptedInputSource.new(_wander(rng))
		_fighters.add_child(fighter)
		_camera.add_target(fighter)
	_camera.make_current()
	_camera.snap()


func fighters() -> Array[Node]:
	return _fighters.get_children()


func camera() -> SharedCamera:
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_X:
			var blast: Vector2 = fighters()[0].global_position + Vector2(0, 8)
			_map.damage_area(blast, 40.0, 100, self)
			SharedCamera.shake(self, 0.8)
		KEY_K:
			for fighter in fighters().slice(1):
				if not fighter.health.is_dead():
					fighter.health.take_damage(999)
					break
		KEY_R:
			get_tree().reload_current_scene()


## Runs one way for a while, hops sometimes and swings now and then.
func _wander(rng: RandomNumberGenerator) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	var direction := 0.0
	var hold := 0
	for i in BOT_FRAMES:
		if hold <= 0:
			direction = [-1.0, 0.0, 1.0][rng.randi_range(0, 2)]
			hold = rng.randi_range(30, 150)
		hold -= 1
		var buttons := 0
		if rng.randf() < 0.02:
			buttons |= InputFrame.JUMP
		if rng.randf() < 0.01:
			buttons |= InputFrame.ATTACK
		frames.append(InputFrame.create(direction, buttons))
	return frames
