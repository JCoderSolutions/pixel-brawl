class_name Hitbox
extends Area2D

## Damage-dealing area. Stays inactive until `activate()` opens a hit window;
## each Hurtbox is struck at most once per window and never its own owner's.

signal hit_landed(target: Hurtbox)

@export var damage := 10
## Knockback applied along +X; flipped by `direction` when the swing lands.
@export var knockback := Vector2(220.0, -120.0)
## The move being thrown scales `damage` (combo finishers, kicks); power-ups
## change `damage` itself.
var damage_scale := 1.0
## A knockout blow launches at least this hard, even a light jab.
const KNOCKOUT_KNOCKBACK := Vector2(220.0, -160.0)

var direction := 1.0
## Never hits this node's hurtboxes either (a thrown weapon's thrower).
var exclude: Node

var _hit_this_window: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_this_window.clear()
	set_deferred("monitoring", true)


func deactivate() -> void:
	set_deferred("monitoring", false)


func is_active() -> bool:
	return monitoring


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.owner == owner or (exclude != null and hurtbox.owner == exclude):
		return
	if hurtbox in _hit_this_window:
		return
	_hit_this_window.append(hurtbox)
	if not hurtbox.melee_proof:
		var dealt := roundi(damage * damage_scale)
		var push := knockback
		if hurtbox.health != null and dealt >= hurtbox.health.current_health:
			push = Vector2(maxf(absf(push.x), KNOCKOUT_KNOCKBACK.x), minf(push.y, KNOCKOUT_KNOCKBACK.y))
		hurtbox.receive_hit(dealt, Vector2(push.x * direction, push.y), owner, &"melee", global_position)
	hit_landed.emit(hurtbox)
