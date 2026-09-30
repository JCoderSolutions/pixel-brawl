extends SceneTree

## Checks AI-generated (or any) sprites and writes a clean, editable copy:
## native pixel size, Endesga 32 only, hard transparency. See PixelArtCheck.
##   godot --headless --path . -s tools/pixel_art_check.gd -- <png...> [--out <folder>]
## Without --out, only reports. Exit code 1 if any input is not editable.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var inputs: Array[String] = []
	var i := 0
	while i < args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
			i += 2
			continue
		inputs.append(args[i])
		i += 1
	if inputs.is_empty():
		print("Uso: tools/pixel_art_check.sh <imagen.png...> [--out carpeta]")
		quit(2)
		return
	var palette := PixelArtCheck.load_palette()
	var all_ok := true
	for path in inputs:
		var image := Image.load_from_file(path)
		if image == null:
			print("%s: no se pudo abrir" % path)
			all_ok = false
			continue
		image.convert(Image.FORMAT_RGBA8)
		var result := PixelArtCheck.report(image, palette)
		all_ok = all_ok and result.ok
		print("%s: %s (%dx%d, %d colores)" % [path, "EDITABLE" if result.ok else "NO EDITABLE",
				result.size.x, result.size.y, result.colors])
		for line in result.errors:
			print("  error: " + line)
		for line in result.warnings:
			print("  aviso: " + line)
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			var cleaned := PixelArtCheck.clean(image, palette, result.scale)
			var target := out.path_join(path.get_file().get_basename() + ".png")
			cleaned.save_png(target)
			var after := PixelArtCheck.report(cleaned, palette)
			print("  limpio -> %s (%dx%d, %d colores)" % [target, cleaned.get_width(), cleaned.get_height(), after.colors])
			for line in after.warnings:
				print("  aviso: " + line)
	quit(0 if all_ok else 1)
