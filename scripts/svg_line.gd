@tool
class_name SVGLine
extends SVGElement

var x1: float = 0.0
var y1: float = 0.0
var x2: float = 10.0
var y2: float = 10.0

func _calculate_content_bounds() -> Rect2:
	var min_x = min(x1, x2)
	var min_y = min(y1, y2)
	var max_x = max(x1, x2)
	var max_y = max(y1, y2)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _draw_content() -> void:
	if stroke_width <= 0 or stroke_color.a <= 0:
		return
	
	var offset = _get_draw_offset()
	var start = Vector2(x1, y1) + offset - _content_bounds.position
	var end = Vector2(x2, y2) + offset - _content_bounds.position
	
	draw_line(start, end, stroke_color, stroke_width, true)

func set_line_properties(attributes: Dictionary) -> void:
	if "x1" in attributes:
		x1 = float(attributes["x1"])
	if "y1" in attributes:
		y1 = float(attributes["y1"])
	if "x2" in attributes:
		x2 = float(attributes["x2"])
	if "y2" in attributes:
		y2 = float(attributes["y2"])
	
	set_common_attributes(attributes)
	apply_svg_transform()

func _has_point(point: Vector2) -> bool:
	if stroke_width <= 0 or stroke_color.a <= 0:
		return false
	
	var test_point = point - _get_draw_offset() + _content_bounds.position
	var start = Vector2(x1, y1)
	var end = Vector2(x2, y2)
	
	var dist = _point_to_segment_distance(test_point, start, end)
	return dist <= stroke_width * 0.5

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ap = point - a
	var ab_squared = ab.dot(ab)
	
	if ab_squared == 0:
		return point.distance_to(a)
	
	var t = clamp(ap.dot(ab) / ab_squared, 0.0, 1.0)
	var projection = a + ab * t
	return point.distance_to(projection)
