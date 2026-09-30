extends Node

## Game feel, registered as the `GameFeel` autoload: sound, impact particles
## and hit-stop for everything that happens in a fight. It never needs
## gameplay code to call it. It watches the SceneTree and connects itself to
## the signals the gameplay nodes already emit:
##
##   Hitbox.hit_landed          -> punch / block thud, hit burst, hit-stop
##   Projectile.impacted        -> flesh hit or ricochet, sparks / dust
##   WeaponHolder.fired         -> shot, shotgun, swing or throw, muzzle spark
##   WeaponHolder.weapon_equipped -> pickup blip (also on weapon_switched)
##   WeaponHolder.dry_fired     -> empty click, "SIN BALAS" over the fighter
##   WeaponHolder.weapon_thrown -> throw whoosh
##   PowerUpReceiver.power_up_applied -> pickup blip, sparkles, floating name
##   Explosion.exploded         -> explosion, blast burst, hit-stop
##   DestructibleBlock.destroyed -> block break, debris
##   Hurtbox.blocked            -> guard clank (or ricochet for a parry), sparks
##   HealthComponent.died       -> death jingle (not for map tiles)
##   fighters (CharacterBody2D with `jump_velocity`) -> jump / landing + dust
##   GameManager.final_blow     -> slow motion and a close-up on the victim
##
## Hit-stop dips Engine.time_scale for a few real-time milliseconds. Headless
## runs (tests, a future dedicated server) skip wiring entirely because they
## have nothing to show and must not have time bent under them.

const WIRED_META := &"_game_feel_wired"

@export var hit_stop_enabled := true
@export var melee_hit_stop := 0.06
@export var explosion_hit_stop := 0.09
## Engine.time_scale during a hit-stop.
@export var hit_stop_scale := 0.05
## The round-deciding death plays at this Engine.time_scale...
@export var final_blow_scale := 0.25
## ...for this many real seconds, with the cameras zoomed in this much.
@export var final_blow_time := 1.2
@export var final_blow_zoom := 1.6
## Falling speed (px/s) a landing needs to raise dust and make a sound.
@export var land_speed := 260.0
## Wire nodes automatically as they enter the tree. Off in headless.
@export var auto_wire := true

## Where sounds go; the `AudioManager` autoload unless a test swaps it.
## Looked up by path because autoload names aren't known to scripts compiled
## before the autoloads exist (e.g. `godot -s` test runners).
var audio: Node

## body -> { on_floor, vy, hit_frame }
var _fighters := {}
var _hit_stop_left := 0.0
var _slow_left := 0.0
var _slow_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After every fighter has moved this tick, so velocity/floor are current.
	process_physics_priority = 100
	if audio == null:
		audio = get_node_or_null(^"/root/AudioManager")
	if DisplayServer.get_name() == "headless":
		auto_wire = false
	if auto_wire:
		get_tree().node_added.connect(wire)
		wire_tree(get_tree().root)
		var manager := get_node_or_null(^"/root/GameManager")
		if manager != null and manager.has_signal(&"final_blow"):
			manager.final_blow.connect(func(_victim, _killer, at: Vector2) -> void: final_blow(at))


func _exit_tree() -> void:
	_hit_stop_left = 0.0
	_slow_left = 0.0
	Engine.time_scale = 1.0


## Slow motion for the blow that decides the round (Superfighters, and most
## of the genre): time crawls and every camera closes in on `at`.
func final_blow(at: Vector2) -> void:
	slow_motion(final_blow_time, final_blow_scale)
	if not is_inside_tree():
		return
	for camera in get_tree().get_nodes_in_group(SharedCamera.GROUP):
		# The close-up runs on game time, which crawls meanwhile; it holds a
		# little past the slow motion so it has time to settle.
		camera.focus_on(at, final_blow_zoom, final_blow_time * final_blow_scale * 1.5)


## Runs the game at `scale` for `duration` real seconds. A hit-stop inside it
## still freezes harder; it hands back to the slow motion when it ends.
func slow_motion(duration: float, scale: float) -> void:
	if not hit_stop_enabled or duration <= 0.0:
		return
	_slow_left = maxf(_slow_left, duration)
	_slow_scale = scale
	_apply_time_scale()


func is_slow_motion() -> bool:
	return _slow_left > 0.0


## Wires `node` and all of its descendants.
func wire_tree(node: Node) -> void:
	wire(node)
	for child in node.get_children():
		wire_tree(child)


## Connects this node's feedback signals once; safe to call repeatedly.
func wire(node: Node) -> void:
	if node.has_meta(WIRED_META):
		return
	if node is Hitbox:
		node.hit_landed.connect(_on_hit_landed.bind(node))
	elif node is Projectile:
		node.impacted.connect(_on_projectile_impacted.bind(node))
	elif node is WeaponHolder:
		node.fired.connect(_on_fired.bind(node))
		node.weapon_equipped.connect(_on_weapon_equipped)
		node.weapon_switched.connect(func(_w: WeaponData) -> void: _play(&"pickup"))
		node.dry_fired.connect(_on_dry_fired.bind(node))
		node.weapon_thrown.connect(func(_w: WeaponData) -> void: _play(&"throw"))
	elif node is Explosion:
		node.exploded.connect(_on_exploded)
	elif node is PowerUpReceiver:
		node.power_up_applied.connect(_on_power_up.bind(node))
	elif node is DestructibleBlock:
		node.destroyed.connect(_on_block_destroyed)
	elif node is Hurtbox:
		node.blocked.connect(_on_blocked.bind(node))
	elif node is HealthComponent:
		node.died.connect(_on_died.bind(node))
	elif _is_fighter(node):
		_track_fighter(node)
	else:
		return
	node.set_meta(WIRED_META, true)


## Freezes the action for `duration` real seconds. Overlapping requests keep
## the longest remaining one.
func hit_stop(duration: float) -> void:
	if not hit_stop_enabled or duration <= 0.0:
		return
	_hit_stop_left = maxf(_hit_stop_left, duration)
	_apply_time_scale()


func is_hit_stopped() -> bool:
	return _hit_stop_left > 0.0


## Counts the hit-stop down in real time (unscaled seconds).
func advance_real(real_delta: float) -> void:
	if _slow_left > 0.0:
		_slow_left -= real_delta
		if _slow_left <= 0.0:
			_slow_left = 0.0
			_apply_time_scale()
	if _hit_stop_left <= 0.0:
		return
	_hit_stop_left -= real_delta
	if _hit_stop_left <= 0.0:
		_end_hit_stop()


func _process(delta: float) -> void:
	# `delta` arrives scaled by Engine.time_scale; undo it for a real-time timer.
	var scale := Engine.time_scale
	advance_real(delta / scale if scale > 0.0 else delta)


func _physics_process(_delta: float) -> void:
	update_fighters(Engine.get_physics_frames())


## Detects jumps and landings from the fighters' state after they moved.
func update_fighters(frame: int) -> void:
	for body in _fighters.keys():
		if not is_instance_valid(body):
			_fighters.erase(body)
			continue
		if not body.is_inside_tree():
			continue
		var state: Dictionary = _fighters[body]
		var on_floor: bool = body.is_on_floor()
		var vy: float = body.velocity.y
		var was_hit: bool = frame - int(state.hit_frame) <= 2
		var alive := _is_alive(body)
		if alive and state.on_floor and not was_hit and vy <= float(body.jump_velocity) * 0.9:
			_play(&"jump")
			_burst(ImpactBurst.Kind.DUST, body.global_position, Vector2.UP)
		elif alive and not state.on_floor and on_floor and float(state.vy) >= land_speed:
			_play(&"land")
			_burst(ImpactBurst.Kind.DUST, body.global_position, Vector2.UP)
		state.on_floor = on_floor
		state.vy = vy


func _play(sfx_name: StringName, volume_db := 0.0) -> void:
	if audio != null:
		audio.play_sfx(sfx_name, volume_db)


func _end_hit_stop() -> void:
	_hit_stop_left = 0.0
	_apply_time_scale()


## The slowest effect running wins; none restores normal speed.
func _apply_time_scale() -> void:
	if _hit_stop_left > 0.0:
		Engine.time_scale = hit_stop_scale
	elif _slow_left > 0.0:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0


func _is_fighter(node: Node) -> bool:
	return node is CharacterBody2D and "jump_velocity" in node


func _track_fighter(body: CharacterBody2D) -> void:
	_fighters[body] = { on_floor = body.is_on_floor(), vy = body.velocity.y, hit_frame = -100 }
	var hurtbox := body.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		hurtbox.hit_received.connect(_on_fighter_hit.bind(body))


func _on_fighter_hit(_damage: int, _knockback: Vector2, _source: Node, body: CharacterBody2D) -> void:
	if _fighters.has(body):
		_fighters[body].hit_frame = Engine.get_physics_frames()


func _is_alive(body: Node) -> bool:
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or not health.is_dead()


func _on_hit_landed(target: Hurtbox, hitbox: Hitbox) -> void:
	var at := _hurtbox_center(target)
	var away := Vector2(hitbox.direction, -0.3)
	if target.get_parent() is DestructibleBlock:
		_play(&"block_hit")
		_burst(ImpactBurst.Kind.DUST, at, away)
		return
	_play(&"punch")
	_burst(ImpactBurst.Kind.HIT, at, away)
	hit_stop(melee_hit_stop)


func _on_projectile_impacted(point: Vector2, collider: Object, projectile: Projectile) -> void:
	var back := -projectile.velocity
	var hurtbox := collider as Hurtbox
	if hurtbox != null and hurtbox.get_parent() is DestructibleBlock:
		_play(&"block_hit")
		_burst(ImpactBurst.Kind.DUST, point, back)
	elif hurtbox != null:
		_play(&"hit")
		_burst(ImpactBurst.Kind.HIT, point, projectile.velocity)
	else:
		_play(&"ricochet", -4.0)
		_burst(ImpactBurst.Kind.SPARK, point, back)


func _on_fired(data: WeaponData, projectile_count: int, holder: WeaponHolder) -> void:
	if data is GrenadeData:
		_play(&"throw")
		return
	if projectile_count == 0:
		_play(&"swing")
		return
	_play(&"shotgun" if projectile_count > 1 else &"shot")
	var muzzle := holder.global_position + Vector2(data.muzzle_offset * holder.facing, 0.0)
	_burst(ImpactBurst.Kind.SPARK, muzzle, Vector2(holder.facing, 0.0))


func _on_weapon_equipped(_weapon: WeaponData, _ammo: int) -> void:
	_play(&"pickup")


func _on_dry_fired(_weapon: WeaponData, holder: WeaponHolder) -> void:
	_play(&"dry_fire")
	FloatingText.spawn(self, "SIN BALAS", Color("c0cbdc"), holder.global_position + Vector2(0.0, -20.0))


func _on_blocked(kind: StringName, hurtbox: Hurtbox) -> void:
	_play(&"ricochet" if kind == &"bullet" else &"block_hit")
	_burst(ImpactBurst.Kind.SPARK, _hurtbox_center(hurtbox), Vector2.UP)


func _on_power_up(data: PowerUpData, receiver: PowerUpReceiver) -> void:
	_play(&"pickup")
	var at := receiver.global_position
	_burst(ImpactBurst.Kind.SPARKLE, at, Vector2.UP).tint(data.color)
	FloatingText.spawn(self, power_up_label(data), data.color, at + Vector2(0.0, -24.0))


## What floats over a fighter who takes `data`: "+30 VIDA" or its name.
static func power_up_label(data: PowerUpData) -> String:
	if data.effect == PowerUpData.Effect.HEAL:
		return "+%d VIDA" % roundi(data.amount)
	return data.display_name.to_upper()


func _on_exploded(center: Vector2, _radius: float, _hits: int) -> void:
	_play(&"explosion")
	_burst(ImpactBurst.Kind.EXPLOSION, center, Vector2.UP)
	_burst(ImpactBurst.Kind.DUST, center, Vector2.UP)
	hit_stop(explosion_hit_stop)


func _on_block_destroyed(block: DestructibleBlock) -> void:
	_play(&"block_break")
	_burst(ImpactBurst.Kind.DEBRIS, block.global_position, Vector2.UP)


func _on_died(_source: Node, health: HealthComponent) -> void:
	var body := health.get_parent()
	if body is DestructibleBlock:
		return
	_play(&"death")
	if body is Node2D:
		_burst(ImpactBurst.Kind.HIT, (body as Node2D).global_position + Vector2(0, -12), Vector2.UP)


## Bursts live under this autoload, not the arena, so they survive the node
## that caused them and never show up in scene-tree based gameplay logic.
func _burst(kind: ImpactBurst.Kind, at: Vector2, direction: Vector2) -> ImpactBurst:
	return ImpactBurst.spawn(self, kind, at, direction)


func _hurtbox_center(hurtbox: Hurtbox) -> Vector2:
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			return (child as CollisionShape2D).global_position
	return hurtbox.global_position
