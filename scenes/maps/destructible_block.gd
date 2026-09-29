class_name DestructibleBlock
extends StaticBody2D

## One 16 px map tile. Its BlockMaterial decides what can break it: bullets
## and melee arrive through the shared Hurtbox / HealthComponent pipeline,
## explosions through take_blast(). It darkens as it loses health and
## disappears when the health runs out.

signal destroyed(block: DestructibleBlock)

const WOOD := preload("res://scenes/maps/materials/wood.tres")
## Visible thickness of a one-way plank; fighters stand on its top edge.
const PLANK_HEIGHT := 6.0

@export var block_material: BlockMaterial = WOOD
## Fighters jump up through it and land on top (platform planks).
@export var one_way := false

## True when nothing can break this tile (metal).
var indestructible: bool:
	get:
		return block_material.is_indestructible()

@onready var health: HealthComponent = $HealthComponent
@onready var _visual: ColorRect = $Visual
@onready var _hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	health.max_health = block_material.max_health
	health.current_health = block_material.max_health
	_visual.color = block_material.color
	# Our _draw() paints the pattern over the base colour.
	_visual.show_behind_parent = true
	# Tileset art replaces the placeholder rectangle and pattern.
	_visual.visible = art() == null
	if one_way:
		$CollisionShape2D.one_way_collision = true
		_visual.offset_bottom = _visual.offset_top + PLANK_HEIGHT
	if not block_material.breaks_from_hits:
		# Bullets and swings pass untouched: with no monitorable hurtbox the
		# hit never registers (bullets still stop on the tile's body).
		_hurtbox.health = null
		_hurtbox.monitorable = false
	_hurtbox.melee_proof = not block_material.breaks_from_melee
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)


## Explosion damage, routed here by DestructibleMap.damage_area().
func take_blast(amount: int, source: Node = null) -> void:
	if block_material.breaks_from_blasts:
		health.take_damage(amount, source)


func _on_health_changed(current: int, maximum: int) -> void:
	var lost := 1.0 - float(current) / float(maximum)
	_visual.color = block_material.color.lerp(block_material.damaged_color, lost)
	queue_redraw()


## The tileset strip this tile draws from, or null for the placeholder.
func art() -> Texture2D:
	if one_way and block_material.plank_texture != null:
		return block_material.plank_texture
	return block_material.texture


## Strip frame for the current damage (0 = intact).
func art_frame() -> int:
	return BlockMaterial.frame_for(art(), float(health.current_health) / float(health.max_health), DestructibleMap.TILE_SIZE)


func _on_died(_source: Node) -> void:
	# Drop the collider now so bodies on top fall this same physics step.
	collision_layer = 0
	_hurtbox.set_deferred("monitorable", false)
	destroyed.emit(self)
	queue_free()


## The material's tileset frame; until there is one, a placeholder: plank
## seams, brick mortar or rivets, so each material reads at a glance.
func _draw() -> void:
	var strip := art()
	if strip != null:
		var tile := DestructibleMap.TILE_SIZE
		var height := PLANK_HEIGHT if one_way else float(tile)
		draw_texture_rect_region(strip, Rect2(-tile / 2.0, -tile / 2.0, tile, height),
				Rect2(art_frame() * tile, 0, tile, height))
		return
	var detail := block_material.detail_color
	match block_material.pattern:
		BlockMaterial.Pattern.PLANKS:
			if one_way:
				draw_line(Vector2(-8, -8 + PLANK_HEIGHT - 0.5), Vector2(8, -8 + PLANK_HEIGHT - 0.5), detail)
				draw_rect(Rect2(-1, -8, 1, PLANK_HEIGHT), detail)
			else:
				draw_rect(Rect2(-8, -8, 16, 16), detail, false, 1.0)
				draw_line(Vector2(-8, -8), Vector2(8, 8), detail)
		BlockMaterial.Pattern.BRICKS:
			draw_rect(Rect2(-8, -1, 16, 1), detail)
			draw_rect(Rect2(-8, 7, 16, 1), detail)
			draw_rect(Rect2(-3, -8, 1, 7), detail)
			draw_rect(Rect2(3, 0, 1, 7), detail)
		BlockMaterial.Pattern.RIVETS:
			draw_rect(Rect2(-8, -8, 16, 16), detail, false, 1.0)
			for corner in [Vector2(-6, -6), Vector2(4, -6), Vector2(-6, 4), Vector2(4, 4)]:
				draw_rect(Rect2(corner, Vector2(2, 2)), detail)
