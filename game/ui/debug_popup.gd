extends CanvasLayer

const UI = preload("res://ui/ui.gd")
var dialog: AcceptDialog
var details_label: Label
var pending: Array[Dictionary] = []

func _ready() -> void:
	layer = 100
	# Embed the dialog so it works in Web exports as well as native games.
	dialog = AcceptDialog.new()
	dialog.force_native = false
	add_child(dialog)
	dialog.ok_button_text = "とじる"
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -64
	dialog.add_child(scroll)
	details_label = UI.label("", 20)
	UI.setup(details_label)
	dialog.theme = details_label.theme
	dialog.theme.set_stylebox("panel", "AcceptDialog", UI.style(Color("f5f2e8")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		dialog.get_ok_button().add_theme_color_override(state, UI.INK)
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	details_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details_label)
	dialog.confirmed.connect(_next.call_deferred)
	dialog.canceled.connect(_next.call_deferred)
	get_viewport().size_changed.connect(_fit_dialog)

# Shared debugging entry point, including release Web builds used on devices.
func show_error(source: String, message: String, details: String = "") -> void:
	pending.append({"source": source, "message": message, "details": details})
	if not dialog.visible: _next()

func _next() -> void:
	if pending.is_empty(): return
	var entry: Dictionary = pending.pop_front()
	dialog.title = "デバッグ: " + str(entry.source)
	details_label.text = str(entry.message)
	if not str(entry.details).is_empty():
		details_label.text += "\n\n" + str(entry.details)
	_fit_dialog()

func _fit_dialog() -> void:
	if not dialog.visible and details_label.text.is_empty(): return
	var viewport_size = get_viewport().get_visible_rect().size
	dialog.popup_centered(Vector2i(minf(720, viewport_size.x - 32), minf(480, viewport_size.y - 32)))
