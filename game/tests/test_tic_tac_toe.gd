extends SceneTree

const State = preload("res://scenes/games/tic_tac_toe/tic_tac_toe_state.gd")
var failures = 0
var results = {0: 0, 1: 0, 2: 0}

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

# Visit every legal game, including wins on the ninth move and both diagonals.
func visit(state: RefCounted) -> void:
	if state.game_over:
		results[state.winner] += 1
		check(not state.place(Vector2i.ZERO), "Reject moves after game ends")
		if state.winner:
			check(state.winning_positions.size() >= 3, "Highlight winning marks")
		return
	for y in 3:
		for x in 3:
			if state.board[y][x] != 0: continue
			var before = state.board.duplicate(true)
			var player: int = state.current_player
			check(state.place(Vector2i(x, y)), "Legal move")
			visit(state)
			check(state.undo(), "Undo every move, including wins and draws")
			check(state.board == before and state.current_player == player and not state.game_over and state.winner == 0 and state.winning_positions.is_empty(), "Undo restores state")

func _initialize() -> void:
	var state = State.new()
	check(not state.undo(), "Empty undo")
	for p in [Vector2i(-1, 0), Vector2i(3, 0), Vector2i(0, -1), Vector2i(0, 3)]:
		check(not state.place(p), "Reject outside")
	state.place(Vector2i.ZERO)
	check(not state.place(Vector2i.ZERO) and state.current_player == 2 and state.move_history.size() == 1, "Occupied move preserves turn")
	state.reset()
	check(state.move_history.is_empty() and state.current_player == 1 and state.board[0][0] == 0, "Reset")
	visit(state)
	check(results == {0: 46080, 1: 131184, 2: 77904}, "All 255168 legal games have the expected outcomes")
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		for player in [1, 2]:
			state.reset()
			var origin = Vector2i(0, 2) if direction.y == -1 else Vector2i.ZERO
			for i in 2:
				var p = origin + direction * i
				state.board[p.y][p.x] = player
			var before = state.board.duplicate(true)
			var hint = state.get_hint()
			check(hint.positions.has(origin + direction * 2), "Hint finds every winning direction for both players")
			check(hint.kind == ("win" if player == 1 else "defend"), "Attack and defense hints")
			check(state.board == before and state.current_player == 1 and state.move_history.is_empty(), "Hints preserve state")
	state.reset()
	state.board[0] = [1, 1, 0]
	state.board[1] = [2, 2, 0]
	check(state.get_hint().positions == [Vector2i(2, 0)], "Attack takes priority")
	_check_scene.call_deferred()

func _check_scene() -> void:
	var scene = load("res://scenes/games/tic_tac_toe/tic_tac_toe.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.cells.size() == 9 and scene.undo_button.disabled, "Scene starts with nine cells")
	for p in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]:
		scene.cells[p.y * 3 + p.x].pressed.emit()
	check(scene.status.text == "○ まるの かち！", "UI shows winner")
	check(scene.celebration.celebrating and scene.celebration.is_processing(), "Win starts sparks")
	check(scene.hint_label.text == "", "No hints after win")
	for cell in scene.cells: check(cell.disabled, "Finished board disabled")
	scene._undo()
	check(not scene.celebration.celebrating and not scene.celebration.is_processing(), "Undo clears celebration")
	check(scene.cells[2].show_hint, "Winning move is highlighted")
	scene._toggle_hint(false, 1)
	check(not scene.cells[2].show_hint and scene.hint_label.text == "", "Player can hide hints")
	scene._toggle_hint(true, 1)
	check(scene.cells[2].show_hint, "Player can restore hints")
	check(not scene.cells[2].disabled and scene.status.text == "○ まるの ばん", "UI resumes after undo")
	scene._restart()
	check(scene.undo_button.disabled and scene.cells[0].mark == 0, "UI restarts")
	for dimensions in [Vector2(480, 760), Vector2(760, 480)]:
		scene.size = dimensions
		scene._layout()
		await process_frame
		check(scene.board.position.x + scene.board.size.x <= dimensions.x and scene.panel_scroll.position.y + scene.panel_scroll.size.y <= dimensions.y, "Layout fits portrait and landscape")
	scene.queue_free()
	if failures == 0: print("Tic tac toe checks passed")
	quit(1 if failures else 0)
