extends Control

const UI = preload("res://ui/ui.gd")
const Kana = preload("res://scenes/games/kotoba_touch/kana.gd")
const ImagePreview = preload("res://scenes/games/kotoba_touch/image_preview.gd")
const WikipediaImages = preload("res://scenes/games/kotoba_touch/wikipedia_images.gd")
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
var candidate_list: VBoxContainer
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
var content_panel: Control
var content_column: VBoxContainer
var keyboard: GridContainer
var keys: Array[Button] = []
var modes: Array[Button] = []
var bridge: JavaScriptObject
var browser_speech_error_callback: JavaScriptObject
var browser_input_callback: JavaScriptObject
var animation: Tween
var photos = WikipediaImages.new()

func _ready() -> void:
	UI.setup(self)
	add_child(photos)
	photos.result_ready.connect(_show_result)
	# Browser APIs stay isolated from native Godot and the other games.
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scenes/games/kotoba_touch/browser.js"), true)
		bridge = JavaScriptBridge.get_interface("kotobaTouch")
		browser_input_callback = JavaScriptBridge.create_callback(_flush_browser_input)
		if bridge:
			bridge.setInputCallback(browser_input_callback)
			browser_speech_error_callback = JavaScriptBridge.create_callback(_browser_speech_error)
			bridge.setSpeechErrorCallback(browser_speech_error_callback)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	margin.add_theme_constant_override("margin_bottom", 16 + UI.BOTTOM_INSET)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	# Keep the upper area fixed; fit its contents into the space above the keys.
	content_panel = Control.new()
	content_panel.size_flags_vertical = SIZE_EXPAND_FILL
	content_panel.clip_contents = true
	layout.add_child(content_panel)
	var column = VBoxContainer.new()
	content_column = column
	column.add_theme_constant_override("separation", 10)
	content_panel.add_child(column)
	content_panel.resized.connect(_fit_upper_content)
	column.minimum_size_changed.connect(_fit_upper_content)
	input_limit_label = UI.label("これいじょう にゅうりょくできません", 21)
	input_limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_limit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_limit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_panel.add_child(input_limit_label)
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
	result_box.size_flags_vertical = SIZE_EXPAND_FILL
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
	gallery_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	gallery_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	image_box.add_child(gallery_scroll)
	candidate_list = VBoxContainer.new()
	candidate_list.size_flags_vertical = SIZE_EXPAND_FILL
	candidate_list.alignment = BoxContainer.ALIGNMENT_CENTER
	candidate_list.add_theme_constant_override("separation", 12)
	image_box.add_child(candidate_list)
	candidate_list.hide()
	image_box.size_flags_stretch_ratio = 3.0
	gallery = HBoxContainer.new()
	gallery.size_flags_horizontal = SIZE_EXPAND_FILL
	gallery.size_flags_vertical = SIZE_EXPAND_FILL
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

func _fit_upper_content() -> void:
	if content_column == null or content_panel.size.y <= 0: return
	# Measure at the available width first, so a previous scale never feeds back
	# into the next layout. Horizontal scrolling remains inside the word/gallery.
	content_column.size.x = content_panel.size.x
	input_limit_label.size.x = content_panel.size.x
	var notice_height = input_limit_label.get_combined_minimum_size().y
	input_limit_label.position.y = maxf(0.0, content_panel.size.y - notice_height)
	var available_height = content_panel.size.y
	if input_text.length() >= MAX_INPUT_LENGTH:
		available_height = maxf(1.0, available_height - notice_height - 10.0)
	var minimum = content_column.get_combined_minimum_size()
	var factor = minf(1.0, available_height / maxf(minimum.y, 1.0))
	factor = minf(factor, content_panel.size.x / maxf(minimum.x, 1.0))
	content_column.scale = Vector2.ONE * factor
	content_column.size = Vector2(content_panel.size.x, available_height) / factor

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
	# Headless tests have no audio backend.
	if DisplayServer.get_name() == "headless": return
	if OS.has_feature("web") and bridge:
		bridge.speak(text)
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_tts_error("unsupported", text)
		return
	# Re-query on each interaction: Web voices may load after scene startup.
	var voices = DisplayServer.tts_get_voices_for_language("ja")
	if voices.is_empty():
		DisplayServer.tts_stop()
		_tts_error("japanese_voice_unavailable", text)
		return
	DisplayServer.tts_speak(text, voices[0], 100, 1.0, 0.85, 0, true)

func _browser_speech_error(arguments: Array) -> void:
	_tts_error(str(arguments[0]), str(arguments[1]))

func _tts_error(code: String, text: String) -> void:
	get_node("/root/DebugPopup").show_error("TTS", "読み上げに失敗しました",
		JSON.stringify({"code": code, "text": text, "lang": "ja", "platform": OS.get_name()}))

func _stop_speech() -> void:
	if bridge:
		bridge.stopSpeech()
		return
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

func _flush_browser_input(_arguments: Array) -> void:
	Input.flush_buffered_events()

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
	_stop_speech()
	input_text = ""
	confirmed = ""
	photos.cancel()
	_reset_result()
	_refresh()

func _refresh() -> void:
	input_label.text = input_text if not input_text.is_empty() else "もじを タッチしてね"
	var at_limit = input_text.length() >= MAX_INPUT_LENGTH
	# The notice shares the upper area; the bottom-anchored keyboard never moves.
	input_limit_label.modulate.a = 1.0 if at_limit else 0.0
	_fit_upper_content()
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
	for candidate in candidate_list.get_children():
		candidate_list.remove_child(candidate)
		candidate.queue_free()
	candidate_list.hide()
	gallery.get_parent().show()
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
	message.text = "さがしているよ…"
	photos.search(confirmed)

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
				var card = VBoxContainer.new()
				card.custom_minimum_size.x = 240
				card.size_flags_horizontal = SIZE_EXPAND_FILL
				card.add_theme_constant_override("separation", 6)
				gallery.add_child(card)
				var title: String = item.get("title", confirmed)
				var preview = ImagePreview.new()
				preview.custom_minimum_size = Vector2(240, 210)
				preview.size_flags_horizontal = SIZE_EXPAND_FILL
				preview.size_flags_vertical = SIZE_EXPAND_FILL
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.texture = ImageTexture.create_from_image(image)
				preview.set_meta("article_url", item.get("article_url", ""))
				preview.set_meta("article_title", title)
				preview.mouse_filter = Control.MOUSE_FILTER_STOP
				preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				preview.gui_input.connect(_picture_input.bind(preview))
				card.add_child(preview)
				var caption = UI.label(title, 20)
				caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				caption.max_lines_visible = 2
				caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				caption.tooltip_text = title
				card.add_child(caption)
				if picture == null: picture = preview
			if picture == null:
				_show_text_candidates(result.get("candidates", result.get("images", [result])))
				return
			image_box.show()
			gallery.modulate.a = 0.0
			animation = create_tween()
			animation.tween_property(gallery, "modulate:a", 1.0, 0.25)
			message.text = ""
		"text": _show_text_candidates(result.get("candidates", []))
		"network": message.text = "つながらなかったよ。もういちど ためしてね"
		"wait": message.text = "すこし まってから けっていしてね"
		"ambiguous": message.text = "どの ことばかな？ ちがう ことばで ためしてね"
		"not_found": message.text = "ことばが みつからなかったよ"
		_: message.text = "しゃしんが みつからなかったよ"

func _show_text_candidates(candidates: Array) -> void:
	var seen: Dictionary = {}
	for candidate in candidates:
		var title: String = candidate.get("title", "")
		if title.is_empty() or seen.has(title): continue
		seen[title] = true
		var label = UI.label(title, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		candidate_list.add_child(label)
		if seen.size() == 3: break
	if seen.is_empty():
		message.text = "しゃしんが みつからなかったよ"
		return
	gallery.get_parent().hide()
	candidate_list.show()
	image_box.show()
	message.text = ""

func _open_link(url: String) -> void:
	if url.begins_with("https://commons.wikimedia.org/") or url.begins_with("https://ja.wikipedia.org/") or url.begins_with("https://creativecommons.org/"):
		OS.shell_open(url)

func _back() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/game_select/game_select.tscn")

func _exit_tree() -> void:
	_stop_speech()
	if bridge:
		bridge.setInputCallback(null)
		bridge.setSpeechErrorCallback(null)
	photos.cancel()

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
	panel.offset_bottom = -UI.BOTTOM_INSET
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UI.style(Color("f5f2e8")))
	image_modal.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(top)
	modal_title = UI.label("", 24)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.size_flags_horizontal = SIZE_EXPAND_FILL
	modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	column.add_child(modal_title)
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
	modal_title.text = preview.get_meta("article_title", confirmed)
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
