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
	# ControlSchemes.Scheme per human; `auto` until someone picks one.
	controls = [0, 1, 2, 3], controls_auto = true,
	# Human cards that have a device: someone pressed a button on it.
	joined = [false, false, false, false],
}
## Fighter cards have a fixed width so long names never push the columns.
const CARD_WIDTH := 108
## The device the menu was last driven with: P1's when several play.
var _menu_scheme: int = ControlSchemes.Scheme.WASD

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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.device < ControlSchemes.MAX_SLOTS:
		_menu_scheme = ControlSchemes.Scheme.PAD_1 + event.device
	elif event is InputEventKey and event.pressed:
		_menu_scheme = ControlSchemes.Scheme.WASD
	if step == Step.FIGHTERS and try_join(event):
		get_viewport().set_input_as_handled()


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
	var before: int = _setup.humans
	if _setup.vs_bots:
		_setup.humans = clampi(humans, 1, MAX_FIGHTERS - 1)
		_setup.bots = clampi(bots, 1, MAX_FIGHTERS - _setup.humans)
	else:
		_setup.humans = clampi(humans, 2, MAX_FIGHTERS)
		_setup.bots = 0
	if _setup.humans != before:
		_setup.controls_auto = true
		_setup.joined = [false, false, false, false]


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


## Keyboard half or gamepad for human `slot` (ControlSchemes.Scheme); the
## card counts as joined.
func set_control(slot: int, scheme: int) -> void:
	_auto_controls()
	_setup.controls[slot] = posmod(scheme, ControlSchemes.LABELS.size())
	_setup.controls_auto = false
	_setup.joined[slot] = true


## Human `slot` takes `scheme` unless another joined player already has that
## keyboard half or pad. Returns whether it joined.
func join(slot: int, scheme: int) -> bool:
	if slot < 0 or slot >= _setup.humans or scheme_taken(scheme, slot):
		return false
	set_control(slot, scheme)
	return true


## Frees human `slot`'s card for another device.
func leave(slot: int) -> void:
	_setup.joined[slot] = false


func is_joined(slot: int) -> bool:
	return _setup.joined[slot]


## True if a joined player other than `except` uses the same device.
func scheme_taken(scheme: int, except := -1) -> bool:
	for slot in _setup.humans:
		if slot != except and _setup.joined[slot] and ControlSchemes.clash(scheme, _setup.controls[slot]):
			return true
	return false


## First human card still waiting for a device, or -1.
func open_slot() -> int:
	for slot in _setup.humans:
		if not _setup.joined[slot]:
			return slot
	return -1


## A button pressed on a device nobody has joins the next open card
## ("apretá para unirte"). Returns whether it did.
func try_join(event: InputEvent) -> bool:
	var scheme := ControlSchemes.join_scheme(event)
	var slot := open_slot()
	if scheme == -1 or slot == -1 or not join(slot, scheme):
		return false
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


func control(slot: int) -> int:
	_auto_controls()
	return _setup.controls[slot]


## Every human has joined with a device, and no two share one.
func controls_valid() -> bool:
	_auto_controls()
	return open_slot() == -1 and ControlSchemes.all_distinct(_setup.controls.slice(0, _setup.humans))


## Until someone picks, controls follow the players and the pads plugged in.
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
			_show(Step.MODE)
		Step.MODE:
			_show(Step.COUNT)
		Step.COUNT:
			_show(Step.FIGHTERS)
		Step.FIGHTERS:
			if teams_valid() and controls_valid():
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
			_hint.text = "En el paso siguiente cada jugador elige teclado o mando"
		Step.FIGHTERS:
			_step_title.text = "LUCHADORES"
			_auto_join_first()
			var cards := HBoxContainer.new()
			cards.alignment = BoxContainer.ALIGNMENT_CENTER
			_content.add_child(cards)
			for slot in fighters():
				cards.add_child(_fighter_card(slot))
			_refresh_teams_hint()
			if _next_button.disabled:
				focus = cards.get_child(0).find_child("Prev", true, false)
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
				# The theme fills the chosen one (pressed): no yellow text here.
				button.remove_theme_color_override("font_color")
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


## P1 always has a device: alone, the keyboard and any pad; with others,
## the one that has been driving the menu.
func _auto_join_first() -> void:
	_auto_controls()
	if _setup.joined[0]:
		return
	_setup.joined[0] = true
	_setup.controls[0] = ControlSchemes.Scheme.KEYS_OR_PAD if _setup.humans == 1 else _menu_scheme


## One fixed-width card per fighter: tag, preview, character, team and
## device. A human card without a device waits for someone to press a button.
func _fighter_card(slot: int) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.name = "Card%d" % slot
	var box := VBoxContainer.new()
	card.add_child(box)
	var human: bool = slot < _setup.humans
	var header := HBoxContainer.new()
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "P%d" % (slot + 1) if human else "BOT %d" % (slot - _setup.humans + 1)
	tag.add_theme_color_override("font_color", UiTokens.TEXT_STRONG)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tag)
	box.add_child(header)
	if human and not _setup.joined[slot]:
		_waiting_card(box, slot)
		return card
	if human and slot > 0:
		var leave_button := Button.new()
		leave_button.name = "Leave"
		leave_button.text = "×"
		leave_button.tooltip_text = "Liberar la tarjeta"
		leave_button.theme_type_variation = &"ButtonSmall"
		leave_button.custom_minimum_size = Vector2(UiTokens.CHIP_HEIGHT, UiTokens.CHIP_HEIGHT)
		leave_button.pressed.connect(func() -> void:
			leave(slot)
			_show(Step.FIGHTERS))
		header.add_child(leave_button)
	else:
		var status := Label.new()
		status.theme_type_variation = &"LabelSmall"
		status.text = "LISTO" if human else "CPU"
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
	name_label.name = "Name"
	var pick := _selector(name_label, func(dir: int) -> void: set_look(slot, _setup.looks[slot] + dir))
	box.add_child(pick)
	var team_button := Button.new()
	team_button.name = "Team"
	team_button.clip_text = true
	team_button.custom_minimum_size = Vector2(0, UiTokens.SELECTOR_HEIGHT)
	team_button.pressed.connect(func() -> void:
		set_team(slot, _setup.teams[slot] + 1)
		_refresh_teams_hint())
	box.add_child(team_button)

	var device := Label.new()
	device.name = "Value"
	device.theme_type_variation = &"LabelSmall"
	var hint := Label.new()
	hint.name = "Keys"
	hint.theme_type_variation = &"LabelSmall"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.clip_text = true
	if human:
		box.add_child(_selector(device, func(dir: int) -> void:
			set_control(slot, _next_free_scheme(slot, _setup.controls[slot], dir))
			_refresh_teams_hint(), "Device"))
	else:
		device.text = "CPU · %s" % BotProfile.display_name(_setup.difficulty)
		device.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		device.clip_text = true
		box.add_child(device)
	box.add_child(hint)

	var refresh := func() -> void:
		var character := FighterLook.at(_setup.looks[slot])
		rig.look = character
		rig.color = character.shirt
		rig.team_color = GameManager.TEAM_COLORS[_setup.teams[slot]]
		name_label.text = character.name
		_paint_team(team_button, _setup.teams[slot])
		if not human:
			return
		var scheme: int = _setup.controls[slot]
		device.text = ControlSchemes.LABELS[scheme]
		hint.text = ControlSchemes.KEY_HINTS.get(scheme, "Cualquier botón")
		# A pad that isn't plugged in still counts: it can be plugged in later.
		var pad := ControlSchemes.pad_of(scheme)
		var missing := pad >= 0 and scheme != ControlSchemes.Scheme.KEYS_OR_PAD \
				and not pad in Input.get_connected_joypads()
		device.add_theme_color_override("font_color", UiTokens.TEXT_MUTED if missing else UiTokens.TEXT)
		if missing:
			hint.text = "Sin conectar"
	var buttons: Array = [pick.get_node("Prev"), pick.get_node("Next"), team_button]
	if human:
		buttons.append_array([box.get_node("Device/Prev"), box.get_node("Device/Next")])
	for button in buttons:
		button.pressed.connect(refresh)
	refresh.call()
	return card


## "Apretá un botón para unirte", blinking; the button joins with the next
## free device, for mouse and touch.
func _waiting_card(box: VBoxContainer, slot: int) -> void:
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
	var button := Button.new()
	button.name = "Join"
	button.text = "Unirse"
	button.custom_minimum_size = Vector2(0, UiTokens.SELECTOR_HEIGHT)
	button.pressed.connect(func() -> void:
		if join(slot, _next_free_scheme(slot, ControlSchemes.Scheme.KEYS_OR_PAD, 1)):
			_show(Step.FIGHTERS))
	box.add_child(button)


## "‹ value ›" with a fixed-width value that clips instead of growing.
func _selector(value: Label, change: Callable, node_name := "Pick") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
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


func _refresh_teams_hint() -> void:
	var teams_ok := teams_valid()
	var controls_ok := controls_valid()
	_next_button.disabled = not (teams_ok and controls_ok)
	var waiting := 0
	for slot in _setup.humans:
		if not _setup.joined[slot]:
			waiting += 1
	if waiting > 0:
		_hint.text = "Falta%s %d: J en WASD, punto en las flechas o cualquier botón del mando" \
				% ["n" if waiting > 1 else "", waiting]
	elif not teams_ok:
		_hint.text = "Todos en el mismo equipo: elegí otro color para alguien"
	elif not controls_ok:
		_hint.text = "Dos jugadores con el mismo teclado o mando"
	else:
		_hint.text = "Hacen equipo los del mismo color"


func _manager() -> Node:
	return get_node_or_null("/root/GameManager")
