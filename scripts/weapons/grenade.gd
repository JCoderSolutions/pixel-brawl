class_name Grenade
extends RigidBody2D

## A thrown grenade. Bounces on the map (mask 1) but flies through fighters
## (layer 0), slides to a stop instead of rolling away, blinks faster as the
## fuse burns and then turns into an Explosion at its current position.

signal exploded(explosion: Explosion)

const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")

var data: GrenadeData
var thrower: Node
var fuse_left := 0.0

var _exploded := false


func setup(grenade: GrenadeData, from: Vector2, launch_velocity: Vector2, source: Node) -> void:
	data = grenade
	thrower = source
	fuse_left = grenade.fuse_time
	global_position = from
	linear_velocity = launch_velocity
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = grenade.bounce
	physics_material_override.friction = 1.0


func _physics_process(delta: float) -> void:
	if data == null or _exploded:
		return
	fuse_left -= delta
	queue_redraw()
	if fuse_left <= 0.0:
		explode()


## Detonates right now (fuse ran out, or a chain reaction later on).
func explode() -> Explosion:
	if _exploded:
		return null
	_exploded = true
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.configure(data)
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	explosion.detonate(thrower)
	exploded.emit(explosion)
	queue_free()
	return explosion


## Placeholder look until sprites land: a green ball whose fuse light blinks
## faster in the last second.
func _draw() -> void:
	var body_color := data.color if data != null else Color("63c74d")
	draw_circle(Vector2.ZERO, 3.0, body_color)
	var rate := 16.0 if fuse_left < 1.0 else 5.0
	if fmod(fuse_left * rate, 2.0) < 1.0:
		draw_circle(Vector2(0, -3), 1.2, Color("feae34"))
