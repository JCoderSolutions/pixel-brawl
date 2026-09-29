class_name Burning
extends Node2D

## Fighter on fire (Superfighters): loses health every second, passes the
## flames to anyone who touches them, and puts them out by rolling or diving.
## Fire pits, molotovs and explosive barrels light it through `ignite()`.
## Lives as a child of the fighter so the player script doesn't know about it.

signal ignited
signal extinguished

## Players only (layer 2).
const FIGHTER_MASK := 2
## Name every fighter gives this node, so fire can find it on another body.
const NODE_NAME := &"Burning"

@export var damage_per_second := 8.0
## Seconds a fresh ignition lasts; touching fire again tops it up.
@export var default_time := 4.0
## How close (px, centre to centre) another fighter must be to catch fire.
@export var spread_radius := 14.0
## Seconds between checks for fighters to pass the flames to.
@export var spread_interval := 0.3
## A fighter lit by spreading burns this share of the time left.
@export_range(0.0, 1.0) var spread_share := 0.75

var _time_left := 0.0
var _pending := 0.0
var _spread_timer := 0.0
var _source: Node
var _flicker := 0.0


## Sets the owner on fire for `seconds` (never shortening a longer burn).
## `source` gets the kill if the flames finish them.
func ignite(seconds := -1.0, source: Node = null) -> void:
	if seconds < 0.0:
		seconds = default_time
	var body := get_parent()
	var health := HazardZone.health_of(body)
	if health == null or health.is_dead() or seconds <= 0.0:
		return
	var was_burning := is_burning()
	if seconds > _time_left:
		_time_left = seconds
	if source != null:
		_source = source
	if not was_burning:
		_spread_timer = spread_interval
		ignited.emit()
		queue_redraw()


func extinguish() -> void:
	if not is_burning():
		return
	_time_left = 0.0
	_pending = 0.0
	extinguished.emit()
	queue_redraw()


func is_burning() -> bool:
	return _time_left > 0.0


func time_left() -> float:
	return _time_left


## The Burning node of `body`, if it can burn.
static func of(body: Node) -> Burning:
	if body == null:
		return null
	return body.get_node_or_null(NodePath(NODE_NAME)) as Burning


func _physics_process(delta: float) -> void:
	if not is_burning():
		return
	var body := get_parent()
	var health := HazardZone.health_of(body)
	if health == null or health.is_dead():
		extinguish()
		return
	# Rolling on the floor or diving smothers the flames.
	if (body.has_method("is_rolling") and body.is_rolling()) \
			or (body.has_method("is_diving") and body.is_diving()):
		extinguish()
		return
	_pending += damage_per_second * delta
	var amount := floori(_pending)
	if amount > 0:
		_pending -= amount
		health.take_damage(amount, _source)
		if health.is_dead():
			extinguish()
			return
	_spread_timer -= delta
	if _spread_timer <= 0.0:
		_spread_timer = spread_interval
		_spread()
	_time_left -= delta
	_flicker += delta
	queue_redraw()
	if _time_left <= 0.0:
		extinguish()


func _spread() -> void:
	if not is_inside_tree():
		return
	var circle := CircleShape2D.new()
	circle.radius = spread_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = FIGHTER_MASK
	var body := get_parent()
	if body is CollisionObject2D:
		query.exclude = [body.get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var other := of(result.collider)
		if other != null and not other.is_burning():
			other.ignite(_time_left * spread_share, _source)


## Placeholder look until the art pass: tongues of flame licking up the body.
func _draw() -> void:
	if not is_burning():
		return
	var colors := [Color("e43b44"), Color("f77622"), Color("feae34")]
	for i in 5:
		var x := -7.0 + i * 3.5
		var height := 7.0 + 5.0 * absf(sin(_flicker * 14.0 + i * 1.7))
		var base := Vector2(x, 8.0 - fmod(i * 5.0, 9.0))
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-2.0, 0.0), base + Vector2(0.0, -height), base + Vector2(2.0, 0.0)]),
			colors[i % colors.size()])
