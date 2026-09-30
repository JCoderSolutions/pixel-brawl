class_name PixelArtCheck
extends RefCounted

## Checks that a sprite (usually an AI output) is real, editable pixel art
## and cleans it when it is not. Editable means that any pixel editor
## (LibreSprite, Aseprite, Pixelorama) sees exactly the pixels the game
## draws: one art pixel per image pixel, only Endesga 32 colours, fully
## opaque or fully transparent, and little single-pixel noise.
## CLI: tools/pixel_art_check.sh. Guide: vault/docs/asset-pipeline.md.

const PALETTE_PATH := "res://assets/palettes/endesga-32.hex"
## Fighter cells and sheets are laid out on this grid.
const CELL := 32
## Alpha at or above this is opaque once cleaned; below it, transparent.
const ALPHA_CUT := 0.5
## In an image drawn N times bigger, colour changes between neighbours
## pile up on the NxN grid lines while noise spreads evenly. A scale is
## accepted when changes are this many times denser on the grid lines than
## on the busiest other line offset.
const GRID_CONTRAST := 1.5
## Largest pixel size looked for (AI tools upscale 4x-16x).
const MAX_SCALE := 16
## More colours than this in one fighter is hard to recolour by hand.
const MAX_EASY_COLORS := 16
## Share of visible pixels with no same-coloured neighbour tolerated (eyes
## and highlights are single pixels; AI noise is many).
const MAX_ORPHAN_SHARE := 0.05


static func load_palette(path := PALETTE_PATH) -> PackedColorArray:
	var colors := PackedColorArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return colors
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_valid_html_color():
			colors.append(Color(line))
	return colors


## Nearest palette colour ("redmean" weighted RGB, close to how eyes rate it).
static func nearest(color: Color, palette: PackedColorArray) -> Color:
	var best := palette[0]
	var best_distance := INF
	for candidate in palette:
		var mean := (color.r + candidate.r) * 0.5
		var dr := color.r - candidate.r
		var dg := color.g - candidate.g
		var db := color.b - candidate.b
		var distance := (2.0 + mean) * dr * dr + 4.0 * dg * dg + (3.0 - mean) * db * db
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return Color(best, 1.0)


## The colour a pixel becomes once cleaned: transparent or a palette colour.
static func snap(color: Color, palette: PackedColorArray) -> Color:
	if color.a < ALPHA_CUT:
		return Color(0, 0, 0, 0)
	return nearest(color, palette)


## Size in image pixels of one art pixel: 1 for native art, N when a tool
## drew every pixel as an NxN block. Only whole divisors of the image size.
static func detect_scale(image: Image, palette: PackedColorArray) -> int:
	var snapped := _snapped(image, palette)
	var width := image.get_width()
	var height := image.get_height()
	for scale in range(mini(MAX_SCALE, mini(width, height)), 1, -1):
		if width % scale != 0 or height % scale != 0:
			continue
		# Changes per line offset (x % scale for columns, y % scale for rows).
		var changes := PackedInt32Array()
		changes.resize(scale)
		for y in height:
			for x in width:
				var here := snapped[y * width + x]
				if x > 0 and snapped[y * width + x - 1] != here:
					changes[x % scale] += 1
				if y > 0 and snapped[(y - 1) * width + x] != here:
					changes[y % scale] += 1
		var busiest_other := 0
		for offset in range(1, scale):
			busiest_other = maxi(busiest_other, changes[offset])
		if changes[0] > 0 and changes[0] >= GRID_CONTRAST * busiest_other:
			return scale
	return 1


## Native-size copy: one pixel per block (its most common colour), every
## pixel a palette colour or fully transparent.
static func clean(image: Image, palette: PackedColorArray, scale := 0) -> Image:
	if scale <= 0:
		scale = detect_scale(image, palette)
	var snapped := _snapped(image, palette)
	var width := image.get_width() / scale
	var height := image.get_height() / scale
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var counts := _block_counts(snapped, image.get_width(), x * scale, y * scale, scale)
			out.set_pixel(x, y, _unpack(_mode_key(counts)))
	return out


## What an editor would find wrong with the image. `ok` is true when it can
## go straight into the game and be edited pixel by pixel.
static func report(image: Image, palette: PackedColorArray) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var lookup := {}
	for color in palette:
		lookup[color.to_rgba32() | 0xff] = true
	var colors := {}
	var semi := 0
	var off_palette := 0
	var visible := 0
	for y in height:
		for x in width:
			var color := image.get_pixel(x, y)
			if color.a8 == 0:
				continue
			visible += 1
			if color.a8 < 255:
				semi += 1
			var key := Color(color, 1.0).to_rgba32()
			colors[key] = true
			if not lookup.has(key):
				off_palette += 1
	var scale := detect_scale(image, palette)
	var orphans := orphan_count(image) if scale == 1 else 0
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if scale > 1:
		errors.append("cada pixel del arte ocupa %dx%d: achicar a %dx%d (sin suavizado)" % [scale, scale, width / scale, height / scale])
	if semi > 0:
		errors.append("%d pixeles semitransparentes (bordes suavizados)" % semi)
	if off_palette > 0:
		errors.append("%d pixeles fuera de la paleta Endesga 32" % off_palette)
	var native := Vector2i(width, height) / scale
	if native.x % CELL != 0 or native.y % CELL != 0:
		warnings.append("%dx%d no es múltiplo de %d: los luchadores van en cuadros de 32x32" % [native.x, native.y, CELL])
	if colors.size() > MAX_EASY_COLORS:
		warnings.append("%d colores: más de %d cuesta retocar y recolorear" % [colors.size(), MAX_EASY_COLORS])
	if visible > 0 and float(orphans) / visible > MAX_ORPHAN_SHARE:
		warnings.append("%d pixeles sueltos (ruido): limpiarlos a mano" % orphans)
	return {
		"size": Vector2i(width, height),
		"scale": scale,
		"colors": colors.size(),
		"semi_transparent": semi,
		"off_palette": off_palette,
		"orphans": orphans,
		"errors": errors,
		"warnings": warnings,
		"ok": errors.is_empty(),
	}


## Visible pixels none of whose 8 neighbours share their colour.
static func orphan_count(image: Image) -> int:
	var width := image.get_width()
	var height := image.get_height()
	var count := 0
	for y in height:
		for x in width:
			var color := image.get_pixel(x, y)
			if color.a8 == 0:
				continue
			var alone := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < width and ny < height \
							and image.get_pixel(nx, ny).to_rgba32() == color.to_rgba32():
						alone = false
			if alone:
				count += 1
	return count


## Palette-snapped pixels as packed RGBA ints (0 = transparent).
static func _snapped(image: Image, palette: PackedColorArray) -> PackedInt64Array:
	var cache := {}
	var out := PackedInt64Array()
	out.resize(image.get_width() * image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var key := color.to_rgba32()
			if not cache.has(key):
				var snapped := snap(color, palette)
				cache[key] = snapped.to_rgba32() if snapped.a > 0.0 else 0
			out[y * image.get_width() + x] = cache[key]
	return out


static func _block_counts(pixels: PackedInt64Array, width: int, left: int, top: int, size: int) -> Dictionary:
	var counts := {}
	for y in range(top, top + size):
		for x in range(left, left + size):
			var key := pixels[y * width + x]
			counts[key] = counts.get(key, 0) + 1
	return counts


static func _mode_key(counts: Dictionary) -> int:
	var best_key := 0
	var best := -1
	for key in counts:
		if counts[key] > best:
			best = counts[key]
			best_key = key
	return best_key


static func _unpack(key: int) -> Color:
	if key == 0:
		return Color(0, 0, 0, 0)
	return Color.hex(key)
