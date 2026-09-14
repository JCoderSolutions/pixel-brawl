extends SceneTree

func _init() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if main_scene_path.is_empty():
		push_error("FATAL: no main scene configured")
		quit(1)
		return
	var scene: PackedScene = load(main_scene_path)
	if scene == null:
		push_error("FATAL: %s could not be loaded" % main_scene_path)
		quit(1)
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	print("OK: %s loaded and instantiated" % main_scene_path)
	quit(0)