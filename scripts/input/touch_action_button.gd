class_name TouchActionButton
extends Control
## Round on-screen button that holds one InputMap action while a finger is on
## it. Each button tracks its own finger index, so jumping while the other
## thumb steers (multi-touch) works. A finger that slides off keeps the button
## held until it lifts, like a physical pad.

@export var action := ""
@export var label := ""
@export var color := Color(1, 1, 1)

var _finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	release()


func is_held() -> bool:
	return _finger != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventScreenTouch:
		return
	if event.pressed and _finger == -1 and _hits(event.position):
		_finger = event.index
		if InputMap.has_action(action):
			Input.action_press(action)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif not event.pressed and event.index == _finger:
		release()
		get_viewport().set_input_as_handled()


func release() -> void:
	if _finger == -1:
		return
	_finger = -1
	if InputMap.has_action(action):
		Input.action_release(action)
	queue_redraw()


## Circular hit area inscribed in the control's rect.
func _hits(point: Vector2) -> bool:
	var rect := get_global_rect()
	return point.distance_to(rect.get_center()) <= minf(rect.size.x, rect.size.y) * 0.5


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	draw_circle(center, r, Color(color, 0.45 if is_held() else 0.2))
	draw_arc(center, r, 0.0, TAU, 32, Color(color, 0.7), 1.5)
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := maxi(8, roundi(r * 0.6))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))
