extends Control

const UI = preload("res://ui/ui.gd")
const State = preload("res://scenes/games/minesweeper/minesweeper_state.gd")
const Cell = preload("res://scenes/games/minesweeper/cell.gd")
const ModeButton = preload("res://scenes/games/minesweeper/mode_button.gd")
const Effects = preload("res://scenes/games/minesweeper/effects.gd")
const COLORS = ["283c3c", "267565", "326caf", "b8444c", "7a50aa", "a65b24", "187984", "67443d", "555555"]
var state = State.new()
var level = 0
var flag_mode = false
var custom_mode = false
var custom_side = 10
var custom_mines = 15
var settings_button: Button
var settings_dialog: ConfirmationDialog
var size_slider: HSlider
var mine_slider: HSlider
var size_value: Label
var mine_value: Label
var settings_note: Label
var selection: ScrollContainer
var play: Control
var game_area: VBoxContainer
var panel_scroll: ScrollContainer
var panel: VBoxContainer
var board_scroll: ScrollContainer
var grid: GridContainer
var cells: Array[Button] = []
var status_label: Label
var count_label: Label
var undo_button: Button
var hint_button: Button
var open_button: Button
var flag_button: Button
var clear_row: HBoxContainer
var sound: AudioStreamPlayer
var effects: Control
var feedback_tweens: Array[Tween] = []

func _ready() -> void:
	UI.setup(self)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	selection = ScrollContainer.new()
	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection.offset_bottom = -UI.BOTTOM_INSET
	selection.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(selection)
	var menu = VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation", 16)
	selection.add_child(menu)
	menu.add_child(UI.label("マインスイーパー", 32))
	menu.add_child(UI.label("なんいどを えらんでね", 24))
	for i in 3:
		var titles = ["かんたん　5 × 5　ばくだん 3こ", "ふつう　10 × 10　ばくだん 15こ", "むずかしい　15 × 15　ばくだん 40こ"]
		var button = UI.button(titles[i], _start.bind(i))
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size.y = 90
		menu.add_child(button)
	menu.add_child(UI.button("カスタマイズ", _start.bind(3)))
	var help = UI.label("すうじは まわりの ばくだんの かず。\nななめも かぞえてね。\nばくだんだと おもったら「はた」！\nながおしでも はたを おけるよ。\nまちがえても「もどる」で やりなおせるよ。", 22)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(help)
	menu.add_child(UI.button("ゲームを えらぶ", _exit))
	play = Control.new()
	add_child(play)
	game_area = VBoxContainer.new()
	game_area.add_theme_constant_override("separation", 12)
	play.add_child(game_area)
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	play.add_child(panel_scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	panel_scroll.add_child(panel)
	panel.add_child(UI.label("マインスイーパー", 26))
	count_label = UI.label("", 22)
	panel.add_child(count_label)
	status_label = UI.label("", 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 64
	panel.add_child(status_label)
	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.custom_minimum_size.y = 100
	board_scroll.follow_focus = true
	game_area.add_child(board_scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.add_child(center)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	center.add_child(grid)
	var modes = _row(game_area)
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	var group = ButtonGroup.new()
	open_button = _mode_button(modes, group, false)
	flag_button = _mode_button(modes, group, true)
	settings_button = ModeButton.new()
	settings_button.is_settings = true
	settings_button.custom_minimum_size = Vector2(104, 76)
	settings_button.tooltip_text = "設定"
	settings_button.pressed.connect(_open_settings)
	modes.add_child(settings_button)
	_build_settings()
	undo_button = _button(panel, "もどる", _undo)
	hint_button = _button(panel, "ヒント", _hint)
	_button(panel, "はじめから", _restart)
	_button(panel, "あたらしく", _start.bind(-1))
	clear_row = _row(panel)
	_button(clear_row, "もういっかい", _start.bind(-1))
	_button(panel, "なんいどを えらぶ", _select)
	effects = Effects.new()
	effects.board_view = board_scroll
	play.add_child(effects)
	play.hide()
	resized.connect(_layout)
	board_scroll.resized.connect(_layout)
	_layout()

func _row(parent: Node) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = UI.button(title, action)
	button.custom_minimum_size.y = 68
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	parent.add_child(button)
	return button

func _mode_button(parent: Node, group: ButtonGroup, is_flag: bool) -> Button:
	var button = ModeButton.new()
	button.is_flag = is_flag
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(104, 76)
	button.tooltip_text = "はた" if is_flag else "あける"
	for style_name in ["normal", "hover", "pressed", "hover_pressed"]:
		var selected = style_name in ["pressed", "hover_pressed"]
		var box = UI.style(UI.GREEN if selected else Color.WHITE, 18)
		if selected:
			box.border_color = Color("164b40")
			box.set_border_width_all(3)
		button.add_theme_stylebox_override(style_name, box)
	button.toggled.connect(func(pressed: bool):
		if pressed: _mode(is_flag)
	)
	parent.add_child(button)
	return button

func _layout() -> void:
	if play == null: return
	play.position = Vector2(12, 12)
	play.size = size - Vector2(24, 24 + UI.BOTTOM_INSET)
	var landscape = size.x > size.y
	if landscape:
		var panel_width = clampf(play.size.x * 0.30, 280, 360)
		game_area.position = Vector2.ZERO
		game_area.size = Vector2(play.size.x - panel_width - 20, play.size.y)
		panel_scroll.position = Vector2(game_area.size.x + 20, 0)
		panel_scroll.size = Vector2(panel_width, play.size.y)
	else:
		var game_height = maxf(240, play.size.y * 0.58)
		game_area.position = Vector2.ZERO
		game_area.size = Vector2(play.size.x, game_height)
		panel_scroll.position = Vector2(0, game_height + 12)
		panel_scroll.size = Vector2(play.size.x, play.size.y - game_height - 12)
	if cells.is_empty(): return
	var available = minf(game_area.size.x - 12, maxf(100, board_scroll.size.y - 12))
	var side = clampf(floor((available - (state.width - 1) * 4) / state.width), 48, 100)
	for cell in cells: cell.custom_minimum_size = Vector2.ONE * side

func _start(difficulty: int) -> void:
	_stop_feedback()
	if difficulty >= 0:
		custom_mode = difficulty == 3
		if custom_mode:
			custom_side = 10
			custom_mines = 15
		else: level = difficulty
	if custom_mode: state.new_custom_game(custom_side, custom_mines)
	else: state.new_game(level)
	settings_button.visible = custom_mode
	flag_mode = false
	for cell in cells:
		grid.remove_child(cell)
		cell.queue_free()
	cells.clear()
	grid.columns = state.width
	for i in state.cells.size():
		var cell = Cell.new()
		cell.add_theme_font_size_override("font_size", 26)
		cell.pressed.connect(_cell_tap.bind(i))
		cell.long_pressed.connect(_tap.bind(i, true))
		board_scroll.scroll_started.connect(cell.cancel_long_press)
		board_scroll.get_h_scroll_bar().value_changed.connect(cell.cancel_long_press)
		board_scroll.get_v_scroll_bar().value_changed.connect(cell.cancel_long_press)
		grid.add_child(cell)
		cells.append(cell)
	selection.hide()
	play.show()
	board_scroll.scroll_horizontal = 0
	board_scroll.scroll_vertical = 0
	_refresh()
	_layout()

func _select() -> void:
	_stop_feedback()
	play.hide()
	selection.show()

func _exit() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/game_select/game_select.tscn")

func _mode(value: bool) -> void:
	flag_mode = value
	_refresh()

func _cell_tap(index: int) -> void:
	if not cells[index].consume_tap(): _tap(index)

func _tap(index: int, force_flag: bool = false) -> void:
	if settings_dialog.visible: return
	var use_flag = flag_mode or force_flag
	var changed: bool = state.flag(index) if use_flag else state.open_cell(index)
	if not changed: return
	_refresh()
	var cell = cells[index]
	cell.modulate = Color("ffe6a0")
	var tween = create_tween()
	tween.tween_property(cell, "modulate", Color.WHITE, 0.22)
	feedback_tweens = feedback_tweens.filter(func(item: Tween): return item.is_valid())
	feedback_tweens.append(tween)
	if state.status == "clear":
		_tone(true)
		effects.begin("clear")
	elif not use_flag and state.cells[index].is_mine:
		effects.begin("miss", cell)
		_burst_sound()
	elif use_flag: _tone(false)

func _undo() -> void:
	_stop_feedback()
	state.undo()
	sound.stop()
	_refresh()

func _restart() -> void:
	_stop_feedback()
	state.restart()
	flag_mode = false
	sound.stop()
	_refresh()

func _hint() -> void:
	state.find_hint()
	_refresh()
	if state.hint >= 0: cells[state.hint].grab_focus()
	status_label.text = "わくの マスは あんぜんだよ！" if state.hint >= 0 else "いまはヒントがみつからないよ"

func _refresh() -> void:
	count_label.text = "のこりのばくだん　%dこ" % (state.mine_count - state.flags() - state.revealed_mines())
	status_label.text = "ばくだんだとおもうマスをえらんでね" if flag_mode else "マスをあけてみよう！"
	if state.last_was_mine: status_label.text = "ばくだんだった！ ほかのマスをさがそう"
	if state.status == "clear": status_label.text = "ぜんぶみつけた！ すごい！"
	undo_button.disabled = state.history.is_empty()
	hint_button.disabled = state.status != "playing"
	clear_row.visible = state.status == "clear"
	open_button.set_pressed_no_signal(not flag_mode)
	flag_button.set_pressed_no_signal(flag_mode)
	open_button.queue_redraw()
	flag_button.queue_redraw()
	for i in cells.size():
		var data = state.cells[i]
		var cell = cells[i]
		cell.flagged = data.is_flagged
		cell.mine = data.is_open and data.is_mine
		cell.text = str(data.adjacent_mines) if data.is_open and not data.is_mine and data.adjacent_mines > 0 else ""
		cell.disabled = data.is_open or state.status != "playing"
		cell.tooltip_text = "%dれつ %dだん" % [i % state.width + 1, i / state.width + 1]
		var color = Color("eeeae1") if data.is_open else Color("d5eadd")
		if cell.mine: color = Color("f9dcd4")
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			var box = UI.style(color.lightened(0.1) if style_name == "hover" else color, 10)
			box.content_margin_left = 0
			box.content_margin_right = 0
			box.content_margin_top = 0
			box.content_margin_bottom = 0
			if i == state.hint:
				box.border_color = Color("b78016")
				box.set_border_width_all(4)
			cell.add_theme_stylebox_override(style_name, box)
		cell.add_theme_color_override("font_disabled_color", Color(COLORS[data.adjacent_mines]))
		cell.queue_redraw()
	_layout()

func _tone(celebrate: bool) -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration = 0.65 if celebrate else 0.10
	var data = PackedByteArray()
	data.resize(int(duration * stream.mix_rate) * 2)
	var notes = [523.25, 659.25, 783.99, 1046.5]
	for i in data.size() / 2:
		var t = float(i) / stream.mix_rate
		var frequency = notes[mini(int(t / 0.16), 3)] if celebrate else 660.0
		var envelope = minf(t * 100, 1) * maxf(0, 1 - fmod(t, 0.16) / 0.16)
		data.encode_s16(i * 2, int(sin(TAU * frequency * t) * 4000 * envelope))
	stream.data = data
	sound.stream = stream
	sound.play()

func _stop_feedback() -> void:
	if effects != null: effects.stop()
	if sound != null: sound.stop()
	for tween in feedback_tweens:
		if tween.is_valid(): tween.kill()
	feedback_tweens.clear()
	for cell in cells:
		cell.cancel_long_press()
		cell.modulate = Color.WHITE

func _burst_sound() -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	data.resize(int(0.28 * stream.mix_rate) * 2)
	for i in data.size() / 2:
		var t = float(i) / stream.mix_rate
		var envelope = minf(t * 150, 1) * pow(maxf(0, 1 - t / 0.28), 2)
		var sample = sin(TAU * (190 * t - 220 * t * t)) + 0.18 * sin(TAU * 610 * t)
		data.encode_s16(i * 2, int(sample * 3800 * envelope))
	stream.data = data
	sound.stream = stream
	sound.play()

func _build_settings() -> void:
	settings_dialog = ConfirmationDialog.new()
	settings_dialog.title = "カスタマイズ"
	settings_dialog.ok_button_text = "決定"
	settings_dialog.cancel_button_text = "戻る"
	settings_dialog.exclusive = true
	settings_dialog.add_theme_stylebox_override("panel", UI.style(Color("f5f2e7"), 18))
	settings_dialog.get_ok_button().custom_minimum_size = Vector2(140, 64)
	settings_dialog.get_cancel_button().custom_minimum_size = Vector2(140, 64)
	add_child(settings_dialog)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	settings_dialog.add_child(content)
	size_value = UI.label("", 24)
	content.add_child(size_value)
	size_slider = _setting_slider(content, 2, 15)
	mine_value = UI.label("", 24)
	content.add_child(mine_value)
	mine_slider = _setting_slider(content, 1, 100)
	settings_note = UI.label("", 20)
	settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_note.custom_minimum_size = Vector2(320, 90)
	content.add_child(settings_note)
	size_slider.value_changed.connect(_settings_changed)
	mine_slider.value_changed.connect(_settings_changed)
	settings_dialog.confirmed.connect(_apply_settings)
	settings_dialog.canceled.connect(func(): settings_button.grab_focus())

func _setting_slider(parent: Node, minimum: int, maximum: int) -> HSlider:
	var row = _row(parent)
	var slider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1
	slider.custom_minimum_size = Vector2(180, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var minus = _button(row, "−", func(): slider.value -= 1)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var plus = _button(row, "＋", func(): slider.value += 1)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return slider

func _open_settings() -> void:
	if not custom_mode: return
	_stop_feedback()
	size_slider.set_value_no_signal(custom_side)
	mine_slider.max_value = custom_side * custom_side
	mine_slider.set_value_no_signal(custom_mines)
	_settings_changed()
	settings_dialog.popup_centered(Vector2i(mini(int(size.x) - 32, 460), 430))
	size_slider.grab_focus()

func _settings_changed(_value: float = 0.0) -> void:
	var side = int(size_slider.value)
	mine_slider.max_value = side * side
	size_value.text = "マス　%d × %d" % [side, side]
	mine_value.text = "ばくだん　%dこ / %dマス" % [int(mine_slider.value), side * side]
	settings_note.text = "「決定」で あたらしい ゲームが はじまるよ。"
	if int(mine_slider.value) == side * side:
		settings_note.text = "ぜんぶ ばくだん！\nあんぜんな マスは ないよ。"

func _apply_settings() -> void:
	custom_side = int(size_slider.value)
	custom_mines = int(mine_slider.value)
	settings_dialog.hide()
	_start(-1)
