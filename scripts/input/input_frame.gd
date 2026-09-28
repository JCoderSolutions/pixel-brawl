class_name InputFrame
extends RefCounted
## One tick of a player's input as plain data: a quantized move axis plus a
## bitmask of held buttons. It carries no "just pressed" state; the player
## derives edges from consecutive frames, so a sequence of frames is enough to
## replay a match, drive a bot or sync a remote peer deterministically.

const JUMP := 1
const CROUCH := 2
const ATTACK := 4
const FIRE := 8
const PICKUP := 16

const AXIS_STEPS := 127

## Move axis in [-AXIS_STEPS, AXIS_STEPS]; ints keep peers bit-identical.
var axis := 0
var buttons := 0


static func create(move: float, held_buttons: int) -> InputFrame:
	var frame := InputFrame.new()
	frame.axis = roundi(clampf(move, -1.0, 1.0) * AXIS_STEPS)
	frame.buttons = held_buttons
	return frame


## Packs the frame into 16 bits: low byte axis (two's complement), high byte buttons.
static func decode(bits: int) -> InputFrame:
	var frame := InputFrame.new()
	var raw_axis := bits & 0xFF
	frame.axis = raw_axis - 0x100 if raw_axis >= 0x80 else raw_axis
	frame.buttons = (bits >> 8) & 0xFF
	return frame


func encode() -> int:
	return (axis & 0xFF) | ((buttons & 0xFF) << 8)


func move_x() -> float:
	return float(axis) / AXIS_STEPS


func is_held(button: int) -> bool:
	return buttons & button != 0


func equals(other: InputFrame) -> bool:
	return axis == other.axis and buttons == other.buttons
