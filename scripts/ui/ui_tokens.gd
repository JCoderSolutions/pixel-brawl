class_name UiTokens
extends RefCounted

## The game's visual language as values (vault/docs/ui-style-guide.md): color
## roles from Endesga 32, the pixel fonts and their exact sizes, and the 4 px
## spacing grid. UiTheme builds assets/ui/theme.tres from these, and code that
## draws by hand (HUD, floating text) reads them too, so the whole game changes
## look from this one file.

# --- Colors by role (all Endesga 32, assets/palettes/endesga-32.hex) ---

const BG := Color("181425")
const SURFACE := Color("262b44")
const SURFACE_HI := Color("3a4466")
const BORDER := Color("5a6988")
const TEXT_MUTED := Color("8b9bb4")
const TEXT := Color("c0cbdc")
const TEXT_STRONG := Color("ffffff")
## Focus and the main action ("¡A pelear!").
const ACCENT := Color("feae34")
## Chosen option, winner, leader.
const ACCENT_HI := Color("fee761")
const DANGER := Color("e43b44")
const SUCCESS := Color("63c74d")
const INFO := Color("0099db")
## Behind panels drawn over something else (options, pause).
const SHADE := Color(BG, 0.85)

# --- Fonts: pixel fonts, only ever used at these sizes so every glyph pixel
# lands on a screen pixel ---

## Pixel Operator (CC0): text, buttons, rows. Designed at 16 px.
const FONT_BODY := preload("res://assets/fonts/PixelOperator.ttf")
## Pixel Operator 8 (CC0): hints and in-game labels. Designed at 8 px.
const FONT_SMALL := preload("res://assets/fonts/PixelOperator8.ttf")
## Jersey 10 (OFL): screen titles, logo and banners.
const FONT_DISPLAY := preload("res://assets/fonts/Jersey10-Regular.ttf")

const TEXT_SMALL := 8
const TEXT_BODY := 16
const TEXT_TITLE := 19
const TEXT_DISPLAY := 38

# --- Spacing and shape (base resolution 480x270, 4 px grid) ---

const GAP := 4
const GROUP_GAP := 8
const SCREEN_MARGIN := 16
const BUTTON_HEIGHT := 24
const SELECTOR_HEIGHT := 20
const CHIP_HEIGHT := 16
## Smallest thing a finger should have to hit.
const TOUCH_MIN := 24
const BORDER_WIDTH := 1
const FOCUS_WIDTH := 2

## Every size a Label or Button may use; the lint test holds the scenes to it.
const TEXT_SIZES: Array[int] = [TEXT_SMALL, TEXT_BODY, TEXT_TITLE, TEXT_DISPLAY]


## The Endesga 32 colors, read from the palette file.
static func palette() -> Array[Color]:
	var colors: Array[Color] = []
	var file := FileAccess.open("res://assets/palettes/endesga-32.hex", FileAccess.READ)
	if file == null:
		return colors
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty():
			colors.append(Color(line))
	return colors


## True if `color` (ignoring alpha) is one of the palette's.
static func in_palette(color: Color) -> bool:
	for swatch in palette():
		if swatch.to_html(false) == color.to_html(false):
			return true
	return false
