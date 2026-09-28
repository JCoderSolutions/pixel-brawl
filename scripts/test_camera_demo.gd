extends SceneTree

## Integration check with real players: four wandering fighters on a map
## twice the screen size stay on screen and the view never leaves the map.

const VIEW := Vector2(480, 270)

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var demo: Node2D = load("res://scenes/camera/camera_demo.tscn").instantiate()
	demo.human_player_one = false
	root.add_child(demo)
	var camera: SharedCamera = demo.camera()
	await physics_frame

	var outside := 0
	var leaks := 0
	for i in 600:
		if i == 300:
			SharedCamera.shake(demo, 1.0)
		if i == 400:
			for fighter in demo.fighters().slice(1, 3):
				fighter.health.take_damage(999)
		await physics_frame
		var view := Rect2(camera.global_position - VIEW / camera.zoom / 2.0, VIEW / camera.zoom)
		if not camera.bounds.grow(0.01).encloses(view):
			leaks += 1
		for fighter in demo.fighters():
			if fighter.health.is_dead():
				continue
			# Allow the smoothing lag: a fighter may run a few px ahead.
			if not view.grow(8.0).has_point(fighter.global_position):
				outside += 1
	_check(leaks == 0, "view stayed inside the map (%d leaking frames)" % leaks)
	_check(outside == 0, "living fighters stayed on screen (%d misses)" % outside)
	_check(camera.zoom.x >= camera.min_zoom - 0.001 and camera.zoom.x <= camera.max_zoom + 0.001,
		"zoom stayed in range (%s)" % camera.zoom)
	print("OK: camera demo keeps four real fighters framed" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false
