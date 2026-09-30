extends SceneTree

## Shared camera: frames every living fighter, zooms to fit them inside the
## map and shakes on hits/explosions without ever showing past the map edge.

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	# Headless opens a 64x64 window; with aspect "expand" that would give a
	# square view. Use the project's default 960x540 window (480x270 at 2x).
	root.size = Vector2i(960, 540)
	await process_frame
	await _test_centers_on_living_targets()
	await _test_ignores_dead_and_freed_targets()
	await _test_zooms_out_to_fit_everyone()
	await _test_zoom_is_capped_when_close()
	await _test_never_shows_past_bounds()
	await _test_smoothing_moves_towards_goal()
	await _test_shake_decays_and_stays_in_bounds()
	await _test_shake_is_as_strong_in_a_corner()
	await _test_static_shake_reaches_cameras()
	await _test_target_damage_adds_trauma()
	await _test_target_group_is_followed()
	await _test_pixel_perfect_zoom_steps()
	await _test_pan_eases_in_without_overshoot()
	await _test_zoom_out_is_quick_and_zoom_in_is_lazy()
	await _test_view_snaps_to_screen_pixels()
	await _test_pixel_perfect_respects_bounds()
	await _test_portrait_screen()
	await _test_portrait_screen_on_wide_map()
	await _test_coarse_steps_still_fit_everyone()
	print("OK: shared camera follows, zooms, clamps and shakes" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _make_camera(bounds := Rect2(0, 0, 960, 540)) -> SharedCamera:
	var camera := SharedCamera.new()
	camera.bounds = bounds
	camera.focus_offset = Vector2.ZERO
	camera.margin = Vector2(32, 32)
	camera.min_zoom = 0.5
	camera.max_zoom = 1.5
	# Continuous zoom keeps these checks exact; pixel-perfect steps have their own tests.
	camera.pixel_perfect_zoom = false
	camera.letterbox_bounds = false
	root.add_child(camera)
	return camera


func _make_target(at: Vector2, with_health := true) -> Node2D:
	var target := Node2D.new()
	target.position = at
	if with_health:
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.max_health = 100
		target.add_child(health)
	root.add_child(target)
	return target


func _visible_rect(camera: SharedCamera) -> Rect2:
	var size := camera.get_viewport_rect().size / camera.zoom
	return Rect2(camera.global_position - size / 2.0, size)


func _cleanup(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	await process_frame


func _test_centers_on_living_targets() -> void:
	var camera := _make_camera()
	var a := _make_target(Vector2(400, 300))
	var b := _make_target(Vector2(500, 260))
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	_check(camera.global_position.is_equal_approx(Vector2(450, 280)),
		"camera centres between two fighters (got %s)" % camera.global_position)
	await _cleanup([camera, a, b])


func _test_ignores_dead_and_freed_targets() -> void:
	var camera := _make_camera()
	var alive := _make_target(Vector2(300, 300))
	var dead := _make_target(Vector2(700, 300))
	var gone := _make_target(Vector2(700, 100))
	for t in [alive, dead, gone]:
		camera.add_target(t)
	dead.get_node("HealthComponent").take_damage(999)
	gone.free()
	camera.snap()
	_check(camera.global_position.is_equal_approx(Vector2(300, 300)),
		"dead and freed fighters are ignored (got %s)" % camera.global_position)
	_check(camera.get_targets().size() == 2, "freed targets are dropped from the list")
	# With nobody alive the camera holds still instead of jumping to 0,0.
	alive.get_node("HealthComponent").take_damage(999)
	camera.snap()
	_check(camera.global_position.is_equal_approx(Vector2(300, 300)),
		"camera holds position when nobody is alive")
	await _cleanup([camera, alive, dead])


func _test_zooms_out_to_fit_everyone() -> void:
	var camera := _make_camera()
	var a := _make_target(Vector2(100, 300))
	var b := _make_target(Vector2(800, 300))
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	_check(camera.zoom.x < 1.0 and is_equal_approx(camera.zoom.x, camera.zoom.y),
		"far apart fighters make the camera zoom out uniformly (zoom %s)" % camera.zoom)
	var view := _visible_rect(camera)
	_check(view.grow(0.01).has_point(a.global_position) and view.grow(0.01).has_point(b.global_position),
		"both fighters fit in the view")
	await _cleanup([camera, a, b])


func _test_zoom_is_capped_when_close() -> void:
	var camera := _make_camera()
	var a := _make_target(Vector2(480, 270))
	camera.add_target(a)
	camera.snap()
	_check(is_equal_approx(camera.zoom.x, camera.max_zoom),
		"a lone fighter zooms in only up to max_zoom (zoom %s)" % camera.zoom)
	# min_zoom wins over fitting: four corners of a huge map can't all fit.
	var far := _make_target(Vector2(-4000, 270))
	camera.add_target(far)
	camera.bounds = Rect2(-5000, -5000, 10000, 10000)
	camera.snap()
	_check(is_equal_approx(camera.zoom.x, camera.min_zoom),
		"zoom never goes below min_zoom (zoom %s)" % camera.zoom)
	await _cleanup([camera, a, far])


func _test_never_shows_past_bounds() -> void:
	var bounds := Rect2(0, 0, 960, 540)
	var camera := _make_camera(bounds)
	var corner := _make_target(Vector2(5, 530))
	camera.add_target(corner)
	camera.snap()
	_check(bounds.grow(0.01).encloses(_visible_rect(camera)),
		"view stays inside the map near a corner (%s)" % _visible_rect(camera))
	# Fighters spread wider than the map: the map limit beats min_zoom.
	var small := Rect2(0, 0, 480, 270)
	camera.bounds = small
	camera.min_zoom = 0.25
	var other := _make_target(Vector2(470, 5))
	camera.add_target(other)
	camera.snap()
	_check(camera.zoom.x >= 1.0 - 0.001, "never zooms out past the map size (zoom %s)" % camera.zoom)
	_check(small.grow(0.01).encloses(_visible_rect(camera)), "small map is not overshot")
	await _cleanup([camera, corner, other])


func _test_smoothing_moves_towards_goal() -> void:
	var camera := _make_camera()
	var a := _make_target(Vector2(300, 300))
	camera.add_target(a)
	camera.snap()
	a.position = Vector2(600, 300)
	camera.advance(1.0 / 60.0)
	var x := camera.global_position.x
	_check(x > 300.0 and x < 600.0, "one step moves part of the way (x = %.1f)" % x)
	for i in 240:
		camera.advance(1.0 / 60.0)
	_check(absf(camera.global_position.x - 600.0) < 1.0, "camera settles on the fighter")
	await _cleanup([camera, a])


func _test_shake_decays_and_stays_in_bounds() -> void:
	var bounds := Rect2(0, 0, 960, 540)
	var camera := _make_camera(bounds)
	var a := _make_target(Vector2(10, 530))
	camera.add_target(a)
	camera.snap()
	camera.add_trauma(5.0)
	_check(is_equal_approx(camera.trauma, 1.0), "trauma is clamped to 1")
	var moved := false
	var rest := camera.global_position
	var inside := true
	for i in 30:
		camera.advance(1.0 / 60.0)
		moved = moved or not camera.global_position.is_equal_approx(rest)
		inside = inside and bounds.grow(0.01).encloses(_visible_rect(camera))
	_check(inside, "shake never shows past the map edge")
	moved = false
	# In the middle of the map the shake is free to move the view.
	a.position = Vector2(480, 270)
	camera.snap()
	rest = camera.global_position
	camera.add_trauma(1.0)
	var biggest := 0.0
	for i in 10:
		camera.advance(1.0 / 60.0)
		moved = moved or not camera.global_position.is_equal_approx(rest)
		biggest = maxf(biggest, (camera.global_position - rest).abs().x)
	_check(moved, "trauma shakes the view")
	_check(biggest >= camera.max_shake_offset.x * 0.4,
		"full trauma kicks close to max_shake_offset (peak %.1f px)" % biggest)
	for i in 240:
		camera.advance(1.0 / 60.0)
	_check(camera.trauma == 0.0, "trauma decays to zero")
	_check(camera.global_position.is_equal_approx(rest), "camera returns to rest after shaking")
	await _cleanup([camera, a])


func _test_shake_is_as_strong_in_a_corner() -> void:
	# Same shake on a camera pinned in a corner and on a free one: the pinned
	# one bounces the kick inward instead of losing it to the clamp.
	var pinned := _make_camera(Rect2(0, 0, 960, 540))
	var free := _make_camera(Rect2(-5000, -5000, 10000, 10000))
	var a := _make_target(Vector2(10, 530))
	for camera in [pinned, free]:
		camera.pixel_snap = false
		camera.add_target(a)
		camera.snap()
	var pinned_rest := pinned.global_position
	var free_rest := free.global_position
	pinned.add_trauma(1.0)
	free.add_trauma(1.0)
	var same := true
	for i in 20:
		pinned.advance(1.0 / 60.0)
		free.advance(1.0 / 60.0)
		var kick_pinned := (pinned.global_position - pinned_rest).abs()
		var kick_free := (free.global_position - free_rest).abs()
		same = same and (kick_pinned - kick_free).length() < 0.01
	_check(same, "a corner doesn't swallow the shake")
	await _cleanup([pinned, free, a])


func _test_static_shake_reaches_cameras() -> void:
	var camera := _make_camera()
	var explosion := Node2D.new()
	root.add_child(explosion)
	SharedCamera.shake(explosion, 0.6)
	_check(is_equal_approx(camera.trauma, 0.6), "SharedCamera.shake() reaches the active camera")
	await _cleanup([camera, explosion])


func _test_target_damage_adds_trauma() -> void:
	var camera := _make_camera()
	camera.trauma_per_damage = 0.02
	var a := _make_target(Vector2(300, 300))
	camera.add_target(a)
	a.get_node("HealthComponent").take_damage(10)
	_check(is_equal_approx(camera.trauma, 0.2), "a 10 damage hit adds 0.2 trauma (got %.2f)" % camera.trauma)
	camera.remove_target(a)
	camera.trauma = 0.0
	a.get_node("HealthComponent").take_damage(10)
	_check(camera.trauma == 0.0, "removed targets no longer shake the camera")
	await _cleanup([camera, a])


func _test_target_group_is_followed() -> void:
	var camera := _make_camera()
	camera.target_group = &"camera_test_fighters"
	var a := _make_target(Vector2(200, 300), false)
	var b := _make_target(Vector2(400, 300), false)
	a.add_to_group(&"camera_test_fighters")
	b.add_to_group(&"camera_test_fighters")
	camera.snap()
	_check(camera.global_position.is_equal_approx(Vector2(300, 300)),
		"fighters in target_group are followed without add_target (got %s)" % camera.global_position)
	await _cleanup([camera, a, b])


## A small screen scale (a portrait phone: ~1.1 screen px per world pixel)
## has no whole step between min_zoom and 1: the camera must still zoom out
## to fit both fighters instead of jumping up to the 1-pixel step.
func _test_coarse_steps_still_fit_everyone() -> void:
	for scale in [1.125, 2.08]:
		var camera := _make_camera()
		camera.pixel_perfect_zoom = true
		camera.screen_scale_override = scale
		var a := _make_target(Vector2(120, 300))
		var b := _make_target(Vector2(840, 300))
		camera.add_target(a)
		camera.add_target(b)
		camera.snap()
		var view := _visible_rect(camera)
		_check(view.grow(0.01).has_point(a.global_position) and view.grow(0.01).has_point(b.global_position),
				"at %.2fx screen scale both far-apart fighters stay in view (zoom %.2f)" % [scale, camera.zoom.x])
		await _cleanup([camera, a, b])


func _test_pixel_perfect_zoom_steps() -> void:
	# At 2x screen scale the camera rests on zooms where every world pixel
	# covers whole screen pixels, but glides between them instead of popping.
	var camera := _make_camera()
	camera.pixel_perfect_zoom = true
	camera.screen_scale_override = 2.0
	camera.max_zoom = 1.7
	var a := _make_target(Vector2(480, 300))
	var b := _make_target(Vector2(480, 300))
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	_check(is_equal_approx(camera.zoom.x, 1.5), "1.7 max zoom rests on 3 screen px per pixel (zoom %s)" % camera.zoom)
	var biggest_step := 0.0
	var glided := false
	var previous := camera.zoom.x
	for i in 180:
		a.position.x -= 2.0
		b.position.x += 2.0
		camera.advance(1.0 / 60.0)
		var pixels := camera.zoom.x * 2.0
		glided = glided or absf(pixels - roundf(pixels)) > 0.05
		biggest_step = maxf(biggest_step, absf(camera.zoom.x - previous))
		previous = camera.zoom.x
	for i in 240:
		camera.advance(1.0 / 60.0)
	var pixels := camera.zoom.x * 2.0
	var view := _visible_rect(camera)
	_check(glided, "zoom glides through in-between values while it changes")
	_check(biggest_step < 0.05, "no single frame pops the zoom (biggest step %.3f)" % biggest_step)
	_check(absf(pixels - roundf(pixels)) < 0.001, "zoom settles on whole screen pixels (zoom %s)" % camera.zoom)
	_check(view.grow(0.01).has_point(a.global_position) and view.grow(0.01).has_point(b.global_position),
		"settled zoom keeps both fighters in view")
	await _cleanup([camera, a, b])


func _test_pan_eases_in_without_overshoot() -> void:
	# A fighter teleporting (respawn, knockback) must not yank the view: the
	# camera accelerates from rest and lands without swinging past.
	var camera := _make_camera()
	var a := _make_target(Vector2(300, 300))
	camera.add_target(a)
	camera.snap()
	a.position = Vector2(600, 300)
	camera.advance(1.0 / 60.0)
	var first := camera.global_position.x - 300.0
	var furthest := 0.0
	var settle_frame := -1
	for i in 180:
		camera.advance(1.0 / 60.0)
		furthest = maxf(furthest, camera.global_position.x)
		if settle_frame < 0 and absf(camera.global_position.x - 600.0) < 1.0:
			settle_frame = i
	_check(first > 0.0 and first < 5.0, "first frame only starts moving (%.1f px)" % first)
	_check(furthest <= 600.5, "no overshoot past the fighter (max x %.1f)" % furthest)
	_check(settle_frame >= 0 and settle_frame < 90, "settles within 1.5 s (frame %d)" % settle_frame)
	await _cleanup([camera, a])


func _test_zoom_out_is_quick_and_zoom_in_is_lazy() -> void:
	# Like Superfighters: widen at once so nobody leaves the screen, but only
	# tighten once fighters have stayed close, so jumps and dodges don't pump.
	var camera := _make_camera()
	var a := _make_target(Vector2(200, 300))
	var b := _make_target(Vector2(760, 300))
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	var wide := camera.zoom.x
	a.position = Vector2(460, 300)
	b.position = Vector2(500, 300)
	for i in 18:
		camera.advance(1.0 / 60.0)
	_check(absf(camera.zoom.x - wide) < 0.01, "a brief clinch doesn't zoom in yet (zoom %.3f)" % camera.zoom.x)
	for i in 240:
		camera.advance(1.0 / 60.0)
	var tight := camera.zoom.x
	_check(tight > wide + 0.3, "fighters that stay close get a tighter view (zoom %.3f)" % tight)
	a.position = Vector2(200, 300)
	b.position = Vector2(760, 300)
	for i in 3:
		camera.advance(1.0 / 60.0)
	_check(camera.zoom.x < tight - 0.001, "spreading out starts widening right away")
	for i in 30:
		camera.advance(1.0 / 60.0)
	var view := _visible_rect(camera)
	_check(view.grow(8.0).has_point(a.global_position) and view.grow(8.0).has_point(b.global_position),
		"after half a second both fighters are back in view")
	await _cleanup([camera, a, b])


func _test_view_snaps_to_screen_pixels() -> void:
	# Rounding to whole *world* pixels at 3 screen px per pixel makes slow pans
	# stutter in 3 px hops; round to screen pixels instead.
	var camera := _make_camera()
	camera.screen_scale_override = 2.0
	camera.pixel_perfect_zoom = true
	var a := _make_target(Vector2(480, 300))
	camera.add_target(a)
	camera.snap()
	var on_grid := true
	var fine := false
	for i in 120:
		a.position.x += 0.4
		camera.advance(1.0 / 60.0)
		var pixels := camera.global_position.x * camera.zoom.x * 2.0
		on_grid = on_grid and absf(pixels - roundf(pixels)) < 0.01
		var world := camera.global_position.x
		fine = fine or absf(world - roundf(world)) > 0.1
	_check(on_grid, "view lands on whole screen pixels")
	_check(fine, "view moves in steps finer than a world pixel when zoomed in")
	await _cleanup([camera, a])


func _test_pixel_perfect_respects_bounds() -> void:
	# Odd screen scale (a 1170 px tall phone): no whole step fits between the
	# map's limit (0.8) and the fighters' fit, so the view rests on the exact
	# zoom that shows the whole map width, never past its edge.
	var bounds := Rect2(0, 0, 600, 400)
	var camera := _make_camera(bounds)
	camera.pixel_perfect_zoom = true
	camera.screen_scale_override = 1.125
	camera.min_zoom = 0.25
	var a := _make_target(Vector2(10, 390))
	var b := _make_target(Vector2(590, 10))
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	_check(is_equal_approx(camera.zoom.x, 0.8), "zoom rests on the map's own fit (%s)" % camera.zoom)
	_check(bounds.grow(0.01).encloses(_visible_rect(camera)), "the view never shows past the map")
	# Close together, the step above the map's limit fits them: pixel-perfect.
	a.position = Vector2(280, 200)
	b.position = Vector2(320, 200)
	camera.snap()
	var pixels := camera.zoom.x * 1.125
	_check(absf(pixels - roundf(pixels)) < 0.001, "close fighters rest on a whole screen-pixel step (%s)" % camera.zoom)
	_check(bounds.grow(0.01).encloses(_visible_rect(camera)), "still inside the map")
	await _cleanup([camera, a, b])


func _test_portrait_screen() -> void:
	# A phone held upright: the view is tall and narrow, so fighters spread
	# sideways force a stronger zoom out than on a landscape screen.
	var screen := SubViewport.new()
	screen.size = Vector2i(270, 480)
	root.add_child(screen)
	var bounds := Rect2(0, 0, 960, 960)
	var camera := SharedCamera.new()
	camera.bounds = bounds
	camera.focus_offset = Vector2.ZERO
	camera.margin = Vector2(32, 32)
	camera.min_zoom = 0.25
	camera.pixel_perfect_zoom = false
	screen.add_child(camera)
	var a := Node2D.new()
	var b := Node2D.new()
	a.position = Vector2(300, 600)
	b.position = Vector2(700, 600)
	screen.add_child(a)
	screen.add_child(b)
	camera.add_target(a)
	camera.add_target(b)
	camera.snap()
	var view := _visible_rect(camera)
	_check(view.size.x < view.size.y, "portrait screen gives a tall view (%s)" % view.size)
	_check(view.grow(0.01).has_point(a.position) and view.grow(0.01).has_point(b.position),
		"both fighters fit on a portrait screen (%s)" % view)
	_check(bounds.grow(0.01).encloses(view), "portrait view stays inside the map")
	_check(camera.zoom.x <= 270.0 / 464.0 + 0.001, "zoom fits the narrow width (zoom %s)" % camera.zoom)
	await _cleanup([screen])


func _test_portrait_screen_on_wide_map() -> void:
	# Upright phone on a 16:9 map: filling the tall view with map would mean
	# zooming in 2x and losing fighters, so letterbox the height instead.
	var screen := SubViewport.new()
	screen.size = Vector2i(480, 1040)
	root.add_child(screen)
	var bounds := Rect2(0, 0, 960, 544)
	var cameras := {}
	for letterbox in [true, false]:
		var camera := SharedCamera.new()
		camera.bounds = bounds
		camera.focus_offset = Vector2.ZERO
		camera.min_zoom = 0.25
		camera.pixel_perfect_zoom = false
		camera.letterbox_bounds = letterbox
		screen.add_child(camera)
		cameras[letterbox] = camera
	var a := Node2D.new()
	var b := Node2D.new()
	a.position = Vector2(60, 500)
	b.position = Vector2(900, 500)
	screen.add_child(a)
	screen.add_child(b)
	for camera in cameras.values():
		camera.add_target(a)
		camera.add_target(b)
		camera.snap()
	var view := _visible_rect(cameras[true])
	_check(view.grow(0.01).has_point(a.position) and view.grow(0.01).has_point(b.position),
		"letterboxed portrait view keeps both fighters (%s)" % view)
	_check(view.position.x >= -0.01 and view.end.x <= 960.01, "letterbox never shows past the map sideways")
	_check(is_equal_approx(view.get_center().y, bounds.get_center().y), "the tall axis is centred on the map")
	var strict := _visible_rect(cameras[false])
	_check(bounds.grow(0.01).encloses(strict), "letterbox off never shows past the map (%s)" % strict)
	await _cleanup([screen])
