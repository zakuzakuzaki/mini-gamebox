extends SceneTree

const State = preload("res://scenes/games/gomoku/gomoku_state.gd")
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var s = State.new()
	check(not s.undo(), "Empty undo")
	check(not s.place(Vector2i(-1, 0)), "Reject outside")
	check(s.place(Vector2i(0, 0)), "First move")
	check(s.current_player == 2, "Alternate players")
	check(not s.place(Vector2i(0, 0)), "Reject occupied")
	check(s.current_player == 2 and s.move_history.size() == 1, "Invalid move preserves state")
	check(s.undo() and s.current_player == 1 and s.board[0][0] == 0, "Undo restores turn")
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		s.reset()
		var origin = Vector2i(0, 14) if d.y == -1 else Vector2i(0, 0)
		for i in 5:
			check(s.place(origin + d * i), "Place winning line")
			if i < 4: check(s.place(Vector2i(10 + i, 7)), "Other player")
		check(s.winner == 1 and s.game_over and s.winning_positions.size() == 5, "Win in every direction")
		check(not s.place(Vector2i(8, 8)), "No moves after win")
		check(s.undo() and not s.game_over and s.winner == 0 and s.winning_positions.is_empty(), "Undo win")
		check(s.current_player == 1 and s.place(origin + d * 4), "Resume after win")
		while s.undo(): pass
		check(s.move_history.is_empty() and s.current_player == 1, "Undo entire history")
	s.reset()
	for x in [0, 1, 2, 4, 5, 3]:
		check(s.place(Vector2i(x, 0)), "Overline move")
		if x != 3: check(s.place(Vector2i(x * 2, 10)), "Spaced opponent")
	check(s.winner == 1 and s.winning_positions.size() == 6, "Six wins")
	s.reset()
	for i in 5:
		check(s.place(Vector2i(i * 2, 12)), "Black spaced")
		check(s.place(Vector2i(i, 14)), "White line")
	check(s.winner == 2, "White wins")
	s.reset()
	# A full alternating 2-column stripe board has no five-in-a-row.
	for y in 15:
		for x in 15: s.board[y][x] = 1 if (x + 2 * y) % 4 < 2 else 2
	s.board[14][14] = 0
	s.current_player = 1 if (14 + 2 * 14) % 4 < 2 else 2
	for i in 224: s.move_history.append({"position": Vector2i.ZERO, "player": 1})
	check(s.place(Vector2i(14, 14)) and s.game_over and s.winner == 0, "Full board draw")
	check(s.undo() and not s.game_over, "Undo draw")
	s.reset()
	check(s.board.size() == 15 and s.move_history.is_empty() and s.current_player == 1 and not s.game_over, "Reset")
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		s.reset()
		var origin = Vector2i(5, 7)
		for i in 3:
			var p = origin + d * i
			s.board[p.y][p.x] = 2
		var before = s.board.duplicate(true)
		var hint = s.get_hint()
		check(hint.positions.size() == 2 and hint.positions.has(origin - d) and hint.positions.has(origin + d * 3), "Open three endpoints in every direction")
		check(s.board == before and s.move_history.is_empty() and s.current_player == 1, "Hints preserve state")
		var fourth = origin + d * 3
		s.board[fourth.y][fourth.x] = 2
		check(s.get_hint().positions.has(origin + d * 4), "Block opponent four")
		s.board[origin.y - d.y][origin.x - d.x] = 1
		check(s.get_hint().positions.size() == 1, "One blocked end")
	s.reset()
	for x in [3, 4, 6, 7]: s.board[7][x] = 2
	check(s.get_hint().positions == [Vector2i(5, 7)], "Block broken four")
	for x in 4: s.board[0][x] = 1
	check(s.get_hint().positions == [Vector2i(4, 0)], "Winning move takes priority over defense")
	s.place(Vector2i(4, 0))
	check(s.get_hint().positions.is_empty(), "No hints after game ends")
	if failures == 0: print("Gomoku checks passed")
	quit(1 if failures else 0)
