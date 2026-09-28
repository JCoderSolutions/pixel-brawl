class_name RagdollOnDeath
extends Node

## Drop-in child for any character with a HealthComponent: when it dies, the
## character's Visual is hidden and a Ragdoll takes its place, thrown along
## the knockback of the killing blow. Works without touching the owner's
## script, so players, dummies and future enemies all get it for free.

signal ragdoll_spawned(ragdoll: Ragdoll)

@export var ragdoll_scene: PackedScene = preload("res://scenes/effects/ragdoll.tscn")
## Defaults to the parent's "HealthComponent" child.
@export var health: HealthComponent
## Defaults to the parent's "Visual" child; its colour tints the ragdoll.
@export var visual: CanvasItem
## Scales the killing blow's knockback so deaths read bigger than hits.
@export var launch_multiplier := 1.5
## Used when the body has no velocity at death (e.g. killed while stunned).
@export var fallback_launch := Vector2(160.0, -160.0)

var ragdoll: Ragdoll

var _body: Node2D
var _color := Color.WHITE


func _ready() -> void:
	_body = get_parent() as Node2D
	if health == null:
		health = _body.get_node_or_null("HealthComponent") as HealthComponent
	if visual == null:
		visual = _body.get_node_or_null("Visual") as CanvasItem
	if visual and "color" in visual:
		_color = visual.color
	if health:
		health.died.connect(_on_died)
	else:
		push_warning("RagdollOnDeath: %s has no HealthComponent" % _body.name)


## Puts the character back on screen, for respawns between rounds.
func restore() -> void:
	if is_instance_valid(ragdoll):
		ragdoll.queue_free()
	ragdoll = null
	if visual:
		visual.visible = true


## `died` fires inside take_damage, before the Hurtbox applies knockback,
## so spawning is deferred until the killing blow's velocity is in place.
func _on_died(source: Node) -> void:
	_spawn.call_deferred(source)


func _spawn(source: Node) -> void:
	if not is_instance_valid(_body) or not _body.is_inside_tree():
		return
	ragdoll = ragdoll_scene.instantiate()
	ragdoll.global_position = _body.global_position
	_body.get_parent().add_child(ragdoll)
	ragdoll.set_color(_color)
	ragdoll.launch(_launch_velocity(source))
	if visual:
		visual.visible = false
	ragdoll_spawned.emit(ragdoll)


func _launch_velocity(source: Node) -> Vector2:
	var velocity: Vector2 = _body.get("velocity") if "velocity" in _body else Vector2.ZERO
	if velocity.length() < 1.0:
		var direction := 1.0
		if source is Node2D:
			direction = signf(_body.global_position.x - source.global_position.x)
			if direction == 0.0:
				direction = 1.0
		velocity = Vector2(fallback_launch.x * direction, fallback_launch.y)
	return velocity * launch_multiplier
