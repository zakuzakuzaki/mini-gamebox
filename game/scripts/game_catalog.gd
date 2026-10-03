extends RefCounted

# Add one entry and a self-contained scene to register another game.
const GAMES = [
	{"title": "ごもくならべ", "subtitle": "ふたりで いしを ならべよう", "scene": "res://scenes/games/gomoku/gomoku.tscn"},
	{"title": "まるばつゲーム", "subtitle": "ふたりで みっつ ならべよう", "icon": "○ × ○", "scene": "res://scenes/games/tic_tac_toe/tic_tac_toe.tscn"},
]
