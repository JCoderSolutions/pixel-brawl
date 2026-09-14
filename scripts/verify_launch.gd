extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	if scene == null:
		push_error("FATAL: main.tscn could not be loaded")
		quit(1)
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	print("OK: main scene loaded and instantiated")
	quit(0)