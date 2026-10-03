extends Control

const UI = preload("res://ui/ui.gd")
const State = preload("res://scenes/games/tic_tac_toe/tic_tac_toe_state.gd")
const Celebration = preload("res://scenes/games/tic_tac_toe/celebration.gd")
const Cell = preload("res://scenes/games/tic_tac_toe/cell.gd")
var state = State.new()
var celebration: Control
var board: GridContainer
var panel_scroll: ScrollContainer
var panel: VBoxContainer
var status: Label
var undo_button: Button
var cells: Array[Button] = []
var hint_buttons: Dictionary = {}
var hint_label: Label
var hint_enabled: Dictionary = {1: true, 2: true}

func _toggle_hint(enabled: bool, player: int) -> void:
	hint_enabled[player] = enabled
	_update_hint_button(player)
	_refresh()

func _update_hint_button(player: int) -> void:
	var button: Button = hint_buttons[player]
	var color_name = "ばつ" if player == 2 else "まる"
	button.text = color_name + ("：オン" if hint_enabled[player] else "：オフ")
	button.set_pressed_no_signal(hint_enabled[player])

func _ready() -> void:
	UI.setup(self)
	board = GridContainer.new()
	board.columns = 3
	board.add_theme_constant_override("h_separation", 8)
	board.add_theme_constant_override("v_separation", 8)
	add_child(board)
	for y in 3:
		for x in 3:
			var cell = Cell.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.pressed.connect(_place.bind(Vector2i(x, y)))
			cells.append(cell)
			board.add_child(cell)
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(panel_scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	panel_scroll.add_child(panel)
	panel.add_child(UI.label("まるばつゲーム", 26))
	status = UI.label("", 30)
	panel.add_child(status)
	panel.add_child(UI.label("ヒント", 20))
	var hint_row = HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	panel.add_child(hint_row)
	for player in [1, 2]:
		var button = Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 20)
		for style_name in ["normal", "hover", "pressed", "hover_pressed"]:
			var selected = style_name in ["pressed", "hover_pressed"]
			var box = UI.style(UI.GREEN if selected else Color.WHITE, 16)
			box.content_margin_left = 10
			box.content_margin_right = 10
			button.add_theme_stylebox_override(style_name, box)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		hint_buttons[player] = button
		_update_hint_button(player)
		button.toggled.connect(_toggle_hint.bind(player))
		hint_row.add_child(button)
	hint_label = UI.label("", 20)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.y = 62
	panel.add_child(hint_label)
	undo_button = UI.button("ひとつ もどる", _undo)
	panel.add_child(undo_button)
	panel.add_child(UI.button("もういちど", _restart))
	panel.add_child(UI.button("ゲームを えらぶ", func(): get_tree().change_scene_to_file.call_deferred("res://scenes/game_select/game_select.tscn")))
	celebration = Celebration.new()
	celebration.state = state
	celebration.board = board
	add_child(celebration)
	celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_refresh()
	_layout()

func _layout() -> void:
	if board == null: return
	var landscape = size.x > size.y
	for child in panel.get_children():
		if child is Button: child.custom_minimum_size.y = 96
	var side = minf(size.y - 24, size.x - 300) if landscape else minf(size.x - 24, size.y - panel.get_combined_minimum_size().y - 36)
	side = maxf(120, side)
	board.position = Vector2(12, (size.y - side) / 2) if landscape else Vector2((size.x - side) / 2, 12)
	board.size = Vector2.ONE * side
	panel_scroll.position = Vector2(side + 24, 12) if landscape else Vector2(12, side + 24)
	panel_scroll.size = Vector2(size.x - side - 36, size.y - 24) if landscape else Vector2(size.x - 24, size.y - side - 36)

func _place(position: Vector2i) -> void:
	if state.place(position): _refresh()

func _undo() -> void:
	state.undo()
	_refresh()

func _restart() -> void:
	state.reset()
	_refresh()

func _refresh() -> void:
	var player: int = state.winner if state.winner else state.current_player
	status.text = ("○ まる" if player == 1 else "× ばつ") + ("の かち！" if state.winner else "の ばん")
	if state.game_over and state.winner == 0: status.text = "ひきわけ！"
	status.add_theme_color_override("font_color", UI.GREEN if state.game_over else UI.INK)
	undo_button.disabled = state.move_history.is_empty()
	var suggestion = state.get_hint() if hint_enabled[state.current_player] else {"positions": [], "text": ""}
	var hint_color = Color("ce3d46") if suggestion.get("kind", "") == "defend" else UI.GREEN
	hint_label.text = suggestion.text
	hint_label.add_theme_color_override("font_color", hint_color)
	for i in cells.size():
		var position = Vector2i(i % 3, i / 3)
		var mark: int = state.board[position.y][position.x]
		var cell = cells[i]
		cell.hint_color = hint_color
		cell.show_hint = suggestion.positions.has(position)
		cell.mark = mark
		cell.disabled = state.game_over or mark != 0
		var won: bool = state.winning_positions.has(position)
		var background = UI.style(Color.WHITE)
		if won:
			background.border_color = UI.GREEN
			background.set_border_width_all(4)
		cell.add_theme_stylebox_override("disabled", background)
	celebration.sync_celebration()
