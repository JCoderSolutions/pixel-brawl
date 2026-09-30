class_name FloatingText
extends Node2D

## A short label that rises from a point and fades out, then frees itself
## (power-up names over the fighter who took them).

const DURATION := 0.9
const RISE := 16.0

var text := ""

var _age := 0.0
var _start := Vector2.ZERO


## Spawns `label` in `color` centred at `at` (global) under `parent`.
static func spawn(parent: Node, label: String, color: Color, at: Vector2) -> FloatingText:
	var floating := FloatingText.new()
	floating.text = label
	floating.z_index = 30
	var node := Label.new()
	node.text = label
	node.theme_type_variation = &"LabelSmall"
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 2)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.size = Vector2(80, 12)
	node.position = Vector2(-40, -6)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.add_child(node)
	parent.add_child(floating)
	floating.global_position = at
	floating._start = at
	return floating


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / DURATION, 0.0, 1.0)
	global_position = _start + Vector2(0.0, -RISE * (1.0 - (1.0 - t) * (1.0 - t)))
	modulate.a = 1.0 - t * t
	if _age >= DURATION:
		queue_free()
