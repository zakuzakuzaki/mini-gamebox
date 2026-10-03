extends Control

var state: RefCounted
var board: GridContainer
var celebration_time = -1.0
var celebrating = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	board.resized.connect(queue_redraw)

func _center(position: Vector2i) -> Vector2:
	var cell = board.get_child(position.y * 3 + position.x) as Control
	return board.position + cell.position + cell.size / 2.0

func sync_celebration() -> void:
	if state.winner != 0 and not celebrating:
		celebrating = true
		celebration_time = 0.0
		set_process(true)
	elif state.winner == 0:
		celebrating = false
		celebration_time = -1.0
		set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	celebration_time += delta
	queue_redraw()
	if celebration_time > 2.4: set_process(false)

func _draw() -> void:
	if not celebrating: return
	# Draw each winning direction independently, including crossing wins.
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var first: Vector2i = state.last_position
		var last = first
		while state.winning_positions.has(first - d): first -= d
		while state.winning_positions.has(last + d): last += d
		if maxi(absi(last.x - first.x), absi(last.y - first.y)) < 2: continue
		var a = _center(first)
		var b = _center(last)
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
