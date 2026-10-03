extends Control

const UI = preload("res://ui/ui.gd")
const Catalog = preload("res://scripts/game_catalog.gd")

func _ready() -> void:
	UI.setup(self)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var top = Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top)
	column.add_child(UI.label("いっしょに あそぼう", 24))
	column.add_child(UI.label("どのゲームで あそぶ？", 32))
	for game in Catalog.GAMES:
		var card = UI.button(game.get("icon", "● ○ ● ○ ●") + "

" + game.title + "
" + game.subtitle, func(): get_tree().change_scene_to_file.call_deferred(game.scene))
		card.custom_minimum_size = Vector2(0, 200)
		card.add_theme_font_size_override("font_size", 24)
		column.add_child(card)
	column.add_child(UI.label("すきな ゲームを タップしてね", 22))
	var bottom = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom)
