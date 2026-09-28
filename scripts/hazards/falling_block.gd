class_name FallingBlock
extends CharacterBody2D

## Heavy crate or metal slab hanging from the ceiling until a TrapSwitch
## releases it (trigger()). A fighter it lands on while standing on the
## ground is crushed to death; one hit in mid-air takes damage by speed and is
## shoved down. Slow contact (resting on a head) hurts nobody.
##
## Sits on the world layer, so once it lands fighters stand on it like any
## tile. The node's origin is the block's top-left corner.

signal released
signal crushed(body: Node2D)
signal landed(impact_speed: float)

## Players (layer 2) plus the world (layer 1).
const FALL_MASK := 3

@export var size := Vector2(32, 16)
## Hangs in place until trigger(); off drops it at once.
@export var held := true
@export var gravity := 900.0
@export var max_fall_speed := 700.0
## Falling speed (px/s) from which the block crushes or hurts fighters.
@export var crush_speed := 150.0
## Hit points a mid-air fighter loses per px/s of impact speed.
@export var impact_damage_per_speed := 0.08
@export var color := Color("5a6988")
@export var detail_color := Color("3a4466")


func _ready() -> void:
	collision_layer = 1
	collision_mask = FALL_MASK
	var collider := CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	collider.shape.size = size
	collider.position = size / 2.0
	add_child(collider, false, Node.INTERNAL_MODE_FRONT)


func trigger() -> void:
	if not held:
		return
	held = false
	queue_redraw()
	released.emit()


func _physics_process(delta: float) -> void:
	if held:
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	var collision := move_and_collide(Vector2(0.0, velocity.y * delta))
	if collision == null:
		return
	var speed := velocity.y
	# Fighters only: map tiles have health too, but a crate doesn't break them.
	var other := collision.get_collider() as CharacterBody2D
	var health := HazardZone.health_of(other) if other else null
	if health != null and collision.get_normal().y < -0.5:
		_hit_fighter(other, health, speed)
	else:
		velocity.y = 0.0
		if speed >= crush_speed:
			landed.emit(speed)


func _hit_fighter(fighter: Node2D, health: HealthComponent, speed: float) -> void:
	if speed < crush_speed or health.is_dead():
		# Resting on a head (or a corpse): stop until it moves away.
		velocity.y = 0.0
		if health.is_dead():
			add_collision_exception_with(fighter)
		return
	var pinned: bool = fighter.has_method("is_on_floor") and fighter.is_on_floor()
	if pinned:
		# Squashed against the ground. The corpse is flung sideways and the
		# block keeps falling through it to the floor.
		var side := signf(fighter.global_position.x - (global_position.x + size.x / 2.0))
		if "velocity" in fighter:
			fighter.velocity = Vector2((side if side != 0.0 else 1.0) * 120.0, -60.0)
		health.take_damage(health.current_health, self)
		add_collision_exception_with(fighter)
		crushed.emit(fighter)
	else:
		health.take_damage(maxi(roundi(speed * impact_damage_per_speed), 1), self)
		if "velocity" in fighter:
			fighter.velocity.y = maxf(fighter.velocity.y, speed)
		velocity.y *= 0.5


## Placeholder look until the art pass: riveted metal with a hook on top.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, size), detail_color, false, 1.0)
	draw_line(Vector2(0, 0), size, detail_color)
	draw_line(Vector2(0, size.y), Vector2(size.x, 0), detail_color)
	if held:
		draw_rect(Rect2(size.x / 2.0 - 1.0, -6.0, 2.0, 6.0), detail_color)
