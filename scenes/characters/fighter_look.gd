class_name FighterLook
extends RefCounted

## A pickable character: a name and the colours FighterRig draws it in
## (Endesga 32). The first four keep P1-P4's classic shirts, so a match set
## up without a character screen looks the same as before.

var name := ""
var shirt := Color.WHITE
var pants := Color("3a4466")
var skin := Color("e8b796")
var band := Color.WHITE
## Sprite sheet for this character: one SpriteFrames animation per
## FighterRig.Anim ("idle", "run", "jump", "fall", "crouch", "attack", "hurt",
## "aim", "victory", "dive", "ride", "block"), 32x32 frames with the feet on
## the bottom edge. Missing animations fall back to native shapes.
var frames: SpriteFrames

## Where each character's sprite sheet goes: `<name in lowercase>.tres` (a
## SpriteFrames), e.g. `bruno.tres`. Dropping one there is all it takes.
const SPRITES_DIR := "res://assets/sprites/characters/"

static var _presets: Array[FighterLook] = []


static func create(look_name: String, shirt_color: Color, pants_color: Color, skin_color: Color, band_color: Color) -> FighterLook:
	var look := FighterLook.new()
	look.name = look_name
	look.shirt = shirt_color
	look.pants = pants_color
	look.skin = skin_color
	look.band = band_color
	var sheet := sprite_path(look_name)
	if ResourceLoader.exists(sheet):
		look.frames = load(sheet) as SpriteFrames
	return look


static func sprite_path(look_name: String) -> String:
	return SPRITES_DIR + look_name.to_lower() + ".tres"


## The roster, built once; index it with the ids the menu stores.
static func presets() -> Array[FighterLook]:
	if _presets.is_empty():
		_presets = [
			create("Bruno", Color("0099db"), Color("3a4466"), Color("e8b796"), Color("2ce8f5")),
			create("Roja", Color("e43b44"), Color("262b44"), Color("c28569"), Color("feae34")),
			create("Kai", Color("63c74d"), Color("5a6988"), Color("733e39"), Color("0099db")),
			create("Sol", Color("fee761"), Color("3e2731"), Color("ead4aa"), Color("e43b44")),
			create("Sombra", Color("262b44"), Color("181425"), Color("e8b796"), Color("e43b44")),
			create("Doc", Color("c0cbdc"), Color("3a4466"), Color("c28569"), Color("0099db")),
			create("Punk", Color("b55088"), Color("262b44"), Color("ead4aa"), Color("63c74d")),
			create("Obrero", Color("f77622"), Color("3a4466"), Color("733e39"), Color("fee761")),
		]
	return _presets


## Preset `index`, wrapping around the roster.
static func at(index: int) -> FighterLook:
	var all := presets()
	return all[posmod(index, all.size())]
