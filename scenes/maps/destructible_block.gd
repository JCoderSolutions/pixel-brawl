class_name DestructibleBlock
extends StaticBody2D

## One 16 px map tile that soaks damage through the shared Hurtbox /
## HealthComponent pipeline and disappears when its health runs out.
## Indestructible blocks keep the collider but never take damage.

signal destroyed(block: DestructibleBlock)

@export var indestructible := false
## Shade the tile fades towards as it loses health.
@export var damaged_color := Color("733e39")
@export var indestructible_color := Color("5a6988")

@onready var health: HealthComponent = $HealthComponent
@onready var _visual: ColorRect = $Visual
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _base_color: Color = _visual.color


func _ready() -> void:
	if indestructible:
		_base_color = indestructible_color
		_visual.color = indestructible_color
		# Hits pass through untouched: no hurtbox means no damage and no hit
		# registered against the swing.
		_hurtbox.health = null
		_hurtbox.monitorable = false
		return
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)


func _on_health_changed(current: int, maximum: int) -> void:
	var lost := 1.0 - float(current) / float(maximum)
	_visual.color = _base_color.lerp(damaged_color, lost)


func _on_died(_source: Node) -> void:
	# Drop the collider now so bodies on top fall this same physics step.
	collision_layer = 0
	_hurtbox.set_deferred("monitorable", false)
	destroyed.emit(self)
	queue_free()
