extends Control

const UI = preload("res://ui/ui.gd")
const Catalog = preload("res://scripts/game_catalog.gd")

func _ready() -> void:
	UI.setup(self)
	var column = UI.column(self)
	var top = Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top)
	column.add_child(UI.label("いっしょに あそぼう", 24))
	column.add_child(UI.label("どのゲームで あそぶ？", 32))
	for game in Catalog.GAMES:
		var card = UI.button("● ○ ● ○ ●

" + game.title + "
" + game.subtitle, func(): get_tree().change_scene_to_file.call_deferred(game.scene))
		card.custom_minimum_size = Vector2(0, 270)
		card.add_theme_font_size_override("font_size", 24)
		column.add_child(card)
	column.add_child(UI.label("すきな ゲームを タップしてね", 22))
	var bottom = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom)
