class_name TouchStick
extends Control
## On-screen stick for touch screens. The first finger that lands inside the
## control becomes its owner and sets the stick's centre (floating stick), so
## the thumb never has to find a fixed spot. The offset is turned into the
## slot's move/crouch actions, which DeviceInputSource already reads: touch
## feeds the same InputFrame path as keyboards and gamepads.

## Action prefix, e.g. "p1_". Set by TouchControls.
@export var prefix := "p1_"
## Knob travel in pixels; the axis reaches 1.0 at this distance.
@export var radius := 32.0
## Fraction of `radius` ignored around the centre.
@export_range(0.0, 0.9) var deadzone := 0.2
## Pulling down past this fraction of the radius holds crouch.
@export_range(0.1, 1.0) var crouch_threshold := 0.6

var axis := Vector2.ZERO
var _finger := -1
var _center := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	release()


## Maps a finger offset from the centre to a stick axis in [-1, 1] per
## component, with a radial deadzone rescaled so movement starts at 0.
static func axis_for(offset: Vector2, stick_radius: float, dead: float) -> Vector2:
	if stick_radius <= 0.0:
		return Vector2.ZERO
	var clamped := offset.limit_length(stick_radius) / stick_radius
	var length := clamped.length()
	if length <= dead:
		return Vector2.ZERO
	return clamped / length * ((length - dead) / (1.0 - dead))


func is_active() -> bool:
	return _finger != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			_center = event.position
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		_update(event.position)
		get_viewport().set_input_as_handled()


## Drops the finger and releases every action this stick holds.
func release() -> void:
	_finger = -1
	axis = Vector2.ZERO
	_apply()
	queue_redraw()


func _update(finger_position: Vector2) -> void:
	axis = axis_for(finger_position - _center, radius, deadzone)
	_apply()
	queue_redraw()


func _apply() -> void:
	_set_action("move_left", maxf(-axis.x, 0.0))
	_set_action("move_right", maxf(axis.x, 0.0))
	_set_action("crouch", 1.0 if axis.y >= crouch_threshold else 0.0)


func _set_action(action: String, strength: float) -> void:
	var full := prefix + action
	if not InputMap.has_action(full):
		return
	if strength > 0.0:
		Input.action_press(full, strength)
	elif Input.is_action_pressed(full):
		Input.action_release(full)


func _draw() -> void:
	var rest := size * 0.5
	var base := (_center - global_position) if is_active() else rest
	draw_circle(base, radius, Color(1, 1, 1, 0.12))
	draw_arc(base, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.45), 1.5)
	draw_circle(base + axis * radius, radius * 0.45, Color(1, 1, 1, 0.5 if is_active() else 0.3))
