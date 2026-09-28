class_name Hitbox
extends Area2D

## Damage-dealing area. Stays inactive until `activate()` opens a hit window;
## each Hurtbox is struck at most once per window and never its own owner's.

signal hit_landed(target: Hurtbox)

@export var damage := 10
## Knockback applied along +X; flipped by `direction` when the swing lands.
@export var knockback := Vector2(220.0, -120.0)

var direction := 1.0

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
	if hurtbox == null or hurtbox.owner == owner:
		return
	if hurtbox in _hit_this_window:
		return
	_hit_this_window.append(hurtbox)
	hurtbox.receive_hit(damage, Vector2(knockback.x * direction, knockback.y), owner)
	hit_landed.emit(hurtbox)
