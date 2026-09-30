class_name DeviceInputSource
extends InputSource
## Reads the `p<slot>_*` actions from the InputMap. Keyboard halves, gamepads
## and on-screen touch buttons all feed a slot by binding to its actions.

const MAX_SLOTS := 4
const ACTIONS := ["move_left", "move_right", "jump", "crouch", "attack", "fire", "pickup", "switch", "power"]

var slot: int
var _prefix: String


func _init(player_slot: int) -> void:
	slot = player_slot
	_prefix = "p%d_" % player_slot


func sample() -> InputFrame:
	var held := 0
	if Input.is_action_pressed(_prefix + "jump"):
		held |= InputFrame.JUMP
	if Input.is_action_pressed(_prefix + "crouch"):
		held |= InputFrame.CROUCH
	if Input.is_action_pressed(_prefix + "attack"):
		held |= InputFrame.ATTACK
	if Input.is_action_pressed(_prefix + "fire"):
		held |= InputFrame.FIRE
	if Input.is_action_pressed(_prefix + "pickup"):
		held |= InputFrame.PICKUP
	if InputMap.has_action(_prefix + "switch") and Input.is_action_pressed(_prefix + "switch"):
		held |= InputFrame.SWITCH
	if InputMap.has_action(_prefix + "power") and Input.is_action_pressed(_prefix + "power"):
		held |= InputFrame.POWER
	var move := Input.get_axis(_prefix + "move_left", _prefix + "move_right")
	return InputFrame.create(move, held)
