class_name Ragdoll
extends Node2D

## Physics corpse made of pinned rigid bodies. Parts live on the "debris"
## layer (5) and only collide with the world, so bodies pile up on the map
## without tripping living players or blocking hitboxes.
##
## Origin sits at the feet, like the player, so it can be dropped at the
## dead body's position without offsets. Art swaps later by replacing each
## part's Visual node.

## Seconds before the corpse fades out and frees itself. 0 keeps it forever.
@export var lifetime := 6.0
@export var fade_time := 0.5
## Spin added to the torso on launch, in rad/s per 100 px/s of horizontal speed.
@export var spin_per_speed := 4.0

@onready var _torso: RigidBody2D = $Torso
@onready var _head: RigidBody2D = $Head


func _ready() -> void:
	if lifetime > 0.0:
		var tween := create_tween()
		tween.tween_interval(lifetime)
		tween.tween_property(self, "modulate:a", 0.0, fade_time)
		tween.tween_callback(queue_free)


func get_parts() -> Array[RigidBody2D]:
	var parts: Array[RigidBody2D] = []
	for child in get_children():
		if child is RigidBody2D:
			parts.append(child)
	return parts


func get_torso() -> RigidBody2D:
	return _torso


func set_color(color: Color) -> void:
	for part in get_parts():
		var visual := part.get_node_or_null("Visual") as ColorRect
		if visual:
			visual.color = color.lightened(0.15) if part == _head else color


## Throws every part with the same velocity so the body leaves as one piece,
## then lets the torso tumble in the direction of travel.
func launch(velocity: Vector2) -> void:
	for part in get_parts():
		part.linear_velocity = velocity
	_torso.angular_velocity = velocity.x / 100.0 * spin_per_speed
	_head.angular_velocity = _torso.angular_velocity * 1.5
