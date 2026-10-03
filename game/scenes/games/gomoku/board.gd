extends Control

signal played(position: Vector2i)
var state: RefCounted
var hint_positions: Array = []
var hint_color = Color("267565")
var celebration_time = -1.0
var celebrating = false

func sync_celebration() -> void:
	if state.winner != 0 and not celebrating:
		celebrating = true
		celebration_time = 0.0
		set_process(true)
	elif state.winner == 0:
		celebrating = false
		celebration_time = -1.0
		set_process(false)

func _process(delta: float) -> void:
	celebration_time += delta
	queue_redraw()
	if celebration_time > 2.4: set_process(false)

var cursor = Vector2i(7, 7)

func _ready() -> void:
	set_process(false)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func geometry() -> Vector3:
	var side = minf(size.x, size.y) - 4.0
	return Vector3((size.x - side) / 2.0, (size.y - side) / 2.0, side)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var g = geometry()
		var step = g.z / 15.0
		var local = event.position - Vector2(g.x, g.y) - Vector2.ONE * step / 2.0
		var p = Vector2i(roundi(local.x / step), roundi(local.y / step))
		if state.inside(p) and Rect2(Vector2(g.x, g.y), Vector2.ONE * g.z).has_point(event.position):
			cursor = p
			played.emit(p)
		accept_event()
	if event is InputEventKey and event.pressed:
		var moved = true
		match event.keycode:
			KEY_LEFT: cursor.x = maxi(0, cursor.x - 1)
			KEY_RIGHT: cursor.x = mini(14, cursor.x + 1)
			KEY_UP: cursor.y = maxi(0, cursor.y - 1)
			KEY_DOWN: cursor.y = mini(14, cursor.y + 1)
			KEY_SPACE, KEY_ENTER: played.emit(cursor)
			_: moved = false
		if moved:
			queue_redraw()
			accept_event()

func _draw() -> void:
	if state == null: return
	var g = geometry()
	var step = g.z / 15.0
	var start = Vector2(g.x, g.y) + Vector2.ONE * step / 2.0
	var panel = preload("res://ui/ui.gd").style(Color("edcf9c"), 18)
	draw_style_box(panel, Rect2(Vector2(g.x, g.y), Vector2.ONE * g.z))
	for i in 15:
		draw_line(start + Vector2(i * step, 0), start + Vector2(i * step, 14 * step), Color("a38a62"), 1.3, true)
		draw_line(start + Vector2(0, i * step), start + Vector2(14 * step, i * step), Color("a38a62"), 1.3, true)
	for p in [Vector2(3, 3), Vector2(11, 3), Vector2(7, 7), Vector2(3, 11), Vector2(11, 11)]:
		draw_circle(start + p * step, 3, Color("967951"))
	for y in 15:
		for x in 15:
			var player: int = state.board[y][x]
			if player == 0: continue
			var center = start + Vector2(x, y) * step
			var radius = step * 0.42
			draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.17))
			draw_circle(center, radius, Color("293637") if player == 1 else Color("fffdf5"), true, -1, true)
			if state.winning_positions.has(Vector2i(x, y)):
				draw_arc(center, radius + 2, 0, TAU, 40, Color("268a68"), 4, true)

	for p in hint_positions:
		var center = start + Vector2(p) * step
		draw_circle(center, step * 0.33, Color(hint_color, 0.22), true, -1, true)
		draw_arc(center, step * 0.33, 0, TAU, 32, hint_color, 3, true)
	if celebrating:
		_draw_celebration(start, step)

func _draw_celebration(start: Vector2, step: float) -> void:
	# Draw each winning direction independently, including crossing wins.
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var first: Vector2i = state.last_position
		var last = first
		while state.winning_positions.has(first - d): first -= d
		while state.winning_positions.has(last + d): last += d
		if maxi(absi(last.x - first.x), absi(last.y - first.y)) < 4: continue
		var a = start + Vector2(first) * step
		var b = start + Vector2(last) * step
		draw_line(a, b, Color(1, 0.7, 0.15, 0.4), 10, true)
		draw_line(a, b, Color("fff2b0"), 3, true)
		if celebration_time > 2.4: continue
		for i in 90:
			var delay = float(i % 15) * 0.035
			var age = celebration_time - delay
			if age < 0 or age > 1.8: continue
			var angle = float(i) * 2.39996
			var velocity = Vector2(cos(angle), sin(angle)) * (35 + i % 7 * 13)
			var origin = a.lerp(b, float(i % 31) / 30.0)
			var point = origin + velocity * age + Vector2(0, 65 * age * age)
			var color = Color("ffca45") if i % 2 == 0 else Color("fff9dc")
			color.a = maxf(0, 1.0 - age / 1.8)
			draw_line(point, point - velocity.normalized() * 7, color, 3, true)
