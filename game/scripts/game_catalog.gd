extends RefCounted

# Add one entry and a self-contained scene to register another game.
const GAMES = [
	{"title": "マインスイーパー", "subtitle": "あんぜんな マスを さがそう", "icon": "1　2　3", "scene": "res://scenes/games/minesweeper/minesweeper.tscn"},
	{"title": "ごもくならべ", "subtitle": "ふたりで いしを ならべよう", "scene": "res://scenes/games/gomoku/gomoku.tscn"},
	{"title": "まるばつゲーム", "subtitle": "ふたりで みっつ ならべよう", "icon": "○ × ○", "scene": "res://scenes/games/tic_tac_toe/tic_tac_toe.tscn"},
]
