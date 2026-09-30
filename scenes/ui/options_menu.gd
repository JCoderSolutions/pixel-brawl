class_name OptionsMenu
extends Control

## "Opciones" panel over the main menu: music and effects volume, fullscreen
## and when to show the touch controls. Every change is applied and saved
## at once (GameSettings), so there is no "save" button to forget.

signal closed

@onready var _music: HSlider = %Music
@onready var _effects: HSlider = %Effects
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _touch: OptionButton = %Touch
@onready var _back: Button = %Back


func _ready() -> void:
	hide()
	_touch.clear()
	# Same order as TouchControls.Visibility.
	for label in ["Automático", "Siempre", "Nunca"]:
		_touch.add_item(label)
	_music.value_changed.connect(_on_music)
	_effects.value_changed.connect(_on_effects)
	_fullscreen.toggled.connect(_on_fullscreen)
	_touch.item_selected.connect(_on_touch)
	_back.pressed.connect(close)
	# Native phone apps are always full screen. Browsers allow it because the
	# switch happens inside the click that toggles it.
	_fullscreen.visible = not OS.has_feature("mobile")
	%FullscreenLabel.visible = _fullscreen.visible


## Shows the stored options and takes the focus for keyboards and pads.
func open() -> void:
	_music.set_value_no_signal(GameSettings.music_volume)
	_effects.set_value_no_signal(GameSettings.sfx_volume)
	_fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	_touch.select(GameSettings.touch_mode)
	show()
	_music.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_music(value: float) -> void:
	GameSettings.music_volume = value
	_store()


func _on_effects(value: float) -> void:
	GameSettings.sfx_volume = value
	_store()


func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.save()
	GameSettings.apply_fullscreen(true)


func _on_touch(index: int) -> void:
	GameSettings.touch_mode = index
	GameSettings.save()


func _store() -> void:
	GameSettings.save()
	GameSettings.apply()
