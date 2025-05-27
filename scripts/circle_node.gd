@tool
class_name SVGCircle
extends SVGElement

@export var radius: float = 10.0:
	set(value):
		radius = max(0, value)
		_update_size()
		queue_redraw()

func _calculate_shape_bounds() -> Rect2:
	return Rect2(-radius, -radius, radius * 2, radius * 2)

func _draw_content() -> void:
	var draw_offset = _get_draw_offset()
	var center = draw_offset + Vector2(radius, radius)
	
	# Draw fill
	if fill_color.a > 0:
		draw_circle(center, radius, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		draw_arc(center, radius, 0, TAU, 64, stroke_color, stroke_width, true)

func set_circle_properties(attributes: Dictionary) -> void:
	if "r" in attributes:
		radius = float(attributes["r"])
	
	# Apply common attributes first
	set_common_attributes(attributes)
	
	# Handle center positioning - keep original logic
	var cx = 0.0
	var cy = 0.0
	if "cx" in attributes:
		cx = float(attributes["cx"])
	if "cy" in attributes:
		cy = float(attributes["cy"])
	
	# Position so circle center is at cx,cy (original working logic)
	position = Vector2(cx - radius - stroke_width * 0.5, cy - radius - stroke_width * 0.5)
	
	# Apply transform if it exists
	if has_transform:
		_apply_svg_transform()
