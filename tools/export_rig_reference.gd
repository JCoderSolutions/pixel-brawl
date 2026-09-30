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


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await _sheet("base", null, BASE_COLOR)
	for look in FighterLook.presets():
		await _sheet(look.name.to_lower(), look, look.shirt)
	print("OK: rig reference sheets in %s" % ProjectSettings.globalize_path(_out))
	quit()


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
			rig.set_process(false)
			rig.position = Vector2(column * CELL, row * CELL)
			rig.size = Vector2(CELL, CELL)
			rig.look = look
			rig.color = shirt
			rig.anim = row
			rig.anim_time = column / fps
			viewport.add_child(rig)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(_out.path_join(file_name + ".png"))
	if look == null:
		_save_poses(image)
	# 4x copy (nearest): AI tools read small references badly.
	image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(_out.path_join("x4"))
	image.save_png(_out.path_join("x4").path_join(file_name + ".png"))
	viewport.queue_free()
	await process_frame
