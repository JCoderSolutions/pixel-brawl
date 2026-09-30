extends Control

## Title screen and match setup. "Jugar" opens the fighters screen, a lobby of
## four fixed-width cards like Superfighters' local game (open slots you fill
## with players or bots of any difficulty) and Brawlhalla's couch party:
##   fighters (join with a button, add bots, pick characters, teams, devices
##   and each bot's difficulty) -> map -> rounds to win.
## "Atrás" (or cancel) goes back a step; the last step starts the match.
## Choices are kept between visits to the menu. "Opciones" opens the options
## panel; the saved options are loaded and applied every time the menu shows
## up (it is the first scene). "Salir" is hidden on web, where closing the
## tab is the only way out.

enum Step { TITLE, FIGHTERS, MAP, ROUNDS }

const MAX_FIGHTERS := 4
const ROUND_CHOICES: Array[int] = [1, 2, 3, 5]
const TEAM_LABELS := ["Sin equipo", "Rojo", "Azul", "Verde", "Amarillo"]
## Fighter cards have a fixed width so long names never push the columns.
const CARD_WIDTH := 108

## The scene the match loads; apply_selection() sets it from the map choice.
@export_file("*.tscn") var match_scene := "res://scenes/maps/test_arena.tscn"

## The setup, kept between visits to the menu. Fighters are humans first, then
## bots: slot i < humans is P(i + 1), the rest are bots. Map 0 = random.
static var _setup := {
	humans = 1, bot_levels = [BotProfile.Difficulty.NORMAL],
	looks = [0, 1, 2, 3], teams = [0, 0, 0, 0], map = 0, rounds = 3,
	# ControlSchemes.Scheme per human; `auto` follows the defaults until
	# someone joins, leaves or picks.
	controls = [0, 1, 2, 3], controls_auto = true,
}

var step: int = Step.TITLE
## Card and control to focus after the cards are rebuilt ("Card2/AddBot").
var _focus_after := ""

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


func _input(event: InputEvent) -> void:
	if step == Step.FIGHTERS and try_join(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if step != Step.TITLE and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


# --- The setup, as values (tests and the step screens use these) ---

func open_setup() -> void:
	_show(Step.FIGHTERS)


## Sets the lineup directly: 1-4 humans and the bots that fit. New bots take
## the last bot's difficulty. The humans' devices go back to the defaults.
func set_counts(humans: int, bots: int) -> void:
	_setup.humans = clampi(humans, 1, MAX_FIGHTERS)
	var level := _last_level()
	_setup.bot_levels.resize(clampi(bots, 0, MAX_FIGHTERS - _setup.humans))
	for index in _setup.bot_levels.size():
		if _setup.bot_levels[index] == null:
			_setup.bot_levels[index] = level
	_setup.controls_auto = true


func humans() -> int:
	return _setup.humans


func bots() -> int:
	return _setup.bot_levels.size()


func fighters() -> int:
	return _setup.humans + bots()


## Adds a bot after the others, if a card is free. Returns whether it did.
func add_bot(level := -1) -> bool:
	if fighters() >= MAX_FIGHTERS:
		return false
	var fresh := _free_look()
	_setup.bot_levels.append(_last_level() if level < 0 else level)
	_setup.looks[fighters() - 1] = fresh
	return true


## Takes bot `index` (0 = BOT 1) out; the fighters after it move up a card.
func remove_bot(index: int) -> void:
	if index < 0 or index >= bots():
		return
	_setup.bot_levels.remove_at(index)
	_remove_slot(_setup.humans + index)


func set_bot_level(index: int, level: int) -> void:
	_setup.bot_levels[index] = clampi(level, 0, BotProfile.NAMES.size() - 1)


func bot_level(index: int) -> int:
	return _setup.bot_levels[index]


## Every bot at `level` (the old single difficulty; select() uses it).
func set_difficulty(level: int) -> void:
	for index in bots():
		set_bot_level(index, level)


func difficulty() -> int:
	return _last_level()


func _last_level() -> int:
	return _setup.bot_levels.back() if bots() > 0 else BotProfile.Difficulty.NORMAL


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


## Keyboard half or gamepad for human `slot` (ControlSchemes.Scheme).
func set_control(slot: int, scheme: int) -> void:
	_auto_controls()
	_setup.controls[slot] = posmod(scheme, ControlSchemes.LABELS.size())
	_setup.controls_auto = false


func control(slot: int) -> int:
	_auto_controls()
	return _setup.controls[slot]


## A new player with `scheme` takes the next card: after the other humans,
## pushing the bots one card over. With every card taken, the last bot makes
## room (Superfighters' drop-in replaces bots). Returns whether they joined.
func join(scheme: int) -> bool:
	if scheme_taken(scheme) or _setup.humans >= MAX_FIGHTERS:
		return false
	if fighters() >= MAX_FIGHTERS:
		remove_bot(bots() - 1)
	_auto_controls()
	_insert_slot(_setup.humans)
	_setup.controls.insert(_setup.humans, scheme)
	_setup.controls.resize(MAX_FIGHTERS)
	_setup.humans += 1
	_setup.controls_auto = false
	return true


## Human `slot` leaves (P1 stays); the fighters after it move up a card.
func leave(slot: int) -> void:
	if slot <= 0 or slot >= _setup.humans:
		return
	_auto_controls()
	_setup.controls.remove_at(slot)
	_setup.controls.append(0)
	_setup.humans -= 1
	_setup.controls_auto = false
	_remove_slot(slot)


## True if a human other than `except` already uses that keyboard half or pad.
func scheme_taken(scheme: int, except := -1) -> bool:
	_auto_controls()
	for slot in _setup.humans:
		if slot != except and ControlSchemes.clash(scheme, _setup.controls[slot]):
			return true
	return false


## A button pressed on a device nobody has joins as a new player ("apretá
## para unirte"). Returns whether it did.
func try_join(event: InputEvent) -> bool:
	var scheme := ControlSchemes.join_scheme(event)
	if scheme == -1 or not join(scheme):
		return false
	_focus_after = "Card%d/Pick/Next" % (_setup.humans - 1)
	if step == Step.FIGHTERS:
		_show(Step.FIGHTERS)
	return true


## The next scheme after `scheme` nobody else has, going `dir` (+1 / -1).
## KEYS_OR_PAD is only for a lone player.
func _next_free_scheme(slot: int, scheme: int, dir: int) -> int:
	var count := ControlSchemes.LABELS.size()
	for offset in range(1, count + 1):
		var candidate := posmod(scheme + dir * offset, count)
		if candidate == ControlSchemes.Scheme.KEYS_OR_PAD and _setup.humans > 1:
			continue
		if not scheme_taken(candidate, slot):
			return candidate
	return scheme


## Opens card `at`: the looks and teams from there on move one card right.
func _insert_slot(at: int) -> void:
	var fresh := _free_look()
	_setup.looks.pop_back()
	_setup.looks.insert(at, fresh)
	_setup.teams.pop_back()
	_setup.teams.insert(at, 0)


## Closes card `at`: the looks and teams after it move one card left.
func _remove_slot(at: int) -> void:
	_setup.looks.append(_setup.looks.pop_at(at))
	_setup.teams.remove_at(at)
	_setup.teams.append(0)


## A character nobody on the cards wears yet (or the first one).
func _free_look() -> int:
	var worn: Array = _setup.looks.slice(0, fighters())
	for index in FighterLook.presets().size():
		if not index in worn:
			return index
	return 0


## Fighters with devices that don't clash, and at least two to fight.
func controls_valid() -> bool:
	_auto_controls()
	return ControlSchemes.all_distinct(_setup.controls.slice(0, _setup.humans))


func can_start() -> bool:
	return fighters() >= 2 and teams_valid() and controls_valid()


## Until someone joins, leaves or picks, controls follow the players and the
## pads plugged in.
func _auto_controls() -> void:
	if not _setup.controls_auto:
		return
	var picked := ControlSchemes.defaults(_setup.humans, Input.get_connected_joypads().size())
	for slot in picked.size():
		_setup.controls[slot] = picked[slot]


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


## Rounds a fighter (or team) needs to win the match.
func set_rounds(rounds: int) -> void:
	_setup.rounds = maxi(rounds, 1)


func rounds() -> int:
	return _setup.rounds


## Shortcut of the old one-screen menu: 0 bots = local 2P, n = P1 vs n bots.
func select(bot_count: int, level: int) -> void:
	set_counts(1 if bot_count > 0 else 2, bot_count)
	set_difficulty(level)


## Hands the setup to the GameManager and resolves the map for the next match.
func apply_selection() -> void:
	var manager := _manager()
	if manager != null:
		manager.configure_match(_setup.humans, bots(), difficulty())
		manager.bot_difficulties.assign(_setup.bot_levels)
		manager.looks.assign(_setup.looks.slice(0, fighters()))
		manager.teams.assign(_setup.teams.slice(0, fighters()) if teams_valid() else [])
		manager.rounds_to_win = _setup.rounds
		_auto_controls()
		manager.controls.assign(_setup.controls.slice(0, _setup.humans))
	match_scene = MapCatalog.random_path() if _setup.map == 0 else MapCatalog.path(_setup.map - 1)


func start_match() -> void:
	apply_selection()
	get_tree().change_scene_to_file(match_scene)


# --- Step navigation ---

func next() -> void:
	match step:
		Step.TITLE:
			_show(Step.FIGHTERS)
		Step.FIGHTERS:
			if can_start():
				_show(Step.MAP)
		Step.MAP:
			_show(Step.ROUNDS)
		Step.ROUNDS:
			start_match()


func back() -> void:
	if step != Step.TITLE:
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
		Step.FIGHTERS:
			_step_title.text = "LUCHADORES"
			var cards := HBoxContainer.new()
			cards.name = "Cards"
			cards.alignment = BoxContainer.ALIGNMENT_CENTER
			_content.add_child(cards)
			for slot in MAX_FIGHTERS:
				cards.add_child(_fighter_card(slot) if slot < fighters() else _open_card(slot))
			_refresh_hint()
			var wanted := cards.get_node_or_null(_focus_after) as Control if _focus_after != "" else null
			_focus_after = ""
			if wanted != null:
				focus = wanted
			elif _next_button.disabled:
				focus = cards.get_child(fighters()).find_child("AddBot", true, false) \
						if fighters() < MAX_FIGHTERS else cards.get_child(0).find_child("Prev", true, false)
		Step.MAP:
			_step_title.text = "MAPA"
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
				button.toggle_mode = true
				button.button_pressed = index == _setup.map
				if index == _setup.map:
					focus = button
		Step.ROUNDS:
			_step_title.text = "RONDAS PARA GANAR"
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
	if bots() > 0:
		var levels := PackedStringArray()
		for level in _setup.bot_levels:
			levels.append(BotProfile.display_name(level))
		who += " + %d bot%s (%s)" % [bots(), "" if bots() == 1 else "s", ", ".join(levels)]
	var map_name := "mapa aleatorio" if _setup.map == 0 else MapCatalog.display_name(_setup.map - 1)
	var rounds_text := "%d ronda%s" % [_setup.rounds, "" if _setup.rounds == 1 else "s"]
	return "%s  ·  %s  ·  gana con %s" % [who, map_name, rounds_text]


# --- Step widgets ---

## A choice button; the theme fills the current one when the caller makes it
## a pressed toggle.
func _choice(text: String, _current: bool, on_press: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 30)
	button.pressed.connect(on_press)
	(parent if parent != null else _content).add_child(button)
	return button


func _arrow(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button


## Rebuilds the cards, then focuses `focus_path` inside them.
func _rebuild(focus_path := "") -> void:
	_focus_after = focus_path
	_show(Step.FIGHTERS)


## A fighter's card: tag, preview, character, team and, for players, their
## device or, for bots, their difficulty. Fixed width: text clips, never grows.
func _fighter_card(slot: int) -> Control:
	var card := _card(slot)
	var box: VBoxContainer = card.get_child(0)
	var human: bool = slot < _setup.humans
	var bot_index: int = slot - _setup.humans
	var header := HBoxContainer.new()
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "P%d" % (slot + 1) if human else "BOT %d" % (bot_index + 1)
	tag.add_theme_color_override("font_color", UiTokens.TEXT_STRONG)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tag)
	box.add_child(header)
	if slot > 0:
		# × frees the card: a player leaves, a bot is taken out.
		var remove := Button.new()
		remove.name = "Remove"
		remove.text = "×"
		remove.tooltip_text = "Salir" if human else "Quitar bot"
		remove.theme_type_variation = &"ButtonSmall"
		remove.custom_minimum_size = Vector2(UiTokens.CHIP_HEIGHT, UiTokens.CHIP_HEIGHT)
		remove.pressed.connect(func() -> void:
			if human:
				leave(slot)
			else:
				remove_bot(bot_index)
			_rebuild("Card%d/AddBot" % (fighters()) if fighters() < MAX_FIGHTERS else ""))
		header.add_child(remove)
	else:
		var status := Label.new()
		status.theme_type_variation = &"LabelSmall"
		status.text = "LISTO"
		header.add_child(status)

	# Preview at twice the game's size, standing on the card's floor line.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 58)
	var rig := FighterRig.new()
	rig.name = "Rig"
	rig.size = Vector2(32, 28)
	rig.scale = Vector2(2, 2)
	stage.add_child(rig)
	stage.resized.connect(func() -> void: rig.position = Vector2(stage.size.x / 2.0 - 32.0, stage.size.y - 56.0))
	box.add_child(stage)

	var name_label := Label.new()
	name_label.name = "Value"
	var pick := _selector(name_label, func(dir: int) -> void: set_look(slot, _setup.looks[slot] + dir), "Pick")
	box.add_child(pick)
	var team_button := Button.new()
	team_button.name = "Team"
	team_button.clip_text = true
	team_button.custom_minimum_size = Vector2(0, UiTokens.SELECTOR_HEIGHT)
	team_button.pressed.connect(func() -> void:
		set_team(slot, _setup.teams[slot] + 1)
		_refresh_hint())
	box.add_child(team_button)

	# Players: "‹ device ›" and its keys. Bots: "‹ difficulty ›" (like
	# Smash's CPU level on the card).
	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = &"LabelSmall"
	var hint := Label.new()
	hint.name = "Keys"
	hint.theme_type_variation = &"LabelSmall"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.clip_text = true
	var setting: HBoxContainer
	if human:
		setting = _selector(value, func(dir: int) -> void:
			set_control(slot, _next_free_scheme(slot, control(slot), dir))
			_refresh_hint(), "Device")
	else:
		setting = _selector(value, func(dir: int) -> void:
			set_bot_level(bot_index, posmod(bot_level(bot_index) + dir, BotProfile.NAMES.size())), "Level")
	box.add_child(setting)
	box.add_child(hint)

	var refresh := func() -> void:
		var character := FighterLook.at(_setup.looks[slot])
		rig.look = character
		rig.color = character.shirt
		rig.team_color = GameManager.TEAM_COLORS[_setup.teams[slot]]
		name_label.text = character.name
		_paint_team(team_button, _setup.teams[slot])
		if not human:
			value.text = BotProfile.display_name(bot_level(bot_index))
			value.add_theme_color_override("font_color", UiTokens.TEXT)
			hint.text = "CPU"
			return
		var scheme := control(slot)
		value.text = ControlSchemes.CARD_LABELS[scheme]
		hint.text = ControlSchemes.KEY_HINTS.get(scheme, "Cualquier botón")
		# A pad that isn't plugged in still counts: it can be plugged in later.
		var pad := ControlSchemes.pad_of(scheme)
		var missing := pad >= 0 and scheme != ControlSchemes.Scheme.KEYS_OR_PAD \
				and not pad in Input.get_connected_joypads()
		value.add_theme_color_override("font_color", UiTokens.TEXT_MUTED if missing else UiTokens.TEXT)
		if missing:
			hint.text = "Sin conectar"
	for button in [pick.get_node("Prev"), pick.get_node("Next"), team_button,
			setting.get_node("Prev"), setting.get_node("Next")]:
		button.pressed.connect(refresh)
	refresh.call()
	return card


## A free card: a player joins by pressing a button on a free keyboard half
## or pad ("apretá para unirte", blinking), or "+ Bot" adds a bot (like
## Superfighters' open slots). "Unirse" joins with the next free device for
## mouse and touch.
func _open_card(slot: int) -> Control:
	var card := _card(slot)
	card.theme_type_variation = &"PanelOpen"
	var box: VBoxContainer = card.get_child(0)
	var plus := Label.new()
	plus.theme_type_variation = &"LabelDisplay"
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.add_theme_color_override("font_color", UiTokens.ACCENT)
	box.add_child(plus)
	var call_label := Label.new()
	call_label.name = "Call"
	call_label.theme_type_variation = &"LabelSmall"
	call_label.text = "APRETÁ UN BOTÓN\nPARA UNIRTE"
	call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(call_label)
	call_label.ready.connect(func() -> void:
		var blink := call_label.create_tween().set_loops()
		blink.tween_interval(0.5)
		blink.tween_callback(func() -> void: call_label.modulate.a = 1.0 - call_label.modulate.a))
	var keys := Label.new()
	keys.theme_type_variation = &"LabelSmall"
	keys.text = "J, . o mando"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.clip_text = true
	box.add_child(keys)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var add := Button.new()
	add.name = "AddBot"
	add.text = "+ Bot"
	add.custom_minimum_size = Vector2(0, UiTokens.SELECTOR_HEIGHT)
	add.pressed.connect(func() -> void:
		if add_bot():
			_rebuild("Card%d/Level/Next" % (fighters() - 1)))
	box.add_child(add)
	var join_button := Button.new()
	join_button.name = "Join"
	join_button.text = "Unirse"
	join_button.custom_minimum_size = Vector2(0, UiTokens.SELECTOR_HEIGHT)
	join_button.disabled = _setup.humans >= MAX_FIGHTERS
	join_button.pressed.connect(func() -> void:
		if join(_next_free_scheme(-1, ControlSchemes.Scheme.KEYS_OR_PAD, 1)):
			_rebuild("Card%d/Pick/Next" % (_setup.humans - 1)))
	box.add_child(join_button)
	return card


func _card(slot: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.name = "Card%d" % slot
	card.add_child(VBoxContainer.new())
	return card


## "‹ value ›" with a fixed-width value that clips instead of growing.
func _selector(value: Label, change: Callable, node_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prev := _arrow("‹", func() -> void: change.call(-1))
	prev.name = "Prev"
	var next_arrow := _arrow("›", func() -> void: change.call(1))
	next_arrow.name = "Next"
	for arrow in [prev, next_arrow]:
		arrow.custom_minimum_size = Vector2(UiTokens.SELECTOR_HEIGHT, UiTokens.SELECTOR_HEIGHT)
	row.add_child(prev)
	row.add_child(value)
	row.add_child(next_arrow)
	return row


## Team button: the team's color as a filled chip, or plain without a team.
func _paint_team(button: Button, team_index: int) -> void:
	button.text = TEAM_LABELS[team_index]
	for state in ["normal", "hover"]:
		button.remove_theme_stylebox_override(state)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		button.remove_theme_color_override(color_name)
	if team_index == 0:
		return
	var tint: Color = GameManager.TEAM_COLORS[team_index]
	for state in ["normal", "hover"]:
		var chip := StyleBoxFlat.new()
		chip.bg_color = tint if state == "normal" else tint.lightened(0.25)
		chip.anti_aliasing = false
		chip.content_margin_left = UiTokens.GAP
		chip.content_margin_right = UiTokens.GAP
		button.add_theme_stylebox_override(state, chip)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, UiTokens.BG)


func _refresh_hint() -> void:
	_next_button.disabled = not can_start()
	if fighters() < 2:
		_hint.text = "Sumá un rival: J, punto o un botón del mando para unirse, o + Bot"
	elif not teams_valid():
		_hint.text = "Todos en el mismo equipo: elegí otro color para alguien"
	elif not controls_valid():
		_hint.text = "Dos jugadores con el mismo teclado o mando"
	elif fighters() < MAX_FIGHTERS:
		_hint.text = "Para sumar a alguien más: J, punto o un botón del mando, o + Bot"
	else:
		_hint.text = "Hacen equipo los del mismo color"


func _manager() -> Node:
	return get_node_or_null("/root/GameManager")
