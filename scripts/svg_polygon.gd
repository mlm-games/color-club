@tool
class_name SVGPolygon
extends SVGElement

var points: PackedVector2Array = PackedVector2Array():
	set(value):
		points = value
		_update_size()
		queue_redraw()

func _calculate_content_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	
	var min_point = points[0]
	var max_point = points[0]
	
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	
	return Rect2(min_point, max_point - min_point)

func _draw_content() -> void:
	if points.size() < 3:
		return
	
	var offset = _get_draw_offset()
	var adjusted_points = PackedVector2Array()
	
	for point in points:
		adjusted_points.append(point + offset - _content_bounds.position)
	
	# Draw fill
	if fill_color.a > 0:
		draw_colored_polygon(adjusted_points, fill_color)
	
	# Draw stroke
	if stroke_width > 0 and stroke_color.a > 0:
		adjusted_points.append(adjusted_points[0])  # Close the polygon
		draw_polyline(adjusted_points, stroke_color, stroke_width, true)

func set_polygon_properties(attributes: Dictionary) -> void:
	if "points" in attributes:
		points = _parse_points(attributes["points"])
	
	set_common_attributes(attributes)
	apply_svg_transform()

func _parse_points(points_string: String) -> PackedVector2Array:
	var result = PackedVector2Array()
	var numbers = []
	
	# Extract all numbers from the string
	var current_number = ""
	for chr in points_string:
		if chr in "0123456789.-":
			current_number += chr
		elif not current_number.is_empty():
			numbers.append(float(current_number))
			current_number = ""
	
	if not current_number.is_empty():
		numbers.append(float(current_number))
	
	# Convert pairs of numbers to points
	for i in range(0, numbers.size() - 1, 2):
		result.append(Vector2(numbers[i], numbers[i + 1]))
	
	return result

func _has_point(point: Vector2) -> bool:
	var test_point = point - _get_draw_offset() + _content_bounds.position
	
	# Check fill
	if fill_color.a > 0:
		return _point_in_polygon(test_point, points)
	
	# Check stroke
	if stroke_width > 0 and stroke_color.a > 0:
		return _point_near_polygon_edge(test_point, points, stroke_width * 0.5)
	
	return false

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# Same implementation as in SVGPath
	if polygon.size() < 3:
		return false
	
	var inside = false
	var p1 = polygon[0]
	
	for i in range(1, polygon.size() + 1):
		var p2 = polygon[i % polygon.size()]
		
		if point.y > min(p1.y, p2.y):
			if point.y <= max(p1.y, p2.y):
				if point.x <= max(p1.x, p2.x):
					if p1.y != p2.y:
						var xinters = (point.y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x
						if p1.x == p2.x or point.x <= xinters:
							inside = not inside
		
		p1 = p2
	
	return inside

func _point_near_polygon_edge(point: Vector2, polygon: PackedVector2Array, threshold: float) -> bool:
	for i in range(polygon.size()):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % polygon.size()]
		
		var dist = _point_to_segment_distance(point, p1, p2)
		if dist <= threshold:
			return true
	
	return false

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ap = point - a
	var ab_squared = ab.dot(ab)
	
	if ab_squared == 0:
		return point.distance_to(a)
	
	var t = clamp(ap.dot(ab) / ab_squared, 0.0, 1.0)
	var projection = a + ab * t
	return point.distance_to(projection)
