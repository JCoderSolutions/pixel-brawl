extends SceneTree

## Headless tests for the dive (Superfighters): crouching while running
## throws the fighter forward, low and briefly untouchable, and it lands into
## a short roll that slows down; crouching with a direction in the air dives
## once per jump; standing crouch stays a crouch; a dive over a ledge lands without fall
## damage; the rig shows it.
## Run: godot --headless --path . -s scripts/test_dive.gd

const PROJECTILE_SCENE := preload("res://scenes/items/projectile.tscn")
const PISTOL := preload("res://scripts/weapons/data/pistol.tres")
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_running_crouch_dives()
	await _test_standing_crouch_does_not_dive()
	await _test_dive_dodges_hits()
	await _test_dive_skips_fall_damage()
	await _test_dive_lands_into_roll()
	await _test_air_dive_once_per_jump()
	await _test_dive_dodges_bullets()
	print("OK: running dive, roll on landing, air dive, standing crouch, dodge window, bullets flying through a dive and roll, and no fall damage after a dive verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


## Floor spans [left, right] at y = 0; returns [stage, player].
func _stage(frames: Array[InputFrame], left := -400.0, right := 1200.0, start := Vector2.ZERO) -> Array:
	var stage := Node2D.new()
	root.add_child(stage)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(right - left, 20)
	floor_body.add_child(shape)
	floor_body.position = Vector2((left + right) / 2.0, 10)
	stage.add_child(floor_body)
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.position = start
	player.input_source = ScriptedInputSource.new(frames)
	stage.add_child(player)
	return [stage, player]


func _hold(frames: Array[InputFrame], count: int, move := 0.0, buttons := 0) -> void:
	for i in count:
		frames.append(InputFrame.create(move, buttons))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _test_running_crouch_dives() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 30, 1.0)
	_hold(frames, 40, 1.0, InputFrame.CROUCH)
	var s := _stage(frames)
	var player: CharacterBody2D = s[1]
	await _frames(41)
	var from := player.position.x
	await _frames(2)
	_check(player.is_diving(), "crouching while running starts a dive")
	_check(player.velocity.x > player.run_speed, "the dive is faster than running (%.0f)" % player.velocity.x)
	_check(player.is_crouching(), "and keeps the body low")
	var rig: FighterRig = player.get_node("Visual")
	await process_frame
	_check(rig.anim == FighterRig.Anim.DIVE, "the rig dives (%s)" % FighterRig.Anim.keys()[rig.anim])
	await _frames(40)
	_check(not player.is_diving(), "the dive ends")
	_check(player.position.x - from > 60.0, "and covers ground (%.0f px)" % (player.position.x - from))
	s[0].queue_free()
	await process_frame


func _test_standing_crouch_does_not_dive() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 30, 0.0, InputFrame.CROUCH)
	var s := _stage(frames)
	var player: CharacterBody2D = s[1]
	var dove := false
	for i in 40:
		await physics_frame
		dove = dove or player.is_diving()
	_check(not dove, "crouching while standing is just a crouch")
	_check(player.is_crouching(), "and crouches")
	s[0].queue_free()
	await process_frame


func _test_dive_dodges_hits() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 30, 1.0)
	_hold(frames, 20, 1.0, InputFrame.CROUCH)
	var s := _stage(frames)
	var player: CharacterBody2D = s[1]
	await _frames(43)
	_check(player.is_diving(), "diving")
	await _frames(1)
	var hurtbox: Hurtbox = player.get_node("Hurtbox")
	_check(not hurtbox.monitorable, "hits can't find a diving fighter")
	await _frames(40)
	_check(hurtbox.monitorable, "they can again once the dive is over")
	s[0].queue_free()
	await process_frame


## The same 10-tile drop hurts from a walk-off and not at the end of a dive.
func _test_dive_skips_fall_damage() -> void:
	for dive in [false, true]:
		var frames: Array[InputFrame] = []
		_hold(frames, 10)
		_hold(frames, 12, 1.0)
		if dive:
			_hold(frames, 40, 1.0, InputFrame.CROUCH)
		else:
			_hold(frames, 40, 1.0)
		var s := _stage(frames, -400.0, 40.0)
		var player: CharacterBody2D = s[1]
		var low := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(800, 20)
		low.add_child(shape)
		low.position = Vector2(400, 170)
		s[0].add_child(low)
		await _frames(150)
		_check(player.is_on_floor() and player.position.y > 150.0, "landed on the low floor (%s)" % player.position)
		var hurt: bool = player.health.current_health < player.health.max_health
		if dive:
			_check(not hurt, "a dive lands without fall damage (hp %d)" % player.health.current_health)
		else:
			_check(hurt, "walking off the same drop hurts (hp %d)" % player.health.current_health)
		s[0].queue_free()
		await process_frame


func _test_dive_lands_into_roll() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 20, 1.0)
	_hold(frames, 1, 1.0, InputFrame.CROUCH)
	_hold(frames, 80)
	var s := _stage(frames)
	var player: CharacterBody2D = s[1]
	var rig: FighterRig = player.get_node("Visual")
	var rolled := false
	var rolled_anim := false
	var roll_speed := 0.0
	var from := 0.0
	for i in 110:
		await physics_frame
		if i == 30:
			from = player.position.x
		if player.is_rolling():
			rolled = true
			roll_speed = maxf(roll_speed, absf(player.velocity.x))
			await process_frame
			rolled_anim = rolled_anim or rig.anim == FighterRig.Anim.ROLL
	_check(rolled, "a dive that lands rolls on")
	_check(roll_speed > player.run_speed, "the roll is faster than running (%.0f)" % roll_speed)
	_check(rolled_anim, "the rig rolls")
	_check(not player.is_rolling() and absf(player.velocity.x) < 1.0, "the roll ends and the fighter stops")
	var travel := player.position.x - from
	_check(travel > 50.0 and travel < 110.0, "dive and roll cover a short stretch, not a long slide (%.0f px)" % travel)
	s[0].queue_free()
	await process_frame


func _test_air_dive_once_per_jump() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 10)
	_hold(frames, 6, 0.0, InputFrame.JUMP)
	_hold(frames, 1, 1.0, InputFrame.CROUCH)
	_hold(frames, 2, 1.0)
	_hold(frames, 1, 1.0, InputFrame.CROUCH)
	_hold(frames, 60)
	var s := _stage(frames)
	var player: CharacterBody2D = s[1]
	await _frames(18)
	_check(not player.is_on_floor(), "in the air")
	_check(player.is_diving(), "crouch with a direction in the air dives")
	_check(player.velocity.x >= player.dive_speed - 1.0, "forward at dive speed (%.0f)" % player.velocity.x)
	var timer: float = player._dive_timer
	await _frames(3)
	_check(player._dive_timer < timer, "a second press in the same jump doesn't dive again")
	s[0].queue_free()
	await process_frame


## Bullets are rays, so the dive's i-frames used to do nothing against them:
## a low shot (under any crouch) mid-dive and mid-roll flies through, the
## same shot once the roll is over hits.
func _test_dive_dodges_bullets() -> void:
	var frames: Array[InputFrame] = []
	_hold(frames, 30, 1.0)
	_hold(frames, 1, 1.0, InputFrame.CROUCH)
	_hold(frames, 80)
	var made := _stage(frames)
	var stage: Node2D = made[0]
	var player: CharacterBody2D = made[1]
	for i in 32:
		await physics_frame
	var hp: int = player.health.current_health
	var dodged := 0
	for i in 22:
		if player.is_dodging():
			_shoot(stage, player)
			dodged += 1
		await physics_frame
	_check(dodged >= 15, "the dive and roll dodge for a while (%d frames)" % dodged)
	_check(player.health.current_health == hp, "bullets fly through a dive and roll (hp %d)" % player.health.current_health)
	for i in 40:
		await physics_frame
	_check(not player.is_dodging(), "the dodge ends")
	_shoot(stage, player)
	for i in 5:
		await physics_frame
	_check(player.health.current_health < hp, "the same shot hits once the roll is over")
	stage.queue_free()
	await process_frame


## A pistol bullet from just behind, at shin height.
func _shoot(stage: Node2D, target: CharacterBody2D) -> void:
	var bullet: Projectile = PROJECTILE_SCENE.instantiate()
	stage.add_child(bullet)
	bullet.setup(target.global_position + Vector2(-30, -5), Vector2.RIGHT, PISTOL, null, [])
