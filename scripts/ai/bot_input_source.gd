class_name BotInputSource
extends InputSource
## A computer-controlled fighter. It looks at the world the way a player
## would (opponents, loose weapons, live grenades, the floor ahead) and answers
## with the same InputFrame a keyboard produces, so the player script cannot
## tell a bot from a human and stays deterministic: same seed, same world,
## same frames.
##
## Priorities, Superfighters style:
##   1. Flee a grenade about to blow (NORMAL and HARD).
##   2. Unarmed and a weapon is closer than the enemy: grab it.
##   2b. A power-up it can use is closer than the enemy: walk over it.
##   3. Close in on the nearest enemy and punch, slash, shoot or throw.
##   Every tick: never walk off a ledge or into a hazard; jump gaps it can
##   clear, walls in the way and platforms the enemy stands on.
##
## Hazards (HazardZone: void, fire, acid, spikes, flame jets) join the
## "hazards" group; the bot treats ground covered by a live one as a hole.

const HAZARD_GROUP := &"hazards"
const WORLD_MASK := 1
## Distances in px, tuned to the player (18x30 body, 16 px punch reach,
## ~57 px jump, 140 px/s run).
const PUNCH_RANGE := 22.0
const MELEE_HEIGHT := 20.0
const PUNCH_STANDOFF := 12.0
const ARRIVE_DISTANCE := 4.0
const GRAB_DISTANCE := 20.0
const LEDGE_PROBE := 14.0
## Deepest step down the bot takes; fall damage starts at ~99 px (500 px/s).
const LEDGE_DROP := 72.0
const GAP_JUMP_REACH := 56.0
## Farthest landing spot looked for across a gap; a full running jump carries
## ~92 px on the level and ~78 px onto a ledge JUMP_RISE higher.
const GAP_JUMP_MAX := 80.0
const GAP_JUMP_STEP := 8.0
const JUMP_RISE := 32.0
const CLIMB_HEIGHT := 24.0
## Hazards up to this high above the feet (spikes, flame jets) block a step.
const HAZARD_HEADROOM := 24.0
const CLIMB_RANGE := 56.0
const GRENADE_THREAT_RADIUS := 64.0
const GRENADE_MIN_RANGE := 50.0
const GRENADE_MAX_RANGE := 150.0
const SHOOT_KEEP_DISTANCE := 90.0
## How close a bot gets before throwing an empty gun.
const THROW_DISTANCE := 60.0
## A dive plus the roll after it covers about this much floor (px): a burning
## bot only dives to put the flames out where that much ground is safe.
const FIRE_ROLL_REACH := 80.0
## Buttons the player reacts to on the press edge; the bot releases them for
## a tick between presses.
const TAP_BUTTONS := InputFrame.JUMP | InputFrame.ATTACK | InputFrame.PICKUP

var profile: BotProfile
## The fighter this bot drives (a player CharacterBody2D with `health` and
## `weapons`).
var body: CharacterBody2D
## Returns the Array of bodies to fight. Defaults to the living fighters that
## share the bot's parent.
var opponents_provider: Callable

var _rng := RandomNumberGenerator.new()
var _tick := 0
var _goal_x := NAN
var _target: Node2D
## What the bot is walking to (a weapon or `_target`); climbs if it is above.
var _destination: Node2D
var _pending := 0
var _last_buttons := 0


func _init(fighter: CharacterBody2D, level := BotProfile.Difficulty.NORMAL, seed_value := 0) -> void:
	body = fighter
	profile = BotProfile.create(level)
	_rng.seed = seed_value
	# Bots with different seeds think on different ticks, so mirrored bots on a
	# symmetric map don't trade identical blows and die on the same frame.
	_tick = _rng.randi() % profile.think_interval
	opponents_provider = _siblings


func sample() -> InputFrame:
	var frame := _decide()
	_last_buttons = frame.buttons
	return frame


func current_target() -> Node2D:
	return _target if is_instance_valid(_target) else null


func _decide() -> InputFrame:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.health.is_dead():
		return InputFrame.new()
	_tick += 1
	if _tick % profile.think_interval == 0:
		_think()

	var rocket := _rocket()
	if rocket != null:
		return InputFrame.create(_steer_towards(rocket, _target), 0)

	var buttons := 0
	var move := 0.0
	if not is_nan(_goal_x) and absf(_goal_x - body.global_position.x) > ARRIVE_DISTANCE:
		move = signf(_goal_x - body.global_position.x)

	var threat := _grenade_threat()
	if threat != null:
		move = 1.0 if body.global_position.x >= threat.global_position.x else -1.0
		_pending = 0
	elif _pending != 0:
		# Strikes come out of the facing side: turn first, strike next tick.
		var side := _side_of(_target)
		if side != 0 and side != body.weapons.facing and _pending & (InputFrame.ATTACK | InputFrame.PICKUP):
			move = side * 0.1
		elif not body.is_on_floor() and not body.weapons.has_weapon() and _pending & InputFrame.ATTACK:
			# An empty-handed attack in the air is a drop kick that could
			# carry the bot over a ledge: punch once it lands.
			pass
		else:
			buttons |= _pending
			_pending = 0

	var on_fire := profile.puts_out_fire and _burning()
	if on_fire and move == 0.0 and body.is_on_floor():
		# Needs a run-up to dive: run where it faces.
		move = float(body.weapons.facing)

	if body.has_method("is_hanging") and body.is_hanging():
		# Caught a ledge on the way: climb it.
		buttons |= InputFrame.JUMP if not _last_buttons & InputFrame.JUMP else 0
	elif body.is_on_floor():
		if move != 0.0 and not _safe_ground(signf(move) * (LEDGE_PROBE + absf(body.velocity.x) * 0.08)):
			if _gap_jumpable(signf(move)):
				buttons |= InputFrame.JUMP
			elif threat == null:
				move = 0.0
			else:
				move = -move
		elif move != 0.0 and body.is_on_wall():
			buttons |= InputFrame.JUMP
		elif _should_climb():
			buttons |= InputFrame.JUMP
		if on_fire and move != 0.0 and _safe_ground(signf(move) * FIRE_ROLL_REACH) \
				and absf(body.velocity.x) >= body.run_speed * body.dive_min_speed \
				and not _last_buttons & InputFrame.CROUCH:
			# Dive and roll to smother the flames (Superfighters).
			buttons |= InputFrame.CROUCH

	# A tap only registers on its press edge: release before pressing again.
	# Automatic weapons are the exception: they fire while FIRE stays held.
	var taps := TAP_BUTTONS & ~(InputFrame.ATTACK if _holds_automatic() else 0)
	var repeated := buttons & _last_buttons & taps
	_pending |= repeated & ~InputFrame.JUMP
	buttons &= ~repeated
	if _holds_automatic() and _last_buttons & InputFrame.ATTACK and threat == null and _in_shot(_target):
		buttons |= InputFrame.ATTACK
	# Letting go of jump cuts the rise short: hold it until the apex.
	if _last_buttons & InputFrame.JUMP and not body.is_on_floor() and body.velocity.y < 0.0:
		buttons |= InputFrame.JUMP
	return InputFrame.create(move, buttons)


func _burning() -> bool:
	var burning := Burning.of(body)
	return burning != null and burning.is_burning()


## Picks what to do next; runs every `think_interval` ticks.
func _think() -> void:
	_target = _nearest(opponents_provider.call())
	var weapons: WeaponHolder = body.weapons
	var pickup := _nearest(_loose_weapons()) if not weapons.has_weapon() else null
	if pickup != null and (_target == null or _dist(pickup) < _dist(_target) * profile.weapon_greed):
		_goal_x = pickup.global_position.x
		_destination = pickup
		if _dist(pickup) <= GRAB_DISTANCE:
			_pending |= InputFrame.PICKUP
		return
	var power_up := _nearest(_loose_power_ups())
	if power_up != null and (_target == null or _dist(power_up) < _dist(_target) * profile.weapon_greed):
		# Power-ups are collected by touch: just walk onto it.
		_goal_x = power_up.global_position.x
		_destination = power_up
		return
	_destination = _target
	if _target == null:
		_goal_x = NAN
		return

	var dx := _target.global_position.x - body.global_position.x
	var dy := absf(_target.global_position.y - body.global_position.y)
	var side := _side_of(_target)
	var weapon: WeaponData = weapons.weapon
	var strike := 0
	if weapon == null:
		# Fighters pass through each other: stop at fist range, not on top.
		_goal_x = _target.global_position.x - side * PUNCH_STANDOFF
		if absf(dx) <= PUNCH_RANGE and dy <= MELEE_HEIGHT:
			# Holding someone, attack knees; otherwise sometimes grab.
			var holding: bool = body.has_method("is_grabbing") and body.is_grabbing()
			var grab := not holding and _rng.randf() < profile.grab_chance
			strike = InputFrame.PICKUP if grab else InputFrame.ATTACK
	elif weapons.is_empty():
		# Out of ammo: close in and throw the gun (Superfighters).
		_goal_x = _target.global_position.x - side * THROW_DISTANCE
		if absf(dx) <= THROW_DISTANCE * 2.0 and dy <= MELEE_HEIGHT:
			strike = InputFrame.PICKUP
	elif weapon is GrenadeData:
		_goal_x = _target.global_position.x - side * (GRENADE_MIN_RANGE + GRENADE_MAX_RANGE) * 0.5
		if absf(dx) >= GRENADE_MIN_RANGE and absf(dx) <= GRENADE_MAX_RANGE and dy <= MELEE_HEIGHT * 2.0:
			strike = InputFrame.ATTACK
	elif weapon.is_ranged():
		_goal_x = _target.global_position.x if dy > profile.aim_tolerance \
				else _target.global_position.x - side * SHOOT_KEEP_DISTANCE
		if _in_shot(_target):
			strike = InputFrame.ATTACK
	else:
		_goal_x = _target.global_position.x - side * weapon.melee_offset
		if absf(dx) <= weapon.melee_offset + weapon.reach.x * 0.5 and dy <= MELEE_HEIGHT:
			strike = InputFrame.ATTACK
	if strike != 0 and (weapon == null or weapons.is_ready()) and _rng.randf() < profile.aggression:
		_pending |= strike


func _in_shot(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or body.weapons.weapon == null:
		return false
	var weapon: WeaponData = body.weapons.weapon
	var dx := absf(target.global_position.x - body.global_position.x)
	var dy := absf(target.global_position.y - body.global_position.y)
	return weapon.is_ranged() and dy <= profile.aim_tolerance and dx <= weapon.projectile_range * 0.8


func _holds_automatic() -> bool:
	return body.weapons.has_weapon() and body.weapons.weapon.automatic and not body.weapons.is_empty()


func _rocket() -> Node2D:
	return body.riding_rocket() if body.has_method("riding_rocket") else null


## Riding a rocket: turn it towards `target` (+1 turns clockwise).
func _steer_towards(rocket: Node2D, target: Node2D) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	var heading: float = rocket.linear_velocity.angle()
	var wanted := (target.global_position + Vector2(0, -12) - rocket.global_position).angle()
	var turn := wrapf(wanted - heading, -PI, PI)
	if absf(turn) > 2.0 and sin(heading) > -0.5:
		# A U-turn loops over the top: turning down would hit the floor.
		# Once climbing, the shortest turn takes it round towards the target.
		return -signf(cos(heading)) if cos(heading) != 0.0 else 1.0
	return 0.0 if absf(turn) < 0.05 else signf(turn)


## The nearest grenade about to blow within reach, if this bot cares.
func _grenade_threat() -> Node2D:
	if profile.grenade_awareness <= 0.0:
		return null
	var best: Node2D = null
	var best_distance := GRENADE_THREAT_RADIUS
	for grenade in _grenades():
		if grenade.fuse_left > profile.grenade_awareness:
			continue
		var distance := _dist(grenade)
		if distance < best_distance:
			best = grenade
			best_distance = distance
	return best


## Thrown grenades land next to their thrower, i.e. among the fighters.
func _grenades() -> Array:
	var found := []
	var world := body.get_parent()
	if world == null:
		return found
	for node in world.get_children():
		if node is Grenade and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _loose_weapons() -> Array:
	var found := []
	for node in body.get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		if not node.is_queued_for_deletion() and absf(node.global_position.y - body.global_position.y) <= CLIMB_RANGE:
			found.append(node)
	return found


## Reachable power-ups, minus medkits while at full health.
func _loose_power_ups() -> Array:
	var found := []
	var full_health: bool = body.health.current_health >= body.health.max_health
	for node in body.get_tree().get_nodes_in_group(PowerUpPickup.GROUP):
		if node.is_queued_for_deletion() or absf(node.global_position.y - body.global_position.y) > CLIMB_RANGE:
			continue
		if full_health and node.power_up.effect == PowerUpData.Effect.HEAL:
			continue
		found.append(node)
	return found


func _siblings() -> Array:
	var found := []
	var world := body.get_parent()
	if world == null:
		return found
	for node in world.get_children():
		if node != body and node is CharacterBody2D and node.get("health") is HealthComponent \
				and not node.health.is_dead() and not _teammate(node):
			found.append(node)
	return found


func _teammate(node: Node) -> bool:
	var team = body.get("team")
	return team is int and team > 0 and node.get("team") == team


## Jump when the destination sits on a platform above us, within reach.
func _should_climb() -> bool:
	if _destination == null or not is_instance_valid(_destination):
		return false
	var rise := body.global_position.y - _destination.global_position.y
	return rise >= CLIMB_HEIGHT and absf(_destination.global_position.x - body.global_position.x) <= CLIMB_RANGE


## True if there is floor, and no live hazard on it or in the drop above
## it, at the point `offset_x` px ahead. `rise` also accepts floor up to that
## many px above the feet (a ledge a jump can land on).
func _safe_ground(offset_x: float, rise := 0.0) -> bool:
	var feet := body.global_position
	var probe := Vector2(feet.x + offset_x, feet.y)
	var space := body.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(probe + Vector2(0, -4 - rise), probe + Vector2(0, LEDGE_DROP), WORLD_MASK, [body.get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty() or _is_hazard(hit.collider):
		return false
	var top := minf(feet.y, hit.position.y) - HAZARD_HEADROOM
	return not _hazard_in_column(probe.x, top, hit.position.y + 2.0)


## Hazard zones are matched by geometry, not physics queries: HazardZone
## (scripts/hazards) only scans for fighters and is invisible to queries.
func _hazard_in_column(x: float, top: float, bottom: float) -> bool:
	for zone in body.get_tree().get_nodes_in_group(HAZARD_GROUP):
		if not zone is Node2D or not _hazard_live(zone):
			continue
		var rect := _hazard_rect(zone)
		if x >= rect.position.x and x <= rect.end.x and rect.position.y <= bottom and rect.end.y >= top:
			return true
	return false


## Off traps are safe to cross, except the ones pulsing on a timer.
func _hazard_live(zone: Node) -> bool:
	if zone.get("active") == false:
		return zone.get("cycle_on") is float and zone.cycle_on > 0.0
	return true


## HazardZone: origin at the top-left corner plus `size`. Anything else: the
## union of its rectangle collision shapes.
func _hazard_rect(zone: Node2D) -> Rect2:
	if zone.get("size") is Vector2:
		return Rect2(zone.global_position, zone.size)
	var rect := Rect2()
	for shape_node in zone.find_children("*", "CollisionShape2D", true, false):
		var shape := (shape_node as CollisionShape2D).shape as RectangleShape2D
		if shape == null:
			continue
		var r := Rect2(shape_node.global_position - shape.size * 0.5, shape.size)
		rect = r if not rect.has_area() else rect.merge(r)
	return rect


func _gap_jumpable(direction: float) -> bool:
	if is_nan(_goal_x) or signf(_goal_x - body.global_position.x) != direction:
		return false
	var reach := GAP_JUMP_REACH
	while reach <= GAP_JUMP_MAX:
		if _safe_ground(direction * reach, JUMP_RISE):
			return true
		reach += GAP_JUMP_STEP
	return false


func _is_hazard(node: Object) -> bool:
	var current := node as Node
	while current != null:
		if current.is_in_group(HAZARD_GROUP):
			return true
		current = current.get_parent()
	return false


func _nearest(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for candidate in candidates:
		var distance := _dist(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _dist(node: Node2D) -> float:
	return body.global_position.distance_to(node.global_position)


func _side_of(node: Node2D) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	return 1 if node.global_position.x >= body.global_position.x else -1
