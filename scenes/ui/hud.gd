extends CanvasLayer

## In-match HUD: one health bar and round score per player, plus a banner for
## round announcements and the standings (Scoreboard) between rounds. Reads
## everything from the GameManager signals.

const FIGHT_BANNER_TIME := 0.8

## Defaults to the GameManager autoload; tests inject their own instance.
var manager: Node

var _panels := {}
var scoreboard: Scoreboard

@onready var _bars_row: HBoxContainer = %Bars
@onready var _banner: Label = %Banner


func _ready() -> void:
	scoreboard = Scoreboard.new()
	scoreboard.hide()
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 40.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(scoreboard)
	add_child(holder)
	if manager == null:
		manager = get_node_or_null("/root/GameManager")
	if manager == null:
		return
	manager.player_spawned.connect(_on_player_spawned)
	manager.scores_changed.connect(_on_scores_changed)
	manager.round_started.connect(_on_round_started)
	manager.fight_started.connect(_on_fight_started)
	manager.sudden_death_started.connect(_on_sudden_death)
	manager.round_ended.connect(_on_round_ended)
	manager.match_ended.connect(_on_match_ended)
	for id in manager.get_player_ids():
		_on_player_spawned(id, manager.get_player(id))
	_banner.hide()


func get_bar(id: int) -> ProgressBar:
	return _panels[id].bar if _panels.has(id) else null


func score_text(id: int) -> String:
	return _panels[id].score.text if _panels.has(id) else ""


func banner_text() -> String:
	return _banner.text if _banner.visible else ""


func _on_player_spawned(id: int, player: Node) -> void:
	var panel = _panels.get(id)
	if panel == null:
		panel = _make_panel(id)
		_panels[id] = panel
	var health: HealthComponent = player.health
	panel.bar.max_value = health.max_health
	panel.bar.value = health.current_health
	health.health_changed.connect(func(current: int, maximum: int) -> void:
		panel.bar.max_value = maximum
		panel.bar.value = current)
	panel.weapon.text = ""
	panel.carried.text = ""
	panel.icon.weapon = null
	var holder: WeaponHolder = player.get("weapons")
	if holder != null:
		var refresh := func() -> void:
			panel.weapon.text = weapon_line(holder)
			panel.carried.text = carried_line(holder)
			panel.icon.weapon = holder.weapon
		holder.inventory_changed.connect(refresh)
		holder.ammo_changed.connect(func(_a) -> void: refresh.call())
		holder.weapon_spent.connect(func(_w) -> void: refresh.call())
		refresh.call()
	panel.power.text = ""
	var receiver := PowerUpReceiver.find_on(player)
	if receiver != null:
		var show_power := func(data: PowerUpData) -> void:
			panel.power.text = power_line(data)
			if data != null:
				panel.power.add_theme_color_override("font_color", data.color)
		receiver.stored_changed.connect(show_power)
		show_power.call(receiver.stored)


func weapon_text(id: int) -> String:
	return _panels[id].weapon.text if _panels.has(id) else ""


## The weapon drawn next to P(id + 1)'s weapon line, or null.
func weapon_icon(id: int) -> WeaponData:
	return _panels[id].icon.weapon if _panels.has(id) else null


## The other carried weapons (the ones not in hand), for the inventory line.
func carried_text(id: int) -> String:
	return _panels[id].carried.text if _panels.has(id) else ""


## The stored power-up of P(id + 1), as shown under the weapons.
func power_text(id: int) -> String:
	return _panels[id].power.text if _panels.has(id) else ""


## "+ Velocidad": the power-up kept for later, drawn in its colour.
func power_line(data: PowerUpData) -> String:
	return "" if data == null else "+ " + data.display_name


func weapon_line(holder: WeaponHolder) -> String:
	if not holder.has_weapon():
		return ""
	var uses := "∞" if holder.weapon.has_unlimited_ammo() else str(holder.ammo)
	return "%s %s" % [holder.weapon.display_name, uses]


## Weapons carried but not in hand, in slot order: "Bate · Granada 2".
func carried_line(holder: WeaponHolder) -> String:
	var names := PackedStringArray()
	for slot in WeaponHolder.SLOT_COUNT:
		var data := holder.carried(slot)
		if data == null or slot == holder.active_slot:
			continue
		var left := holder.ammo_in(slot)
		names.append(data.display_name if data.has_unlimited_ammo() else "%s %d" % [data.display_name, left])
	return " · ".join(names)


func _make_panel(id: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "P%d" % (id + 1)
	name_label.add_theme_color_override("font_color", manager.player_color(id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score := Label.new()
	score.text = "0"
	header.add_child(name_label)
	header.add_child(score)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = manager.player_color(id)
	bar.add_theme_stylebox_override("fill", fill)
	var weapon := Label.new()
	weapon.theme_type_variation = &"LabelSmall"
	weapon.add_theme_color_override("font_color", UiTokens.TEXT)
	var carried := Label.new()
	carried.theme_type_variation = &"LabelSmall"
	var power := Label.new()
	power.theme_type_variation = &"LabelSmall"
	# The weapon in hand drawn small next to its name.
	var weapon_row := HBoxContainer.new()
	var icon := WeaponIcon.new()
	weapon_row.add_child(icon)
	weapon_row.add_child(weapon)
	box.add_child(header)
	box.add_child(bar)
	box.add_child(weapon_row)
	box.add_child(carried)
	box.add_child(power)
	_bars_row.add_child(box)
	return {"bar": bar, "score": score, "weapon": weapon, "carried": carried, "icon": icon, "power": power}


func _on_scores_changed(scores: Array) -> void:
	for id in _panels:
		_panels[id].score.text = str(scores[id]) if id < scores.size() else "0"


func _on_round_started(round_number: int) -> void:
	scoreboard.hide()
	_show_banner("RONDA %d" % round_number)


func _on_fight_started() -> void:
	_flash_banner("¡PELEA!")


## Shows `text` for FIGHT_BANNER_TIME seconds, unless something replaces it.
func _flash_banner(text: String) -> void:
	_show_banner(text)
	get_tree().create_timer(FIGHT_BANNER_TIME).timeout.connect(func() -> void:
		if _banner.text == text:
			_banner.hide())


func _on_sudden_death() -> void:
	_flash_banner("¡MUERTE SÚBITA!")


func _on_round_ended(winner_id: int) -> void:
	if winner_id == manager.NO_WINNER:
		_show_banner("EMPATE")
	else:
		_show_banner("%s GANA LA RONDA" % manager.side_label(winner_id))
	scoreboard.refresh(manager)
	scoreboard.show()


## The winner screen takes over when the match ends.
func _on_match_ended(_winner_id: int) -> void:
	_banner.hide()
	scoreboard.hide()


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.show()
