@tool
class_name SVGCircle extends SVGElement

@export var radius: float = 10.0:
	set(value):
		radius = value
		_update_control_size()
		queue_redraw()

func _update_control_size() -> void:
	var total_radius = radius + stroke_width
	custom_minimum_size = Vector2(total_radius * 2, total_radius * 2)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size / 2
	
	# Update bounds
	_bounds_min = Vector2(-radius, -radius)
	_bounds_max = Vector2(radius, radius)

func _draw() -> void:
	var center = custom_minimum_size / 2
	
	# Draw fill
	if fill_color.a > 0:
		draw_circle(center, radius, fill_color)
	
	# Draw stroke
	if stroke_width > 0:
		draw_arc(center, radius, 0, TAU, 32, stroke_color, stroke_width, true)

func _is_point_in_shape(point: Vector2) -> bool:
	var center = custom_minimum_size / 2
	var distance = point.distance_to(center)
	return distance <= radius
	
func set_circle_properties(attributes: Dictionary) -> void:
	set_common_attributes(attributes)
	
	if "r" in attributes:
		radius = float(attributes["r"])
	if "cx" in attributes:
		position.x = float(attributes["cx"])
	if "cy" in attributes:
		position.y = float(attributes["cy"])
