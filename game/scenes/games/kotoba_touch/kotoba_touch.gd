extends Control

const UI = preload("res://ui/ui.gd")
const Kana = preload("res://scenes/games/kotoba_touch/kana.gd")
const ImagePreview = preload("res://scenes/games/kotoba_touch/image_preview.gd")
const MAX_INPUT_LENGTH = 20
var input_text = ""
var confirmed = ""
var hiragana_mode = false
var spoken: Array[String] = []
var input_label: Label
var input_scroll: ScrollContainer
var confirm_button: Button
var erase_button: Button
var clear_button: Button
var long_mark_button: Button
var input_limit_label: Label
var result_word: Label
var message: Label
var picture: TextureRect
var gallery: HBoxContainer
var image_modal: Control
var modal_picture: TextureRect
var modal_title: Label
var modal_wiki: Button
var article_url = ""
var modal_close: Button
var previous_focus: Control
var result_box: HBoxContainer
var heading: BoxContainer
var input_row: BoxContainer
var image_box: VBoxContainer
var keyboard_dock: HBoxContainer
var content_scroll: ScrollContainer
var keyboard: GridContainer
var keys: Array[Button] = []
var modes: Array[Button] = []
var bridge: JavaScriptObject
var animation: Tween

func _ready() -> void:
	UI.setup(self)
	# Browser APIs stay isolated from native Godot and the other games.
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scenes/games/kotoba_touch/browser.js"), true)
		bridge = JavaScriptBridge.get_interface("kotobaTouch")
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	# Only the upper content scrolls. The keyboard's height and bottom edge never
	# depend on result text, image dimensions, credits, or loading/error states.
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	layout.add_child(content_scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	content_scroll.add_child(column)
	input_limit_label = UI.label("これいじょう にゅうりょくできません", 21)
	input_limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_limit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_limit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(input_limit_label)
	keyboard_dock = HBoxContainer.new()
	keyboard_dock.add_theme_constant_override("separation", 10)
	layout.add_child(keyboard_dock)
	heading = BoxContainer.new()
	column.add_child(heading)
	heading.add_child(_button("もどる", _back))
	var title = UI.label("ことばタッチ", 28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(title)
	var mode_row = HBoxContainer.new()
	mode_row.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(mode_row)
	for mode in [true, false]:
		var button = _button("ひらがな" if mode else "カタカナ", _set_mode.bind(mode))
		button.toggle_mode = true
		mode_row.add_child(button)
		modes.append(button)
	input_row = BoxContainer.new()
	column.add_child(input_row)
	input_scroll = ScrollContainer.new()
	input_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	input_scroll.custom_minimum_size.y = 70
	input_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	input_row.add_child(input_scroll)
	input_label = UI.label("", 40)
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	input_scroll.add_child(input_label)
	erase_button = _button("1もじけす", _erase)
	clear_button = _button("ぜんぶけす", _clear)
	confirm_button = _button("けってい", _confirm)
	result_box = HBoxContainer.new()
	column.add_child(result_box)
	image_box = VBoxContainer.new()
	image_box.size_flags_horizontal = SIZE_EXPAND_FILL
	result_box.add_child(image_box)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	result_box.add_child(details)
	result_word = UI.label("", 34)
	result_word.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	details.add_child(result_word)
	message = UI.label("", 22)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(message)
	var gallery_scroll = ScrollContainer.new()
	gallery_scroll.custom_minimum_size.y = 230
	gallery_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	image_box.add_child(gallery_scroll)
	image_box.size_flags_stretch_ratio = 3.0
	gallery = HBoxContainer.new()
	gallery.size_flags_horizontal = SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("separation", 12)
	gallery_scroll.add_child(gallery)
	var result_actions = VBoxContainer.new()
	details.add_child(result_actions)
	result_actions.add_child(_button("もういちどきく", func(): _speak(confirmed)))
	var key_column = VBoxContainer.new()
	key_column.size_flags_horizontal = SIZE_EXPAND_FILL
	key_column.add_theme_constant_override("separation", 10)
	keyboard_dock.add_child(key_column)
	var edit = VBoxContainer.new()
	edit.add_theme_constant_override("separation", 10)
	keyboard_dock.add_child(edit)
	edit.add_child(erase_button)
	edit.add_child(clear_button)
	var edit_space = Control.new()
	edit_space.size_flags_vertical = SIZE_EXPAND_FILL
	edit.add_child(edit_space)
	confirm_button.custom_minimum_size.y = 120
	edit.add_child(confirm_button)
	keyboard = GridContainer.new()
	keyboard.columns = 10
	keyboard.add_theme_constant_override("h_separation", 6)
	keyboard.add_theme_constant_override("v_separation", 6)
	key_column.add_child(keyboard)
	# Traditional gojuon: vowel rows, consonant columns, right to left.
	for vowel in 5:
		for row in range(9, -1, -1):
			var character: String = Kana.ROWS[row][vowel]
			var button = _button(character, func(): pass)
			button.custom_minimum_size.y = 52
			button.add_theme_font_size_override("font_size", 28)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var box = button.get_theme_stylebox(state)
				box.content_margin_top = 5
				box.content_margin_bottom = 5
			button.set_meta("kana", character)
			button.pressed.connect(func(): _append(Kana.hiragana(character) if hiragana_mode else character))
			button.disabled = character == " "
			if button.disabled: button.modulate.a = 0.0
			keyboard.add_child(button)
			keys.append(button)
	var modifiers = HBoxContainer.new()
	key_column.add_child(modifiers)
	for entry in [["゛", "voiced"], ["゜", "semi"], ["こもじ", "small"]]:
		modifiers.add_child(_button(entry[0], _modify.bind(entry[1])))
	long_mark_button = _button("ー", _append.bind("ー"))
	modifiers.add_child(long_mark_button)
	if not bridge:
		var hint = UI.label("こえと しゃしんは ブラウザで あそんでね", 18)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(hint)
	_build_image_modal()
	_set_mode(false)
	_reset_result()
	_refresh()
	resized.connect(_layout)
	_layout()

func _button(text: String, action: Callable) -> Button:
	var button = UI.button(text, action)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 60
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_focus_color", UI.INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box = theme.get_stylebox(state, "Button").duplicate()
		if state == "disabled": box.bg_color = Color("d4d4d4")
		# Compact horizontal padding keeps ten large keys within a tablet viewport.
		box.content_margin_left = 8
		box.content_margin_right = 8
		button.add_theme_stylebox_override(state, box)
	return button

func _layout() -> void:
	if keyboard == null: return
	var wide = size.x >= 760
	input_limit_label.add_theme_font_size_override("font_size", 21 if wide else 18)
	keyboard.columns = 10 if wide else 5
	for button in [erase_button, clear_button, confirm_button]:
		button.custom_minimum_size.x = 156 if wide else 128
		button.add_theme_font_size_override("font_size", 21 if wide else 18)
	for key in keys:
		key.custom_minimum_size.y = 52 if wide else 44
		key.add_theme_font_size_override("font_size", 28 if wide else 22)
	heading.vertical = size.x < 1000
	input_row.vertical = size.x < 1000

func _set_mode(mode: bool) -> void:
	hiragana_mode = mode
	for button in keys:
		button.text = Kana.hiragana(button.get_meta("kana")) if mode else button.get_meta("kana")
	modes[0].set_pressed_no_signal(mode)
	modes[1].set_pressed_no_signal(not mode)

func _speak(text: String) -> void:
	if text.is_empty(): return
	spoken.append(text)
	if spoken.size() > 32: spoken.pop_front()
	if bridge: bridge.speak(text)

func _append(character: String) -> void:
	if character.strip_edges().is_empty(): return
	if input_text.length() + character.length() > MAX_INPUT_LENGTH: return
	var sound = Kana.prolonged_sound(input_text) if character == "ー" else character
	input_text += character
	_refresh()
	_speak(sound)

func _modify(kind: String) -> void:
	var changed = Kana.transform(input_text, kind)
	if changed == input_text: return
	input_text = changed
	_refresh()
	_speak(input_text.right(1))

func _erase() -> void:
	input_text = input_text.left(-1)
	_refresh()

func _clear() -> void:
	input_text = ""
	confirmed = ""
	if bridge: bridge.cancel()
	_reset_result()
	_refresh()

func _refresh() -> void:
	input_label.text = input_text if not input_text.is_empty() else "もじを タッチしてね"
	var at_limit = input_text.length() >= MAX_INPUT_LENGTH
	# Reserve the message's space even when empty so the keys never move.
	input_limit_label.modulate.a = 1.0 if at_limit else 0.0
	for key in keys:
		key.disabled = at_limit or key.get_meta("kana") == " "
	long_mark_button.disabled = at_limit
	confirm_button.disabled = input_text.is_empty()
	erase_button.disabled = input_text.is_empty()
	clear_button.disabled = input_text.is_empty() and confirmed.is_empty()
	_scroll_to_end.call_deferred()

func _scroll_to_end() -> void:
	input_scroll.scroll_horizontal = int(input_scroll.get_h_scroll_bar().max_value)

func _reset_result() -> void:
	_close_image_modal()
	if animation: animation.kill()
	for preview in gallery.get_children():
		gallery.remove_child(preview)
		preview.queue_free()
	picture = null
	image_box.hide()
	article_url = ""
	result_box.hide()

func _confirm() -> void:
	if input_text.is_empty(): return
	confirmed = input_text
	input_text = ""
	_refresh()
	_speak(confirmed)
	_reset_result()
	result_box.show()
	result_word.text = confirmed
	message.text = "さがしているよ…" if bridge else "しゃしんは ブラウザで みてね"
	if bridge: bridge.search(confirmed)

func _process(_delta: float) -> void:
	if not bridge: return
	var payload: String = bridge.take()
	if payload.is_empty(): return
	var result = JSON.parse_string(payload)
	if result is Dictionary: _show_result(result)

func _show_result(result: Dictionary) -> void:
	if result.get("word", "") != confirmed or confirmed.is_empty(): return
	match result.get("status", ""):
		"image":
			for item in result.get("images", [result]):
				var image = Image.new()
				var bytes = Marshalls.base64_to_raw(item.get("image", ""))
				var error = ERR_FILE_UNRECOGNIZED
				if bytes.size() >= 12:
					if bytes[0] == 0xff and bytes[1] == 0xd8:
						error = image.load_jpg_from_buffer(bytes)
					elif bytes[0] == 0x89 and bytes.slice(1, 4).get_string_from_ascii() == "PNG":
						error = image.load_png_from_buffer(bytes)
					elif bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
						error = image.load_webp_from_buffer(bytes)
				if error != OK: continue
				var preview = ImagePreview.new()
				preview.custom_minimum_size = Vector2(240, 210)
				preview.size_flags_horizontal = SIZE_EXPAND_FILL
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.texture = ImageTexture.create_from_image(image)
				preview.set_meta("article_url", item.get("article_url", ""))
				preview.mouse_filter = Control.MOUSE_FILTER_STOP
				preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				preview.gui_input.connect(_picture_input.bind(preview))
				gallery.add_child(preview)
				if picture == null: picture = preview
			if picture == null:
				message.text = "しゃしんが みつからなかったよ"
				return
			image_box.show()
			gallery.modulate.a = 0.0
			animation = create_tween()
			animation.tween_property(gallery, "modulate:a", 1.0, 0.25)
			message.text = ""
		"network": message.text = "つながらなかったよ。もういちど ためしてね"
		"wait": message.text = "すこし まってから けっていしてね"
		"ambiguous": message.text = "どの ことばかな？ ちがう ことばで ためしてね"
		"not_found": message.text = "ことばが みつからなかったよ"
		_: message.text = "しゃしんが みつからなかったよ"

func _open_link(url: String) -> void:
	if url.begins_with("https://commons.wikimedia.org/") or url.begins_with("https://ja.wikipedia.org/") or url.begins_with("https://creativecommons.org/"):
		OS.shell_open(url)

func _back() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/game_select/game_select.tscn")

func _exit_tree() -> void:
	if bridge: bridge.cancel()

func _build_image_modal() -> void:
	image_modal = Control.new()
	image_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(image_modal)
	var backdrop = Button.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		backdrop.add_theme_stylebox_override(state, UI.style(Color(0.05, 0.09, 0.09, 0.8), 0))
	backdrop.pressed.connect(_close_image_modal)
	image_modal.add_child(backdrop)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.06
	panel.anchor_top = 0.05
	panel.anchor_right = 0.94
	panel.anchor_bottom = 0.95
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UI.style(Color("f5f2e8")))
	image_modal.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var top = HBoxContainer.new()
	column.add_child(top)
	modal_title = UI.label("", 30)
	modal_title.size_flags_horizontal = SIZE_EXPAND_FILL
	modal_title.clip_text = true
	top.add_child(modal_title)
	modal_close = _button("とじる", _close_image_modal)
	modal_close.size_flags_horizontal = SIZE_SHRINK_END
	top.add_child(modal_close)
	# Keep keyboard focus inside the modal while it is open.
	modal_close.focus_next = modal_close.get_path()
	modal_close.focus_previous = modal_close.get_path()
	modal_picture = TextureRect.new()
	modal_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	modal_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	modal_picture.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(modal_picture)
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	modal_wiki = _button("Wikipedia", func(): _open_link(article_url))
	modal_wiki.size_flags_horizontal = SIZE_SHRINK_END
	modal_wiki.custom_minimum_size.y = 48
	modal_wiki.add_theme_font_size_override("font_size", 18)
	footer.add_child(modal_wiki)
	modal_close.focus_next = modal_wiki.get_path()
	modal_close.focus_previous = modal_wiki.get_path()
	modal_wiki.focus_next = modal_close.get_path()
	modal_wiki.focus_previous = modal_close.get_path()
	image_modal.hide()

func _picture_input(event: InputEvent, preview: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		preview.accept_event()
		_open_image_modal(preview)

func _open_image_modal(preview: TextureRect = null) -> void:
	if preview == null: preview = picture
	if preview == null or preview.texture == null: return
	article_url = preview.get_meta("article_url", "")
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_picture.texture = preview.texture
	modal_title.text = confirmed
	modal_wiki.disabled = article_url.is_empty()
	image_modal.show()
	modal_close.grab_focus()

func _close_image_modal() -> void:
	if image_modal == null: return
	image_modal.hide()
	modal_picture.texture = null
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	previous_focus = null

func _input(event: InputEvent) -> void:
	if image_modal != null and image_modal.visible and event.is_action_pressed("ui_cancel"):
		_close_image_modal()
		get_viewport().set_input_as_handled()
