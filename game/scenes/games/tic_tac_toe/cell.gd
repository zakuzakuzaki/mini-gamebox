extends Button

const UI = preload("res://ui/ui.gd")
var show_hint = false
var hint_color = UI.GREEN
var mark: int = 0:
	set(value):
		mark = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var side = minf(size.x, size.y)
	var center = size / 2.0
	if mark == 0:
		if show_hint:
			var inset = side * 0.10
			var corners = [Vector2(inset, inset), Vector2(size.x - inset, inset), size - Vector2.ONE * inset, Vector2(inset, size.y - inset)]
			for i in 4:
				draw_dashed_line(corners[i], corners[(i + 1) % 4], hint_color, maxf(2.0, side * 0.025), side * 0.07, true, true)
		return
	var width = side * 0.085
	var radius = side * 0.40
	var color = UI.GREEN if mark == 1 else Color("b34b42")
	if mark == 1:
		draw_arc(center, radius, 0, TAU, 128, color, width, true)
	else:
		for direction in [Vector2(1, 1), Vector2(1, -1)]:
			var start = center - direction * radius
			var end = center + direction * radius
			draw_line(start, end, color, width, true)
			draw_circle(start, width / 2.0, color, true, -1, true)
			draw_circle(end, width / 2.0, color, true, -1, true)
