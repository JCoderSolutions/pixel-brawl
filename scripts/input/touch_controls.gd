class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets: a floating stick on the left
## (move + crouch) and jump/attack/fire/pickup buttons on the right. They press
## the slot's `p<slot>_*` actions, so the player reads them through its usual
## DeviceInputSource with no touch-specific code.
##
## The layout is recomputed from the visible viewport size, so it scales with
## the resolution and works in landscape and portrait.

enum Visibility { AUTO, ALWAYS, NEVER }

## Base height the sizes below are designed for (project viewport is 480x270).
const BASE_SIZE := 270.0
const MARGIN := 10.0
const STICK_RADIUS := 32.0
## Button centres as offsets from the bottom-right corner (minus margin), and
## radii, in base units. Attack is the biggest and sits under the thumb.
const BUTTONS := {
	"Attack": {"offset": Vector2(-78, -26), "radius": 22.0},
	"Jump": {"offset": Vector2(-26, -48), "radius": 20.0},
	"Fire": {"offset": Vector2(-74, -76), "radius": 17.0},
	"Pickup": {"offset": Vector2(-26, -100), "radius": 15.0},
}
## Actions that may not be in project.godot yet (weapons are not wired into
## the player). They are created empty at runtime so the buttons can press them.
const RUNTIME_ACTIONS := ["fire", "pickup"]

@export_range(1, 4) var slot := 1
## AUTO shows the controls on touch screens, or as soon as a finger touches.
@export var visibility := Visibility.AUTO

@onready var joystick: VirtualJoystick = $Joystick
@onready var buttons := {
	"Attack": $Attack as TouchActionButton,
	"Jump": $Jump as TouchActionButton,
	"Fire": $Fire as TouchActionButton,
	"Pickup": $Pickup as TouchActionButton,
}


func _ready() -> void:
	var prefix := "p%d_" % slot
	for action in RUNTIME_ACTIONS:
		ensure_action(prefix + action)
	joystick.prefix = prefix
	for name in buttons:
		buttons[name].action = prefix + name.to_lower()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	set_shown(should_show(visibility, DisplayServer.is_touchscreen_available()))


static func should_show(mode: Visibility, has_touchscreen: bool) -> bool:
	match mode:
		Visibility.ALWAYS:
			return true
		Visibility.NEVER:
			return false
	return has_touchscreen


## Adds an action with no bindings if the InputMap lacks it.
static func ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


## Rects in screen pixels for a visible area of `screen` size: "Stick" is the
## zone where a finger grabs the stick, the rest are the buttons' squares.
static func compute_layout(screen: Vector2) -> Dictionary:
	var unit := minf(screen.x, screen.y) / BASE_SIZE
	var margin := MARGIN * unit
	var corner := screen - Vector2(margin, margin)
	var layout := {}
	for name in BUTTONS:
		var r: float = BUTTONS[name].radius * unit
		var center: Vector2 = corner + BUTTONS[name].offset * unit
		layout[name] = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	# Lower-left area, up to 45% of the width: the stick floats to the finger.
	var top := screen.y * 0.35
	layout["Stick"] = Rect2(Vector2(0, top), Vector2(screen.x * 0.45, screen.y - top))
	layout["unit"] = unit
	return layout


func set_shown(shown: bool) -> void:
	if visible == shown:
		return
	visible = shown
	if not shown:
		release_all()


func release_all() -> void:
	joystick.release()
	for name in buttons:
		buttons[name].release()


func _input(event: InputEvent) -> void:
	# AUTO on a device that did not report a touch screen: the first touch
	# reveals the controls. Re-dispatch it (already in viewport coordinates) so
	# that touch also presses whatever is under it.
	if visible or visibility != Visibility.AUTO or not (event is InputEventScreenTouch and event.pressed):
		return
	set_shown(true)
	get_viewport().set_input_as_handled()
	get_viewport().push_input.call_deferred(event, true)


func _relayout() -> void:
	var layout := compute_layout(get_viewport().get_visible_rect().size)
	var unit: float = layout.unit
	var zone: Rect2 = layout.Stick
	joystick.position = zone.position
	joystick.size = zone.size
	joystick.radius = STICK_RADIUS * unit
	for name in buttons:
		var rect: Rect2 = layout[name]
		buttons[name].position = rect.position
		buttons[name].size = rect.size
