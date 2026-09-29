class_name Scoreboard
extends PanelContainer

## Match standings (Superfighters' round-end screen): one row per fighter
## with rounds won, kills and deaths, best first, plus how many died to the
## map itself. Built in code so the HUD and the winner screen share it.

const HEADERS := ["", "RONDAS", "KILLS", "MUERTES"]
const FONT_SIZE := 8
const LEADER_COLOR := Color("feae34")

var _grid: GridContainer
var _footer: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.094, 0.078, 0.145, 0.85)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_grid = GridContainer.new()
	_grid.columns = HEADERS.size()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 1)
	box.add_child(_grid)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", FONT_SIZE)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer)


## Rebuilds the table from `manager` (the GameManager or a test double).
func refresh(manager: Node) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for header in HEADERS:
		_grid.add_child(_cell(header, Color("8b9bb4")))
	var ids := order(manager)
	for rank in ids.size():
		var id: int = ids[rank]
		var leader: bool = rank == 0 and _stat(manager.scores, id) > 0
		var name_text: String = "%d. P%d" % [rank + 1, id + 1]
		if manager.is_bot(id):
			name_text += " BOT"
		_grid.add_child(_cell(name_text, manager.player_color(id)))
		var color := LEADER_COLOR if leader else Color.WHITE
		_grid.add_child(_cell(str(_stat(manager.scores, id)), color))
		_grid.add_child(_cell(str(_stat(manager.kills, id)), color))
		_grid.add_child(_cell(str(_stat(manager.deaths, id)), color))
	var by_map: int = manager.environment_kills
	_footer.text = "Muertes por el entorno: %d" % by_map
	_footer.visible = by_map > 0


## Player ids best first: rounds won, then kills, then fewest deaths.
static func order(manager: Node) -> Array:
	var ids: Array = range(manager.scores.size())
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ka := [_stat(manager.scores, a), _stat(manager.kills, a), -_stat(manager.deaths, a), -a]
		var kb := [_stat(manager.scores, b), _stat(manager.kills, b), -_stat(manager.deaths, b), -b]
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] > kb[i]
		return false)
	return ids


## The text in row `row` (0 = headers), column `column`, for tests.
func cell_text(row: int, column: int) -> String:
	var index := row * HEADERS.size() + column
	var cells := _grid.get_children()
	return cells[index].text if index < cells.size() else ""


func footer_text() -> String:
	return _footer.text if _footer.visible else ""


static func _stat(values: Array, id: int) -> int:
	return values[id] if id < values.size() else 0


func _cell(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
