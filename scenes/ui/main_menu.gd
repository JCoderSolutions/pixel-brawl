extends Control

## Title screen and match setup. "Jugar" walks through the setup one step at
## a time, like Superfighters' local game screen:
##   mode (bots or local players) -> how many -> character and team per
##   fighter -> map -> bot difficulty (only with bots) -> rounds to win.
## "Atrás" (or cancel) goes back a step; the last step starts the match.
## Choices are kept between visits to the menu. "Opciones" opens the options
## panel; the saved options are loaded and applied every time the menu shows
## up (it is the first scene). "Salir" is hidden on web, where closing the
## tab is the only way out.

enum Step { TITLE, MODE, COUNT, FIGHTERS, MAP, DIFFICULTY, ROUNDS }

const MAX_FIGHTERS := 4
const ROUND_CHOICES: Array[int] = [1, 2, 3, 5]
const TEAM_LABELS := ["Sin equipo", "Rojo", "Azul", "Verde", "Amarillo"]

## The scene the match loads; apply_selection() sets it from the map choice.
@export_file("*.tscn") var match_scene := "res://scenes/maps/test_arena.tscn"

## The setup, kept between visits to the menu. Map 0 = a random map.
static var _setup := {
	vs_bots = true, humans = 1, bots = 1, difficulty = BotProfile.Difficulty.NORMAL,
	looks = [0, 1, 2, 3], teams = [0, 0, 0, 0], map = 0, rounds = 3,
}

var step: int = Step.TITLE

@onready var _title_box: Control = %TitleBox
@onready var _setup_box: Control = %SetupBox
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_button: Button = %OptionsButton
@onready var _options: OptionsMenu = %Options
@onready var _step_title: Label = %StepTitle
@onready var _content: VBoxContainer = %Content
@onready var _hint: Label = %Hint
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	GameSettings.load_saved()
	GameSettings.apply()
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_track(&"menu")
	_play_button.pressed.connect(open_setup)
	_quit_button.pressed.connect(get_tree().quit)
	_options_button.pressed.connect(_options.open)
	_options.closed.connect(_options_button.grab_focus)
	_quit_button.visible = not OS.has_feature("web")
	_back_button.pressed.connect(back)
	_next_button.pressed.connect(next)
	_show(Step.TITLE)


func _unhandled_input(event: InputEvent) -> void:
	if step != Step.TITLE and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


# --- The setup, as values (tests and the step screens use these) ---

func open_setup() -> void:
	_show(Step.MODE)


## Local players only (2-4, P3 and P4 on gamepads) or against the computer.
func choose_mode(vs_bots: bool) -> void:
	_setup.vs_bots = vs_bots
	set_counts(_setup.humans, _setup.bots)


## Clamps to what the mode allows: 2-4 humans alone, or 1-3 humans and at
## least one bot, never more than MAX_FIGHTERS in total.
func set_counts(humans: int, bots: int) -> void:
	if _setup.vs_bots:
		_setup.humans = clampi(humans, 1, MAX_FIGHTERS - 1)
		_setup.bots = clampi(bots, 1, MAX_FIGHTERS - _setup.humans)
	else:
		_setup.humans = clampi(humans, 2, MAX_FIGHTERS)
		_setup.bots = 0


func humans() -> int:
	return _setup.humans


func bots() -> int:
	return _setup.bots


func fighters() -> int:
	return _setup.humans + _setup.bots


func is_vs_bots() -> bool:
	return _setup.vs_bots


## Character (FighterLook preset) for fighter `slot` (humans first, then bots).
func set_look(slot: int, index: int) -> void:
	_setup.looks[slot] = posmod(index, FighterLook.presets().size())


func look(slot: int) -> int:
	return _setup.looks[slot]


## Team for fighter `slot`: 0 = on their own, 1-4 = GameManager.TEAM_NAMES.
func set_team(slot: int, team: int) -> void:
	_setup.teams[slot] = posmod(team, TEAM_LABELS.size())


func team(slot: int) -> int:
	return _setup.teams[slot]


## Someone has to have a rival: not everybody on the same team.
func teams_valid() -> bool:
	var first: int = _setup.teams[0]
	if first == 0:
		return true
	for slot in range(1, fighters()):
		if _setup.teams[slot] != first:
			return true
	return false


## Picks the map: 0 = a random map each match, n = MapCatalog entry n - 1.
func select_map(index: int) -> void:
	_setup.map = clampi(index, 0, MapCatalog.size())


func map_choice() -> int:
	return _setup.map


func set_difficulty(level: int) -> void:
	_setup.difficulty = clampi(level, 0, BotProfile.NAMES.size() - 1)


func difficulty() -> int:
	return _setup.difficulty


## Rounds a fighter (or team) needs to win the match.
func set_rounds(rounds: int) -> void:
	_setup.rounds = maxi(rounds, 1)


func rounds() -> int:
	return _setup.rounds


## Shortcut of the old one-screen menu: 0 bots = local 2P, n = P1 vs n bots.
func select(bot_count: int, level: int) -> void:
	choose_mode(bot_count > 0)
	set_counts(1 if bot_count > 0 else 2, bot_count)
	set_difficulty(level)


## Hands the setup to the GameManager and resolves the map for the next match.
func apply_selection() -> void:
	var manager := _manager()
	if manager != null:
		manager.configure_match(_setup.humans, _setup.bots, _setup.difficulty)
		manager.looks.assign(_setup.looks.slice(0, fighters()))
		manager.teams.assign(_setup.teams.slice(0, fighters()) if teams_valid() else [])
		manager.rounds_to_win = _setup.rounds
	match_scene = MapCatalog.random_path() if _setup.map == 0 else MapCatalog.path(_setup.map - 1)


func start_match() -> void:
	apply_selection()
	get_tree().change_scene_to_file(match_scene)


# --- Step navigation ---

func next() -> void:
	match step:
		Step.TITLE:
			_show(Step.MODE)
		Step.MODE:
			_show(Step.COUNT)
		Step.COUNT:
			_show(Step.FIGHTERS)
		Step.FIGHTERS:
			if teams_valid():
				_show(Step.MAP)
		Step.MAP:
			_show(Step.DIFFICULTY if _setup.vs_bots else Step.ROUNDS)
		Step.DIFFICULTY:
			_show(Step.ROUNDS)
		Step.ROUNDS:
			start_match()


func back() -> void:
	match step:
		Step.MODE:
			_show(Step.TITLE)
		Step.ROUNDS:
			_show(Step.DIFFICULTY if _setup.vs_bots else Step.MAP)
		Step.TITLE:
			pass
		_:
			_show(step - 1)


func _show(to: int) -> void:
	step = to
	_title_box.visible = step == Step.TITLE
	_setup_box.visible = step != Step.TITLE
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_hint.text = ""
	_next_button.text = "Siguiente"
	_next_button.visible = true
	_next_button.disabled = false
	var focus: Control = _next_button
	match step:
		Step.TITLE:
			_focus.call_deferred(_play_button)
			return
		Step.MODE:
			_step_title.text = "¿Contra quién?"
			_next_button.visible = false
			var bots_button := _choice("Contra bots", _setup.vs_bots, func() -> void:
				choose_mode(true)
				next())
			var local_button := _choice("Jugadores locales", not _setup.vs_bots, func() -> void:
				choose_mode(false)
				next())
			focus = bots_button if _setup.vs_bots else local_button
		Step.COUNT:
			_step_title.text = "¿Cuántos?"
			_build_counts()
			_hint.text = "P1: WASD  ·  P2: flechas  ·  P3 y P4: mando"
		Step.FIGHTERS:
			_step_title.text = "Personajes y equipos"
			for slot in fighters():
				_content.add_child(_fighter_row(slot))
			_refresh_teams_hint()
		Step.MAP:
			_step_title.text = "Mapa"
			_next_button.visible = false
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 6)
			_content.add_child(grid)
			for index in MapCatalog.size() + 1:
				var label := "Aleatorio" if index == 0 else MapCatalog.display_name(index - 1)
				var pick := func() -> void:
					select_map(index)
					next()
				var button := _choice(label, index == _setup.map, pick, grid)
				if index == _setup.map:
					focus = button
		Step.DIFFICULTY:
			_step_title.text = "Dificultad de los bots"
			_next_button.visible = false
			for level in BotProfile.NAMES.size():
				var button := _choice(BotProfile.display_name(level), level == _setup.difficulty, func() -> void:
					set_difficulty(level)
					next())
				if level == _setup.difficulty:
					focus = button
		Step.ROUNDS:
			_step_title.text = "Rondas para ganar"
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			_content.add_child(row)
			var group := ButtonGroup.new()
			for rounds_choice in ROUND_CHOICES:
				var pick := func() -> void:
					set_rounds(rounds_choice)
					_hint.text = _summary()
				var button := _choice(str(rounds_choice), rounds_choice == _setup.rounds, pick, row)
				button.toggle_mode = true
				button.button_group = group
				button.button_pressed = rounds_choice == _setup.rounds
				button.remove_theme_color_override("font_color")
				button.add_theme_color_override("font_pressed_color", Color("fee761"))
				button.custom_minimum_size.x = 44
			_hint.text = _summary()
			_next_button.text = "¡A pelear!"
	_focus.call_deferred(focus)


## Deferred so a fresh button can take focus; skipped if the step moved on.
func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


## One line with the whole setup, shown before starting.
func _summary() -> String:
	var who := "%d jugador%s" % [_setup.humans, "" if _setup.humans == 1 else "es"]
	if _setup.bots > 0:
		who += " + %d bot%s (%s)" % [_setup.bots, "" if _setup.bots == 1 else "s", BotProfile.display_name(_setup.difficulty)]
	var map_name := "mapa aleatorio" if _setup.map == 0 else MapCatalog.display_name(_setup.map - 1)
	var rounds_text := "%d ronda%s" % [_setup.rounds, "" if _setup.rounds == 1 else "s"]
	return "%s  ·  %s  ·  gana con %s" % [who, map_name, rounds_text]


# --- Step widgets ---

func _choice(text: String, current: bool, on_press: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 30)
	if current:
		button.add_theme_color_override("font_color", Color("fee761"))
	button.pressed.connect(on_press)
	(parent if parent != null else _content).add_child(button)
	return button


func _build_counts() -> void:
	_content.add_child(_stepper("Jugadores", func() -> int: return _setup.humans,
			func(delta: int) -> void: set_counts(_setup.humans + delta, _setup.bots)))
	if _setup.vs_bots:
		_content.add_child(_stepper("Bots", func() -> int: return _setup.bots,
				func(delta: int) -> void: set_counts(_setup.humans, _setup.bots + delta)))


## "Label  <  n  >": the arrows change a count through `change`, which clamps.
func _stepper(text: String, value: Callable, change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 80
	row.add_child(label)
	var shown := Label.new()
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.custom_minimum_size.x = 28
	shown.text = str(value.call())
	var refresh := func() -> void:
		for other in _content.get_children():
			if other.has_meta("refresh"):
				other.get_meta("refresh").call()
	row.set_meta("refresh", func() -> void: shown.text = str(value.call()))
	row.add_child(_arrow("<", func() -> void:
		change.call(-1)
		refresh.call()))
	row.add_child(shown)
	row.add_child(_arrow(">", func() -> void:
		change.call(1)
		refresh.call()))
	return row


func _arrow(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(28, 28)
	button.pressed.connect(on_press)
	return button


## "P1  < [rig] Bruno >  [ Sin equipo ]": the character arrows and a team
## button that cycles through the teams, both redrawing the preview.
func _fighter_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var tag := Label.new()
	tag.text = "P%d" % (slot + 1) if slot < _setup.humans else "BOT %d" % (slot - _setup.humans + 1)
	tag.custom_minimum_size.x = 44
	row.add_child(tag)
	var rig := FighterRig.new()
	rig.custom_minimum_size = Vector2(32, 32)
	var name_label := Label.new()
	name_label.custom_minimum_size.x = 60
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var team_button := Button.new()
	team_button.custom_minimum_size = Vector2(96, 28)
	var refresh := func() -> void:
		var character := FighterLook.at(_setup.looks[slot])
		rig.look = character
		rig.color = character.shirt
		rig.team_color = GameManager.TEAM_COLORS[_setup.teams[slot]]
		name_label.text = character.name
		team_button.text = TEAM_LABELS[_setup.teams[slot]]
		var tint: Color = GameManager.TEAM_COLORS[_setup.teams[slot]]
		if _setup.teams[slot] == 0:
			team_button.remove_theme_color_override("font_color")
		else:
			team_button.add_theme_color_override("font_color", tint)
	row.add_child(_arrow("<", func() -> void:
		set_look(slot, _setup.looks[slot] - 1)
		refresh.call()))
	row.add_child(rig)
	row.add_child(name_label)
	row.add_child(_arrow(">", func() -> void:
		set_look(slot, _setup.looks[slot] + 1)
		refresh.call()))
	team_button.pressed.connect(func() -> void:
		set_team(slot, _setup.teams[slot] + 1)
		refresh.call()
		_refresh_teams_hint())
	row.add_child(team_button)
	refresh.call()
	return row


func _refresh_teams_hint() -> void:
	var ok := teams_valid()
	_next_button.disabled = not ok
	_hint.text = "Hacen equipo los del mismo color" if ok else "Todos en el mismo equipo: no queda rival"


func _manager() -> Node:
	return get_node_or_null("/root/GameManager")
