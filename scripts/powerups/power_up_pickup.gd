class_name PowerUpPickup
extends RigidBody2D

## A power-up lying on the map. Falls on the world (mask 1) without blocking
## anyone (layer 0); its Grab area (mask 2) hands it to the first fighter with
## a PowerUpReceiver that walks over it, Superfighters style: no button.

signal collected(data: PowerUpData, by: Node)

const GROUP := &"power_ups"

@export var power_up: PowerUpData:
	set(value):
		power_up = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	$Grab.body_entered.connect(try_give)


## Gives the power-up to `fighter`; returns false if it can't use it now.
func try_give(fighter: Node) -> bool:
	if is_queued_for_deletion() or power_up == null:
		return false
	var receiver := PowerUpReceiver.find_on(fighter)
	if receiver == null or not receiver.apply(power_up):
		return false
	remove_from_group(GROUP)
	collected.emit(power_up, fighter)
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio != null:
		audio.play_sfx(&"pickup")
	queue_free()
	return true


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	# A fighter already standing on it (e.g. a medkit refused at full health)
	# grabs it as soon as it can use it.
	if Engine.get_physics_frames() % 10 == 0:
		for fighter in $Grab.get_overlapping_bodies():
			if try_give(fighter):
				return


## Placeholder look until sprites land: a glowing box with a glyph per effect.
func _draw() -> void:
	if power_up == null:
		return
	var glow := 0.35 + 0.25 * sin(_time * 5.0)
	draw_circle(Vector2.ZERO, 9.0, Color(power_up.color, glow * 0.5))
	draw_rect(Rect2(-6, -6, 12, 12), power_up.color)
	var ink := Color(1, 1, 1, 0.95)
	match power_up.effect:
		PowerUpData.Effect.HEAL:
			draw_rect(Rect2(-1, -4, 2, 8), ink)
			draw_rect(Rect2(-4, -1, 8, 2), ink)
		PowerUpData.Effect.SPEED:
			draw_polyline(PackedVector2Array([Vector2(-4, -3), Vector2(-1, 0), Vector2(-4, 3)]), ink, 1.0)
			draw_polyline(PackedVector2Array([Vector2(0, -3), Vector2(3, 0), Vector2(0, 3)]), ink, 1.0)
		PowerUpData.Effect.STRENGTH:
			draw_rect(Rect2(-3, -3, 6, 6), ink)
			draw_rect(Rect2(-1, 3, 2, 2), ink)
		PowerUpData.Effect.SHIELD:
			draw_polygon(PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]), PackedColorArray([ink]))
