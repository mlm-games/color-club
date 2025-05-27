@tool
class_name SVGEllipse
extends SVGElement

@export var radius_x: float = 10.0:
	set(value):
		radius_x = max(0, value)
		_update_size()
		queue_redraw()

@export var radius_y: float = 10.0:
	set(value):
		radius_y = max(0, value)
		_update_size()
		queue_redraw()

func _calculate_shape_bounds() -> Rect2:
	return Rect2(-radius_x, -radius_y, radius_x * 2, radius_y * 2)

func _draw_content() -> void:
	var draw_offset = _get_draw_offset()
	var center = draw_offset + Vector2(radius_x, radius_y)
	
	# Draw fill
	if fill_color.a > 0:
		var points = _generate_ellipse_points(center, radius_x, radius_y, 64)
		if points.size() > 2:
			draw_colored_polygon(points, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		var points = _generate_ellipse_points(center, radius_x, radius_y, 64)
		if points.size() > 1:
			points.append(points[0])  # Close the ellipse
			draw_polyline(points, stroke_color, stroke_width, true)

func _generate_ellipse_points(center: Vector2, rx: float, ry: float, point_count: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(point_count):
		var angle = float(i) / point_count * TAU
		var x = center.x + rx * cos(angle)
		var y = center.y + ry * sin(angle)
		points.append(Vector2(x, y))
	return points

func set_ellipse_properties(attributes: Dictionary) -> void:
	if "rx" in attributes:
		radius_x = float(attributes["rx"])
	if "ry" in attributes:
		radius_y = float(attributes["ry"])
	
	# Apply common attributes
	set_common_attributes(attributes)
	
	# Handle center positioning
	var cx = 0.0
	var cy = 0.0
	if "cx" in attributes:
		cx = float(attributes["cx"])
	if "cy" in attributes:
		cy = float(attributes["cy"])
	
	# Position so ellipse center is at cx,cy
	position = Vector2(cx - radius_x - stroke_width * 0.5, cy - radius_y - stroke_width * 0.5)
