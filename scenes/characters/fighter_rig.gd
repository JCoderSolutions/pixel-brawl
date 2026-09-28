class_name FighterRig
extends Control

## The fighter's body drawn with native shapes (no sprites yet): head with a
## headband and an eye, torso, two arms and two legs, posed per animation.
## It is the player's "Visual" node: a 32x32 frame anchored at the feet that
## the player flips to face and tints per slot through `color`, like the
## ColorRect it replaces. Each frame it reads its parent fighter's state
## (floor, velocity, crouch, attack, hitstun, weapon) and picks a pose.
##
## Angles are in radians from hanging straight down; negative swings the
## limb forward (towards +x, the facing side).

enum Anim { IDLE, RUN, JUMP, FALL, CROUCH, ATTACK, HURT, AIM }

## Seconds for a full stride (two steps) at run speed.
const RUN_PERIOD := 0.5
## Below this horizontal speed (px/s) a grounded fighter idles.
const RUN_THRESHOLD := 20.0
const LEG_LENGTH := 10.0
## Hip to knee; the rest of the leg is the shin and the shoe.
const THIGH_LENGTH := 5.0
const SHOE_LENGTH := 2.0
const TORSO_HEIGHT := 10.0
const ARM_LENGTH := 9.0
## Upper part of the arm in the player colour; the rest is the bare forearm.
const SLEEVE_LENGTH := 4.0
const TORSO_WIDTH := 6.0
const LIMB_WIDTH := 3.0
const HEAD_SIZE := 8.0
## Endesga 32 swatches for the parts that don't take the player colour.
const SKIN := Color("e8b796")
const PANTS := Color("3a4466")
const DARK := Color("181425")

## Player colour: torso, sleeves and headband.
@export var color := Color("0099db"):
	set(value):
		color = value
		queue_redraw()
## Hit flash: every part drawn white while it lasts.
var flash := false:
	set(value):
		flash = value
		queue_redraw()
var anim := Anim.IDLE
## Holding a weapon: the gun arm stays up while moving.
var armed := false
var anim_time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(-16, -32)
	size = Vector2(32, 32)


func _process(delta: float) -> void:
	var fighter := get_parent()
	if fighter == null or not fighter.has_method("is_on_floor"):
		return
	var state := read_state(fighter)
	armed = state.armed
	var next := choose_anim(state)
	if next != anim:
		anim = next
		anim_time = 0.0
	else:
		anim_time += delta
	queue_redraw()


func _draw() -> void:
	# Pose space has its origin at the feet, the Control's bottom centre.
	draw_set_transform(Vector2(size.x / 2.0, size.y))
	for part in parts(pose(anim, anim_time, armed), color, flash):
		draw_colored_polygon(part.points, part.color)


## What the animation choice needs to know about a player fighter.
static func read_state(fighter: Node) -> Dictionary:
	var weapons = fighter.get("weapons")
	return {
		"on_floor": fighter.is_on_floor(),
		"velocity": fighter.velocity,
		"crouching": fighter.has_method("is_crouching") and fighter.is_crouching(),
		"attacking": fighter.has_method("is_attacking") and fighter.is_attacking(),
		"hurt": fighter.has_method("is_in_hitstun") and fighter.is_in_hitstun(),
		"armed": weapons != null and weapons.has_weapon(),
	}


static func choose_anim(state: Dictionary) -> Anim:
	if state.hurt:
		return Anim.HURT
	if state.attacking:
		return Anim.ATTACK
	if not state.on_floor:
		return Anim.JUMP if state.velocity.y < 0.0 else Anim.FALL
	if state.crouching:
		return Anim.CROUCH
	if absf(state.velocity.x) > RUN_THRESHOLD:
		return Anim.RUN
	return Anim.AIM if state.armed else Anim.IDLE


## Joint angles and offsets for `anim` at `t` seconds into it. `armed`
## keeps the front arm pointing the weapon forward on the move.
static func pose(anim: Anim, t: float, armed := false) -> Dictionary:
	var p := {"hip_y": -LEG_LENGTH, "bob": 0.0, "lean": 0.0,
			"leg_front": 0.08, "leg_back": -0.08, "knee_front": 0.0, "knee_back": 0.0,
			"arm_front": -0.1, "arm_back": 0.15}
	match anim:
		Anim.IDLE, Anim.AIM:
			p.bob = 1.0 if sin(t * TAU / 1.2) > 0.0 else 0.0
			if anim == Anim.AIM:
				p.arm_front = -PI / 2.0
				p.arm_back = -1.2
		Anim.RUN:
			var s := sin(t * TAU / RUN_PERIOD)
			p.leg_front = 0.75 * s
			p.leg_back = -0.75 * s
			# The leg swinging back folds at the knee.
			p.knee_front = 1.0 * maxf(s, 0.0)
			p.knee_back = 1.0 * maxf(-s, 0.0)
			p.arm_front = -0.9 * s
			p.arm_back = 0.9 * s
			p.lean = 0.15
			p.bob = -1.0 if absf(s) < 0.4 else 0.0
		Anim.JUMP:
			p.leg_front = -1.1
			p.knee_front = 1.4
			p.leg_back = 0.35
			p.knee_back = 0.5
			p.arm_front = -2.6
			p.arm_back = 2.4
		Anim.FALL:
			var wiggle := 0.25 * sin(t * 20.0)
			p.leg_front = -0.3
			p.leg_back = 0.3
			p.arm_front = -2.0 - wiggle
			p.arm_back = 2.0 + wiggle
		Anim.CROUCH:
			p.hip_y = -6.0
			p.leg_front = -1.3
			p.knee_front = 1.4
			p.leg_back = -1.25
			p.knee_back = 1.5
			p.lean = 1.0
			p.arm_front = -0.6
			p.arm_back = 0.3
		Anim.ATTACK:
			p.arm_front = -PI / 2.0
			p.arm_back = 0.6
			p.lean = 0.2
			p.leg_front = -0.3
			p.leg_back = 0.3
		Anim.HURT:
			p.lean = -0.35
			p.arm_front = 2.0
			p.arm_back = 2.6
			p.leg_front = 0.3
			p.leg_back = -0.2
	if armed and anim in [Anim.IDLE, Anim.AIM, Anim.RUN, Anim.JUMP, Anim.FALL]:
		p.arm_front = -PI / 2.0
	return p


## The body as coloured polygons in pose space (feet at the origin, facing
## +x), back to front. `team` tints torso, sleeves and headband.
static func parts(p: Dictionary, team: Color, flashing := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hip := Vector2(0.0, p.hip_y + p.bob)
	var up := Vector2.UP.rotated(p.lean)
	var shoulder := hip + up * (TORSO_HEIGHT - 1.0)
	var back := team.darkened(0.3)
	_limb(out, "leg_back", hip + Vector2(-1.5, 0), p.leg_back, p.knee_back, PANTS.darkened(0.3), DARK)
	_arm(out, "arm_back", shoulder, p.arm_back, back, SKIN.darkened(0.25))
	_add(out, "torso", _bar(hip, p.lean + PI, TORSO_HEIGHT, TORSO_WIDTH), team)
	_limb(out, "leg_front", hip + Vector2(1.5, 0), p.leg_front, p.knee_front, PANTS, DARK)
	var head := (shoulder + up * (HEAD_SIZE / 2.0 + 1.0)).round()
	var half := HEAD_SIZE / 2.0
	_add(out, "head", _box(head - Vector2(half, half), Vector2(HEAD_SIZE, HEAD_SIZE)), SKIN)
	_add(out, "headband", _box(head - Vector2(half, half - 1.0), Vector2(HEAD_SIZE, 2.0)), team.lightened(0.3))
	_add(out, "eye", _box(head + Vector2(1.0, -1.0), Vector2(2.0, 2.0)), DARK)
	_arm(out, "arm_front", shoulder, p.arm_front, team.lightened(0.18), SKIN)
	# Spread legs reach below the hips' drop: lift the body so the lowest
	# shoe corner rests on the floor line instead of sinking through it.
	var lowest := -INF
	for part in out:
		for point in part.points:
			lowest = maxf(lowest, point.y)
	if lowest > 0.0:
		for part in out:
			var points: PackedVector2Array = part.points
			for i in points.size():
				points[i].y -= lowest
			part.points = points
	if flashing:
		for part in out:
			part.color = Color.WHITE
	return out


## A leg: thigh from the hip, then shin and shoe bent `knee` rad further back.
static func _limb(out: Array[Dictionary], part_name: String, hip: Vector2, angle: float, knee: float, pants: Color, shoe: Color) -> void:
	var knee_point := hip + _dir(angle) * THIGH_LENGTH
	var shin_angle := angle + knee
	var shin := LEG_LENGTH - THIGH_LENGTH - SHOE_LENGTH
	_add(out, part_name, _bar(hip, angle, THIGH_LENGTH), pants)
	_add(out, part_name + "_shin", _bar(knee_point, shin_angle, shin), pants)
	_add(out, part_name + "_shoe", _bar(knee_point + _dir(shin_angle) * shin, shin_angle, SHOE_LENGTH), shoe)


static func _arm(out: Array[Dictionary], part_name: String, shoulder: Vector2, angle: float, sleeve: Color, skin: Color) -> void:
	_add(out, part_name, _bar(shoulder, angle, SLEEVE_LENGTH), sleeve)
	_add(out, part_name + "_forearm", _bar(shoulder + _dir(angle) * SLEEVE_LENGTH, angle, ARM_LENGTH - SLEEVE_LENGTH), skin)


static func _add(out: Array[Dictionary], part_name: String, points: PackedVector2Array, part_color: Color) -> void:
	out.append({"name": part_name, "points": points, "color": part_color})


static func _dir(angle: float) -> Vector2:
	return Vector2.DOWN.rotated(angle)


## A limb: a `width` px wide bar from `from`, `length` px along `angle`.
static func _bar(from: Vector2, angle: float, length: float, width := LIMB_WIDTH) -> PackedVector2Array:
	var along := _dir(angle) * length
	var side := _dir(angle).orthogonal() * (width / 2.0)
	return PackedVector2Array([from + side, from + along + side, from + along - side, from - side])


static func _box(corner: Vector2, box_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([corner, corner + Vector2(box_size.x, 0), corner + box_size, corner + Vector2(0, box_size.y)])
