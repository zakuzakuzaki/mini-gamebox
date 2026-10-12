extends RefCounted

const LEVELS = [[5, 3], [10, 15], [15, 40]]
var width = 5
var mine_count = 3
var cells: Array = []
var history: Array = []
var generated = false
var status = "playing"
var hint = -1
var last_was_mine = false

func _init() -> void:
	new_game(0)

func new_game(level: int) -> void:
	new_custom_game(LEVELS[level][0], LEVELS[level][1])

func new_custom_game(side: int, mines: int) -> void:
	width = clampi(side, 2, 15)
	mine_count = clampi(mines, 1, width * width)
	generated = false
	cells.clear()
	for i in width * width:
		cells.append({"is_mine": false, "is_open": false, "is_flagged": false, "adjacent_mines": 0})
	restart()

func restart() -> void:
	for cell in cells:
		cell.is_open = false
		cell.is_flagged = false
	history.clear()
	status = "playing"
	last_was_mine = false
	hint = -1

func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x = index % width + dx
			var y = index / width + dy
			if (dx != 0 or dy != 0) and x >= 0 and x < width and y >= 0 and y < width:
				result.append(y * width + x)
	return result

# Replace this generator to add logically solvable boards later.
func generate(first: int) -> void:
	var excluded = neighbors(first)
	excluded.append(first)
	if mine_count > cells.size() - excluded.size(): excluded = [first]
	if mine_count == cells.size(): excluded.clear()
	var candidates: Array[int] = []
	for i in cells.size():
		if not excluded.has(i): candidates.append(i)
	candidates.shuffle()
	for i in mine_count: cells[candidates[i]].is_mine = true
	for i in cells.size():
		for other in neighbors(i):
			if cells[other].is_mine: cells[i].adjacent_mines += 1
	generated = true

func save() -> void:
	history.append({"cells": cells.duplicate(true), "status": status, "last_was_mine": last_was_mine})
	last_was_mine = false
	hint = -1

func open_cell(index: int) -> bool:
	if index < 0 or index >= cells.size() or status != "playing": return false
	if cells[index].is_open or cells[index].is_flagged: return false
	# Generate before snapshotting: undo never changes the mine layout.
	if not generated: generate(index)
	save()
	if cells[index].is_mine:
		cells[index].is_open = true
		last_was_mine = true
		return true
	var pending: Array[int] = [index]
	while not pending.is_empty():
		var current = pending.pop_back()
		var cell = cells[current]
		if cell.is_open or cell.is_flagged or cell.is_mine: continue
		cell.is_open = true
		if cell.adjacent_mines == 0: pending.append_array(neighbors(current))
	status = "clear"
	for cell in cells:
		if not cell.is_mine and not cell.is_open:
			status = "playing"
			break
	return true

func flag(index: int) -> bool:
	if index < 0 or index >= cells.size() or status != "playing" or cells[index].is_open: return false
	save()
	cells[index].is_flagged = not cells[index].is_flagged
	return true

func undo() -> bool:
	if history.is_empty(): return false
	var previous = history.pop_back()
	for i in cells.size():
		cells[i].is_open = previous.cells[i].is_open
		cells[i].is_flagged = previous.cells[i].is_flagged
	status = previous.status
	last_was_mine = previous.last_was_mine
	hint = -1
	return true

func flags() -> int:
	var count = 0
	for cell in cells:
		if cell.is_flagged: count += 1
	return count

# Deduce mines from visible numbers only; user flags are never evidence.
func find_hint() -> int:
	hint = -1
	if status != "playing" or not generated: return hint
	var known_mines: Array[int] = []
	for i in cells.size():
		if cells[i].is_open and cells[i].is_mine: known_mines.append(i)
	var safe: Array[int] = []
	var changed = true
	while changed:
		changed = false
		for i in cells.size():
			if not cells[i].is_open or cells[i].is_mine: continue
			var unknown: Array[int] = []
			var remaining: int = cells[i].adjacent_mines
			for other in neighbors(i):
				if known_mines.has(other): remaining -= 1
				elif not cells[other].is_open and not safe.has(other): unknown.append(other)
			if unknown.is_empty(): continue
			if remaining == 0:
				safe.append_array(unknown)
				changed = true
			elif remaining == unknown.size():
				known_mines.append_array(unknown)
				changed = true
	for index in safe:
		if not cells[index].is_flagged:
			hint = index
			break
	return hint

func revealed_mines() -> int:
	var count = 0
	for cell in cells:
		if cell.is_open and cell.is_mine: count += 1
	return count
