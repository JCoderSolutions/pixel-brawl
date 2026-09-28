extends SceneTree

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_axis_math()
	_test_layout_fits_every_orientation()
	_test_visibility_rules()
	await _test_controls_press_slot_actions()
	await _test_multitouch_and_release()
	await _test_player_moves_with_touch()
	await _test_first_touch_reveals_controls()
	print("OK: touch stick math, layout in landscape/portrait, visibility, per-slot actions, multi-touch and player movement verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)  # already in viewport coordinates


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	root.push_input(event, true)  # already in viewport coordinates


func _spawn_controls(mode: TouchControls.Visibility, slot := 1) -> TouchControls:
	var controls: TouchControls = load("res://scenes/ui/touch/touch_controls.tscn").instantiate()
	controls.visibility = mode
	controls.slot = slot
	root.add_child(controls)
	return controls


func _test_axis_math() -> void:
	_check(VirtualJoystick.axis_for(Vector2(3, 0), 32, 0.2) == Vector2.ZERO, "inside deadzone is neutral")
	_check(VirtualJoystick.axis_for(Vector2(100, 0), 32, 0.2).is_equal_approx(Vector2(1, 0)), "past radius clamps to 1")
	var half := VirtualJoystick.axis_for(Vector2(-19.2, 0), 32, 0.2)
	_check(is_equal_approx(half.x, -0.5), "deadzone is rescaled so 60%% travel reads 0.5 (got %s)" % half.x)
	_check(VirtualJoystick.axis_for(Vector2(0, 40), 0, 0.2) == Vector2.ZERO, "zero radius is safe")


func _test_layout_fits_every_orientation() -> void:
	for screen in [Vector2(480, 270), Vector2(270, 480), Vector2(1920, 1080), Vector2(1080, 2340), Vector2(2340, 1080), Vector2(768, 1024), Vector2(360, 360)]:
		var layout := TouchControls.compute_layout(screen)
		var screen_rect := Rect2(Vector2.ZERO, screen)
		var names: Array = TouchControls.BUTTONS.keys()
		for i in names.size():
			var rect: Rect2 = layout[names[i]]
			_check(screen_rect.encloses(rect), "%s inside %s" % [names[i], screen])
			_check(not rect.intersects(layout.Stick), "%s clear of the stick zone at %s" % [names[i], screen])
			_check(rect.size.x >= 30.0 * layout.unit, "%s big enough for a thumb at %s" % [names[i], screen])
			for j in range(i + 1, names.size()):
				var other: Rect2 = layout[names[j]]
				var gap := rect.get_center().distance_to(other.get_center()) - (rect.size.x + other.size.x) * 0.5
				_check(gap > 0.0, "%s and %s do not overlap at %s" % [names[i], names[j], screen])
		_check(screen_rect.encloses(layout.Stick), "stick zone inside %s" % screen)
	var small := TouchControls.compute_layout(Vector2(480, 270))
	var big := TouchControls.compute_layout(Vector2(1920, 1080))
	_check(is_equal_approx(big.Attack.size.x, small.Attack.size.x * 4.0), "buttons scale with resolution")
	var portrait := TouchControls.compute_layout(Vector2(270, 480))
	_check(is_equal_approx(portrait.Attack.size.x, small.Attack.size.x), "portrait uses the short side for size")


func _test_visibility_rules() -> void:
	_check(TouchControls.should_show(TouchControls.Visibility.AUTO, true), "auto shows on touch screens")
	_check(not TouchControls.should_show(TouchControls.Visibility.AUTO, false), "auto hides without touch")
	_check(TouchControls.should_show(TouchControls.Visibility.ALWAYS, false), "always shows")
	_check(not TouchControls.should_show(TouchControls.Visibility.NEVER, true), "never hides")


func _test_controls_press_slot_actions() -> void:
	var controls := _spawn_controls(TouchControls.Visibility.ALWAYS, 2)
	await _frames(1)
	_check(InputMap.has_action("p2_fire") and InputMap.has_action("p2_pickup"), "fire/pickup created for the slot")
	for name in controls.buttons:
		var button: TouchActionButton = controls.buttons[name]
		var action: String = button.action
		_touch(3, button.get_global_rect().get_center(), true)
		await _frames(1)
		_check(Input.is_action_pressed(action), "%s pressed by touch" % action)
		var slot1: String = "p1_" + name.to_lower()
		_check(not InputMap.has_action(slot1) or not Input.is_action_pressed(slot1), "slot 1 untouched by %s" % action)
		_touch(3, button.get_global_rect().get_center(), false)
		await _frames(1)
		_check(not Input.is_action_pressed(action), "%s released on lift" % action)
	var zone := controls.joystick.get_global_rect()
	var start := zone.get_center()
	# Offsets in stick radii: the radius scales with the visible screen size.
	var r := controls.joystick.radius
	_touch(0, start, true)
	_drag(0, start + Vector2(-1.25, 0) * r)
	await _frames(1)
	_check(Input.is_action_pressed("p2_move_left"), "stick left presses move_left")
	_check(is_equal_approx(Input.get_action_strength("p2_move_left"), 1.0), "full push is full strength")
	_check(not Input.is_action_pressed("p2_move_right"), "move_right stays up")
	_drag(0, start + Vector2(0.25, 0.8) * r)
	await _frames(1)
	_check(Input.is_action_pressed("p2_crouch"), "stick down crouches")
	_check(Input.is_action_pressed("p2_move_right") and not Input.is_action_pressed("p2_move_left"), "stick flips direction")
	var frame := DeviceInputSource.new(2).sample()
	_check(frame.move_x() > 0.0 and frame.is_held(InputFrame.CROUCH), "DeviceInputSource reads touch")
	_touch(0, start, false)
	await _frames(1)
	_check(not Input.is_action_pressed("p2_move_right") and not Input.is_action_pressed("p2_crouch"), "lifting the stick releases all")
	controls.queue_free()
	await _frames(1)


func _test_multitouch_and_release() -> void:
	var controls := _spawn_controls(TouchControls.Visibility.ALWAYS)
	await _frames(1)
	var stick := controls.joystick.get_global_rect().get_center()
	var jump: Vector2 = controls.buttons.Jump.get_global_rect().get_center()
	var attack: Vector2 = controls.buttons.Attack.get_global_rect().get_center()
	_touch(0, stick, true)
	_drag(0, stick + Vector2(controls.joystick.radius * 1.25, 0))
	_touch(1, jump, true)
	_touch(2, attack, true)
	await _frames(1)
	_check(Input.is_action_pressed("p1_move_right") and Input.is_action_pressed("p1_jump") and Input.is_action_pressed("p1_attack"), "three fingers at once")
	_touch(1, jump, false)
	await _frames(1)
	_check(not Input.is_action_pressed("p1_jump") and Input.is_action_pressed("p1_attack"), "lifting one finger keeps the others")
	_check(Input.is_action_pressed("p1_move_right"), "stick survives other fingers")
	controls.set_shown(false)
	_check(not Input.is_action_pressed("p1_move_right") and not Input.is_action_pressed("p1_attack"), "hiding releases every held action")
	_touch(0, stick, false)
	_touch(2, attack, false)
	_touch(4, attack, true)
	await _frames(1)
	_check(not Input.is_action_pressed("p1_attack"), "hidden controls ignore touches")
	_touch(4, attack, false)
	controls.set_shown(true)
	_touch(5, attack, true)
	await _frames(1)
	controls.queue_free()
	await _frames(1)
	_check(not Input.is_action_pressed("p1_attack"), "freeing the controls releases held actions")


func _test_player_moves_with_touch() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(4000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 25)
	arena.add_child(floor_body)
	var player: CharacterBody2D = load("res://scenes/characters/player.tscn").instantiate()
	arena.add_child(player)
	var controls := _spawn_controls(TouchControls.Visibility.ALWAYS)
	await _frames(20)
	var start_x := player.position.x
	var stick := controls.joystick.get_global_rect().get_center()
	_touch(0, stick, true)
	_drag(0, stick + Vector2(controls.joystick.radius * 1.25, 0))
	await _frames(20)
	_check(player.position.x > start_x + 10.0, "player walks right with the stick (%s -> %s)" % [start_x, player.position.x])
	var jump: Vector2 = controls.buttons.Jump.get_global_rect().get_center()
	_touch(1, jump, true)
	await _frames(4)
	_check(player.velocity.y < 0.0, "jump button makes the player jump")
	_touch(1, jump, false)
	_touch(0, stick, false)
	controls.queue_free()
	arena.queue_free()
	await _frames(1)


func _test_first_touch_reveals_controls() -> void:
	var controls := _spawn_controls(TouchControls.Visibility.AUTO)
	await _frames(1)
	_check(not controls.visible, "auto stays hidden without a touch screen")
	var attack: Vector2 = controls.buttons.Attack.get_global_rect().get_center()
	_touch(0, attack, true)
	await _frames(2)
	_check(controls.visible, "first touch shows the controls")
	_check(Input.is_action_pressed("p1_attack"), "the revealing touch also counts")
	_touch(0, attack, false)
	await _frames(1)
	_check(not Input.is_action_pressed("p1_attack"), "and releases normally")
	controls.queue_free()
	await _frames(1)
