extends Control

const UI = preload("res://ui/ui.gd")
const Catalog = preload("res://scripts/game_catalog.gd")

var column: VBoxContainer

func _ready() -> void:
	UI.setup(self)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	column.add_child(UI.label("いっしょに あそぼう", 24))
	column.add_child(UI.label("どのゲームで あそぶ？", 32))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for game in Catalog.GAMES:
		var card = UI.button("", func(): get_tree().change_scene_to_file.call_deferred(game.scene))
		card.custom_minimum_size = Vector2(0, 200)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = game.title
		grid.add_child(card)
		var padding = MarginContainer.new()
		padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge in ["left", "right", "top", "bottom"]:
			padding.add_theme_constant_override("margin_" + edge, 12)
		card.add_child(padding)
		var content = VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 12)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		padding.add_child(content)
		for item in [[game.get("icon", "● ○ ● ○ ●"), 26], [game.title, 20], [game.subtitle, 16]]:
			var label = UI.label(item[0], item[1])
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(label)
	column.add_child(UI.label("すきな ゲームを タップしてね", 22))
	resized.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	column.custom_minimum_size.x = minf(760.0, maxf(0.0, size.x - 48.0))
