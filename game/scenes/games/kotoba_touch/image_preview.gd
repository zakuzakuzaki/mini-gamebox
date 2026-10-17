extends TextureRect

# STRETCH_KEEP_ASPECT_CENTERED leaves padding inside the Control. Restrict
# both pointer hover and input picking to the rectangle actually drawn.
func _has_point(point: Vector2) -> bool:
	if texture == null or size.x <= 0 or size.y <= 0: return false
	var texture_size = texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0: return false
	var scale_factor = minf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn_size = texture_size * scale_factor
	return Rect2((size - drawn_size) * 0.5, drawn_size).has_point(point)
