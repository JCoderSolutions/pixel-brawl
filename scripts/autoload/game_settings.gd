class_name GameSettings
extends RefCounted

## Player options kept between sessions in `path` (a ConfigFile; on the web
## build it lives in the browser's storage). The main menu loads and applies
## them on boot; the options panel edits them and saves on every change.

const AudioManagerScript := preload("res://scripts/audio/audio_manager.gd")

## 0..1 like the sliders; 0 mutes the bus.
static var music_volume := 1.0
static var sfx_volume := 1.0
static var fullscreen := false
## Read by TouchControls whose own `visibility` is AUTO.
static var touch_mode := TouchControls.Visibility.AUTO
static var path := "user://settings.cfg"


static func reset() -> void:
	music_volume = 1.0
	sfx_volume = 1.0
	fullscreen = false
	touch_mode = TouchControls.Visibility.AUTO


## Reads the saved options; a missing or damaged file keeps the defaults.
static func load_saved() -> void:
	reset()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	music_volume = _volume(file.get_value("audio", "music", music_volume))
	sfx_volume = _volume(file.get_value("audio", "sfx", sfx_volume))
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))
	var mode = file.get_value("display", "touch_mode", touch_mode)
	touch_mode = mode if mode is int and mode in TouchControls.Visibility.values() else TouchControls.Visibility.AUTO


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "touch_mode", touch_mode)
	var error := file.save(path)
	if error != OK:
		push_warning("GameSettings: could not save %s (%s)" % [path, error_string(error)])


## Pushes the volumes to the audio buses and the window to fullscreen.
static func apply() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var audio := tree.root.get_node_or_null("/root/AudioManager") if tree != null else null
	if audio != null:
		audio.set_bus_volume(AudioManagerScript.BUS_MUSIC, music_volume)
		audio.set_bus_volume(AudioManagerScript.BUS_SFX, sfx_volume)
	apply_fullscreen()


## Boot only ever enters fullscreen: phones and web pages that start full
## screen stay that way while the option is off. Leaving it takes the player
## switching the option off (`user_toggled`).
static func apply_fullscreen(user_toggled := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full and user_toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func _volume(value) -> float:
	return clampf(float(value), 0.0, 1.0) if value is float or value is int else 1.0
