extends RefCounted

const SIZE = 3
var board: Array = []
var current_player: int = 1
var move_history: Array[Dictionary] = []
var last_position = Vector2i(-1, -1)
var game_over: bool = false
var winner: int = 0
var winning_positions: Array[Vector2i] = []

func _init() -> void:
	reset()

func reset() -> void:
	board.clear()
	for y in SIZE:
		var row: Array[int] = []
		row.resize(SIZE)
		row.fill(0)
		board.append(row)
	current_player = 1
	move_history.clear()
	last_position = Vector2i(-1, -1)
	game_over = false
	winner = 0
	winning_positions.clear()

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE

func place(p: Vector2i) -> bool:
	if game_over or not inside(p) or board[p.y][p.x] != 0:
		return false
	board[p.y][p.x] = current_player
	move_history.append({"position": p, "player": current_player})
	last_position = p
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var line: Array[Vector2i] = [p]
		for sign_value in [-1, 1]:
			var next: Vector2i = p + direction * sign_value
			while inside(next) and board[next.y][next.x] == current_player:
				line.append(next)
				next += direction * sign_value
		if line.size() >= 3:
			for point in line:
				if not winning_positions.has(point): winning_positions.append(point)
	if not winning_positions.is_empty():
		winner = current_player
		game_over = true
	elif move_history.size() == SIZE * SIZE:
		game_over = true
	else:
		current_player = 3 - current_player
	return true

func undo() -> bool:
	if move_history.is_empty(): return false
	var move: Dictionary = move_history.pop_back()
	board[move.position.y][move.position.x] = 0
	current_player = move.player
	last_position = move_history.back().position if not move_history.is_empty() else Vector2i(-1, -1)
	winner = 0
	game_over = false
	winning_positions.clear()
	return true

# Hypothetical checks never change turns, history, or the visible board.
func would_win(p: Vector2i, player: int) -> bool:
	if not inside(p) or board[p.y][p.x] != 0: return false
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var count = 1
		for sign_value in [-1, 1]:
			var q: Vector2i = p + d * sign_value
			while inside(q) and board[q.y][q.x] == player:
				count += 1
				q += d * sign_value
		if count >= 3: return true
	return false

func winning_moves(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			var p = Vector2i(x, y)
			if would_win(p, player): result.append(p)
	return result

func get_hint() -> Dictionary:
	if game_over: return {"positions": [], "text": ""}
	var wins = winning_moves(current_player)
	if not wins.is_empty(): return {"kind": "win", "positions": wins, "text": "ここで みっつ！"}
	var blocks = winning_moves(3 - current_player)
	if not blocks.is_empty():
		return {"kind": "defend", "positions": blocks, "text": "ここを とめよう！" if blocks.size() == 1 else "ピンチ！ みっつの場所が ふたつ"}
	return {"positions": [], "text": "たて・よこ・ななめに みっつ！"}
