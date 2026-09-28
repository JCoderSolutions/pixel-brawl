class_name FallDamage
extends Node

## Drop-in child for a CharacterBody2D fighter: landing faster than
## `safe_speed` hurts through the body's HealthComponent, harder the faster
## the fall. A normal jump (~380 px/s on landing) never hurts; dropping about six tiles
## starts to. Needs no code in the owner, like RagdollOnDeath.

signal hard_landing(impact_speed: float, damage: int)

## Falling speed (px/s) a landing can take without harm. Falling from rest
## reaches sqrt(2 * gravity * height): 500 px/s is ~99 px (6 tiles) with the
## player's falling gravity (900 x 1.4 = 1260).
@export var safe_speed := 500.0
## Hit points lost per px/s above `safe_speed`.
@export var damage_per_speed := 0.2
## Defaults to the parent's "HealthComponent" child.
@export var health: HealthComponent

var _body: CharacterBody2D
var _was_on_floor := true
var _fall_speed := 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if health == null and _body:
		health = _body.get_node_or_null("HealthComponent") as HealthComponent
	# After the owner's move_and_slide(), so floor state is this tick's.
	process_physics_priority = 1


## Damage a landing at `impact_speed` px/s deals.
func damage_for(impact_speed: float) -> int:
	return maxi(roundi((impact_speed - safe_speed) * damage_per_speed), 0)


func _physics_process(_delta: float) -> void:
	if _body == null:
		return
	var on_floor := _body.is_on_floor()
	if on_floor and not _was_on_floor:
		_land(_fall_speed)
	# Landing zeroes velocity, so remember the last airborne speed.
	_fall_speed = 0.0 if on_floor else maxf(_body.velocity.y, 0.0)
	_was_on_floor = on_floor


func _land(impact_speed: float) -> void:
	var damage := damage_for(impact_speed)
	if damage == 0 or health == null or health.is_dead():
		return
	health.take_damage(damage, _body)
	hard_landing.emit(impact_speed, damage)
