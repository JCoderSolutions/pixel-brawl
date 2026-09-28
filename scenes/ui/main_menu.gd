extends Control

## Title screen. "Jugar" loads the match scene; "Salir" is hidden on web,
## where closing the tab is the only way out.

@export_file("*.tscn") var match_scene := "res://scenes/ui/match_sandbox.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play)
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	_play_button.grab_focus()


func _on_play() -> void:
	get_tree().change_scene_to_file(match_scene)
