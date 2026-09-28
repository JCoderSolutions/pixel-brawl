extends CharacterBody2D

@export var run_speed := 140.0
@export var crouch_speed_multiplier := 0.4
@export var jump_velocity := -320.0
@export var gravity := 900.0
@export var acceleration := 1800.0
@export var air_acceleration := 1200.0
@export var friction := 2000.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var crouch_height := 14.0
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

## Swap in a ScriptedInputSource, a bot or a network source to drive this
## player; by default a controlled player reads its slot's device actions.
var input_source: InputSource

@onready var _visual: ColorRect = $Visual
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _collision_shape: RectangleShape2D = _collider.shape
@onready var _stand_height: float = _collision_shape.size.y
@onready var _hurtbox_collider: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _hurtbox_shape: RectangleShape2D = _hurtbox_collider.shape
@onready var _base_color: Color = _visual.color
@onready var health: HealthComponent = $HealthComponent
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hitbox_offset: float = absf(_hitbox.position.x)


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

	if just_pressed & InputFrame.JUMP:
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	if just_pressed & InputFrame.ATTACK:
		start_attack()
	_update_attack(delta)

	_set_crouching(want_crouch)
	_apply_gravity(delta, want_crouch)
	if _hitstun_timer == 0.0:
		_apply_horizontal(input_dir, delta)
	_perform_jump(input_dir)

	move_and_slide()


func _sample_input() -> InputFrame:
	if not is_controlled or input_source == null:
		return InputFrame.new()
	return input_source.sample()


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
	_visual.color = Color.WHITE


func _end_invulnerability() -> void:
	if health.is_dead():
		return
	$Hurtbox.set_deferred("monitorable", true)
	_visual.color = _base_color


func _on_died(_source: Node) -> void:
	_attack_timer = 0.0
	_hitbox.deactivate()
	$Hurtbox.set_deferred("monitorable", false)
	_visual.color = _base_color.darkened(0.6)


func _apply_gravity(delta: float, want_crouch: bool) -> void:
	var current_gravity := gravity
	if want_crouch and is_on_floor():
		current_gravity = gravity * 1.5
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


func _set_crouching(pressed: bool) -> void:
	var want_crouch := pressed and is_on_floor()
	if want_crouch == _is_crouching:
		return
	_is_crouching = want_crouch
	_set_body_height(crouch_height if _is_crouching else _stand_height)


## Origin sits at the feet, so shapes grow upward from y = 0 and the body
## never sinks into or pops out of the floor when its height changes.
func _set_body_height(height: float) -> void:
	_collision_shape.size.y = height
	_collider.position.y = -height / 2.0
	_hurtbox_shape.size.y = height - 2.0
	_hurtbox_collider.position.y = -height / 2.0
	_visual.offset_top = -height


func _flip(facing_right: bool) -> void:
	_facing_right = facing_right
	# Mirror around the body's centre line; the default pivot is the rect's
	# left edge, which drew the body 18 px away from its collider.
	_visual.pivot_offset.x = _visual.size.x / 2.0
	_visual.scale.x = 1.0 if facing_right else -1.0
	_hitbox.position.x = _hitbox_offset if facing_right else -_hitbox_offset