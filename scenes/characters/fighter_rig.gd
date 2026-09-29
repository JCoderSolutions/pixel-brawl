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

## VICTORY is never picked from a fighter's state: screens set it.
enum Anim { IDLE, RUN, JUMP, FALL, CROUCH, ATTACK, HURT, AIM, VICTORY, DIVE, RIDE, BLOCK }

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
## The character (FighterLook): pants, skin and headband. Null keeps the
## default look with a headband in a lighter `color`.
var look: FighterLook:
	set(value):
		look = value
		queue_redraw()
## Team marker over the head; transparent (no team) hides it.
var team_color := Color(0, 0, 0, 0):
	set(value):
		team_color = value
		queue_redraw()
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
		# Not on a fighter (winner screen, menus): play `anim` as set.
		anim_time += delta
		queue_redraw()
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
	var frame := sprite_frame()
	if frame != null:
		_draw_sprite(frame)
		return
	for part in parts(pose(anim, anim_time, armed), color, flash, look, team_color):
		draw_colored_polygon(part.points, part.color)


## The character's sprite for the current animation and time, or null to
## draw native shapes (no SpriteFrames on the look, or not this animation).
func sprite_frame() -> Texture2D:
	if look == null or look.frames == null:
		return null
	var frames := look.frames
	var sprite_anim := anim_name(anim)
	if not frames.has_animation(sprite_anim) or frames.get_frame_count(sprite_anim) == 0:
		return null
	var count := frames.get_frame_count(sprite_anim)
	var index := floori(anim_time * frames.get_animation_speed(sprite_anim))
	index = posmod(index, count) if frames.get_animation_loop(sprite_anim) else mini(index, count - 1)
	return frames.get_frame_texture(sprite_anim, index)


## SpriteFrames animation name for `which`: "idle", "run", "jump"...
static func anim_name(which: Anim) -> StringName:
	return StringName(Anim.keys()[which].to_lower())


## A sprite frame stands on the feet line, centred; the hit flash washes it
## out and the team marker floats over it like over the shapes.
func _draw_sprite(frame: Texture2D) -> void:
	var frame_size := frame.get_size()
	var tint := Color(4, 4, 4) if flash else Color.WHITE
	draw_texture(frame, Vector2(-frame_size.x / 2.0, -frame_size.y).round(), tint)
	if team_color.a > 0.0:
		var tip := Vector2(0.0, -frame_size.y - 1.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -3), tip + Vector2(2, -3), tip]), team_color)


## What the animation choice needs to know about a player fighter.
static func read_state(fighter: Node) -> Dictionary:
	var weapons = fighter.get("weapons")
	return {
		"on_floor": fighter.is_on_floor(),
		"velocity": fighter.velocity,
		"crouching": fighter.has_method("is_crouching") and fighter.is_crouching(),
		"attacking": fighter.has_method("is_attacking") and fighter.is_attacking(),
		"hurt": fighter.has_method("is_in_hitstun") and fighter.is_in_hitstun(),
		"diving": fighter.has_method("is_diving") and fighter.is_diving(),
		"riding": fighter.has_method("is_riding") and fighter.is_riding(),
		"blocking": fighter.has_method("is_blocking") and fighter.is_blocking(),
		"armed": weapons != null and weapons.has_weapon(),
	}


static func choose_anim(state: Dictionary) -> Anim:
	if state.get("riding", false):
		return Anim.RIDE
	if state.hurt:
		return Anim.HURT
	if state.get("diving", false):
		return Anim.DIVE
	if state.get("blocking", false):
		return Anim.BLOCK
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
	var p := {"hip_y": -LEG_LENGTH, "hip_x": 0.0, "bob": 0.0, "lean": 0.0,
			"leg_front": 0.08, "leg_back": -0.08, "knee_front": 0.0, "knee_back": 0.0,
			"arm_front": -0.1, "arm_back": 0.15, "shoulder_spread": 0.0}
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
		Anim.DIVE:
			# Flat out, arms first, legs trailing.
			p.hip_x = -3.0
			p.hip_y = -6.0
			p.lean = 1.1
			p.arm_front = -1.3
			p.arm_back = -1.5
			p.leg_front = 1.0
			p.leg_back = 1.3
		Anim.RIDE:
			# Crouched on the rocket, arms out for balance.
			var sway := 0.2 * sin(t * 12.0)
			p.hip_y = -6.0
			p.leg_front = -1.3
			p.knee_front = 1.4
			p.leg_back = -1.25
			p.knee_back = 1.5
			p.lean = 0.35
			p.arm_front = -1.7 + sway
			p.arm_back = 1.7 + sway
		Anim.BLOCK:
			# Guard up: forearms raised in front of the face.
			p.lean = -0.1
			p.arm_front = -2.3
			p.arm_back = -1.9
			p.leg_front = -0.25
			p.leg_back = 0.25
		Anim.VICTORY:
			var pump := sin(t * 10.0)
			# Arms up in a V from spread shoulders, beside the head.
			p.shoulder_spread = 4.0
			p.arm_front = -2.6 - 0.15 * pump
			p.arm_back = 2.6 + 0.15 * pump
			p.bob = -2.0 if sin(t * 6.0) > 0.0 else 0.0
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
static func parts(p: Dictionary, team: Color, flashing := false, character: FighterLook = null, marker := Color(0, 0, 0, 0)) -> Array[Dictionary]:
	var pants := character.pants if character != null else PANTS
	var skin := character.skin if character != null else SKIN
	var band := character.band if character != null else team.lightened(0.3)
	var out: Array[Dictionary] = []
	var hip := Vector2(p.hip_x, p.hip_y + p.bob)
	var up := Vector2.UP.rotated(p.lean)
	var shoulder := hip + up * (TORSO_HEIGHT - 1.0)
	var back := team.darkened(0.3)
	_limb(out, "leg_back", hip + Vector2(-1.5, 0), p.leg_back, p.knee_back, pants.darkened(0.3), DARK)
	var spread := Vector2(p.shoulder_spread, 0.0)
	_arm(out, "arm_back", shoulder - spread, p.arm_back, back, skin.darkened(0.25))
	_add(out, "torso", _bar(hip, p.lean + PI, TORSO_HEIGHT, TORSO_WIDTH), team)
	_limb(out, "leg_front", hip + Vector2(1.5, 0), p.leg_front, p.knee_front, pants, DARK)
	var head := (shoulder + up * (HEAD_SIZE / 2.0 + 1.0)).round()
	var half := HEAD_SIZE / 2.0
	_add(out, "head", _box(head - Vector2(half, half), Vector2(HEAD_SIZE, HEAD_SIZE)), skin)
	_add(out, "headband", _box(head - Vector2(half, half - 1.0), Vector2(HEAD_SIZE, 2.0)), band)
	if marker.a > 0.0:
		# Team marker: a small arrow just over the head.
		var tip := head - Vector2(0.0, half + 1.0)
		_add(out, "team_marker", PackedVector2Array([tip + Vector2(-2, -3), tip + Vector2(2, -3), tip]), marker)
	_add(out, "eye", _box(head + Vector2(1.0, -1.0), Vector2(2.0, 2.0)), DARK)
	_arm(out, "arm_front", shoulder + spread, p.arm_front, team.lightened(0.18), skin)
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
