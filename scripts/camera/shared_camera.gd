class_name SharedCamera
extends Camera2D

## One camera for 2-4 local fighters. Every physics tick it frames the living
## targets: centres on them, zooms out just enough to fit them (between
## min_zoom and max_zoom) and never shows anything outside `bounds`.
##
## Feel, Superfighters-style: pan and zoom ride a critically damped spring
## (they ease in and land without overshoot), the view widens at once when
## fighters spread but only tightens after they stay close for a moment, so
## jumps and dodges don't make the zoom pump.
##
## Screen shake uses a "trauma" value in [0, 1]: hits and explosions add
## trauma, it decays over time and the offset grows with trauma squared, so
## small hits wiggle and big blasts punch. Anything can shake the view with
## `SharedCamera.shake(self, 0.5)` without holding a reference to the camera.
##
## The map limit beats min_zoom, so a map smaller than view_size / min_zoom
## can leave far-apart fighters off screen. Size maps with the 16:9 view in
## mind (e.g. 960x544 for zoom 0.5).
##
## Responsive: the view size comes from the viewport every tick, so portrait
## phones, landscape phones and PC windows all frame correctly. With
## `letterbox_bounds` a map whose shape doesn't match the screen (a wide map
## on an upright phone) is shown whole on its tight axis and centred on the
## other, so the extra strip shows background instead of cutting fighters.

const GROUP := &"shared_cameras"

## World area the view must stay inside (usually the map's playable rect).
@export var bounds := Rect2(0, 0, 480, 270)
## When the map's aspect differs from the screen's, allow seeing past the map
## on one axis (centred) rather than zooming in and losing fighters. Off:
## never show past the map, whatever it costs.
@export var letterbox_bounds := true
## Nodes in this group are followed automatically, on top of add_target().
@export var target_group := &""
## Offset from a target's origin to the point we frame (players stand on
## their origin, so aim a bit higher, at the chest).
@export var focus_offset := Vector2(0, -16)
## Free space kept around the outermost fighters, in world pixels.
@export var margin := Vector2(48, 40)
@export var min_zoom := 0.5
@export var max_zoom := 1.5
## Roughly how long (s) the view takes to catch a fighter. 0 snaps.
@export var follow_time := 0.3
## Vertical follow is lazier so jumps don't bob the whole screen.
@export var follow_time_vertical := 0.45
## How long (s) widening takes: short, so nobody runs off screen.
@export var zoom_out_time := 0.25
## How long (s) tightening takes once it starts: long and gentle.
@export var zoom_in_time := 0.9
## Fighters must stay close this long (s) before the view tightens.
@export var zoom_in_delay := 0.5
## Rounds the view to whole screen pixels so the pixel art doesn't swim.
@export var pixel_snap := true
## Rest on zooms where one world pixel covers a whole number of screen
## pixels, so sprites never get uneven rows/columns at any window size.
## Between two such zooms the view glides; only the resting zoom is snapped.
@export var pixel_perfect_zoom := true
## Screen pixels per viewport pixel; 0 reads it from the window stretch.
## Tests set it to simulate a given screen.
@export var screen_scale_override := 0.0

@export_group("Shake")
## Maximum displacement in world pixels at full trauma.
@export var max_shake_offset := Vector2(8, 6)
## Trauma lost per second.
@export var trauma_decay := 1.5
## Noise speed; higher is a more violent rattle.
@export var shake_frequency := 25.0
## Trauma added per point of damage a followed target takes (0 disables).
@export var trauma_per_damage := 0.015

var trauma := 0.0

# Untyped: a typed array rejects (and can't erase) freed objects.
var _targets: Array = []
var _center := Vector2.ZERO
var _zoom := 1.0
var _center_velocity := Vector2.ZERO
var _zoom_velocity := 0.0
## Zoom the spring is heading to; lags the ideal one when tightening.
var _zoom_goal := 1.0
var _zoom_in_timer := 0.0
var _shake_time := 0.0
var _noise := FastNoiseLite.new()


## Adds trauma to every SharedCamera in `context`'s viewport.
static func shake(context: Node, amount: float) -> void:
	if context == null or not context.is_inside_tree():
		return
	var viewport := context.get_viewport()
	for camera: SharedCamera in context.get_tree().get_nodes_in_group(GROUP):
		if camera.get_viewport() == viewport:
			camera.add_trauma(amount)


func _init() -> void:
	# We smooth and clamp ourselves; the built-in limits would eat the shake.
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_noise.seed = 7
	_noise.frequency = 1.0
	# Single octave: the full [-1, 1] range, so max_shake_offset means what it says.
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


func _enter_tree() -> void:
	add_to_group(GROUP)
	if _center == Vector2.ZERO:
		_center = global_position
	_zoom = zoom.x
	_zoom_goal = _zoom


func _physics_process(delta: float) -> void:
	advance(delta)


func add_target(target: Node2D) -> void:
	if target == null or _targets.has(target):
		return
	_targets.append(target)
	var health := _health_of(target)
	if health and not health.damaged.is_connected(_on_target_damaged):
		health.damaged.connect(_on_target_damaged)


func remove_target(target: Node2D) -> void:
	_targets.erase(target)
	if is_instance_valid(target):
		var health := _health_of(target)
		if health and health.damaged.is_connected(_on_target_damaged):
			health.damaged.disconnect(_on_target_damaged)


func get_targets() -> Array[Node2D]:
	_refresh_targets()
	var result: Array[Node2D] = []
	result.assign(_targets)
	return result


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Jumps straight to the framing goal (round start, respawn, tests).
func snap() -> void:
	_refresh_targets()
	var goal := _goal()
	_zoom = _resting_zoom(goal.z)
	_zoom_goal = _zoom
	_zoom_in_timer = 0.0
	_zoom_velocity = 0.0
	_center = _clamp_center(Vector2(goal.x, goal.y), _zoom)
	_center_velocity = Vector2.ZERO
	_apply(Vector2.ZERO)


## One camera tick; public so tests can step it deterministically.
func advance(delta: float) -> void:
	_refresh_targets()
	var goal := _goal()
	_update_zoom_goal(_resting_zoom(goal.z), delta)
	var zoom_time := zoom_out_time if _zoom_goal < _zoom else zoom_in_time
	var zoom_step := _smooth_damp(_zoom, _zoom_goal, _zoom_velocity, zoom_time, delta)
	_zoom = zoom_step.x
	_zoom_velocity = zoom_step.y
	# Aim for where the goal sits at the zoom we'll actually show.
	var aim := _clamp_center(Vector2(goal.x, goal.y), _final_zoom(_zoom))
	var step_x := _smooth_damp(_center.x, aim.x, _center_velocity.x, follow_time, delta)
	var step_y := _smooth_damp(_center.y, aim.y, _center_velocity.y, follow_time_vertical, delta)
	_center = Vector2(step_x.x, step_y.x)
	_center_velocity = Vector2(step_x.y, step_y.y)
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	_shake_time += delta
	_apply(_shake_offset())


## Goal as (centre.x, centre.y, zoom). Holds the current framing when nobody
## is alive, so the view doesn't jump while a round resets.
func _goal() -> Vector3:
	var points: Array[Vector2] = []
	for target in _targets:
		if _is_alive(target):
			points.append(target.global_position + focus_offset)
	if points.is_empty():
		return Vector3(_center.x, _center.y, _zoom)
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	var view := _view_size()
	var framed := box.size + margin * 2.0
	var fit := minf(view.x / maxf(framed.x, 1.0), view.y / maxf(framed.y, 1.0))
	var z := clampf(fit, min_zoom, max_zoom)
	z = maxf(z, _min_zoom_for_bounds())
	var center := _clamp_center(box.get_center(), z)
	return Vector3(center.x, center.y, z)


## Smallest zoom whose view still fits inside `bounds`.
func _min_zoom_for_bounds() -> float:
	var view := _view_size()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var per_axis := view / bounds.size
	return minf(per_axis.x, per_axis.y) if letterbox_bounds else maxf(per_axis.x, per_axis.y)


func _clamp_center(center: Vector2, z: float) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return center
	var half := _view_size() / (2.0 * z)
	var result := center
	for axis in 2:
		var low := bounds.position[axis] + half[axis]
		var high := bounds.end[axis] - half[axis]
		result[axis] = bounds.get_center()[axis] if low > high else clampf(center[axis], low, high)
	return result


func _apply(shake_offset: Vector2) -> void:
	var z := _final_zoom(_zoom)
	var base := _clamp_center(_center, z)
	var center := _clamp_center(base + shake_offset, z)
	# Pinned against the map edge the clamp would swallow the kick, so bounce
	# it inward instead: shakes stay visible in corners too.
	for axis in 2:
		if not is_equal_approx(center[axis], base[axis] + shake_offset[axis]):
			center[axis] = base[axis] - shake_offset[axis]
	if pixel_snap:
		var pixels_per_unit := z * _screen_scale()
		center = (center * pixels_per_unit).round() / pixels_per_unit
	zoom = Vector2(z, z)
	global_position = _clamp_center(center, z)


## Widening happens now; tightening waits until the fighters have stayed
## close for zoom_in_delay, so short clinches and jumps don't pump the zoom.
func _update_zoom_goal(wanted: float, delta: float) -> void:
	if wanted <= _zoom_goal:
		_zoom_goal = wanted
		_zoom_in_timer = 0.0
		return
	_zoom_in_timer += delta
	if _zoom_in_timer >= zoom_in_delay:
		_zoom_goal = wanted
		_zoom_in_timer = 0.0


## The zoom actually shown: never bigger than the map. It may sit between
## pixel-perfect steps while gliding; the goal it rests on is snapped.
func _final_zoom(eased: float) -> float:
	return maxf(eased, _min_zoom_for_bounds())


## Where the zoom comes to rest: with pixel_perfect_zoom, a whole number of
## screen pixels per world pixel.
func _resting_zoom(ideal: float) -> float:
	var lowest := _min_zoom_for_bounds()
	var z := maxf(ideal, lowest)
	if not pixel_perfect_zoom:
		return z
	var screen := _screen_scale()
	# Round down so everyone still fits; step back up if that would show past
	# the map or go under min_zoom.
	var steps := maxf(floorf(z * screen + 0.001), 1.0)
	var floor_zoom := maxf(lowest, min_zoom)
	if steps / screen < floor_zoom - 0.001:
		steps = ceilf(floor_zoom * screen - 0.001)
	return steps / screen


func _screen_scale() -> float:
	if screen_scale_override > 0.0:
		return screen_scale_override
	if not is_inside_tree():
		return 1.0
	# Includes the window stretch (e.g. 2 on a 960x540 window for a 480x270
	# base). Below 1 the art is downscaled anyway, so treat it as 1.
	return maxf(get_viewport().get_final_transform().x.length(), 1.0)


func _shake_offset() -> Vector2:
	if trauma <= 0.0:
		return Vector2.ZERO
	var strength := trauma * trauma
	var t := _shake_time * shake_frequency
	return Vector2(
		max_shake_offset.x * strength * _noise.get_noise_2d(t, 0.0),
		max_shake_offset.y * strength * _noise.get_noise_2d(0.0, t))


func _refresh_targets() -> void:
	_targets = _targets.filter(func(t): return is_instance_valid(t))
	if target_group != &"" and is_inside_tree():
		for node in get_tree().get_nodes_in_group(target_group):
			if node is Node2D:
				add_target(node)


func _is_alive(target) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if not target.is_visible_in_tree():
		return false
	var health := _health_of(target)
	return health == null or not health.is_dead()


func _health_of(target: Node) -> HealthComponent:
	return target.get_node_or_null("HealthComponent") as HealthComponent


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(480, 270)


func _on_target_damaged(amount: int, _source: Node) -> void:
	add_trauma(amount * trauma_per_damage)


## Critically damped spring (Game Programming Gems 4, "SmoothDamp"): eases
## in from rest, never overshoots. Returns (new value, new velocity).
static func _smooth_damp(current: float, target: float, velocity: float,
		smooth_time: float, delta: float) -> Vector2:
	if smooth_time <= 0.0:
		return Vector2(target, 0.0)
	var omega := 2.0 / smooth_time
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var temp := (velocity + omega * change) * delta
	var new_velocity := (velocity - omega * temp) * decay
	var result := target + (change + temp) * decay
	# Landed past the target: stop there instead of swinging back.
	if (target - current > 0.0) == (result > target):
		return Vector2(target, 0.0)
	return Vector2(result, new_velocity)
