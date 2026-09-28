class_name Grenade
extends RigidBody2D

## A thrown grenade. Bounces on the map (mask 1) but flies through fighters
## (layer 0), slides to a stop instead of rolling away, blinks faster as the
## fuse burns and then turns into an Explosion at its current position.
## Rockets (`explode_on_contact`) also collide with fighters (layer 2), skip
## their shooter and blow up on the first thing they touch.

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
	# Teleport the physics body too: otherwise its first step still starts
	# from wherever it was added (the world origin) and can hit the map there.
	if is_inside_tree():
		PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	linear_velocity = launch_velocity
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = grenade.bounce
	physics_material_override.friction = 1.0
	gravity_scale = grenade.gravity_scale
	if grenade.explode_on_contact:
		collision_mask |= 2
		if source is PhysicsBody2D:
			add_collision_exception_with(source)
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_contact, CONNECT_ONE_SHOT)


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


## Deferred: the blast frees map blocks, which can't happen mid-callback.
func _on_contact(_body: Node) -> void:
	explode.call_deferred()


## Placeholder look until sprites land: a green ball whose fuse light blinks
## faster in the last second; rockets are a body with a flame at the back.
func _draw() -> void:
	if data != null and data.explode_on_contact:
		var back := -signf(linear_velocity.x) if linear_velocity.x != 0.0 else -1.0
		draw_rect(Rect2(-4, -1.5, 8, 3), data.color)
		draw_circle(Vector2(5.0 * back, 0), 1.8 + fmod(fuse_left * 20.0, 1.0), Color("feae34"))
		return
	var body_color := data.color if data != null else Color("63c74d")
	draw_circle(Vector2.ZERO, 3.0, body_color)
	var rate := 16.0 if fuse_left < 1.0 else 5.0
	if fmod(fuse_left * rate, 2.0) < 1.0:
		draw_circle(Vector2(0, -3), 1.2, Color("feae34"))
