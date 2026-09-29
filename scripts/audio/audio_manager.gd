extends Node

## Central audio playback, registered as the `AudioManager` autoload.
## Owns the `Music` and `SFX` buses (created at runtime, so no bus layout file
## is needed), a small round-robin pool of voices for one-shot effects and a
## single music player with fades. Gameplay code never creates its own
## AudioStreamPlayers: it calls `AudioManager.play_sfx(&"punch")`.

## Emitted for every effect that actually starts (not throttled). Handy for
## tests, captions or a future "visual sound" accessibility option.
signal sfx_played(sfx_name: StringName)

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

## Every effect by name. Sources and licence: assets/audio/CREDITS.md.
const SFX := {
	&"punch": preload("res://assets/audio/sfx/punch.wav"),
	&"hit": preload("res://assets/audio/sfx/hit.wav"),
	&"ricochet": preload("res://assets/audio/sfx/ricochet.wav"),
	&"shot": preload("res://assets/audio/sfx/shot.wav"),
	&"shotgun": preload("res://assets/audio/sfx/shotgun.wav"),
	&"swing": preload("res://assets/audio/sfx/swing.wav"),
	&"throw": preload("res://assets/audio/sfx/throw.wav"),
	&"explosion": preload("res://assets/audio/sfx/explosion.wav"),
	&"block_hit": preload("res://assets/audio/sfx/block_hit.wav"),
	&"block_break": preload("res://assets/audio/sfx/block_break.wav"),
	&"jump": preload("res://assets/audio/sfx/jump.wav"),
	&"land": preload("res://assets/audio/sfx/land.wav"),
	&"death": preload("res://assets/audio/sfx/death.wav"),
	&"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	&"dry_fire": preload("res://assets/audio/sfx/dry_fire.wav"),
}

## Looping chiptune themes (assets/audio/generate_music.py).
const MUSIC := {
	&"menu": preload("res://assets/audio/music/menu.wav"),
	&"battle": preload("res://assets/audio/music/battle.wav"),
}
## Mix level of each theme, so music sits under the effects.
const MUSIC_VOLUME_DB := {
	&"menu": -8.0,
	&"battle": -6.0,
}

## Simultaneous effects; the oldest voice is cut when all are busy.
@export var voices := 12
## Same effect re-triggered faster than this (seconds) is skipped, so a
## shotgun volley or an explosion breaking ten tiles doesn't stack into noise.
@export var min_interval := 0.04
## Random pitch spread (+/-) so repeated hits don't sound robotic.
@export var pitch_jitter := 0.08

var _pool: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _track := &""
var _music_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for i in voices:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		voice.bus = BUS_SFX
		add_child(voice)
		_pool.append(voice)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = BUS_MUSIC
	add_child(_music)
	if _track != &"":
		var pending := _track
		_track = &""
		play_track(pending)


## Adds the Music and SFX buses (routed to Master) if they don't exist yet.
static func ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)


func has_sfx(sfx_name: StringName) -> bool:
	return SFX.has(sfx_name)


## Plays a named effect on the SFX bus. Returns the voice used, or null when
## the name is unknown or the effect was throttled by `min_interval`.
func play_sfx(sfx_name: StringName, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not SFX.has(sfx_name):
		push_warning("AudioManager: unknown sfx '%s'" % sfx_name)
		return null
	if _pool.is_empty():
		return null
	var now := _now()
	if _last_played.has(sfx_name) and now - float(_last_played[sfx_name]) < min_interval:
		return null
	_last_played[sfx_name] = now
	var voice := _pool[_next_voice]
	_next_voice = (_next_voice + 1) % _pool.size()
	voice.stream = SFX[sfx_name]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
	voice.play()
	sfx_played.emit(sfx_name)
	return voice


## Starts `stream` on the Music bus, fading in over `fade` seconds. Loop
## the stream from its import settings.
func play_music(stream: AudioStream, fade := 0.5, volume_db := 0.0) -> void:
	_kill_music_tween()
	_track = &""
	_music.stream = stream
	_music.volume_db = -60.0 if fade > 0.0 else volume_db
	_music.play()
	if fade > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", volume_db, fade)


## Plays a theme from MUSIC at its mix level. Asking for the theme already
## playing does nothing, so the menu -> match -> menu loop never restarts it.
func play_track(track: StringName, fade := 1.0) -> void:
	if not MUSIC.has(track):
		push_warning("Unknown music track: %s" % track)
		return
	if _music == null:
		# Asked before _ready (a scene booting with the autoloads): play then.
		_track = track
		return
	if track == _track and _music.playing:
		return
	play_music(MUSIC[track], fade, MUSIC_VOLUME_DB.get(track, 0.0))
	_track = track


## The MUSIC theme playing, or &"" for none (or a raw play_music stream).
func current_track() -> StringName:
	return _track if _music.playing else &""


func stop_music(fade := 0.5) -> void:
	_kill_music_tween()
	_track = &""
	if fade <= 0.0 or not _music.playing:
		_music.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -60.0, fade)
	_music_tween.tween_callback(_music.stop)


func is_music_playing() -> bool:
	return _music.playing


## Volume as a 0..1 slider value (options menu); 0 mutes the bus.
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, linear == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func get_bus_volume(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1 or AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
