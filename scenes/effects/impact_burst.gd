class_name ImpactBurst
extends CPUParticles2D

## One-shot pixel particle burst (hit flash, sparks, dust, debris, blast).
## Untextured particles draw as square pixels, which suits the pixel-art look
## and needs no asset. CPU particles so it behaves the same on Web/mobile.
## Frees itself once the last particle dies.

enum Kind { HIT, SPARK, DUST, DEBRIS, EXPLOSION }

## Endesga 32 swatches.
const WHITE := Color("ffffff")
const YELLOW := Color("fee761")
const ORANGE := Color("f77622")
const RED := Color("e43b44")
const DUST_GREY := Color("c0cbdc")
const BRICK := Color("b86f50")
const DARK_BRICK := Color("733e39")

var kind := Kind.HIT

var _life_left := 0.0


## Spawns a burst of `kind` at `at` (global) under `parent`, aimed along
## `direction` (spread comes from the preset).
static func spawn(parent: Node, burst_kind: Kind, at: Vector2, direction := Vector2.UP) -> ImpactBurst:
	var burst := ImpactBurst.new()
	burst.configure(burst_kind, direction)
	parent.add_child(burst)
	burst.global_position = at
	burst.restart()
	return burst


func configure(burst_kind: Kind, direction := Vector2.UP) -> void:
	kind = burst_kind
	one_shot = true
	explosiveness = 1.0
	local_coords = false
	z_index = 20
	self.direction = direction.normalized() if direction.length() > 0.01 else Vector2.UP
	match kind:
		Kind.HIT:
			_preset(10, 0.25, 70.0, 140.0, 70.0, 300.0, 1.0, 2.0, WHITE, RED)
		Kind.SPARK:
			_preset(8, 0.18, 90.0, 180.0, 35.0, 200.0, 1.0, 1.0, WHITE, YELLOW)
		Kind.DUST:
			_preset(6, 0.35, 15.0, 45.0, 80.0, -20.0, 1.0, 2.0, DUST_GREY, DUST_GREY)
		Kind.DEBRIS:
			_preset(10, 0.6, 50.0, 130.0, 70.0, 500.0, 1.0, 3.0, BRICK, DARK_BRICK)
		Kind.EXPLOSION:
			_preset(28, 0.5, 60.0, 190.0, 180.0, 120.0, 1.0, 3.0, YELLOW, ORANGE)
	_life_left = lifetime + 0.1
	emitting = true


func _preset(count: int, life: float, speed_min: float, speed_max: float,
		spread_deg: float, fall: float, size_min: float, size_max: float,
		from: Color, to: Color) -> void:
	amount = count
	lifetime = life
	initial_velocity_min = speed_min
	initial_velocity_max = speed_max
	spread = spread_deg
	gravity = Vector2(0.0, fall)
	damping_min = speed_min * 0.5
	damping_max = speed_max * 0.5
	scale_amount_min = size_min
	scale_amount_max = size_max
	var ramp := Gradient.new()
	ramp.set_color(0, from)
	ramp.set_color(1, Color(to, 0.0))
	color_ramp = ramp


func _process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
