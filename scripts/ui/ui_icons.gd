class_name UiIcons
extends RefCounted

## 8x8 pixel icons for the UI, drawn from text maps in the palette so they
## need no image files: "#" is the icon color, "x" the dark detail (bg) and
## "." clear. Swap a map for real art later without touching the screens.

const KEYBOARD := [
	"........",
	"########",
	"#x#x#x##",
	"########",
	"##x#x#x#",
	"########",
	"#xxxxx##",
	"########",
]
const PAD := [
	"........",
	".######.",
	"##x###x#",
	"#xxx#x#x",
	"##x###x#",
	"########",
	"###..###",
	".##..##.",
]
const BOT := [
	"...##...",
	"..####..",
	"########",
	"#x####x#",
	"########",
	"#.xxxx.#",
	"########",
	"..#..#..",
]

static var _cache := {}


## The icon for `map` in `color`, cached.
static func texture(map: Array, color := UiTokens.TEXT) -> ImageTexture:
	var key := "%s|%s" % [map.hash(), color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			match row[x]:
				"#":
					image.set_pixel(x, y, color)
				"x":
					image.set_pixel(x, y, UiTokens.BG)
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


## Keyboard for keyboard halves (and keyboard-or-pad), pad for gamepads.
static func for_scheme(scheme: int) -> Array:
	return PAD if ControlSchemes.pad_of(scheme) >= 0 and scheme != ControlSchemes.Scheme.KEYS_OR_PAD else KEYBOARD


## An 8x8 TextureRect showing `map`, pixel-exact.
static func rect(map: Array, color := UiTokens.TEXT) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(map, color)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(8, 8)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon
