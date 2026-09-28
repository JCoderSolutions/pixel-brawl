extends CanvasLayer

## End-of-match overlay: the winner cheers (FighterRig VICTORY, in their
## colour, drawn 2x inside a 64x64 stage: containers reset their children's
## scale), is named, and a rematch or the menu is offered.

@export_file("*.tscn") var menu_scene := "res://scenes/ui/main_menu.tscn"

## Defaults to the GameManager autoload; tests inject their own instance.
var manager: Node

@onready var _title: Label = %Title
@onready var _rematch_button: Button = %RematchButton
@onready var _menu_button: Button = %MenuButton
@onready var _winner_rig: FighterRig = %WinnerRig


func _ready() -> void:
	hide()
	# FighterRig._init anchors itself at the feet; here it fills the stage.
	_winner_rig.position = Vector2.ZERO
	if manager == null:
		manager = get_node_or_null("/root/GameManager")
	if manager == null:
		return
	manager.match_ended.connect(_on_match_ended)
	_rematch_button.pressed.connect(rematch)
	_menu_button.pressed.connect(back_to_menu)


func title_text() -> String:
	return _title.text


func rematch() -> void:
	hide()
	manager.start_match()


func back_to_menu() -> void:
	manager.teardown()
	get_tree().change_scene_to_file(menu_scene)


func _on_match_ended(winner_id: int) -> void:
	_title.text = "¡P%d GANA!" % (winner_id + 1)
	var color: Color = manager.PLAYER_COLORS[winner_id % manager.PLAYER_COLORS.size()]
	_title.add_theme_color_override("font_color", color)
	_winner_rig.color = color
	_winner_rig.anim = FighterRig.Anim.VICTORY
	_winner_rig.anim_time = 0.0
	show()
	_rematch_button.grab_focus()
