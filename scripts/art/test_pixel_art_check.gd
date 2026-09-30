extends SceneTree

## Headless tests for PixelArtCheck: the game's own reference art passes, an
## AI-style output (upscaled, noisy, soft edges, off-palette) is caught and
## cleaned back to the exact native sprite, and the palette ships in a
## format pixel editors import.
## Run: godot --headless --path . -s scripts/art/test_pixel_art_check.gd

const REFERENCE_DIR := "res://assets/sprites/characters/reference/"
const GPL_PATH := "res://assets/palettes/endesga-32.gpl"

var _ok := true
var _palette: PackedColorArray


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_palette = PixelArtCheck.load_palette()
	_check(_palette.size() == 32, "the Endesga 32 palette loads (%d)" % _palette.size())
	_test_reference_art_is_editable()
	_test_ai_output_is_cleaned()
	_test_warnings()
	_test_gpl_palette()
	print("OK: reference art editable, AI-style output detected and cleaned to the native sprite, stray pixels warned, GIMP palette verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _cell(sheet: Image) -> Image:
	return sheet.get_region(Rect2i(0, 0, 32, 32))


func _same(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if pa.a8 == 0 and pb.a8 == 0:
				continue
			if pa.to_rgba32() != pb.to_rgba32():
				return false
	return true


func _test_reference_art_is_editable() -> void:
	for file_name in ["base.png", "bruno.png", "sombra.png"]:
		var result := PixelArtCheck.report(_load(REFERENCE_DIR + file_name), _palette)
		_check(result.ok, "%s is editable pixel art: %s" % [file_name, result.errors])
		_check(result.scale == 1, "%s is drawn at native size" % file_name)
	var pose := _load(REFERENCE_DIR + "poses/idle.png")
	_check(PixelArtCheck.detect_scale(pose, _palette) == 4, "the 4x pose image reads as 4x")


## What an image model returns: every art pixel an 8x8 block, colour noise,
## a soft semi-transparent halo and colours near, but not on, the palette.
func _test_ai_output_is_cleaned() -> void:
	var native := _cell(_load(REFERENCE_DIR + "bruno.png"))
	var ai := native.duplicate() as Image
	ai.resize(native.get_width() * 8, native.get_height() * 8, Image.INTERPOLATE_NEAREST)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in ai.get_height():
		for x in ai.get_width():
			var color := ai.get_pixel(x, y)
			if color.a8 == 0:
				if x > 0 and ai.get_pixel(x - 1, y).a8 == 255:
					ai.set_pixel(x, y, Color(0.1, 0.1, 0.1, 0.3))
				continue
			# Strong enough to flip some pixels to a neighbouring palette colour.
			ai.set_pixel(x, y, Color(clampf(color.r + rng.randf_range(-0.06, 0.06), 0, 1),
					clampf(color.g + rng.randf_range(-0.06, 0.06), 0, 1), clampf(color.b + rng.randf_range(-0.06, 0.06), 0, 1)))
	var before := PixelArtCheck.report(ai, _palette)
	_check(not before.ok, "the AI-style image is flagged")
	_check(before.scale == 8, "its 8x pixels are detected (%d)" % before.scale)
	_check(before.semi_transparent > 0 and before.off_palette > 0, "soft edges and off-palette colours are counted")
	var cleaned := PixelArtCheck.clean(ai, _palette)
	_check(cleaned.get_size() == native.get_size(), "cleaning returns the native size")
	_check(_same(cleaned, native), "cleaning restores the exact sprite")
	_check(PixelArtCheck.report(cleaned, _palette).ok, "the cleaned sprite passes")


func _test_warnings() -> void:
	# AI noise: single stray pixels scattered over a flat area.
	var noisy := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	noisy.fill(_palette[20])
	for y in range(1, 32, 3):
		for x in range(1, 32, 3):
			noisy.set_pixel(x, y, _palette[(x + y) % 5])
	var result := PixelArtCheck.report(noisy, _palette)
	_check(result.scale == 1, "a noisy sprite is native size")
	_check(result.orphans > 50, "stray pixels are counted (%d)" % result.orphans)
	_check(result.ok and not result.warnings.is_empty(), "stray pixels are a warning, not an error")
	var odd := Image.create(20, 30, false, Image.FORMAT_RGBA8)
	odd.fill(_palette[3])
	_check(not PixelArtCheck.report(odd, _palette).warnings.is_empty(), "sizes off the 16 px grid warn")


func _test_gpl_palette() -> void:
	var file := FileAccess.open(GPL_PATH, FileAccess.READ)
	_check(file != null, "endesga-32.gpl exists")
	if file == null:
		return
	_check(file.get_line() == "GIMP Palette", "the .gpl has the GIMP header")
	var colors := PackedColorArray()
	while not file.eof_reached():
		var parts := file.get_line().split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int():
			colors.append(Color8(parts[0].to_int(), parts[1].to_int(), parts[2].split("\t")[0].to_int()))
	_check(colors == _palette, "the .gpl has the same 32 colours as the .hex")
