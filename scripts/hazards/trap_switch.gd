class_name TrapSwitch
extends Node2D

## Lever or button that fires the traps wired to it: punch it, shoot it or
## catch it in a blast. Hits arrive through its Hurtbox like on any fighter,
## so every weapon works without knowing switches exist. Each target gets
## trigger() (FallingBlock, HazardZone or anything with that method).

signal switched(by: Node)

@export var targets: Array[NodePath] = []
## Seconds before it can be switched again.
@export var cooldown := 1.0
## Fires once per round and then stays down.
@export var one_shot := false
@export var color := Color("feae34")
@export var used_color := Color("733e39")

var _cooldown_left := 0.0
var _used := false

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _health: HealthComponent = $HealthComponent


func _ready() -> void:
	_hurtbox.hit_received.connect(func(_damage, _knockback, source): activate(source))


func can_activate() -> bool:
	return _cooldown_left <= 0.0 and not (one_shot and _used)


func activate(by: Node = null) -> void:
	# The switch never breaks: top its health back up after every hit.
	_health.current_health = _health.max_health
	if not can_activate():
		return
	_used = true
	_cooldown_left = cooldown
	for path in targets:
		var target := get_node_or_null(path)
		if target != null and target.has_method("trigger"):
			target.trigger()
	switched.emit(by)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		if _cooldown_left <= 0.0:
			queue_redraw()


## Placeholder look: a wall plate with a lever that flips while recharging.
func _draw() -> void:
	draw_rect(Rect2(-5, -8, 10, 16), Color("3a4466"))
	var ready := can_activate()
	var tip := Vector2(4, -6) if ready else Vector2(4, 6)
	draw_line(Vector2.ZERO, tip, color if ready else used_color, 2.0)
	draw_circle(tip, 2.0, color if ready else used_color)
