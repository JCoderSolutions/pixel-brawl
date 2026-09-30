extends Node

## Menu feel for the whole game (autoload, vault/docs/ui-style-guide.md §3.7):
## moving the focus ticks and hops the control 1 px, every button press
## confirms with a rising blip, and back()/closing plays a falling one.
## Buttons are picked up as they enter the tree, so no screen has to wire
## anything; a button with the "silent" meta stays quiet.

## Seconds the focused control stays 1 px up.
const HOP_TIME := 0.06

var _hop: Tween
var _hopped: Control
var _rest_y := 0.0


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)


## Plays the "back" sound (a menu going back a step, a panel closing).
func back() -> void:
	_play(&"ui_back")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent"):
		node.pressed.connect(_on_pressed.bind(node))


func _on_pressed(button: BaseButton) -> void:
	if not button.has_meta("silent"):
		_play(&"ui_confirm")


func _on_focus_changed(control: Control) -> void:
	if not control is BaseButton and not control is Range:
		return
	_play(&"ui_move")
	# After the containers have laid the screen out (a panel that just opened
	# sorts at the end of the frame).
	_hop_up.call_deferred(control)


## A 1 px hop that settles back after HOP_TIME.
func _hop_up(control: Control) -> void:
	_settle()
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	_hopped = control
	_rest_y = control.position.y
	control.position.y = _rest_y - 1.0
	_hop = control.create_tween()
	_hop.tween_interval(HOP_TIME)
	_hop.tween_callback(_settle)


## Puts the control that hopped back: its container lays it out again (in
## case it moved meanwhile), or it goes back to where it was.
func _settle() -> void:
	if _hop != null and _hop.is_valid():
		_hop.kill()
	if is_instance_valid(_hopped):
		if _hopped.get_parent() is Container:
			_hopped.get_parent().queue_sort()
		else:
			_hopped.position.y = _rest_y
	_hopped = null


func _play(sfx: StringName) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sfx)
