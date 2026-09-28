class_name TargetDummy
extends StaticBody2D

## Practice target for weapons: takes hits through the same Hurtbox +
## HealthComponent as a player, flashes, and refills after dying.

## Seconds before a dead dummy refills; 0 keeps it dead.
@export var respawn_delay := 1.5

var last_knockback := Vector2.ZERO

@onready var health: HealthComponent = $HealthComponent
@onready var _visual: ColorRect = $Visual
@onready var _base_color: Color = _visual.color


func _ready() -> void:
	$Hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _on_hit_received(_damage: int, knockback: Vector2, _source: Node) -> void:
	last_knockback = knockback
	_visual.color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(_restore_color)


func _restore_color() -> void:
	_visual.color = _base_color.darkened(0.6) if health.is_dead() else _base_color


func _on_died(_source: Node) -> void:
	_visual.color = _base_color.darkened(0.6)
	if respawn_delay > 0.0:
		get_tree().create_timer(respawn_delay).timeout.connect(_revive)


func _revive() -> void:
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	_visual.color = _base_color
