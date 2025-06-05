@tool
class_name SVGRect
extends SVGElement

@export var rect_width: float = 10.0:
	set(value):
		rect_width = max(0, value)
		_update_size()
		queue_redraw()

@export var rect_height: float = 10.0:
	set(value):
		rect_height = max(0, value)
		_update_size()
		queue_redraw()

@export var corner_radius_x: float = 0.0:
	set(value):
		corner_radius_x = max(0, value)
		queue_redraw()

@export var corner_radius_y: float = 0.0:
	set(value):
		corner_radius_y = max(0, value)
		queue_redraw()

func _calculate_content_bounds() -> Rect2:
	return Rect2(0, 0, rect_width, rect_height)

func _draw_content() -> void:
	var draw_offset = _get_draw_offset()
	var shape_rect = Rect2(draw_offset, Vector2(rect_width, rect_height))
	
	# Draw fill
	if fill_color.a > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			_draw_rounded_rect_fill(shape_rect, corner_radius_x, corner_radius_y, fill_color)
		else:
			draw_rect(shape_rect, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		if corner_radius_x > 0 or corner_radius_y > 0:
			_draw_rounded_rect_stroke(shape_rect, corner_radius_x, corner_radius_y, stroke_color, stroke_width)
		else:
			draw_rect(shape_rect, stroke_color, false, stroke_width)

func _draw_rounded_rect_fill(rect: Rect2, rx: float, ry: float, color: Color) -> void:
	# Ensure radii don't exceed half the rectangle dimensions
	rx = min(rx, rect.size.x * 0.5)
	ry = min(ry, rect.size.y * 0.5)
	
	# Create a path for the rounded rectangle
	var points = _get_rounded_rect_points(rect, rx, ry, 16)
	if points.size() > 2:
		draw_colored_polygon(points, color)

func _draw_rounded_rect_stroke(rect: Rect2, rx: float, ry: float, color: Color, width: float) -> void:
	rx = min(rx, rect.size.x * 0.5)
	ry = min(ry, rect.size.y * 0.5)
	
	var points = _get_rounded_rect_points(rect, rx, ry, 16)
	if points.size() > 1:
		points.append(points[0])  # Close the path
		draw_polyline(points, color, width, true)

func _get_rounded_rect_points(rect: Rect2, rx: float, ry: float, segments_per_corner: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	
	# Top-left corner
	var center = rect.position + Vector2(rx, ry)
	for i in range(segments_per_corner + 1):
		var angle = PI + (PI * 0.5) * float(i) / float(segments_per_corner)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	
	# Top-right corner
	center = rect.position + Vector2(rect.size.x - rx, ry)
	for i in range(1, segments_per_corner + 1):
		var angle = PI * 1.5 + (PI * 0.5) * float(i) / float(segments_per_corner)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	
	# Bottom-right corner
	center = rect.position + Vector2(rect.size.x - rx, rect.size.y - ry)
	for i in range(1, segments_per_corner + 1):
		var angle = (PI * 0.5) * float(i) / float(segments_per_corner)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	
	# Bottom-left corner
	center = rect.position + Vector2(rx, rect.size.y - ry)
	for i in range(1, segments_per_corner + 1):
		var angle = PI * 0.5 + (PI * 0.5) * float(i) / float(segments_per_corner)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	
	return points

func set_rect_properties(attributes: Dictionary) -> void:
	# Parse dimensions
	if "width" in attributes:
		rect_width = float(attributes["width"])
	if "height" in attributes:
		rect_height = float(attributes["height"])
	if "rx" in attributes:
		corner_radius_x = float(attributes["rx"])
		if not "ry" in attributes:
			corner_radius_y = corner_radius_x
	if "ry" in attributes:
		corner_radius_y = float(attributes["ry"])
		if not "rx" in attributes:
			corner_radius_x = corner_radius_y
	
	# Apply common attributes (including position)
	set_common_attributes(attributes)
	
	# Apply transform after all properties are set
	apply_svg_transform()

func _has_point(point: Vector2) -> bool:
	var content_rect = Rect2(_get_draw_offset(), Vector2(rect_width, rect_height))
	
	if corner_radius_x > 0 or corner_radius_y > 0:
		# For rounded rectangles, check if point is inside the rounded shape
		return _point_in_rounded_rect(point, content_rect, corner_radius_x, corner_radius_y)
	else:
		return content_rect.has_point(point)

func _point_in_rounded_rect(point: Vector2, rect: Rect2, rx: float, ry: float) -> bool:
	# Quick bounds check
	if not rect.has_point(point):
		return false
	
	# Check corners
	var rel_x = point.x - rect.position.x
	var rel_y = point.y - rect.position.y
	
	# Top-left corner
	if rel_x < rx and rel_y < ry:
		var dx = (rel_x - rx) / rx
		var dy = (rel_y - ry) / ry
		return dx * dx + dy * dy <= 1.0
	
	# Top-right corner
	if rel_x > rect.size.x - rx and rel_y < ry:
		var dx = (rel_x - (rect.size.x - rx)) / rx
		var dy = (rel_y - ry) / ry
		return dx * dx + dy * dy <= 1.0
	
	# Bottom-left corner
	if rel_x < rx and rel_y > rect.size.y - ry:
		var dx = (rel_x - rx) / rx
		var dy = (rel_y - (rect.size.y - ry)) / ry
		return dx * dx + dy * dy <= 1.0
	
	# Bottom-right corner
	if rel_x > rect.size.x - rx and rel_y > rect.size.y - ry:
		var dx = (rel_x - (rect.size.x - rx)) / rx
		var dy = (rel_y - (rect.size.y - ry)) / ry
		return dx * dx + dy * dy <= 1.0
	
	return true
