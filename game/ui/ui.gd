extends RefCounted

# Extra space above tablet system gestures, in logical viewport pixels.
const BOTTOM_INSET = 48

const INK = Color("283c3c")
const GREEN = Color("267565")

static func style(color: Color, radius: int = 22) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func setup(root: Control) -> void:
	var theme = Theme.new()
	var font = FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansJP.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	theme.default_font = font
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color = Color("ffffff")
		if state == "hover": color = Color("e3f0e9")
		if state == "pressed": color = Color("c8e1d5")
		if state == "disabled": color = Color("e6e6df")
		var box = style(color)
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = GREEN
			box.set_border_width_all(3)
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", GREEN)
	theme.set_color("font_pressed_color", "Button", GREEN)
	theme.set_color("font_disabled_color", "Button", Color("969e98"))
	root.theme = theme

static func label(text: String, font_size: int = 24) -> Label:
	var result = Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size)
	return result

static func button(text: String, action: Callable) -> Button:
	var result = Button.new()
	result.text = text
	result.custom_minimum_size.y = 68
	result.pressed.connect(action)
	return result

static func column(root: Control) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	margin.add_theme_constant_override("margin_bottom", 24 + BOTTOM_INSET)
	root.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	return column
