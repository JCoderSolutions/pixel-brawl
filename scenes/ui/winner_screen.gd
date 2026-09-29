extends CanvasLayer

## End-of-match overlay: the winner cheers (FighterRig VICTORY, in their
## colour, drawn 2x inside a 64x64 stage: containers reset their children's
## scale), is named, the match standings (Scoreboard) show, and a rematch or
## the menu is offered.

@export_file("*.tscn") var menu_scene := "res://scenes/ui/main_menu.tscn"

## Defaults to the GameManager autoload; tests inject their own instance.
var manager: Node

@onready var _title: Label = %Title
@onready var _rematch_button: Button = %RematchButton
@onready var _menu_button: Button = %MenuButton
@onready var _winner_rig: FighterRig = %WinnerRig

var scoreboard := Scoreboard.new()


func _ready() -> void:
	hide()
	# FighterRig._init anchors itself at the feet; here it fills the stage.
	_winner_rig.position = Vector2.ZERO
	_title.add_sibling(scoreboard)
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
	_title.text = "¡%s GANA!" % manager.side_label(winner_id)
	_title.add_theme_color_override("font_color", manager.side_color(winner_id))
	_winner_rig.look = manager.look_of(winner_id)
	_winner_rig.color = manager.player_color(winner_id)
	_winner_rig.anim = FighterRig.Anim.VICTORY
	_winner_rig.anim_time = 0.0
	scoreboard.refresh(manager)
	show()
	_rematch_button.grab_focus()
