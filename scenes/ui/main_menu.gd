extends Control

## Title screen. "Jugar" loads the match scene with the chosen rivals: the
## local 2P match or P1 against 1-3 bots of a difficulty. "Salir" is hidden
## on web, where closing the tab is the only way out.

@export_file("*.tscn") var match_scene := "res://scenes/maps/test_arena.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _rivals: OptionButton = %Rivals
@onready var _difficulty: OptionButton = %Difficulty


func _ready() -> void:
	_play_button.pressed.connect(_on_play)
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	_rivals.clear()
	_rivals.add_item("2 jugadores")
	for bots in range(1, 4):
		_rivals.add_item("Contra %d bot%s" % [bots, "" if bots == 1 else "s"])
	_difficulty.clear()
	for level in BotProfile.NAMES.size():
		_difficulty.add_item(BotProfile.display_name(level))
	_rivals.item_selected.connect(func(_i: int) -> void: _refresh())
	var manager := _manager()
	var bots: int = manager.bot_difficulties.size() if manager != null else 0
	select(bots, manager.bot_difficulties[0] if bots > 0 else BotProfile.Difficulty.NORMAL)
	_play_button.grab_focus()


## Picks the rivals row (0 = local 2P, n = n bots) and the bot difficulty.
func select(bots: int, difficulty: int) -> void:
	_rivals.select(clampi(bots, 0, 3))
	_difficulty.select(difficulty)
	_refresh()


## Hands the choice to the GameManager for the next match.
func apply_selection() -> void:
	var manager := _manager()
	if manager != null:
		manager.configure_bots(_rivals.selected, _difficulty.selected)


func _refresh() -> void:
	_difficulty.disabled = _rivals.selected == 0


func _manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_play() -> void:
	apply_selection()
	get_tree().change_scene_to_file(match_scene)
