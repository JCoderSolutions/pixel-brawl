extends CharacterBody2D

@export var run_speed := 140.0
@export var crouch_speed_multiplier := 0.4
@export var jump_velocity := -320.0
@export var gravity := 900.0
## Gravity is multiplied by this while falling: quick drops, floaty-free arcs.
@export var fall_gravity_multiplier := 1.4
## Letting go of jump while still rising caps the upward speed at this share
## of `jump_velocity`: tap for a hop, hold for the full jump.
@export_range(0.0, 1.0) var jump_cut := 0.45
@export var acceleration := 1800.0
@export var air_acceleration := 1200.0
@export var friction := 2000.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var crouch_height := 14.0

@export_group("Block")
## A block younger than this (seconds) with a metal blade sends bullets back.
@export var block_parry_window := 0.25
## Push a blocked hit still gives the blocker (px/s, away from the hit).
@export var block_push := 80.0
## Share of a blocked hit's damage that still gets through the guard.
@export_range(0.0, 1.0) var block_chip := 0.25
## Guard energy (0-1, Superfighters' energy bar) spent per second held...
@export var block_drain := 0.12
## ...and per point of damage stopped.
@export var block_hit_cost := 0.03
## Guard energy recovered per second while not blocking.
@export var block_regen := 0.35
## Hitstun when a hit empties the guard; no blocking again until the energy
## is back to `block_recover`.
@export var guard_break_stun := 0.8
@export_range(0.0, 1.0) var block_recover := 0.35

@export_group("Aim")
## Holding block with a gun, grenade or rocket aims instead (Superfighters):
## the fighter plants, jump/crouch turn the aim up/down at this speed
## (rad/s) and left/right picks the side.
@export var aim_speed := 2.5

@export_group("Sprint")
## Double-tap a direction (within this many seconds) to sprint while it's held.
@export var sprint_tap_window := 0.25
@export var sprint_multiplier := 1.45

@export_group("Ledge")
## Falling while pushing into a wall whose top is within reach of the hands
## hangs from it (Superfighters). Jump climbs up; crouch or away lets go.
@export var ledge_grab := true
## How far up (px) a climb from a ledge throws the fighter, as a share of
## the jump.
@export_range(0.0, 1.5) var ledge_climb := 0.9
@export var ledge_cooldown := 0.3
## Pressing crouch this many seconds before landing rolls out of the fall:
## no fall damage (Superfighters' recovery roll).
@export var recovery_window := 0.25

@export_group("Dive")
## Crouching while running this fast (share of run_speed) dives forward; in
## the air, crouch with a direction dives once per jump.
@export var dive_min_speed := 0.35
@export var dive_speed := 190.0
@export var dive_lift := -130.0
## Seconds before a dive can end: past that it ends as soon as it touches the
## floor, so it's a short hop into a roll, not a slide.
@export var dive_time := 0.12
## Seconds a dive can't be hit, from its start.
@export var dive_dodge_time := 0.3
@export var dive_cooldown := 0.4
## A dive that lands turns into a roll along the floor: low and fast, and it
## loses speed as it goes (down to roll_end_speed) so it settles naturally.
@export var roll_time := 0.25
@export var roll_speed := 170.0
@export var roll_end_speed := 60.0
## Seconds of the roll that can't be hit.
@export var roll_dodge_time := 0.15
## Only the controlled player reads input; others (dummies) don't.
@export var is_controlled := true
## Team from the match setup (0 = none). Bots leave teammates alone.
@export var team := 0
## Local slot whose `p<slot>_*` actions drive this player when no other
## input source is assigned.
@export_range(1, 4) var player_slot := 1

@export_group("Melee")
@export var hitstun := 0.25
## Short enough for a combo's next punch to land.
@export var invulnerability := 0.15
## Seconds after a jab or cross when the next press chains the combo
## (jab -> cross -> uppercut, Superfighters). A press during a swing queues it.
@export var combo_window := 0.3

@export_group("Grab")
## Pickup with empty hands next to a rival grabs them (Superfighters).
@export var grab_reach := 20.0
## Seconds before a grabbed rival slips away.
@export var grab_hold_time := 1.5
## Presses the grabbed fighter needs to break free.
@export var grab_escape_presses := 6
## Knees (attack while holding) before the rival is thrown anyway.
@export var max_knees := 3
@export var knee_damage := 7
@export var knee_cooldown := 0.3
## Throw (pickup while holding, towards the facing side or the held
## direction): launch speed, damage and the thrown fighter's stun.
@export var throw_velocity := Vector2(330.0, -230.0)
@export var throw_damage := 6
@export var throw_stun := 0.6

## Melee moves: damage scale on the punch Hitbox (the Strength power-up
## scales its base), knockback, timings (s) and where the hit lands.
const MOVES := {
	&"jab": {"scale": 1.0, "knockback": Vector2(10, -20), "startup": 0.05, "active": 0.08,
			"recovery": 0.12, "offset": Vector2(16, -17)},
	&"cross": {"scale": 1.0, "knockback": Vector2(30, -30), "startup": 0.05, "active": 0.08,
			"recovery": 0.14, "offset": Vector2(16, -17)},
	&"uppercut": {"scale": 1.6, "knockback": Vector2(200, -330), "startup": 0.08, "active": 0.1,
			"recovery": 0.25, "offset": Vector2(16, -20)},
	&"kick": {"scale": 1.3, "knockback": Vector2(290, -150), "startup": 0.08, "active": 0.1,
			"recovery": 0.22, "offset": Vector2(18, -8)},
	&"air_kick": {"scale": 1.4, "knockback": Vector2(250, -60), "startup": 0.04, "active": 0.2,
			"recovery": 0.12, "offset": Vector2(16, -10)},
}
## Chained punches step in this far (px) so the combo keeps its reach.
const COMBO_STEP := 6.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_crouching := false
var _facing_right := true
var _attack_timer := 0.0
var _hitstun_timer := 0.0
var _invulnerable_timer := 0.0
var _prev_buttons := 0
var _move := &"jab"
## 1 after a jab, 2 after a cross: what the next press in the window chains.
var _combo_step := 0
var _combo_timer := 0.0
var _attack_buffered := false
var _holding: CharacterBody2D
var _held_by: CharacterBody2D
var _grab_timer := 0.0
var _knees := 0
var _knee_timer := 0.0
var _escape_presses := 0
var _diving := false
## The rocket this fighter is riding (Grenade), if any.
var _riding: Node
var _ride_steer := 0.0
var _blocking := false
var _block_time := 0.0
var _dive_timer := 0.0
var _dive_cooldown_timer := 0.0
var _air_dive_used := false
var _rolling := false
var _roll_timer := 0.0
var _roll_dir := 1.0
var _guard := 1.0
var _guard_broken := false
## True from a jump until its rise ends or is cut; knockback launches never
## set it, so letting go of jump only shortens real jumps.
var _jump_rising := false
var _sprinting := false
var _aiming := false
## Direction and time of the last move press, for the sprint double tap.
var _last_tap_dir := 0.0
var _since_tap := INF
var _prev_move_dir := 0.0
var _hanging := false
var _ledge_timer := 0.0
var _since_crouch_press := INF
var _was_airborne := false
## Distance from the feet to the hands when they hang from a ledge.
const HANG_REACH := 29.0

## Swap in a ScriptedInputSource, a bot or a network source to drive this
## player; by default a controlled player reads its slot's device actions.
var input_source: InputSource

@onready var _visual: FighterRig = $Visual
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _collision_shape: RectangleShape2D = _collider.shape
@onready var _stand_height: float = _collision_shape.size.y
@onready var _hurtbox_collider: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _hurtbox_shape: RectangleShape2D = _hurtbox_collider.shape
@onready var _base_color: Color = _visual.color
@onready var health: HealthComponent = $HealthComponent
@onready var _hitbox: Hitbox = $Hitbox
@onready var weapons: WeaponHolder = $WeaponHolder


func _ready() -> void:
	if input_source == null and is_controlled:
		input_source = DeviceInputSource.new(player_slot)
	$Hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	else:
		_coyote_timer = coyote_time

	_hitstun_timer = max(_hitstun_timer - delta, 0.0)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer = max(_invulnerable_timer - delta, 0.0)
		if _invulnerable_timer == 0.0:
			_end_invulnerability()

	# Sample every tick, even when unable to act, so a button held through
	# hitstun doesn't read as a fresh press once control returns.
	var frame := _sample_input()
	var just_pressed := frame.buttons & ~_prev_buttons
	_prev_buttons = frame.buttons
	# Held by a rival: only mashing buttons to break free.
	if _update_held(just_pressed):
		return

	var can_act := _hitstun_timer == 0.0 and not health.is_dead()
	if not can_act:
		frame = InputFrame.new()
		just_pressed = 0
	var input_dir := frame.move_x()
	var want_crouch := frame.is_held(InputFrame.CROUCH)

	if _ride(input_dir):
		return
	_update_sprint(delta, input_dir)
	_since_crouch_press = 0.0 if just_pressed & InputFrame.CROUCH else _since_crouch_press + delta
	_ledge_timer = maxf(_ledge_timer - delta, 0.0)
	if _hanging:
		_update_hang(input_dir, just_pressed)
		return
	var had_grab := _holding != null
	_update_grab(delta, input_dir, just_pressed)
	if had_grab:
		# Planted while holding someone: attack knees, pickup throws (and
		# that press doesn't grab again right away).
		input_dir = 0.0
		just_pressed = 0
		frame = InputFrame.new()
		want_crouch = false
	_update_dive(delta, input_dir, just_pressed, can_act)
	_update_roll(delta)
	_update_aim(delta, frame)
	if _aiming:
		# Planted while aiming: jump and crouch turn the aim instead.
		input_dir = 0.0
		want_crouch = false
		just_pressed &= ~(InputFrame.JUMP | InputFrame.CROUCH | InputFrame.PICKUP)
		frame = InputFrame.create(0.0, frame.buttons & ~(InputFrame.JUMP | InputFrame.CROUCH))
	_update_block(delta, frame)
	if _blocking:
		# Planted behind the guard: no walking, no attacks.
		input_dir = 0.0
		just_pressed &= ~(InputFrame.ATTACK | InputFrame.PICKUP)
		frame = InputFrame.create(0.0, frame.buttons & ~InputFrame.ATTACK)

	if just_pressed & InputFrame.JUMP:
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# Attack punches with empty hands (crouched it kicks, in the air it kicks
	# without breaking the jump); with a weapon it uses the weapon.
	if just_pressed & InputFrame.ATTACK and not weapons.has_weapon():
		_press_attack(want_crouch)
	_update_attack(delta)
	_use_weapon(frame, just_pressed)

	_set_crouching(want_crouch)
	_apply_gravity(delta, want_crouch)
	if _hitstun_timer == 0.0 and not _diving and not _rolling:
		_apply_horizontal(input_dir, delta)
	if not _diving and not _rolling:
		_perform_jump(input_dir)
	_cut_jump(frame.is_held(InputFrame.JUMP))

	move_and_slide()
	_check_recovery_roll(input_dir)
	_try_ledge_grab(input_dir)


func _sample_input() -> InputFrame:
	if not is_controlled or input_source == null:
		return InputFrame.new()
	return input_source.sample()


## Attack uses the weapon in hand (the fire button blocks now). Automatic weapons
## fire while it is held; the rest need a fresh press per shot. Pickup grabs
## the nearest weapon, or throws the current one when nothing is in reach.
## Switch draws the next carried weapon (or the fists). Power uses the
## stored power-up.
func _use_weapon(frame: InputFrame, just_pressed: int) -> void:
	if just_pressed & InputFrame.SWITCH and not is_attacking():
		weapons.switch_next()
	if just_pressed & InputFrame.POWER:
		var receiver := PowerUpReceiver.find_on(self)
		if receiver != null:
			receiver.use_stored()
	if just_pressed & InputFrame.PICKUP and not weapons.try_pick_up():
		if weapons.has_weapon():
			weapons.throw_weapon()
		else:
			try_grab()
	if not weapons.has_weapon():
		return
	var trigger := frame.buttons if weapons.weapon.automatic else just_pressed
	if trigger & InputFrame.ATTACK:
		weapons.try_use()


## The rig (FighterRig) reads these to pick its pose.
func is_crouching() -> bool:
	return _is_crouching


func is_in_hitstun() -> bool:
	return _hitstun_timer > 0.0


## Carried away by a bazooka rocket that hit this fighter (Grenade calls it).
func start_rocket_ride(rocket: Node) -> void:
	release_grab()
	_riding = rocket
	_diving = false
	_rolling = false
	_blocking = false
	_attack_timer = 0.0
	_hitbox.deactivate()
	velocity = Vector2.ZERO


func end_rocket_ride() -> void:
	_riding = null


func is_riding() -> bool:
	return _riding != null and is_instance_valid(_riding)


func riding_rocket() -> Node:
	return _riding if is_riding() else null


## Left/right steering the rider gives the rocket: -1..1, + is clockwise.
func rocket_steer() -> float:
	return _ride_steer


## While riding, the fighter sits on the rocket and only steers it.
func _ride(input_dir: float) -> bool:
	if _riding != null and not is_instance_valid(_riding):
		_riding = null
	if _riding == null:
		return false
	_ride_steer = input_dir
	velocity = Vector2.ZERO
	global_position = _riding.global_position + Vector2(0.0, 3.0)
	return true


func is_blocking() -> bool:
	return _blocking


## Hurtbox asks before a hit lands: a guard stops melee (fists, blades,
## thrown weapons) coming from the front and pushes the blocker back a bit.
## Some damage still gets through (chip) and each hit spends guard energy;
## the hit that empties it breaks the guard and stuns the blocker.
func guard(kind: StringName, from: Vector2, damage := 0, source: Node = null) -> bool:
	if not _blocking or kind != &"melee" or not _in_front(from):
		return false
	velocity.x = (-1.0 if _facing_right else 1.0) * block_push
	_guard = maxf(_guard - damage * block_hit_cost, 0.0)
	var chip := ceili(damage * block_chip)
	if chip > 0:
		health.take_damage(chip, source)
	if _guard == 0.0:
		_break_guard()
	return true


## Guard energy, 0-1: the rig shows it while it isn't full.
func guard_energy() -> float:
	return _guard


func is_guard_broken() -> bool:
	return _guard_broken


func _break_guard() -> void:
	_blocking = false
	_guard_broken = true
	_hitstun_timer = maxf(_hitstun_timer, guard_break_stun)
	velocity.x *= 2.0


## A bullet from the front meets a fresh block with a metal blade: it goes
## back (Superfighters' perfect block).
func parry(from: Vector2) -> bool:
	return _blocking and _block_time <= block_parry_window and _in_front(from) \
			and weapons.has_weapon() and weapons.weapon.metal


func _in_front(from: Vector2) -> bool:
	if from == Vector2.INF:
		return false
	return (from.x - global_position.x) * (1.0 if _facing_right else -1.0) >= -2.0


func _update_block(delta: float, frame: InputFrame) -> void:
	if _guard_broken and _guard >= block_recover:
		_guard_broken = false
	var want := frame.is_held(InputFrame.BLOCK) and is_on_floor() and not _diving \
			and not _rolling and not _guard_broken and not _aiming and not is_attacking() \
			and _hitstun_timer == 0.0 and not health.is_dead()
	if want and not _blocking:
		_block_time = 0.0
	elif want:
		_block_time += delta
	_blocking = want
	if _blocking:
		_guard = maxf(_guard - block_drain * delta, 0.0)
		if _guard == 0.0:
			_break_guard()
	else:
		_guard = minf(_guard + block_regen * delta, 1.0)


## Mid-dive: low, fast and (at first) untouchable. FallDamage skips it.
func is_diving() -> bool:
	return _diving


## Rolling along the floor after a dive lands.
func is_rolling() -> bool:
	return _rolling


func is_attacking() -> bool:
	return _attack_timer > 0.0


## The melee move being thrown (&"jab", &"cross", &"uppercut", &"kick",
## &"air_kick"); the rig poses it.
func attack_move() -> StringName:
	return _move


## Starts the next punch of the combo (or a jab); tests and scripts call it.
func start_attack() -> void:
	if is_attacking() or health.is_dead():
		return
	_begin_move(_next_punch())


func _press_attack(crouching: bool) -> void:
	if health.is_dead():
		return
	if is_attacking():
		_attack_buffered = _move == &"jab" or _move == &"cross"
		return
	_begin_move(_next_move(crouching))


func _next_move(crouching: bool) -> StringName:
	if not is_on_floor():
		return &"air_kick"
	if crouching:
		return &"kick"
	return _next_punch()


## Jab, or the next punch of the combo while its window is open.
func _next_punch() -> StringName:
	if _combo_timer > 0.0:
		if _combo_step == 1:
			return &"cross"
		if _combo_step == 2:
			return &"uppercut"
	return &"jab"


func _begin_move(move: StringName) -> void:
	var m: Dictionary = MOVES[move]
	_move = move
	_combo_step = 1 if move == &"jab" else (2 if move == &"cross" else 0)
	_combo_timer = 0.0
	_attack_buffered = false
	_attack_timer = m.startup + m.active + m.recovery
	var facing := 1.0 if _facing_right else -1.0
	_hitbox.damage_scale = m.scale
	_hitbox.knockback = m.knockback
	_hitbox.position = Vector2(m.offset.x * facing, m.offset.y)
	if move == &"cross" or move == &"uppercut":
		move_and_collide(Vector2(facing * COMBO_STEP, 0.0))


## Hit window opens after startup and closes before recovery, so a swing
## reads as wind-up -> strike -> follow-through. A press queued during a jab
## or cross chains the next punch as soon as the swing ends.
func _update_attack(delta: float) -> void:
	if not is_attacking():
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		return
	var m: Dictionary = MOVES[_move]
	_attack_timer = max(_attack_timer - delta, 0.0)
	var in_active_window: bool = _attack_timer <= m.active + m.recovery \
			and _attack_timer > m.recovery
	if in_active_window and not _hitbox.is_active():
		_hitbox.direction = 1.0 if _facing_right else -1.0
		_hitbox.activate()
	elif not in_active_window and _hitbox.is_active():
		_hitbox.deactivate()
	if _attack_timer == 0.0:
		_combo_timer = combo_window if _combo_step > 0 else 0.0
		if _attack_buffered and is_on_floor() and _hitstun_timer == 0.0:
			_begin_move(_next_punch())


func is_grabbing() -> bool:
	return _holding != null and is_instance_valid(_holding)


func is_held() -> bool:
	return _held_by != null and is_instance_valid(_held_by)


## Grabs the closest rival right in front, if any (pickup with empty hands).
func try_grab() -> bool:
	if not is_on_floor() or is_attacking() or _blocking or _diving or _rolling \
			or is_grabbing() or health.is_dead():
		return false
	var target := _grab_target()
	if target == null:
		return false
	_holding = target
	_grab_timer = grab_hold_time
	_knees = 0
	_knee_timer = 0.0
	target.start_held(self)
	return true


## Whether this fighter can be grabbed right now.
func can_be_grabbed() -> bool:
	return not health.is_dead() and not is_riding() and not is_held() and not is_grabbing() \
			and not _diving and not _rolling


func _grab_target() -> CharacterBody2D:
	var facing := 1.0 if _facing_right else -1.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(grab_reach, 24.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * (8.0 + grab_reach / 2.0), -15.0))
	query.collision_mask = collision_layer
	query.exclude = [get_rid()]
	var best: CharacterBody2D
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := hit.collider as CharacterBody2D
		if body == null or not body.has_method("can_be_grabbed") or not body.can_be_grabbed():
			continue
		if team != 0 and body.team == team:
			continue
		if best == null or absf(body.global_position.x - global_position.x) < absf(best.global_position.x - global_position.x):
			best = body
	return best


## Called by the grabber: this fighter hangs in front of it until thrown,
## let go or it breaks free.
func start_held(by: CharacterBody2D) -> void:
	_held_by = by
	_escape_presses = 0
	_attack_timer = 0.0
	_hitbox.deactivate()
	_blocking = false
	_diving = false
	_rolling = false
	velocity = Vector2.ZERO


func _update_held(just_pressed: int) -> bool:
	if _held_by == null:
		return false
	if not is_instance_valid(_held_by) or _held_by._holding != self:
		_held_by = null
		return false
	if just_pressed != 0:
		_escape_presses += 1
		if _escape_presses >= _held_by.grab_escape_presses:
			_held_by.release_grab(true)
			return false
	var facing := 1.0 if _held_by._facing_right else -1.0
	global_position = _held_by.global_position + Vector2(facing * 14.0, -2.0)
	velocity = Vector2.ZERO
	return true


func _update_grab(delta: float, input_dir: float, just_pressed: int) -> void:
	if _holding == null:
		return
	if not is_grabbing() or health.is_dead() or _hitstun_timer > 0.0 or _holding.health.is_dead():
		release_grab()
		return
	_grab_timer -= delta
	_knee_timer = maxf(_knee_timer - delta, 0.0)
	var facing := 1.0 if _facing_right else -1.0
	if just_pressed & InputFrame.PICKUP:
		var dir := signf(input_dir) if input_dir != 0.0 else facing
		if dir != facing:
			_flip(dir > 0.0)
		_throw(dir)
	elif just_pressed & InputFrame.ATTACK and _knee_timer == 0.0:
		_knees += 1
		_knee_timer = knee_cooldown
		var damage := roundi(knee_damage * _hitbox.damage / 10.0)
		_holding.get_node("Hurtbox").receive_hit(damage, Vector2.ZERO, self, &"knee")
		if _knees >= max_knees:
			_throw(facing)
	elif _grab_timer <= 0.0:
		release_grab(true)


func _throw(dir: float) -> void:
	var victim := _holding
	_holding = null
	if not is_instance_valid(victim):
		return
	victim._held_by = null
	victim.get_node("Hurtbox").receive_hit(throw_damage, Vector2(dir * throw_velocity.x, throw_velocity.y), self, &"throw")
	victim._hitstun_timer = maxf(victim._hitstun_timer, throw_stun)


## Lets go of the held rival; `pushed` shoves both apart (it broke free or
## slipped away), and a rival breaking free leaves the grabber reeling.
func release_grab(pushed := false) -> void:
	var victim := _holding
	_holding = null
	if not is_instance_valid(victim):
		return
	victim._held_by = null
	if pushed:
		var facing := 1.0 if _facing_right else -1.0
		victim.velocity.x = facing * 140.0
		velocity.x = -facing * 140.0
		if victim._escape_presses >= grab_escape_presses:
			_hitstun_timer = maxf(_hitstun_timer, 0.3)


func _on_hit_received(_damage: int, knockback: Vector2, _source: Node) -> void:
	velocity = knockback
	_hitstun_timer = hitstun
	_invulnerable_timer = invulnerability
	$Hurtbox.set_deferred("monitorable", false)
	_visual.flash = true


func _end_invulnerability() -> void:
	if health.is_dead():
		return
	$Hurtbox.set_deferred("monitorable", true)
	_visual.flash = false


func _on_died(_source: Node) -> void:
	release_grab()
	_attack_timer = 0.0
	_hitbox.deactivate()
	$Hurtbox.set_deferred("monitorable", false)
	_visual.flash = false
	_visual.color = _base_color.darkened(0.6)
	# Dead hands let go of everything carried; deferred because physics
	# bodies can't be added from inside the hit's physics callback.
	weapons.drop_all.call_deferred()


func _apply_gravity(delta: float, want_crouch: bool) -> void:
	var current_gravity := gravity
	if want_crouch and is_on_floor():
		current_gravity = gravity * 1.5
	elif velocity.y > 0.0:
		current_gravity = gravity * fall_gravity_multiplier
	velocity.y += current_gravity * delta


func _apply_horizontal(input_dir: float, delta: float) -> void:
	var target_speed := input_dir * run_speed * (sprint_multiplier if _sprinting else 1.0)
	if _is_crouching:
		target_speed *= crouch_speed_multiplier

	var current_accel := acceleration if is_on_floor() else air_acceleration
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if input_dir > 0.0 and not _facing_right:
		_flip(true)
	elif input_dir < 0.0 and _facing_right:
		_flip(false)


func _perform_jump(input_dir: float) -> void:
	if _coyote_timer > 0.0 and _jump_buffer_timer > 0.0:
		if not _is_crouching or input_dir != 0.0:
			velocity.y = jump_velocity
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			_jump_rising = true


## Variable height: releasing jump mid-rise trims the upward speed once.
func _cut_jump(jump_held: bool) -> void:
	if not _jump_rising:
		return
	if velocity.y >= 0.0:
		_jump_rising = false
	elif not jump_held:
		velocity.y = maxf(velocity.y, jump_velocity * jump_cut)
		_jump_rising = false


func _set_crouching(pressed: bool) -> void:
	var want_crouch := (pressed and is_on_floor()) or _diving or _rolling
	if want_crouch == _is_crouching:
		return
	_is_crouching = want_crouch
	_set_body_height(crouch_height if _is_crouching else _stand_height)


## Superfighters dive: crouch while running to throw yourself forward (or
## crouch with a direction in the air, once per jump). It keeps its momentum
## (no steering, no jumping) until it lands, then rolls on along the floor.
func _update_dive(delta: float, input_dir: float, just_pressed: int, can_act: bool) -> void:
	_dive_cooldown_timer = maxf(_dive_cooldown_timer - delta, 0.0)
	if is_on_floor() and not _diving:
		_air_dive_used = false
	if _diving:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		if _dive_timer == 0.0 and is_on_floor():
			_diving = false
			_dive_cooldown_timer = dive_cooldown
			_start_roll(signf(velocity.x) if velocity.x != 0.0 else _roll_dir)
		return
	if not can_act or not just_pressed & InputFrame.CROUCH or input_dir == 0.0 \
			or _dive_cooldown_timer > 0.0 or is_attacking() or _rolling:
		return
	if is_on_floor():
		var running := absf(velocity.x) >= run_speed * dive_min_speed \
				and signf(velocity.x) == signf(input_dir)
		if running:
			_start_dive(signf(input_dir), dive_lift)
	elif not _air_dive_used:
		_air_dive_used = true
		_start_dive(signf(input_dir), minf(velocity.y, 0.0))


func _start_dive(dir: float, lift: float) -> void:
	_diving = true
	_dive_timer = dive_time
	_roll_dir = dir
	velocity = Vector2(dir * dive_speed, lift)
	_flip(dir > 0.0)
	_invulnerable_timer = maxf(_invulnerable_timer, dive_dodge_time)
	$Hurtbox.set_deferred("monitorable", false)


func _start_roll(dir: float) -> void:
	_rolling = true
	_roll_timer = roll_time
	_roll_dir = dir
	_invulnerable_timer = maxf(_invulnerable_timer, roll_dodge_time)
	$Hurtbox.set_deferred("monitorable", false)


## The roll slows down along the floor; rolling off a ledge just falls.
func _update_roll(delta: float) -> void:
	if not _rolling:
		return
	_roll_timer = maxf(_roll_timer - delta, 0.0)
	if _roll_timer == 0.0 or not is_on_floor() or health.is_dead() or _hitstun_timer > 0.0:
		_rolling = false
		return
	velocity.x = _roll_dir * lerpf(roll_end_speed, roll_speed, _roll_timer / roll_time)


func is_aiming() -> bool:
	return _aiming


## Manual aim, radians off the facing side (negative = up); the rig reads it.
func aim_angle() -> float:
	return weapons.aim_angle


func _can_aim() -> bool:
	return weapons.has_weapon() and (weapons.weapon.is_ranged() or weapons.weapon is GrenadeData)


func _update_aim(delta: float, frame: InputFrame) -> void:
	var want := frame.is_held(InputFrame.BLOCK) and _can_aim() and is_on_floor() \
			and not _diving and not _rolling and not is_grabbing() and not health.is_dead()
	if want:
		_aiming = true
		var turn := (1.0 if frame.is_held(InputFrame.CROUCH) else 0.0) \
				- (1.0 if frame.is_held(InputFrame.JUMP) else 0.0)
		weapons.aim_angle += turn * aim_speed * delta
		var dir := signf(frame.move_x())
		if dir != 0.0 and (dir > 0.0) != _facing_right:
			_flip(dir > 0.0)
	elif _aiming:
		_aiming = false
		weapons.aim_angle = 0.0
	weapons.aiming = _aiming


func is_sprinting() -> bool:
	return _sprinting


## Double tap: a second press of the same direction soon after the first
## sprints until the direction is let go, reversed or crouched out of.
func _update_sprint(delta: float, input_dir: float) -> void:
	var dir := signf(input_dir)
	_since_tap += delta
	if dir != 0.0 and _prev_move_dir == 0.0:
		if dir == _last_tap_dir and _since_tap <= sprint_tap_window:
			_sprinting = true
		_last_tap_dir = dir
		_since_tap = 0.0
	if dir == 0.0 or dir != _last_tap_dir or _is_crouching:
		_sprinting = false
	_prev_move_dir = dir


func is_hanging() -> bool:
	return _hanging


## After moving: falling into a wall while pushing towards it, with the
## wall's top edge at hand height and room above it, hangs from that edge.
func _try_ledge_grab(input_dir: float) -> void:
	if not ledge_grab or _hanging or is_on_floor() or velocity.y < 0.0 or input_dir == 0.0 \
			or _ledge_timer > 0.0 or _diving or _rolling or is_attacking() or is_grabbing() \
			or _hitstun_timer > 0.0 or health.is_dead() or is_riding():
		return
	var dir := signf(input_dir)
	var space := get_world_2d().direct_space_state
	var half := _collision_shape.size.x / 2.0
	# The wall at chest height, right in front.
	var chest := global_position + Vector2(0.0, -20.0)
	var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(chest, chest + Vector2(dir * (half + 4.0), 0.0), 1, [get_rid()]))
	if wall.is_empty():
		return
	# Its top: looking down just past the wall face, from above the hands.
	# Walls are stacks of separate 16 px blocks: a probe that starts inside one
	# must count it (hit_from_inside), or the seam with the block below reads
	# as a ledge in the middle of the wall.
	var probe_x: float = wall.position.x + dir * 3.0
	var from := Vector2(probe_x, global_position.y - HANG_REACH - 8.0)
	var down := PhysicsRayQueryParameters2D.create(from, Vector2(probe_x, chest.y + 2.0), 1, [get_rid()])
	down.hit_from_inside = true
	var top := space.intersect_ray(down)
	if top.is_empty() or top.normal.y > -0.7:
		return
	var ledge_y: float = top.position.y
	# Room to climb onto it: nothing solid right above the edge.
	var above := Vector2(probe_x, ledge_y - 2.0)
	var up := PhysicsRayQueryParameters2D.create(above, above + Vector2(0.0, -24.0), 1, [get_rid()])
	up.hit_from_inside = true
	if not space.intersect_ray(up).is_empty():
		return
	_hanging = true
	_sprinting = false
	_jump_rising = false
	velocity = Vector2.ZERO
	_flip(dir > 0.0)
	global_position = Vector2(wall.position.x - dir * half, ledge_y + HANG_REACH)


## Hanging: jump climbs over the edge, crouch or pushing away lets go.
func _update_hang(input_dir: float, just_pressed: int) -> void:
	var facing := 1.0 if _facing_right else -1.0
	if _hitstun_timer > 0.0 or health.is_dead():
		_hanging = false
		return
	if just_pressed & InputFrame.JUMP:
		_hanging = false
		_ledge_timer = ledge_cooldown
		velocity = Vector2(facing * 70.0, jump_velocity * ledge_climb)
		_jump_rising = false
	elif just_pressed & InputFrame.CROUCH or signf(input_dir) == -facing:
		_hanging = false
		_ledge_timer = ledge_cooldown
	else:
		velocity = Vector2.ZERO
		return
	move_and_slide()


## Landing from a fall with crouch pressed just before: roll out of it
## (FallDamage skips rolls, like dives).
func _check_recovery_roll(input_dir: float) -> void:
	var airborne := not is_on_floor()
	if _was_airborne and not airborne and _since_crouch_press <= recovery_window \
			and not _diving and not _rolling and not health.is_dead() and _hitstun_timer == 0.0:
		var dir := signf(input_dir) if input_dir != 0.0 else (1.0 if _facing_right else -1.0)
		_start_roll(dir)
		_since_crouch_press = INF
	_was_airborne = airborne


## Origin sits at the feet, so shapes grow upward from y = 0 and the body
## never sinks into or pops out of the floor when its height changes.
func _set_body_height(height: float) -> void:
	_collision_shape.size.y = height
	_collider.position.y = -height / 2.0
	_hurtbox_shape.size.y = height - 2.0
	_hurtbox_collider.position.y = -height / 2.0


func _flip(facing_right: bool) -> void:
	_facing_right = facing_right
	# Mirror around the body's centre line; the default pivot is the rect's
	# left edge, which drew the body 18 px away from its collider.
	_visual.pivot_offset.x = _visual.size.x / 2.0
	_visual.scale.x = 1.0 if facing_right else -1.0
	_hitbox.position.x = absf(_hitbox.position.x) * (1.0 if facing_right else -1.0)
	weapons.facing = 1 if facing_right else -1