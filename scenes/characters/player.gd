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

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_crouching := false
var _facing_right := true

@onready var _visual: ColorRect = $Visual
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _collision_shape: RectangleShape2D = _collider.shape
@onready var _stand_height: float = _collision_shape.size.y


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	else:
		_coyote_timer = coyote_time

	var input_dir := Input.get_axis("move_left", "move_right")
	var want_crouch := Input.is_action_pressed("crouch")

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	_set_crouching(want_crouch)
	_apply_gravity(delta, want_crouch)
	_apply_horizontal(input_dir, delta)
	_perform_jump(input_dir)

	move_and_slide()


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
	if _is_crouching:
		_collision_shape.size.y = crouch_height
	else:
		_collision_shape.size.y = _stand_height


func _flip(facing_right: bool) -> void:
	_facing_right = facing_right
	_visual.scale.x = 1.0 if facing_right else -1.0