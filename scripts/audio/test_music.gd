extends SceneTree

## Headless tests for the music (TASK-012): the generated tracks import as
## seamless loops, AudioManager.play_track() switches between them without
## restarting the one already playing, the menu plays the menu theme and a
## match plays the battle theme.
## Run: godot --headless --path . -s scripts/audio/test_music.gd

const AudioManagerScript := preload("res://scripts/audio/audio_manager.gd")
const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const ARENA_PATH := "res://scenes/maps/test_arena.tscn"

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_library()
	await _test_play_track()
	await _test_scenes_pick_their_theme()
	print("OK: looping menu and battle tracks, play_track switching without restarts, menu and match themes verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _test_library() -> void:
	for track in [&"menu", &"battle"]:
		_check(AudioManagerScript.MUSIC.has(track), "music library has %s" % track)
		var stream := AudioManagerScript.MUSIC.get(track) as AudioStreamWAV
		_check(stream != null, "%s is a WAV stream" % track)
		if stream == null:
			continue
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % track)
		_check(stream.get_length() >= 15.0 and stream.get_length() <= 40.0,
				"%s lasts 15-40 s (%.1f)" % [track, stream.get_length()])
		_check(stream.format == AudioStreamWAV.FORMAT_IMA_ADPCM, "%s is compressed for the web build" % track)


func _test_play_track() -> void:
	# A scene can boot before the autoload is ready: the request waits.
	var early = AudioManagerScript.new()
	early.play_track(&"battle")
	root.add_child(early)
	_check(early.current_track() == &"battle", "a track asked for before _ready plays once ready")
	early.queue_free()

	var manager = AudioManagerScript.new()
	root.add_child(manager)
	var player: AudioStreamPlayer = manager.get_node("Music")
	manager.play_track(&"menu", 0.1)
	_check(manager.is_music_playing(), "play_track starts the music")
	_check(manager.current_track() == &"menu", "current track is the menu theme")
	_check(player.stream == AudioManagerScript.MUSIC[&"menu"], "the menu stream is loaded")
	await create_timer(0.25).timeout
	var target: float = AudioManagerScript.MUSIC_VOLUME_DB[&"menu"]
	_check(absf(player.volume_db - target) < 0.5, "menu fades in to its mix volume (%.1f dB)" % player.volume_db)
	manager.play_track(&"menu", 0.1)
	_check(absf(player.volume_db - target) < 0.5, "asking for the playing track does not restart it")
	manager.play_track(&"battle", 0.1)
	_check(manager.current_track() == &"battle", "switching tracks changes the current one")
	_check(player.stream == AudioManagerScript.MUSIC[&"battle"], "the battle stream is loaded")
	manager.stop_music(0.0)
	_check(manager.current_track() == &"", "stopping clears the current track")
	manager.queue_free()
	await process_frame


func _test_scenes_pick_their_theme() -> void:
	var audio: Node = root.get_node("/root/AudioManager")
	var menu: Node = load(MENU_PATH).instantiate()
	root.add_child(menu)
	await process_frame
	_check(audio.current_track() == &"menu", "the main menu plays the menu theme")
	menu.queue_free()
	await process_frame

	var arena: Node = load(ARENA_PATH).instantiate()
	arena.get_node("TouchControls").visibility = TouchControls.Visibility.NEVER
	root.add_child(arena)
	await process_frame
	_check(audio.current_track() == &"battle", "a match plays the battle theme")
	arena.queue_free()
	await process_frame
	audio.stop_music(0.0)
