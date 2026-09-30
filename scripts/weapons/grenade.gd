class_name Grenade
extends RigidBody2D

## A thrown grenade. Bounces on the map (mask 1) but flies through fighters
## (layer 0), slides to a stop instead of rolling away, blinks faster as the
## fuse burns and then turns into an Explosion at its current position.
## Rockets (`explode_on_contact`) also collide with fighters (layer 2), skip
## their shooter and blow up on the first thing they touch, except that a
## fighter hit head-on gets carried away riding it (Superfighters): the rider
## steers with left/right and dies in the blast when the ride ends. A ridden
## rocket slows down so the rider can react, and every rocket blows up at the
## edge of the map the camera shows, so nobody rides out of sight.
## A molotov (`fire_width`) shatters on contact, sets fighters in the blast on
## fire and leaves a burning puddle on the floor below.

signal exploded(explosion: Explosion)

const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")
## Longest a rocket can carry a rider before it blows up anyway (seconds).
const RIDE_TIME := 3.0
## How fast a rider turns the rocket (radians per second at full stick).
## With RIDE_SPEED_SCALE the turning circle stays about as wide as before:
## more time to react, not an easier way to aim it back at someone.
const STEER_RATE := 2.0
## Share of the launch speed a rocket keeps once someone rides it.
const RIDE_SPEED_SCALE := 0.6
## A rocket this close (px) to the edge of the camera's bounds hits it like a
## wall: the rider can't fly off the screen.
const EDGE_MARGIN := 8.0
## How far below the blast (px) a molotov looks for floor to spill onto.
const SPILL_REACH := 160.0
## Height of the burning puddle (px): tall enough to catch feet.
const FIRE_HEIGHT := 10.0

var data: GrenadeData
var thrower: Node
var fuse_left := 0.0
## The fighter riding this rocket, if any.
var rider: Node

## Heading and speed of the flight: a mount keeps flying at launch speed
## (the contact with the rider's body would otherwise brake it).
var _flight := Vector2.ZERO
var _speed := 0.0

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
	_flight = launch_velocity
	_speed = launch_velocity.length()
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
		body_entered.connect(_on_contact)


func _physics_process(delta: float) -> void:
	if data == null or _exploded:
		return
	fuse_left -= delta
	if rider != null:
		if not is_instance_valid(rider) or rider.health.is_dead():
			rider = null
		else:
			# Same speed, new heading: the rider only turns it.
			var steer: float = rider.rocket_steer()
			_flight = _flight.rotated(steer * STEER_RATE * delta)
			linear_velocity = _flight
	elif data.is_rocket() and linear_velocity.length() > _speed * 0.9:
		_flight = linear_velocity
	queue_redraw()
	if fuse_left <= 0.0 or (data.is_rocket() and _out_of_bounds()):
		explode()


## True past the edge (less EDGE_MARGIN) of the area the shared camera may
## show; false when there is no camera (tests, demos).
func _out_of_bounds() -> bool:
	var camera := get_tree().get_first_node_in_group(SharedCamera.GROUP) as SharedCamera
	if camera == null or camera.bounds.size.x <= 0.0 or camera.bounds.size.y <= 0.0:
		return false
	return not camera.bounds.grow(-EDGE_MARGIN).has_point(global_position)


## Detonates right now (fuse ran out, or a chain reaction later on).
func explode() -> Explosion:
	if _exploded:
		return null
	_exploded = true
	if rider != null and is_instance_valid(rider):
		rider.end_rocket_ride()
		rider.health.take_damage(rider.health.current_health, thrower)
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.configure(data)
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	explosion.detonate(thrower)
	if data.fire_width > 0.0:
		_ignite_around()
		_spill_fire()
	exploded.emit(explosion)
	queue_free()
	return explosion


## Deferred: the blast frees map blocks, which can't happen mid-callback.
func _on_contact(body: Node) -> void:
	if _exploded:
		return
	if data.is_rocket() and rider == null and body != thrower and body.has_method("start_rocket_ride") \
			and not body.health.is_dead():
		_mount.call_deferred(body)
		return
	if body == rider:
		return
	explode.call_deferred()


func _mount(body: Node) -> void:
	if _exploded or rider != null or not is_instance_valid(body):
		return
	rider = body
	add_collision_exception_with(body)
	fuse_left = RIDE_TIME
	_speed *= RIDE_SPEED_SCALE
	_flight = _flight.normalized() * _speed
	linear_velocity = _flight
	# Now it can come back for whoever fired it.
	if thrower is PhysicsBody2D and is_instance_valid(thrower):
		remove_collision_exception_with(thrower)
	body.start_rocket_ride(self)


## Fighters caught in a molotov's blast catch fire.
func _ignite_around() -> void:
	var circle := CircleShape2D.new()
	circle.radius = data.explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = Burning.FIGHTER_MASK
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var burning := Burning.of(result.collider)
		if burning != null:
			burning.ignite(data.ignite_time, thrower)


## Leaves a burning puddle on the first floor below the blast, if any.
func _spill_fire() -> Node:
	var query := PhysicsRayQueryParameters2D.create(
			global_position + Vector2(0, -2), global_position + Vector2(0, SPILL_REACH), 1)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var fire := HazardZone.new()
	fire.kind = HazardZone.Kind.FIRE
	fire.size = Vector2(data.fire_width, FIRE_HEIGHT)
	fire.damage_per_second = data.fire_damage_per_second
	fire.ignite_time = data.ignite_time
	fire.lifetime = data.fire_time
	fire.source = thrower
	get_parent().add_child(fire)
	fire.global_position = hit.position - Vector2(data.fire_width / 2.0, FIRE_HEIGHT)
	return fire


## Placeholder look until sprites land: a green ball whose fuse light blinks
## faster in the last second; rockets are a body with a flame at the back.
func _draw() -> void:
	if data != null and data.fire_width > 0.0:
		# A spinning bottle with a lit rag.
		draw_set_transform(Vector2.ZERO, fuse_left * 12.0)
		draw_rect(Rect2(-2.5, -2, 5, 5), data.color)
		draw_rect(Rect2(-1, -4, 2, 2), Color("b86f50"))
		draw_circle(Vector2(0, -5), 1.5 + fmod(fuse_left * 20.0, 1.0), Color("feae34"))
		return
	if data != null and data.is_rocket():
		# Drawn along its flight, so a steered rocket points where it goes.
		draw_set_transform(Vector2.ZERO, linear_velocity.angle() if linear_velocity.length() > 1.0 else 0.0)
		draw_rect(Rect2(-4, -1.5, 8, 3), data.color)
		draw_circle(Vector2(-5.0, 0), 1.8 + fmod(fuse_left * 20.0, 1.0), Color("feae34"))
		return
	var body_color := data.color if data != null else Color("63c74d")
	draw_circle(Vector2.ZERO, 3.0, body_color)
	var rate := 16.0 if fuse_left < 1.0 else 5.0
	if fmod(fuse_left * rate, 2.0) < 1.0:
		draw_circle(Vector2(0, -3), 1.2, Color("feae34"))
