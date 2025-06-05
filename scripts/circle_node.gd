@tool
class_name SVGCircle
extends SVGElement

@export var radius: float = 10.0:
	set(value):
		radius = max(0, value)
		_update_size()
		queue_redraw()

var center_x: float = 0.0
var center_y: float = 0.0

func _calculate_content_bounds() -> Rect2:
	return Rect2(0, 0, radius * 2, radius * 2)

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
	
	# Store center coordinates
	if "cx" in attributes:
		center_x = float(attributes["cx"])
	if "cy" in attributes:
		center_y = float(attributes["cy"])
	
	# Apply common attributes
	set_common_attributes(attributes)
	
	# For circles, we need to adjust the position to account for the radius
	# SVG circles are positioned by their center, but Godot positions by top-left
	svg_x = center_x - radius
	svg_y = center_y - radius
	
	# Apply transform
	apply_svg_transform()

func _has_point(point: Vector2) -> bool:
	var center = _get_draw_offset() + Vector2(radius, radius)
	var distance = point.distance_to(center)
	return distance <= radius + stroke_width * 0.5
