extends Control

const UI = preload("res://ui/ui.gd")
const State = preload("res://scenes/games/gomoku/gomoku_state.gd")
const Board = preload("res://scenes/games/gomoku/board.gd")
var state = State.new()
var board: Control
var status: Label
var undo_button: Button
var panel_scroll: ScrollContainer
var panel: VBoxContainer
var hint_buttons: Dictionary = {}
var hint_label: Label
var hint_enabled: Dictionary = {1: true, 2: true}

func _layout() -> void:
	if board == null: return
	var landscape = size.x > size.y
	var available_height = size.y - UI.BOTTOM_INSET
	for child in panel.get_children():
		if child is Button: child.custom_minimum_size.y = 128 if landscape else 96
	var panel_height = panel.get_combined_minimum_size().y
	var side = minf(available_height - 8, size.x - 260) if landscape else minf(size.x - 8, available_height - panel_height - 20)
	side = maxf(100, side)
	board.position = Vector2(4, (available_height - side) / 2) if landscape else Vector2((size.x - side) / 2, 4)
	board.size = Vector2.ONE * side
	panel_scroll.position = Vector2(side + 16, 12) if landscape else Vector2(8, side + 12)
	panel_scroll.size = Vector2(size.x - side - 24, available_height - 24) if landscape else Vector2(size.x - 16, available_height - side - 20)
	for child in panel.get_children():
		if child is Button: child.custom_minimum_size.y = 128 if landscape else 96

func _toggle_hint(enabled: bool, player: int) -> void:
	hint_enabled[player] = enabled
	_update_hint_button(player)
	_refresh()

func _update_hint_button(player: int) -> void:
	var button: Button = hint_buttons[player]
	var color_name = "しろ" if player == 2 else "くろ"
	button.text = color_name + ("：オン" if hint_enabled[player] else "：オフ")
	button.set_pressed_no_signal(hint_enabled[player])

func _ready() -> void:
	UI.setup(self)
	board = Board.new()
	board.state = state
	board.played.connect(_place)
	add_child(board)
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(panel_scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	panel_scroll.add_child(panel)
	panel.add_child(UI.label("ごもくならべ", 26))
	status = UI.label("", 30)
	panel.add_child(status)
	panel.add_child(UI.label("ヒント", 20))
	var hint_row = HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	panel.add_child(hint_row)
	for player in [2, 1]:
		var button = Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
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
	resized.connect(_layout)
	_layout()
	_refresh()

func _place(position: Vector2i) -> void:
	if state.place(position): _refresh()

func _undo() -> void:
	state.undo()
	_refresh()

func _restart() -> void:
	state.reset()
	_refresh()

func _refresh() -> void:
	var player: int = state.winner if state.winner != 0 else state.current_player
	var name_text = "● くろ" if player == 1 else "○ しろ"
	status.text = name_text + ("の かち！" if state.winner != 0 else "の ばん")
	if state.game_over and state.winner == 0: status.text = "ひきわけ！"
	status.add_theme_color_override("font_color", UI.GREEN if state.game_over else UI.INK)
	undo_button.disabled = state.move_history.is_empty()
	var show_hint: bool = hint_enabled[state.current_player]
	var suggestion = state.get_hint() if show_hint else {"positions": [], "text": ""}
	var hint_color = UI.INK
	match suggestion.get("kind", ""):
		"win": hint_color = UI.GREEN
		"defend": hint_color = Color("ce3d46")
	board.hint_color = hint_color
	hint_label.add_theme_color_override("font_color", hint_color)
	board.hint_positions = suggestion.positions
	hint_label.text = suggestion.text
	board.sync_celebration()
	board.queue_redraw()
