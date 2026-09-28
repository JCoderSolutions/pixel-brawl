@tool
class_name HazardZone
extends Area2D

## Area of the map that hurts every fighter inside it: bottomless drops, fire
## and acid pits, spikes, flame jets. Damage goes through the fighter's
## HealthComponent, so ragdoll, HUD, rounds and sound react on their own.
##
## The node's origin is the zone's top-left corner, so it lines up with
## DestructibleMap cells (cell * 16). A zone can start off and be switched on
## by a TrapSwitch (trigger()) or pulse on a timer (cycle_on / cycle_off).

signal activated
signal deactivated
## A fighter took damage (or died) from this zone.
signal hurt(body: Node2D, amount: int)

enum Kind { VOID, FIRE, ACID, SPIKES }

## Placeholder palette (Endesga 32) until the art pass: [base, highlight].
const COLORS := {
	Kind.VOID: [Color("181425"), Color("262b44")],
	Kind.FIRE: [Color("e43b44"), Color("feae34")],
	Kind.ACID: [Color("3e8948"), Color("63c74d")],
	Kind.SPIKES: [Color("5a6988"), Color("c0cbdc")],
}
## Players only (layer 2).
const FIGHTER_MASK := 2

@export var kind := Kind.FIRE:
	set(value):
		kind = value
		queue_redraw()
@export var size := Vector2(48, 16):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var damage_per_second := 40.0
## Kills on contact whatever the damage (bottomless drops, crushers).
@export var instant_kill := false
## Velocity given to a fighter when the zone first hurts it; fire makes you
## hop out of the pit, acid doesn't let go.
@export var launch := Vector2.ZERO
@export var active := true:
	set(value):
		if value == active:
			return
		active = value
		_victims.clear()
		queue_redraw()
		if is_inside_tree():
			(activated if active else deactivated).emit()
## Seconds trigger() keeps the zone on; 0 leaves it on for good.
@export var trigger_duration := 1.5
## Periodic trap: seconds on, then `cycle_off` seconds off. 0 disables.
@export var cycle_on := 0.0
@export var cycle_off := 0.0

## body -> damage accumulated below 1 hp, so low rates still add up.
var _victims := {}
var _on_timer := 0.0
var _cycle_timer := 0.0
var _collider: CollisionShape2D


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = FIGHTER_MASK
	monitorable = false
	_cycle_timer = cycle_on if active else cycle_off
	body_exited.connect(func(body): _victims.erase(body))


## Switches the zone on for `trigger_duration` seconds (TrapSwitch target).
func trigger() -> void:
	active = true
	_on_timer = trigger_duration


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_tick_timers(delta)
	if active:
		for body in get_overlapping_bodies():
			_hurt(body, delta)


func _tick_timers(delta: float) -> void:
	if _on_timer > 0.0:
		_on_timer -= delta
		if _on_timer <= 0.0:
			active = false
	elif cycle_on > 0.0 and cycle_off > 0.0:
		_cycle_timer -= delta
		if _cycle_timer <= 0.0:
			active = not active
			_cycle_timer = cycle_on if active else cycle_off


func _hurt(body: Node2D, delta: float) -> void:
	var health := health_of(body)
	if health == null or health.is_dead():
		return
	if not _victims.has(body):
		_victims[body] = 0.0
		if launch != Vector2.ZERO and "velocity" in body:
			body.velocity = launch
	var amount: int
	if instant_kill:
		amount = health.current_health
	else:
		var pending: float = _victims[body] + damage_per_second * delta
		amount = floori(pending)
		_victims[body] = pending - amount
	if amount > 0:
		health.take_damage(amount, self)
		hurt.emit(body, amount)


## The HealthComponent a body exposes as `health`, or its child of that name.
static func health_of(body: Node) -> HealthComponent:
	var health = body.get("health")
	if health is HealthComponent:
		return health
	return body.get_node_or_null("HealthComponent") as HealthComponent


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _collider == null:
		_collider = CollisionShape2D.new()
		_collider.shape = RectangleShape2D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
	_collider.shape.size = size
	_collider.position = size / 2.0


## Placeholder look until the art pass: a flat pool with a lighter surface
## line and a few tongues of flame, bubbles or spikes on top.
func _draw() -> void:
	var colors: Array = COLORS[kind]
	var base: Color = colors[0]
	var top: Color = colors[1]
	if not active:
		# Dormant trap: only the vent shows.
		draw_rect(Rect2(0, size.y - 3, size.x, 3), base.darkened(0.4))
		return
	draw_rect(Rect2(Vector2.ZERO, size), base)
	match kind:
		Kind.VOID:
			pass
		Kind.SPIKES:
			var x := 0.0
			while x < size.x:
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, size.y), Vector2(x + 4, 0), Vector2(x + 8, size.y)]), top)
				x += 8.0
		_:
			draw_rect(Rect2(0, 0, size.x, 2), top)
			var x := 3.0
			while x < size.x - 2:
				draw_rect(Rect2(x, 3 + fmod(x * 7.0, 5.0), 2, 2), top)
				x += 7.0
