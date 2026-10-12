extends Button

var is_flag = false
var is_settings = false

func _draw() -> void:
	var c = size / 2
	var ink = Color("ffffff") if button_pressed else Color("283c3c")
	if is_settings:
		for i in 8:
			var direction = Vector2.from_angle(TAU * i / 8)
			draw_line(c + direction * 16, c + direction * 24, ink, 8, true)
		draw_arc(c, 15, 0, TAU, 48, ink, 7, true)
		draw_arc(c, 6, 0, TAU, 32, ink, 3, true)
	elif is_flag:
		draw_line(c + Vector2(-12, 20), c + Vector2(-12, -21), ink, 4, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -21), c + Vector2(22, -10), c + Vector2(-8, 2)]), ink)
		draw_line(c + Vector2(-20, 21), c + Vector2(5, 21), ink, 4, true)
	else:
		# A lifted tile with a pointer shows the open-cell action.
		draw_style_box(_tile_style(ink), Rect2(c + Vector2(-22, -22), Vector2(32, 32)))
		var pointer = PackedVector2Array([c + Vector2(-2, -5), c + Vector2(21, 9), c + Vector2(11, 12), c + Vector2(17, 23), c + Vector2(10, 27), c + Vector2(4, 16), c + Vector2(-3, 23)])
		draw_colored_polygon(pointer, ink)

func _tile_style(color: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(3)
	box.set_corner_radius_all(5)
	return box
