class_name PauseMenu
extends CanvasLayer

## In-match pause (Esc, Start on a pad, or the touch "II" button): freezes the
## match and offers Seguir, Reiniciar and Menú in the game's UI style. It is
## not available once the match is over (the winner screen is up). The arena
## adds it by itself (arena_match.gd).

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _resume_button: Button


func _init() -> void:
	name = "PauseMenu"
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := Panel.new()
	dim.theme_type_variation = &"PanelDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(180, 0)
	box.add_theme_constant_override("separation", UiTokens.GROUP_GAP)
	center.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"LabelDisplay"
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_resume_button = _button(box, "Seguir", resume, &"ButtonPrimary")
	_resume_button.set_meta("silent", true)
	_button(box, "Reiniciar partida", restart)
	_button(box, "Menú", to_menu)
	var hint := Label.new()
	hint.theme_type_variation = &"LabelSmall"
	hint.text = "Esc o Start para seguir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	hide()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle()


func toggle() -> void:
	if visible:
		resume()
	else:
		pause()


## Freezes the match and shows the menu. Returns false when there's no match
## left to pause (the winner screen is up).
func pause() -> bool:
	if visible or _match_over():
		return false
	get_tree().paused = true
	show()
	_resume_button.grab_focus()
	return true


func resume() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	var feedback := get_node_or_null("/root/UiFeedback")
	if feedback != null:
		feedback.back()


func restart() -> void:
	hide()
	get_tree().paused = false
	_manager().start_match()


func to_menu() -> void:
	hide()
	get_tree().paused = false
	_manager().teardown()
	get_tree().change_scene_to_file(MENU_SCENE)


## The GameManager autoload (by path: this global class compiles before the
## autoloads exist).
func _manager() -> Node:
	return get_node("/root/GameManager")


func _match_over() -> bool:
	var winner := get_parent().get_node_or_null("WinnerScreen") if get_parent() != null else null
	return winner != null and winner.visible


func _button(box: Control, text: String, action: Callable, variation := &"") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, UiTokens.BUTTON_HEIGHT)
	button.theme_type_variation = variation
	button.pressed.connect(action)
	box.add_child(button)
	return button
