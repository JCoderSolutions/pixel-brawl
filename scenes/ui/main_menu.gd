extends Control

## Title screen. "Jugar" loads the chosen map (or a random one) with the
## chosen rivals: the local 2P match or P1 against 1-3 bots of a difficulty.
## "Salir" is hidden on web, where closing the tab is the only way out.

## The scene "Jugar" loads; apply_selection() sets it from the map option.
@export_file("*.tscn") var match_scene := "res://scenes/maps/test_arena.tscn"

## Map option kept between visits to the menu (0 = random).
static var _last_map := 0

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _rivals: OptionButton = %Rivals
@onready var _difficulty: OptionButton = %Difficulty
@onready var _map: OptionButton = %Map


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
	_map.clear()
	_map.add_item("Mapa aleatorio")
	for i in MapCatalog.size():
		_map.add_item(MapCatalog.display_name(i))
	_map.item_selected.connect(func(index: int) -> void: _last_map = index)
	select_map(_last_map)
	var manager := _manager()
	var bots: int = manager.bot_difficulties.size() if manager != null else 0
	select(bots, manager.bot_difficulties[0] if bots > 0 else BotProfile.Difficulty.NORMAL)
	_play_button.grab_focus()


## Picks the rivals row (0 = local 2P, n = n bots) and the bot difficulty.
func select(bots: int, difficulty: int) -> void:
	_rivals.select(clampi(bots, 0, 3))
	_difficulty.select(difficulty)
	_refresh()


## Picks the map row: 0 = a random map each match, n = MapCatalog entry n - 1.
func select_map(index: int) -> void:
	_map.select(clampi(index, 0, MapCatalog.size()))
	_last_map = _map.selected


## Hands the rivals to the GameManager and resolves the map for the next match.
func apply_selection() -> void:
	var manager := _manager()
	if manager != null:
		manager.configure_bots(_rivals.selected, _difficulty.selected)
	var map := _map.selected
	match_scene = MapCatalog.random_path() if map == 0 else MapCatalog.path(map - 1)


func _refresh() -> void:
	_difficulty.disabled = _rivals.selected == 0


func _manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_play() -> void:
	apply_selection()
	get_tree().change_scene_to_file(match_scene)
