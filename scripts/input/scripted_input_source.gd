class_name ScriptedInputSource
extends InputSource
## Plays back a fixed list of frames, then stays neutral. Used by tests and
## replays; bots can feed it or extend InputSource directly.

var _frames: Array[InputFrame]
var _index := 0


func _init(frames: Array[InputFrame]) -> void:
	_frames = frames


func sample() -> InputFrame:
	if _index >= _frames.size():
		return InputFrame.new()
	_index += 1
	return _frames[_index - 1]
