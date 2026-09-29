class_name BreakableProp
extends CharacterBody2D

## Loose object on the map that fighters can hit, shoot and blow up:
## explosive barrels, supply crates. Hits go through the same Hurtbox +
## HealthComponent pipeline as fighters, shove the prop around, and when its
## health runs out `_break()` decides what it leaves behind.

signal broken(source: Node)

## Every prop joins this group so a new round can put them back.
const GROUP := &"props"
## Share of a hit's knockback turned into a shove (props are heavy).
const SHOVE := 0.5
## Props fall like fighters (and land on one-way planks like them, which
## rigid bodies don't do reliably) and slide to a stop on the floor.
const GRAVITY := 980.0
const FRICTION := 600.0
const MAX_FALL := 700.0

## Who hit it last: they get the credit for whatever it does when it breaks.
var last_attacker: Node

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: Hurtbox = $Hurtbox

var _flash := 0.0
var _broken := false


func _ready() -> void:
	add_to_group(GROUP)
	_hurtbox.hit_received.connect(_on_hit_received)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func is_broken() -> bool:
	return _broken


func _on_damaged(_amount: int, source: Node) -> void:
	if source != null:
		last_attacker = source


func _on_died(_source: Node) -> void:
	_on_broken.call_deferred()


func _on_hit_received(_damage: int, knockback: Vector2, _source: Node) -> void:
	velocity += knockback * SHOVE
	_flash = 0.08
	queue_redraw()


## Deferred from `died`: breaking frees bodies and may blow up the map,
## which can't happen inside a physics callback.
func _on_broken() -> void:
	if _broken:
		return
	_broken = true
	_break()
	broken.emit(last_attacker)
	queue_free()


## What the prop does as it breaks (explode, drop a weapon...).
func _break() -> void:
	pass


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()


func is_flashing() -> bool:
	return _flash > 0.0
