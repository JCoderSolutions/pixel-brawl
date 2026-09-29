class_name ExplosiveBarrel
extends BreakableProp

## Red barrel (Superfighters): a few punches, one bullet volley or any blast
## sets it off. The explosion hurts everyone around, breaks the map, sets
## fighters in the middle on fire and sets off other barrels in reach, so
## they chain. The kill goes to whoever hit it last.

const EXPLOSION_SCENE := preload("res://scenes/items/explosion.tscn")

@export var explosion_radius := 56.0
@export var explosion_damage := 50
@export var explosion_knockback := 360.0
@export var explosion_lift := 150.0
@export var block_damage := 40
## Fighters this close to the centre (share of the radius) catch fire.
@export_range(0.0, 1.0) var ignite_share := 0.6
@export var ignite_time := 2.5


func _break() -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.radius = explosion_radius
	explosion.damage = explosion_damage
	explosion.knockback = explosion_knockback
	explosion.lift = explosion_lift
	explosion.block_damage = block_damage
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector2(0, -10)
	explosion.detonate(last_attacker)
	_ignite_around(explosion.global_position)


func _ignite_around(center: Vector2) -> void:
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius * ignite_share
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = Burning.FIGHTER_MASK
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var burning := Burning.of(result.collider)
		if burning != null:
			burning.ignite(ignite_time, last_attacker)


## Placeholder look until the art pass: a red drum with dark hoops and a
## yellow hazard band; white while flashing from a hit.
func _draw() -> void:
	var body := Color("e43b44")
	if is_flashing():
		body = Color.WHITE
	elif health != null and health.current_health < health.max_health / 2:
		# Damaged barrels pulse, a warning they're about to go.
		body = body.lerp(Color("feae34"), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
	draw_rect(Rect2(-6, -20, 12, 20), body)
	draw_rect(Rect2(-6, -20, 12, 1), Color("a22633"))
	draw_rect(Rect2(-6, -16, 12, 1), Color("a22633"))
	draw_rect(Rect2(-6, -5, 12, 1), Color("a22633"))
	draw_rect(Rect2(-6, -12, 12, 4), Color("feae34"))
	draw_rect(Rect2(-2, -11, 4, 2), Color("181425"))


func _process(delta: float) -> void:
	super(delta)
	if health != null and health.current_health < health.max_health / 2:
		queue_redraw()
