extends SceneTree

var _player
var _ok := true

func _init() -> void:
	process_frame.connect(_run_test, CONNECT_ONE_SHOT)

func _run_test() -> void:
	var scene: PackedScene = load("res://scenes/characters/player.tscn")
	if scene == null:
		push_error("FATAL: player.tscn could not be loaded")
		quit(1)
		return
	_player = scene.instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(0, 0)
	_player.velocity = Vector2(50, 0)

	if _player.velocity.x != 50.0:
		push_error("FAIL: initial velocity")
		_ok = false
	if _player.get_node("CollisionShape2D").shape.size.y < 1.0:
		push_error("FAIL: collision shape")
		_ok = false

	Input.action_press("p1_move_right")
	for i in range(30):
		_player._physics_process(1.0 / 60.0)
	Input.action_release("p1_move_right")

	if _player.velocity.x <= 0.0:
		push_error("FAIL: player did not accelerate right")
		_ok = false
	if _player.velocity.y <= 0.0:
		push_error("FAIL: gravity did not pull player down")
		_ok = false

	if _player._visual.scale.x < 0.0:
		push_error("FAIL: expected facing right after moving right")
		_ok = false

	Input.action_press("p1_move_left")
	for i in range(30):
		_player._physics_process(1.0 / 60.0)
	Input.action_release("p1_move_left")

	if _player._visual.scale.x > 0.0:
		push_error("FAIL: expected flip to face left after moving left")
		_ok = false

	print("OK: movement acceleration, gravity, and horizontal flip verified")
	quit(0 if _ok else 1)