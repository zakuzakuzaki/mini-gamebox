extends SceneTree

const State = preload("res://scenes/games/minesweeper/minesweeper_state.gd")
var failures = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	for side in range(2, 16):
		for mines in [1, side * side - 1, side * side]:
			var custom = State.new()
			custom.new_custom_game(side, mines)
			custom.open_cell(0)
			var count = 0
			for cell in custom.cells:
				if cell.is_mine: count += 1
			check(custom.cells.size() == side * side and count == mines, "Custom size and exact mine count including full board")
			check(custom.last_was_mine and custom.status == "playing" if mines == side * side else not custom.cells[0].is_mine, "Custom first cell safety when possible")
			custom.undo()
			check(custom.status == "playing" and custom.history.is_empty(), "Dense custom board undo")
	for level in 3:
		for trial in 30:
			var state = State.new()
			state.new_game(level)
			var first = trial % state.cells.size()
			check(state.open_cell(first), "First open")
			check(not state.cells[first].is_mine and state.cells[first].adjacent_mines == 0, "Safe first neighborhood")
			var mines = 0
			for i in state.cells.size():
				if state.cells[i].is_mine: mines += 1
				var count = 0
				for other in state.neighbors(i):
					if state.cells[other].is_mine: count += 1
				check(count == state.cells[i].adjacent_mines, "Numbers match eight neighbors")
			check(mines == state.mine_count, "Exact mine count")
			var layout = state.cells.duplicate(true)
			check(state.history.size() == 1 and state.undo(), "Flood is one undo")
			for i in state.cells.size():
				check(not state.cells[i].is_open and state.cells[i].is_mine == layout[i].is_mine, "Undo first retains layout")
			state.flag(first)
			check(not state.open_cell(first), "Flag prevents opening")
			state.flag(first)
			state.undo()
			check(state.cells[first].is_flagged, "Undo unflag")
			state.undo()
			check(not state.cells[first].is_flagged and not state.undo(), "Undo all flags")
			for i in state.cells.size():
				if state.cells[i].is_mine:
					state.open_cell(i)
					check(state.status == "playing" and state.cells[i].is_open and state.last_was_mine, "Mine stays revealed and play continues")
					check(state.flag(first), "Flag after revealing mine")
					state.undo()
					check(state.last_was_mine, "Undo restores mine message")
					check(state.open_cell(first), "Open safe cell after revealing mine")
					state.undo()
					state.undo()
					check(state.status == "playing" and not state.cells[i].is_open, "Undo miss")
					break
			state.open_cell(first)
			# Deliberately flag safe and unsafe cells; hints must ignore guesses.
			for i in state.cells.size():
				if i % 3 == 0: state.flag(i)
			var hint = state.find_hint()
			check(hint == -1 or (not state.cells[hint].is_mine and not state.cells[hint].is_open and not state.cells[hint].is_flagged), "Hint is safe despite incorrect flags")
			state.restart()
			for i in state.cells.size():
				check(state.cells[i].is_mine == layout[i].is_mine, "Restart retains layout")
				if not state.cells[i].is_mine: state.open_cell(i)
			check(state.status == "clear", "All safe cells clears without flags")
			state.undo()
			check(state.status == "playing", "Undo clear")
			state.new_game(level)
			check(not state.generated and state.history.is_empty() and state.hint == -1, "New resets")
	var fixture = State.new()
	fixture.generated = true
	fixture.mine_count = 1
	fixture.cells[0].is_mine = true
	for i in fixture.cells.size():
		fixture.cells[i].adjacent_mines = 1 if fixture.neighbors(i).has(0) else 0
	fixture.cells[1].is_open = true
	fixture.cells[5].is_open = true
	fixture.cells[6].is_open = true
	fixture.cells[2].is_open = true
	fixture.cells[7].is_open = true
	fixture.cells[10].is_open = true
	fixture.cells[11].is_open = true
	fixture.cells[12].is_open = true
	check(fixture.find_hint() >= 0, "Visible constraints yield a hint")
	# A revealed mine is evidence, but its adjacent count is not a clue.
	fixture.restart()
	fixture.cells[0].is_open = true
	check(fixture.find_hint() == -1, "Revealed mine is not a numbered clue")
	fixture.cells[1].is_open = true
	var revealed_hint = fixture.find_hint()
	check(revealed_hint >= 0 and not fixture.cells[revealed_hint].is_mine, "Hints use revealed mines")
	for i in fixture.cells.size():
		if not fixture.cells[i].is_mine: fixture.open_cell(i)
	check(fixture.status == "clear", "Clear remains possible after revealing mine")
	_check_scene.call_deferred()

func _check_scene() -> void:
	var scene = load("res://scenes/games/minesweeper/minesweeper.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.selection.visible and not scene.play.visible, "Difficulty selection first")
	for viewport in [Vector2i(480, 760), Vector2i(1280, 800), Vector2i(800, 1280)]:
		root.size = viewport
		for level in 3:
			scene._start(level)
			await process_frame
			await process_frame
			check(scene.cells.size() == State.LEVELS[level][0] ** 2, "Correct grid size")
			check(scene.play.size.x <= scene.size.x and scene.play.size.y <= scene.size.y, "Controls fit viewport %s level %d play %s scene %s" % [viewport, level, scene.play.size, scene.size])
			check(scene.cells[0].size.x >= 48 and scene.cells[0].size.y >= 48, "Touch targets remain large")
			check(scene.board_scroll.size.y >= 100, "Scrollable board remains visible")
			scene.cells[0].pressed.emit()
			check(not scene.undo_button.disabled, "UI enables undo")
			scene.undo_button.pressed.emit()
			check(scene.undo_button.disabled, "UI syncs undo")
	scene._start(0)
	await process_frame
	await process_frame
	var cell = scene.cells[0]
	var point = cell.global_position + cell.size / 2
	_mouse(point, true)
	await create_timer(0.6).timeout
	check(scene.state.cells[0].is_flagged and not scene.flag_mode, "Long press flags without changing mode")
	_mouse(point, false)
	await process_frame
	check(scene.state.cells[0].is_flagged and not scene.state.cells[0].is_open and scene.state.history.size() == 1, "Release after hold does not tap")
	_mouse(point, true)
	await create_timer(0.6).timeout
	_mouse(point, false)
	await process_frame
	check(not scene.state.cells[0].is_flagged and not scene.state.cells[0].is_open, "Long press removes flag without opening")
	_mouse(point, true)
	var motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(20, 0)
	motion.relative = Vector2(20, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await create_timer(0.6).timeout
	_mouse(point + Vector2(20, 0), false)
	await process_frame
	check(scene.state.history.size() == 2, "Dragging cancels hold and tap")
	_mouse(point, true)
	_mouse(point, false)
	await process_frame
	check(scene.state.cells[0].is_open, "Short tap still opens")
	scene._start(3)
	await process_frame
	check(scene.custom_mode and scene.state.width == 10 and scene.state.mine_count == 15 and scene.settings_button.visible, "Customize starts at normal settings")
	scene._tap(0, true)
	var before = scene.state.cells.duplicate(true)
	var history_size = scene.state.history.size()
	scene._open_settings()
	scene.size_slider.value = 2
	check(scene.mine_slider.max_value == 4 and scene.mine_slider.value <= 4, "Size constrains mine selector")
	scene._tap(1)
	check(scene.state.cells == before, "Modal blocks board input")
	scene.settings_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not scene.settings_dialog.visible and scene.state.cells == before and scene.state.history.size() == history_size, "Cancel keeps current game and history")
	scene._open_settings()
	check(scene.size_slider.value == 10 and scene.mine_slider.value == 15, "Cancel discards edited settings")
	scene.size_slider.value = 2
	scene.mine_slider.value = 4
	scene.settings_dialog.get_ok_button().pressed.emit()
	check(scene.state.width == 2 and scene.state.mine_count == 4 and scene.state.history.is_empty() and scene.cells.size() == 4, "Confirm starts configured board")
	scene._tap(0)
	check(scene.cells[0].mine and not scene.cells[1].disabled and not scene.hint_button.disabled, "UI allows continuing after explosion")
	check(scene.effects.kind == "miss" and scene.status_label.text.contains("ほかのマス"), "Mine still triggers effect and continuation message")
	scene._tap(1)
	check(scene.state.revealed_mines() == 2, "Multiple mines can be revealed without undo")
	scene._undo()
	check(scene.state.revealed_mines() == 1 and scene.effects.kind == "", "Undo hides only the last mine and stops effects")
	scene._start(-1)
	check(scene.state.width == 2 and scene.state.mine_count == 4, "New game preserves custom settings")
	scene._start(1)
	check(not scene.custom_mode and not scene.settings_button.visible, "Presets hide settings gear")
	scene.queue_free()
	await process_frame
	if failures == 0: print("Minesweeper checks passed")
	quit(1 if failures else 0)

func _mouse(point: Vector2, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)
