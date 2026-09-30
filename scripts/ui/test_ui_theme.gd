extends SceneTree

## Headless tests for the UI system (TASK-024, vault/docs/ui-style-guide.md):
## the project uses the saved theme, the saved theme matches what UiTheme
## builds from UiTokens, the color roles come from Endesga 32, the pixel fonts
## cover Spanish and import without antialiasing, and no scene sets its own
## font size or adds colors outside the tokens.
## Run: godot --headless --path . -s scripts/ui/test_ui_theme.gd

const SPANISH := "¡¿ñÑáéíóúÁÉÍÓÚü"
## Folders held to the rule "no font sizes of your own".
const SIZE_LINT_DIRS := ["res://scenes", "res://scripts"]
## Files allowed to set sizes: the theme itself, the touch buttons (they draw
## their label scaled to the button) and the tests.
const SIZE_LINT_SKIP := ["ui_theme.gd", "touch_action_button.gd"]
## Color literals still left in the UI screens, per file. Fase 4 of TASK-024
## moves them to UiTokens; the count may only go down.
const COLOR_BASELINE := {
	"res://scenes/ui/scoreboard.gd": 3,
	"res://scenes/ui/main_menu.tscn": 1,
	"res://scenes/ui/options_menu.tscn": 1,
	"res://scenes/ui/winner_screen.tscn": 1,
	"res://scenes/ui/touch/touch_controls.tscn": 5,
}

var _ok := true


func _init() -> void:
	_test_project_theme()
	_test_saved_theme_matches_tokens()
	_test_palette_roles()
	_test_fonts()
	_test_no_font_sizes()
	_test_no_new_colors()
	print("OK: project theme, saved theme in sync with the tokens, palette roles, pixel fonts with Spanish glyphs and the font size and color lint verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _test_project_theme() -> void:
	_check(ProjectSettings.get_setting("gui/theme/custom") == UiTheme.PATH, "the project uses the UI theme")
	_check(load(UiTheme.PATH) is Theme, "the theme file loads")


## Rebuild the theme from the tokens and compare it item by item with the
## saved one: a token changed without running tools/build_ui_theme.gd fails.
func _test_saved_theme_matches_tokens() -> void:
	var saved: Theme = load(UiTheme.PATH)
	var built := UiTheme.build()
	_check(saved.default_font == built.default_font and saved.default_font_size == built.default_font_size,
			"default font and size")
	for type in built.get_type_list():
		_check(saved.get_type_variation_base(type) == built.get_type_variation_base(type), "%s variation base" % type)
		for name in built.get_color_list(type):
			_check(saved.get_color(name, type).is_equal_approx(built.get_color(name, type)), "%s.%s color" % [type, name])
		for name in built.get_constant_list(type):
			_check(saved.get_constant(name, type) == built.get_constant(name, type), "%s.%s constant" % [type, name])
		for name in built.get_font_size_list(type):
			_check(saved.get_font_size(name, type) == built.get_font_size(name, type), "%s.%s size" % [type, name])
		for name in built.get_font_list(type):
			_check(saved.get_font(name, type) == built.get_font(name, type), "%s.%s font" % [type, name])
		for name in built.get_stylebox_list(type):
			var a := saved.get_stylebox(name, type) as StyleBoxFlat
			var b := built.get_stylebox(name, type) as StyleBoxFlat
			_check(a != null and a.bg_color.is_equal_approx(b.bg_color) and a.border_color.is_equal_approx(b.border_color) \
					and a.border_width_top == b.border_width_top and a.draw_center == b.draw_center \
					and a.content_margin_top == b.content_margin_top,
					"%s.%s style box (run tools/build_ui_theme.gd after changing a token)" % [type, name])
	_check(saved.has_font_size("font_size", "LabelTitle") and saved.has_stylebox("normal", "ButtonPrimary"),
			"the theme has the title and primary button variations")


func _test_palette_roles() -> void:
	_check(UiTokens.palette().size() == 32, "Endesga 32 has 32 colors (%d)" % UiTokens.palette().size())
	for role in [UiTokens.BG, UiTokens.SURFACE, UiTokens.SURFACE_HI, UiTokens.BORDER, UiTokens.TEXT_MUTED,
			UiTokens.TEXT, UiTokens.TEXT_STRONG, UiTokens.ACCENT, UiTokens.ACCENT_HI, UiTokens.DANGER,
			UiTokens.SUCCESS, UiTokens.INFO, UiTokens.SHADE]:
		_check(UiTokens.in_palette(role), "color role %s is from Endesga 32" % role.to_html(false))


func _test_fonts() -> void:
	for font in [UiTokens.FONT_BODY, UiTokens.FONT_SMALL, UiTokens.FONT_DISPLAY]:
		var file := font as FontFile
		var missing := ""
		for c in SPANISH:
			if not file.has_char(c.unicode_at(0)):
				missing += c
		_check(missing.is_empty(), "%s has every Spanish glyph (missing %s)" % [file.resource_path, missing])
		_check(file.antialiasing == TextServer.FONT_ANTIALIASING_NONE and file.hinting == TextServer.HINTING_NONE,
				"%s imports pixel-exact (no antialias, no hinting)" % file.resource_path)


func _test_no_font_sizes() -> void:
	var offenders: Array[String] = []
	for dir in SIZE_LINT_DIRS:
		for path in _files(dir):
			if path.get_file().begins_with("test_") or path.get_file() in SIZE_LINT_SKIP:
				continue
			var text := FileAccess.get_file_as_string(path)
			if text.contains("theme_override_font_sizes/") or text.contains("add_theme_font_size_override"):
				offenders.append(path)
	_check(offenders.is_empty(), "no scene sets its own font size, they use the theme variations (%s)" % [offenders])


func _test_no_new_colors() -> void:
	for path in _files("res://scenes/ui"):
		if path.get_file().begins_with("touch_test"):
			continue
		var count := FileAccess.get_file_as_string(path).count("Color(")
		var allowed: int = COLOR_BASELINE.get(path, 0)
		_check(count <= allowed, "%s adds color literals (%d > %d): use UiTokens" % [path, count, allowed])


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return out
	for file in access.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir.path_join(file))
	for sub in access.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out
