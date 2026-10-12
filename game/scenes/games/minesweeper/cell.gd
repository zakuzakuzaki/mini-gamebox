extends Button

signal long_pressed

const HOLD_SECONDS = 0.5
const DRAG_DISTANCE = 12.0
var holding = false
var hold_time = 0.0
var press_position = Vector2.ZERO
var suppress_tap = false

func _ready() -> void:
	set_process(false)
	mouse_exited.connect(cancel_long_press)
	visibility_changed.connect(cancel_long_press)

func _gui_input(event: InputEvent) -> void:
	# Touch is already mapped to mouse by the project settings. Handle one
	# stream only so a touch cannot toggle the flag twice.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not disabled:
			suppress_tap = false
			holding = true
			hold_time = 0.0
			press_position = global_position + event.position
			set_process(true)

func _input(event: InputEvent) -> void:
	if not holding: return
	if event is InputEventMouseMotion and event.position.distance_to(press_position) > DRAG_DISTANCE:
		cancel_long_press()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		holding = false
		set_process(false)

func _process(delta: float) -> void:
	if disabled or not is_visible_in_tree():
		cancel_long_press()
		return
	hold_time += delta
	if hold_time >= HOLD_SECONDS:
		holding = false
		suppress_tap = true
		set_process(false)
		long_pressed.emit()

func cancel_long_press(_value: float = 0.0) -> void:
	if holding: suppress_tap = true
	holding = false
	set_process(false)

func consume_tap() -> bool:
	var suppressed = suppress_tap
	suppress_tap = false
	return suppressed

var flagged = false
var mine = false

func _draw() -> void:
	var center = size / 2
	if flagged:
		draw_line(center + Vector2(-8, 14), center + Vector2(-8, -15), Color("283c3c"), 3, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -15), center + Vector2(15, -7), center + Vector2(-6, 1)]), Color("cf5552"))
		draw_line(center + Vector2(-14, 15), center + Vector2(5, 15), Color("283c3c"), 3, true)
	if mine:
		draw_circle(center + Vector2(0, 3), 12, Color("626579"))
		draw_arc(center + Vector2(6, -10), 6, PI, TAU, 12, Color("626579"), 3, true)
		draw_circle(center + Vector2(-4, -1), 3, Color.WHITE)
