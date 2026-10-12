extends Control

const PALETTE = [Color("efbd42"), Color("e8757d"), Color("55ac91"), Color("699fd5"), Color("a488cf")]
var board_view: Control
var target: Control
var kind = ""
var elapsed = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)

func begin(effect: String, cell: Control = null) -> void:
	kind = effect
	target = cell
	elapsed = 0.0
	set_process(true)
	_sync_rect()
	queue_redraw()

func stop() -> void:
	kind = ""
	target = null
	set_process(false)
	queue_redraw()

func _sync_rect() -> void:
	global_position = board_view.global_position
	size = board_view.size

func _process(delta: float) -> void:
	elapsed += delta
	_sync_rect()
	if elapsed >= (3.2 if kind == "clear" else 1.15):
		stop()
	else:
		queue_redraw()

func _draw() -> void:
	if kind == "clear": _draw_clear()
	elif kind == "miss" and is_instance_valid(target): _draw_burst()

func _draw_clear() -> void:
	var fade = clampf((3.2 - elapsed) / 0.6, 0, 1)
	# A small, fixed particle count keeps the effect light on tablets.
	for i in 64:
		var age = elapsed - float(i % 8) * 0.055
		if age < 0: continue
		var origin = Vector2(size.x * (0.18 if i % 2 == 0 else 0.82), size.y * 0.58)
		var velocity = Vector2(sin(i * 2.39996) * size.x * 0.32, -150.0 - i % 9 * 22)
		var point = origin + velocity * age + Vector2(0, 115 * age * age)
		var color: Color = PALETTE[i % PALETTE.size()]
		color.a = fade
		var direction = Vector2.from_angle(age * 4 + i)
		draw_line(point - direction * 5, point + direction * 5, color, 5, true)
	for i in 12:
		var point = Vector2(size.x * (0.08 + fmod(i * 0.273, 0.84)), size.y * (0.12 + fmod(i * 0.193, 0.7)))
		var radius = (5 + 5 * sin(elapsed * 5 + i)) * fade
		_star(point, radius, Color(1, 0.77, 0.22, fade))
	var font = get_theme_default_font()
	var text = "やったね！"
	var font_size = 36
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var center = Vector2(size.x / 2, size.y * 0.30)
	var box = StyleBoxFlat.new()
	box.bg_color = Color(1, 0.98, 0.90, 0.94 * fade)
	box.set_corner_radius_all(24)
	box.border_color = Color(0.93, 0.72, 0.23, fade)
	box.set_border_width_all(3)
	draw_style_box(box, Rect2(center - text_size / 2 - Vector2(22, 10), text_size + Vector2(44, 20)))
	draw_string(font, center + Vector2(-text_size.x / 2, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.46, 0.39, fade))

func _draw_burst() -> void:
	var center = target.global_position + target.size / 2 - global_position
	var progress = elapsed / 1.15
	var fade = 1.0 - progress
	var radius = minf(target.size.x, target.size.y) * 0.55
	var expansion = 1 - pow(1 - progress, 3)
	# Rounded puffs and a soft ring, without screen shake or flashing.
	for i in 8:
		var direction = Vector2.from_angle(TAU * i / 8)
		var point = center + direction * radius * expansion * 1.8
		draw_circle(point, radius * (0.24 + progress * 0.25), Color(1, 0.70, 0.38, fade * 0.72))
		draw_line(center + direction * radius * (0.4 + expansion), center + direction * radius * (0.7 + expansion * 1.8), Color(0.93, 0.49, 0.29, fade), 4, true)
	draw_arc(center, radius * (0.5 + expansion * 1.8), 0, TAU, 48, Color(1, 0.77, 0.42, fade), 4, true)
	_star(center, radius * (1 - progress) * 0.75, Color(1, 0.89, 0.61, fade))

func _star(center: Vector2, radius: float, color: Color) -> void:
	if radius < 1.0: return
	var points = PackedVector2Array()
	for i in 8:
		points.append(Vector2.from_angle(PI * i / 4) * radius * (1.0 if i % 2 == 0 else 0.3))
	draw_set_transform(center)
	draw_colored_polygon(points, color)
	draw_set_transform(Vector2.ZERO)
