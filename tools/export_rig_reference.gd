extends SceneTree

## Exports the fighter's native-shape poses as PNG sprite sheets: one row per
## animation (FighterRig.Anim order), one 32x32 cell per frame, feet on the
## bottom edge, facing right. They are the exact size and proportions the game
## expects, so an artist (or an AI tool, as a reference image) can draw over
## them and every character keeps the same body. See vault/docs/asset-pipeline.md.
## Needs a renderer: tools/export_rig_reference.sh runs it under Xvfb.
##   godot --rendering-driver opengl3 --path . -s tools/export_rig_reference.gd -- <out_dir>

const CELL := 32
## [frames, fps] per animation, in FighterRig.Anim order.
const FRAMES := [
	[4, 6], [6, 12], [2, 10], [2, 10], [1, 1], [3, 16], [2, 10], [1, 1], [4, 8], [2, 12],
	[2, 8], [1, 1], [4, 16], [3, 16], [3, 16], [2, 12], [2, 10], [2, 10], [2, 6],
]
## Grey stand-in for the shirt on the base mannequin.
const BASE_COLOR := Color("8b9bb4")

var _out := "user://rig_reference"
var _palette := PixelArtCheck.load_palette()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_save_guide()
	await _sheet("base", null, BASE_COLOR)
	for look in FighterLook.presets():
		await _sheet(look.name.to_lower(), look, look.shirt)
	print("OK: rig reference sheets in %s" % ProjectSettings.globalize_path(_out))
	quit()


## guide.png (32x32) and guide_48.png (48x48, room for swings and kicks,
## like the 16x32-in-48x64 packs): the fighter's frame, for a guide layer in
## a pixel editor. Cyan box = hurtbox (16x28, player.tscn): the body goes
## inside it; hair up to 4 px above it, and gloves, kicks or a weapon may
## stick out anywhere in the frame. Green row = the ground (feet on the last
## row). Red = centre column. Yellow ticks on the left = chibi proportions:
## head down to the first tick, torso to the second, legs below.
func _save_guide() -> void:
	DirAccess.make_dir_recursive_absolute(_out.path_join("x4"))
	for size in [CELL, 48]:
		var guide := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var hurt := Rect2i(size / 2 - 8, size - 28, 16, 28)
		for x in range(hurt.position.x, hurt.end.x):
			guide.set_pixel(x, hurt.position.y, Color("2ce8f5"))
		for y in range(hurt.position.y, hurt.end.y):
			guide.set_pixel(hurt.position.x, y, Color("2ce8f5"))
			guide.set_pixel(hurt.end.x - 1, y, Color("2ce8f5"))
		for y in range(0, size, 2):
			guide.set_pixel(size / 2, y, Color("e43b44"))
		for x in size:
			guide.set_pixel(x, size - 1, Color("63c74d"))
		for y in [size - 28 + 11, size - 28 + 19]:
			guide.set_pixel(0, y, Color("fee761"))
			guide.set_pixel(1, y, Color("fee761"))
		var file_name: String = "guide.png" if size == CELL else "guide_%d.png" % size
		guide.save_png(_out.path_join(file_name))
		guide.resize(size * 4, size * 4, Image.INTERPOLATE_NEAREST)
		guide.save_png(_out.path_join("x4").path_join(file_name))


## One file per pose for img2img tools (Retro Diffusion's input image takes
## a single, opaque picture): the first frame of each animation of the base
## mannequin, on white, 4x (128x128). poses/idle.png, poses/run.png...
func _save_poses(sheet: Image) -> void:
	var folder := _out.path_join("poses")
	DirAccess.make_dir_recursive_absolute(folder)
	for row in FRAMES.size():
		var pose := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		pose.fill(Color.WHITE)
		pose.blend_rect(sheet, Rect2i(0, row * CELL, CELL, CELL), Vector2i.ZERO)
		pose.convert(Image.FORMAT_RGB8)
		pose.resize(CELL * 4, CELL * 4, Image.INTERPOLATE_NEAREST)
		pose.save_png(folder.path_join(String(FighterRig.anim_name(row)) + ".png"))


func _sheet(file_name: String, look: FighterLook, shirt: Color) -> void:
	var columns := 0
	for entry in FRAMES:
		columns = maxi(columns, entry[0])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL * columns, CELL * FRAMES.size())
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	for row in FRAMES.size():
		var count: int = FRAMES[row][0]
		var fps: float = FRAMES[row][1]
		for column in count:
			var rig := FighterRig.new()
			rig.position = Vector2(column * CELL, row * CELL)
			rig.size = Vector2(CELL, CELL)
			rig.look = look
			rig.color = shirt
			rig.anim = row
			rig.anim_time = column / fps
			viewport.add_child(rig)
			# After add_child: _ready turns _process back on, and it would
			# advance anim_time with the real clock (a different frame per run).
			rig.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	# The rig shades its colours (darkened/lightened): snap them back onto
	# Endesga 32 so the sheet opens in any editor with the palette intact.
	image = PixelArtCheck.clean(image, _palette, 1)
	image.save_png(_out.path_join(file_name + ".png"))
	if look == null:
		_save_poses(image)
	# 4x copy (nearest): AI tools read small references badly.
	image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(_out.path_join("x4"))
	image.save_png(_out.path_join("x4").path_join(file_name + ".png"))
	viewport.queue_free()
	await process_frame
