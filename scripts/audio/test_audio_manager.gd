extends SceneTree

## Headless tests for the AudioManager autoload (TASK-012): buses, effect
## library, voice pool, throttling, pitch jitter, volume and music fades.
## Run: godot --headless --path . -s scripts/audio/test_audio_manager.gd

const AudioManagerScript := preload("res://scripts/audio/audio_manager.gd")

var _ok := true


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_buses()
	_test_library()
	_test_play_and_pool()
	_test_throttle()
	_test_volume()
	await _test_music()
	print("OK: audio buses, sfx library, voice pool, throttle, pitch jitter, bus volume and music fades verified" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_ok = false


func _make_manager(voices := 4) -> Node:
	var manager = AudioManagerScript.new()
	manager.voices = voices
	manager.min_interval = 0.0
	root.add_child(manager)
	return manager


func _test_buses() -> void:
	AudioManagerScript.ensure_buses()
	AudioManagerScript.ensure_buses()
	for bus_name in [&"Music", &"SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		_check(index != -1, "bus %s exists" % bus_name)
		_check(AudioServer.get_bus_send(index) == &"Master", "bus %s routes to Master" % bus_name)
	var count := 0
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == "SFX":
			count += 1
	_check(count == 1, "ensure_buses is idempotent")


func _test_library() -> void:
	for sfx_name in AudioManagerScript.SFX:
		var stream: AudioStream = AudioManagerScript.SFX[sfx_name]
		_check(stream is AudioStreamWAV, "%s is a WAV stream" % sfx_name)
		_check(stream.get_length() > 0.05 and stream.get_length() < 1.5, "%s has a short, non-empty length" % sfx_name)
	for needed in [&"punch", &"hit", &"shot", &"explosion", &"jump", &"death", &"block_break"]:
		_check(AudioManagerScript.SFX.has(needed), "library has %s" % needed)


func _test_play_and_pool() -> void:
	var manager := _make_manager(3)
	var played: Array[StringName] = []
	manager.sfx_played.connect(func(n: StringName) -> void: played.append(n))
	var first: AudioStreamPlayer = manager.play_sfx(&"punch")
	_check(first != null and first.stream == AudioManagerScript.SFX[&"punch"], "play_sfx loads the stream in a voice")
	_check(first.bus == &"SFX", "effects play on the SFX bus")
	_check(absf(first.pitch_scale - 1.0) <= manager.pitch_jitter + 0.001, "pitch jitter stays within range")
	var second: AudioStreamPlayer = manager.play_sfx(&"shot")
	var third: AudioStreamPlayer = manager.play_sfx(&"jump")
	var fourth: AudioStreamPlayer = manager.play_sfx(&"land")
	_check(second != first and third != second, "consecutive effects use different voices")
	_check(fourth == first, "the oldest voice is reused when the pool is full")
	_check(played == [&"punch", &"shot", &"jump", &"land"], "sfx_played reports each effect")
	_check(manager.play_sfx(&"nope") == null, "unknown effects are ignored")
	manager.queue_free()


func _test_throttle() -> void:
	var manager := _make_manager()
	manager.min_interval = 10.0
	_check(manager.play_sfx(&"block_break") != null, "first break plays")
	_check(manager.play_sfx(&"block_break") == null, "an immediate repeat is throttled")
	_check(manager.play_sfx(&"explosion") != null, "throttling is per effect")
	manager.queue_free()


func _test_volume() -> void:
	var manager := _make_manager()
	manager.set_bus_volume(&"SFX", 0.5)
	_check(absf(manager.get_bus_volume(&"SFX") - 0.5) < 0.01, "bus volume round-trips as linear")
	manager.set_bus_volume(&"Music", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "volume 0 mutes the bus")
	_check(manager.get_bus_volume(&"Music") == 0.0, "muted bus reads as 0")
	manager.set_bus_volume(&"Music", 1.0)
	manager.set_bus_volume(&"SFX", 1.0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "raising the volume unmutes")
	manager.queue_free()


func _test_music() -> void:
	var manager := _make_manager()
	var stream: AudioStream = AudioManagerScript.SFX[&"explosion"]
	manager.play_music(stream, 0.1)
	_check(manager.is_music_playing(), "music starts")
	var player: AudioStreamPlayer = manager.get_node("Music")
	_check(player.bus == &"Music", "music plays on the Music bus")
	_check(player.volume_db < -30.0, "music fades in from silence")
	await create_timer(0.25).timeout
	_check(absf(player.volume_db) < 0.5, "fade-in reaches the target volume")
	manager.stop_music(0.0)
	_check(not manager.is_music_playing(), "stop_music without fade stops at once")
	manager.queue_free()
