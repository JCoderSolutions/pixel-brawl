class_name UiTheme
extends RefCounted

## Builds the game-wide Theme from UiTokens. The result is saved to
## assets/ui/theme.tres (tools/build_ui_theme.gd) and set as the project's
## custom theme, so every Control in the game uses it; test_ui_theme checks
## the saved file still matches this code.
##
## Components (type variations): Button (secondary), ButtonPrimary, Label,
## LabelSmall, LabelTitle, LabelDisplay, PanelCard, PanelOverlay. States:
## normal, hover, focus, pressed (and toggled on = chosen), disabled.

const PATH := "res://assets/ui/theme.tres"


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = UiTokens.FONT_BODY
	theme.default_font_size = UiTokens.TEXT_BODY
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_ranges(theme)
	_menus(theme)
	return theme


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.TEXT)
	theme.set_color("font_outline_color", "Label", UiTokens.BG)
	_variation(theme, "LabelSmall", "Label", UiTokens.FONT_SMALL, UiTokens.TEXT_SMALL, UiTokens.TEXT_MUTED)
	_variation(theme, "LabelTitle", "Label", UiTokens.FONT_DISPLAY, UiTokens.TEXT_TITLE, UiTokens.TEXT_STRONG)
	_variation(theme, "LabelDisplay", "Label", UiTokens.FONT_DISPLAY, UiTokens.TEXT_DISPLAY, UiTokens.TEXT_STRONG)
	theme.set_constant("outline_size", "LabelDisplay", 2)


static func _variation(theme: Theme, name: StringName, base: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


## Secondary buttons: dark surface with a 1 px border. The focus ring is an
## accent border drawn on top; pressed sinks the text 1 px; a toggle button
## that is on (a chosen option) fills with the highlight.
static func _buttons(theme: Theme) -> void:
	_button_type(theme, "Button", UiTokens.SURFACE, UiTokens.BORDER, UiTokens.TEXT)
	for type in ["OptionButton", "CheckButton", "CheckBox"]:
		_button_type(theme, type, UiTokens.SURFACE, UiTokens.BORDER, UiTokens.TEXT)
	theme.set_stylebox("normal", "CheckButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	theme.set_stylebox("hover", "CheckButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	theme.set_stylebox("pressed", "CheckButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	theme.set_color("font_pressed_color", "CheckButton", UiTokens.TEXT_STRONG)

	theme.set_type_variation("ButtonPrimary", "Button")
	_button_type(theme, "ButtonPrimary", UiTokens.ACCENT, UiTokens.ACCENT, UiTokens.BG)
	theme.set_stylebox("hover", "ButtonPrimary", _box(UiTokens.ACCENT_HI, UiTokens.ACCENT_HI, UiTokens.BORDER_WIDTH))
	theme.set_stylebox("focus", "ButtonPrimary", _box(Color(0, 0, 0, 0), UiTokens.TEXT_STRONG, UiTokens.FOCUS_WIDTH, false))
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "ButtonPrimary", UiTokens.BG)


static func _button_type(theme: Theme, type: StringName, fill: Color, edge: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, _box(fill, edge, UiTokens.BORDER_WIDTH))
	theme.set_stylebox("hover", type, _box(UiTokens.SURFACE_HI, edge, UiTokens.BORDER_WIDTH))
	var pressed := _box(UiTokens.ACCENT_HI, UiTokens.ACCENT_HI, UiTokens.BORDER_WIDTH)
	pressed.content_margin_top += 1
	pressed.content_margin_bottom -= 1
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, _box(UiTokens.SURFACE, UiTokens.SURFACE_HI, UiTokens.BORDER_WIDTH))
	theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), UiTokens.ACCENT, UiTokens.FOCUS_WIDTH, false))
	theme.set_color("font_color", type, text)
	theme.set_color("font_hover_color", type, UiTokens.TEXT_STRONG)
	theme.set_color("font_focus_color", type, UiTokens.TEXT_STRONG)
	theme.set_color("font_pressed_color", type, UiTokens.BG)
	theme.set_color("font_hover_pressed_color", type, UiTokens.BG)
	theme.set_color("font_disabled_color", type, UiTokens.TEXT_MUTED)
	theme.set_color("font_outline_color", type, UiTokens.BG)
	theme.set_constant("h_separation", type, UiTokens.GAP)


static func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _box(UiTokens.SURFACE, UiTokens.BORDER, UiTokens.BORDER_WIDTH))
	theme.set_stylebox("panel", "PanelContainer", _box(UiTokens.SURFACE, UiTokens.BORDER, UiTokens.BORDER_WIDTH, true, UiTokens.GROUP_GAP))
	theme.set_type_variation("PanelCard", "PanelContainer")
	theme.set_stylebox("panel", "PanelCard", _box(UiTokens.SURFACE, UiTokens.BORDER, UiTokens.BORDER_WIDTH, true, UiTokens.GAP))
	theme.set_type_variation("PanelOverlay", "PanelContainer")
	theme.set_stylebox("panel", "PanelOverlay", _box(UiTokens.SHADE, Color(0, 0, 0, 0), 0, true, UiTokens.SCREEN_MARGIN))
	for container in ["BoxContainer", "HBoxContainer", "VBoxContainer"]:
		theme.set_constant("separation", container, UiTokens.GAP)
	theme.set_constant("h_separation", "GridContainer", UiTokens.GAP)
	theme.set_constant("v_separation", "GridContainer", UiTokens.GAP)


## Health bars and volume sliders: a dark track with a 1 px border.
static func _ranges(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(UiTokens.BG, UiTokens.BORDER, UiTokens.BORDER_WIDTH))
	theme.set_stylebox("fill", "ProgressBar", _box(UiTokens.SUCCESS, UiTokens.SUCCESS, 0))
	theme.set_color("font_color", "ProgressBar", UiTokens.TEXT)
	var track := _box(UiTokens.BG, UiTokens.BORDER, UiTokens.BORDER_WIDTH, true, 2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(UiTokens.ACCENT, UiTokens.ACCENT, 0, true, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(UiTokens.ACCENT_HI, UiTokens.ACCENT_HI, 0, true, 2))
	theme.set_icon("grabber", "HSlider", _rect_icon(Vector2i(6, 12), UiTokens.TEXT_STRONG, UiTokens.BG))
	theme.set_icon("grabber_highlight", "HSlider", _rect_icon(Vector2i(6, 12), UiTokens.ACCENT_HI, UiTokens.BG))
	theme.set_icon("grabber_disabled", "HSlider", _rect_icon(Vector2i(6, 12), UiTokens.TEXT_MUTED, UiTokens.BG))
	theme.set_icon("checked", "CheckButton", _switch_icon(true))
	theme.set_icon("unchecked", "CheckButton", _switch_icon(false))
	theme.set_icon("checked_mirrored", "CheckButton", _switch_icon(true))
	theme.set_icon("unchecked_mirrored", "CheckButton", _switch_icon(false))


static func _menus(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _box(UiTokens.SURFACE, UiTokens.BORDER, UiTokens.BORDER_WIDTH, true, UiTokens.GAP))
	theme.set_stylebox("hover", "PopupMenu", _box(UiTokens.SURFACE_HI, UiTokens.ACCENT, UiTokens.BORDER_WIDTH))
	theme.set_color("font_color", "PopupMenu", UiTokens.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", UiTokens.TEXT_STRONG)
	theme.set_icon("arrow", "OptionButton", _arrow_icon())


## Square corners, no antialiasing: pixel-exact at any integer scale.
static func _box(fill: Color, edge: Color, width: int, draw_center := true, padding := -1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = draw_center
	box.border_color = edge
	box.set_border_width_all(width)
	box.anti_aliasing = false
	var margin_x := padding if padding >= 0 else UiTokens.GROUP_GAP
	var margin_y := padding if padding >= 0 else UiTokens.GAP
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


static func _rect_icon(size: Vector2i, fill: Color, edge: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(edge)
	image.fill_rect(Rect2i(Vector2i.ONE, size - Vector2i(2, 2)), fill)
	return ImageTexture.create_from_image(image)


## 16x8 on/off switch: the knob sits right and lit when on.
static func _switch_icon(on: bool) -> ImageTexture:
	var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	image.fill(UiTokens.BORDER)
	image.fill_rect(Rect2i(1, 1, 14, 6), UiTokens.ACCENT if on else UiTokens.BG)
	image.fill_rect(Rect2i(9 if on else 1, 1, 6, 6), UiTokens.TEXT_STRONG if on else UiTokens.TEXT_MUTED)
	return ImageTexture.create_from_image(image)


## 7x4 down arrow for dropdowns.
static func _arrow_icon() -> ImageTexture:
	var image := Image.create(7, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in 4:
		image.fill_rect(Rect2i(row, row, 7 - row * 2, 1), UiTokens.TEXT)
	return ImageTexture.create_from_image(image)
