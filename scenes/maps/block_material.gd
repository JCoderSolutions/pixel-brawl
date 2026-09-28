class_name BlockMaterial
extends Resource

## What a map tile is made of: how tough it is, which kinds of damage can
## break it and how it is drawn until the art pass lands.
##
## Hits are bullets and melee swings (they arrive through the tile's Hurtbox);
## blasts are explosions (they arrive through DestructibleMap.damage_area).

enum Pattern { PLANKS, BRICKS, RIVETS }

@export var display_name := ""
@export var max_health := 30
@export var breaks_from_hits := true
@export var breaks_from_blasts := true
@export var color := Color.WHITE
## Shade the tile fades towards as it loses health.
@export var damaged_color := Color.BLACK
## Colour of the seams, mortar or rivets drawn over the tile.
@export var detail_color := Color.BLACK
@export var pattern := Pattern.PLANKS


func is_indestructible() -> bool:
	return not breaks_from_hits and not breaks_from_blasts
