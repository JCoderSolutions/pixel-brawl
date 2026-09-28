extends Node2D

## Playable sandbox for the touch controls. On desktop the mouse emulates a
## finger, so the stick and buttons can be tried without a phone. The label
## shows what player 1 reads this tick through DeviceInputSource.

@export var hud: Label

var _source := DeviceInputSource.new(1)
## Godot 4.2 only reads "emulate touch from mouse" at startup and this scene
## must not edit project.godot, so the left mouse button is turned into a
## finger here. Skipped on touch screens, where the mouse is itself emulated.
var _mouse_as_finger := not DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if not _mouse_as_finger:
		return
	var finger: InputEvent
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		finger = InputEventScreenTouch.new()
		finger.pressed = event.pressed
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		finger = InputEventScreenDrag.new()
	else:
		return
	finger.position = event.position
	get_viewport().set_input_as_handled()
	get_viewport().push_input.call_deferred(finger, true)


func _physics_process(_delta: float) -> void:
	var frame := _source.sample()
	var held := PackedStringArray()
	for button in [["salto", InputFrame.JUMP], ["agachar", InputFrame.CROUCH], ["golpe", InputFrame.ATTACK]]:
		if frame.is_held(button[1]):
			held.append(button[0])
	for action in ["p1_fire", "p1_pickup"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			held.append(action.trim_prefix("p1_"))
	hud.text = "eje %+.2f  %s" % [frame.move_x(), " ".join(held)]
