class_name ControlSchemes
extends RefCounted

## Which keyboard half or gamepad drives each local player. The project's
## InputMap ships P1 on WASD + the first gamepad, P2 on the arrows + the
## second and P3/P4 on the third and fourth, so a player's pad depended on
## plug-in order. apply() rebinds the `p<slot>_*` actions to the schemes
## picked in the menu (DeviceInputSource and the touch buttons keep reading
## the same actions); reset() puts the shipped bindings back.

enum Scheme { KEYS_OR_PAD, WASD, ARROWS, PAD_1, PAD_2, PAD_3, PAD_4 }

const LABELS := ["WASD o mando", "WASD", "Flechas", "Mando 1", "Mando 2", "Mando 3", "Mando 4"]
## Shorter names that fit a fighter card's device selector.
const CARD_LABELS := ["Todos", "WASD", "Flechas", "Mando 1", "Mando 2", "Mando 3", "Mando 4"]
const MAX_SLOTS := 4

## Shipped bindings, taken the first time they are needed:
## action -> Array[InputEvent].
static var _shipped := {}


## Keyboard half a scheme uses: 1 = WASD, 2 = arrows, 0 = none.
static func keys_of(scheme: int) -> int:
	match scheme:
		Scheme.KEYS_OR_PAD, Scheme.WASD:
			return 1
		Scheme.ARROWS:
			return 2
	return 0


## Gamepad (device index) a scheme uses, or -1.
static func pad_of(scheme: int) -> int:
	if scheme == Scheme.KEYS_OR_PAD:
		return 0
	return scheme - Scheme.PAD_1 if scheme >= Scheme.PAD_1 else -1


## Keys each keyboard half shows on its fighter card.
const KEY_HINTS := {Scheme.WASD: "J K L I", Scheme.ARROWS: ". , / Enter", Scheme.KEYS_OR_PAD: "Teclado o mando"}
## Actions that join a keyboard half to a fighter card. Movement and jump are
## left out: the arrows and the space bar also move through the menu.
const JOIN_ACTIONS := ["attack", "fire", "pickup", "switch"]


## Scheme whose device sent `event` as a "join me" press: any button on
## gamepads 1-4, or an attack/block/pickup/switch key of either keyboard half
## that isn't also a menu key (Enter and Space confirm). -1 otherwise.
static func join_scheme(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		return Scheme.PAD_1 + event.device if event.device >= 0 and event.device < MAX_SLOTS else -1
	if not (event is InputEventKey and event.pressed and not event.echo):
		return -1
	for menu_action in ["ui_accept", "ui_select", "ui_cancel"]:
		if InputMap.has_action(menu_action) and event.is_action(menu_action):
			return -1
	_remember_shipped()
	for half in [1, 2]:
		for action in JOIN_ACTIONS:
			for shipped in _shipped.get("p%d_%s" % [half, action], []):
				if shipped is InputEventKey and shipped.physical_keycode == event.physical_keycode:
					return Scheme.WASD if half == 1 else Scheme.ARROWS
	return -1


## Two players can't share a keyboard half or a gamepad.
static func clash(a: int, b: int) -> bool:
	var keys := keys_of(a)
	var pad := pad_of(a)
	return (keys != 0 and keys == keys_of(b)) or (pad != -1 and pad == pad_of(b))


static func all_distinct(schemes: Array) -> bool:
	for i in schemes.size():
		for j in range(i + 1, schemes.size()):
			if clash(schemes[i], schemes[j]):
				return false
	return true


## What each of `humans` players gets before anyone picks: a lone player
## takes both the keyboard and the first pad; otherwise the keyboard halves
## go to the players the connected pads can't cover, and the pads to the rest.
static func defaults(humans: int, pads: int) -> Array[int]:
	var out: Array[int] = []
	if humans == 1:
		out.append(Scheme.KEYS_OR_PAD)
		return out
	var keyboards := clampi(humans - pads, 0, 2)
	for i in humans:
		if i < keyboards:
			out.append(Scheme.WASD if i == 0 else Scheme.ARROWS)
		else:
			out.append(Scheme.PAD_1 + mini(i - keyboards, 3))
	return out


## Binds slot i + 1 to `schemes[i]`; an empty list restores the shipped map.
static func apply(schemes: Array) -> void:
	_remember_shipped()
	reset()
	for i in mini(schemes.size(), MAX_SLOTS):
		_bind(i + 1, schemes[i])


static func reset() -> void:
	_remember_shipped()
	for action in _shipped:
		InputMap.action_erase_events(action)
		for event in _shipped[action]:
			InputMap.action_add_event(action, event)


static func _bind(slot: int, scheme: int) -> void:
	var keys := keys_of(scheme)
	var pad := pad_of(scheme)
	for action in DeviceInputSource.ACTIONS:
		var name := "p%d_%s" % [slot, action]
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		InputMap.action_erase_events(name)
		if keys != 0:
			for event in _shipped.get("p%d_%s" % [keys, action], []):
				if event is InputEventKey:
					InputMap.action_add_event(name, event)
		if pad != -1:
			# P1's pad bindings are the template; only the device changes.
			for event in _shipped.get("p1_" + action, []):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					var copy: InputEvent = event.duplicate()
					copy.device = pad
					InputMap.action_add_event(name, copy)


static func _remember_shipped() -> void:
	if not _shipped.is_empty():
		return
	for slot in range(1, MAX_SLOTS + 1):
		for action in DeviceInputSource.ACTIONS:
			var name := "p%d_%s" % [slot, action]
			if InputMap.has_action(name):
				var events: Array[InputEvent] = []
				for event in InputMap.action_get_events(name):
					events.append(event.duplicate())
				_shipped[name] = events
