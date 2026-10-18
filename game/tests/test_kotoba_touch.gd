extends SceneTree

const Kana = preload("res://scenes/games/kotoba_touch/kana.gd")
var failures = 0

func check(value: bool, description: String) -> void:
	if not value:
		push_error(description)
		failures += 1

func _initialize() -> void:
	_check_image_hit_area()
	check(Kana.transform("ハ", "voiced") == "バ", "Voiced kana")
	check(Kana.transform("バ", "semi") == "パ", "Semi voiced from voiced")
	check(Kana.transform("ぱ", "voiced") == "ば", "Hiragana voiced from semi voiced")
	check(Kana.transform("バ", "voiced") == "ハ", "Toggle voiced")
	check(Kana.transform("ウ", "voiced") == "ヴ", "Voiced u")
	check(Kana.transform("ね", "voiced") == "ね", "Unsupported transformation is unchanged")
	check(Kana.transform("", "small") == "", "Empty transformation")
	check(Kana.transform("ジュ", "small") == "ジユ", "Toggle small kana")
	check(Kana.transform("つ", "small") == "っ", "Small hiragana")
	check(Kana.hiragana("ジュース") == "じゅーす", "Hiragana conversion preserves prolonged mark")
	for pair in [["カ", "あ"], ["き", "い"], ["ジュ", "う"], ["ぺ", "え"], ["ショ", "お"], ["ティ", "い"], ["ヴ", "う"], ["コーー", "お"], ["", "ンー"], ["ン", "ンー"], ["ッ", "ンー"]]:
		check(Kana.prolonged_sound(pair[0]) == pair[1], "Long mark speech: " + pair[0])
	_check_scene.call_deferred()

func _check_image_hit_area() -> void:
	var preview = preload("res://scenes/games/kotoba_touch/image_preview.gd").new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(600, 120)
	check(not preview._has_point(Vector2(300, 60)), "Empty image is not clickable")
	preview.texture = ImageTexture.create_from_image(Image.create(100, 200, false, Image.FORMAT_RGB8))
	check(preview._has_point(Vector2(300, 60)), "Portrait image center is clickable")
	check(not preview._has_point(Vector2(100, 60)) and not preview._has_point(Vector2(500, 60)), "Side padding is not clickable")
	preview.size = Vector2(120, 200)
	preview.texture = ImageTexture.create_from_image(Image.create(200, 100, false, Image.FORMAT_RGB8))
	check(preview._has_point(Vector2(60, 100)), "Landscape image center is clickable after resize")
	check(not preview._has_point(Vector2(60, 20)) and not preview._has_point(Vector2(60, 180)), "Top and bottom padding are not clickable")
	preview.free()

func _check_scene() -> void:
	var scene = load("res://scenes/games/kotoba_touch/kotoba_touch.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.confirm_button.disabled and not scene.result_box.visible, "Empty initial state")
	check(scene.keys.size() == 50 and not scene.hiragana_mode, "Shared 50-position katakana keyboard")
	for letter in ["ネ", "コ"]:
		for key in scene.keys:
			if key.text == letter: key.pressed.emit()
	check(scene.input_text == "ネコ" and scene.spoken == ["ネ", "コ"], "Tap speaks individual characters")
	scene._confirm()
	check(scene.input_text.is_empty() and scene.confirm_button.disabled, "Confirm clears input for next word")
	check(scene.confirmed == "ネコ" and scene.spoken.back() == "ネコ", "Confirm speaks word")
	scene._show_result({"word": "old", "status": "network"})
	check(scene.message.text != "つながらなかったよ。もういちど ためしてね", "Ignore stale result")
	scene._clear()
	scene._set_mode(true)
	for letter in ["ね", "こ"]:
		for key in scene.keys:
			if key.text == letter: key.pressed.emit()
	check(scene.input_text == "ねこ", "Hiragana tapping")
	scene._confirm()
	check(scene.spoken.back() == "ねこ", "Hiragana word speech")
	scene._erase()
	scene._set_mode(false)
	scene._append("コ")
	check(scene.input_text == "コ", "Next input starts fresh after confirmation")
	scene._clear()
	scene._append("ハ")
	scene._modify("voiced")
	scene._append("ナ")
	scene._append("ナ")
	check(scene.input_text == "バナナ", "Banana input")
	scene._clear()
	scene._append("シ")
	scene._modify("voiced")
	scene._append("ユ")
	scene._modify("small")
	scene._append("ー")
	check(scene.input_text == "ジュー" and scene.spoken.back() == "う", "Long mark speaks vowel while preserving input")
	scene._append("ス")
	check(scene.input_text == "ジュース", "Juice input")
	scene._confirm()
	scene._show_result({"word": "ジュース", "status": "network"})
	scene._append("ア")
	check(scene.input_text == "ア", "Network failure preserves editing")
	scene._clear()
	check(scene.input_text.is_empty() and scene.confirmed.is_empty() and not scene.result_box.visible, "Clear resets result and input")
	var sample = Image.create(16, 16, false, Image.FORMAT_RGB8)
	var encoded = Marshalls.raw_to_base64(sample.save_png_to_buffer())
	scene._append("カキ")
	scene._confirm()
	scene._append("ネ")
	scene._show_result({"word": "カキ", "status": "image", "images": [
		{"image": encoded, "article_url": "https://ja.wikipedia.org/wiki/柿"},
		{"image": encoded, "article_url": "https://ja.wikipedia.org/wiki/牡蠣"}]})
	check(scene.gallery.get_child_count() == 2, "Show multiple candidates while typing next word")
	scene._open_image_modal(scene.gallery.get_child(1))
	check(scene.article_url.ends_with("牡蠣"), "Modal link belongs to tapped image")
	check(scene.input_text == "ネ" and scene.confirmed == "カキ", "Search result preserves next input")
	scene._close_image_modal()
	scene._clear()
	for i in 20: scene._append("ハ")
	check(scene.keys.all(func(key): return key.disabled) and scene.long_mark_button.disabled, "Adding keys disabled at limit")
	check(scene.input_limit_label.modulate.a == 1.0, "Show input limit message at 20 characters")
	var speech_count: int = scene.spoken.size()
	scene._append("ア")
	scene._append("ー")
	check(scene.input_text.length() == 20 and scene.spoken.size() == speech_count, "Reject extra characters without speech at limit")
	scene._modify("voiced")
	check(scene.input_text.length() == 20 and scene.input_text.ends_with("バ"), "Modifiers still work at limit")
	scene._erase()
	check(not scene.long_mark_button.disabled, "Long mark re-enabled after deletion")
	check(scene.input_limit_label.modulate.a == 0.0, "Hide input limit message after deletion")
	for key in scene.keys:
		check(key.disabled == (key.get_meta("kana") == " "), "Kana keys re-enabled while blanks stay disabled")
	scene._append("コ")
	check(scene.input_text.length() == 20 and scene.input_text.ends_with("コ"), "Deletion allows replacement at limit")
	scene._confirm()
	scene._append("ネ")
	check(scene.input_text == "ネ" and scene.confirmed.length() == 20, "Confirm resets input capacity")
	await _check_fixed_keyboard(scene)
	scene.queue_free()
	await process_frame
	if failures == 0: print("Kotoba touch checks passed")
	quit(1 if failures else 0)

func _settle_layout() -> void:
	for frame in 4: await process_frame

func _check_fixed_keyboard(scene: Control) -> void:
	var sample = Image.create(16, 16, false, Image.FORMAT_RGB8)
	sample.fill(Color.GREEN)
	for viewport_size in [Vector2i(1216, 760), Vector2i(480, 760)]:
		root.size = viewport_size
		scene._clear()
		await _settle_layout()
		var positions: Array[Rect2] = []
		var fixed_keys: Array = Array(scene.keys) + [scene.erase_button, scene.clear_button, scene.confirm_button]
		for key in fixed_keys: positions.append(key.get_global_rect())
		check(scene.erase_button.get_global_rect().position.x >= scene.keyboard.get_global_rect().end.x, "Editing keys sit to the right of kana")
		check(scene.confirm_button.get_global_rect().position.y > scene.clear_button.get_global_rect().end.y, "Enter sits at bottom right")
		var dock_rect: Rect2 = scene.keyboard_dock.get_global_rect()
		check(absf(dock_rect.end.y - (scene.size.y - 16)) < 1, "Keyboard is anchored to bottom")
		check(scene.content_panel.size.y > 100, "Upper content retains usable space")
		for status in ["loading", "image", "not_found", "network", "limit", "clear", "mode"]:
			if status == "clear": scene._clear()
			elif status == "mode": scene._set_mode(not scene.hiragana_mode)
			elif status == "limit":
				scene.input_text = "ア".repeat(20)
				scene._refresh()
			else:
				scene.input_text = "ネコ"
				scene._confirm()
				if status == "image":
					scene._show_result({"word": "ネコ", "status": "image", "image": Marshalls.raw_to_base64(sample.save_png_to_buffer()),
						"credit": "ながい クレジット ".repeat(40), "license": "CC BY-SA", "source": "", "license_url": ""})
				elif status != "loading": scene._show_result({"word": "ネコ", "status": status})
			await _settle_layout()
			for i in fixed_keys.size():
				check(fixed_keys[i].get_global_rect().is_equal_approx(positions[i]), "Every key stays fixed: " + status)
			check(scene.keyboard_dock.get_global_rect().is_equal_approx(dock_rect), "Modifier keys stay fixed: " + status)
			check(scene.content_panel.get_global_rect().end.y <= dock_rect.position.y, "Content cannot overlap keyboard")
			check(scene.content_column.get_global_rect().end.y <= scene.content_panel.get_global_rect().end.y + 1, "Upper content fits without vertical scrolling: " + status)
