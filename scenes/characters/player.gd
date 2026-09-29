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

@export_group("Dive")
## Crouching while running this fast (share of run_speed) dives forward.
@export var dive_min_speed := 0.8
@export var dive_speed := 250.0
@export var dive_lift := -150.0
## Seconds before a dive can end (it lasts until the fighter lands).
@export var dive_time := 0.4
## Seconds a dive can't be hit, from its start.
@export var dive_dodge_time := 0.3
@export var dive_cooldown := 0.4
## Only the controlled player reads input; others (dummies) don't.
@export var is_controlled := true
## Local slot whose `p<slot>_*` actions drive this player when no other
## input source is assigned.
@export_range(1, 4) var player_slot := 1

@export_group("Melee")
@export var attack_startup := 0.05
@export var attack_active := 0.1
@export var attack_recovery := 0.15
@export var hitstun := 0.25
@export var invulnerability := 0.3

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_crouching := false
var _facing_right := true
var _attack_timer := 0.0
var _hitstun_timer := 0.0
var _invulnerable_timer := 0.0
var _prev_buttons := 0
var _diving := false
## The rocket this fighter is riding (Grenade), if any.
var _riding: Node
var _ride_steer := 0.0
var _dive_timer := 0.0
var _dive_cooldown_timer := 0.0
## True from a jump until its rise ends or is cut; knockback launches never
## set it, so letting go of jump only shortens real jumps.
var _jump_rising := false

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
@onready var _hitbox_offset: float = absf(_hitbox.position.x)
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

	var can_act := _hitstun_timer == 0.0 and not health.is_dead()
	if not can_act:
		frame = InputFrame.new()
		just_pressed = 0
	var input_dir := frame.move_x()
	var want_crouch := frame.is_held(InputFrame.CROUCH)

	if _ride(input_dir):
		return
	_update_dive(delta, input_dir, just_pressed, can_act)

	if just_pressed & InputFrame.JUMP:
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# Attack punches with empty hands; with a weapon it uses the weapon.
	if just_pressed & InputFrame.ATTACK and not weapons.has_weapon():
		start_attack()
	_update_attack(delta)
	_use_weapon(frame, just_pressed)

	_set_crouching(want_crouch)
	_apply_gravity(delta, want_crouch)
	if _hitstun_timer == 0.0 and not _diving:
		_apply_horizontal(input_dir, delta)
	if not _diving:
		_perform_jump(input_dir)
	_cut_jump(frame.is_held(InputFrame.JUMP))

	move_and_slide()


func _sample_input() -> InputFrame:
	if not is_controlled or input_source == null:
		return InputFrame.new()
	return input_source.sample()


## Attack (or the fire button) uses the weapon in hand. Automatic weapons
## fire while it is held; the rest need a fresh press per shot. Pickup grabs
## the nearest weapon, or throws the current one when nothing is in reach.
func _use_weapon(frame: InputFrame, just_pressed: int) -> void:
	if just_pressed & InputFrame.PICKUP and not weapons.try_pick_up():
		weapons.throw_weapon()
	if not weapons.has_weapon():
		return
	var trigger := frame.buttons if weapons.weapon.automatic else just_pressed
	if trigger & (InputFrame.ATTACK | InputFrame.FIRE):
		weapons.try_use()


## The rig (FighterRig) reads these to pick its pose.
func is_crouching() -> bool:
	return _is_crouching


func is_in_hitstun() -> bool:
	return _hitstun_timer > 0.0


## Carried away by a bazooka rocket that hit this fighter (Grenade calls it).
func start_rocket_ride(rocket: Node) -> void:
	_riding = rocket
	_diving = false
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


## Mid-dive: low, fast and (at first) untouchable. FallDamage skips it.
func is_diving() -> bool:
	return _diving


func is_attacking() -> bool:
	return _attack_timer > 0.0


func start_attack() -> void:
	if is_attacking() or health.is_dead():
		return
	_attack_timer = attack_startup + attack_active + attack_recovery


## Hit window opens after startup and closes before recovery, so a swing
## reads as wind-up -> strike -> follow-through.
func _update_attack(delta: float) -> void:
	if not is_attacking():
		return
	_attack_timer = max(_attack_timer - delta, 0.0)
	var in_active_window := _attack_timer <= attack_active + attack_recovery \
			and _attack_timer > attack_recovery
	if in_active_window and not _hitbox.is_active():
		_hitbox.direction = 1.0 if _facing_right else -1.0
		_hitbox.activate()
	elif not in_active_window and _hitbox.is_active():
		_hitbox.deactivate()


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
	_attack_timer = 0.0
	_hitbox.deactivate()
	$Hurtbox.set_deferred("monitorable", false)
	_visual.flash = false
	_visual.color = _base_color.darkened(0.6)
	# Dead hands let go; deferred because physics bodies can't be added
	# from inside the hit's physics callback.
	weapons.drop.call_deferred()


func _apply_gravity(delta: float, want_crouch: bool) -> void:
	var current_gravity := gravity
	if want_crouch and is_on_floor():
		current_gravity = gravity * 1.5
	elif velocity.y > 0.0:
		current_gravity = gravity * fall_gravity_multiplier
	velocity.y += current_gravity * delta


func _apply_horizontal(input_dir: float, delta: float) -> void:
	var target_speed := input_dir * run_speed
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
	var want_crouch := (pressed and is_on_floor()) or _diving
	if want_crouch == _is_crouching:
		return
	_is_crouching = want_crouch
	_set_body_height(crouch_height if _is_crouching else _stand_height)


## Superfighters dive: crouch while running to throw yourself forward. It
## keeps its momentum (no steering, no jumping) until it lands.
func _update_dive(delta: float, input_dir: float, just_pressed: int, can_act: bool) -> void:
	_dive_cooldown_timer = maxf(_dive_cooldown_timer - delta, 0.0)
	if _diving:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		if _dive_timer == 0.0 and is_on_floor():
			_diving = false
			_dive_cooldown_timer = dive_cooldown
		return
	var running := absf(velocity.x) >= run_speed * dive_min_speed and input_dir != 0.0
	if can_act and just_pressed & InputFrame.CROUCH and running and is_on_floor() \
			and _dive_cooldown_timer == 0.0 and not is_attacking():
		_diving = true
		_dive_timer = dive_time
		velocity = Vector2(signf(velocity.x) * dive_speed, dive_lift)
		_invulnerable_timer = maxf(_invulnerable_timer, dive_dodge_time)
		$Hurtbox.set_deferred("monitorable", false)


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
	_hitbox.position.x = _hitbox_offset if facing_right else -_hitbox_offset
	weapons.facing = 1 if facing_right else -1