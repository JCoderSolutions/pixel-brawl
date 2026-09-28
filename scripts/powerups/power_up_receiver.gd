class_name PowerUpReceiver
extends Node2D

## Lets a fighter use power-ups. Add it as a child of the body (at chest
## height): it changes the body's own knobs (`run_speed`, the punch Hitbox,
## WeaponHolder.damage_multiplier, HealthComponent.shield) and puts them back
## when the effect runs out, so the player script needs no power-up code.
## Picking the same effect again refreshes its timer instead of stacking.

signal power_up_applied(data: PowerUpData)
signal power_up_expired(data: PowerUpData)

## Seconds before expiry when the aura starts blinking.
const WARN_TIME := 2.0
const HEAL_FLASH := 0.5

## Active timed effects: Effect -> {"data": PowerUpData, "left": float}.
var _active := {}
var _base_run_speed := 0.0
var _base_punch_damage := 0
var _heal_flash := 0.0
var _time := 0.0


static func find_on(node: Node) -> PowerUpReceiver:
	if node == null:
		return null
	for child in node.get_children():
		if child is PowerUpReceiver:
			return child
	return null


func _ready() -> void:
	var run_speed = body().get("run_speed")
	_base_run_speed = run_speed if run_speed != null else 0.0
	var hitbox := _punch_hitbox()
	_base_punch_damage = hitbox.damage if hitbox != null else 0
	var health := _health()
	if health != null:
		health.died.connect(func(_source: Node) -> void: clear())


func body() -> Node:
	return get_parent()


## Applies `data`. Returns false if nothing happened (dead fighter, or a
## medkit at full health), so the pickup stays on the map.
func apply(data: PowerUpData) -> bool:
	var health := _health()
	if data == null or (health != null and health.is_dead()):
		return false
	match data.effect:
		PowerUpData.Effect.HEAL:
			if health == null or health.current_health >= health.max_health:
				return false
			health.heal(roundi(data.amount))
			_heal_flash = HEAL_FLASH
		PowerUpData.Effect.SPEED:
			body().set("run_speed", _base_run_speed * data.amount)
		PowerUpData.Effect.STRENGTH:
			_set_strength(data.amount)
		PowerUpData.Effect.SHIELD:
			if health == null:
				return false
			health.shield = roundi(data.amount)
	if not data.is_instant():
		_active[data.effect] = {"data": data, "left": data.duration}
	power_up_applied.emit(data)
	queue_redraw()
	return true


func is_active(effect: PowerUpData.Effect) -> bool:
	return _active.has(effect)


func time_left(effect: PowerUpData.Effect) -> float:
	return _active[effect].left if _active.has(effect) else 0.0


## Ends every timed effect now (death, end of round).
func clear() -> void:
	for effect in _active.keys():
		_expire(effect)


func _physics_process(delta: float) -> void:
	_time += delta
	_heal_flash = maxf(_heal_flash - delta, 0.0)
	for effect in _active.keys():
		_active[effect].left -= delta
		if _active[effect].left <= 0.0:
			_expire(effect)
	var health := _health()
	# A shield broken by damage ends early.
	if _active.has(PowerUpData.Effect.SHIELD) and health != null and health.shield == 0:
		_expire(PowerUpData.Effect.SHIELD)
	if not _active.is_empty() or _heal_flash > 0.0:
		queue_redraw()


func _expire(effect: PowerUpData.Effect) -> void:
	var data: PowerUpData = _active[effect].data
	_active.erase(effect)
	match effect:
		PowerUpData.Effect.SPEED:
			body().set("run_speed", _base_run_speed)
		PowerUpData.Effect.STRENGTH:
			_set_strength(1.0)
		PowerUpData.Effect.SHIELD:
			var health := _health()
			if health != null:
				health.shield = 0
	power_up_expired.emit(data)
	queue_redraw()


func _set_strength(multiplier: float) -> void:
	var hitbox := _punch_hitbox()
	if hitbox != null:
		hitbox.damage = roundi(_base_punch_damage * multiplier)
	var holder := _weapon_holder()
	if holder != null:
		holder.damage_multiplier = multiplier


func _health() -> HealthComponent:
	var health = body().get("health")
	if health is HealthComponent:
		return health
	for child in body().get_children():
		if child is HealthComponent:
			return child
	return null


func _punch_hitbox() -> Hitbox:
	return body().get_node_or_null("Hitbox") as Hitbox


func _weapon_holder() -> WeaponHolder:
	for child in body().get_children():
		if child is WeaponHolder:
			return child
	return null


## Placeholder feedback until the art pass: one ring per active effect in its
## color (a filled bubble for the shield), blinking in the last seconds, and
## a green cross flash on heal.
func _draw() -> void:
	var radius := 17.0
	for effect in _active.keys():
		var entry: Dictionary = _active[effect]
		var data: PowerUpData = entry.data
		if entry.left < WARN_TIME and fmod(_time * 8.0, 2.0) < 1.0:
			radius += 2.5
			continue
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		if effect == PowerUpData.Effect.SHIELD:
			draw_circle(Vector2.ZERO, radius, Color(data.color, 0.18 + 0.08 * pulse))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(data.color, 0.6 + 0.3 * pulse), 1.0)
		radius += 2.5
	if _heal_flash > 0.0:
		var alpha := _heal_flash / HEAL_FLASH
		var rise := -20.0 - (1.0 - alpha) * 8.0
		var green := Color(0.388, 0.78, 0.302, alpha)
		draw_rect(Rect2(-1.5, rise - 4.0, 3.0, 8.0), green)
		draw_rect(Rect2(-4.0, rise - 1.5, 8.0, 3.0), green)
