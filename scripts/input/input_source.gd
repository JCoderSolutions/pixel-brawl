class_name InputSource
extends RefCounted
## Where a player's input comes from: a local device, a script, a bot or a
## remote peer. The owner calls `sample()` exactly once per physics tick.


func sample() -> InputFrame:
	return InputFrame.new()
