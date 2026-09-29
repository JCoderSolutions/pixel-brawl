class_name BlockMaterial
extends Resource

## What a map tile is made of: how tough it is, which kinds of damage can
## break it and how it is drawn until the art pass lands.
##
## Hits are bullets and melee swings (they arrive through the tile's Hurtbox);
## blasts are explosions (they arrive through DestructibleMap.damage_area).
## Melee only counts with `breaks_from_melee`: fists and blades don't dig
## through the map, like in Superfighters.

enum Pattern { PLANKS, BRICKS, RIVETS }

@export var display_name := ""
@export var max_health := 30
@export var breaks_from_hits := true
@export var breaks_from_blasts := true
@export var breaks_from_melee := false
@export var color := Color.WHITE
## Shade the tile fades towards as it loses health.
@export var damaged_color := Color.BLACK
## Colour of the seams, mortar or rivets drawn over the tile.
@export var detail_color := Color.BLACK
@export var pattern := Pattern.PLANKS

@export_group("Art")
## Tileset art: a strip of 16x16 frames left to right, from intact to about
## to break; the tile shows the frame for its damage. Empty keeps the
## colour-and-pattern placeholder above.
@export var texture: Texture2D
## Same strip for one-way planks (only the top PLANK_HEIGHT px are shown);
## empty uses `texture`.
@export var plank_texture: Texture2D


## Frames in a strip: its width over the tile size.
static func frame_count(strip: Texture2D, tile := 16) -> int:
	return maxi(1, strip.get_width() / tile) if strip != null else 0


## The strip frame for a tile at `health_ratio` (1 = intact, 0 = gone).
static func frame_for(strip: Texture2D, health_ratio: float, tile := 16) -> int:
	var frames := frame_count(strip, tile)
	if frames <= 1:
		return 0
	return clampi(floori((1.0 - health_ratio) * frames), 0, frames - 1)


func is_indestructible() -> bool:
	return not breaks_from_hits and not breaks_from_blasts
